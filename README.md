# OpsLens

Reliability, overload, and failure engineering for a document-processing workload on AWS and Kubernetes.

OpsLens uses the open-source Gotenberg document conversion service as a real production-style workload and follows a measurement-first SRE engineering cycle:

**Baseline → Observe → Hypothesize → Change → Test → Measure → Compare**

The goal is not to demonstrate a collection of DevOps tools. The goal is to understand how a real service behaves under concurrency, resource pressure, scaling events, mixed workloads, failures, recovery, and operational change.

<p align="center">
  <img src="docs/assets/opslens-architecture.png" alt="OpsLens architecture" width="100%" />
</p>

## What OpsLens Demonstrates

- Local workload characterization before cloud migration
- ECS/Fargate baseline and horizontal-scaling experiments
- EKS migration and workload isolation
- CPU HPA versus queue-aware autoscaling
- Metrics, logs, dashboards, SLIs, and alerts
- Controlled Kubernetes failure injection
- Persistent Loki storage through EBS CSI
- Durable conversion-result validation through S3
- Asynchronous webhook delivery validation
- GitHub Actions repository validation
- Argo CD GitOps reconciliation and self-healing
- Availability hardening based on a measured failure

## Architecture at a Glance

The final active request path is:

`Client → AWS ALB → Envoy Gateway x2 → Chromium / LibreOffice Gotenberg engines`

The supporting platform is intentionally bounded:

- **Prometheus** for metrics
- **Grafana** for visualization
- **Loki** for persistent logs
- **OpenTelemetry Collector** for Kubernetes log collection/enrichment
- **CloudWatch** for AWS/EKS infrastructure and control-plane visibility
- **S3** for short-lived durable-result validation artifacts
- **Argo CD** for the active OpsLens application boundary
- **Terraform** for AWS infrastructure

Distributed tracing was deliberately deferred rather than adding another system without a strong engineering requirement.

See [Architecture](docs/architecture/architecture.md) for the detailed design and ownership boundaries.

## Key Engineering Results

### Local workload characterization

The two conversion engines behaved differently under load:

- Chromium plateaued at roughly **19 requests/second** in the local concurrency experiment.
- LibreOffice plateaued at roughly **8 requests/second**.
- Chromium was more CPU-sensitive.
- Very low Chromium memory limits produced severe OOM behavior.
- Mixed workloads interfered with one another when sharing the same runtime boundary.

These observations motivated workload isolation instead of treating all document conversions as one homogeneous workload.

### ECS horizontal scaling

Scaling the ECS service from one task to two tasks produced the following controlled-lab results:

- Chromium throughput: **+93.9%**
- Chromium p95 latency: **-41.2%**
- LibreOffice throughput: **+85.3%**
- LibreOffice p95 latency: **-43.9%**
- Requests completed: **720/720**

These are bounded experiment results, not generalized cloud-platform capacity claims.

### EKS workload isolation

Separating Chromium and LibreOffice into independent Kubernetes Deployments and Services improved predictability under mixed load.

| Engine | Shared runtime degradation | Isolated runtime degradation |
|---|---:|---:|
| Chromium | ~21.1% | ~4.8% |
| LibreOffice | ~50.7% | ~38.1% |

Isolation reduced interference, although it did not automatically maximize aggregate throughput.

### Autoscaling control loop

OpsLens compared CPU HPA with a custom queue-aware scaler.

| Measurement | CPU HPA | Queue-aware scaler |
|---|---:|---:|
| Scale decision | ~36.6 s | ~2.55 s |
| Second replica Ready | ~55.1 s | ~5.3 s |

The queue-aware signal reacted substantially earlier. The experiment also demonstrated an important SRE principle: **a faster scaling decision does not automatically guarantee better end-to-end performance when another workload bottleneck remains.**

## Observability and Reliability Signals

The observability scope is intentionally small and explicit:

| Concern | Tool |
|---|---|
| AWS/EKS infrastructure | CloudWatch |
| Metrics | Prometheus |
| Logs | Loki |
| Kubernetes log collection | OpenTelemetry Collector |
| Visualization | Grafana |

Prometheus recording rules cover:

- upstream request rate
- upstream 5xx rate
- upstream success ratio
- upstream p95 latency

Alerts cover:

- scrape-target loss
- upstream 5xx rate
- excessive upstream latency
- engine queue backlog
- engine restart activity

Zero-traffic behavior is explicitly handled so an idle period is not reported as a synthetic 100% success ratio.

## Failure Engineering

OpsLens injects failures instead of assuming Kubernetes recovery is enough.

### Chromium pod deletion

During a 90-request probe:

- Successful: **89/90**
- Failed: **1**
- Success rate: **98.89%**

Kubernetes recreated the engine pod and request processing recovered.

### Single Envoy gateway deletion

Before hardening:

- Successful: **86/90**
- Failed: **4**
- Success rate: **95.56%**

This exposed the single Envoy replica as a real availability weakness.

Evidence: [`docs/evidence/016-failure-engineering/`](docs/evidence/016-failure-engineering/)

