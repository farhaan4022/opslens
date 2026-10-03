#!/usr/bin/env bash
set -Eeuo pipefail

AWS_PROFILE="${AWS_PROFILE:-opslens}"
NAMESPACE="${NAMESPACE:-opslens}"
LOCAL_PORT="${LOCAL_PORT:-18080}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

EXPERIMENT_ID="017a-$(date -u +%Y%m%dT%H%M%SZ)"
TMP_DIR="$(mktemp -d)"
PF_PID=""

cleanup() {
  if [[ -n "${PF_PID:-}" ]]; then
    kill "$PF_PID" >/dev/null 2>&1 || true
    wait "$PF_PID" >/dev/null 2>&1 || true
  fi

  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

for cmd in kubectl curl aws terraform sha256sum python3; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "ERROR: required command not found: $cmd" >&2
    exit 1
  }
done

HTML_FILE="$TMP_DIR/index.html"
PDF_FILE="$TMP_DIR/result.pdf"
DOWNLOADED_FILE="$TMP_DIR/result-downloaded.pdf"
HEAD_FILE="$TMP_DIR/head-object.json"
METADATA_FILE="$TMP_DIR/metadata.json"

echo "=== OpsLens Durable Conversion Validation ==="
echo "Experiment ID : $EXPERIMENT_ID"

RESULTS_BUCKET="$(
  terraform -chdir="$ROOT_DIR/terraform/infrastructure" \
    output -raw opslens_results_bucket_name
)"

if [[ -z "$RESULTS_BUCKET" ]]; then
  echo "ERROR: Terraform results bucket output is empty." >&2
  exit 1
fi

OBJECT_PREFIX="experiments/$EXPERIMENT_ID"
PDF_KEY="$OBJECT_PREFIX/result.pdf"
METADATA_KEY="$OBJECT_PREFIX/metadata.json"

cat > "$HTML_FILE" <<HTML
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>OpsLens Durable Validation</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      margin: 48px;
    }
    h1 {
      font-size: 28px;
    }
    code {
      font-size: 16px;
    }
  </style>
</head>
<body>
  <h1>OpsLens Durable Request Validation</h1>
  <p>This PDF was generated through Envoy and Gotenberg on EKS.</p>
  <p>Experiment:</p>
  <code>$EXPERIMENT_ID</code>
</body>
</html>
HTML

echo
echo "[1/8] Starting localhost-only Envoy port-forward..."

kubectl port-forward \
  -n "$NAMESPACE" \
  svc/envoy-gateway \
  "$LOCAL_PORT:8080" \
  >"$TMP_DIR/port-forward.log" 2>&1 &

PF_PID=$!

READY=false

for _ in $(seq 1 30); do
  if curl -fsS \
    --max-time 2 \
    "http://127.0.0.1:$LOCAL_PORT/version" \
    >/dev/null 2>&1
  then
    READY=true
    break
  fi

  if ! kill -0 "$PF_PID" >/dev/null 2>&1; then
    echo "ERROR: port-forward exited unexpectedly." >&2
    cat "$TMP_DIR/port-forward.log" >&2
    exit 1
  fi

  sleep 1
done

if [[ "$READY" != "true" ]]; then
  echo "ERROR: Envoy did not become reachable." >&2
  cat "$TMP_DIR/port-forward.log" >&2
  exit 1
fi

echo "      Envoy reachable."

echo
echo "[2/8] Converting HTML to PDF through Envoy..."

HTTP_STATUS="$(
  curl \
    -sS \
    --max-time 60 \
    -o "$PDF_FILE" \
    -w '%{http_code}' \
    -F "files=@$HTML_FILE;type=text/html" \
    "http://127.0.0.1:$LOCAL_PORT/forms/chromium/convert/html"
)"

if [[ "$HTTP_STATUS" != "200" ]]; then
  echo "ERROR: conversion returned HTTP $HTTP_STATUS" >&2
  exit 1
fi

echo "      HTTP status: $HTTP_STATUS"

echo
echo "[3/8] Validating generated PDF..."

PDF_MAGIC="$(head -c 5 "$PDF_FILE")"
PDF_SIZE="$(stat -c '%s' "$PDF_FILE")"

if [[ "$PDF_MAGIC" != "%PDF-" ]]; then
  echo "ERROR: output does not have a PDF signature." >&2
  exit 1
fi

if (( PDF_SIZE < 1000 )); then
  echo "ERROR: PDF is unexpectedly small: $PDF_SIZE bytes" >&2
  exit 1
fi

ORIGINAL_SHA="$(
  sha256sum "$PDF_FILE" | awk '{print $1}'
)"

echo "      PDF signature: PASS"
echo "      PDF bytes    : $PDF_SIZE"
echo "      SHA-256      : $ORIGINAL_SHA"

echo
echo "[4/8] Uploading PDF to durable S3 storage..."

aws s3 cp \
  "$PDF_FILE" \
  "s3://$RESULTS_BUCKET/$PDF_KEY" \
  --profile "$AWS_PROFILE" \
  --content-type application/pdf \
  --metadata "sha256=$ORIGINAL_SHA,experiment=$EXPERIMENT_ID" \
  --only-show-errors

