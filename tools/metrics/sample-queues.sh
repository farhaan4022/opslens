#!/usr/bin/env bash

set -u

OUTPUT="${1:?output CSV required}"
SAMPLES="${2:-100}"
INTERVAL="${3:-0.1}"

mkdir -p "$(dirname "$OUTPUT")"

echo "timestamp_ms,chromium_queue,libreoffice_queue" > "$OUTPUT"

for ((i=1; i<=SAMPLES; i++)); do
    timestamp=$(date +%s%3N)

    metrics=$(curl -sS http://localhost:3000/prometheus/metrics || true)

    chromium=$(printf '%s\n' "$metrics" |
        awk '$1=="gotenberg_chromium_requests_queue_size" {print $2; exit}')

    libreoffice=$(printf '%s\n' "$metrics" |
        awk '$1=="gotenberg_libreoffice_requests_queue_size" {print $2; exit}')

    echo "${timestamp},${chromium:-NA},${libreoffice:-NA}" >> "$OUTPUT"

    sleep "$INTERVAL"
done
