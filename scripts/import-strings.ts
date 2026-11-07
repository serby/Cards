// Imports one language's translations from a payload that
// scripts/export-strings.ts wrote and a person or another AI filled in. Each
// unit is validated as translate-strings validates a reply; a unit whose
// translation is null is left as it is. A translation also goes to the same
// string in the other target's catalogue. The catalogues are written in
// Xcode's format.
//
// Usage: node scripts/import-strings.ts --lang <code> <file> [--root <dir>]
// Exits 1 if any unit was refused.

import { readFileSync } from "node:fs";
import { parseArgs } from "node:util";
import { logger, runScript, UsageError } from "./lib/command-line.ts";
import { loadCatalogues, oneProjectLanguage, projectFrom, saveCatalogues } from "./lib/string-catalogues.ts";
import { importReply } from "./lib/translation.ts";

const usage = `Usage: node scripts/import-strings.ts --lang <code> <file> [options]

Applies a filled-in payload from export-strings, validated as translate-strings validates a reply.

Options:
  --lang <code>   The language, one in knownRegions
  --root <dir>    Repository root (default: this repository)`;

function main(argv: string[]): number {
    const { values, positionals } = parseArgs({
        args: argv,
        allowPositionals: true,
        options: {
            lang: { type: "string", multiple: true },
            root: { type: "string" },
            help: { type: "boolean", short: "h", default: false },
        },
    });
    if (values.help) {
        console.log(usage);
        return 0;
    }
    const [file, ...others] = positionals;
    if (!file || others.length > 0) throw new UsageError("needs one file: node scripts/import-strings.ts --lang <code> <file>");
    const project = projectFrom(values.root);
    const lang = oneProjectLanguage(values.lang, project);
    const catalogues = loadCatalogues(project);
    const result = importReply(catalogues, lang, readFileSync(file, "utf8"));
    saveCatalogues(catalogues, logger("import-strings"));
    for (const problem of result.problems) console.error(`error: ${problem}`);
    console.log(`Imported ${result.applied} translation${result.applied === 1 ? "" : "s"} for ${lang}, and ${result.copied} to the same string in another catalogue; ${result.skipped} left empty; ${result.problems.length} problem${result.problems.length === 1 ? "" : "s"}.`);
    return result.problems.length > 0 ? 1 : 0;
}

if (import.meta.main) runScript("import-strings", main);