## Production Availability Hardening

The gateway was changed to:

- **2 Envoy replicas**
- preferred pod anti-affinity across worker nodes
- `PodDisruptionBudget` with `minAvailable: 1`
- Git-managed desired state reconciled by Argo CD

The same failure class was then retested.

| Experiment | Envoy replicas | Requests | Successful | Failed | Success rate |
|---|---:|---:|---:|---:|---:|
| Before hardening | 1 | 90 | 86 | 4 | 95.56% |
| After hardening | 2 | 90 | 90 | 0 | 100.00% |

In this controlled lab run, gateway redundancy eliminated the request failures observed during the earlier single-replica test. This is a bounded result, not a universal zero-downtime claim.

Evidence: [`docs/evidence/019-production-hardening/`](docs/evidence/019-production-hardening/)

## Durable Result Validation

A real conversion path is validated end to end:

`HTML → Envoy → Gotenberg Chromium → PDF → private S3 → independent download → SHA-256 comparison`

The harness validates:

- HTTP conversion success
- PDF file signature
- PDF size
- SHA-256 checksum
- S3 AES256 server-side encryption
- S3 versioning
- independent re-download
- checksum equality after download

A separate experiment validates Gotenberg asynchronous webhook delivery and request/callback correlation.

Evidence: [`docs/evidence/017-durable-validation/`](docs/evidence/017-durable-validation/)

## CI/CD and GitOps

### GitHub Actions

Repository CI validates:

- Terraform formatting and configuration
- Kubernetes manifests
- shell-script syntax
- Grafana dashboard JSON
- repository hygiene

CI intentionally does not require production AWS or EKS credentials.

### Argo CD

Argo CD manages only the active OpsLens application boundary:

- OpsLens Namespace
- Envoy ConfigMap
- Envoy Deployment
- Envoy Services
- Envoy PodDisruptionBudget
- Chromium Deployment and Service
- LibreOffice Deployment and Service

Observability and temporary validation resources remain outside this Argo application by design.

GitOps self-healing was tested by manually changing the Envoy replica count. Argo restored the Git-defined desired state and returned the application to **Synced / Healthy**.

## Infrastructure Ownership

| Layer | Owner |
|---|---|
| AWS infrastructure | Terraform |
| Observability platform components | Helm |
| Argo CD installation | Helm |
| Active OpsLens application | Argo CD + Kubernetes manifests |
| Repository validation | GitHub Actions |

The project deliberately avoids giving multiple tools competing ownership of the same resource.

## Security Decisions

Selected controls include:

- private EKS worker subnets
- restricted EKS API access
- restricted ALB ingress
- separate IAM roles by responsibility
- IRSA for AWS Load Balancer Controller
- IRSA for EBS CSI
- private Grafana access through localhost port-forwarding
- Envoy admin interface exposed only through ClusterIP
- private S3 results bucket
- S3 public-access blocking
- server-side encryption
- S3 versioning and lifecycle expiration
- reduced Envoy Linux capabilities
- no application credentials committed to Git

See [Security and Cost Notes](docs/security-cost.md).

## Repository Structure

```text
.
├── .github/workflows/       GitHub Actions CI
├── docs/
│   ├── adr/                 Architecture decisions
│   ├── architecture/        Architecture documentation
│   ├── assets/              README / architecture visuals
│   ├── evidence/            Failure and reliability evidence
│   └── runbooks/            Operational procedures
├── experiments/
│   ├── baseline/            Local experiments 001-008
│   └── cloud/               ECS/EKS experiments 009-013
├── kubernetes/
│   ├── base/
│   ├── engines/
│   ├── gateway/
│   ├── gitops/
│   ├── observability/
│   └── validation/
├── scripts/                 Validation harnesses
├── terraform/
│   ├── bootstrap/
│   └── infrastructure/
└── tools/                   Load, metrics, scaling, lifecycle tooling
```

## Experiment Progression

| Experiment | Focus |
|---|---|
| 001-008 | Local workload characterization |
| 009 | ECS single-task baseline |
| 010 | ECS horizontal scaling |
| 011 | EKS single-pod baseline |
| 012 | Mixed-workload isolation |
| 013 | CPU HPA versus queue-aware autoscaling |
| 014 | Metrics and log observability |
| 015 | Reliability SLIs and alerting |
| 016 | Kubernetes failure engineering |
| 017 | Durable and asynchronous result validation |
| 018 | CI/CD and GitOps |
| 019 | Production availability hardening |

See [Evidence Index](docs/evidence/README.md).

## Scope and Limitations

OpsLens is an engineering lab, not a claim of production certification.

Important boundaries:

- results are controlled experiments rather than universal capacity guarantees
- short-window reliability indicators are used because the lab does not retain production-length telemetry
- the environment uses a deliberately small EKS node group
- distributed tracing was intentionally deferred
- the project focuses on reliability engineering rather than application feature development

## Workload Attribution

OpsLens uses Gotenberg as the upstream document-processing workload.

See [ATTRIBUTION.md](ATTRIBUTION.md) for attribution details.
