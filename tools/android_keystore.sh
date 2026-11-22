#!/usr/bin/env bash
# Creates the Android release keystore and (if GitHub CLI is logged in inside the repo)
# stores it as the secrets the Build & Release workflow expects.
#   ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS
# Usage (from the repo root):  bash tools/android_keystore.sh [alias] [file]
set -euo pipefail
ALIAS="${1:-prismfall}"
KS="${2:-prismfall-release.keystore}"
if [ -e "$KS" ]; then echo "$KS already exists - refusing to overwrite your signing key." >&2; exit 1; fi
read -r -s -p "Keystore password (min 6 chars): " PASS; echo
keytool -genkeypair -v -keystore "$KS" -alias "$ALIAS" -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass "$PASS" -keypass "$PASS" -dname "CN=Prismfall, O=Prismfall, C=US"
if command -v gh >/dev/null 2>&1; then
  base64 < "$KS" | tr -d '\n' | gh secret set ANDROID_KEYSTORE_BASE64
  printf %s "$PASS" | gh secret set ANDROID_KEYSTORE_PASSWORD
  printf %s "$ALIAS" | gh secret set ANDROID_KEY_ALIAS
  echo "GitHub secrets set."
else
  echo "Add repository secrets ANDROID_KEYSTORE_BASE64 (base64 of $KS), ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS=$ALIAS"
fi
echo "Back up $KS and its password: Google Play needs the same key for every update. Never commit it."
