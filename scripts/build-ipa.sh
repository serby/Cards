#!/bin/bash
# Archive the app in Release and export a distribution .ipa.
#
# Prints the path to the exported .ipa on stdout (and nothing else), so callers
# can capture it:
#
#   IPA=$(scripts/build-ipa.sh)
#
# Signing defaults to manual against the App Store profile that CI installs
# into ~/Library/MobileDevice/Provisioning Profiles. Override with:
#   PROVISIONING_PROFILE_SPECIFIER  profile name (default below)
#   CODE_SIGN_IDENTITY              signing identity (default "Apple Distribution")
#   EXPORT_METHOD                   app-store-connect | release-testing | debugging
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

XCODE_APP="${XCODE_APP:-/Applications/Xcode27.1.app}"
export DEVELOPER_DIR="$XCODE_APP/Contents/Developer"

TEAM_ID="${DEVELOPMENT_TEAM:-ZMBFPG86J4}"
BUNDLE_ID="${PRODUCT_BUNDLE_IDENTIFIER:-net.serby.Cards}"
PROFILE="${PROVISIONING_PROFILE_SPECIFIER:-Card Codes Wallet App Store Profile}"
IDENTITY="${CODE_SIGN_IDENTITY:-Apple Distribution}"
METHOD="${EXPORT_METHOD:-app-store-connect}"

BUILD_DIR="$PROJECT_DIR/build/release"
ARCHIVE_PATH="$BUILD_DIR/Cards.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"

cd "$PROJECT_DIR"
rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"
mkdir -p "$BUILD_DIR"

# Generated rather than checked in: it embeds the team and profile name, and we
# want env overrides to take effect without editing a tracked file.
cat > "$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>${METHOD}</string>
	<key>teamID</key>
	<string>${TEAM_ID}</string>
	<key>signingStyle</key>
	<string>manual</string>
	<key>signingCertificate</key>
	<string>${IDENTITY}</string>
	<key>provisioningProfiles</key>
	<dict>
		<key>${BUNDLE_ID}</key>
		<string>${PROFILE}</string>
	</dict>
	<key>stripSwiftSymbols</key>
	<true/>
	<key>uploadSymbols</key>
	<true/>
	<key>destination</key>
	<string>export</string>
</dict>
</plist>
PLIST

echo "==> Archiving (Release)" >&2
xcodebuild archive \
	-project Cards.xcodeproj \
	-scheme Cards \
	-configuration Release \
	-destination 'generic/platform=iOS' \
	-archivePath "$ARCHIVE_PATH" \
	-derivedDataPath "$BUILD_DIR/dd" \
	CODE_SIGN_STYLE=Manual \
	DEVELOPMENT_TEAM="$TEAM_ID" \
	PROVISIONING_PROFILE_SPECIFIER="$PROFILE" \
	CODE_SIGN_IDENTITY="$IDENTITY" >&2

echo "==> Exporting .ipa" >&2
xcodebuild -exportArchive \
	-archivePath "$ARCHIVE_PATH" \
	-exportOptionsPlist "$EXPORT_OPTIONS" \
	-exportPath "$EXPORT_DIR" >&2

IPA=$(find "$EXPORT_DIR" -maxdepth 1 -name '*.ipa' -type f | head -n 1)
if [[ -z "$IPA" ]]; then
	echo "error: no .ipa produced in $EXPORT_DIR" >&2
	exit 1
fi

echo "$IPA"
