#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

ALB="$(terraform -chdir=terraform/infrastructure output -raw alb_dns_name)"
TARGET="http://${ALB}"

HTML_FIXTURE="experiments/baseline/002-engine-characterization/fixtures/index.html"
LO_FIXTURE="experiments/baseline/002-engine-characterization/fixtures/sample.txt"

OUT="experiments/cloud/009-ecs-single-task-baseline/formal"
SAMPLER="tools/metrics/sample-gotenberg-queues.sh"

mkdir -p "$OUT"

RUN_START_MS="$(date +%s%3N)"
RUN_START_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

cat > "${OUT}/run-window.env" <<META
START_MS=${RUN_START_MS}
START_UTC=${RUN_START_UTC}
TARGET=${TARGET}
META

echo "OpsLens Experiment 009"
echo "Target: $TARGET"
echo "Started: $RUN_START_UTC"
echo

run_case() {
    local engine="$1"
    local concurrency="$2"
    local fixture="$3"

    local dir="${OUT}/${engine}/c${concurrency}"

    mkdir -p "$dir"

    # Do not overwrite a successfully completed case.
    if [[ -f "${dir}/summary.json" ]]; then
        echo "Skipping completed case: ${engine} c${concurrency}"
        return
    fi

    echo
    echo "========================================"
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
target=${TARGET}
started_ms=${case_start_ms}
started_utc=${case_start_utc}
META

    curl -fsS \
        "${TARGET}/prometheus/metrics" \
        > "${dir}/metrics-before.txt"

    bash "$SAMPLER" \
        "$TARGET" \
        "${dir}/queues.tsv" \
        0.25 &

    sampler_pid=$!

    # Allow queue sampling to establish its initial baseline.
    sleep 1

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

    # Capture a short post-load window.
    sleep 1

    kill "$sampler_pid" 2>/dev/null || true
    wait "$sampler_pid" 2>/dev/null || true

    curl -fsS \
        "${TARGET}/prometheus/metrics" \
        > "${dir}/metrics-after.txt" || true

    case_end_ms="$(date +%s%3N)"
    case_end_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    {
        echo "ended_ms=${case_end_ms}"
        echo "ended_utc=${case_end_utc}"
        echo "loadgen_exit_code=${loadgen_rc}"
        echo "queue_samples=$(($(wc -l < "${dir}/queues.tsv") - 1))"
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

echo
echo "========================================"
echo "Experiment 009 formal run complete"
echo "Started: ${RUN_START_UTC}"
echo "Ended:   ${RUN_END_UTC}"
echo "========================================"
