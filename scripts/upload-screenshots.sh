#!/bin/bash
# Upload App Store screenshots from screenshots/<locale>/*.png.
#
# Detects each image's display type from its pixel dimensions, creates the
# screenshot set on the editable version if missing, uploads the bytes, then
# polls the screenshot's assetDeliveryState until it reaches COMPLETE.
#
# Required env vars: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_CONTENT (or .p8 on disk).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SCREENSHOTS_DIR="$PROJECT_DIR/screenshots"
BUNDLE_ID="${BUNDLE_ID:-net.serby.Cards}"

source "$SCRIPT_DIR/asc-auth.sh"

# curl wrappers that ABORT on HTTP >= 400 (--fail-with-body keeps the body for
# inspection). The old script used `curl -s` which silently swallowed errors.
asc_get()   { curl -fSs --globoff -H "Authorization: Bearer $ASC_JWT" "$ASC_API$1"; }
asc_post()  { curl -fSs --globoff -X POST -H "Authorization: Bearer $ASC_JWT" -H "Content-Type: application/json" -d "$2" "$ASC_API$1"; }
asc_patch() { curl -fSs --globoff -X PATCH -H "Authorization: Bearer $ASC_JWT" -H "Content-Type: application/json" -d "$2" "$ASC_API$1"; }

jq_py() { python3 -c "$1"; }

# (width, height) → App Store display-type enum. Covers the sizes Apple
# currently accepts as primary / derivable. See
# https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/
display_type_for() {
    local w="$1" h="$2"
    # App Store Connect's API tops out at APP_IPHONE_67 — there is no 6.9"
    # enum. iPhone 16/17 Pro Max native (1320x2868) must be uploaded as
    # APP_IPHONE_67; Apple resizes for display.
    case "${w}x${h}" in
        1320x2868|2868x1320) echo APP_IPHONE_67 ;;
        1290x2796|2796x1290) echo APP_IPHONE_67 ;;
        1284x2778|2778x1284) echo APP_IPHONE_67 ;;
        1242x2688|2688x1242) echo APP_IPHONE_65 ;;
        1170x2532|2532x1170) echo APP_IPHONE_61 ;;
        1242x2208|2208x1242) echo APP_IPHONE_55 ;;
        2064x2752|2752x2064) echo APP_IPAD_PRO_3GEN_129 ;;
        2048x2732|2732x2048) echo APP_IPAD_PRO_3GEN_129 ;;
        *) echo "" ;;
    esac
}

echo "==> Resolving app and editable version"
APP_ID=$(asc_get "/apps?filter[bundleId]=$BUNDLE_ID" \
    | jq_py "import sys,json; print(json.load(sys.stdin)['data'][0]['id'])")
VERSION_ID=$(asc_get "/apps/$APP_ID/appStoreVersions?filter[appStoreState]=READY_FOR_REVIEW,PREPARE_FOR_SUBMISSION" \
    | jq_py "import sys,json; print(json.load(sys.stdin)['data'][0]['id'])")
echo "    App $APP_ID, version $VERSION_ID"

