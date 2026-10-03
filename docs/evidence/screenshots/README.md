# OpsLens Visual Evidence Gallery

This directory contains a curated set of screenshots that support the measurements and architecture described in the root README.

The goal is **evidence, not decoration**. Screenshots are kept only when they demonstrate a meaningful engineering result.

## Experiments

### ECS horizontal scaling
`experiments/ecs-horizontal-scaling.png`

Shows the 1-task vs 2-task experiment:
- Chromium throughput +93.9%
- Chromium p95 -41.2%
- LibreOffice throughput +85.3%
- LibreOffice p95 -43.9%

### ECS vs EKS controlled baseline
`experiments/ecs-vs-eks-baseline.png`

A bounded comparison from the single-pod baseline. It should **not** be interpreted as a universal platform ranking.

### EKS single-pod results
`experiments/eks-single-pod-results.png`

Shows the concurrency sweep used for the EKS single-pod baseline.

### Mixed-workload isolation
`experiments/mixed-workload-isolation.png`

Shows shared vs isolated mixed-load degradation:
- Chromium RPS loss: -21.1% shared vs -4.8% isolated
- LibreOffice RPS loss: -50.7% shared vs -38.1% isolated
- 2,880 requests, 0 failures

### CPU HPA vs queue-aware scaling
`experiments/autoscaling-comparison.png`

Shows:
- CPU HPA scale decision ~36.6s
- queue-aware decision ~2.55s
- CPU HPA second replica Ready ~55.1s
- queue-aware second replica Ready ~5.3s

---

## Observability

### Grafana overview
`observability/grafana-overview.png`

Shows:
- Chromium and LibreOffice queue depth
- engine readiness
- Envoy request rate / 5xx rate
- pod CPU and memory
- deployment readiness
- EKS node utilization

### Grafana logs
`observability/grafana-logs.png`

Shows real Envoy access logs and Gotenberg engine logs collected through OpenTelemetry and queried through Loki/Grafana.

### Prometheus rules
`observability/prometheus-rules.png`

Shows the operational alert rules and SLI recording-rule group in a healthy state.

### Prometheus alert firing
`observability/prometheus-alert-firing.png`

Shows `OpsLensScrapeTargetDown` in the FIRING state during the controlled alert experiment.

---

## GitOps

### Argo CD resource tree
`gitops/argocd-resource-tree.png`

Shows the active OpsLens application as `Synced / Healthy` with the managed resource tree.

### Argo reconciliation lifecycle
`gitops/argocd-reconciliation.png`

Captures Argo moving through `OutOfSync` / `Progressing` and returning to `Synced / Healthy`.

### Argo self-heal observation
`gitops/argocd-self-heal.png`

Shows the live replica drift being restored to the desired value.

---

## Kubernetes final state

### Cluster state
`kubernetes/final-cluster-state.png`

Shows:
- two Ready EKS nodes
- Envoy desired 2 / available 2
- Chromium and LibreOffice Ready
- Envoy replicas placed on different nodes

### HA, PDB, storage, and Argo state
`kubernetes/envoy-ha-pdb-storage.png`

Shows:
- two Envoy replicas on different nodes
- PodDisruptionBudget `minAvailable: 1`
- Loki PVC using gp3
- Argo application `Synced / Healthy`

---

## AWS / ECS evidence

### Two-task ECS and target health
`aws/ecs-two-task-target-health.png`

Shows:
- ECS service desired/running 2
- both ALB target entries healthy

This terminal evidence was selected instead of AWS Console screenshots because several Console screenshots expose the AWS account ID.

---

## Intentionally excluded from the public package

The following captured screenshots are **not included** in this Git-ready package:

- EKS Console overview containing AWS account ID / ARNs
- S3 Console screenshot where the bucket name embeds the AWS account ID
- ECS Console screenshots exposing the AWS account identifier
- GitHub Actions screenshot where all captured workflow runs are red
- duplicate or weaker screenshots that add no new engineering evidence
- screenshots containing long ECR image URLs with AWS account ID

Keep those locally for private reference if useful.

### GitHub Actions CI

`gitops/github-actions-ci-green.png`

The latest `OpsLens CI` run succeeded after Kubernetes validation was changed to operate offline, without EKS credentials or a kubeconfig.

Validated jobs:

- Terraform validation
- Kubernetes validation
- Script validation
- Repository hygiene

Earlier failed runs remain visible in the workflow history, which is expected; the latest run is the authoritative CI state.
