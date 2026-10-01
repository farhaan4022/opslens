# Experiment 001 - Local Single-Instance Idle Baseline

## Objective

Establish the initial operating state of an unmodified Gotenberg instance
before workload generation, resource limits, Kubernetes orchestration,
autoscaling or observability changes.

## Configuration

- Gotenberg: 8.37.0
- Deployment: Docker
- Replicas: 1
- Exposure: localhost only
- Explicit CPU limit: none
- Explicit memory limit: none
- Workload during measurement: none

## Observations

- API health endpoint returned HTTP 200.
- Chromium health status: up.
- LibreOffice health status: up.
- No warning, error, fatal or panic messages were observed in startup logs.
- Idle CPU utilization was approximately 0.02-0.04%.
- Idle container memory was approximately 8.8-9.4 MiB.
- Only the Gotenberg process and tini init process were visible during the
  idle process inspection.

## Interpretation

The service is healthy while idle and is suitable for workload
characterization.

The idle memory and CPU observations must not be treated as production
resource-sizing values because no document conversion was active.

## Next Experiment

Characterize Chromium and LibreOffice conversion behaviour independently.
