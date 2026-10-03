# Experiment 013A - CPU-Based Kubernetes HPA

## Objective

Measure how Kubernetes CPU-based HorizontalPodAutoscaler responds to a
sudden mixed Gotenberg workload and identify delays between workload
pressure, metric detection, scale-out, and additional capacity becoming
Ready.

## Configuration

Both engine deployments started with one replica.

Each engine pod:

- CPU request: 500m
- CPU limit: 1 CPU
- Memory request: 512 MiB
- Memory limit: 2 GiB

HPA configuration:

- minimum replicas: 1
- maximum replicas: 2
- target CPU utilization: 70%
- scale-up stabilization: 0 seconds
- scale-down stabilization: 120 seconds

Two EKS worker nodes were made Ready before the test so that this experiment
measured pod autoscaling rather than EC2 node provisioning latency.

## Workload

Chromium and LibreOffice were stressed simultaneously.

Each engine received:

- 600 measured requests
- concurrency 12
- one warm-up request
- 60-second request timeout

Total measured requests:

- 1,200

## Request Results

### Chromium

- Successful: 600
- Failed: 0
- Throughput: 3.905 RPS
- p50: 3.176 s
- p95: 3.978 s
- p99: 4.935 s
- max: 5.712 s

### LibreOffice

- Successful: 600
- Failed: 0
- Throughput: 4.305 RPS
- p50: 2.663 s
- p95: 3.424 s
- p99: 3.500 s
- max: 3.541 s

The mixed burst lasted approximately 155 seconds.

## HPA Response

The first recorded desired replica count of two occurred at approximately
36.6 seconds after the burst began.

The Deployment and pod samplers observed the second replicas becoming Ready
approximately 50-58 seconds after burst start.

The direct pod lifecycle sampler observed both new engine pods Ready at
approximately 55.1 seconds after burst start.

This means the main delay was not pod scheduling itself. A significant part
of the response time occurred before CPU-based HPA initiated scaling.

Because the samplers execute independent kubectl requests, individual
timestamps are approximate and should not be interpreted at sub-second
precision.

## CPU Behavior

Peak observed pod CPU:

- original Chromium pod: approximately 994m
- new Chromium pod: approximately 189m
- original LibreOffice pod: approximately 779m
- new LibreOffice pod: approximately 51m

Peak HPA utilization:

- Chromium: 198%
- LibreOffice: 155%

These percentages are measured relative to the 500m CPU request.

For example, approximately 1 CPU of actual Chromium consumption corresponds
to roughly 200% utilization relative to a 500m CPU request.

## Queue Pressure

Peak observed queue depth:

- Chromium: 12
- LibreOffice: 12

Both workloads therefore developed visible queue pressure before the
additional replicas could provide capacity.

Exact queue-signal timing relative to HPA scale-out is analyzed separately.

## Scale-Out Capacity Utilization

The additional replicas became Ready successfully, but they consumed much
less CPU than the original replicas during the measured burst.

This indicates that newly added capacity was not evenly utilized during the
test.

Possible causes include upstream connection reuse, request distribution
behavior through Envoy and the Kubernetes Service, or simply insufficient
remaining workload after the replicas became Ready.

This experiment does not establish the cause.

The load-distribution behavior should therefore be verified before drawing
strong conclusions about autoscaling efficiency.

## Scale Down

The HPA event history confirms that both engine Deployments were later
reduced from two replicas back to one after CPU utilization dropped below
the target.

This is consistent with the configured scale-down stabilization behavior.

## Interpretation

CPU-based HPA functioned correctly:

1. workload pressure increased CPU utilization;
2. CPU utilization exceeded the 70% target;
3. HPA increased the desired replica count from one to two;
4. Kubernetes created and scheduled additional pods;
5. the new pods became Ready;
6. both workloads completed without request failures;
7. HPA later returned both Deployments to one replica.

However, scale-out was reactive.

Approximately 36 seconds elapsed before the first observed HPA scale-out
decision, and additional pods were not Ready until roughly 50-58 seconds
after workload start.

During that interval both Gotenberg queues reached a peak depth of 12.

This provides the motivation for testing queue-aware scaling: queue pressure
may expose overload earlier than CPU metrics and could potentially request
capacity before the CPU HPA reacts.

The next experiment must use the same workload, replica limits, node
capacity, and routing architecture so that the scaling signal is the main
variable.
