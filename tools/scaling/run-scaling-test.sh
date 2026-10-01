#!/usr/bin/env bash

set -euo pipefail


REPLICAS="${1:?replica count required}"
ENGINE="${2:?engine required}"

REQUESTS="${REQUESTS:-120}"
CONCURRENCY="${CONCURRENCY:-12}"


ROOT="experiments/baseline/008-scaling-capacity"

OUTPUT="${ROOT}/replicas-${REPLICAS}/${ENGINE}"


TARGET="http://127.0.0.1:8080"


case "$ENGINE" in

chromium)

    FIXTURE="experiments/baseline/002-engine-characterization/fixtures/index.html"

    ;;

libreoffice)

    FIXTURE="experiments/baseline/002-engine-characterization/fixtures/sample.txt"

    ;;

*)

    echo "Unsupported engine"
    exit 1

    ;;

esac


mkdir -p "$OUTPUT"


echo
echo "======================================"
echo "Scaling Experiment"
echo "Replicas:     $REPLICAS"
echo "Engine:       $ENGINE"
echo "Requests:     $REQUESTS"
echo "Concurrency:  $CONCURRENCY"
echo "Target:       $TARGET"
echo "======================================"


python tools/loadgen/loadgen.py \
    --engine "$ENGINE" \
    --fixture "$FIXTURE" \
    --requests "$REQUESTS" \
    --concurrency "$CONCURRENCY" \
    --warmup 1 \
    --target "$TARGET" \
    --output-dir "$OUTPUT/loadgen"



docker ps \
    --filter name=opslens-scale \
    > "$OUTPUT/container-list.txt"



docker stats \
    --no-stream \
    $(docker ps \
        --filter name=opslens-scale \
        -q) \
    > "$OUTPUT/final-resource.txt" 2>/dev/null || true



echo

echo "Completed scaling test"

