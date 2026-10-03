# OpsLens Evidence Index

OpsLens stores experiment outputs so architectural claims can be traced back to measurements.

## Experiments 001-008 — local baseline

Location: `experiments/baseline/`

Topics include:

- single-instance baseline
- engine characterization
- cold/warm lifecycle
- queue formation
- concurrency sweep
- CPU and memory constraints
- engine interference
- local scaling capacity

## Experiments 009-013 — cloud and Kubernetes

Location: `experiments/cloud/`

Topics include:

- ECS single-task baseline
- ECS horizontal scaling
- EKS single-pod baseline
- mixed-workload isolation
- CPU HPA versus queue-aware scaling

## Experiment 016 — failure engineering

Location: `docs/evidence/016-failure-engineering/`

Key observations:

- Chromium pod deletion: 89/90 successful requests
- single Envoy deletion: 86/90 successful requests
- gateway single-replica availability weakness identified

## Experiment 017 — durable and asynchronous validation

Location: `docs/evidence/017-durable-validation/`

Validates:

- real PDF conversion
- PDF signature and size
- S3 AES256 encryption
- S3 versioning
- independent re-download
- SHA-256 equality
- asynchronous webhook callback
- correlation between request and callback

## Experiment 019 — production hardening

Location: `docs/evidence/019-production-hardening/`

The gateway was changed from one Envoy replica to two replicas distributed across worker nodes, with a PodDisruptionBudget.

Controlled comparison:

| Test | Successful | Failed | Success rate |
|---|---:|---:|---:|
| Single Envoy deletion | 86/90 | 4 | 95.56% |
| Hardened two-replica Envoy deletion | 90/90 | 0 | 100.00% |

The result is reported as a bounded lab experiment, not a universal availability guarantee.
