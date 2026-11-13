// Rewrites String Catalogues byte for byte as Xcode's catalogue editor writes
// them (key order, spacing, escapes, no final newline), so Xcode re-saving
// them changes nothing. Run it after `xcodebuild -exportLocalizations`, whose
// files differ (docs/DEVELOPMENT.md, "Add or change copy").
//
// Usage: node scripts/normalise-strings.ts [<file>…] [--root <dir>]
// With no files, it rewrites every catalogue the app and the widget ship.

import { resolve } from "node:path";
import { parseArgs } from "node:util";
import { runScript } from "./lib/command-line.ts";
import { findCatalogues, loadCatalogues, projectFrom, saveCatalogue } from "./lib/string-catalogues.ts";

const usage = `Usage: node scripts/normalise-strings.ts [<file>…] [options]

Rewrites String Catalogues in Xcode's format: the files given, or every one under Cards/, CardsWidget/ and CardsWatch/.

Options:
  --root <dir>   Repository root (default: this repository)`;

function main(argv: string[]): number {
    const { values, positionals } = parseArgs({
        args: argv,
        allowPositionals: true,
        options: {
            root: { type: "string" },
            help: { type: "boolean", short: "h", default: false },
        },
    });
    if (values.help) {
        console.log(usage);
        return 0;
    }
    const project = projectFrom(values.root);
    const paths = positionals.length > 0 ? positionals.map((path) => resolve(path)) : findCatalogues(project);
    for (const catalogue of loadCatalogues(project, paths)) {
        console.log(saveCatalogue(catalogue) ? `Rewrote ${catalogue.name} in Xcode's format.` : `${catalogue.name} is already in Xcode's format.`);
    }
    return 0;
}

if (import.meta.main) runScript("normalise-strings", main);
