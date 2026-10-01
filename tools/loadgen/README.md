# OpsLens Load Generator

Reusable workload generator used for Gotenberg reliability experiments.

## Purpose

Provide repeatable workload execution across:

- Docker
- Kubernetes
- future cloud deployments

## Captured Metrics

- request latency
- throughput
- success rate
- p50/p95/p99 latency
- response validation
- request trace identifiers

## Components

### loadgen.py

Executes a single controlled workload.

### run-sweep.sh

Runs multiple concurrency levels:

1
2
4
6
8
12

with repeated measurements.

### summarize-sweep.py

Aggregates experiment outputs into CSV summaries.

