# Experiment 012 - EKS Mixed-Workload Isolation

## Objective

Determine whether separating Chromium and LibreOffice into independently
managed Kubernetes workloads reduces mixed-workload interference compared
with running both engines inside one shared Gotenberg pod.

## Test Design

Both architectures used the same aggregate application resource budget.

### Shared Control

One Gotenberg pod:

- CPU request: 1 CPU
- CPU limit: 2 CPU
- Memory request: 1 GiB
- Memory limit: 4 GiB

Both Chromium and LibreOffice routes were handled by the same process.

### Isolated Architecture

Chromium:

- CPU request: 500m
- CPU limit: 1 CPU
- Memory request: 512 MiB
- Memory limit: 2 GiB

LibreOffice:

- CPU request: 500m
- CPU limit: 1 CPU
- Memory request: 512 MiB
- Memory limit: 2 GiB

Combined resource budget:

- CPU request: 1 CPU
- CPU limit: 2 CPU
- Memory request: 1 GiB
- Memory limit: 4 GiB

Envoy remained in the request path for both architectures.

Each architecture was tested with:

- Chromium-only: 120 requests at concurrency 6
- LibreOffice-only: 120 requests at concurrency 6
- Mixed: 120 Chromium + 120 LibreOffice requests simultaneously
- 3 repetitions

Each architecture therefore processed 1,440 measured requests.

Total experiment volume: 2,880 measured requests.

All requests completed successfully.

## Shared Control Results

### Chromium

- Solo mean throughput: 6.616 RPS
- Mixed mean throughput: 5.223 RPS
- Throughput change: -21.1%

- Solo mean p95: 1.070 s
- Mixed mean p95: 1.441 s
- p95 change: +34.7%

- Solo mean p99: 1.348 s
- Mixed mean p99: 1.727 s
- p99 change: +28.1%

### LibreOffice

- Solo mean throughput: 7.865 RPS
- Mixed mean throughput: 3.876 RPS
- Throughput change: -50.7%

- Solo mean p95: 0.935 s
- Mixed mean p95: 3.075 s
- p95 change: +228.8%

- Solo mean p99: 1.217 s
- Mixed mean p99: 3.309 s
- p99 change: +171.8%

The shared process showed clear workload interference, particularly for
LibreOffice under simultaneous Chromium demand.

## Isolated Architecture Results

### Chromium

- Solo mean throughput: 3.774 RPS
- Mixed mean throughput: 3.593 RPS
- Throughput change: -4.8%

- Solo mean p95: 2.065 s
- Mixed mean p95: 2.135 s
- p95 change: +3.4%

- Solo mean p99: 2.413 s
- Mixed mean p99: 2.625 s
- p99 change: +8.8%

### LibreOffice

- Solo mean throughput: 6.947 RPS
- Mixed mean throughput: 4.303 RPS
- Throughput change: -38.1%

- Solo mean p95: 1.111 s
- Mixed mean p95: 1.798 s
- p95 change: +61.8%

- Solo mean p99: 1.201 s
- Mixed mean p99: 1.939 s
- p99 change: +61.4%

## Shared vs Isolated Interference

| Engine | Metric | Shared | Isolated |
|---|---:|---:|---:|
| Chromium | Throughput change | -21.1% | -4.8% |
| Chromium | p95 change | +34.7% | +3.4% |
| Chromium | p99 change | +28.1% | +8.8% |
| LibreOffice | Throughput change | -50.7% | -38.1% |
| LibreOffice | p95 change | +228.8% | +61.8% |
| LibreOffice | p99 change | +171.8% | +61.4% |

The isolated configuration substantially reduced mixed-workload degradation
for both engines.

The effect was particularly strong for Chromium latency and LibreOffice tail
latency.

## Throughput Tradeoff

Isolation did not improve every metric.

Approximate aggregate mixed throughput was:

- Shared: 9.10 RPS
- Isolated: 7.90 RPS

The isolated configuration therefore produced lower aggregate throughput in
this fixed one-replica-per-engine configuration.

This is explained by the different resource-sharing behavior.

In the shared configuration, either engine can opportunistically consume
more of the pod's two-CPU limit.

In the isolated configuration, each engine is independently capped at one
CPU. This prevents one workload from consuming the other workload's CPU
allocation, but it also prevents unused capacity in one pool from being
immediately borrowed by the other.

## Interpretation

The hypothesis is partially supported.

Separate Kubernetes workload boundaries substantially reduced cross-engine
interference and improved performance predictability, especially tail
latency.

However, fixed resource partitioning also reduced burst efficiency and
aggregate throughput.

The result therefore supports independent engine pools primarily as a
resource-isolation and scaling architecture rather than as an automatic
throughput optimization.

The next engineering step is independent autoscaling.

Autoscaling can preserve the isolation benefits while allowing a pressured
engine to add capacity rather than being permanently restricted to one CPU
and one replica.

## Conclusion

Experiment 012 demonstrated a measurable reason for separating Chromium and
LibreOffice.

The shared architecture allowed better opportunistic CPU sharing but showed
substantial mixed-workload interference, especially for LibreOffice.

The isolated architecture significantly reduced interference and tail-latency
amplification but introduced a capacity tradeoff because each engine was
limited to a fixed resource boundary.

This establishes the technical basis for evaluating independent autoscaling
policies in the next phase.