echo "      Upload: PASS"
echo "      Object key: $PDF_KEY"

echo
echo "[5/8] Verifying stored S3 object..."

aws s3api head-object \
  --bucket "$RESULTS_BUCKET" \
  --key "$PDF_KEY" \
  --profile "$AWS_PROFILE" \
  > "$HEAD_FILE"

read -r STORED_SIZE STORED_SSE VERSION_ID STORED_SHA < <(
  python3 - "$HEAD_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    d = json.load(f)

print(
    d.get("ContentLength", ""),
    d.get("ServerSideEncryption", ""),
    d.get("VersionId", ""),
    d.get("Metadata", {}).get("sha256", ""),
)
PY
)

if [[ "$STORED_SIZE" != "$PDF_SIZE" ]]; then
  echo "ERROR: S3 ContentLength does not match original file size." >&2
  exit 1
fi

if [[ "$STORED_SSE" != "AES256" ]]; then
  echo "ERROR: expected AES256 S3 encryption, got: $STORED_SSE" >&2
  exit 1
fi

if [[ "$STORED_SHA" != "$ORIGINAL_SHA" ]]; then
  echo "ERROR: stored SHA-256 metadata does not match." >&2
  exit 1
fi

if [[ -z "$VERSION_ID" || "$VERSION_ID" == "null" ]]; then
  echo "ERROR: S3 object has no version ID." >&2
  exit 1
fi

echo "      Stored bytes : $STORED_SIZE"
echo "      Encryption   : $STORED_SSE"
echo "      Version ID   : present"
echo "      SHA metadata : MATCH"

echo
echo "[6/8] Downloading object to an independent file..."

aws s3 cp \
  "s3://$RESULTS_BUCKET/$PDF_KEY" \
  "$DOWNLOADED_FILE" \
  --profile "$AWS_PROFILE" \
  --only-show-errors

DOWNLOADED_SHA="$(
  sha256sum "$DOWNLOADED_FILE" | awk '{print $1}'
)"

DOWNLOADED_MAGIC="$(head -c 5 "$DOWNLOADED_FILE")"

if [[ "$DOWNLOADED_MAGIC" != "%PDF-" ]]; then
  echo "ERROR: downloaded object is not a PDF." >&2
  exit 1
fi

echo "      Download: PASS"
echo "      SHA-256 : $DOWNLOADED_SHA"

echo
echo "[7/8] Comparing original and durable copy..."

if [[ "$ORIGINAL_SHA" != "$DOWNLOADED_SHA" ]]; then
  echo "ERROR: downloaded SHA-256 differs from original." >&2
  exit 1
fi

echo "      Checksum match: PASS"

export EXPERIMENT_ID
export HTTP_STATUS
export PDF_SIZE
export ORIGINAL_SHA
export DOWNLOADED_SHA
export PDF_KEY
export VERSION_ID
export STORED_SSE

python3 - "$METADATA_FILE" <<'PY'
import json
import os
import sys
from datetime import datetime, timezone

metadata = {
    "experiment_id": os.environ["EXPERIMENT_ID"],
    "validated_at_utc": datetime.now(timezone.utc).isoformat(),
    "path": "Envoy -> Gotenberg Chromium -> PDF -> S3 -> download",
    "http_status": int(os.environ["HTTP_STATUS"]),
    "pdf_bytes": int(os.environ["PDF_SIZE"]),
    "original_sha256": os.environ["ORIGINAL_SHA"],
    "downloaded_sha256": os.environ["DOWNLOADED_SHA"],
    "checksum_match": os.environ["ORIGINAL_SHA"] == os.environ["DOWNLOADED_SHA"],
    "s3_object_key": os.environ["PDF_KEY"],
    "s3_version_id_present": bool(os.environ["VERSION_ID"]),
    "s3_server_side_encryption": os.environ["STORED_SSE"],
    "result": "PASS",
}

with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump(metadata, f, indent=2)
    f.write("\n")
PY

aws s3 cp \
  "$METADATA_FILE" \
  "s3://$RESULTS_BUCKET/$METADATA_KEY" \
  --profile "$AWS_PROFILE" \
  --content-type application/json \
  --only-show-errors

echo
echo "[8/8] Validation metadata uploaded."
echo
echo "============================================"
echo "DURABLE VALIDATION: PASS"
echo "============================================"
echo "Experiment       : $EXPERIMENT_ID"
echo "HTTP conversion  : PASS ($HTTP_STATUS)"
echo "PDF validation   : PASS"
echo "PDF bytes        : $PDF_SIZE"
echo "Original SHA256  : $ORIGINAL_SHA"
echo "S3 upload        : PASS"
echo "S3 encryption    : $STORED_SSE"
echo "S3 versioning    : PASS"
echo "S3 re-download   : PASS"
echo "Downloaded SHA256: $DOWNLOADED_SHA"
echo "Checksum match   : PASS"
echo "Metadata key     : $METADATA_KEY"
