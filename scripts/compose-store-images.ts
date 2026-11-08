// Composes the App Store images from the raw captures (make capture-screenshots),
// each locale's captions.json and the vector templates in screenshots/templates/
// (lib/store-images.ts), into screenshots/store/<locale>/<file><suffix>.png.
// Devices without a template yet are left out and listed.
//
// Usage: node scripts/compose-store-images.ts [--device <name>]... [--locale <locale>]... [--out <dir>]
//   --device   iPhone, iPad or Duo; repeat for more; every device with a template unless given
//   --locale   a store locale; repeat for more; every locale with a captions.json unless given
//   --out      where the images go instead of screenshots/store/<locale>/, as <out>/<locale>/

import { existsSync, mkdirSync, readdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { parseArgs } from "node:util";
import { composeStoreImage, readCaptions, root, storeDevices, templatesDir } from "./lib/store-images.ts";

const usage = "Usage: node scripts/compose-store-images.ts [--device <name>]... [--locale <locale>]... [--out <dir>]";
let options: { device?: string[]; locale?: string[]; out?: string };
try {
    options = parseArgs({
        options: { device: { type: "string", multiple: true }, locale: { type: "string", multiple: true }, out: { type: "string" } },
        allowPositionals: false,
    }).values as typeof options;
} catch (error) {
    console.error(`${error instanceof Error ? error.message : String(error)}\n${usage}`);
    process.exit(2);
}

const store = join(root, "screenshots", "store");
const locales = options.locale ?? readdirSync(store).filter((locale) => existsSync(join(store, locale, "captions.json"))).sort();
const chosen = options.device ? storeDevices.filter((device) => options.device!.includes(device.name)) : storeDevices;
const unknown = (options.device ?? []).filter((name) => !storeDevices.some((device) => device.name === name));
if (unknown.length > 0) {
    console.error(`Unknown device ${unknown.join(", ")}: one of ${storeDevices.map((device) => device.name).join(", ")}\n${usage}`);
    process.exit(2);
}
const devices = chosen.filter((device) => existsSync(join(templatesDir, device.template)));
const missing = chosen.filter((device) => !devices.includes(device));
if (missing.length > 0) console.log(`No template yet for ${missing.map((device) => device.name).join(", ")}: left out`);

let count = 0;
for (const locale of locales) {
    const folder = options.out ? join(options.out, locale) : join(store, locale);
    mkdirSync(folder, { recursive: true });
    for (const caption of readCaptions(locale)) {
        for (const device of devices) {
            const started = Date.now();
            const name = `${caption.file}${device.suffix}.png`;
            writeFileSync(join(folder, name), composeStoreImage(caption, device, locale));
            console.log(`${locale}/${name}  ${Date.now() - started} ms`);
            count++;
        }
    }
}
console.log(`Composed ${count} images.`);
