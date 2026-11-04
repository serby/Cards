#!/bin/bash
# Capture App Store screenshots by running the screenshot UI test on a target
# simulator, then extracting the attachments into screenshots/<locale>/.
#
# Usage:
#   scripts/capture-screenshots.sh                         # iPhone 16 Pro Max, en-US
#   scripts/capture-screenshots.sh "iPad Pro 13-inch (M4)" en-GB
#   scripts/capture-screenshots.sh "iPhone Duo" en-GB             # outer display, "_Duo" names
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DEVICE="${1:-iPhone 16 Pro Max}"
LOCALE="${2:-en-US}"
OUT_DIR="$PROJECT_DIR/screenshots/$LOCALE"
RESULT_BUNDLE="/tmp/Cards-screenshots.xcresult"
EXPORT_DIR="/tmp/Cards-screenshots-export"
# Which screenshots the test takes, and the suffix it gives their names.
CAPTURE_SET="iphone"
SUFFIX=""
if [[ "$DEVICE" == iPad* ]]; then
    CAPTURE_SET="ipad"
elif [[ "$DEVICE" == "iPhone Duo" ]]; then
    CAPTURE_SET="duo"
    SUFFIX="_Duo"
fi
LANGUAGE="${LOCALE%%-*}"
REGION="${LOCALE#*-}"
source "$SCRIPT_DIR/xcode-env.sh"

cd "$PROJECT_DIR"

echo "==> Resolving simulator"
SIM_INFO=$("$SCRIPT_DIR/ci-resolve-sim.sh" "$DEVICE")
SIM_NAME=$(printf '%s\n' "$SIM_INFO" | sed -n 's/^device=//p')
SIM_VERSION=$(printf '%s\n' "$SIM_INFO" | sed -n 's/^version=//p')

echo "==> Running screenshot test on $SIM_NAME (iOS $SIM_VERSION)"
rm -rf "$RESULT_BUNDLE" "$EXPORT_DIR"
TEST_RUNNER_SCREENSHOT_SUFFIX="$SUFFIX" xcodebuild test \
    -project Cards.xcodeproj \
    -scheme Cards \
    -destination "platform=iOS Simulator,name=$SIM_NAME,OS=$SIM_VERSION" \
    -only-testing:CardsUITests/CardsScreenshotTests/testCaptureScreenshots \
    -testLanguage "$LANGUAGE" \
    -testRegion "$REGION" \
    -enableCodeCoverage NO \
    -collect-test-diagnostics never \
    -resultBundlePath "$RESULT_BUNDLE"

echo "==> Extracting attachments"
xcrun xcresulttool export attachments \
    --path "$RESULT_BUNDLE" \
    --output-path "$EXPORT_DIR"

mkdir -p "$OUT_DIR"
# manifest.json maps attachment names to exported files. Apple suggests
# "<our-name>_<iter>_<UUID>.png"; trimming from "_<iter>_" gets our name back.
EXPORT_DIR="$EXPORT_DIR" OUT_DIR="$OUT_DIR" CAPTURE_SET="$CAPTURE_SET" node --input-type=module -e '
import { copyFileSync, readFileSync } from "node:fs";
import { join } from "node:path";
const { EXPORT_DIR: exportDir, OUT_DIR: outDir, CAPTURE_SET: set } = process.env;
const screens = ["01_CardList", "02_CardDetail", "03_EditCard", "04_LocationPicker"];
const expected = new Set({
    iphone: screens,
    ipad: ["01_CardList_iPad", "02_CardDetail_iPad"],
    duo: screens.map((name) => name + "_Duo"),
}[set]);
const seen = new Set();
for (const entry of JSON.parse(readFileSync(join(exportDir, "manifest.json"), "utf8"))) {
    for (const attachment of entry.attachments ?? []) {
        const raw = attachment.suggestedHumanReadableName ?? attachment.exportedFileName ?? "";
        const name = raw.replace(/_\d+_[0-9A-Fa-f-]{36}\.png$/, "");
        if (!expected.has(name)) continue;
        copyFileSync(join(exportDir, attachment.exportedFileName), join(outDir, name + ".png"));
        seen.add(name);
    }
}
const missing = [...expected].filter((name) => !seen.has(name));
if (missing.length > 0) throw new Error("Missing screenshot attachments: " + missing.join(", "));
console.log("Copied:", [...seen].sort().join(", "));
'

python3 "$SCRIPT_DIR/validate-screenshots.py"

echo
echo "==> Screenshots in $OUT_DIR:"
ls -la "$OUT_DIR"
echo
echo "Check them, commit, push, then run the App Store screenshots workflow to upload."
