# Experiment 004 - Queue Formation Under Concurrent Load

## Objective

Observe how Gotenberg Chromium and LibreOffice behave when simultaneous
request demand exceeds available conversion capacity.

## Environment

- Gotenberg: 8.37.0
- Deployment: local Docker container
- Explicit CPU limit: none
- Explicit memory limit: none
- Engines tested independently
- Native Gotenberg queue metrics sampled during each workload

## LibreOffice Test

### Workload

- 20 concurrent requests
- Small plain-text conversion fixture
- Engine warmed before workload

### Results

- Successful requests: 20/20
- HTTP failures: 0
- Minimum client latency: approximately 0.092 seconds
- Maximum client latency: approximately 2.439 seconds
- Mean client latency: approximately 1.127 seconds
- Maximum observed request queue: 16

Observed queue samples showed the queue decreasing from high demand toward zero
as work completed.

### Interpretation

Concurrent demand exceeded the conversion capacity of the LibreOffice
instance.

The latency spread is consistent with serialized processing and queue wait.

The measured queue maximum is an observed sampled value, not necessarily the
instantaneous absolute maximum.

## Chromium Test

### Workload

- 12 concurrent requests
- Small HTML fixture
- Chromium warmed before workload
- waitDelay=2s intentionally added to make concurrency behaviour observable

### Results

- Successful requests: 12/12
- HTTP failures: 0
- Minimum client latency: approximately 2.221 seconds
- Maximum client latency: approximately 4.530 seconds
- Mean client latency: approximately 3.391 seconds
- Maximum observed queue: 12

Requests formed two clear completion bands:

- Approximately six requests completed around 2.2-2.3 seconds.
- Approximately six requests completed around 4.5 seconds.

### Interpretation

The measured latency bands are consistent with Chromium's configured
six-conversion concurrency limit.

When offered demand exceeded available Chromium conversion slots, requests
waited until capacity became available.

The synthetic waitDelay was used only to expose concurrency behaviour and
does not represent production request latency.

## Engineering Conclusion

Chromium and LibreOffice have materially different concurrency and queueing
behaviour.

This supports further evaluation of independent workload pools and scaling
policies rather than assuming both conversion engines should share identical
capacity controls.

No production sizing decision is made from this local experiment.

## Measurement Notes

An early queue CSV used an ISO timestamp containing a comma, which introduced
an extra CSV field and caused the initial LibreOffice queue analysis to read
the wrong column.

The sampler was corrected to use epoch-millisecond timestamps.
