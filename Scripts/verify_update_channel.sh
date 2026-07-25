#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

APP_NAME=${APP_NAME:-PaceMouse}
APP="$ROOT/${APP_NAME}.app"
FAIL=0

pass() { echo "PASS  $*"; }
fail() { echo "FAIL  $*"; FAIL=1; }

echo "== localize keys =="
for key in \
  "Automatically Check for Updates" \
  "Include Pre-release Updates" \
  "Check for Updates…" \
  "Update Available — v%@…" \
  "Update Available"
do
  if grep -Fq "\"$key\"" Sources/PaceMouse/Resources/en.lproj/Localizable.strings \
    && grep -Fq "\"$key\"" Sources/PaceMouse/Resources/zh-Hans.lproj/Localizable.strings; then
    pass "l10n: $key"
  else
    fail "l10n missing: $key"
  fi
done

echo "== package =="
if [[ ! -d "$APP" ]]; then
  SIGNING_MODE=${SIGNING_MODE:-adhoc} Scripts/package_app.sh release
fi

test -x "$APP/Contents/MacOS/$APP_NAME" && pass "executable" || fail "executable"
test -d "$APP/Contents/Frameworks/Sparkle.framework" && pass "Sparkle.framework" || fail "Sparkle.framework"
if codesign -d --entitlements - "$APP" 2>/dev/null | grep -q 'disable-library-validation'; then
  pass "entitlement disable-library-validation"
else
  fail "entitlement disable-library-validation (required for Sparkle under Hardened Runtime)"
fi
if otool -l "$APP/Contents/MacOS/$APP_NAME" | grep -q '@executable_path/../Frameworks'; then
  pass "rpath Frameworks"
else
  fail "rpath Frameworks missing"
fi
sparkle_ver="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
for nested in \
  "$sparkle_ver/XPCServices/Installer.xpc" \
  "$sparkle_ver/XPCServices/Downloader.xpc" \
  "$sparkle_ver/Autoupdate" \
  "$sparkle_ver/Updater.app" \
  "$APP/Contents/Frameworks/Sparkle.framework"
do
  if [[ -e "$nested" ]] && codesign --verify --strict "$nested" >/dev/null 2>&1; then
    pass "signed $(basename "$nested")"
  else
    fail "signed $(basename "$nested")"
  fi
done
grep -q "preserve-metadata=entitlements" Scripts/package_app.sh \
  && pass "Downloader preserve-metadata entitlements" \
  || fail "Downloader preserve-metadata entitlements"
grep -q 'Sparkle.framework not found' Scripts/package_app.sh \
  && pass "package fails without Sparkle.framework" \
  || fail "package fails without Sparkle.framework"
grep -q 'zip_mutated=1' .github/workflows/ci-release.yml \
  && grep -q 'appcast_mutated=1' .github/workflows/ci-release.yml \
  && grep -q 'rollback_sparkle_asset' .github/workflows/ci-release.yml \
  && grep -q 'wait_for_asset_digest "$zip_name"' .github/workflows/ci-release.yml \
  && pass "CI Sparkle upload inside rollback window" \
  || fail "CI Sparkle upload rollback wiring"

for key in SUFeedURL SUPublicEDKey SUEnableAutomaticChecks; do
  if /usr/libexec/PlistBuddy -c "Print :$key" "$APP/Contents/Info.plist" >/dev/null 2>&1; then
    pass "Info.plist $key"
  else
    fail "Info.plist $key"
  fi
done

FEED=$(/usr/libexec/PlistBuddy -c "Print :SUFeedURL" "$APP/Contents/Info.plist")
[[ "$FEED" == *"app-latest/appcast.xml" ]] && pass "feed URL points at app-latest" || fail "feed URL: $FEED"

AUTO=$(/usr/libexec/PlistBuddy -c "Print :SUEnableAutomaticChecks" "$APP/Contents/Info.plist")
[[ "$AUTO" == "true" ]] && pass "automatic checks default on" || fail "automatic checks: $AUTO"

echo "== appcast =="
if [[ -z "${SPARKLE_PRIVATE_KEY:-}" && ! -f Secrets/sparkle_eddsa_private.pem ]]; then
  if [[ "${REQUIRE_APPCAST:-0}" == "1" ]]; then
    fail "Sparkle private key unavailable for appcast generation"
  else
    echo "SKIP  appcast generation (no private key)"
  fi
else
  Scripts/make_appcast.sh
  test -f appcast.xml && pass "appcast.xml written" || fail "appcast.xml missing"
  shopt -s nullglob
  zips=("${APP_NAME}-"*.zip)
  shopt -u nullglob
  if [[ ${#zips[@]} -gt 0 ]]; then
    pass "update zip written (${zips[0]})"
  else
    fail "update zip missing"
  fi
  if grep -q '<sparkle:version>' appcast.xml \
    && grep -q 'sparkle:edSignature=' appcast.xml \
    && grep -q 'app-latest/PaceMouse-.*\.zip' appcast.xml; then
    pass "appcast has version, signature, zip URL"
  else
    fail "appcast content incomplete"
    cat appcast.xml
  fi

  # shellcheck disable=SC1091
  source version.env
  channel=${SPARKLE_CHANNEL:-${RELEASE_CHANNEL:-}}
  if [[ -n "$channel" ]]; then
    if grep -Fq "<sparkle:channel>$channel</sparkle:channel>" appcast.xml; then
      pass "appcast channel=$channel"
    else
      fail "appcast missing channel $channel"
      cat appcast.xml
    fi
  else
    if grep -q '<sparkle:channel>' appcast.xml; then
      fail "stable release should not set sparkle:channel"
      cat appcast.xml
    else
      pass "appcast stable (no channel)"
    fi
  fi
fi

echo "== source wiring =="
grep -q "UpdateController" Sources/PaceMouse/AppDelegate.swift && pass "AppDelegate wires UpdateController" || fail "AppDelegate missing UpdateController"
grep -q "onInstallUpdate" Sources/PaceMouse/StatusItemController.swift && pass "menu update action" || fail "menu update action"
grep -q "Check for Updates" Sources/PaceMouse/SettingsWindowController.swift && pass "settings check button" || fail "settings check button"
grep -q "canCheckForUpdates" Sources/PaceMouse/SettingsWindowController.swift && pass "settings respects canCheckForUpdates" || fail "canCheckForUpdates wiring"
grep -q "allowedChannels" Sources/PaceMouse/UpdateController.swift && pass "UpdateController allowedChannels" || fail "allowedChannels missing"
grep -q "includePreReleaseUpdates" Sources/PaceMouse/SettingsStore.swift && pass "SettingsStore pre-release toggle" || fail "pre-release setting missing"
grep -q "applyChannelPreference" Sources/PaceMouse/UpdateController.swift && pass "channel preference resets session" || fail "applyChannelPreference missing"
grep -q "dismissUpdateInstallation" Sources/PaceMouse/UpdateController.swift && pass "opt-out dismisses Sparkle session" || fail "dismissUpdateInstallation missing"
grep -q "sparkle-project/Sparkle" Package.swift && pass "Package.swift depends on Sparkle" || fail "Package.swift Sparkle dependency"
grep -q 'RELEASE_CHANNEL=' version.env && pass "version.env RELEASE_CHANNEL" || fail "version.env RELEASE_CHANNEL"
grep -q "UpdateChannel" Sources/PaceMouseCore/UpdateChannel.swift && pass "UpdateChannel helper" || fail "UpdateChannel.swift missing"

if [[ "$FAIL" -ne 0 ]]; then
  echo "verify_update_channel: FAILED"
  exit 1
fi
echo "verify_update_channel: OK"
