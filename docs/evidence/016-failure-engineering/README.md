# Experiment 016 — Failure Engineering

This experiment evaluated how the OpsLens EKS workload behaves when individual
application components disappear unexpectedly.

## 016A — Chromium pod failure

A continuous one-request-per-second probe was sent through Envoy while the
single Chromium pod was deliberately deleted.

Results:

- Requests observed: 90
- Successful: 89
- Failed: 1
- Success rate: 98.89%
- Failure response: HTTP 503
- Pod deletion: 2026-10-03T11:13:09Z
- First failed request: 2026-10-03T11:13:11Z
- Successful traffic resumed: 2026-10-03T11:13:14Z
- Final application recovery check: successful

The Deployment recreated the Chromium pod automatically. The experiment shows
that Kubernetes self-healing restored the backend quickly, but self-healing did
not imply zero client-visible impact.

## 016B — Envoy gateway pod failure

The same continuous probe was used while the single Envoy gateway pod was
deliberately deleted.

Results:

- Requests observed: 90
- Successful: 86
- Failed: 4
- Success rate: 95.56%
- Failure type: connection-level failures/timeouts
- Envoy pod deletion: 2026-10-03T11:17:32Z
- First failed request: 2026-10-03T11:17:34Z
- Last failed request: 2026-10-03T11:17:40Z
- First successful request after failure: 2026-10-03T11:17:41Z
- Final application recovery check: successful

Gateway failure produced greater client impact than conversion-engine failure
because the single Envoy replica was itself on the request path.

## 016C — Worker-node evacuation

A previously completed EKS resilience test reduced the managed node group from
two workers to one. Workloads on the removed node were evicted and recreated
on the surviving worker, after which the application path recovered.

This earlier test is retained as qualitative node-level rescheduling evidence.
It is not presented as a request-level availability benchmark because an
equivalent continuous-probe measurement was not captured for that test.

## Finding

Kubernetes successfully recreated failed application components, but recovery
speed and client impact depended on the failure boundary. Backend failure
caused a brief 503, while failure of the single gateway replica caused a
longer connection-level interruption.

A production-hardening follow-up is to remove the Envoy single-replica failure
domain using gateway high availability and placement controls.
