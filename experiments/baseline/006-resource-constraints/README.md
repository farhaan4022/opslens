# Experiment 006 - Resource Constraints

## Objective

Measure how explicit container resource limits affect Gotenberg throughput,
latency, and reliability.

The experiment is intended to provide evidence for future Kubernetes/EKS
resource requests, limits, and scaling decisions.

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

They will instead be used as hypotheses for later Kubernetes/EKS experiments.

## Memory Method

Memory was varied independently while CPU remained unlimited.

Formal configurations:

- unlimited
- 1 GiB
- 512 MiB
- 256 MiB

Each configuration was tested twice.

LibreOffice used concurrency 6 and Chromium used concurrency 8, with 120
requests per run.

For memory-limited containers, Docker memory and memory-swap were set to the
same value. On this cgroup v2 host this resulted in `memory.swap.max=0`, so
swap could not mask memory pressure.

## Memory Results

| Engine | Memory | Successes | Failures | Success Rate | Mean Throughput RPS | Mean p95 s | OOM Kills |
|---|---:|---:|---:|---:|---:|---:|---:|
| Chromium | unlimited | 240 | 0 | 100% | 19.402 | 0.601 | 0 |
| Chromium | 1 GiB | 240 | 0 | 100% | 19.618 | 0.569 | 0 |
| Chromium | 512 MiB | 240 | 0 | 100% | 19.327 | 0.557 | 0 |
| Chromium | 256 MiB | 4 | 236 | 1.67% | 0.104 | N/A | 198 |
| LibreOffice | unlimited | 240 | 0 | 100% | 7.889 | 1.005 | 0 |
| LibreOffice | 1 GiB | 240 | 0 | 100% | 8.036 | 0.946 | 0 |
| LibreOffice | 512 MiB | 240 | 0 | 100% | 8.263 | 0.885 | 0 |
| LibreOffice | 256 MiB | 240 | 0 | 100% | 8.224 | 0.921 | 0 |

Successful-request latency is intentionally not reported for the Chromium
256 MiB configuration because only four of 240 requests succeeded. Those
latencies would not represent normal service performance.

## Chromium 256 MiB Failure Characterization

Both Chromium 256 MiB repetitions experienced severe request failure.

Repeat 1:

- 2 successful requests
- 118 failed requests
- 110 HTTP 503 responses
- 8 HTTP 400 responses
- 102 cgroup OOM-kill events

Repeat 2:

- 2 successful requests
- 118 failed requests
- 102 HTTP 503 responses
- 16 HTTP 400 responses
- 96 cgroup OOM-kill events

The request CSV `error` field remained empty for these HTTP failures because
the current workload generator records HTTP response failures using
`status_code` and `success`; the error field is primarily populated for client
exceptions.

## Memory Observations

For the tested small HTML workload, Chromium showed no material degradation
between unlimited memory, 1 GiB, and 512 MiB.

At 256 MiB, however, Chromium crossed a clear reliability boundary. Request
success fell to 1.67%, and the cgroup recorded repeated OOM kills.

The container was still observed in a running state after these runs despite
severe request-level failure and OOM activity. This demonstrates why container
state alone is insufficient as a service-health signal.

LibreOffice completed all requests at every tested memory level, including
256 MiB, for the small text fixture.

These measurements are specific to this local host, fixture size, concurrency,
Gotenberg version, and workload. They are not universal production sizing
recommendations.

## Engineering Conclusions

The two conversion engines have materially different resource behavior.

Chromium is strongly CPU-sensitive and substantially more memory-sensitive.
For this workload, 512 MiB remained healthy while 256 MiB produced severe
OOM-related service degradation.

LibreOffice reached diminishing CPU returns earlier and tolerated the tested
256 MiB memory limit without request failures.

The results support treating Chromium and LibreOffice as separate workload
classes when designing Kubernetes resource requests, limits, scaling policy,
and failure isolation.

Final Kubernetes values will be validated again under EKS rather than copied
directly from these local measurements.
