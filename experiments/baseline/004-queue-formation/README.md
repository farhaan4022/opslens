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

Observed queue samples included:

- Queue depth 16: 9 samples
- Queue depth 8: 9 samples
- Queue depth 1: 9 samples
- Queue depth 0: 123 samples

### Interpretation

Concurrent demand exceeded the processing capacity of the LibreOffice
instance.

The latency spread is consistent with serialized conversion execution and
queue waiting.

The measured queue maximum of 16 is a sampled observation and should not be
interpreted as the instantaneous absolute maximum.

The original LibreOffice queue CSV contains an ISO-8601 timestamp whose
fractional-second separator introduced an additional comma-delimited field.
The raw evidence is preserved unchanged. Analysis accounted for this by
reading the LibreOffice queue value from the fourth field.

## Chromium Test

### Workload

- 12 concurrent requests
- Small HTML conversion fixture
- Engine warmed before workload
- waitDelay=2s used deliberately to hold conversion slots long enough to make
  concurrency behaviour observable

### Results

- Successful requests: 12/12
- HTTP failures: 0
- Minimum client latency: approximately 2.221 seconds
- Maximum client latency: approximately 4.530 seconds
- Mean client latency: approximately 3.391 seconds
- Maximum observed Chromium queue: 12

Observed Chromium queue samples:

- Queue depth 12: 17 samples
- Queue depth 6: 26 samples
- Queue depth 0: 107 samples

Request completion times formed two clear groups:

- Six requests completed at approximately 2.22-2.33 seconds.
- Six requests completed at approximately 4.47-4.53 seconds.

### Interpretation

The two latency groups are consistent with Chromium processing a limited
number of conversions concurrently and excess requests waiting for available
capacity.

The synthetic 2-second waitDelay was used only to expose the concurrency
boundary and must not be interpreted as representative production latency.

The queue metric is sampled periodically, so recorded queue values are
observations rather than guaranteed instantaneous maxima.

## Engineering Conclusion

Chromium and LibreOffice demonstrate materially different concurrency,
resource, and queueing behaviour.

LibreOffice exhibited serialized completion behaviour under concurrent
arrival, while Chromium processed multiple requests simultaneously before
queued work progressed.

These findings justify further testing of independent workload pools,
resource policies, and scaling strategies rather than assuming both engines
should share identical capacity controls.

No production sizing decision is made from this local experiment.

## Measurement Improvement

The initial queue sampler used an ISO timestamp that contained a comma,
causing incorrect CSV field parsing.

The sampler was corrected to use an epoch-millisecond timestamp:

timestamp_ms,chromium_queue,libreoffice_queue

Future experiments use the corrected format.

## Next Step

Build a reusable workload generator capable of controlling:

- engine
- request count
- concurrency
- workload fixture
- synthetic delay where applicable

The generator will calculate repeatable latency, throughput, success, and
failure measurements for later Docker and Kubernetes comparisons.
