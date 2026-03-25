#!/bin/bash
set -euo pipefail

# Upload App Store metadata from metadata/ directory
# Required env vars: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_CONTENT (or .p8 on disk)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
METADATA_DIR="$PROJECT_DIR/metadata"
BUNDLE_ID="net.serby.Cards"

source "$SCRIPT_DIR/asc-auth.sh"

asc_get() { curl -s -H "Authorization: Bearer $ASC_JWT" "$ASC_API$1"; }
asc_patch() { curl -s -X PATCH -H "Authorization: Bearer $ASC_JWT" -H "Content-Type: application/json" -d "$2" "$ASC_API$1"; }

# Find the app
APP_ID=$(asc_get "/apps?filter[bundleId]=$BUNDLE_ID" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'][0]['id'])")
echo "App ID: $APP_ID"

# Get the editable app info version
INFO_ID=$(asc_get "/apps/$APP_ID/appInfos" | python3 -c "import sys,json; infos=json.load(sys.stdin)['data']; print([i['id'] for i in infos if i['attributes']['appStoreState']=='READY_FOR_SUBMISSION' or i['attributes']['appStoreState']=='PREPARE_FOR_SUBMISSION'][0])" 2>/dev/null || echo "")

if [[ -z "$INFO_ID" ]]; then
    echo "No editable app version found. Create a new version in App Store Connect first."
    exit 1
fi

# Get localizations
LOCALIZATIONS=$(asc_get "/appInfos/$INFO_ID/appInfoLocalizations")

for locale_dir in "$METADATA_DIR"/*/; do
    locale=$(basename "$locale_dir")
    [[ "$locale" == "review_information" ]] && continue

    echo "Updating $locale..."

    # Find localization ID
    LOC_ID=$(echo "$LOCALIZATIONS" | python3 -c "import sys,json; locs=json.load(sys.stdin)['data']; print([l['id'] for l in locs if l['attributes']['locale']=='$locale'][0])" 2>/dev/null || echo "")

    if [[ -z "$LOC_ID" ]]; then
        echo "  Locale $locale not found in App Store Connect, skipping."
        continue
    fi

    # Read metadata files
    NAME=$(cat "$locale_dir/name.txt" 2>/dev/null || echo "")
    SUBTITLE=$(cat "$locale_dir/subtitle.txt" 2>/dev/null || echo "")
    PROMO=$(cat "$locale_dir/promotional_text.txt" 2>/dev/null || echo "")

    # Build JSON payload
    PAYLOAD=$(python3 -c "
import json
attrs = {}
if '$NAME': attrs['name'] = '$NAME'
if '$SUBTITLE': attrs['subtitle'] = '$SUBTITLE'
if '$PROMO': attrs['promotionalText'] = '$PROMO'
print(json.dumps({'data': {'type': 'appInfoLocalizations', 'id': '$LOC_ID', 'attributes': attrs}}))
")

    asc_patch "/appInfoLocalizations/$LOC_ID" "$PAYLOAD" > /dev/null
    echo "  Updated name, subtitle, promotional text."
done

# Update version-level localizations (description, keywords, etc.)
VERSION_ID=$(asc_get "/apps/$APP_ID/appStoreVersions?filter[appStoreState]=READY_FOR_SUBMISSION,PREPARE_FOR_SUBMISSION" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'][0]['id'])" 2>/dev/null || echo "")

if [[ -n "$VERSION_ID" ]]; then
    VER_LOCS=$(asc_get "/appStoreVersions/$VERSION_ID/appStoreVersionLocalizations")

    for locale_dir in "$METADATA_DIR"/*/; do
        locale=$(basename "$locale_dir")
        [[ "$locale" == "review_information" ]] && continue

        VER_LOC_ID=$(echo "$VER_LOCS" | python3 -c "import sys,json; locs=json.load(sys.stdin)['data']; print([l['id'] for l in locs if l['attributes']['locale']=='$locale'][0])" 2>/dev/null || echo "")
        [[ -z "$VER_LOC_ID" ]] && continue

        DESC=$(cat "$locale_dir/description.txt" 2>/dev/null || echo "")
        KEYWORDS=$(cat "$locale_dir/keywords.txt" 2>/dev/null || echo "")

        PAYLOAD=$(python3 << EOF
import json
attrs = {}
desc = open('$locale_dir/description.txt').read().strip() if True else ''
kw = open('$locale_dir/keywords.txt').read().strip() if True else ''
if desc: attrs['description'] = desc
if kw: attrs['keywords'] = kw
print(json.dumps({'data': {'type': 'appStoreVersionLocalizations', 'id': '$VER_LOC_ID', 'attributes': attrs}}))
EOF
        )

        asc_patch "/appStoreVersionLocalizations/$VER_LOC_ID" "$PAYLOAD" > /dev/null
        echo "  Updated description, keywords for $locale."
    done
fi

echo "Done. Metadata uploaded."
