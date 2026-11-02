#!/bin/bash
# Renders the app icon PNGs from DesignAssets/Icon.svg.
# Light uses the SVG as is; dark and tinted swap it to a white glyph on black
# (iOS tints the tinted variant by luminance, so it shares the dark artwork).
# Outputs are opaque RGB with no alpha, as App Store Connect requires.
# Requires librsvg and ImageMagick: brew install librsvg imagemagick
# Usage: scripts/generate-app-icons.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/DesignAssets/Icon.svg"
ICONSET="$ROOT/Cards/Assets.xcassets/AppIcon.appiconset"
DESIGN="$ROOT/DesignAssets"
WEB_ICON="$ROOT/Website/src/icon.png"

LIGHT_BG="#FFFFFF"
LIGHT_FG="#0A0A0A"
DARK_BG="#000000"
DARK_FG="#FFFFFF"

for tool in rsvg-convert magick; do
    command -v "$tool" >/dev/null || { echo "Error: $tool not found (brew install librsvg imagemagick)" >&2; exit 1; }
done

WORK="$(mktemp -d)"
trap 'command rm -rf "$WORK"' EXIT

sed -e "s/$LIGHT_BG/@BG@/g" -e "s/$LIGHT_FG/@FG@/g" \
    -e "s/@BG@/$DARK_BG/g" -e "s/@FG@/$DARK_FG/g" "$SRC" > "$WORK/dark.svg"

render() {
    local svg="$1" size="$2" out="$3"
    rsvg-convert -w "$size" -h "$size" "$svg" -o "$WORK/raw.png"
    magick "$WORK/raw.png" -alpha off -strip -define png:color-type=2 "$out"
}

render "$SRC" 1024 "$ICONSET/Icon.png"
render "$WORK/dark.svg" 1024 "$ICONSET/Icon-Dark.png"
render "$WORK/dark.svg" 1024 "$ICONSET/Icon-Tinted.png"

command cp -f "$ICONSET/Icon.png" "$ICONSET/Icon-Dark.png" "$ICONSET/Icon-Tinted.png" "$DESIGN/"

# apple-touch-icon referenced by Website/src/index.html
render "$SRC" 180 "$WEB_ICON"

echo "App icons written to $ICONSET, $DESIGN and $WEB_ICON"
