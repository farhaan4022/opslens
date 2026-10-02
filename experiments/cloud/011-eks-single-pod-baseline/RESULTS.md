# Experiment 011 - EKS Single-Pod Baseline

## Objective

Establish the capacity and latency characteristics of Gotenberg running as a
single Kubernetes pod on Amazon EKS and compare the results with the earlier
single-task ECS Fargate baseline.

## Configuration

- Platform: Amazon EKS
- Kubernetes: 1.35
- Replicas: 1
- Worker node: m6i.large
- Gotenberg: 8.37.0
- CPU request: 500m
- CPU limit: 1 CPU
- Memory request: 512 MiB
- Memory limit: 2 GiB
- External traffic: AWS ALB
- ALB target type: pod IP
- Requests per concurrency point: 60
- Warm-up requests: 1
- Concurrency: 1, 2, 4, 6, 8, 12

The same fixtures and load generator used for the ECS baseline were reused.

## Chromium Results

| Concurrency | Success | Failure | Throughput RPS | p50 s | p95 s | p99 s |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 60 | 0 | 1.916 | 0.485 | 0.625 | 1.276 |
| 2 | 60 | 0 | 2.694 | 0.684 | 1.086 | 1.176 |
| 4 | 60 | 0 | 3.697 | 1.095 | 1.199 | 1.282 |
| 6 | 60 | 0 | 3.816 | 1.503 | 2.076 | 2.259 |
| 8 | 60 | 0 | 3.769 | 1.871 | 2.713 | 3.032 |
| 12 | 60 | 0 | 3.968 | 2.975 | 3.286 | 3.473 |

Useful Chromium throughput gains occurred primarily up to approximately
concurrency 4. Beyond this point throughput remained around 3.7-4.0 RPS,
while latency continued to increase.

At concurrency 8 and 12, sampled pod CPU reached approximately 992m and
1003m respectively, consistent with the workload approaching its configured
1-CPU limit.

## LibreOffice Results

| Concurrency | Success | Failure | Throughput RPS | p50 s | p95 s | p99 s |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 60 | 0 | 2.627 | 0.315 | 0.658 | 1.085 |
| 2 | 60 | 0 | 4.992 | 0.316 | 0.736 | 0.758 |
| 4 | 60 | 0 | 6.827 | 0.396 | 0.903 | 0.938 |
| 6 | 60 | 0 | 6.836 | 1.025 | 1.097 | 1.130 |
| 8 | 60 | 0 | 6.803 | 1.218 | 1.302 | 1.515 |
| 12 | 60 | 0 | 6.990 | 1.572 | 2.109 | 2.129 |

LibreOffice throughput increased strongly until approximately concurrency 4
and then plateaued around 6.8-7.0 RPS.

Additional concurrency primarily increased latency rather than processing
capacity.

## Queue Behaviour

Peak Chromium queue observations increased with concurrency:

1, 2, 4, 6, 8, 12.

Peak LibreOffice observations were:

1, 1, 3, 6, 8, 12.

These metrics are used as indicators of request pressure. They are not
interpreted as exact measurements of requests waiting specifically for CPU
execution.

## Resource Observations

The highest sampled Chromium CPU values were approximately:

- concurrency 8: 992m
- concurrency 12: 1003m

This is consistent with Chromium approaching the configured one-core CPU
limit under high concurrency.

The highest observed pod memory value was approximately 357 MiB, well below
the configured 2 GiB memory limit.

Metrics Server was sampled every five seconds. Because several benchmark
cases completed quickly, some cases contain only a small number of resource
samples. These measurements therefore provide coarse utilization evidence
rather than high-resolution CPU profiling.

In particular, the sampled LibreOffice CPU peaks should not be interpreted
as proof of low CPU demand.

## ECS Comparison

Compared with the earlier single-task ECS Fargate baseline, this EKS
configuration showed higher throughput at moderate and high concurrency.

At concurrency 12:

| Engine | ECS RPS | EKS RPS | Throughput Change | ECS p95 | EKS p95 | p95 Change |
|---|---:|---:|---:|---:|---:|---:|
| Chromium | 2.734 | 3.968 | +45.1% | 4.818 s | 3.286 s | -31.8% |
| LibreOffice | 4.921 | 6.990 | +42.0% | 3.045 s | 2.109 s | -30.7% |

These results demonstrate the behavior of the tested configurations and
should not be interpreted as a general claim that EKS is inherently faster
than ECS.

The environments differ in underlying compute implementation, runtime,
network path and platform overhead even though the application-level CPU and
memory boundaries were intentionally kept similar.

## Conclusion

The EKS single-pod experiment establishes a clear baseline before Kubernetes
workload isolation and autoscaling are introduced.

Both engines eventually reached throughput plateaus as concurrency increased.

Chromium approached its configured one-core CPU limit at high concurrency,
while memory remained well below its configured limit.

The next experiment will investigate whether separating Chromium and
LibreOffice into independently managed Kubernetes workloads provides better
resource isolation and creates a stronger foundation for engine-specific
scaling policies.
