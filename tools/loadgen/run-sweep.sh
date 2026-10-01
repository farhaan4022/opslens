#!/usr/bin/env bash

set -euo pipefail

ENGINE="${1:?engine required}"
OUTPUT_ROOT="${2:?output directory required}"

REQUESTS="${REQUESTS:-60}"
REPEATS="${REPEATS:-3}"

case "$ENGINE" in
    chromium)
        FIXTURE="experiments/baseline/002-engine-characterization/fixtures/index.html"
        ;;
    libreoffice)
        FIXTURE="experiments/baseline/002-engine-characterization/fixtures/sample.txt"
        ;;
    *)
        echo "Unsupported engine: $ENGINE"
        exit 1
        ;;
esac

CONCURRENCY_LEVELS=(1 2 4 6 8 12)

mkdir -p "$OUTPUT_ROOT"

for concurrency in "${CONCURRENCY_LEVELS[@]}"; do
    for repeat in $(seq 1 "$REPEATS"); do

        output_dir="$OUTPUT_ROOT/c${concurrency}/run${repeat}"

        echo "=============================================="
        echo "Engine: $ENGINE"
        echo "Concurrency: $concurrency"
        echo "Repeat: $repeat"
        echo "=============================================="

        python tools/loadgen/loadgen.py \
            --engine "$ENGINE" \
            --fixture "$FIXTURE" \
            --requests "$REQUESTS" \
            --concurrency "$concurrency" \
            --warmup 1 \
            --output-dir "$output_dir"

        sleep 2

    done
done
