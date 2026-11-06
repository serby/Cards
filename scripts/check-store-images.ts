// Checks the App Store images the listing uploads, for every store locale (each
// folder in metadata/): screenshots/store/<locale>/ has one image per caption in
// its captions.json for each device (iPhone, iPad and iPhone Duo), and the
// universal creative asset its creative-asset.json names. If any locale has a
// creative asset, every locale must, because Apple asks for one in every
// language the listing has. The asset must be a 5244 x 2950 PNG with no alpha
// channel, as App Store Connect requires. No caption's title or subtitle, and
// no creative asset's title, has the word "free" in the listing's language,
// which App Store Review Guideline 2.3.7 keeps out of screenshots. It is the
// only screenshot check CI runs; capturing, composing and looking at the images
// happen locally before they are committed (docs/DEVELOPMENT.md).
//
// Usage: node scripts/check-store-images.ts

import { closeSync, existsSync, openSync, readFileSync, readSync } from "node:fs";
import { join } from "node:path";
import { priceWord } from "./check-metadata.ts";
import { storeLocales } from "./lib/locales.ts";

const root = join(import.meta.dirname, "..");
/// The file name suffix of each device's image, as StoreScreenshotTests writes them.
const deviceSuffixes = ["", "_iPad", "_Duo"];
/// The universal creative asset's size in pixels, as StoreCreativeAsset draws it.
const creativeAssetSize = { width: 5244, height: 2950 };
/// PNG colour types with no alpha channel: greyscale and RGB.
const opaqueColourTypes = new Set([0, 2]);

interface Caption {
    file: string;
    title?: string;
    subtitle?: string;
}

interface CreativeAsset {
    file: string;
    title?: string;
}

export interface StoreImagesReport {
    /// Images, captions.json and creative-asset.json files that should be there
    /// and are not, relative to the root.
    missing: string[];
    /// Everything else wrong: price words, and images App Store Connect would refuse.
    problems: string[];
    /// How many images are present.
    found: number;
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

function checkPrice(report: StoreImagesReport, file: string, what: string, text: string | undefined, locale: string): void {
    const word = priceWord(text ?? "", locale);
    if (word) report.problems.push(`${file}: ${what} has "${word}"; App Store Review Guideline 2.3.7 keeps price words out of screenshots and their captions`);
}

export function checkStoreImages(rootDir: string = root): StoreImagesReport {
    const report: StoreImagesReport = { missing: [], problems: [], found: 0 };
    const locales = storeLocales(rootDir);
    const withCreativeAsset = locales.filter((locale) => existsSync(join(rootDir, "screenshots", "store", locale, "creative-asset.json")));
    for (const locale of locales) {
        const folder = join(rootDir, "screenshots", "store", locale);
        const captionsPath = join(folder, "captions.json");
        if (!existsSync(captionsPath)) {
            report.missing.push(`screenshots/store/${locale}/captions.json`);
        } else {
            const captions = JSON.parse(readFileSync(captionsPath, "utf8")) as Caption[];
            for (const caption of captions) {
                for (const field of ["title", "subtitle"] as const) {
                    checkPrice(report, `screenshots/store/${locale}/captions.json`, `${caption.file}'s ${field}`, caption[field], locale);
                }
                for (const suffix of deviceSuffixes) {
                    const name = `${caption.file}${suffix}.png`;
                    if (existsSync(join(folder, name))) {
                        report.found += 1;
                    } else {
                        report.missing.push(`screenshots/store/${locale}/${name}`);
                    }
                }
            }
        }

        const creativeAssetPath = join(folder, "creative-asset.json");
        if (!existsSync(creativeAssetPath)) {
            if (withCreativeAsset.length > 0) {
                report.missing.push(`screenshots/store/${locale}/creative-asset.json (${withCreativeAsset.join(", ")} have one)`);
            }
            continue;
        }
        const asset = JSON.parse(readFileSync(creativeAssetPath, "utf8")) as CreativeAsset;
        checkPrice(report, `screenshots/store/${locale}/creative-asset.json`, "the title", asset.title, locale);
        const path = join(folder, `${asset.file}.png`);
        if (!existsSync(path)) {
            report.missing.push(`screenshots/store/${locale}/${asset.file}.png`);
            continue;
        }
        report.found += 1;
        const header = pngHeader(path);
        const name = `screenshots/store/${locale}/${asset.file}.png`;
        if (!header) {
            report.problems.push(`${name} is not a PNG`);
        } else if (header.width !== creativeAssetSize.width || header.height !== creativeAssetSize.height) {
            report.problems.push(`${name} is ${header.width} x ${header.height}, not ${creativeAssetSize.width} x ${creativeAssetSize.height}`);
        } else if (!opaqueColourTypes.has(header.colourType)) {
            report.problems.push(`${name} has an alpha channel (PNG colour type ${header.colourType})`);
        }
    }
    return report;
}

if (import.meta.main) {
    const { missing, problems, found } = checkStoreImages();
    if (missing.length > 0) console.error(`Missing App Store images (run make store-screenshots):\n${missing.map((path) => `  ${path}`).join("\n")}`);
    if (problems.length > 0) console.error(`Problems with the App Store images:\n${problems.map((problem) => `  ${problem}`).join("\n")}`);
    if (missing.length > 0 || problems.length > 0) process.exit(1);
    console.log(`All ${found} App Store images are present.`);
}
