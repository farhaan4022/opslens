# Experiment 002 - Engine Characterization

## Objective

Observe the runtime behaviour of Chromium and LibreOffice independently
during their first document conversions.

## Configuration

- Gotenberg: 8.37.0
- Deployment: single local Docker container
- Explicit CPU limit: none
- Explicit memory limit: none
- Chromium fixture: small HTML document
- LibreOffice fixture: small plain-text document

## Results

### Chromium

- HTTP status: 200
- Client-observed duration: approximately 0.714 seconds
- Output: valid one-page PDF
- Post-conversion container memory: approximately 318.6 MiB
- Post-conversion PID count: 118
- Chromium subprocesses remained visible after request completion

### LibreOffice

- HTTP status: 200
- Client-observed duration: approximately 0.514 seconds
- Output: valid one-page PDF
- After both engines had been activated, container memory was approximately
  402.1 MiB with 124 PIDs.
- soffice.bin was visible after the LibreOffice conversion.

## Native Metrics Observed

Gotenberg exposed:

- gotenberg_chromium_requests_queue_size
- gotenberg_chromium_restarts_count
- gotenberg_libreoffice_requests_queue_size
- gotenberg_libreoffice_restarts_count

Both queues and restart counters were zero after the sequential low-load test.

## Measurement Limitation

The attempted streaming `docker stats` sampling produced only initial
placeholder values. The individual requests completed faster than the
sampling method could capture useful resource data.

Therefore, no claim is made about peak CPU or peak memory consumption from
this experiment.

Later workload experiments will use sustained and concurrent requests so
resource sampling occurs while conversion work is actively running.

## Interpretation

The approximately 9 MiB fresh idle footprint observed in Experiment 001
does not represent the operating footprint after conversion engines have
been activated.

Chromium and LibreOffice exhibit distinct subprocess behaviour, supporting
further investigation of workload isolation. This experiment alone does
not prove that separate deployment pools improve reliability or performance.

The Chromium and LibreOffice request durations must not be compared as a
performance ranking because different document types and rendering paths
were used.

## Next Experiment

Measure cold-start versus warm-request behaviour and determine how long
Chromium and LibreOffice subprocesses remain resident.
