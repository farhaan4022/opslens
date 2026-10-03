#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

OUT="experiments/cloud/013-eks-autoscaling/results/distribution-check"

rm -rf "$OUT"
mkdir -p "$OUT"

TARGET="http://$(
  kubectl get ingress gotenberg \
    -n opslens \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
)"

HTML_FIXTURE="experiments/baseline/002-engine-characterization/fixtures/index.html"
LO_FIXTURE="experiments/baseline/002-engine-characterization/fixtures/sample.txt"

echo "Target: $TARGET"

kubectl get pods \
  -n opslens \
  -l 'app in (gotenberg-chromium,gotenberg-libreoffice)' \
  -o wide \
  > "$OUT/pods-before.txt"

printf "timestamp_ms\tpod\tcpu\tmemory\n" \
  > "$OUT/pod-resources.tsv"

sample_resources() {
  while true; do

    ts="$(date +%s%3N)"

    kubectl top pod \
      -n opslens \
      --no-headers \
      2>/dev/null \
    | awk -v ts="$ts" '
      $1 ~ /^gotenberg-(chromium|libreoffice)-/ {
        print ts "\t" $1 "\t" $2 "\t" $3
      }
    ' >> "$OUT/pod-resources.tsv" || true

    sleep 1
  done
}

sample_resources &
SAMPLER_PID=$!

cleanup() {
  kill "$SAMPLER_PID" 2>/dev/null || true
  wait "$SAMPLER_PID" 2>/dev/null || true
}

trap cleanup EXIT INT TERM

sleep 5

echo
echo "Starting distribution-check mixed load..."
echo "Chromium:     360 requests @ concurrency 12"
echo "LibreOffice:  360 requests @ concurrency 12"
echo

.venv/bin/python tools/loadgen/loadgen.py \
  --engine chromium \
  --target "$TARGET" \
  --fixture "$HTML_FIXTURE" \
  --requests 360 \
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
  --requests 360 \
  --concurrency 12 \
  --warmup 1 \
  --timeout 60 \
  --output-dir "$OUT/libreoffice" \
  > "$OUT/libreoffice-run.log" 2>&1 &

LO_PID=$!

set +e

wait "$CHR_PID"
CHR_RC=$?

wait "$LO_PID"
LO_RC=$?

set -e

sleep 3

cleanup
trap - EXIT INT TERM

cat "$OUT/chromium-run.log"
cat "$OUT/libreoffice-run.log"

kubectl get pods \
  -n opslens \
  -l 'app in (gotenberg-chromium,gotenberg-libreoffice)' \
  -o wide \
  > "$OUT/pods-after.txt"

if [[ "$CHR_RC" -ne 0 || "$LO_RC" -ne 0 ]]; then
  echo "Distribution test workload failed."
  exit 1
fi

echo
echo "Distribution check complete."
