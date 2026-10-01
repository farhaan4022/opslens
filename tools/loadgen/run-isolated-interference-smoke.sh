#!/usr/bin/env bash

set -euo pipefail

IMAGE="gotenberg/gotenberg:8.37.0"

CHROMIUM_CONTAINER="opslens-chromium"
LIBREOFFICE_CONTAINER="opslens-libreoffice"

CHROMIUM_TARGET="http://127.0.0.1:3001"
LIBREOFFICE_TARGET="http://127.0.0.1:3002"

REQUESTS="${REQUESTS:-120}"
LABEL="${LABEL:-isolated-mixed-smoke-120}"

OUT="experiments/baseline/007-engine-interference/${LABEL}"

CHROMIUM_FIXTURE="experiments/baseline/002-engine-characterization/fixtures/index.html"
LIBREOFFICE_FIXTURE="experiments/baseline/002-engine-characterization/fixtures/sample.txt"

mkdir -p "$OUT/chromium" "$OUT/libreoffice"

docker rm -f \
    opslens-shared \
    "$CHROMIUM_CONTAINER" \
    "$LIBREOFFICE_CONTAINER" \
    >/dev/null 2>&1 || true

docker run -d \
    --name "$CHROMIUM_CONTAINER" \
    --cpus=3 \
    --memory=768m \
    --memory-swap=768m \
    -p 127.0.0.1:3001:3000 \
    "$IMAGE" \
    > "$OUT/chromium-container-id.txt"

docker run -d \
    --name "$LIBREOFFICE_CONTAINER" \
    --cpus=1 \
    --memory=256m \
    --memory-swap=256m \
    -p 127.0.0.1:3002:3000 \
    "$IMAGE" \
    > "$OUT/libreoffice-container-id.txt"

wait_health() {
    local target="$1"
    local name="$2"

    for _ in $(seq 1 60); do
        if curl -fsS "$target/health" >/dev/null 2>&1; then
            echo "$name healthy"
            return 0
        fi

        sleep 1
    done

    echo "$name failed health check"
    return 1
}

wait_health "$CHROMIUM_TARGET" "Chromium container"
wait_health "$LIBREOFFICE_TARGET" "LibreOffice container"

docker inspect \
    --format 'nano_cpus={{.HostConfig.NanoCpus}} memory_bytes={{.HostConfig.Memory}} memory_swap={{.HostConfig.MemorySwap}}' \
    "$CHROMIUM_CONTAINER" \
    > "$OUT/chromium-container-config.txt"

docker inspect \
    --format 'nano_cpus={{.HostConfig.NanoCpus}} memory_bytes={{.HostConfig.Memory}} memory_swap={{.HostConfig.MemorySwap}}' \
    "$LIBREOFFICE_CONTAINER" \
    > "$OUT/libreoffice-container-config.txt"

echo "Warming Chromium..."

python tools/loadgen/loadgen.py \
    --target "$CHROMIUM_TARGET" \
    --engine chromium \
    --fixture "$CHROMIUM_FIXTURE" \
    --requests 1 \
    --concurrency 1 \
    --warmup 0 \
    --output-dir "$OUT/warmup-chromium" \
    >/dev/null

echo "Warming LibreOffice..."

python tools/loadgen/loadgen.py \
    --target "$LIBREOFFICE_TARGET" \
    --engine libreoffice \
    --fixture "$LIBREOFFICE_FIXTURE" \
    --requests 1 \
    --concurrency 1 \
    --warmup 0 \
    --output-dir "$OUT/warmup-libreoffice" \
    >/dev/null

tools/metrics/sample-gotenberg-queues.sh \
    "$CHROMIUM_TARGET" \
    "$OUT/chromium-queues.tsv" \
    0.25 &

CHROMIUM_QUEUE_PID=$!

tools/metrics/sample-gotenberg-queues.sh \
    "$LIBREOFFICE_TARGET" \
    "$OUT/libreoffice-queues.tsv" \
    0.25 &

LIBREOFFICE_QUEUE_PID=$!

tools/metrics/sample-container.sh \
    "$CHROMIUM_CONTAINER" \
    "$OUT/chromium-resources.tsv" \
    0.25 &

CHROMIUM_RESOURCE_PID=$!

tools/metrics/sample-container.sh \
    "$LIBREOFFICE_CONTAINER" \
    "$OUT/libreoffice-resources.tsv" \
    0.25 &

LIBREOFFICE_RESOURCE_PID=$!

echo
echo "Starting isolated concurrent workload"
echo

python tools/loadgen/loadgen.py \
    --target "$CHROMIUM_TARGET" \
    --engine chromium \
    --fixture "$CHROMIUM_FIXTURE" \
    --requests "$REQUESTS" \
    --concurrency 8 \
    --warmup 0 \
    --output-dir "$OUT/chromium" \
    > "$OUT/chromium-console.log" 2>&1 &

CHROMIUM_PID=$!

python tools/loadgen/loadgen.py \
    --target "$LIBREOFFICE_TARGET" \
    --engine libreoffice \
    --fixture "$LIBREOFFICE_FIXTURE" \
    --requests "$REQUESTS" \
    --concurrency 6 \
    --warmup 0 \
    --output-dir "$OUT/libreoffice" \
    > "$OUT/libreoffice-console.log" 2>&1 &

LIBREOFFICE_PID=$!

set +e

wait "$CHROMIUM_PID"
CHROMIUM_EXIT=$?

wait "$LIBREOFFICE_PID"
LIBREOFFICE_EXIT=$?

set -e

for pid in \
    "$CHROMIUM_QUEUE_PID" \
    "$LIBREOFFICE_QUEUE_PID" \
    "$CHROMIUM_RESOURCE_PID" \
    "$LIBREOFFICE_RESOURCE_PID"
do
    kill "$pid" >/dev/null 2>&1 || true
done

for pid in \
    "$CHROMIUM_QUEUE_PID" \
    "$LIBREOFFICE_QUEUE_PID" \
    "$CHROMIUM_RESOURCE_PID" \
    "$LIBREOFFICE_RESOURCE_PID"
do
    wait "$pid" >/dev/null 2>&1 || true
done

printf \
    "chromium_exit=%s\nlibreoffice_exit=%s\n" \
    "$CHROMIUM_EXIT" \
    "$LIBREOFFICE_EXIT" \
    > "$OUT/loadgen-exit-codes.txt"

docker inspect \
    --format 'status={{.State.Status}} oom_killed={{.State.OOMKilled}} exit_code={{.State.ExitCode}}' \
    "$CHROMIUM_CONTAINER" \
    > "$OUT/chromium-container-state.txt"

docker inspect \
    --format 'status={{.State.Status}} oom_killed={{.State.OOMKilled}} exit_code={{.State.ExitCode}}' \
    "$LIBREOFFICE_CONTAINER" \
    > "$OUT/libreoffice-container-state.txt"

echo
echo "Isolated smoke test complete."
echo "Chromium exit:    $CHROMIUM_EXIT"
echo "LibreOffice exit: $LIBREOFFICE_EXIT"
