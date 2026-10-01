#!/usr/bin/env bash
set -euo pipefail

REQUESTS="${REQUESTS:-120}"
REPEATS="${REPEATS:-3}"

run_engine() {
    local engine="$1"
    local concurrency="$2"

    local cpu_values=("unlimited" "4" "2" "1" "0.5")
    local cpu_labels=("unlimited" "4" "2" "1" "0p5")

    for i in "${!cpu_values[@]}"; do
        cpu="${cpu_values[$i]}"
        cpu_label="${cpu_labels[$i]}"

        for repeat in $(seq 1 "$REPEATS"); do
            label="cpu-${cpu_label}-r${repeat}"
            summary="experiments/baseline/006-resource-constraints/${engine}/${label}/loadgen/summary.json"

            # Preserve already completed valid runs.
            if [[ -f "$summary" ]]; then
                echo "SKIP existing: $engine $label"
                continue
            fi

            echo
            echo "##############################################"
            echo "$engine | CPU=$cpu | repeat=$repeat"
            echo "##############################################"

            tools/loadgen/run-resource-test.sh \
                "$label" \
                "$engine" \
                "$cpu" \
                "$concurrency" \
                "$REQUESTS"

            sleep 2
        done
    done
}

run_engine libreoffice 6
run_engine chromium 8
