#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
APP_NAME=${APP_NAME:-PaceMouse}

if [[ -f "$ROOT/version.env" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT/version.env"
else
  MARKETING_VERSION=${MARKETING_VERSION:-0.1.1}
fi

APP="$ROOT/${APP_NAME}.app"
if [[ ! -d "$APP" ]]; then
  echo "ERROR: $APP not found. Run Scripts/package_app.sh first." >&2
  exit 1
fi

GENERATE_APPCAST=${GENERATE_APPCAST:-"$ROOT/.build/artifacts/sparkle/Sparkle/bin/generate_appcast"}
if [[ ! -x "$GENERATE_APPCAST" ]]; then
  echo "ERROR: generate_appcast not found at $GENERATE_APPCAST (run swift package resolve)" >&2
  exit 1
fi

ARCHIVE_DIR=$(mktemp -d)
TMP_KEY=""
cleanup() {
  rm -rf "$ARCHIVE_DIR"
  if [[ -n "$TMP_KEY" ]]; then
    rm -f "$TMP_KEY"
  fi
}
trap cleanup EXIT

PRIVATE_KEY_FILE=${SPARKLE_PRIVATE_KEY_FILE:-"$ROOT/Secrets/sparkle_eddsa_private.pem"}
if [[ ! -f "$PRIVATE_KEY_FILE" ]]; then
  if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
    TMP_KEY=$(mktemp)
    printf '%s\n' "$SPARKLE_PRIVATE_KEY" > "$TMP_KEY"
    PRIVATE_KEY_FILE="$TMP_KEY"
  else
    echo "ERROR: Sparkle private key missing. Set SPARKLE_PRIVATE_KEY or Secrets/sparkle_eddsa_private.pem" >&2
    exit 1
  fi
fi

ZIP_NAME="${APP_NAME}-${MARKETING_VERSION}.zip"
ZIP_PATH="$ROOT/$ZIP_NAME"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP" "$ZIP_PATH"
cp "$ZIP_PATH" "$ARCHIVE_DIR/"

DOWNLOAD_PREFIX=${SPARKLE_DOWNLOAD_PREFIX:-"https://github.com/ChuwuYo/PaceMouse/releases/download/app-latest/"}
CHANNEL=${SPARKLE_CHANNEL:-${RELEASE_CHANNEL:-}}

ARGS=(
  --ed-key-file "$PRIVATE_KEY_FILE"
  --download-url-prefix "$DOWNLOAD_PREFIX"
)
if [[ -n "$CHANNEL" ]]; then
  ARGS+=(--channel "$CHANNEL")
  echo "Sparkle channel: $CHANNEL"
else
  echo "Sparkle channel: (stable / default)"
fi

"$GENERATE_APPCAST" "${ARGS[@]}" "$ARCHIVE_DIR"

APPCAST_SRC="$ARCHIVE_DIR/appcast.xml"
if [[ ! -f "$APPCAST_SRC" ]]; then
  echo "ERROR: appcast.xml was not generated" >&2
  exit 1
fi
cp "$APPCAST_SRC" "$ROOT/appcast.xml"
echo "Created $ZIP_PATH"
echo "Created $ROOT/appcast.xml"
