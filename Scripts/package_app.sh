#!/usr/bin/env bash
set -euo pipefail

CONF=${1:-release}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

APP_NAME=${APP_NAME:-PaceMouse}
BUNDLE_ID=${BUNDLE_ID:-com.chuwuyo.pacemouse}
MACOS_MIN_VERSION=${MACOS_MIN_VERSION:-14.0}
MENU_BAR_APP=${MENU_BAR_APP:-1}
SIGNING_MODE=${SIGNING_MODE:-}
APP_IDENTITY=${APP_IDENTITY:-}

if [[ -f "$ROOT/version.env" ]]; then
  source "$ROOT/version.env"
else
  MARKETING_VERSION=${MARKETING_VERSION:-0.1.0}
  BUILD_NUMBER=${BUILD_NUMBER:-1}
fi

ARCH_LIST=( ${ARCHES:-} )
if [[ ${#ARCH_LIST[@]} -eq 0 ]]; then
  HOST_ARCH=$(uname -m)
  ARCH_LIST=("$HOST_ARCH")
fi

for ARCH in "${ARCH_LIST[@]}"; do
  swift build -c "$CONF" --arch "$ARCH"
done

APP="$ROOT/${APP_NAME}.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"

# Convert Icon.icon to Icon.icns if present (requires iconutil).
ICON_SOURCE="$ROOT/Icon.icon"
ICON_TARGET="$ROOT/Icon.icns"
if [[ -f "$ICON_SOURCE" ]]; then
  iconutil --convert icns --output "$ICON_TARGET" "$ICON_SOURCE"
fi

LSUI_VALUE="false"
if [[ "$MENU_BAR_APP" == "1" ]]; then
  LSUI_VALUE="true"
fi

BUILD_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${MARKETING_VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key><string>${MACOS_MIN_VERSION}</string>
    <key>LSUIElement</key><${LSUI_VALUE}/>
    <key>CFBundleIconFile</key><string>Icon</string>
    <key>BuildTimestamp</key><string>${BUILD_TIMESTAMP}</string>
    <key>GitCommit</key><string>${GIT_COMMIT}</string>
    <key>SUFeedURL</key><string>https://github.com/ChuwuYo/PaceMouse/releases/download/app-latest/appcast.xml</string>
    <key>SUPublicEDKey</key><string>D6TGQX7Rk0CvTw9Qlt2fszDlX29EzhCWJayAwI4M0gQ=</string>
    <key>SUEnableAutomaticChecks</key><true/>
    <key>SUScheduledCheckInterval</key><integer>86400</integer>
    <key>SUAllowsAutomaticUpdates</key><false/>
    <key>SUAutomaticallyUpdate</key><false/>
</dict>
</plist>
PLIST

build_product_path() {
  local name="$1"
  local arch="$2"
  case "$arch" in
    arm64|x86_64) echo ".build/${arch}-apple-macosx/$CONF/$name" ;;
    *) echo ".build/$CONF/$name" ;;
  esac
}

verify_binary_arches() {
  local binary="$1"; shift
  local expected=("$@")
  local actual
  actual=$(lipo -archs "$binary")
  local actual_count expected_count
  actual_count=$(wc -w <<<"$actual" | tr -d ' ')
  expected_count=${#expected[@]}
  if [[ "$actual_count" -ne "$expected_count" ]]; then
    echo "ERROR: $binary arch mismatch (expected: ${expected[*]}, actual: ${actual})" >&2
    exit 1
  fi
  for arch in "${expected[@]}"; do
    if [[ "$actual" != *"$arch"* ]]; then
      echo "ERROR: $binary missing arch $arch (have: ${actual})" >&2
      exit 1
    fi
  done
}

install_binary() {
  local name="$1"
  local dest="$2"
  local binaries=()
  for arch in "${ARCH_LIST[@]}"; do
    local src
    src=$(build_product_path "$name" "$arch")
    if [[ ! -f "$src" ]]; then
      echo "ERROR: Missing ${name} build for ${arch} at ${src}" >&2
      exit 1
    fi
    binaries+=("$src")
  done
  if [[ ${#ARCH_LIST[@]} -gt 1 ]]; then
    lipo -create "${binaries[@]}" -output "$dest"
  else
    cp "${binaries[0]}" "$dest"
  fi
  chmod +x "$dest"
  verify_binary_arches "$dest" "${ARCH_LIST[@]}"
}

install_binary "$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"

# Bundle app resources (if any).
APP_RESOURCES_DIR="$ROOT/Sources/$APP_NAME/Resources"
if [[ -d "$APP_RESOURCES_DIR" ]]; then
  cp -R "$APP_RESOURCES_DIR/." "$APP/Contents/Resources/"
fi

# SwiftPM resource bundles are emitted next to the built binary.
PREFERRED_BUILD_DIR="$(dirname "$(build_product_path "$APP_NAME" "${ARCH_LIST[0]}")")"
shopt -s nullglob
SWIFTPM_BUNDLES=("${PREFERRED_BUILD_DIR}/"*.bundle)
shopt -u nullglob
if [[ ${#SWIFTPM_BUNDLES[@]} -gt 0 ]]; then
  for bundle in "${SWIFTPM_BUNDLES[@]}"; do
    cp -R "$bundle" "$APP/Contents/Resources/"
  done
fi

mkdir -p "$APP/Contents/Frameworks"
SPARKLE_FW="$ROOT/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [[ ! -d "$SPARKLE_FW" ]]; then
  echo "ERROR: Sparkle.framework not found at $SPARKLE_FW (run swift package resolve / swift build)" >&2
  exit 1
fi
rm -rf "$APP/Contents/Frameworks/Sparkle.framework"
cp -R "$SPARKLE_FW" "$APP/Contents/Frameworks/"
FRAMEWORK_DIRS=(".build/$CONF" ".build/${ARCH_LIST[0]}-apple-macosx/$CONF")
for dir in "${FRAMEWORK_DIRS[@]}"; do
  if compgen -G "${dir}/*.framework" >/dev/null; then
    cp -R "${dir}/"*.framework "$APP/Contents/Frameworks/"
  fi
done
chmod -R a+rX "$APP/Contents/Frameworks"
if ! otool -l "$APP/Contents/MacOS/$APP_NAME" | grep -q '@executable_path/../Frameworks'; then
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/$APP_NAME"
fi

if [[ -f "$ICON_TARGET" ]]; then
  cp "$ICON_TARGET" "$APP/Contents/Resources/Icon.icns"
fi

# Ensure contents are writable before stripping attributes and signing.
chmod -R u+w "$APP"

# Strip extended attributes to prevent AppleDouble files that break code sealing.
xattr -cr "$APP"
find "$APP" -name '._*' -delete

ENTITLEMENTS_DIR="$ROOT/.build/entitlements"
DEFAULT_ENTITLEMENTS="$ENTITLEMENTS_DIR/${APP_NAME}.entitlements"
mkdir -p "$ENTITLEMENTS_DIR"

APP_ENTITLEMENTS=${APP_ENTITLEMENTS:-$DEFAULT_ENTITLEMENTS}
if [[ ! -f "$APP_ENTITLEMENTS" ]]; then
  cat > "$APP_ENTITLEMENTS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Add entitlements here if needed. -->
</dict>
</plist>
PLIST
fi

if [[ "$SIGNING_MODE" == "adhoc" || -z "$APP_IDENTITY" ]]; then
  CODESIGN_ARGS=(--force --sign "-")
elif [[ "${SIGN_TIMESTAMP:-0}" == "1" ]]; then
  CODESIGN_ARGS=(--force --timestamp --options runtime --sign "$APP_IDENTITY")
else
  CODESIGN_ARGS=(--force --options runtime --sign "$APP_IDENTITY")
fi

DEV_KC="${DEV_KC:-$HOME/Library/Keychains/pacemouse-dev.keychain-db}"
if [[ "$SIGNING_MODE" != "adhoc" && -n "$APP_IDENTITY" && -f "$DEV_KC" ]]; then
  security unlock-keychain -p "${DEV_KC_PASS:-pacemouse-dev}" "$DEV_KC" || true
  EXISTING_KCS=$(security list-keychains -d user | tr -d '"')
  security list-keychains -d user -s $EXISTING_KCS "$DEV_KC"
fi

# Sign embedded frameworks before the app bundle.
# Sparkle nested helpers must follow upstream order; Downloader keeps its entitlements.
sign_sparkle_framework() {
  local fw="$APP/Contents/Frameworks/Sparkle.framework"
  local ver="$fw/Versions/B"
  if [[ ! -d "$ver" ]]; then
    ver="$fw/Versions/Current"
  fi
  if [[ -d "$ver/XPCServices/Installer.xpc" ]]; then
    codesign "${CODESIGN_ARGS[@]}" "$ver/XPCServices/Installer.xpc"
  fi
  if [[ -d "$ver/XPCServices/Downloader.xpc" ]]; then
    codesign "${CODESIGN_ARGS[@]}" --preserve-metadata=entitlements "$ver/XPCServices/Downloader.xpc"
  fi
  if [[ -x "$ver/Autoupdate" ]]; then
    codesign "${CODESIGN_ARGS[@]}" "$ver/Autoupdate"
  fi
  if [[ -d "$ver/Updater.app" ]]; then
    codesign "${CODESIGN_ARGS[@]}" "$ver/Updater.app"
  fi
  codesign "${CODESIGN_ARGS[@]}" "$fw"
}

sign_frameworks() {
  local fw
  for fw in "$APP/Contents/Frameworks/"*.framework; do
    if [[ ! -d "$fw" ]]; then
      continue
    fi
    if [[ "$(basename "$fw")" == "Sparkle.framework" ]]; then
      sign_sparkle_framework
      continue
    fi
    while IFS= read -r -d '' bin; do
      codesign "${CODESIGN_ARGS[@]}" "$bin"
    done < <(find "$fw" -type f -perm -111 -print0)
    codesign "${CODESIGN_ARGS[@]}" "$fw"
  done
}
sign_frameworks

codesign "${CODESIGN_ARGS[@]}" \
  --entitlements "$APP_ENTITLEMENTS" \
  "$APP"

echo "Created $APP"
