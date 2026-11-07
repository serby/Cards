// Translates the app's String Catalogues with AI: every string that is
// missing, empty, flagged for review or broken in each language (every string
// with --force), with the translator brief (l10n/context.md) and the
// language's style guide (l10n/languages/<code>.md). Every reply is validated
// as check-strings validates the catalogues, and asked for again, with the
// problems, when it fails; the catalogues are written in Xcode's format.
//
// Usage: node scripts/translate-strings.ts [--lang <code>…] [--force] [--jobs <n>] [--batch-size <n>] [--root <dir>]
// Exits 1 if any string still fails after three attempts.

import { parseArgs } from "node:util";
import { logger, positiveInteger, runScript } from "./lib/command-line.ts";
import { languageArguments, languagesOf, loadCatalogues, projectFrom, requireProjectLanguages } from "./lib/string-catalogues.ts";
import { defaultAICommand, stopAIOnInterrupt, translateProject } from "./lib/translation.ts";

const usage = `Usage: node scripts/translate-strings.ts [options]

Translates what needs it in every String Catalogue, in every language in knownRegions by default.

Options:
  --lang <code>…      Only these languages; one value may hold several ("de ja")
  --force             Translate every string afresh, not just those that need it
  --jobs <n>          Languages translated in parallel (default 3)
  --batch-size <n>    Units per AI call (default 50)
  --root <dir>        Repository root (default: this repository)

Environment:
  L10N_AI_COMMAND     Shell command: prompt on stdin, reply on stdout
                      (default: ${defaultAICommand})
  L10N_AI_TIMEOUT     Seconds allowed per call (default 900)`;

async function main(argv: string[]): Promise<number> {
    const { values } = parseArgs({
        args: argv,
        options: {
            lang: { type: "string", multiple: true },
            force: { type: "boolean", default: false },
            jobs: { type: "string" },
            "batch-size": { type: "string" },
            root: { type: "string" },
            help: { type: "boolean", short: "h", default: false },
        },
    });
    if (values.help) {
        console.log(usage);
        return 0;
    }
    const project = projectFrom(values.root);
    const jobs = positiveInteger(values.jobs, 3, "--jobs");
    const batchSize = positiveInteger(values["batch-size"], 50, "--batch-size");
    const languages = languagesOf(project);
    const requested = languageArguments(values.lang);
    const chosen = requested.length > 0 ? requireProjectLanguages(requested, languages) : languages;
    return translateProject(project, loadCatalogues(project), chosen, { force: values.force, jobs, batchSize, log: logger("translate-strings") });
}

if (import.meta.main) {
    stopAIOnInterrupt();
    runScript("translate-strings", main);
}
