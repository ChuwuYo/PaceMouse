#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
APP_NAME=${APP_NAME:-PaceMouse}
BG_PNG="$ROOT/Scripts/dmg_assets/background.png"
BG_TIFF="$ROOT/Scripts/dmg_assets/background.tiff"
BG_GEN="$ROOT/Scripts/dmg_assets/generate_background.swift"

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

echo "Generating DMG background…"
swift "$BG_GEN" "$BG_PNG"
test -f "$BG_PNG"
test -f "$BG_TIFF"

DMG="$ROOT/${APP_NAME}-${MARKETING_VERSION}.dmg"
rm -f "$DMG"

STAGE=$(mktemp -d)
RW_DMG=""
VOL="/Volumes/$APP_NAME"
cleanup() {
  hdiutil detach "$VOL" -quiet 2>/dev/null || true
  [[ -n "$RW_DMG" ]] && rm -f "$RW_DMG"
  rm -rf "$STAGE"
}
trap cleanup EXIT

cp -R "$APP" "$STAGE/"

if command -v create-dmg >/dev/null 2>&1; then
  attempt=1
  while true; do
    if create-dmg \
      --volname "$APP_NAME" \
      --background "$BG_PNG" \
      --window-pos 200 160 \
      --window-size 640 400 \
      --icon-size 96 \
      --icon "$APP_NAME.app" 160 200 \
      --hide-extension "$APP_NAME.app" \
      --app-drop-link 480 200 \
      --no-internet-enable \
      --overwrite \
      --hdiutil-retries 10 \
      --applescript-sleep-duration 8 \
      "$DMG" \
      "$STAGE"
    then
      echo "Created $DMG (create-dmg)"
      exit 0
    fi
    if [[ "$attempt" -ge 3 ]]; then
      echo "ERROR: create-dmg failed after ${attempt} attempts" >&2
      exit 1
    fi
    echo "WARNING: create-dmg failed (attempt ${attempt}); retrying…" >&2
    attempt=$((attempt + 1))
    rm -f "$DMG"
    sleep 2
  done
fi

echo "create-dmg not found; using Finder fallback"
ln -s /Applications "$STAGE/Applications"
mkdir -p "$STAGE/.background"
cp "$BG_TIFF" "$STAGE/.background/background.tiff"

APP_MB=$(du -sm "$APP" | awk '{print $1}')
DMG_MB=$((APP_MB + 24))
if [[ "$DMG_MB" -lt 32 ]]; then
  DMG_MB=32
fi

RW_DMG=$(mktemp -u "/tmp/${APP_NAME}-rw-XXXXXX").dmg
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -format UDRW \
  -fs HFS+ \
  -fsargs "-c c=64,a=16,e=16" \
  -size "${DMG_MB}m" \
  "$RW_DMG" >/dev/null

DEVICE=""
for attach_try in 1 2 3 4 5; do
  if DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG" | awk 'END { print $1 }') \
    && [[ -n "$DEVICE" ]]; then
    break
  fi
  echo "WARNING: hdiutil attach failed (attempt ${attach_try}); retrying…" >&2
  sleep 2
done
if [[ -z "$DEVICE" ]]; then
  echo "ERROR: could not attach $RW_DMG" >&2
  exit 1
fi

for _ in $(seq 1 50); do
  [[ -d "$VOL" ]] && break
  sleep 0.1
done
if [[ ! -d "$VOL" ]]; then
  echo "ERROR: volume $VOL did not appear" >&2
  exit 1
fi

chmod -Rf go-w "$VOL" || true
mkdir -p "$VOL/.background"
cp "$BG_TIFF" "$VOL/.background/background.tiff"
if [[ -x /usr/bin/SetFile ]]; then
  SetFile -a V "$VOL/.background" || true
fi

BG_POSIX="$VOL/.background/background.tiff"
layout_ok=0
for layout_try in 1 2 3; do
  if osascript <<EOF
tell application "Finder"
  tell disk "$APP_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {200, 160, 840, 560}
    set viewOptions to icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 96
    set text size of viewOptions to 12
    set background picture of viewOptions to POSIX file "$BG_POSIX"
    set position of item "$APP_NAME.app" of container window to {160, 200}
    set position of item "Applications" of container window to {480, 200}
    update without registering applications
    delay 1
    close
    open
    delay 1
    set position of item "$APP_NAME.app" of container window to {160, 200}
    set position of item "Applications" of container window to {480, 200}
    close
  end tell
end tell
EOF
  then
    layout_ok=1
    break
  fi
  echo "WARNING: Finder layout failed (attempt ${layout_try}); retrying…" >&2
  sleep 2
done
if [[ "$layout_ok" -ne 1 ]]; then
  echo "ERROR: Finder layout failed after retries" >&2
  exit 1
fi

sync
sleep 1
for detach_try in 1 2 3 4 5; do
  if hdiutil detach "$DEVICE" -quiet || hdiutil detach "$VOL" -force -quiet; then
    break
  fi
  echo "WARNING: hdiutil detach failed (attempt ${detach_try}); retrying…" >&2
  sleep 2
done
sleep 0.5

hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
echo "Created $DMG (Finder fallback)"
