#!/bin/bash
# End-to-end App Store submission via App Store Connect REST API.
#
# Steps:
#   1. Resolve app by bundle ID
#   2. Wait for the build (matching CFBundleVersion) to finish processing
#   3. Find or create appStoreVersion for $MARKETING_VERSION
#   4. Attach the build to the version
#   5. Set "What's New" on every existing version localisation
#   6. Submit for review
#
# Required env vars:
#   ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_CONTENT
#   MARKETING_VERSION   (e.g. 1.1.0)
#   BUILD_VERSION       (CFBundleVersion of the upload to attach, e.g. 31)
#   WHATS_NEW           (release notes text)
#   BUNDLE_ID           (default: net.serby.Cards)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLE_ID="${BUNDLE_ID:-net.serby.Cards}"
PLATFORM="IOS"

: "${MARKETING_VERSION:?MARKETING_VERSION required (e.g. 1.1.0)}"
: "${BUILD_VERSION:?BUILD_VERSION required (CFBundleVersion of the just-uploaded build)}"
: "${WHATS_NEW:?WHATS_NEW required (release notes text)}"

source "$SCRIPT_DIR/asc-auth.sh"

api() {
    local method="${1:-GET}"; shift
    local path="$1"; shift
    local data="${1:-}"
    if [[ -n "$data" ]]; then
        curl -fsS -X "$method" \
            -H "Authorization: Bearer $ASC_JWT" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$ASC_API$path"
    else
        curl -fsS -X "$method" \
            -H "Authorization: Bearer $ASC_JWT" \
            "$ASC_API$path"
    fi
}

jq_py() { python3 -c "import sys,json; $1"; }

echo "==> Resolving app for bundle $BUNDLE_ID"
APP_ID=$(api GET "/apps?filter[bundleId]=$BUNDLE_ID" \
    | jq_py "print(json.load(sys.stdin)['data'][0]['id'])")
echo "    App ID: $APP_ID"

# Apple's processing pipeline takes 5-30 min. Poll until build appears with
# valid processing state.
echo "==> Waiting for build $BUILD_VERSION to finish processing"
BUILD_ID=""
for attempt in $(seq 1 60); do
    BUILDS=$(api GET "/apps/$APP_ID/builds?filter[version]=$BUILD_VERSION&limit=10")
    BUILD_ID=$(echo "$BUILDS" | jq_py "
data = json.load(sys.stdin).get('data', [])
ready = [b for b in data if b['attributes'].get('processingState') == 'VALID']
print(ready[0]['id'] if ready else '')
")
    if [[ -n "$BUILD_ID" ]]; then
        echo "    Build $BUILD_VERSION ready (id $BUILD_ID)"
        break
    fi
    STATE=$(echo "$BUILDS" | jq_py "
data = json.load(sys.stdin).get('data', [])
print(data[0]['attributes'].get('processingState','MISSING') if data else 'MISSING')
")
    echo "    [$attempt/60] still $STATE; sleeping 30s"
    sleep 30
done

if [[ -z "$BUILD_ID" ]]; then
    echo "::error::Build $BUILD_VERSION did not finish processing within 30 min"
    exit 1
fi

echo "==> Finding or creating appStoreVersion $MARKETING_VERSION"
VERSION_ID=$(api GET "/apps/$APP_ID/appStoreVersions?filter[versionString]=$MARKETING_VERSION&filter[platform]=$PLATFORM" \
    | jq_py "
data = json.load(sys.stdin).get('data', [])
print(data[0]['id'] if data else '')
")

if [[ -z "$VERSION_ID" ]]; then
    PAYLOAD=$(python3 -c "
import json
print(json.dumps({
  'data': {
    'type': 'appStoreVersions',
    'attributes': {
      'platform': '$PLATFORM',
      'versionString': '$MARKETING_VERSION'
    },
    'relationships': {
      'app': {'data': {'type': 'apps', 'id': '$APP_ID'}}
    }
  }
}))")
    VERSION_ID=$(api POST "/appStoreVersions" "$PAYLOAD" \
        | jq_py "print(json.load(sys.stdin)['data']['id'])")
    echo "    Created version $MARKETING_VERSION (id $VERSION_ID)"
else
    echo "    Reusing existing version $MARKETING_VERSION (id $VERSION_ID)"
fi

echo "==> Attaching build $BUILD_ID to version $VERSION_ID"
PAYLOAD=$(python3 -c "
import json
print(json.dumps({'data': {'type': 'builds', 'id': '$BUILD_ID'}}))")
api PATCH "/appStoreVersions/$VERSION_ID/relationships/build" "$PAYLOAD" > /dev/null
echo "    Attached"

echo "==> Setting 'What's New' on all version localisations"
LOCS=$(api GET "/appStoreVersions/$VERSION_ID/appStoreVersionLocalizations")
echo "$LOCS" | jq_py "
data = json.load(sys.stdin).get('data', [])
for l in data:
    print(l['id'], l['attributes']['locale'])
" | while read -r LOC_ID LOC_NAME; do
    PAYLOAD=$(WHATS_NEW="$WHATS_NEW" python3 -c "
import json, os
print(json.dumps({
  'data': {
    'type': 'appStoreVersionLocalizations',
    'id': '$LOC_ID',
    'attributes': {'whatsNew': os.environ['WHATS_NEW']}
  }
}))")
    api PATCH "/appStoreVersionLocalizations/$LOC_ID" "$PAYLOAD" > /dev/null
    echo "    $LOC_NAME updated"
done

echo "==> Submitting version for review"
PAYLOAD=$(python3 -c "
import json
print(json.dumps({
  'data': {
    'type': 'appStoreVersionSubmissions',
    'relationships': {
      'appStoreVersion': {'data': {'type': 'appStoreVersions', 'id': '$VERSION_ID'}}
    }
  }
}))")

if api POST "/appStoreVersionSubmissions" "$PAYLOAD" > /tmp/submit-response.json 2>&1; then
    echo "    Submitted for review."
    echo "    Track at https://appstoreconnect.apple.com"
else
    echo "::error::Submission failed; response below"
    cat /tmp/submit-response.json
    exit 1
fi
