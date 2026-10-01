#!/usr/bin/env bash
set -euo pipefail

REQUESTS="${REQUESTS:-120}"
REPEATS="${REPEATS:-3}"

run_case() {
    local repeat="$1"
    local arch="$2"
    local mode="$3"

    label="${arch}-${mode}-r${repeat}"

    if [[ -f \
        "experiments/baseline/007-engine-interference/formal/${label}/run-state.txt" \
    ]]; then
        echo "SKIP existing: $label"
        return
    fi

    echo
    echo "=============================================="
    echo "Repeat:       $repeat"
    echo "Architecture: $arch"
    echo "Mode:         $mode"
    echo "=============================================="

    tools/loadgen/run-interference-case.sh \
        "$arch" \
        "$mode" \
        "$label" \
        "$REQUESTS"

    sleep 2
}


for repeat in $(seq 1 "$REPEATS"); do

    if [[ "$repeat" == "1" ]]; then
        run_case "$repeat" shared chromium
        run_case "$repeat" shared libreoffice
        run_case "$repeat" shared mixed
        run_case "$repeat" isolated chromium
        run_case "$repeat" isolated libreoffice
        run_case "$repeat" isolated mixed

    elif [[ "$repeat" == "2" ]]; then
        run_case "$repeat" isolated mixed
        run_case "$repeat" isolated libreoffice
        run_case "$repeat" isolated chromium
        run_case "$repeat" shared mixed
        run_case "$repeat" shared libreoffice
        run_case "$repeat" shared chromium

    else
        run_case "$repeat" shared libreoffice
        run_case "$repeat" isolated chromium
        run_case "$repeat" shared mixed
        run_case "$repeat" isolated mixed
        run_case "$repeat" shared chromium
        run_case "$repeat" isolated libreoffice
    fi

done
