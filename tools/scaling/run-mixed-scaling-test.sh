#!/usr/bin/env bash

set -euo pipefail


REPLICAS="${1:?replicas required}"

REQUESTS="${REQUESTS:-120}"
CONCURRENCY="${CONCURRENCY:-12}"


ROOT="experiments/baseline/008-scaling-capacity"

OUTPUT="${ROOT}/replicas-${REPLICAS}/mixed"

TARGET="http://127.0.0.1:8080"


CHROMIUM_FIXTURE="experiments/baseline/002-engine-characterization/fixtures/index.html"

LIBREOFFICE_FIXTURE="experiments/baseline/002-engine-characterization/fixtures/sample.txt"


mkdir -p \
    "$OUTPUT/chromium" \
    "$OUTPUT/libreoffice"


echo
echo "======================================"
echo "Mixed Scaling Experiment"
echo "Replicas:     $REPLICAS"
echo "Requests:     $REQUESTS per engine"
echo "Concurrency:  $CONCURRENCY"
echo "Target:       $TARGET"
echo "======================================"


python tools/loadgen/loadgen.py \
    --engine chromium \
    --target "$TARGET" \
    --requests "$REQUESTS" \
    --concurrency "$CONCURRENCY" \
    --fixture "$CHROMIUM_FIXTURE" \
    --output-dir "$OUTPUT/chromium" \
    > "$OUTPUT/chromium-output.log" \
    2>&1 &

CHROMIUM_PID=$!



python tools/loadgen/loadgen.py \
    --engine libreoffice \
    --target "$TARGET" \
    --requests "$REQUESTS" \
    --concurrency "$CONCURRENCY" \
    --fixture "$LIBREOFFICE_FIXTURE" \
    --output-dir "$OUTPUT/libreoffice" \
    > "$OUTPUT/libreoffice-output.log" \
    2>&1 &

LIBREOFFICE_PID=$!



set +e

wait "$CHROMIUM_PID"
CHROMIUM_EXIT=$?


wait "$LIBREOFFICE_PID"
LIBREOFFICE_EXIT=$?

set -e



cat > "$OUTPUT/run-state.txt" <<STATE
chromium_exit=$CHROMIUM_EXIT
libreoffice_exit=$LIBREOFFICE_EXIT
STATE


echo
echo "Mixed scaling test completed"

echo "Chromium exit:    $CHROMIUM_EXIT"
echo "LibreOffice exit: $LIBREOFFICE_EXIT"

