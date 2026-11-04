#!/bin/bash
# Archive the app in Release and export a distribution .ipa.
#
# Prints the path to the exported .ipa on stdout (and nothing else), so callers
# can capture it:
#
#   IPA=$(scripts/build-ipa.sh)
#
# Signing is manual, against the App Store profiles scripts/asc-profiles.ts
# installs into ~/Library/MobileDevice/Provisioning Profiles: one for the app and
# one for its widget. Override with:
#   CARDS_APP_PROFILE      the app's profile name (default below)
#   CARDS_WIDGET_PROFILE   the widget's profile name (default below)
#   CODE_SIGN_IDENTITY     signing identity (default "Apple Distribution")
#   EXPORT_METHOD          app-store-connect | release-testing | debugging
#   BUILD_NUMBER           CFBundleVersion for the app and widget (default: the project's)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/xcode-env.sh"

TEAM_ID="${DEVELOPMENT_TEAM:-ZMBFPG86J4}"
APP_ID="net.serby.Cards"
WIDGET_ID="net.serby.Cards.Widget"
APP_PROFILE="${CARDS_APP_PROFILE:-Cards CI App Store $APP_ID}"
WIDGET_PROFILE="${CARDS_WIDGET_PROFILE:-Cards CI App Store $WIDGET_ID}"
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
		<key>${APP_ID}</key>
		<string>${APP_PROFILE}</string>
		<key>${WIDGET_ID}</key>
		<string>${WIDGET_PROFILE}</string>
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

# The app and the widget must carry the same CFBundleVersion, so it is set once,
# for every target, rather than in either Info.plist.
VERSION_ARGS=()
if [[ -n "${BUILD_NUMBER:-}" ]]; then
	VERSION_ARGS=(CURRENT_PROJECT_VERSION="$BUILD_NUMBER")
fi

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
	CARDS_APP_PROFILE="$APP_PROFILE" \
	CARDS_WIDGET_PROFILE="$WIDGET_PROFILE" \
	CODE_SIGN_IDENTITY="$IDENTITY" \
	${VERSION_ARGS[@]+"${VERSION_ARGS[@]}"} >&2

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
