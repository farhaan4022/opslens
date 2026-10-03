# Experiment 019 — Envoy Gateway Availability Hardening

## Objective

Validate whether removing the single-replica Envoy gateway failure domain reduces
request interruption during an Envoy pod failure.

## Previous finding

Experiment 016B tested deletion of the single Envoy gateway pod while a client
probe was running.

Result:

- Requests: 90
- Successful: 86
- Failed: 4
- Success rate: 95.56%

This identified the single Envoy replica as a gateway availability risk.

## Hardening change

The Envoy gateway configuration was changed to:

- 2 replicas
- preferred pod anti-affinity using `kubernetes.io/hostname`
- PodDisruptionBudget with `minAvailable: 1`
- Git-managed desired state reconciled through Argo CD

The two Envoy replicas were scheduled on separate EKS worker nodes.

## Failure experiment

A persistent client pod issued 90 requests to:

`http://envoy-gateway.opslens.svc.cluster.local:8080/version`

During the probe, one Envoy pod was deliberately deleted.

Deletion evidence:

- Victim: `envoy-gateway-59bb78bb96-cl784`
- Delete time: `12:41:42 UTC`

Kubernetes maintained the remaining Envoy replica while recreating the deleted
pod.

## Result

- Requests: 90
- Successful: 90
- Failed: 0
- Success rate: 100.00%
- Non-200 responses: 0

Final state:

- Envoy Deployment: 2/2 Ready
- Replicas distributed across both worker nodes
- PDB `minAvailable`: 1
- Allowed disruptions: 1

## Comparison

| Experiment | Gateway replicas | Requests | Successful | Failed | Success rate |
|---|---:|---:|---:|---:|---:|
| 016B baseline | 1 | 90 | 86 | 4 | 95.56% |
| 019B hardened | 2 | 90 | 90 | 0 | 100.00% |

In this controlled failure experiment, adding gateway redundancy eliminated the
request failures observed during the earlier single-replica test.

This is a bounded lab result and should not be interpreted as proof of universal
zero-downtime behavior under every failure mode.

## Evidence

- `019-envoy-ha-failure.log`
- `019-envoy-delete.log`
- `kubernetes/gateway/envoy.yaml`
