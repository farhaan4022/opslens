#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"

if [[ "$MODE" != "shared" && "$MODE" != "isolated" ]]; then
    echo "Usage: $0 shared|isolated"
    exit 1
fi

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

BASE="experiments/cloud/012-eks-mixed-workload-isolation/formal/${MODE}"
mkdir -p "$BASE"

TARGET="http://$(
    kubectl get ingress gotenberg \
      -n opslens \
      -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
)"

HTML_FIXTURE="experiments/baseline/002-engine-characterization/fixtures/index.html"
LO_FIXTURE="experiments/baseline/002-engine-characterization/fixtures/sample.txt"

QUEUE_SAMPLER="tools/metrics/sample-gotenberg-queues.sh"

PIDS=()

cleanup() {
    for pid in "${PIDS[@]:-}"; do
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    done

    PIDS=()
}

trap cleanup EXIT INT TERM

sample_resources() {
    local output="$1"

    printf "timestamp_ms\tpod\tcpu\tmemory\n" > "$output"

    while true; do
        ts="$(date +%s%3N)"

        kubectl top pod \
          -n opslens \
          --no-headers \
          2>/dev/null \
        | awk -v ts="$ts" '
            $1 ~ /^(envoy-gateway|gotenberg-shared-control|gotenberg-chromium|gotenberg-libreoffice)-/ {
                print ts "\t" $1 "\t" $2 "\t" $3
            }
        ' >> "$output" || true

        sleep 5
    done
}

start_shared_queue_sampler() {
    local dir="$1"

    kubectl port-forward \
      -n opslens \
      service/gotenberg-shared-control \
      3300:3000 \
      >"${dir}/shared-port-forward.log" 2>&1 &

    pf_pid=$!
    PIDS+=("$pf_pid")

    sleep 2

    bash "$QUEUE_SAMPLER" \
      http://127.0.0.1:3300 \
      "${dir}/shared-queues.tsv" \
      0.25 &

    sampler_pid=$!
    PIDS+=("$sampler_pid")
}

start_isolated_queue_samplers() {
    local dir="$1"

    kubectl port-forward \
      -n opslens \
      service/gotenberg-chromium \
      3301:3000 \
      >"${dir}/chromium-port-forward.log" 2>&1 &

    chr_pf=$!
    PIDS+=("$chr_pf")

    kubectl port-forward \
      -n opslens \
      service/gotenberg-libreoffice \
      3302:3000 \
      >"${dir}/libreoffice-port-forward.log" 2>&1 &

    lo_pf=$!
    PIDS+=("$lo_pf")

    sleep 2

    bash "$QUEUE_SAMPLER" \
      http://127.0.0.1:3301 \
      "${dir}/chromium-queues.tsv" \
      0.25 &

    chr_sampler=$!
    PIDS+=("$chr_sampler")

    bash "$QUEUE_SAMPLER" \
      http://127.0.0.1:3302 \
      "${dir}/libreoffice-queues.tsv" \
      0.25 &

    lo_sampler=$!
    PIDS+=("$lo_sampler")
}

start_sampling() {
    local dir="$1"

    PIDS=()

    sample_resources "${dir}/pod-resources.tsv" &
    resource_pid=$!
    PIDS+=("$resource_pid")

    if [[ "$MODE" == "shared" ]]; then
        start_shared_queue_sampler "$dir"
    else
        start_isolated_queue_samplers "$dir"
    fi
}

stop_sampling() {
    cleanup
    trap cleanup EXIT INT TERM
}

run_engine() {
    local engine="$1"
    local out="$2"

    if [[ "$engine" == "chromium" ]]; then
        fixture="$HTML_FIXTURE"
    else
        fixture="$LO_FIXTURE"
    fi

    .venv/bin/python tools/loadgen/loadgen.py \
      --engine "$engine" \
      --target "$TARGET" \
      --fixture "$fixture" \
      --requests 120 \
      --concurrency 6 \
      --warmup 1 \
      --timeout 60 \
      --output-dir "$out"
}

run_solo() {
    local rep="$1"
    local engine="$2"

    dir="${BASE}/rep${rep}/${engine}-solo"
    mkdir -p "$dir"

    echo
    echo "=========================================="
    echo "MODE:        $MODE"
    echo "REPETITION:  $rep"
    echo "WORKLOAD:    ${engine}-solo"
    echo "REQUESTS:    120"
    echo "CONCURRENCY: 6"
    echo "=========================================="

    kubectl get pods -n opslens -o wide \
      > "${dir}/pods-before.txt"

    start_sampling "$dir"

    set +e
    run_engine "$engine" "${dir}/${engine}"
    rc=$?
    set -e

    sleep 3
    stop_sampling

    kubectl get pods -n opslens -o wide \
      > "${dir}/pods-after.txt"

    if [[ "$rc" -ne 0 ]]; then
        echo "FAILED: ${engine}-solo rep ${rep}"
        exit "$rc"
    fi

    sleep 15
}

run_mixed() {
    local rep="$1"

    dir="${BASE}/rep${rep}/mixed"
    mkdir -p "$dir"

    echo
    echo "=========================================="
    echo "MODE:        $MODE"
    echo "REPETITION:  $rep"
    echo "WORKLOAD:    mixed"
    echo "CHROMIUM:    120 @ c6"
    echo "LIBREOFFICE: 120 @ c6"
    echo "=========================================="

    kubectl get pods -n opslens -o wide \
      > "${dir}/pods-before.txt"

    start_sampling "$dir"

    set +e

    run_engine chromium "${dir}/chromium" \
      > "${dir}/chromium-run.log" 2>&1 &
    chr_pid=$!

    run_engine libreoffice "${dir}/libreoffice" \
      > "${dir}/libreoffice-run.log" 2>&1 &
    lo_pid=$!

    wait "$chr_pid"
    chr_rc=$?

    wait "$lo_pid"
    lo_rc=$?

    set -e

    cat "${dir}/chromium-run.log"
    cat "${dir}/libreoffice-run.log"

    sleep 3
    stop_sampling

    kubectl get pods -n opslens -o wide \
      > "${dir}/pods-after.txt"

    if [[ "$chr_rc" -ne 0 || "$lo_rc" -ne 0 ]]; then
        echo "FAILED: mixed workload rep ${rep}"
        exit 1
    fi

    sleep 15
}

echo "Experiment 012"
echo "Mode:   $MODE"
echo "Target: $TARGET"

kubectl get deployment,pods,service \
  -n opslens \
  -o wide \
  > "${BASE}/architecture-before.txt"

kubectl top node \
  > "${BASE}/node-before.txt"

for rep in 1 2 3; do
    run_solo "$rep" chromium
    run_solo "$rep" libreoffice
    run_mixed "$rep"
done

kubectl get deployment,pods,service \
  -n opslens \
  -o wide \
  > "${BASE}/architecture-after.txt"

kubectl top node \
  > "${BASE}/node-after.txt"

echo
echo "=========================================="
echo "Experiment 012 ${MODE} mode complete"
echo "=========================================="
