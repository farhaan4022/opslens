#!/usr/bin/env bash

set -euo pipefail

LABEL="${1:?label required}"
ENGINE="${2:?engine required}"
CPUS="${3:?CPU limit required, e.g. unlimited, 0.5, 1, 2}"
CONCURRENCY="${4:?concurrency required}"
REQUESTS="${5:-240}"
MEMORY="${6:-unlimited}"

IMAGE="gotenberg/gotenberg:8.37.0"
CONTAINER="opslens-gotenberg"

OUTPUT="experiments/baseline/006-resource-constraints/${ENGINE}/${LABEL}"

case "$ENGINE" in
    chromium)
        FIXTURE="experiments/baseline/002-engine-characterization/fixtures/index.html"
        ;;
    libreoffice)
        FIXTURE="experiments/baseline/002-engine-characterization/fixtures/sample.txt"
        ;;
    *)
        echo "Unsupported engine: $ENGINE" >&2
        exit 1
        ;;
esac

mkdir -p "$OUTPUT"

docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

RUN_ARGS=(
    docker run -d
    --name "$CONTAINER"
    -p 127.0.0.1:3000:3000
)

if [[ "$CPUS" != "unlimited" ]]; then
    RUN_ARGS+=(--cpus="$CPUS")
fi

if [[ "$MEMORY" != "unlimited" ]]; then
    RUN_ARGS+=(
        --memory="$MEMORY"
        --memory-swap="$MEMORY"
    )
fi

RUN_ARGS+=("$IMAGE")

echo
echo "=============================================="
echo "Experiment:  $LABEL"
echo "Engine:      $ENGINE"
echo "CPU limit:   $CPUS"
echo "Memory:      $MEMORY"
echo "Concurrency: $CONCURRENCY"
echo "Requests:    $REQUESTS"
echo "=============================================="

"${RUN_ARGS[@]}" > "$OUTPUT/container-id.txt"

healthy=0

for _ in $(seq 1 60); do
    if curl -fsS http://127.0.0.1:3000/health >/dev/null 2>&1; then
        healthy=1
        break
    fi

    sleep 1
done

if [[ "$healthy" -ne 1 ]]; then
    echo "Container failed health check" | tee "$OUTPUT/health-failure.txt"
    docker logs "$CONTAINER" > "$OUTPUT/container.log" 2>&1 || true
    exit 1
fi

docker inspect \
    --format 'nano_cpus={{.HostConfig.NanoCpus}} cpu_quota={{.HostConfig.CpuQuota}} cpu_period={{.HostConfig.CpuPeriod}} memory_bytes={{.HostConfig.Memory}}' \
    "$CONTAINER" \
    > "$OUTPUT/container-config.txt"

docker exec "$CONTAINER" cat /sys/fs/cgroup/cpu.max \
    > "$OUTPUT/cpu-max.txt" 2>/dev/null || true

docker exec "$CONTAINER" cat /sys/fs/cgroup/memory.max \
    > "$OUTPUT/memory-max.txt" 2>/dev/null || true

docker exec "$CONTAINER" cat /sys/fs/cgroup/memory.swap.max \
    > "$OUTPUT/memory-swap-max.txt" 2>/dev/null || true

docker exec "$CONTAINER" cat /sys/fs/cgroup/memory.events \
    > "$OUTPUT/memory-events-before.txt" 2>/dev/null || true

docker exec "$CONTAINER" cat /sys/fs/cgroup/cpu.stat \
    > "$OUTPUT/cpu-stat-before.txt" 2>/dev/null || true

tools/metrics/sample-container.sh \
    "$CONTAINER" \
    "$OUTPUT/resources.tsv" \
    0.25 &

SAMPLER_PID=$!

if python tools/loadgen/loadgen.py \
    --engine "$ENGINE" \
    --fixture "$FIXTURE" \
    --requests "$REQUESTS" \
    --concurrency "$CONCURRENCY" \
    --warmup 1 \
    --output-dir "$OUTPUT/loadgen"; then
    LOAD_EXIT=0
else
    LOAD_EXIT=$?
fi

printf '%s\n' "$LOAD_EXIT" > "$OUTPUT/loadgen-exit-code.txt"

kill "$SAMPLER_PID" >/dev/null 2>&1 || true
wait "$SAMPLER_PID" >/dev/null 2>&1 || true

docker exec "$CONTAINER" cat /sys/fs/cgroup/cpu.stat \
    > "$OUTPUT/cpu-stat-after.txt" 2>/dev/null || true

docker exec "$CONTAINER" cat /sys/fs/cgroup/memory.events \
    > "$OUTPUT/memory-events-after.txt" 2>/dev/null || true

docker inspect \
    --format 'status={{.State.Status}} oom_killed={{.State.OOMKilled}} exit_code={{.State.ExitCode}}' \
    "$CONTAINER" \
    > "$OUTPUT/container-state.txt"

docker stats "$CONTAINER" --no-stream \
    > "$OUTPUT/final-stats.txt" 2>/dev/null || true

exit "$LOAD_EXIT"
