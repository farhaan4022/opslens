#!/usr/bin/env bash
set -euo pipefail

ARCH="${1:?architecture required: shared or isolated}"
MODE="${2:?mode required: chromium, libreoffice, or mixed}"
LABEL="${3:?output label required}"
REQUESTS="${4:-120}"

IMAGE="gotenberg/gotenberg:8.37.0"

ROOT="experiments/baseline/007-engine-interference/formal"
OUT="${ROOT}/${LABEL}"

CHROMIUM_FIXTURE="experiments/baseline/002-engine-characterization/fixtures/index.html"
LIBREOFFICE_FIXTURE="experiments/baseline/002-engine-characterization/fixtures/sample.txt"

SHARED_CONTAINER="opslens-shared"
CHROMIUM_CONTAINER="opslens-chromium"
LIBREOFFICE_CONTAINER="opslens-libreoffice"

PIDS=()

cleanup_samplers() {
    for pid in "${PIDS[@]:-}"; do
        kill "$pid" >/dev/null 2>&1 || true
    done

    for pid in "${PIDS[@]:-}"; do
        wait "$pid" >/dev/null 2>&1 || true
    done
}

trap cleanup_samplers EXIT

mkdir -p "$OUT"

docker rm -f \
    "$SHARED_CONTAINER" \
    "$CHROMIUM_CONTAINER" \
    "$LIBREOFFICE_CONTAINER" \
    >/dev/null 2>&1 || true


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


if [[ "$ARCH" == "shared" ]]; then

    CHROMIUM_TARGET="http://127.0.0.1:3000"
    LIBREOFFICE_TARGET="http://127.0.0.1:3000"

    docker run -d \
        --name "$SHARED_CONTAINER" \
        --cpus=4 \
        --memory=1g \
        --memory-swap=1g \
        -p 127.0.0.1:3000:3000 \
        "$IMAGE" \
        > "$OUT/shared-container-id.txt"

    wait_health "$CHROMIUM_TARGET" "Shared container"

    docker inspect \
        --format 'nano_cpus={{.HostConfig.NanoCpus}} memory_bytes={{.HostConfig.Memory}} memory_swap={{.HostConfig.MemorySwap}}' \
        "$SHARED_CONTAINER" \
        > "$OUT/shared-container-config.txt"

elif [[ "$ARCH" == "isolated" ]]; then

    CHROMIUM_TARGET="http://127.0.0.1:3001"
    LIBREOFFICE_TARGET="http://127.0.0.1:3002"

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

else
    echo "Unsupported architecture: $ARCH" >&2
    exit 1
fi


# Warm both engines for every condition so engine lifecycle state is comparable.

python tools/loadgen/loadgen.py \
    --target "$CHROMIUM_TARGET" \
    --engine chromium \
    --fixture "$CHROMIUM_FIXTURE" \
    --requests 1 \
    --concurrency 1 \
    --warmup 0 \
    --output-dir "$OUT/warmup-chromium" \
    >/dev/null

python tools/loadgen/loadgen.py \
    --target "$LIBREOFFICE_TARGET" \
    --engine libreoffice \
    --fixture "$LIBREOFFICE_FIXTURE" \
    --requests 1 \
    --concurrency 1 \
    --warmup 0 \
    --output-dir "$OUT/warmup-libreoffice" \
    >/dev/null


if [[ "$ARCH" == "shared" ]]; then

    tools/metrics/sample-gotenberg-queues.sh \
        "$CHROMIUM_TARGET" \
        "$OUT/queues.tsv" \
        0.25 &
    PIDS+=("$!")

    tools/metrics/sample-container.sh \
        "$SHARED_CONTAINER" \
        "$OUT/resources.tsv" \
        0.25 &
    PIDS+=("$!")

else

    tools/metrics/sample-gotenberg-queues.sh \
        "$CHROMIUM_TARGET" \
        "$OUT/chromium-queues.tsv" \
        0.25 &
    PIDS+=("$!")

    tools/metrics/sample-gotenberg-queues.sh \
        "$LIBREOFFICE_TARGET" \
        "$OUT/libreoffice-queues.tsv" \
        0.25 &
    PIDS+=("$!")

    tools/metrics/sample-container.sh \
        "$CHROMIUM_CONTAINER" \
        "$OUT/chromium-resources.tsv" \
        0.25 &
    PIDS+=("$!")

    tools/metrics/sample-container.sh \
        "$LIBREOFFICE_CONTAINER" \
        "$OUT/libreoffice-resources.tsv" \
        0.25 &
    PIDS+=("$!")
fi


CHROMIUM_EXIT="not-run"
LIBREOFFICE_EXIT="not-run"

if [[ "$MODE" == "chromium" || "$MODE" == "mixed" ]]; then

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
fi

if [[ "$MODE" == "libreoffice" || "$MODE" == "mixed" ]]; then

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
fi


set +e

if [[ "$MODE" == "chromium" || "$MODE" == "mixed" ]]; then
    wait "$CHROMIUM_PID"
    CHROMIUM_EXIT=$?
fi

if [[ "$MODE" == "libreoffice" || "$MODE" == "mixed" ]]; then
    wait "$LIBREOFFICE_PID"
    LIBREOFFICE_EXIT=$?
fi

set -e


cleanup_samplers
PIDS=()


printf \
    "architecture=%s\nmode=%s\nchromium_exit=%s\nlibreoffice_exit=%s\n" \
    "$ARCH" \
    "$MODE" \
    "$CHROMIUM_EXIT" \
    "$LIBREOFFICE_EXIT" \
    > "$OUT/run-state.txt"


if [[ "$ARCH" == "shared" ]]; then

    docker inspect \
        --format 'status={{.State.Status}} oom_killed={{.State.OOMKilled}} exit_code={{.State.ExitCode}}' \
        "$SHARED_CONTAINER" \
        > "$OUT/shared-container-state.txt"

else

    docker inspect \
        --format 'status={{.State.Status}} oom_killed={{.State.OOMKilled}} exit_code={{.State.ExitCode}}' \
        "$CHROMIUM_CONTAINER" \
        > "$OUT/chromium-container-state.txt"

    docker inspect \
        --format 'status={{.State.Status}} oom_killed={{.State.OOMKilled}} exit_code={{.State.ExitCode}}' \
        "$LIBREOFFICE_CONTAINER" \
        > "$OUT/libreoffice-container-state.txt"
fi

echo "Completed: $LABEL"
