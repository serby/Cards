// Exports one language's strings that need work (every string with --force) as
// a JSON payload for a person or another AI to translate or review: each
// unit's catalogue, key, comment, English source, placeholders, the plural
// categories the language needs, and its current translation. A string in both
// targets' catalogues is exported once. scripts/import-strings.ts applies the
// filled-in file.
//
// Usage: node scripts/export-strings.ts --lang <code> --out <file> [--force] [--root <dir>]
// --out - writes the payload to stdout.

import { writeFileSync } from "node:fs";
import { parseArgs } from "node:util";
import { logger, runScript, UsageError } from "./lib/command-line.ts";
import { loadCatalogues, oneProjectLanguage, planWork, projectFrom } from "./lib/string-catalogues.ts";
import { payloadFor } from "./lib/translation.ts";

const usage = `Usage: node scripts/export-strings.ts --lang <code> --out <file> [options]

Writes the payload of one language's strings that need work, for a person or another AI.

Options:
  --lang <code>   The language, one in knownRegions
  --out <file>    Where to write it (- for stdout)
  --force         Every string, not just those that need work
  --root <dir>    Repository root (default: this repository)`;

const log = logger("export-strings");

function main(argv: string[]): number {
    const { values } = parseArgs({
        args: argv,
        options: {
            lang: { type: "string", multiple: true },
            out: { type: "string" },
            force: { type: "boolean", default: false },
            root: { type: "string" },
            help: { type: "boolean", short: "h", default: false },
        },
    });
    if (values.help) {
        console.log(usage);
        return 0;
    }
    const project = projectFrom(values.root);
    const lang = oneProjectLanguage(values.lang, project);
    if (!values.out) throw new UsageError("needs --out <file> (- for stdout)");
    const catalogues = loadCatalogues(project);
    // One unit per string: import-strings gives its translation to the twins,
    // and copies the twins of strings already translated.
    const units = planWork(catalogues, lang, values.force).ask;
    const text = `${JSON.stringify(payloadFor(units, lang, catalogues[0]?.doc.sourceLanguage), null, 2)}\n`;
    if (values.out === "-") process.stdout.write(text);
    else writeFileSync(values.out, text);
    log(`exported ${units.length} unit${units.length === 1 ? "" : "s"} for ${lang}${values.out === "-" ? "" : ` to ${values.out}`}`);
    return 0;
}

if (import.meta.main) runScript("export-strings", main);
