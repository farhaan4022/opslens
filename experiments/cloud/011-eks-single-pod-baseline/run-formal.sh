#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

OUT="experiments/cloud/011-eks-single-pod-baseline/formal"
mkdir -p "$OUT"

HTML_FIXTURE="experiments/baseline/002-engine-characterization/fixtures/index.html"
LO_FIXTURE="experiments/baseline/002-engine-characterization/fixtures/sample.txt"

QUEUE_SAMPLER="tools/metrics/sample-gotenberg-queues.sh"
RESOURCE_SAMPLER="tools/metrics/sample-k8s-pod-resources.sh"

EKS_ALB="$(
    kubectl get ingress gotenberg \
      -n opslens \
      -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
)"

TARGET="http://${EKS_ALB}"

RUN_START_MS="$(date +%s%3N)"
RUN_START_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

cat > "${OUT}/run-window.env" <<META
START_MS=${RUN_START_MS}
START_UTC=${RUN_START_UTC}
TARGET=${TARGET}
PLATFORM=EKS
REPLICAS=1
CPU_REQUEST=500m
CPU_LIMIT=1
MEMORY_REQUEST=512Mi
MEMORY_LIMIT=2Gi
REQUESTS_PER_CASE=60
META

kubectl get deployment gotenberg \
  -n opslens \
  -o json \
  > "${OUT}/deployment-before.json"

kubectl get pods \
  -n opslens \
  -l app=gotenberg \
  -o json \
  > "${OUT}/pods-before.json"

kubectl get nodes \
  -o wide \
  > "${OUT}/nodes.txt"

kubectl top node \
  > "${OUT}/node-resources-before.txt"

kubectl top pod \
  -n opslens \
  > "${OUT}/pod-resources-before.txt"

curl -fsS \
  "${TARGET}/prometheus/metrics" \
  > "${OUT}/metrics-before.txt"

run_case() {
    local engine="$1"
    local concurrency="$2"
    local fixture="$3"

    local dir="${OUT}/${engine}/c${concurrency}"
    mkdir -p "$dir"

    echo
    echo "========================================"
    echo "Platform:    EKS"
    echo "Replicas:    1"
    echo "Engine:      ${engine}"
    echo "Concurrency: ${concurrency}"
    echo "Requests:    60"
    echo "========================================"

    local case_start_ms
    local case_start_utc

    case_start_ms="$(date +%s%3N)"
    case_start_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    cat > "${dir}/case-metadata.txt" <<META
engine=${engine}
concurrency=${concurrency}
requests=60
warmup_requests=1
queue_sample_interval_s=0.25
resource_sample_interval_s=5
started_ms=${case_start_ms}
started_utc=${case_start_utc}
target=${TARGET}
META

    curl -fsS \
      "${TARGET}/prometheus/metrics" \
      > "${dir}/metrics-before.txt"

    bash "$QUEUE_SAMPLER" \
      "$TARGET" \
      "${dir}/queues.tsv" \
      0.25 &

    queue_pid=$!

    bash "$RESOURCE_SAMPLER" \
      opslens \
      app=gotenberg \
      "${dir}/pod-resources.tsv" \
      5 &

    resource_pid=$!

    sleep 2

    set +e

    .venv/bin/python tools/loadgen/loadgen.py \
      --engine "$engine" \
      --target "$TARGET" \
      --fixture "$fixture" \
      --requests 60 \
      --concurrency "$concurrency" \
      --warmup 1 \
      --timeout 60 \
      --output-dir "$dir"

    loadgen_rc=$?

    set -e

    sleep 2

    kill "$queue_pid" 2>/dev/null || true
    kill "$resource_pid" 2>/dev/null || true

    wait "$queue_pid" 2>/dev/null || true
    wait "$resource_pid" 2>/dev/null || true

    curl -fsS \
      "${TARGET}/prometheus/metrics" \
      > "${dir}/metrics-after.txt" || true

    kubectl get pods \
      -n opslens \
      -l app=gotenberg \
      -o json \
      > "${dir}/pods-after.json"

    case_end_ms="$(date +%s%3N)"
    case_end_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    {
        echo "ended_ms=${case_end_ms}"
        echo "ended_utc=${case_end_utc}"
        echo "loadgen_exit_code=${loadgen_rc}"
        echo "queue_samples=$(($(wc -l < "${dir}/queues.tsv") - 1))"
        echo "resource_samples=$(($(wc -l < "${dir}/pod-resources.tsv") - 1))"
    } >> "${dir}/case-metadata.txt"

    if [[ "$loadgen_rc" -ne 0 ]]; then
        echo "FAILED: ${engine} c${concurrency}"
        exit "$loadgen_rc"
    fi

    echo "Completed: ${engine} c${concurrency}"

    sleep 10
}

for concurrency in 1 2 4 6 8 12; do
    run_case \
      chromium \
      "$concurrency" \
      "$HTML_FIXTURE"
done

for concurrency in 1 2 4 6 8 12; do
    run_case \
      libreoffice \
      "$concurrency" \
      "$LO_FIXTURE"
done

RUN_END_MS="$(date +%s%3N)"
RUN_END_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

cat >> "${OUT}/run-window.env" <<META
END_MS=${RUN_END_MS}
END_UTC=${RUN_END_UTC}
META

kubectl get deployment gotenberg \
  -n opslens \
  -o json \
  > "${OUT}/deployment-after.json"

kubectl get pods \
  -n opslens \
  -l app=gotenberg \
  -o json \
  > "${OUT}/pods-after.json"

kubectl top node \
  > "${OUT}/node-resources-after.txt"

kubectl top pod \
  -n opslens \
  > "${OUT}/pod-resources-after.txt"

curl -fsS \
  "${TARGET}/prometheus/metrics" \
  > "${OUT}/metrics-after.txt"

echo
echo "========================================"
echo "Experiment 011 complete"
echo "Started: ${RUN_START_UTC}"
echo "Ended:   ${RUN_END_UTC}"
echo "========================================"
