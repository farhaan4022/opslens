#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

OUT="experiments/cloud/010-ecs-horizontal-scaling/task2"
mkdir -p "$OUT"

ALB="$(terraform -chdir=terraform/infrastructure output -raw alb_dns_name)"
TARGET="http://${ALB}"

HTML_FIXTURE="experiments/baseline/002-engine-characterization/fixtures/index.html"
LO_FIXTURE="experiments/baseline/002-engine-characterization/fixtures/sample.txt"

TG_ARN="$(aws elbv2 describe-target-groups \
  --names opslens-gotenberg \
  --profile opslens \
  --region ap-south-1 \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)"

START_MS="$(date +%s%3N)"
START_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

cat > "${OUT}/run-window.env" <<META
START_MS=${START_MS}
START_UTC=${START_UTC}
TARGET=${TARGET}
TASK_COUNT=2
REQUESTS_PER_RUN=120
CONCURRENCY=12
REPEATS=3
META

aws ecs describe-services \
  --cluster opslens-cluster \
  --services opslens-gotenberg \
  --profile opslens \
  --region ap-south-1 \
  > "${OUT}/service-before.json"

aws elbv2 describe-target-health \
  --target-group-arn "$TG_ARN" \
  --profile opslens \
  --region ap-south-1 \
  > "${OUT}/targets-before.json"

run_engine() {
    local engine="$1"
    local fixture="$2"

    for repeat in 1 2 3; do
        dir="${OUT}/${engine}/run${repeat}"
        mkdir -p "$dir"

        echo
        echo "========================================"
        echo "Tasks:       2"
        echo "Engine:      ${engine}"
        echo "Repeat:      ${repeat}/3"
        echo "Requests:    120"
        echo "Concurrency: 12"
        echo "========================================"

        .venv/bin/python tools/loadgen/loadgen.py \
          --engine "$engine" \
          --target "$TARGET" \
          --fixture "$fixture" \
          --requests 120 \
          --concurrency 12 \
          --warmup 1 \
          --timeout 60 \
          --output-dir "$dir"

        sleep 10
    done
}

run_engine chromium "$HTML_FIXTURE"
run_engine libreoffice "$LO_FIXTURE"

END_MS="$(date +%s%3N)"
END_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

cat >> "${OUT}/run-window.env" <<META
END_MS=${END_MS}
END_UTC=${END_UTC}
META

aws ecs describe-services \
  --cluster opslens-cluster \
  --services opslens-gotenberg \
  --profile opslens \
  --region ap-south-1 \
  > "${OUT}/service-after.json"

aws elbv2 describe-target-health \
  --target-group-arn "$TG_ARN" \
  --profile opslens \
  --region ap-south-1 \
  > "${OUT}/targets-after.json"

echo
echo "Two-task test complete"
echo "Started: ${START_UTC}"
echo "Ended:   ${END_UTC}"
