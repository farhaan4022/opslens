# Experiment 003 - Cold/Warm Behaviour and Engine Lifecycle

## Objective

Measure the difference between first-use and subsequent conversions and
observe whether Chromium and LibreOffice remain resident after work completes.

## Environment

- Gotenberg: 8.37.0
- Deployment: single local Docker container
- Explicit CPU limit: none
- Explicit memory limit: none
- Engines tested separately from fresh containers

## Chromium observations

Fresh container:

- Memory: approximately 7 MiB
- PIDs: approximately 11

Observed lifecycle after activation:

- ~30 seconds: approximately 156.8 MiB / 120 PIDs
- ~60 seconds: approximately 172.4 MiB / 122 PIDs
- ~120 seconds: approximately 176.6 MiB / 121 PIDs
- Chromium remained resident through the measured lifecycle.

Observed request timings included:

- Cold request: approximately 0.42-0.47 seconds
- Immediate warm request: approximately 0.094 seconds

These measurements demonstrate a local cold/warm effect but are not
statistically sufficient for a general performance claim.

## LibreOffice observations

Fresh container:

- Memory: approximately 6.9 MiB
- PIDs: approximately 11

After activation:

- Immediately after cold request: approximately 84.8 MiB / 21 PIDs
- Immediately after warm request: approximately 87.3 MiB / 21 PIDs
- ~30 seconds: approximately 87.3 MiB / 21 PIDs
- ~60 seconds: approximately 87.3 MiB / 21 PIDs
- ~120 seconds: approximately 86.8 MiB / 21 PIDs
- soffice.bin remained resident through the measured lifecycle.

Two local cold/warm pairs showed the same pattern:

Run 1:
- Cold: approximately 0.473 seconds
- Warm: approximately 0.102 seconds

Run 2:
- Cold: approximately 0.449 seconds
- Warm: approximately 0.092 seconds

The sample size is too small for a production latency claim.

## Interpretation

The fresh-container idle footprint is not representative of the warmed
operating state.

Both engines are lazy-started and retain substantial runtime state after
their first conversion.

Chromium and LibreOffice have materially different runtime characteristics.
Further experiments will determine how these differences affect queueing,
overload and scaling behaviour.

## Next Experiment

Generate concurrent load and directly observe request queue formation.
