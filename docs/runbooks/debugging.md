# OpsLens Debugging Runbook

This runbook captures recurring debugging patterns demonstrated during OpsLens.

## Pod Pending

1. `kubectl describe pod <pod>`
2. inspect scheduling events
3. compare pod **requests** with node allocatable/requested resources
4. do not confuse current CPU usage with scheduler placement decisions

OpsLens observed a Pending pod caused by `Insufficient CPU` even though instantaneous usage did not look high. The scheduler places pods using resource requests.

## CrashLoopBackOff

1. inspect `kubectl logs --previous`
2. inspect image ENTRYPOINT/CMD
3. inspect Kubernetes `command` and `args`
4. inspect exit code

OpsLens observed exit code `127` after Kubernetes `args` replaced the image command semantics and `tini` attempted to execute a flag.

## Multi-container pod OOM

Inspect per-container status rather than only the pod summary:

```bash
kubectl get pod <pod> -o jsonpath='{.status.containerStatuses}'
```

OpsLens observed a Grafana pod showing OOM symptoms where the actual OOM-killed container was the dashboard sidecar, not Grafana itself.

## ALB returns 503 after rollout

Check separately:

- Kubernetes readiness
- Service endpoints
- ALB target health
- controller reconciliation

A successful controller reconciliation does not mean the ALB target is instantly healthy. OpsLens observed a short target-health convergence period.

## Prometheus rule looks missing

Validate independently:

1. generated configuration
2. mounted rule file
3. `promtool`
4. reload success
5. evaluation timing

OpsLens saw valid rules appear after evaluation cycles rather than immediately after reload.

## GitOps says healthy but manual state changed briefly

Argo may reconcile drift faster than the Application status exposes an `OutOfSync` sample. Compare the manual mutation, transient live state, final desired state, and reconciliation outcome instead of requiring every intermediate UI status to be captured.
