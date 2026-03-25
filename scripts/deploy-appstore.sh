#!/bin/bash
set -euo pipefail

# Deploy to App Store via App Store Connect API key
# Required env vars: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_CONTENT (or ASC_KEY_FILE)
# Note: This uploads the binary. Submission for review must be done via
# App Store Connect or the upload-metadata.sh script.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IPA_PATH="$PROJECT_DIR/bazel-bin/Cards/Cards.ipa"
KEY_DIR="${API_PRIVATE_KEYS_DIR:-$HOME/.appstoreconnect/private_keys}"
KEY_FILE="$KEY_DIR/AuthKey_${ASC_KEY_ID}.p8"

if [[ ! -f "$KEY_FILE" && -n "${ASC_KEY_CONTENT:-}" ]]; then
    mkdir -p "$KEY_DIR"
    echo "$ASC_KEY_CONTENT" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
fi

echo "Building for distribution..."
cd "$PROJECT_DIR"
bazel build //Cards:Cards --ios_multi_cpus=arm64 --compilation_mode=opt

echo "Uploading to App Store..."
xcrun altool --upload-app \
    -f "$IPA_PATH" \
    --type ios \
    --apiKey "$ASC_KEY_ID" \
    --apiIssuer "$ASC_ISSUER_ID"

echo "Done. Build uploaded to App Store Connect."
echo "Submit for review at: https://appstoreconnect.apple.com"
