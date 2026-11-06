// Prints a version's What's New from changelog.json, one change a line, new
// first, for the release tag's message. British English (en-GB) unless
// --locale names another store locale, a folder in metadata/. It fails if the
// version has no text in that locale for a change, as an older version may not.
//
// Usage: node scripts/print-release-notes.ts <version> [--locale <store locale>]
// For example: git tag -a v1.3 -F <(node scripts/print-release-notes.ts 1.3)
//              node scripts/print-release-notes.ts 1.4 --locale es-MX

import { parseArgs } from "node:util";
import { load, readLocales, releaseNotes } from "./lib/changelog.ts";

const usage = "Usage: node scripts/print-release-notes.ts <version> [--locale <store locale>]";

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
    const { store } = readLocales();
    if (!store.includes(locale)) throw new Error(`--locale must be a store locale: ${store.join(", ")}`);
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
