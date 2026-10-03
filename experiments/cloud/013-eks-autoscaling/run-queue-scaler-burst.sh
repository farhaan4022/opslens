#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

OUT="experiments/cloud/013-eks-autoscaling/results/queue-aware"

rm -rf "$OUT"
mkdir -p "$OUT"

TARGET="http://$(
  kubectl get ingress gotenberg \
    -n opslens \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
)"

HTML_FIXTURE="experiments/baseline/002-engine-characterization/fixtures/index.html"
LO_FIXTURE="experiments/baseline/002-engine-characterization/fixtures/sample.txt"

PIDS=()

cleanup() {
  for pid in "${PIDS[@]:-}"; do
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  done

  PIDS=()
}

trap cleanup EXIT INT TERM


# ------------------------------------------------------------
# Reset experimental state
# ------------------------------------------------------------

kubectl scale \
  deployment/gotenberg-chromium \
  deployment/gotenberg-libreoffice \
  -n opslens \
  --replicas=1

kubectl rollout status deployment/gotenberg-chromium \
  -n opslens --timeout=180s

kubectl rollout status deployment/gotenberg-libreoffice \
  -n opslens --timeout=180s

# Restarting the scaler resets its in-memory experiment state.
kubectl rollout restart deployment/queue-scaler \
  -n opslens

kubectl rollout status deployment/queue-scaler \
  -n opslens \
  --timeout=180s

sleep 5


# ------------------------------------------------------------
# Starting state
# ------------------------------------------------------------

date --iso-8601=seconds > "$OUT/start-time.txt"

kubectl get nodes -o wide \
  > "$OUT/nodes-before.txt"

kubectl top nodes \
  > "$OUT/node-usage-before.txt"

kubectl get deployment,pods \
  -n opslens \
  -o wide \
  > "$OUT/architecture-before.txt"

aws eks describe-nodegroup \
  --cluster-name opslens-eks \
  --nodegroup-name opslens-general \
  --region ap-south-1 \
  --profile opslens \
  --query 'nodegroup.scalingConfig' \
  --output json \
  > "$OUT/nodegroup-scaling-config.json"


# ------------------------------------------------------------
# Stream custom-scaler events
# ------------------------------------------------------------

# Experiment guard: CPU HPA must not exist.
HPA_COUNT="$(
  kubectl get hpa     -n opslens     --no-headers 2>/dev/null   | wc -l
)"

if [[ "$HPA_COUNT" -ne 0 ]]; then
  echo "ERROR: HPA objects still exist in namespace opslens."
  kubectl get hpa -n opslens
  exit 1
fi

# Recreate strategy should guarantee one active controller.
SCALER_COUNT="$(
  kubectl get pod     -n opslens     -l app=queue-scaler     -o name   | wc -l
)"

if [[ "$SCALER_COUNT" -ne 1 ]]; then
  echo "ERROR: expected exactly one queue-scaler pod; found ${SCALER_COUNT}"
  kubectl get pods -n opslens -l app=queue-scaler -o wide
  exit 1
fi

SCALER_POD="$(
  kubectl get pod     -n opslens     -l app=queue-scaler     -o jsonpath='{.items[0].metadata.name}'
)"

echo "$SCALER_POD" > "$OUT/queue-scaler-pod.txt"

kubectl logs   -n opslens   "$SCALER_POD"   --since=10s   -f   > "$OUT/queue-scaler.log"   2>&1 &

PIDS+=("$!")


# ------------------------------------------------------------
# Deployment replica sampler
# ------------------------------------------------------------

sample_deployments() {

  printf "timestamp_ms\tdeployment\tspec_replicas\tready\tavailable\n" \
    > "$OUT/deployments.tsv"

  while true; do

    ts="$(date +%s%3N)"

    for deploy in gotenberg-chromium gotenberg-libreoffice; do

      spec="$(
        kubectl get deployment "$deploy" \
          -n opslens \
          -o jsonpath='{.spec.replicas}' \
          2>/dev/null || true
      )"

      ready="$(
        kubectl get deployment "$deploy" \
          -n opslens \
          -o jsonpath='{.status.readyReplicas}' \
          2>/dev/null || true
      )"

      available="$(
        kubectl get deployment "$deploy" \
          -n opslens \
          -o jsonpath='{.status.availableReplicas}' \
          2>/dev/null || true
      )"

      printf "%s\t%s\t%s\t%s\t%s\n" \
        "$ts" \
        "$deploy" \
        "${spec:-0}" \
        "${ready:-0}" \
        "${available:-0}" \
        >> "$OUT/deployments.tsv"

    done

    sleep 1
  done
}


# ------------------------------------------------------------
# Pod lifecycle sampler
# ------------------------------------------------------------

