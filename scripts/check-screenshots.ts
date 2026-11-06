// Checks the raw App Store captures in screenshots/<locale>/, before they are
// committed: there are exactly the en-GB and en-US folders (besides store/),
// each holds exactly the expected PNGs, the iPhone, iPad and iPhone Duo screens
// are the right size, every file is an 8-bit RGB or RGBA PNG and none is
// suspiciously small. capture-screenshots.ts runs it after each capture, and
// the Makefile before it composes the store images. CI does not: it only checks
// that the composed store images are present (check-store-images.ts).
//
// Usage: node scripts/check-screenshots.ts [<screenshots folder>]
//   The folder is screenshots/ unless given, for checking a copy elsewhere.

import { closeSync, existsSync, openSync, readdirSync, readSync, statSync } from "node:fs";
import { join, resolve } from "node:path";

const root = join(import.meta.dirname, "..");

interface Size {
    width: number;
    height: number;
}

const iPhone: Size = { width: 1320, height: 2868 };
const iPad: Size = { width: 2064, height: 2752 };
/// iPhone Duo's outer display: the simulator boots folded.
const duo: Size = { width: 1398, height: 2034 };
const screens = ["01_CardList", "02_CardDetail", "03_EditCard", "04_LocationPicker"];
/// The files each locale holds, and the size each must be. The widget shot is a
/// crop of the Home Screen round the widget, whatever size the widget takes
/// there, so it can be any size (undefined).
const expectedFiles = new Map<string, Size | undefined>([
    ...screens.map((name): [string, Size] => [`${name}.png`, iPhone]),
    ...screens.map((name): [string, Size] => [`${name}_Duo.png`, duo]),
    ...screens.map((name): [string, Size] => [`${name}_iPad.png`, iPad]),
    ["05_Widget.png", undefined],
    ["05_Widget_Duo.png", undefined],
    ["05_Widget_iPad.png", undefined],
]);
const locales = ["en-GB", "en-US"];
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

/// Everything wrong with the captures in `folder`.
function check(folder: string): string[] {
    const errors: string[] = [];
    const folders = new Set(
        readdirSync(folder, { withFileTypes: true })
            .filter((entry) => entry.isDirectory() && !entry.name.startsWith(".") && entry.name !== "store")
            .map((entry) => entry.name),
    );
    if (!sameSet(folders, new Set(locales))) {
        errors.push(`locale folders: expected ${list(locales)}, found ${list(folders)}`);
    }

    for (const locale of locales) {
        const localeFolder = join(folder, locale);
        const files = new Set(existsSync(localeFolder) ? readdirSync(localeFolder).filter((name) => name.endsWith(".png")) : []);
        if (!sameSet(files, new Set(expectedFiles.keys()))) {
            errors.push(`${locale}: expected ${list(expectedFiles.keys())}, found ${list(files)}`);
        }
        for (const [name, size] of expectedFiles) {
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
const errors = check(folder);
if (errors.length > 0) {
    for (const error of errors) console.error(`ERROR: ${error}`);
    process.exit(1);
}
console.log("Screenshot check passed.");
