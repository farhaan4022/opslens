#!/usr/bin/env bash
set -Eeuo pipefail

NAMESPACE="${NAMESPACE:-opslens}"
LOCAL_PORT="${LOCAL_PORT:-18080}"

EXPERIMENT_ID="017b-$(date -u +%Y%m%dT%H%M%SZ)"
TMP_DIR="$(mktemp -d)"
HTML_FILE="$TMP_DIR/index.html"
PF_PID=""

cleanup() {
  if [[ -n "${PF_PID:-}" ]]; then
    kill "$PF_PID" >/dev/null 2>&1 || true
    wait "$PF_PID" >/dev/null 2>&1 || true
  fi

  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

cat > "$HTML_FILE" <<HTML
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>OpsLens Webhook Validation</title>
</head>
<body>
  <h1>OpsLens asynchronous conversion</h1>
  <p>Experiment: $EXPERIMENT_ID</p>
</body>
</html>
HTML

echo "=== OpsLens Webhook Validation ==="
echo "Experiment ID : $EXPERIMENT_ID"

echo
echo "[1/5] Starting Envoy port-forward..."

kubectl port-forward \
  -n "$NAMESPACE" \
  svc/envoy-gateway \
  "$LOCAL_PORT:8080" \
  >"$TMP_DIR/port-forward.log" 2>&1 &

PF_PID=$!

for _ in $(seq 1 30); do
  if curl -fsS \
    --max-time 2 \
    "http://127.0.0.1:$LOCAL_PORT/version" \
    >/dev/null 2>&1
  then
    break
  fi

  sleep 1
done

echo "      Envoy reachable."

echo
echo "[2/5] Submitting asynchronous conversion..."

HTTP_STATUS="$(
  curl \
    -sS \
    --max-time 15 \
    -o /dev/null \
    -w '%{http_code}' \
    -H "Gotenberg-Trace: $EXPERIMENT_ID" \
    -H "Gotenberg-Webhook-Url: http://webhook-receiver.observability.svc.cluster.local:8080/callback" \
    -H "Gotenberg-Webhook-Events-Url: http://webhook-receiver.observability.svc.cluster.local:8080/events" \
    -F "files=@$HTML_FILE;type=text/html" \
    "http://127.0.0.1:$LOCAL_PORT/forms/chromium/convert/html"
)"

echo "      Initial HTTP status: $HTTP_STATUS"

if [[ "$HTTP_STATUS" != "204" ]]; then
  echo "ERROR: expected asynchronous HTTP 204, got $HTTP_STATUS" >&2
  exit 1
fi

echo
echo "[3/5] Waiting for callback..."

CALLBACK_JSON=""

for _ in $(seq 1 30); do
  CALLBACK_JSON="$(
    kubectl exec \
      -n observability \
      deploy/webhook-receiver \
      -- python -c '
import json
import sys
import urllib.request

experiment = sys.argv[1]

with urllib.request.urlopen(
    "http://127.0.0.1:8080/status",
    timeout=2,
) as response:
    data = json.load(response)

callback = data.get("callbacks", {}).get(experiment)

if callback:
    print(json.dumps(callback))
' "$EXPERIMENT_ID"
  )"

  if [[ -n "$CALLBACK_JSON" ]]; then
    break
  fi

  sleep 1
done

if [[ -z "$CALLBACK_JSON" ]]; then
  echo "ERROR: callback was not received within 30 seconds." >&2

  kubectl logs \
    -n observability \
    deploy/webhook-receiver \
    --tail=50 >&2 || true

  exit 1
fi

echo "      Callback received."

echo
echo "[4/5] Validating callback payload..."

python3 - "$EXPERIMENT_ID" "$CALLBACK_JSON" <<'PY'
import json
import sys

experiment = sys.argv[1]
callback = json.loads(sys.argv[2])

checks = {
    "trace_match": callback.get("gotenberg_trace") == experiment,
    "pdf_signature": callback.get("pdf_signature") is True,
    "content_type_pdf": callback.get("content_type", "").startswith("application/pdf"),
    "nonzero_bytes": callback.get("bytes", 0) > 1000,
    "sha256_present": len(callback.get("sha256", "")) == 64,
}

for name, result in checks.items():
    print(f"      {name:18} {'PASS' if result else 'FAIL'}")

if not all(checks.values()):
    raise SystemExit(1)

print()
print("      Callback bytes :", callback["bytes"])
print("      SHA-256        :", callback["sha256"])
print("      Gotenberg-Trace:", callback["gotenberg_trace"])
print("      traceparent    :", callback.get("traceparent", ""))
PY

echo
echo "[5/5] Result"
echo
echo "============================================"
echo "WEBHOOK VALIDATION: PASS"
echo "============================================"
echo "Experiment       : $EXPERIMENT_ID"
echo "Initial response : 204"
echo "Async callback   : PASS"
echo "PDF validation   : PASS"
echo "Trace correlation: PASS"
