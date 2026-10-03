# Experiment 013 - EKS Autoscaling

## Objective

Compare reactive CPU-based Kubernetes autoscaling with workload-aware
autoscaling based on Gotenberg queue pressure.

The purpose is not only to determine whether replicas increase, but to
measure what happens to requests while the autoscaler is detecting and
responding to overload.

## Architecture

Traffic path:

Client
  -> AWS ALB
  -> Envoy
  -> Chromium service / LibreOffice service
  -> independently scalable Gotenberg engine deployments

Each engine pod retains the resource boundaries established during
Experiment 012:

- CPU request: 500m
- CPU limit: 1 CPU
- Memory request: 512 MiB
- Memory limit: 2 GiB

## Infrastructure Constraint

The EKS managed node group is capped at two worker nodes during this
experiment.

This creates a fixed infrastructure capacity ceiling so different
autoscaling policies can be compared under the same cluster limit.

## Phase A - CPU HPA

Kubernetes HorizontalPodAutoscaler will scale each engine using CPU
utilization.

Initial policy:

- min replicas: 1
- max replicas: 2
- target average CPU utilization: 70%

Measurements:

- workload start time
- CPU rise
- queue depth
- HPA desired replica count
- replica creation time
- new pod Ready time
- throughput
- p50/p95/p99 latency
- failures
- peak queue depth
- scale-down behavior

## Phase B - Queue-Aware Scaling

The same architecture and workload will later be tested using Gotenberg
queue metrics rather than CPU utilization as the primary overload signal.

The objective is to determine whether workload pressure can be detected
earlier than CPU-based HPA.

## Interpretation

CPU HPA will not be considered ineffective simply because queue-aware
scaling reacts faster.

The comparison must distinguish:

- metric detection delay
- scheduling delay
- pod startup delay
- available node capacity
- workload behavior after capacity becomes Ready

Results apply only to the tested EKS/Gotenberg configuration.
