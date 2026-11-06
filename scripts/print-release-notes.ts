// Prints a version's What's New from changelog.json, one change a line, new
// first, for the release tag's message. British English unless --locale
// en-US asks for American.
//
// Usage: node scripts/print-release-notes.ts <version> [--locale en-US]
// For example: git tag -a v1.3 -F <(node scripts/print-release-notes.ts 1.3)

import { parseArgs } from "node:util";
import { isLocale, load, locales, releaseNotes } from "./lib/changelog.ts";

const usage = "Usage: node scripts/print-release-notes.ts <version> [--locale en-US]";

function main(): void {
    const { values, positionals } = parseArgs({
        args: process.argv.slice(2),
        options: { locale: { type: "string", default: "en-GB" } },
        strict: true,
        allowPositionals: true,
    });
    if (positionals.length !== 1) throw new Error(usage);
    const [versionString] = positionals;
    const locale = values.locale;
    if (!isLocale(locale)) throw new Error(`--locale must be one of ${locales.join(", ")}`);
    const version = load().versions.find((entry) => entry.version === versionString);
    if (!version) throw new Error(`No version ${versionString} in changelog.json`);
    process.stdout.write(releaseNotes(version, locale));
}

try {
    main();
} catch (error) {
    console.error(`error: ${error instanceof Error ? error.message : String(error)}`);
    process.exitCode = 1;
}
