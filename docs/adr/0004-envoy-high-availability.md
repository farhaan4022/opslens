# ADR 0004 — Run Two Envoy Gateway Replicas

## Status

Accepted after failure testing.

## Context

Experiment 016B deleted the only Envoy gateway pod during a 90-request probe. Four requests failed, producing a 95.56% success rate. The gateway was therefore a measured single point of failure.

## Decision

Run two Envoy replicas, prefer placement on different worker nodes, and add a PodDisruptionBudget with `minAvailable: 1`.

## Validation

The same failure class was retested after hardening. One Envoy pod was deleted during a 90-request run and all 90 requests succeeded.

## Consequences

- gateway availability improved in the controlled test
- extra baseline compute is consumed
- the result is not a universal guarantee against all outage classes
