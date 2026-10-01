#!/usr/bin/env bash

set -euo pipefail


REQUESTS="${REQUESTS:-120}"


run_test() {

    replicas="$1"
    engine="$2"


    echo
    echo "====================================="
    echo "Running"
    echo "Replicas: $replicas"
    echo "Engine:   $engine"
    echo "====================================="


    tools/scaling/run-scaling-test.sh \
        "$replicas" \
        "$engine"

    sleep 2

}


for replicas in 1 2 3
do

    for engine in chromium libreoffice
    do

        run_test "$replicas" "$engine"

    done

done

