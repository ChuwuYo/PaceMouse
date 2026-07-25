#!/usr/bin/env bash
# Setup stable development code signing in a dedicated keychain with a known
# password so codesign never triggers interactive keychain prompts.
set -euo pipefail

APP_NAME=${APP_NAME:-PaceMouse}
CERT_NAME="${APP_NAME} Development"
KC="$HOME/Library/Keychains/pacemouse-dev.keychain-db"
KC_PASS="pacemouse-dev"

if security find-certificate -c "$CERT_NAME" "$KC" >/dev/null 2>&1; then
  echo "Certificate '$CERT_NAME' already exists in $KC."
  echo "  export APP_IDENTITY='$CERT_NAME'"
  exit 0
fi

security delete-certificate -c "$CERT_NAME" ~/Library/Keychains/login.keychain-db 2>/dev/null || true

rm -f "$KC"
security create-keychain -p "$KC_PASS" "$KC"
security set-keychain-settings "$KC"
security unlock-keychain -p "$KC_PASS" "$KC"

TEMP_CONFIG=$(mktemp)
trap "rm -f $TEMP_CONFIG /tmp/pacemouse-dev.{key,crt,p12}" EXIT

cat > "$TEMP_CONFIG" <<EOFCONF
[ req ]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[ req_distinguished_name ]
CN = $CERT_NAME
O = ${APP_NAME} Development
C = US

[ v3_req ]
keyUsage = critical,digitalSignature
extendedKeyUsage = codeSigning
EOFCONF

openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 \
    -nodes -keyout /tmp/pacemouse-dev.key -out /tmp/pacemouse-dev.crt \
    -config "$TEMP_CONFIG" 2>/dev/null

openssl pkcs12 -export -legacy -out /tmp/pacemouse-dev.p12 \
    -inkey /tmp/pacemouse-dev.key -in /tmp/pacemouse-dev.crt \
    -passout pass:"$KC_PASS" 2>/dev/null

security import /tmp/pacemouse-dev.p12 -k "$KC" \
  -P "$KC_PASS" -T /usr/bin/codesign -T /usr/bin/security

security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KC_PASS" "$KC" >/dev/null

EXISTING=$(security list-keychains -d user | tr -d '"')
security list-keychains -d user -s $EXISTING "$KC"

echo "Certificate '$CERT_NAME' created in dedicated keychain $KC"
echo "  export APP_IDENTITY='$CERT_NAME'"
