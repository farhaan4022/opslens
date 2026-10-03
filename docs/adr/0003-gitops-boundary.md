# ADR 0003 — Limit Argo CD to the Active Application Boundary

## Status

Accepted.

## Context

The repository contains active application manifests, legacy standalone Gotenberg resources, observability Helm values, and temporary validation resources. Recursively handing the entire `kubernetes/` tree to Argo CD would create ambiguous ownership and could re-enable intentionally retired resources.

## Decision

Use `kubernetes/kustomization.yaml` as the explicit GitOps entry point and include only the active OpsLens application resources.

## Consequences

- Argo owns the active application only.
- Helm retains ownership of observability and Argo itself.
- legacy and validation resources are not accidentally reconciled.
- ownership boundaries remain easy to explain and debug.
