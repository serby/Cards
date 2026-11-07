// Reports how far each String Catalogue is translated into each language in
// the project's knownRegions: translated, missing, needing review, invalid and
// stale counts, after a line per catalogue with its translatable, not
// translatable and stale keys.
//
// Usage: node scripts/report-strings.ts [--root <dir>]

import { parseArgs } from "node:util";
import { runScript } from "./lib/command-line.ts";
import { languagesOf, loadCatalogues, projectFrom, sourceFolders, statusReport } from "./lib/string-catalogues.ts";

const usage = `Usage: node scripts/report-strings.ts [--root <dir>]

Prints translated, missing, needs-review, invalid and stale counts per String Catalogue and language.

Options:
  --root <dir>   Repository root (default: this repository)`;

function main(argv: string[]): number {
    const { values } = parseArgs({
        args: argv,
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
    const catalogues = loadCatalogues(project);
    if (catalogues.length === 0) console.log(`No String Catalogues under ${sourceFolders(project)}.`);
    else console.log(statusReport(catalogues, languagesOf(project)));
    return 0;
}

if (import.meta.main) runScript("report-strings", main);
