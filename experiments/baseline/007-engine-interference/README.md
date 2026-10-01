# Experiment 007 - Engine Interference and Isolation

## Objective

Determine whether Chromium and LibreOffice workloads interfere with each other
when they share one Gotenberg instance, and whether workload isolation changes
latency, throughput, queue behaviour, and reliability.

## Hypothesis

Experiment 006 demonstrated materially different CPU and memory behaviour
between Chromium and LibreOffice.

A shared resource pool may therefore allow demand from one conversion engine
to affect the latency or throughput of the other.

This experiment tests that hypothesis rather than assuming separate
Kubernetes workloads are automatically better.

## Comparison

### Shared architecture

One Gotenberg container with:

- 4 CPUs
- 1 GiB memory
- Chromium and LibreOffice requests submitted concurrently

### Isolated architecture

Two Gotenberg containers with an aggregate resource budget equivalent to the
shared architecture.

The initial evidence-informed partition is:

- Chromium: 3 CPUs and 768 MiB
- LibreOffice: 1 CPU and 256 MiB

This partition is based on Experiment 006, where Chromium showed substantially
greater CPU and memory sensitivity while LibreOffice tolerated lower resource
limits for the tested small-document workload.

The isolated comparison therefore represents both engine isolation and an
explicit resource partition. It is not interpreted as a pure isolation-only
experiment.

## Measurements

For each engine:

- request success rate
- throughput
- p50 latency
- p95 latency
- p99 latency
- observed queue depth

Container CPU and memory utilisation are also captured.

## Interpretation Constraint

Results are specific to the local host, Gotenberg 8.37.0, selected fixtures,
concurrency levels, resource partition, and experiment duration.

The results are intended to inform the later Kubernetes/EKS architecture.

## Results Summary

All 18 formal runs completed successfully with:

- 100% request success rate
- no container OOM events
- no abnormal container exits

### Shared Architecture

Mixed workload execution reduced throughput and increased tail latency
compared with single-engine execution.

Chromium throughput decreased from approximately 16.146 RPS to 13.546 RPS,
with p95 latency increasing from 0.664 s to 0.797 s.

LibreOffice showed a larger impact, with throughput decreasing from
approximately 8.011 RPS to 6.036 RPS and p95 latency increasing from
0.938 s to 1.797 s.

### Isolated Architecture

The isolated architecture showed smaller differences between solo and mixed
execution.

Chromium throughput changed from approximately 12.159 RPS to 11.834 RPS,
while p95 latency remained approximately stable.

LibreOffice throughput changed from approximately 7.280 RPS to 6.903 RPS,
with a smaller p95 latency increase compared with the shared architecture.

### Interpretation

Under the tested workload and resource allocation, shared execution created
greater cross-engine contention, particularly affecting LibreOffice tail
latency.

The isolated architecture reduced this observed interference by allocating
separate resource pools.

These findings represent local Docker measurements and will be validated
against Kubernetes/EKS deployment behaviour in later experiments.
