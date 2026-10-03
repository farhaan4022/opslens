# Experiment 013 - CPU HPA vs Queue-Aware Autoscaling

## Objective

Compare Kubernetes CPU-based HorizontalPodAutoscaler with an
application-aware queue scaling strategy under the same Gotenberg engine
architecture, workload, replica limits, and fixed EKS node capacity.

The experiment asks two separate questions:

1. How quickly does each scaling signal detect overload and provision
   additional Ready capacity?
2. Does an earlier scaling decision translate into better request-level
   performance?

## Controlled Test Configuration

Both tests used the isolated engine architecture:

- Envoy gateway
- one Chromium Deployment
- one LibreOffice Deployment
- ClusterIP Services
- two EKS worker nodes already Ready before workload generation

Each Gotenberg engine started with one replica.

Per engine pod:

- CPU request: 500m
- CPU limit: 1 CPU
- memory request: 512 MiB
- memory limit: 2 GiB

Maximum replicas per engine:

- 2

Workload per engine:

- 600 measured requests
- concurrency: 12
- one warm-up request
- 60-second request timeout

Chromium and LibreOffice were stressed simultaneously.

The two-node EKS capacity was deliberately provisioned before the tests so
that the experiment measured pod-autoscaling behavior rather than EC2 node
provisioning latency.

---

## 013A - CPU HPA

CPU HPA configuration:

- minimum replicas: 1
- maximum replicas: 2
- target CPU utilization: 70% of the 500m CPU request
- scale-up stabilization: 0 seconds
- scale-down stabilization: 120 seconds

### CPU HPA Timing

Both HPAs first requested two replicas approximately 36.609 seconds after
the burst began.

Direct pod lifecycle sampling observed the additional Chromium and
LibreOffice pods Ready at approximately 55.148 seconds after burst start.

Before the scale decision:

- Chromium queue pressure was visible at approximately +2.326 seconds.
- LibreOffice queue pressure was visible at approximately +1.102 seconds.

Peak HPA utilization reached:

- Chromium: 198%
- LibreOffice: 155%

Because HPA CPU utilization is calculated relative to CPU requests,
approximately 1 CPU of consumption corresponds to approximately 200%
utilization for a pod requesting 500m.

### CPU HPA Request Results

Chromium:

- successful requests: 600
- failed requests: 0
- throughput: 3.905 RPS
- p50: 3.176 s
- p95: 3.978 s
- p99: 4.935 s
- workload wall time: 153.640 s

LibreOffice:

- successful requests: 600
- failed requests: 0
- throughput: 4.305 RPS
- p50: 2.663 s
- p95: 3.424 s
- p99: 3.500 s
- workload wall time: 139.378 s

Overall measured burst duration:

- 154.972 s

The experiment showed that CPU HPA functioned correctly, but application
queue pressure appeared more than thirty seconds before the CPU-based
control loop requested additional replicas.

---

## Queue-Aware Scaling Design

The queue-aware experiment used application-level Gotenberg queue metrics.

Policy:

- poll interval: 1 second
- scale-up threshold: queue depth >= 2
- scale-up confirmation: two consecutive samples
- minimum replicas: 1
- maximum replicas: 2
- scale-down: queue depth remains zero for 120 seconds

The controller was intentionally given only namespace-scoped permission to
read and patch Deployment scale subresources.

This is an experimental autoscaling controller rather than the final
production autoscaling architecture.

---

## Rejected Queue-Aware Trial

The first queue-aware run was rejected from the final comparison.

The queue-scaler Deployment initially used the default RollingUpdate
strategy. Restarting it temporarily allowed an old and new controller pod
to overlap.

Both controller instances had permission to modify the same Deployment
scale subresources.

As a result, one controller could change a Deployment while logs were being
captured from another controller. This produced an apparently missing
Chromium scale-up event even though Chromium had changed from one to two
replicas.

The problem was diagnosed using:

- absence of live HPA objects
- historical Kubernetes scaling event timestamps
- Deployment scaling events
- resource telemetry containing two queue-scaler pod identities

The experiment was rejected rather than interpreted as valid evidence.

The controller Deployment was changed to Recreate strategy and the
controller pod identity was added to every structured log record.

The benchmark runner was also changed to capture logs from one exact
controller pod.

A production controller running multiple replicas would normally use
leader election rather than relying only on Deployment Recreate behavior.

---

## 013B - Final Queue-Aware Run

The final run started with:

- no HPA resources
- one Chromium replica
- one LibreOffice replica
- exactly one queue-scaler controller
- two Ready EKS worker nodes

The same single controller generated all final scale-up and scale-down
events.

No queue-scaler error events were recorded.

### Queue Signal Timing

External queue sampling observed:

Chromium:

- first queue > 0: +0.314 s
- peak queue 12: +1.388 s

LibreOffice:

- first queue > 0: +0.895 s
- peak queue 12: +4.924 s

The controller itself observed:

Chromium:

- first queue > 0: +0.539 s
- first queue >= 2: +1.539 s
- scale decision: +2.548 s

LibreOffice:

- first queue > 0: +1.552 s
- first queue >= 2: +1.552 s
- scale decision: +2.571 s

### Pod Provisioning

Direct pod lifecycle sampling showed:

Chromium second replica:

- first observed: +3.189 s
- Ready: +5.300 s

LibreOffice second replica:

- first observed: +3.189 s
- Ready: +5.300 s

