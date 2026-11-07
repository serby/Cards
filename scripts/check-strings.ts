// Checks the app's String Catalogues are complete: every key in every language
// in the project's knownRegions, with the source's placeholders and the plural
// forms the language needs, no translations for a language the project does
// not have, and a string compiled into both targets translated the same in
// both. Stale keys are warnings. CI runs it (docs/DEVELOPMENT.md, rule 17).
//
// Usage: node scripts/check-strings.ts [--root <dir>]
// Exits 1 if any language is incomplete or broken.

import { parseArgs } from "node:util";
import { runScript } from "./lib/command-line.ts";
import { checkReport, languagesOf, loadCatalogues, projectFrom, sourceFolders, unitsOf } from "./lib/string-catalogues.ts";

const usage = `Usage: node scripts/check-strings.ts [--root <dir>]

Fails if any language in knownRegions is incomplete or broken in any String Catalogue.

Options:
  --root <dir>   Repository root (default: this repository)`;

const plural = (count: number, noun: string): string => `${count} ${noun}${count === 1 ? "" : "s"}`;

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
    const languages = languagesOf(project);
    if (catalogues.length === 0) console.error(`warning: no String Catalogues under ${sourceFolders(project)}`);
    if (languages.length === 0) console.error("warning: the project has no languages besides en and Base");
    const { errors, warnings } = checkReport(catalogues, languages);
    for (const warning of warnings) console.error(`warning: ${warning}`);
    for (const error of errors) console.error(`error: ${error}`);
    const units = catalogues.reduce((sum, catalogue) => sum + unitsOf(catalogue).units.length, 0);
    console.log(`Checked ${plural(units, "key")} in ${plural(catalogues.length, "catalogue")} × ${plural(languages.length, "language")}: ${plural(errors.length, "error")}, ${plural(warnings.length, "warning")}.`);
    return errors.length > 0 ? 1 : 0;
}

if (import.meta.main) runScript("check-strings", main);
