#!/bin/bash
set -euo pipefail

# Upload App Store screenshots from screenshots/ directory
# Required env vars: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_CONTENT (or .p8 on disk)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SCREENSHOTS_DIR="$PROJECT_DIR/screenshots"
BUNDLE_ID="net.serby.Cards"

source "$SCRIPT_DIR/asc-auth.sh"

asc_get() { curl -s -H "Authorization: Bearer $ASC_JWT" "$ASC_API$1"; }
asc_post() { curl -s -X POST -H "Authorization: Bearer $ASC_JWT" -H "Content-Type: application/json" -d "$2" "$ASC_API$1"; }
asc_upload() { curl -s -X PUT -H "Content-Type: image/png" --data-binary "@$2" "$1"; }
asc_patch() { curl -s -X PATCH -H "Authorization: Bearer $ASC_JWT" -H "Content-Type: application/json" -d "$2" "$ASC_API$1"; }

APP_ID=$(asc_get "/apps?filter[bundleId]=$BUNDLE_ID" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'][0]['id'])")
VERSION_ID=$(asc_get "/apps/$APP_ID/appStoreVersions?filter[appStoreState]=READY_FOR_SUBMISSION,PREPARE_FOR_SUBMISSION" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'][0]['id'])")

echo "App ID: $APP_ID, Version ID: $VERSION_ID"

for locale_dir in "$SCREENSHOTS_DIR"/*/; do
    locale=$(basename "$locale_dir")
    echo "Uploading screenshots for $locale..."

    # Get localization ID
    VER_LOC_ID=$(asc_get "/appStoreVersions/$VERSION_ID/appStoreVersionLocalizations" | python3 -c "import sys,json; locs=json.load(sys.stdin)['data']; print([l['id'] for l in locs if l['attributes']['locale']=='$locale'][0])")

    # Get screenshot sets
    SETS=$(asc_get "/appStoreVersionLocalizations/$VER_LOC_ID/appScreenshotSets")

    # Default to iPhone 6.7" display
    DISPLAY_TYPE="APP_IPHONE_67"
    SET_ID=$(echo "$SETS" | python3 -c "import sys,json; sets=json.load(sys.stdin)['data']; matches=[s['id'] for s in sets if s['attributes']['screenshotDisplayType']=='$DISPLAY_TYPE']; print(matches[0] if matches else '')" 2>/dev/null || echo "")

    # Create set if it doesn't exist
    if [[ -z "$SET_ID" ]]; then
        SET_ID=$(asc_post "/appScreenshotSets" "{\"data\":{\"type\":\"appScreenshotSets\",\"attributes\":{\"screenshotDisplayType\":\"$DISPLAY_TYPE\"},\"relationships\":{\"appStoreVersionLocalization\":{\"data\":{\"type\":\"appStoreVersionLocalizations\",\"id\":\"$VER_LOC_ID\"}}}}}" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['id'])")
        echo "  Created screenshot set: $SET_ID"
    fi

    for screenshot in "$locale_dir"/*.png; do
        [[ -f "$screenshot" ]] || continue
        FILENAME=$(basename "$screenshot")
        FILESIZE=$(stat -f%z "$screenshot")
        echo "  Uploading $FILENAME ($FILESIZE bytes)..."

        # Reserve upload
        RESERVATION=$(asc_post "/appScreenshots" "{\"data\":{\"type\":\"appScreenshots\",\"attributes\":{\"fileName\":\"$FILENAME\",\"fileSize\":$FILESIZE},\"relationships\":{\"appScreenshotSet\":{\"data\":{\"type\":\"appScreenshotSets\",\"id\":\"$SET_ID\"}}}}}")

        SCREENSHOT_ID=$(echo "$RESERVATION" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['id'])")
        UPLOAD_URL=$(echo "$RESERVATION" | python3 -c "import sys,json; ops=json.load(sys.stdin)['data']['attributes']['uploadOperations']; print(ops[0]['url'])")

        # Upload the file
        asc_upload "$UPLOAD_URL" "$screenshot" > /dev/null

        # Commit
        asc_patch "/appScreenshots/$SCREENSHOT_ID" "{\"data\":{\"type\":\"appScreenshots\",\"id\":\"$SCREENSHOT_ID\",\"attributes\":{\"uploaded\":true,\"sourceFileChecksum\":{\"type\":\"md5\",\"value\":\"$(md5 -q "$screenshot")\"}}}}" > /dev/null

        echo "  Uploaded $FILENAME"
    done
done

echo "Done. Screenshots uploaded."
