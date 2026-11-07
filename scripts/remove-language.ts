// Takes a language out of the app: removes its code from the project's
// knownRegions and its translations from every String Catalogue, then prints
// the command that brings it back from the current commit, translations and
// all (scripts/add-language.ts --from). l10n/context.md lists the languages
// held back this way.
//
// Usage: node scripts/remove-language.ts <code> [--root <dir>]

import { spawnSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { parseArgs } from "node:util";
import { logger, runScript, UsageError } from "./lib/command-line.ts";
import { languageArgument, loadCatalogues, projectFrom, removeKnownRegion, removeLanguage, saveCatalogues } from "./lib/string-catalogues.ts";

const usage = `Usage: node scripts/remove-language.ts <code> [options]

Takes a language, such as fr or pt-BR, out of knownRegions and every String Catalogue.

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
    const [code, ...others] = positionals;
    if (!code || others.length > 0) throw new UsageError("needs one language code, such as fr or pt-BR");
    const project = projectFrom(values.root);
    const lang = languageArgument(code);
    const catalogues = loadCatalogues(project);
    const source = catalogues[0]?.doc.sourceLanguage ?? "en";
    if (lang === "en" || lang === source) throw new UsageError(`${lang} is the source language`);

    const edit = removeKnownRegion(readFileSync(project.pbxproj, "utf8"), lang);
    if (edit.changed) writeFileSync(project.pbxproj, edit.text);
    const removed = removeLanguage(catalogues, lang);
    saveCatalogues(catalogues, logger("remove-language"));
    if (!edit.changed && removed === 0) {
        console.log(`${lang} is not a project language and has no translations.`);
        return 0;
    }
    const head = spawnSync("git", ["rev-parse", "--short", "HEAD"], { cwd: project.root, encoding: "utf8" }).stdout?.trim();
    console.log(`Took ${lang} out of knownRegions and removed its ${removed} translation${removed === 1 ? "" : "s"}.`);
    if (head) console.log(`Bring it back with: node scripts/add-language.ts ${lang} --from ${head}`);
    return 0;
}

if (import.meta.main) runScript("remove-language", main);
