#!/bin/bash
# Capture App Store screenshots by running the screenshot UI test on a target
# simulator, then extracting the attachments into screenshots/<locale>/.
#
# Usage:
#   scripts/capture-screenshots.sh                         # iPhone 16 Pro Max, en-US
#   scripts/capture-screenshots.sh "iPad Pro 13-inch (M4)" en-GB
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
XCODE_APP="${XCODE_APP:-/Applications/Xcode.27.1.app}"
DEVICE="${1:-iPhone 16 Pro Max}"
LOCALE="${2:-en-US}"
OUT_DIR="$PROJECT_DIR/screenshots/$LOCALE"
RESULT_BUNDLE="/tmp/Cards-screenshots.xcresult"
EXPORT_DIR="/tmp/Cards-screenshots-export"
CAPTURE_SET="iphone"
if [[ "$DEVICE" == iPad* ]]; then
    CAPTURE_SET="ipad"
fi
LANGUAGE="${LOCALE%%-*}"
REGION="${LOCALE#*-}"
export DEVELOPER_DIR="$XCODE_APP/Contents/Developer"

cd "$PROJECT_DIR"

# Ensure the xcodeproj is current.
echo "==> Generating Xcode project"
bazel run //:xcodeproj
chmod -R u+w Cards.xcodeproj

echo "==> Resolving simulator"
SIM_INFO=$("$SCRIPT_DIR/ci-resolve-sim.sh" "$DEVICE")
SIM_NAME=$(printf '%s\n' "$SIM_INFO" | sed -n 's/^device=//p')
SIM_VERSION=$(printf '%s\n' "$SIM_INFO" | sed -n 's/^version=//p')

echo "==> Running screenshot test on $SIM_NAME (iOS $SIM_VERSION)"
rm -rf "$RESULT_BUNDLE" "$EXPORT_DIR"
xcodebuild test \
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
# manifest.json maps original attachment names → exported filenames. The
# suggestedHumanReadableName Apple returns is "<our-name>_<iter>_<UUID>.png";
# we strip everything from "_0_" onwards to get back to our chosen prefix.
EXPORT_DIR="$EXPORT_DIR" OUT_DIR="$OUT_DIR" CAPTURE_SET="$CAPTURE_SET" python3 - <<'PY'
import json, os, re, shutil
export_dir = os.environ["EXPORT_DIR"]
out_dir = os.environ["OUT_DIR"]
capture_set = os.environ["CAPTURE_SET"]
manifest_path = os.path.join(export_dir, "manifest.json")
with open(manifest_path) as f:
    manifest = json.load(f)

expected = {
    "iphone": {"01_CardList", "02_AddCard", "03_Settings"},
    "ipad": {"01_CardList_iPad"},
}[capture_set]
seen = set()
for entry in manifest:
    for att in entry.get("attachments", []):
        raw = att.get("suggestedHumanReadableName") or att.get("exportedFileName", "")
        # Trim Apple's "_<iter>_<UUID>.png" suffix back to our prefix.
        clean = re.sub(r"_\d+_[0-9A-Fa-f-]{36}\.png$", "", raw)
        if clean not in expected:
            continue
        src = os.path.join(export_dir, att["exportedFileName"])
        dst = os.path.join(out_dir, f"{clean}.png")
        shutil.copyfile(src, dst)
        seen.add(clean)
missing = expected - seen
if missing:
    raise SystemExit(f"Missing screenshot attachments: {sorted(missing)}")
print("Copied:", sorted(seen))
PY

python3 "$SCRIPT_DIR/validate-screenshots.py"

echo
echo "==> Screenshots in $OUT_DIR:"
ls -la "$OUT_DIR"
echo
echo "Verify dimensions, then upload with: scripts/upload-screenshots.sh"
