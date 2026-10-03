#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

OUT="experiments/cloud/013-eks-autoscaling/results/cpu-hpa"
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

echo "Experiment 013A - CPU HPA"
echo "Target: $TARGET"
echo

# ------------------------------------------------------------
# Capture starting architecture
# ------------------------------------------------------------

date --iso-8601=seconds > "$OUT/start-time.txt"

kubectl get nodes -o wide \
  > "$OUT/nodes-before.txt"

kubectl top nodes \
  > "$OUT/node-usage-before.txt"

kubectl get deployment,pods,hpa \
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
# HPA sampler
# ------------------------------------------------------------

sample_hpa() {
  printf "timestamp_ms\thpa\tcpu_pct\tcurrent_replicas\tdesired_replicas\n" \
    > "$OUT/hpa.tsv"

  while true; do
    ts="$(date +%s%3N)"

    for hpa in gotenberg-chromium gotenberg-libreoffice; do

      cpu="$(
        kubectl get hpa "$hpa" \
          -n opslens \
          -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' \
          2>/dev/null || true
      )"

      current="$(
        kubectl get hpa "$hpa" \
          -n opslens \
          -o jsonpath='{.status.currentReplicas}' \
          2>/dev/null || true
      )"

      desired="$(
        kubectl get hpa "$hpa" \
          -n opslens \
          -o jsonpath='{.status.desiredReplicas}' \
          2>/dev/null || true
      )"

      printf "%s\t%s\t%s\t%s\t%s\n" \
        "$ts" \
        "$hpa" \
        "${cpu:-NA}" \
        "${current:-NA}" \
        "${desired:-NA}" \
        >> "$OUT/hpa.tsv"

    done

    sleep 1
  done
}

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
          "$ts" "$pod" "$phase" "$ready" "$node" "$ip" "$created"
      done >> "$OUT/pods.tsv"

    sleep 1
  done
}

# ------------------------------------------------------------
# CPU / memory sampler
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
      $1 ~ /^(envoy-gateway|gotenberg-chromium|gotenberg-libreoffice)-/ {
        print ts "\t" $1 "\t" $2 "\t" $3
      }
    ' >> "$OUT/pod-resources.tsv" || true

    sleep 2
  done
}

# ------------------------------------------------------------
# Queue metric samplers
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

sample_hpa &
PIDS+=("$!")

sample_deployments &
PIDS+=("$!")

sample_pods &
PIDS+=("$!")

sample_resources &
PIDS+=("$!")

sleep 5

BURST_START_MS="$(date +%s%3N)"
echo "$BURST_START_MS" > "$OUT/burst-start-ms.txt"

echo
echo "=========================================="
echo "Starting simultaneous mixed burst"
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
echo "Observing HPA scale-down for 180 seconds..."
echo

sleep 180

date --iso-8601=seconds > "$OUT/end-time.txt"

kubectl get deployment,pods,hpa \
  -n opslens \
  -o wide \
  > "$OUT/architecture-after.txt"

kubectl top nodes \
  > "$OUT/node-usage-after.txt"

kubectl describe hpa gotenberg-chromium \
  -n opslens \
  > "$OUT/chromium-hpa-describe.txt"

kubectl describe hpa gotenberg-libreoffice \
  -n opslens \
  > "$OUT/libreoffice-hpa-describe.txt"

cleanup

if [[ "$CHR_RC" -ne 0 || "$LO_RC" -ne 0 ]]; then
  echo "One or more workloads returned non-zero status."
  exit 1
fi

echo
echo "=========================================="
echo "Experiment 013A CPU-HPA burst complete"
echo "Results: $OUT"
echo "=========================================="
