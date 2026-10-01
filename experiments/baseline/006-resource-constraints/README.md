# Experiment 006 - Resource Constraints

## Objective

Measure how explicit container resource limits affect Gotenberg throughput,
latency, and reliability.

The experiment is intended to provide evidence for future ECS task sizing and
Kubernetes resource requests and limits.

## CPU Method

Each formal CPU configuration was tested three times.

### LibreOffice

- requests per run: 120
- concurrency: 6

### Chromium

- requests per run: 120
- concurrency: 8

CPU configurations:

- unlimited
- 4 CPUs
- 2 CPUs
- 1 CPU
- 0.5 CPU

Each run used a fresh Gotenberg container and one warm-up request.

The test harness also captured container resource data and cgroup CPU state.

## CPU Results

| Engine | CPU | Mean Throughput RPS | Mean p50 s | Mean p95 s | Mean p99 s |
|---|---:|---:|---:|---:|---:|
| Chromium | unlimited | 17.858 | 0.416 | 0.619 | 0.937 |
| Chromium | 4 | 15.312 | 0.491 | 0.700 | 0.907 |
| Chromium | 2 | 8.123 | 0.901 | 1.298 | 1.652 |
| Chromium | 1 | 3.936 | 1.840 | 2.792 | 3.546 |
| Chromium | 0.5 | 1.860 | 3.886 | 6.068 | 7.198 |
| LibreOffice | unlimited | 7.220 | 0.923 | 1.080 | 1.168 |
| LibreOffice | 4 | 7.409 | 0.914 | 0.999 | 1.127 |
| LibreOffice | 2 | 7.483 | 0.912 | 0.981 | 1.009 |
| LibreOffice | 1 | 6.773 | 1.029 | 1.163 | 1.234 |
| LibreOffice | 0.5 | 3.301 | 2.095 | 2.355 | 2.411 |

All formal CPU runs completed with a 100% request success rate.

## CPU Observations

Chromium was strongly CPU-sensitive in this workload. Reducing available CPU
caused substantial throughput loss and tail-latency growth.

LibreOffice showed comparatively small performance differences between
unlimited, 4 CPU, and 2 CPU configurations for the small text fixture. A more
noticeable reduction appeared at 1 CPU, while the 0.5 CPU configuration
approximately halved throughput.

These results are workload-specific local measurements and should not be
interpreted as universal Gotenberg sizing recommendations.

They will instead be used as hypotheses for later ECS and EKS experiments.

## Memory Phase

Memory-limit characterization is performed separately so CPU and memory effects
are not intentionally varied at the same time.
