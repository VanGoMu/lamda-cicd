#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?Uso: $0 VERSION}"
[[ "$VERSION" =~ ^(v)?[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  printf 'Version no valida: %s\n' "$VERSION" >&2
  exit 1
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/package"
OUTPUT="$ROOT_DIR/build/lambda-${VERSION#v}.zip"
PYTHON="${PYTHON:-python3}"
rm -rf "$BUILD_DIR" "$OUTPUT"
mkdir -p "$BUILD_DIR"

"$PYTHON" -m pip install --disable-pip-version-check --no-cache-dir \
  --requirement "$ROOT_DIR/requirements.txt" --target "$BUILD_DIR" >/dev/null
cp -R "$ROOT_DIR/src/app" "$BUILD_DIR/"

(
  cd "$BUILD_DIR"
  zip -qr "$OUTPUT" . \
    -x '*/__pycache__/*' '*.pyc' 'tests/*' 'config/*' '.env*'
)

if unzip -l "$OUTPUT" | grep -E \
  '^[[:space:]]*[0-9]+[[:space:]]+.*[[:space:]](config/|tests/|\.env)' >/dev/null; then
  printf 'El ZIP contiene archivos prohibidos\n' >&2
  exit 1
fi
printf '%s\n' "$OUTPUT"