for locale_dir in "$SCREENSHOTS_DIR"/*/; do
    locale=$(basename "$locale_dir")
    echo
    echo "==> $locale"

    VER_LOC_ID=$(asc_get "/appStoreVersions/$VERSION_ID/appStoreVersionLocalizations" \
        | LOCALE="$locale" jq_py "
import sys, json, os
target = os.environ['LOCALE']
locs = json.load(sys.stdin)['data']
match = [l['id'] for l in locs if l['attributes']['locale'] == target]
if not match:
    sys.exit(f\"::error::no localization for {target}\")
print(match[0])
")
    echo "    localization $VER_LOC_ID"

    EXISTING_SETS_JSON=$(asc_get "/appStoreVersionLocalizations/$VER_LOC_ID/appScreenshotSets")

    for screenshot in "$locale_dir"/*.png; do
        [[ -f "$screenshot" ]] || continue
        FILENAME=$(basename "$screenshot")
        FILESIZE=$(stat -f%z "$screenshot")
        # Cheap PNG header parse: width @ bytes 16-19, height @ 20-23.
        DIMS=$(python3 -c "
import struct, sys
with open('$screenshot','rb') as f:
    f.seek(16); w,h = struct.unpack('>II', f.read(8))
print(w, h)")
        WIDTH="${DIMS% *}"
        HEIGHT="${DIMS#* }"
        DISPLAY_TYPE=$(display_type_for "$WIDTH" "$HEIGHT")
        if [[ -z "$DISPLAY_TYPE" ]]; then
            echo "    !! $FILENAME: unrecognised size ${WIDTH}x${HEIGHT}, skipping"
            continue
        fi

        SET_ID=$(echo "$EXISTING_SETS_JSON" | DT="$DISPLAY_TYPE" jq_py "
import sys, json, os
dt = os.environ['DT']
sets = json.load(sys.stdin)['data']
match = [s['id'] for s in sets if s['attributes']['screenshotDisplayType'] == dt]
print(match[0] if match else '')
")
        if [[ -z "$SET_ID" ]]; then
            BODY=$(DT="$DISPLAY_TYPE" LOC="$VER_LOC_ID" python3 -c '
import json, os
print(json.dumps({"data": {
    "type": "appScreenshotSets",
    "attributes": {"screenshotDisplayType": os.environ["DT"]},
    "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": os.environ["LOC"]}}}
}}))
')
            SET_ID=$(asc_post "/appScreenshotSets" "$BODY" \
                | jq_py "import sys, json; print(json.load(sys.stdin)['data']['id'])")
            echo "    created $DISPLAY_TYPE set $SET_ID"
            EXISTING_SETS_JSON=$(asc_get "/appStoreVersionLocalizations/$VER_LOC_ID/appScreenshotSets")
        fi

        echo "    $FILENAME (${WIDTH}x${HEIGHT}, $FILESIZE bytes) → $DISPLAY_TYPE"

        # Reserve.
        BODY=$(FN="$FILENAME" FS="$FILESIZE" SID="$SET_ID" python3 -c '
import json, os
print(json.dumps({"data": {
    "type": "appScreenshots",
    "attributes": {"fileName": os.environ["FN"], "fileSize": int(os.environ["FS"])},
    "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": os.environ["SID"]}}}
}}))
')
        RESERVATION=$(asc_post "/appScreenshots" "$BODY")
        SCREENSHOT_ID=$(echo "$RESERVATION" | jq_py "import sys, json; print(json.load(sys.stdin)['data']['id'])")

        # The uploadOperations entry tells us the URL, method, and per-chunk
        # headers required for this specific reservation. We only ever upload
        # one chunk because the files are small, but we MUST replay the headers
        # Apple specifies — they include an authentication token.
        UP_METHOD=$(echo "$RESERVATION" \
            | jq_py "import sys, json; print(json.load(sys.stdin)['data']['attributes']['uploadOperations'][0]['method'])")
        UP_URL=$(echo "$RESERVATION" \
            | jq_py "import sys, json; print(json.load(sys.stdin)['data']['attributes']['uploadOperations'][0]['url'])")
        UP_HEADER_ARGS=()
        while IFS=$'\t' read -r header_name header_value; do
            UP_HEADER_ARGS+=(-H "$header_name: $header_value")
        done < <(echo "$RESERVATION" | jq_py "
import sys, json
op = json.load(sys.stdin)['data']['attributes']['uploadOperations'][0]
for header in op.get('requestHeaders', []):
    print(header['name'], header['value'], sep='\\t')
")

        # Upload bytes. We want the response code, not just a silent exit.
        UPLOAD_STATUS=$(curl -sS --globoff -o /dev/null -w '%{http_code}' \
            -X "$UP_METHOD" "${UP_HEADER_ARGS[@]}" --data-binary "@$screenshot" "$UP_URL")
        if [[ "$UPLOAD_STATUS" -ge 400 ]]; then
            echo "    !! upload PUT returned $UPLOAD_STATUS; aborting"
            exit 1
        fi

        # Commit (sourceFileChecksum is a plain string, not an object).
        MD5=$(md5 -q "$screenshot")
        BODY=$(SID="$SCREENSHOT_ID" MD5="$MD5" python3 -c '
import json, os
print(json.dumps({"data": {
    "type": "appScreenshots",
    "id": os.environ["SID"],
    "attributes": {"uploaded": True, "sourceFileChecksum": os.environ["MD5"]}
}}))
')
        asc_patch "/appScreenshots/$SCREENSHOT_ID" "$BODY" > /dev/null

        # Poll until processed. App Store rejects anything that didn't reach
        # COMPLETE — silent "Uploaded" prints from the old script masked this.
        for attempt in $(seq 1 20); do
            STATE=$(asc_get "/appScreenshots/$SCREENSHOT_ID" \
                | jq_py "import sys, json; print(json.load(sys.stdin)['data']['attributes']['assetDeliveryState']['state'])")
            case "$STATE" in
                COMPLETE) echo "    ✓ processed"; break ;;
                UPLOAD_COMPLETE|PROCESSING) sleep 3 ;;
                *) echo "    !! unexpected assetDeliveryState=$STATE; aborting"; exit 1 ;;
            esac
            [[ $attempt -eq 20 ]] && { echo "    !! timed out waiting for COMPLETE"; exit 1; }
        done
    done
done

echo
echo "Done. Verify at https://appstoreconnect.apple.com"
