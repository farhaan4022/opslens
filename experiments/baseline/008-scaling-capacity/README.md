# Experiment 008 - Scaling Behaviour and Replica Capacity

## Objective

Determine how increasing the number of Gotenberg replicas affects throughput,
latency, reliability, and resource efficiency under increasing workload.

The experiment evaluates horizontal scaling behaviour before moving the
architecture to AWS ECS/EKS.

---

## Background

Previous experiments evaluated a single Gotenberg instance.

Experiment 005 showed that increasing concurrency increases queueing and
latency.

Experiment 006 showed that resource constraints affect Chromium and
LibreOffice differently.

Experiment 007 showed that workload isolation can reduce interference between
conversion engines.

Production systems normally handle increasing demand through horizontal
scaling, where additional service instances are added behind a load balancer.

This experiment evaluates that behaviour locally.

---

## Hypothesis

Increasing the number of Gotenberg replicas should improve total throughput
because workload can be distributed across multiple independent workers.

However, improvement may not be linear because of:

- load distribution overhead
- client concurrency limits
- resource contention on the host machine
- workload characteristics

---

## Architectures Tested

### Single Replica

One Gotenberg instance:

Load Generator
       |
       |
 Gotenberg-1

Resources:

- CPU: 4 cores
- Memory: 1 GiB


### Two Replicas

         Gotenberg-1
Load Generator
         Gotenberg-2

Resources:

- Total CPU: 8 cores
- Total Memory: 2 GiB


### Three Replicas

         Gotenberg-1

Resources:

- Total CPU: 12 cores
- Total Memory: 3 GiB


---

## Workloads

The following workloads will be evaluated:

### Chromium

Purpose:

Measure scaling behaviour of CPU-sensitive browser conversion.

### LibreOffice

Purpose:

Measure scaling behaviour of office conversion workload.

### Mixed workload

Purpose:

Represent a realistic document conversion service.

---

## Metrics Collected

### Reliability

Success rate percentage.

Example:

100 successful requests / 100 requests

= 100% success rate


### Throughput

Requests completed per second.

Higher throughput indicates greater processing capacity.


### Latency Percentiles

Latency distribution will be measured.

P50:

Median user experience.

P95:

Latency experienced by slowest 5% users.

P99:

Worst-case tail latency.


### Resource Efficiency

Calculate:

- requests per CPU core
- requests per GB memory


---

## Interpretation

The results are local measurements using:

- Gotenberg 8.37.0
- selected fixtures
- local Docker environment

The results will be used as baseline evidence for Kubernetes/EKS deployment
decisions.

They should not be treated as universal production sizing values.

