// Adds a language to the app: puts its code in the project's knownRegions, the
// only list of languages there is, and translates every String Catalogue into
// it as translate-strings does. With --from, it first restores the language's
// translations from an earlier commit, for every string whose English has not
// changed since, so a language that was held back comes back with its reviewed
// translations and only the rest is translated (l10n/context.md names the
// commit).
//
// Usage: node scripts/add-language.ts <code> [--from <commit>] [--force] [--batch-size <n>] [--root <dir>]
// Exits 1 if any string still fails after three attempts.

import { readFileSync, writeFileSync } from "node:fs";
import { relative } from "node:path";
import { parseArgs } from "node:util";
import { logger, positiveInteger, runScript, UsageError } from "./lib/command-line.ts";
import {
    addKnownRegion,
    cataloguesAt,
    isCommit,
    languageArgument,
    languageName,
    loadCatalogues,
    projectFrom,
    restoreLanguage,
    saveCatalogues,
} from "./lib/string-catalogues.ts";
import { defaultAICommand, stopAIOnInterrupt, translateProject } from "./lib/translation.ts";

const usage = `Usage: node scripts/add-language.ts <code> [options]

Adds a language, such as fr or pt-BR, to knownRegions and translates everything into it.

Options:
  --from <commit>     First restore its translations from this commit, where the English is unchanged
  --force             Translate every string afresh, restored ones too
  --batch-size <n>    Units per AI call (default 50)
  --root <dir>        Repository root (default: this repository)

Environment:
  L10N_AI_COMMAND     Shell command: prompt on stdin, reply on stdout
                      (default: ${defaultAICommand})
  L10N_AI_TIMEOUT     Seconds allowed per call (default 900)`;

const log = logger("add-language");

async function main(argv: string[]): Promise<number> {
    const { values, positionals } = parseArgs({
        args: argv,
        allowPositionals: true,
        options: {
            from: { type: "string" },
            force: { type: "boolean", default: false },
            "batch-size": { type: "string" },
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
    const batchSize = positiveInteger(values["batch-size"], 50, "--batch-size");
    const lang = languageArgument(code);
    const name = languageName(lang);
    if (!name) throw new UsageError(`${lang} is not a language the system knows`);
    const catalogues = loadCatalogues(project);
    const source = catalogues[0]?.doc.sourceLanguage ?? "en";
    if (lang === "en" || lang === source) throw new UsageError(`${lang} is the source language`);
    if (values.from !== undefined && !isCommit(project, values.from)) throw new UsageError(`${values.from} is not a commit in ${project.root}`);

    const edit = addKnownRegion(readFileSync(project.pbxproj, "utf8"), lang);
    if (edit.changed) {
        writeFileSync(project.pbxproj, edit.text);
        console.log(`Added ${lang} (${name}) to knownRegions in ${relative(project.root, project.pbxproj)}.`);
    } else {
        console.log(`${lang} (${name}) is already a project language.`);
    }
    if (values.from !== undefined) {
        const restored = restoreLanguage(catalogues, cataloguesAt(project, catalogues, values.from), lang);
        saveCatalogues(catalogues, log);
        console.log(`Restored ${restored} translation${restored === 1 ? "" : "s"} into ${lang} from ${values.from}.`);
    }
    return translateProject(project, catalogues, [lang], { force: values.force, jobs: 1, batchSize, log });
}

if (import.meta.main) {
    stopAIOnInterrupt();
    runScript("add-language", main);
}
