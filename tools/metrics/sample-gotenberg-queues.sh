#!/usr/bin/env bash

set -u

TARGET="${1:?target URL required}"
OUTPUT="${2:?output file required}"
INTERVAL="${3:-0.25}"

mkdir -p "$(dirname "$OUTPUT")"

printf "timestamp_ms\tchromium_queue\tlibreoffice_queue\n" > "$OUTPUT"

while true; do
    timestamp=$(date +%s%3N)

    metrics=$(curl -fsS \
        --max-time 2 \
        "${TARGET}/prometheus/metrics" \
        2>/dev/null) || break

    chromium=$(awk '
        $1 == "gotenberg_chromium_requests_queue_size" {
            print $2
            exit
        }
    ' <<< "$metrics")

    libreoffice=$(awk '
        $1 == "gotenberg_libreoffice_requests_queue_size" {
            print $2
            exit
        }
    ' <<< "$metrics")

    chromium="${chromium:-0}"
    libreoffice="${libreoffice:-0}"

    printf "%s\t%s\t%s\n" \
        "$timestamp" \
        "$chromium" \
        "$libreoffice" \
        >> "$OUTPUT"

    sleep "$INTERVAL"
done
