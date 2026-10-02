#!/usr/bin/env bash
set -u

NAMESPACE="${1:?namespace required}"
SELECTOR="${2:?label selector required}"
OUTPUT="${3:?output file required}"
INTERVAL="${4:-5}"

mkdir -p "$(dirname "$OUTPUT")"

printf "timestamp_ms\tpod\tcpu\tmemory\n" > "$OUTPUT"

while true; do
    timestamp="$(date +%s%3N)"

    line="$(
        kubectl top pod \
          -n "$NAMESPACE" \
          -l "$SELECTOR" \
          --no-headers \
          2>/dev/null \
        | head -1
    )"

    if [[ -n "$line" ]]; then
        pod="$(awk '{print $1}' <<< "$line")"
        cpu="$(awk '{print $2}' <<< "$line")"
        memory="$(awk '{print $3}' <<< "$line")"

        printf "%s\t%s\t%s\t%s\n" \
          "$timestamp" \
          "$pod" \
          "$cpu" \
          "$memory" \
          >> "$OUTPUT"
    fi

    sleep "$INTERVAL"
done
