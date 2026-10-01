# Experiment 008 - Scaling Behaviour and Replica Capacity
## Results and Analysis

---

# 1. Objective

The objective of this experiment was to evaluate whether increasing the number of Gotenberg replicas improves document conversion capacity under increasing workload.

Previous experiments focused on:

- individual engine behaviour
- CPU and memory constraints
- workload interference

This experiment evaluates horizontal scaling behaviour before moving the architecture to AWS ECS/EKS.

The key question was:

> Does adding more Gotenberg instances increase throughput and reduce latency under a realistic mixed workload?

---

# 2. Experimental Architecture

The experiment used a local load-balanced architecture.
            Load Generator

                   |

            Nginx Load Balancer

                   |

    ---------------------------------

    |               |               |
Gotenberg-1    Gotenberg-2    Gotenberg-3

Nginx distributed incoming conversion requests between available Gotenberg instances.

---

# 3. Resource Configuration

## Single Replica

Gotenberg-1
CPU:
4 cores
Memory:
1 GiB

## Two Replicas

Gotenberg-1
Gotenberg-2
Total:
CPU:
8 cores
Memory:
2 GiB

## Three Replicas

Gotenberg-1
Gotenberg-2
Gotenberg-3
Total:
CPU:
12 cores
Memory:
3 GiB

---

# 4. Workload

Two conversion engines were tested simultaneously.

## Chromium

Purpose:

Evaluate scaling behaviour of browser-based HTML conversion.

Characteristics:

- CPU intensive
- higher resource sensitivity
- observed as the more demanding workload in previous experiments

---

## LibreOffice

Purpose:

Evaluate office-document conversion scaling behaviour.

Characteristics:

- different processing model compared with Chromium
- lower CPU sensitivity in previous resource experiments

---

# 5. Test Parameters

Each replica configuration used:

Requests:

600 Chromium requests
600 LibreOffice requests

Total:

1200 conversion requests

Concurrency:

48 concurrent requests per engine

Success criterion:

Successful conversions / Total requests

---

# 6. Results

## Chromium Mixed Workload

| Replicas | Success Rate | Throughput (req/s) | P50 | P95 | P99 |
|---|---|---|---|---|---|
|1|100%|12.959|3.603s|5.409s|6.329s|
|2|100%|13.104|3.592s|5.605s|6.392s|
|3|100%|12.770|3.646s|5.500s|6.303s|

---

## LibreOffice Mixed Workload

| Replicas | Success Rate | Throughput (req/s) | P50 | P95 | P99 |
|---|---|---|---|---|---|
|1|100%|6.278|6.051s|11.152s|11.537s|
|2|100%|6.167|6.189s|11.769s|12.012s|
|3|100%|6.233|6.286s|10.869s|11.056s|

---

# 7. Interpretation

Increasing replica count from one to three replicas did not produce proportional throughput improvement.

The results remained approximately stable across configurations.

This indicates that replica count was not the only capacity limitation in this environment.

Possible limiting factors include:

- physical host CPU availability
- local resource contention
- load generator capacity
- workload characteristics
- conversion engine processing limits

The experiment demonstrates that horizontal scaling should be evaluated against the actual system bottleneck rather than assumed to provide linear improvement.

---

# 8. Reliability Findings

All tested configurations achieved:

100% request success rate

No:

- container failures
- load generator failures
- conversion failures

were observed during the experiment.

---

# 9. SRE Interpretation

From an SRE perspective, this experiment validates capacity planning principles.

Adding replicas is only useful when the application layer is the limiting factor.

A production scaling strategy should consider:

- CPU utilisation
- memory pressure
- request latency
- queue depth
- saturation indicators

before increasing replica count.

---

# 10. Kubernetes/EKS Relevance

The experiment provides the baseline for future Kubernetes deployment.

In Kubernetes, the equivalent architecture becomes:

AWS Load Balancer
    |
Kubernetes Service
    |
Gotenberg Pods
    |
Horizontal Pod Autoscaler

Future experiments will validate:

- pod scaling behaviour
- resource requests
- resource limits
- readiness probes
- deployment behaviour
- observability

---

# 11. Limitation

The experiment was performed on a local Docker environment.

Results represent behaviour under:

- Gotenberg 8.37.0
- selected fixtures
- local hardware resources
- Nginx round-robin balancing

The results should not be interpreted as universal production sizing recommendations.

They provide evidence for designing and validating the later cloud deployment.



---

# 12. Lessons Learned

This experiment demonstrated that horizontal scaling is not automatically equivalent to performance improvement.

Increasing Gotenberg replicas provides additional processing capacity, but the overall system throughput depends on the complete request path:

Client
 |
Load Generator
 |
Load Balancer
 |
Application Replica
 |
Conversion Engine
 |
Host Resources

A production scaling decision should therefore be based on multiple signals:

- request throughput
- latency percentiles
- CPU utilisation
- memory utilisation
- queue depth
- error rate

The experiment also provided the baseline required before Kubernetes deployment.

In AWS ECS/EKS, replica scaling would be combined with:

- health checks
- readiness probes
- resource requests
- resource limits
- autoscaling policies
- monitoring dashboards

