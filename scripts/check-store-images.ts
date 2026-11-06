// Checks that every App Store image the listing uploads is present: for each
// locale in metadata/, screenshots/store/<locale>/ has one image per caption in
// its captions.json for each device (iPhone, iPad and iPhone Duo), and the
// universal creative asset its creative-asset.json names. If any locale has a
// creative asset, every locale must, because Apple asks for one in every
// language the listing has. The asset must be a 5244 x 2950 PNG with no alpha
// channel, as App Store Connect requires. It is the only screenshot check CI
// runs; capturing, composing and looking at the images happen locally before
// they are committed (docs/DEVELOPMENT.md).
//
// Usage: node scripts/check-store-images.ts

import { closeSync, existsSync, openSync, readdirSync, readFileSync, readSync, statSync } from "node:fs";
import { join } from "node:path";

const root = join(import.meta.dirname, "..");
/// The file name suffix of each device's image, as StoreScreenshotTests writes them.
const deviceSuffixes = ["", "_iPad", "_Duo"];
/// The universal creative asset's size in pixels, as StoreCreativeAsset draws it.
const creativeAssetSize = { width: 5244, height: 2950 };
/// PNG colour types with no alpha channel: greyscale and RGB.
const opaqueColourTypes = new Set([0, 2]);

interface Caption {
    file: string;
}

interface CreativeAsset {
    file: string;
}

function locales(): string[] {
    const metadata = join(root, "metadata");
    return readdirSync(metadata).filter((name) => statSync(join(metadata, name)).isDirectory()).sort();
}

/// A PNG's size and colour type, from its IHDR chunk, which comes first.
function pngHeader(path: string): { width: number; height: number; colourType: number } | undefined {
    const header = Buffer.alloc(26);
    const file = openSync(path, "r");
    try {
        if (readSync(file, header, 0, header.length, 0) < header.length) return undefined;
    } finally {
        closeSync(file);
    }
    if (header.toString("latin1", 1, 4) !== "PNG" || header.toString("latin1", 12, 16) !== "IHDR") return undefined;
    return { width: header.readUInt32BE(16), height: header.readUInt32BE(20), colourType: header.readUInt8(25) };
}

const missing: string[] = [];
const wrong: string[] = [];
let found = 0;
const localeList = locales();
const withCreativeAsset = localeList.filter((locale) => existsSync(join(root, "screenshots", "store", locale, "creative-asset.json")));
for (const locale of localeList) {
    const folder = join(root, "screenshots", "store", locale);
    const captionsPath = join(folder, "captions.json");
    if (!existsSync(captionsPath)) {
        missing.push(`screenshots/store/${locale}/captions.json`);
    } else {
        const captions = JSON.parse(readFileSync(captionsPath, "utf8")) as Caption[];
        for (const caption of captions) {
            for (const suffix of deviceSuffixes) {
                const name = `${caption.file}${suffix}.png`;
                if (existsSync(join(folder, name))) {
                    found += 1;
                } else {
                    missing.push(`screenshots/store/${locale}/${name}`);
                }
            }
        }
    }

    const creativeAssetPath = join(folder, "creative-asset.json");
    if (!existsSync(creativeAssetPath)) {
        if (withCreativeAsset.length > 0) missing.push(`screenshots/store/${locale}/creative-asset.json (${withCreativeAsset.join(", ")} have one)`);
        continue;
    }
    const asset = JSON.parse(readFileSync(creativeAssetPath, "utf8")) as CreativeAsset;
    const path = join(folder, `${asset.file}.png`);
    if (!existsSync(path)) {
        missing.push(`screenshots/store/${locale}/${asset.file}.png`);
        continue;
    }
    found += 1;
    const header = pngHeader(path);
    if (!header) {
        wrong.push(`screenshots/store/${locale}/${asset.file}.png is not a PNG`);
    } else if (header.width !== creativeAssetSize.width || header.height !== creativeAssetSize.height) {
        wrong.push(`screenshots/store/${locale}/${asset.file}.png is ${header.width} x ${header.height}, not ${creativeAssetSize.width} x ${creativeAssetSize.height}`);
    } else if (!opaqueColourTypes.has(header.colourType)) {
        wrong.push(`screenshots/store/${locale}/${asset.file}.png has an alpha channel (PNG colour type ${header.colourType})`);
    }
}

if (missing.length > 0) {
    console.error(`Missing App Store images (run make store-screenshots):\n${missing.map((path) => `  ${path}`).join("\n")}`);
}
if (wrong.length > 0) {
    console.error(`App Store images App Store Connect would refuse:\n${wrong.map((problem) => `  ${problem}`).join("\n")}`);
}
if (missing.length > 0 || wrong.length > 0) process.exit(1);
console.log(`All ${found} App Store images are present.`);
