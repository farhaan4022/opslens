#!/usr/bin/env bash

set -euo pipefail

CONTAINER="${1:-opslens-gotenberg}"
OUTPUT="${2:?output file required}"

mkdir -p "$(dirname "$OUTPUT")"

{
    echo "timestamp=$(date --iso-8601=seconds)"

    echo
    echo "=== DOCKER STATS ==="
    docker stats "$CONTAINER" --no-stream

    echo
    echo "=== PROCESS SNAPSHOT ==="
    docker top "$CONTAINER" -eo pid,ppid,user,%cpu,%mem,etime,args
} > "$OUTPUT"
