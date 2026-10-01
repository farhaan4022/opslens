#!/usr/bin/env bash

set -euo pipefail

REQUESTS="${REQUESTS:-120}"
REPEATS="${REPEATS:-2}"

run_engine() {
    local engine="$1"
    local concurrency="$2"

    local memory_values=("unlimited" "1g" "512m" "256m")

    for memory in "${memory_values[@]}"; do

        for repeat in $(seq 1 "$REPEATS"); do

            label="mem-${memory}-r${repeat}"

            output="experiments/baseline/006-resource-constraints/${engine}/${label}"
            summary="${output}/loadgen/summary.json"
            state="${output}/container-state.txt"

            if [[ -f "$summary" || -f "$state" ]]; then
                echo "SKIP existing: $engine $label"
                continue
            fi

            echo
            echo "##############################################"
            echo "Engine:      $engine"
            echo "Memory:      $memory"
            echo "Repeat:      $repeat"
            echo "Concurrency: $concurrency"
            echo "Requests:    $REQUESTS"
            echo "##############################################"

            if tools/loadgen/run-resource-test.sh \
                "$label" \
                "$engine" \
                unlimited \
                "$concurrency" \
                "$REQUESTS" \
                "$memory"
            then
                echo "RESULT: completed normally"
            else
                rc=$?
                echo "RESULT: experiment returned exit code $rc"
                echo "$rc" > "${output}/experiment-exit-code.txt"
                echo "Continuing because failure may be experimental evidence."
            fi

            sleep 2
        done
    done
}

run_engine libreoffice 6
run_engine chromium 8
