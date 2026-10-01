# Experiment 005 - Concurrency Sweep

## Objective

Measure how Gotenberg throughput and latency change as concurrent request
load increases.

This experiment establishes a baseline capacity curve before introducing
Kubernetes scheduling, resource limits, autoscaling, or workload isolation.

## Method

Concurrency levels:

- 1
- 2
- 4
- 6
- 8
- 12

Each level is repeated three times.

Workloads:

- Chromium HTML conversion
- LibreOffice document conversion

Metrics collected:

- throughput
- success rate
- p50 latency
- p95 latency
- p99 latency
- maximum latency

## Engineering Question

At what concurrency level does additional parallelism stop increasing useful
throughput and begin increasing queue wait time?

## Expected Output

The experiment will produce:

- raw per-request measurements
- summary CSV files
- evidence for Kubernetes resource and scaling decisions
