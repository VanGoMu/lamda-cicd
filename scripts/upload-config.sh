#!/usr/bin/env bash
set -euo pipefail

: "${ARTIFACT_BUCKET:?Define ARTIFACT_BUCKET}"
: "${AWS_REGION:?Define AWS_REGION}"
VERSION="${1:?Uso: $0 VERSION}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY="config/${VERSION#v}.json"

aws s3 cp "$ROOT_DIR/config/example.json" "s3://${ARTIFACT_BUCKET}/${KEY}" \
  --region "$AWS_REGION" --sse AES256
printf 's3://%s/%s\n' "$ARTIFACT_BUCKET" "$KEY"
