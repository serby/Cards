// Checks that every App Store image the listing uploads is present: for each
// locale in metadata/, screenshots/store/<locale>/ has one image per caption in
// its captions.json for each device (iPhone, iPad and iPhone Duo). It is the
// only screenshot check CI runs; capturing, composing and looking at the images
// happen locally before they are committed (docs/DEVELOPMENT.md).
//
// Usage: node scripts/check-store-images.ts

import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

const root = join(import.meta.dirname, "..");
/// The file name suffix of each device's image, as StoreScreenshotTests writes them.
const deviceSuffixes = ["", "_iPad", "_Duo"];

interface Caption {
    file: string;
}

function locales(): string[] {
    const metadata = join(root, "metadata");
    return readdirSync(metadata).filter((name) => statSync(join(metadata, name)).isDirectory()).sort();
}

const missing: string[] = [];
let found = 0;
for (const locale of locales()) {
    const folder = join(root, "screenshots", "store", locale);
    const captionsPath = join(folder, "captions.json");
    if (!existsSync(captionsPath)) {
        missing.push(`screenshots/store/${locale}/captions.json`);
        continue;
    }
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

if (missing.length > 0) {
    console.error(`Missing App Store images (run make store-screenshots):\n${missing.map((path) => `  ${path}`).join("\n")}`);
    process.exit(1);
}
console.log(`All ${found} App Store images are present.`);