sample_pods() {

  printf "timestamp_ms\tpod\tphase\tready\tnode\tpod_ip\tcreated\n" \
    > "$OUT/pods.tsv"

  while true; do

    ts="$(date +%s%3N)"

    kubectl get pods \
      -n opslens \
      -l 'app in (gotenberg-chromium,gotenberg-libreoffice)' \
      --no-headers \
      -o custom-columns='NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,NODE:.spec.nodeName,IP:.status.podIP,CREATED:.metadata.creationTimestamp' \
      2>/dev/null \
    | while read -r pod phase ready node ip created; do

        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
          "$ts" \
          "$pod" \
          "$phase" \
          "$ready" \
          "$node" \
          "$ip" \
          "$created"

      done >> "$OUT/pods.tsv"

    sleep 1
  done
}


# ------------------------------------------------------------
# Resource sampler
# ------------------------------------------------------------

sample_resources() {

  printf "timestamp_ms\tpod\tcpu\tmemory\n" \
    > "$OUT/pod-resources.tsv"

  while true; do

    ts="$(date +%s%3N)"

    kubectl top pod \
      -n opslens \
      --no-headers \
      2>/dev/null \
    | awk -v ts="$ts" '
      $1 ~ /^(envoy-gateway|gotenberg-chromium|gotenberg-libreoffice|queue-scaler)-/ {
        print ts "\t" $1 "\t" $2 "\t" $3
      }
    ' >> "$OUT/pod-resources.tsv" || true

    sleep 2
  done
}


# ------------------------------------------------------------
# Queue samplers
# ------------------------------------------------------------

kubectl port-forward \
  -n opslens \
  service/gotenberg-chromium \
  3301:3000 \
  > "$OUT/chromium-port-forward.log" 2>&1 &

PIDS+=("$!")

kubectl port-forward \
  -n opslens \
  service/gotenberg-libreoffice \
  3302:3000 \
  > "$OUT/libreoffice-port-forward.log" 2>&1 &

PIDS+=("$!")

sleep 3

bash tools/metrics/sample-gotenberg-queues.sh \
  http://127.0.0.1:3301 \
  "$OUT/chromium-queues.tsv" \
  0.25 &

PIDS+=("$!")

bash tools/metrics/sample-gotenberg-queues.sh \
  http://127.0.0.1:3302 \
  "$OUT/libreoffice-queues.tsv" \
  0.25 &

PIDS+=("$!")


# ------------------------------------------------------------
# Start Kubernetes samplers
# ------------------------------------------------------------

sample_deployments &
PIDS+=("$!")

sample_pods &
PIDS+=("$!")

sample_resources &
PIDS+=("$!")

sleep 5


# ------------------------------------------------------------
# Workload
# ------------------------------------------------------------

BURST_START_MS="$(date +%s%3N)"
echo "$BURST_START_MS" > "$OUT/burst-start-ms.txt"

echo
echo "=========================================="
echo "Experiment 013B - Queue-aware scaling"
echo "Chromium:     600 requests @ concurrency 12"
echo "LibreOffice:  600 requests @ concurrency 12"
echo "=========================================="
echo

set +e

.venv/bin/python tools/loadgen/loadgen.py \
  --engine chromium \
  --target "$TARGET" \
  --fixture "$HTML_FIXTURE" \
  --requests 600 \
  --concurrency 12 \
  --warmup 1 \
  --timeout 60 \
  --output-dir "$OUT/chromium" \
  > "$OUT/chromium-run.log" 2>&1 &

CHR_PID=$!

.venv/bin/python tools/loadgen/loadgen.py \
  --engine libreoffice \
  --target "$TARGET" \
  --fixture "$LO_FIXTURE" \
  --requests 600 \
  --concurrency 12 \
  --warmup 1 \
  --timeout 60 \
  --output-dir "$OUT/libreoffice" \
  > "$OUT/libreoffice-run.log" 2>&1 &

LO_PID=$!

wait "$CHR_PID"
CHR_RC=$?

wait "$LO_PID"
LO_RC=$?

set -e

BURST_END_MS="$(date +%s%3N)"
echo "$BURST_END_MS" > "$OUT/burst-end-ms.txt"

cat "$OUT/chromium-run.log"
cat "$OUT/libreoffice-run.log"

echo
echo "Burst finished."
echo "Observing queue-aware scale-down for 180 seconds..."
echo

sleep 180


# ------------------------------------------------------------
# Final state
# ------------------------------------------------------------

date --iso-8601=seconds > "$OUT/end-time.txt"

kubectl get deployment,pods \
  -n opslens \
  -o wide \
  > "$OUT/architecture-after.txt"

kubectl top nodes \
  > "$OUT/node-usage-after.txt"

cleanup


if [[ "$CHR_RC" -ne 0 || "$LO_RC" -ne 0 ]]; then
  echo "One or more workloads returned non-zero status."
  exit 1
fi

echo
echo "=========================================="
echo "Experiment 013B queue-aware burst complete"
echo "Results: $OUT"
echo "=========================================="
