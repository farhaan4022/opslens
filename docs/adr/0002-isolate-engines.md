# ADR 0002 — Isolate Chromium and LibreOffice Workloads

## Status

Accepted.

## Context

Local and EKS mixed-load experiments showed that Chromium and LibreOffice have materially different resource behavior and interfere with each other when they share a runtime boundary.

## Decision

Run Chromium and LibreOffice as independent Kubernetes Deployments and Services behind Envoy path-based routing.

## Consequences

Positive:

- independent resources and scaling
- clearer queue signals
- reduced cross-engine interference
- improved failure isolation

Trade-off:

- additional Kubernetes objects and routing complexity
- isolation does not guarantee higher aggregate throughput under every load shape
