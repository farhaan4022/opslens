#!/usr/bin/env bash

set -euo pipefail

IMAGE="gotenberg/gotenberg:8.37.0"
CONTAINER="opslens-shared"

OUT="experiments/baseline/007-engine-interference/shared-mixed-smoke"

CHROMIUM_FIXTURE="experiments/baseline/002-engine-characterization/fixtures/index.html"
LIBREOFFICE_FIXTURE="experiments/baseline/002-engine-characterization/fixtures/sample.txt"

mkdir -p "$OUT"

docker rm -f opslens-gotenberg "$CONTAINER" >/dev/null 2>&1 || true

docker run -d \
    --name "$CONTAINER" \
    --cpus=4 \
    --memory=1g \
    --memory-swap=1g \
    -p 127.0.0.1:3000:3000 \
    "$IMAGE" \
    > "$OUT/container-id.txt"

healthy=0

for _ in $(seq 1 60); do
    if curl -fsS \
        http://127.0.0.1:3000/health \
        >/dev/null 2>&1
    then
        healthy=1
        break
    fi

    sleep 1
done

if [[ "$healthy" -ne 1 ]]; then
    echo "Gotenberg failed health check"
    docker logs "$CONTAINER" > "$OUT/container.log" 2>&1 || true
    exit 1
fi

docker inspect \
    --format \
    'nano_cpus={{.HostConfig.NanoCpus}} memory_bytes={{.HostConfig.Memory}} memory_swap={{.HostConfig.MemorySwap}}' \
    "$CONTAINER" \
    > "$OUT/container-config.txt"

docker exec "$CONTAINER" cat /sys/fs/cgroup/cpu.max \
    > "$OUT/cpu-max.txt"

docker exec "$CONTAINER" cat /sys/fs/cgroup/memory.max \
    > "$OUT/memory-max.txt"

docker exec "$CONTAINER" cat /sys/fs/cgroup/memory.swap.max \
    > "$OUT/memory-swap-max.txt"

echo "Warming Chromium..."

python tools/loadgen/loadgen.py \
    --engine chromium \
    --fixture "$CHROMIUM_FIXTURE" \
    --requests 1 \
    --concurrency 1 \
    --warmup 0 \
    --output-dir "$OUT/warmup-chromium" \
    >/dev/null

echo "Warming LibreOffice..."

python tools/loadgen/loadgen.py \
    --engine libreoffice \
    --fixture "$LIBREOFFICE_FIXTURE" \
    --requests 1 \
    --concurrency 1 \
    --warmup 0 \
    --output-dir "$OUT/warmup-libreoffice" \
    >/dev/null

tools/metrics/sample-gotenberg-queues.sh \
    http://127.0.0.1:3000 \
    "$OUT/queues.tsv" \
    0.25 &

QUEUE_PID=$!

tools/metrics/sample-container.sh \
    "$CONTAINER" \
    "$OUT/resources.tsv" \
    0.25 &

RESOURCE_PID=$!

echo
echo "Starting concurrent Chromium + LibreOffice workload"
echo

python tools/loadgen/loadgen.py \
    --engine chromium \
    --fixture "$CHROMIUM_FIXTURE" \
    --requests 120 \
    --concurrency 8 \
    --warmup 0 \
    --output-dir "$OUT/chromium" \
    > "$OUT/chromium-console.log" 2>&1 &

CHROMIUM_PID=$!

python tools/loadgen/loadgen.py \
    --engine libreoffice \
    --fixture "$LIBREOFFICE_FIXTURE" \
    --requests 120 \
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

kill "$QUEUE_PID" >/dev/null 2>&1 || true
kill "$RESOURCE_PID" >/dev/null 2>&1 || true

wait "$QUEUE_PID" >/dev/null 2>&1 || true
wait "$RESOURCE_PID" >/dev/null 2>&1 || true

printf \
    "chromium_exit=%s\nlibreoffice_exit=%s\n" \
    "$CHROMIUM_EXIT" \
    "$LIBREOFFICE_EXIT" \
    > "$OUT/loadgen-exit-codes.txt"

docker inspect \
    --format \
    'status={{.State.Status}} oom_killed={{.State.OOMKilled}} exit_code={{.State.ExitCode}}' \
    "$CONTAINER" \
    > "$OUT/container-state.txt"

echo
echo "Smoke test complete."
echo "Chromium exit:    $CHROMIUM_EXIT"
echo "LibreOffice exit: $LIBREOFFICE_EXIT"