Deployment sampler timestamps are not used for precise provisioning latency
because each row is assembled using multiple sequential kubectl requests.
The row timestamp is captured before those requests complete and therefore
does not represent an atomic Kubernetes state snapshot.

Controller logs are used as the authoritative scale-decision timestamp,
while pod lifecycle observations are used as the authoritative readiness
timestamp.

### Queue-Aware Request Results

Chromium:

- successful requests: 600
- failed requests: 0
- throughput: 3.811 RPS
- p50: 3.176 s
- p95: 4.118 s
- p99: 4.851 s
- workload wall time: 157.454 s

LibreOffice:

- successful requests: 600
- failed requests: 0
- throughput: 6.021 RPS
- p50: 2.476 s
- p95: 3.336 s
- p99: 3.486 s
- workload wall time: 99.644 s

Overall measured burst duration:

- 158.165 s

---

## Direct Comparison

| Measurement | CPU HPA | Queue-aware | Difference |
|---|---:|---:|---:|
| Chromium scale decision | 36.609 s | 2.548 s | 34.061 s earlier |
| LibreOffice scale decision | 36.609 s | 2.571 s | 34.038 s earlier |
| Chromium second pod Ready | 55.148 s | 5.300 s | 49.848 s earlier |
| LibreOffice second pod Ready | 55.148 s | 5.300 s | 49.848 s earlier |
| Chromium throughput | 3.905 RPS | 3.811 RPS | -2.4% |
| Chromium p50 | 3.176 s | 3.176 s | approximately unchanged |
| Chromium p95 | 3.978 s | 4.118 s | +3.5% |
| Chromium p99 | 4.935 s | 4.851 s | -1.7% |
| LibreOffice throughput | 4.305 RPS | 6.021 RPS | +39.9% |
| LibreOffice p50 | 2.663 s | 2.476 s | -7.0% |
| LibreOffice p95 | 3.424 s | 3.336 s | -2.6% |
| LibreOffice p99 | 3.500 s | 3.486 s | -0.4% |
| Overall burst duration | 154.972 s | 158.165 s | +2.1% |
| Request failures | 0 | 0 | unchanged |

Queue-aware scaling reduced scale-decision latency by approximately 93%.

Additional Ready capacity became available approximately 50 seconds earlier
than in the CPU-HPA test.

---

## Scale-Down Validation

Chromium queue-aware workload wall time:

- approximately 157.454 seconds

Chromium scale-down:

- +277.573 seconds

Approximate zero-queue interval before scale-down:

- 120.119 seconds

LibreOffice queue-aware workload wall time:

- approximately 99.644 seconds

LibreOffice scale-down:

- +221.580 seconds

Approximate interval:

- 121.936 seconds

These observations are consistent with the configured 120-second sustained
zero-queue scale-down policy.

LibreOffice therefore scaled down before Chromium because its workload
finished substantially earlier.

---

## Interpretation

The application queue was a substantially earlier overload signal than CPU
utilization.

CPU HPA did not request additional replicas until approximately 36.6
seconds after workload start, while the queue-aware controller requested
scale-out at approximately 2.5 seconds.

This reduced control-loop decision latency by approximately 34 seconds and
made additional Ready engine capacity available roughly 50 seconds earlier.

However, earlier scaling did not improve every application metric.

LibreOffice benefited materially:

- throughput increased by approximately 39.9%
- median latency decreased by approximately 7.0%
- p95 decreased slightly
- workload completion time decreased substantially

Chromium did not show equivalent gains:

- throughput decreased slightly
- p50 was effectively unchanged
- p95 increased slightly
- p99 improved slightly

Because Chromium remained the longer-running workload, overall mixed-burst
completion time did not improve.

The result therefore does not support the simplistic conclusion that a
faster scaling signal automatically produces better end-to-end
performance.

Instead, the experiment demonstrates two separate properties:

1. Application queue depth can provide a materially faster overload signal
   than CPU utilization.
2. The value of earlier scaling still depends on workload characteristics,
   routing behavior, process concurrency, and how effectively new replicas
   absorb work.

---

## Production Design Limitation

The experimental controller retrieves Gotenberg queue metrics through each
engine's load-balanced Kubernetes Service.

This is reliable for the initial one-to-two scale-up decision because only
one backend exists before scale-out.

After multiple replicas exist, a Service scrape may reach any backend and
does not represent a true aggregate of all per-pod queues.

The experimental controller is therefore not proposed as the final
production autoscaling implementation.

The observability phase will introduce centralized Prometheus collection,
which can aggregate per-pod application metrics and provide a stronger
foundation for production queue-based autoscaling.

---

## Conclusion

Experiment 013 demonstrated that selecting an application-level overload
signal can dramatically improve autoscaling control-loop responsiveness.

Queue-aware scaling moved the scale decision from approximately 36.6
seconds to approximately 2.5 seconds and made additional Ready capacity
available about 50 seconds earlier.

The experiment also showed why autoscaling should not be evaluated only by
controller response time.

LibreOffice benefited strongly from the earlier capacity, while Chromium
did not. End-to-end performance therefore remained workload-dependent.

The experiment also exposed and corrected a real controller-operational
failure mode: multiple active scaler instances modifying the same scale
subresources without leader election.

These results motivate the next OpsLens phase: centralized observability,
metric aggregation, SLO definition, and production-oriented alerting.
