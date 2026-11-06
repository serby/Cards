// Checks the App Store images the listing uploads, for every store locale (each
// folder in metadata/): screenshots/store/<locale>/ has one image per caption in
// its captions.json for each device (iPhone, iPad and iPhone Duo), and no
// caption's title or subtitle has the word "free" in the listing's language,
// which App Store Review Guideline 2.3.7 keeps out of screenshot captions. It is
// the only screenshot check CI runs; capturing, composing and looking at the
// images happen locally before they are committed (docs/DEVELOPMENT.md).
//
// Usage: node scripts/check-store-images.ts

import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { priceWord } from "./check-metadata.ts";
import { storeLocales } from "./lib/locales.ts";

const root = join(import.meta.dirname, "..");
/// The file name suffix of each device's image, as StoreScreenshotTests writes them.
const deviceSuffixes = ["", "_iPad", "_Duo"];

interface Caption {
    file: string;
    title?: string;
    subtitle?: string;
}

export interface StoreImagesReport {
    /// Images and captions.json files that should be there and are not, relative to the root.
    missing: string[];
    /// Everything else wrong with the captions.
    problems: string[];
    /// How many images are present.
    found: number;
}

export function checkStoreImages(rootDir: string = root): StoreImagesReport {
    const report: StoreImagesReport = { missing: [], problems: [], found: 0 };
    for (const locale of storeLocales(rootDir)) {
        const folder = join(rootDir, "screenshots", "store", locale);
        const captionsPath = join(folder, "captions.json");
        if (!existsSync(captionsPath)) {
            report.missing.push(`screenshots/store/${locale}/captions.json`);
            continue;
        }
        const captions = JSON.parse(readFileSync(captionsPath, "utf8")) as Caption[];
        for (const caption of captions) {
            for (const field of ["title", "subtitle"] as const) {
                const word = priceWord(caption[field] ?? "", locale);
                if (word) report.problems.push(`screenshots/store/${locale}/captions.json: ${caption.file}'s ${field} has "${word}"; App Store Review Guideline 2.3.7 keeps price words out of screenshot captions`);
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
    return report;
}

if (import.meta.main) {
    const { missing, problems, found } = checkStoreImages();
    if (missing.length > 0) console.error(`Missing App Store images (run make store-screenshots):\n${missing.map((path) => `  ${path}`).join("\n")}`);
    for (const problem of problems) console.error(problem);
    if (missing.length > 0 || problems.length > 0) process.exit(1);
    console.log(`All ${found} App Store images are present.`);
}
