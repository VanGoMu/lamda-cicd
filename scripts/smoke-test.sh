#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:?Define AWS_REGION}"
FUNCTION_NAME="${FUNCTION_NAME:?Define FUNCTION_NAME}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT_DIR/build"

if [[ -n "${API_URL:-}" ]]; then
  command -v curl >/dev/null || {
    printf 'curl es obligatorio para API_URL\n' >&2
    exit 1
  }
  response="$(curl --fail-with-body --silent --show-error \
    --header 'Content-Type: application/json' \
    --data '{"requestContext":{"requestId":"smoke-test"}}' \
    "$API_URL")"
  jq -e '.ok == true' <<<"$response" >/dev/null
  printf 'Smoke test API Gateway correcto para %s\n' "$API_URL"
  exit 0
fi

PAYLOAD="$ROOT_DIR/build/smoke-payload.json"
RESPONSE="$ROOT_DIR/build/smoke-response.json"
printf '%s\n' '{"requestContext":{"requestId":"smoke-test"}}' > "$PAYLOAD"

aws lambda invoke \
  --region "$AWS_REGION" \
  --function-name "$FUNCTION_NAME" \
  --payload "fileb://$PAYLOAD" \
  --cli-binary-format raw-in-base64-out \
  "$RESPONSE" >/dev/null

jq -e '.statusCode == 200 and (.body | fromjson | .ok == true)' "$RESPONSE" >/dev/null
printf 'Smoke test correcto para %s\n' "$FUNCTION_NAME"
