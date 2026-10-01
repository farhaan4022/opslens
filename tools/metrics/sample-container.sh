#!/usr/bin/env bash

set -u

CONTAINER="${1:-opslens-gotenberg}"
OUTPUT="${2:?output file required}"
INTERVAL="${3:-0.25}"

mkdir -p "$(dirname "$OUTPUT")"

printf "timestamp_ms\tcpu_pct\tmemory_usage\tmemory_pct\tpids\n" > "$OUTPUT"

while true; do
    timestamp=$(date +%s%3N)

    stats=$(docker stats "$CONTAINER" \
        --no-stream \
        --format '{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}|{{.PIDs}}' \
        2>/dev/null) || break

    IFS='|' read -r cpu memory memory_pct pids <<< "$stats"

    printf "%s\t%s\t%s\t%s\t%s\n" \
        "$timestamp" \
        "$cpu" \
        "$memory" \
        "$memory_pct" \
        "$pids" \
        >> "$OUTPUT"

    sleep "$INTERVAL"
done
