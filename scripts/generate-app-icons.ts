// Renders the app icon PNGs from DesignAssets/Icon.svg.
// Light uses the SVG as is; dark and tinted swap it to a white glyph on black
// (iOS tints the tinted variant by luminance, so it shares the dark artwork).
// The Apple Watch app's single icon is the light artwork, which watchOS masks
// to a circle; the cards sit well inside it.
// Outputs are opaque RGB with no alpha, as App Store Connect requires.
// Requires librsvg and ImageMagick: brew install librsvg imagemagick
//
// Usage: node scripts/generate-app-icons.ts

import { execFileSync } from "node:child_process";
import { accessSync, constants, copyFileSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { basename, delimiter, join } from "node:path";

const root = join(import.meta.dirname, "..");
const source = join(root, "DesignAssets", "Icon.svg");
const iconSet = join(root, "Cards", "Assets.xcassets", "AppIcon.appiconset");
const watchIconSet = join(root, "CardsWatch", "Assets.xcassets", "AppIcon.appiconset");
const design = join(root, "DesignAssets");
const webIcon = join(root, "Website", "static", "icon.png");

const light = { background: "#FFFFFF", foreground: "#0A0A0A" };
const dark = { background: "#000000", foreground: "#FFFFFF" };

/// Whether a command is on PATH, as `command -v` would find it.
function onPath(command: string): boolean {
    return (process.env.PATH ?? "").split(delimiter).some((directory) => {
        try {
            accessSync(join(directory, command), constants.X_OK);
            return true;
        } catch {
            return false;
        }
    });
}

for (const tool of ["rsvg-convert", "magick"]) {
    if (!onPath(tool)) {
        console.error(`Error: ${tool} not found (brew install librsvg imagemagick)`);
        process.exit(1);
    }
}

const work = mkdtempSync(join(tmpdir(), "cards-icons-"));
try {
    // Swap the light colours for the dark ones through placeholders, so the
    // light background (white) and the dark foreground (also white) never collide.
    const darkSVG = join(work, "dark.svg");
    const svg = readFileSync(source, "utf8")
        .replaceAll(light.background, "@BG@")
        .replaceAll(light.foreground, "@FG@")
        .replaceAll("@BG@", dark.background)
        .replaceAll("@FG@", dark.foreground);
    writeFileSync(darkSVG, svg);

    const render = (svgPath: string, size: number, output: string): void => {
        const raw = join(work, "raw.png");
        execFileSync("rsvg-convert", ["-w", String(size), "-h", String(size), svgPath, "-o", raw], { stdio: "inherit" });
        execFileSync("magick", [raw, "-alpha", "off", "-strip", "-define", "png:color-type=2", output], { stdio: "inherit" });
    };

    const lightIcon = join(iconSet, "Icon.png");
    const darkIcon = join(iconSet, "Icon-Dark.png");
    const tintedIcon = join(iconSet, "Icon-Tinted.png");
    render(source, 1024, lightIcon);
    render(darkSVG, 1024, darkIcon);
    render(darkSVG, 1024, tintedIcon);

    for (const icon of [lightIcon, darkIcon, tintedIcon]) copyFileSync(icon, join(design, basename(icon)));

    render(source, 1024, join(watchIconSet, "Icon.png"));

    // The apple-touch-icon the website's pages link to.
    render(source, 180, webIcon);
} finally {
    rmSync(work, { recursive: true, force: true });
}

console.log(`App icons written to ${iconSet}, ${watchIconSet}, ${design} and ${webIcon}`);
