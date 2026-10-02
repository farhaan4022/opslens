# Experiment 010 - ECS Horizontal Scaling

## Objective

Determine whether the capacity boundary observed in the single-task ECS
baseline was primarily caused by per-task compute capacity.

The experiment compares one and two identical ECS Fargate tasks under the
same deliberately saturated workload.

## Hypothesis

If the throughput plateau observed in Experiment 009 is primarily caused by
single-task CPU capacity, increasing the service from one to two identical
Fargate tasks should increase aggregate throughput and reduce request latency
when traffic is distributed through the same Application Load Balancer.

## Configuration

The application configuration remained unchanged between tests except for
the ECS desired task count.

- Platform: AWS ECS Fargate
- Region: ap-south-1
- Gotenberg: 8.37.0
- CPU per task: 1 vCPU
- Memory per task: 2 GiB
- Load balancer: Application Load Balancer
- Requests per run: 120
- Concurrency: 12
- Repeats: 3
- Chromium and LibreOffice tested independently

The one-task control and two-task experiment used the same client, fixtures,
request count, concurrency and application image.

## Results

### Chromium

| Tasks | Throughput RPS | p50 s | p95 s | p99 s |
|---:|---:|---:|---:|---:|
| 1 | 2.656 | 4.327 | 5.703 | 7.706 |
| 2 | 5.150 | 2.231 | 3.355 | 3.852 |

Moving from one task to two tasks increased Chromium throughput by 93.9%.

At the same time, p95 latency decreased by 41.2%.

The throughput result is close to the ideal doubling expected from adding a
second equivalent unit of compute capacity, although the experiment does not
assume perfectly linear scaling because load-balancing, runtime and network
overheads remain present.

### LibreOffice

| Tasks | Throughput RPS | p50 s | p95 s | p99 s |
|---:|---:|---:|---:|---:|
| 1 | 4.996 | 2.226 | 3.023 | 3.063 |
| 2 | 9.256 | 1.256 | 1.697 | 1.876 |

Moving from one task to two tasks increased LibreOffice throughput by 85.3%.

At the same time, p95 latency decreased by 43.9%.

The result demonstrates that additional independent task capacity materially
increased the service processing rate while reducing request waiting time.

## Resource Utilization

| Tasks | Metric | Average | Peak |
|---:|---|---:|---:|
| 1 | CPU utilization | 63.97% | 100.00% |
| 1 | Memory utilization | 16.12% | 18.87% |
| 2 | CPU utilization | 43.59% | 99.97% |
| 2 | Memory utilization | 11.35% | 16.14% |

CPU reached approximately 100% during both configurations.

The two-task service nevertheless processed substantially more requests per
second because the workload could be distributed across additional compute
capacity.

Average service CPU utilization was lower in the two-task run because more
reserved CPU capacity was available across the service and the workload
completed more quickly.

Memory remained comparatively low in both configurations and did not appear
to be the primary capacity constraint for these workloads.

## Interpretation

Experiment 009 showed that increasing concurrency against one Fargate task
eventually produced higher latency without proportional throughput gains.

Experiment 010 tested whether that plateau could be shifted by adding an
independent task.

The result supports that interpretation.

For Chromium, doubling task count produced a 93.9% increase in throughput.
For LibreOffice, throughput increased by 85.3%.

Both engines also experienced substantial reductions in p95 and p99 latency.

This indicates that the earlier throughput plateau was strongly associated
with available task-level compute capacity rather than a fixed client-side or
service-wide throughput ceiling.

## Operational Observation

Before the two-task test, the ECS service reported:

- Desired tasks: 2
- Running tasks: 2
- Pending tasks: 0

The ALB target group reported two healthy Gotenberg targets on port 3000.

This verified that both task instances were available to receive traffic
before the benchmark began.

## Limitations

The experiment used one workload shape, one AWS region, one task size and one
client location.

ALB request distribution was not measured on a per-request basis, and service
CPU metrics were collected at CloudWatch's one-minute resolution.

Therefore, the results demonstrate horizontal scaling behavior for this
specific controlled workload rather than claiming universal scaling
efficiency for all Gotenberg workloads.

## Conclusion

Horizontal scaling materially increased capacity.

Compared with one Fargate task:

- Chromium throughput increased by 93.9%.
- Chromium p95 latency decreased by 41.2%.
- LibreOffice throughput increased by 85.3%.
- LibreOffice p95 latency decreased by 43.9%.

The results support the hypothesis that CPU capacity at the individual task
level was a major contributor to the single-task throughput plateau.

This completes the bounded ECS performance phase of OpsLens.

The next phase moves the workload to Kubernetes/EKS, where scaling,
engine isolation, observability and failure recovery will be explored in
greater depth.
