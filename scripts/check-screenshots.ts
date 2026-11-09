// Checks the raw App Store captures in screenshots/<locale>/, before they are
// committed: there is exactly one folder (besides store/) for each store locale,
// the folders in metadata/, each holds exactly the expected PNGs, the iPhone, iPad and iPhone Duo screens
// are the right size, every file is an 8-bit RGB or RGBA PNG and none is
// suspiciously small. capture-screenshots.ts runs it once it has captured
// everything, and the Makefile after it composes the store images. CI does not:
// it only checks that the composed store images are present
// (check-store-images.ts).
//
// A screen with no capture in any locale on any device is new, added to the
// tests since the last capture. It is reported as waiting for the next full
// capture rather than failed, so the committed set still passes until the
// release refresh takes it; once any capture of it exists, every locale and
// device must have one. make store-screenshots cannot compose an image from it
// before then, and CI's store image check fails while that image is missing.
//
// Usage: node scripts/check-screenshots.ts [<screenshots folder>]
//   The folder is screenshots/ unless given, for checking a copy elsewhere.

import { closeSync, existsSync, openSync, readdirSync, readSync, statSync } from "node:fs";
import { join, resolve } from "node:path";
import { storeLocales } from "./lib/locales.ts";

const root = join(import.meta.dirname, "..");

interface Size {
    width: number;
    height: number;
}

/// Each device's file name suffix and screen size: the iPhone 17 Pro Max, the
/// iPad Pro 13-inch, and the iPhone Duo's outer display (the simulator boots folded).
const devices: { suffix: string; size: Size }[] = [
    { suffix: "", size: { width: 1320, height: 2868 } },
    { suffix: "_Duo", size: { width: 1398, height: 2034 } },
    { suffix: "_iPad", size: { width: 2064, height: 2752 } },
];
/// Whole screens, the device's size. capture-screenshots.ts lists the same screens.
const screens = [
    "01_CardList", "02_CardDetail", "03_EditCard", "04_LocationPicker", "05_HomeScreen", "06_ShareCard",
    "07_CardWhereYouAre", "08_Privacy", "09_ManyCards",
];
/// Crops of the Home Screen round the widget, whatever size the widget takes
/// there, so they can be any size.
const bands = ["05_Widget"];

interface ExpectedFile {
    screen: string;
    /// Undefined for a band, which can be any size.
    size?: Size;
}

/// The files each locale holds, and the size each must be.
const expectedFiles = new Map<string, ExpectedFile>(
    [...screens, ...bands].flatMap((screen) =>
        devices.map(({ suffix, size }): [string, ExpectedFile] => [
            `${screen}${suffix}.png`,
            { screen, size: bands.includes(screen) ? undefined : size },
        ]),
    ),
);
const locales = storeLocales();
/// Smaller than this and a capture is probably blank or broken.
const minimumBytes = 50_000;
const pngSignature = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
/// PNG colour types for RGB and RGBA.
const rgbColourTypes = new Set([2, 6]);

interface PngHeader extends Size {
    bitDepth: number;
    colourType: number;
}

/// Reads a PNG's IHDR chunk, which the format puts first, straight after the signature.
function readPngHeader(path: string): PngHeader {
    const header = Buffer.alloc(26);
    const file = openSync(path, "r");
    let length: number;
    try {
        length = readSync(file, header, 0, header.length, 0);
    } finally {
        closeSync(file);
    }
    if (length < pngSignature.length || !header.subarray(0, 8).equals(pngSignature)) throw new Error("not a PNG");
    if (length < header.length) throw new Error("truncated PNG header");
    if (header.toString("latin1", 12, 16) !== "IHDR" || header.readUInt32BE(8) !== 13) throw new Error("missing PNG IHDR");
    return {
        width: header.readUInt32BE(16),
        height: header.readUInt32BE(20),
        bitDepth: header.readUInt8(24),
        colourType: header.readUInt8(25),
    };
}

function list(names: Iterable<string>): string {
    return `[${[...names].sort().join(", ")}]`;
}

function sameSet(a: Set<string>, b: Set<string>): boolean {
    return a.size === b.size && [...a].every((name) => b.has(name));
}

/// The screens with no capture in any locale on any device: new ones, waiting
/// for the next full capture.
function uncaptured(folder: string): string[] {
    const captured = new Set(
        locales.flatMap((locale) =>
            [...expectedFiles].filter(([name]) => existsSync(join(folder, locale, name))).map(([, file]) => file.screen),
        ),
    );
    return [...screens, ...bands].filter((screen) => !captured.has(screen));
}

/// Everything wrong with the captures in `folder`, leaving out the `waiting` screens.
function check(folder: string, waiting: string[]): string[] {
    const errors: string[] = [];
    const folders = new Set(
        readdirSync(folder, { withFileTypes: true })
            .filter((entry) => entry.isDirectory() && !entry.name.startsWith(".") && !["store", "templates"].includes(entry.name))
            .map((entry) => entry.name),
    );
    if (!sameSet(folders, new Set(locales))) {
        errors.push(`locale folders: expected ${list(locales)}, found ${list(folders)}`);
    }
    if (waiting.length === screens.length + bands.length) {
        errors.push("no captures at all: run make capture-screenshots");
    }

    const expected = new Map([...expectedFiles].filter(([, file]) => !waiting.includes(file.screen)));
    for (const locale of locales) {
        const localeFolder = join(folder, locale);
        const files = new Set(existsSync(localeFolder) ? readdirSync(localeFolder).filter((name) => name.endsWith(".png")) : []);
        if (!sameSet(files, new Set(expected.keys()))) {
            errors.push(`${locale}: expected ${list(expected.keys())}, found ${list(files)}`);
        }
        for (const [name, { size }] of expected) {
            const path = join(localeFolder, name);
            if (!existsSync(path)) continue;
            let header: PngHeader;
            try {
                header = readPngHeader(path);
            } catch (error) {
                errors.push(`${locale}/${name}: ${error instanceof Error ? error.message : String(error)}`);
                continue;
            }
            if (size && (header.width !== size.width || header.height !== size.height)) {
                errors.push(`${locale}/${name}: expected ${size.width}x${size.height}, found ${header.width}x${header.height}`);
            }
            if (header.bitDepth !== 8 || !rgbColourTypes.has(header.colourType)) {
                errors.push(`${locale}/${name}: expected an 8-bit RGB or RGBA PNG, found bit depth ${header.bitDepth}, colour type ${header.colourType}`);
            }
            if (statSync(path).size < minimumBytes) {
                errors.push(`${locale}/${name}: file is unexpectedly small`);
            }
        }
    }
    return errors;
}

const args = process.argv.slice(2);
if (args.length > 1) {
    console.error("Usage: node scripts/check-screenshots.ts [<screenshots folder>]");
    process.exit(2);
}
const folder = args[0] ? resolve(args[0]) : join(root, "screenshots");
if (!existsSync(folder) || !statSync(folder).isDirectory()) {
    console.error(`ERROR: ${folder} is not a folder`);
    process.exit(1);
}
const waiting = uncaptured(folder);
const errors = check(folder, waiting);
if (errors.length > 0) {
    for (const error of errors) console.error(`ERROR: ${error}`);
    process.exit(1);
}
for (const screen of waiting) {
    console.log(`Not captured yet: ${screen}, a new screen the next make capture-screenshots takes.`);
}
console.log("Screenshot check passed.");
