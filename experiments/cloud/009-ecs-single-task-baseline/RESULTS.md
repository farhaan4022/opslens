# Experiment 009 - ECS Single-Task Cloud Baseline Results

## Objective

Establish the performance and capacity baseline of Gotenberg running as a
single AWS ECS Fargate task before evaluating horizontal scaling.

## Runtime Configuration

- AWS region: ap-south-1
- ECS launch type: Fargate
- Desired task count: 1
- Task CPU: 1 vCPU
- Task memory: 2 GiB
- Gotenberg version: 8.37.0
- Container image: ECR image pinned by digest
- Container port: 3000
- Application Load Balancer: HTTP port 80
- ECS tasks: private subnets
- CloudWatch logs enabled
- ECS Container Insights enabled
- Formal benchmark source restricted to trusted static VPN ingress

## Functional Validation

Before formal testing, both conversion engines were validated through the
public ALB.

Chromium smoke test:

- Requests: 5
- Successes: 5
- Failures: 0
- Success rate: 100%
- Throughput: 1.623 RPS
- p50 latency: 0.616 s
- p95 latency: 0.697 s

LibreOffice smoke test:

- Requests: 5
- Successes: 5
- Failures: 0
- Success rate: 100%
- Throughput: 2.608 RPS
- p50 latency: 0.355 s
- p95 latency: 0.479 s

## Chromium Results

| Concurrency | Success | Failure | Throughput RPS | p50 s | p95 s | p99 s | Max s | Peak Queue |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 60 | 0 | 1.710 | 0.587 | 0.608 | 0.646 | 0.647 | 1 |
| 2 | 60 | 0 | 2.253 | 0.858 | 0.961 | 1.661 | 1.797 | 2 |
| 4 | 60 | 0 | 2.576 | 1.558 | 1.791 | 1.972 | 2.047 | 4 |
| 6 | 60 | 0 | 2.547 | 2.265 | 3.190 | 3.536 | 3.651 | 6 |
| 8 | 60 | 0 | 2.631 | 2.782 | 4.131 | 4.387 | 4.403 | 8 |
| 12 | 60 | 0 | 2.734 | 4.269 | 4.818 | 5.036 | 5.331 | 12 |

Chromium showed useful throughput improvement between concurrency 1 and 4.
Beyond approximately concurrency 4, throughput changed only marginally while
latency increased substantially.

For example, throughput increased from 2.576 RPS at concurrency 4 to only
2.734 RPS at concurrency 12, while p95 latency increased from 1.791 seconds
to 4.818 seconds.

This indicates diminishing returns from additional concurrency on the
single-vCPU task.

## LibreOffice Results

| Concurrency | Success | Failure | Throughput RPS | p50 s | p95 s | p99 s | Max s | Peak Queue |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 60 | 0 | 2.287 | 0.352 | 0.964 | 1.146 | 1.255 | 1 |
| 2 | 60 | 0 | 4.003 | 0.357 | 1.067 | 1.124 | 1.145 | 2 |
| 4 | 60 | 0 | 4.915 | 0.494 | 1.310 | 1.424 | 1.497 | 4 |
| 6 | 60 | 0 | 5.050 | 1.448 | 1.524 | 1.535 | 1.536 | 6 |
| 8 | 60 | 0 | 4.885 | 1.735 | 1.780 | 1.792 | 1.792 | 8 |
| 12 | 60 | 0 | 4.921 | 2.256 | 3.045 | 3.063 | 3.077 | 12 |

LibreOffice throughput increased strongly up to approximately concurrency
4-6. Beyond that point, throughput remained close to 5 RPS while latency
continued to rise.

Concurrency 6 produced 5.050 RPS, while concurrency 12 produced 4.921 RPS.
At the same time, p95 latency increased from 1.524 seconds to 3.045 seconds.

This establishes a practical throughput plateau for this workload on the
single task.

## Queue Behaviour

The sampled Gotenberg queue metrics increased with submitted concurrency for
both engines.

Observed peak values were:

- Chromium: 1, 2, 4, 6, 8, 12
- LibreOffice: 1, 2, 4, 6, 8, 12

These measurements demonstrate increasing request pressure as concurrency
rises.

The queue metric is not interpreted here as an exact count of requests
waiting for CPU execution. The experiment only uses it as evidence that
Gotenberg's internal request pressure increased with concurrency.

## ECS Resource Utilization

CloudWatch ECS service metrics collected over the formal benchmark window
reported:

| Resource | Samples | Average | Peak |
|---|---:|---:|---:|
| CPU utilization | 7 | 48.13% | 99.96% |
| Memory utilization | 7 | 13.57% | 17.80% |

The nearly 100% observed CPU peak, combined with the throughput plateau and
increasing tail latency, is consistent with CPU becoming a limiting resource
during portions of the workload.

Memory utilization remained comparatively low, with a peak of 17.80%.
Therefore, this experiment does not indicate memory capacity as the primary
constraint.

CloudWatch measurements were collected at one-minute resolution across the
overall test window. They should therefore be treated as coarse service-level
evidence rather than per-concurrency measurements.

## Security Observation

During the initial period in which the ALB allowed HTTP traffic from
0.0.0.0/0, unsolicited requests were observed in the application logs.

The requests targeted unrelated PHP and WordPress-style paths and received
HTTP 404 responses from Gotenberg.

Before the formal benchmark was executed, ALB ingress was restricted to the
operator's trusted static VPN address using a /32 security-group rule.

This reduced unrelated public traffic during the benchmark and provided a
cleaner test environment.

## Interpretation

The single-task ECS baseline demonstrates that increasing client concurrency
does not translate indefinitely into greater processing capacity.

For Chromium, useful throughput gains occurred primarily up to approximately
concurrency 4. Beyond this point, additional concurrency mainly increased
latency while throughput remained near 2.5-2.7 RPS.

For LibreOffice, useful throughput gains occurred primarily up to concurrency
4-6. Higher concurrency produced little additional throughput while increasing
tail latency.

CPU utilization reached 99.96% during the benchmark, while memory utilization
remained below 18%. Together with the latency and throughput behaviour, this
supports CPU capacity as the main observed resource constraint for the
single-task configuration.

## Conclusion

A single 1-vCPU, 2-GiB ECS Fargate task provides a clear capacity boundary
for the tested Gotenberg workloads.

Adding concurrency beyond the useful processing range causes request pressure
and higher latency without proportional throughput improvement.

The next experiment should therefore test whether adding independent Fargate
tasks increases aggregate throughput and reduces latency under a deliberately
saturated workload.

This establishes the hypothesis for horizontal scaling:

> If the observed throughput plateau is primarily caused by single-task CPU
> capacity, increasing the number of Fargate tasks should increase aggregate
> throughput when traffic is distributed across those tasks.
