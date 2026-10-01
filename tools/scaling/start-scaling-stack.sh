#!/usr/bin/env bash

set -euo pipefail

REPLICAS="${1:-1}"


cd tools/scaling


docker compose down \
    >/dev/null 2>&1 || true


docker compose up -d \
    --scale gotenberg="$REPLICAS"


echo
echo "Waiting for scaling stack..."


for i in $(seq 1 60)
do

    if curl -fsS \
        http://127.0.0.1:8080/health \
        >/dev/null 2>&1
    then

        echo "Scaling stack healthy"
        echo "Replicas: $REPLICAS"
        exit 0

    fi


    sleep 1

done


echo "Health check failed"

docker compose logs

exit 1

