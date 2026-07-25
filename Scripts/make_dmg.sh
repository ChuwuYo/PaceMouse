#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
APP_NAME=${APP_NAME:-PaceMouse}

if [[ -f "$ROOT/version.env" ]]; then
  source "$ROOT/version.env"
else
  MARKETING_VERSION=${MARKETING_VERSION:-0.1.0}
fi

APP="$ROOT/${APP_NAME}.app"
if [[ ! -d "$APP" ]]; then
  echo "ERROR: $APP not found. Run Scripts/package_app.sh first." >&2
  exit 1
fi

STAGE=$(mktemp -d)
trap "rm -rf '$STAGE'" EXIT

cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

DMG="$ROOT/${APP_NAME}-${MARKETING_VERSION}.dmg"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

echo "Created $DMG"
