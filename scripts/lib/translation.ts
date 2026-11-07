// Translating the String Catalogues, for translate-strings, export-strings,
// import-strings and add-language: the payload a translator (a person or an
// AI) works on, the prompt, reading a reply, running the AI command, the
// translate loop, and applying a filled-in payload.
//
// The AI is any shell command that reads a prompt on stdin and writes its reply
// on stdout: L10N_AI_COMMAND, or by default the local Claude Code CLI with no
// tools, allowed L10N_AI_TIMEOUT seconds a call (default 900). Every reply is
// validated with the same rules as check-strings before anything is written.
//
// Usage: import { importReply, payloadFor, translateProject } from "./lib/translation.ts";

import { spawn } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join, relative } from "node:path";
import { positiveInteger } from "./command-line.ts";
import {
    applyTranslation,
    type Catalogue,
    canonicalLanguage,
    compareKeys,
    isObject,
    languageName,
    placeholders,
    planWork,
    pluralCategories,
    type Project,
    requiredPluralCategories,
    saveCatalogues,
    singleNumber,
    sourceFolders,
    sourcePluralForms,
    stringsIn,
    type Text,
    textOf,
    type Translation,
    type Unit,
    twinsOf,
    unitId,
    unitsOf,
    validate,
    withTwins,
} from "./string-catalogues.ts";

// MARK: - Payload

export interface PayloadUnit {
    catalogue: string;
    key: string;
    comment?: string;
    source: Text;
    placeholders: string[];
    pluralCategories?: string[];
    translation: Text | null;
}

export interface Payload {
    sourceLanguage: string;
    targetLanguage: string;
    targetLanguageName: string;
    instructions: string;
    units: PayloadUnit[];
}

export function payloadUnit(unit: Unit, lang: string): PayloadUnit {
    const forms = sourcePluralForms(unit.source);
    const current = textOf(unit.entry.localizations?.[lang]);
    return {
        catalogue: unit.catalogue.name,
        key: unit.key,
        ...(unit.entry.comment ? { comment: unit.entry.comment } : {}),
        source: unit.source,
        placeholders: [...new Set(stringsIn(unit.source).flatMap((s) => placeholders(s).map((p) => p.raw)))],
        ...(forms ? { pluralCategories: requiredPluralCategories(lang, forms) } : {}),
        translation: current ?? null,
    };
}

export function payloadFor(units: Unit[], lang: string, sourceLanguage = "en"): Payload {
    const name = languageName(lang) ?? lang;
    return {
        sourceLanguage,
        targetLanguage: lang,
        targetLanguageName: name,
        instructions:
            `Translate each unit's "source" from British English into ${name} (${lang}) and put it in "translation", ` +
            'in the same shape as "source". Keep every placeholder. A plural needs exactly the categories in "pluralCategories". ' +
            'Return this document with every unit; each unit needs only "catalogue", "key" and "translation".',
        units: units.map((unit) => payloadUnit(unit, lang)),
    };
}

// MARK: - Prompt

export interface RetryNote {
    catalogue: string;
    key: string;
    translation?: unknown;
    problems: string[];
}

export function buildPrompt(payload: Payload, brief: string, notes: string | undefined, retry: { general?: string; units: RetryNote[] }): string {
    const name = payload.targetLanguageName;
    const lang = payload.targetLanguage;
    const sections = [
        `You are localising the interface of an iPhone app from British English into ${name} (language code ${lang}). ` +
            "Reply with one JSON object and nothing else: no explanation, no Markdown and no code fence.",
        `## The app\n\n${brief.trim()}`,
    ];
    if (notes?.trim()) sections.push(`## Notes for ${name}\n\n${notes.trim()}`);
    const single = pluralCategories(lang).flatMap((category) => {
        const n = singleNumber(lang, category);
        return n === undefined ? [] : [`"${category}" (only ever ${n})`];
    });
    const spellOut = single.length === 0
        ? "keep the number's placeholder."
        : `keep the number's placeholder, except in a category that only ever means one number: ${single.join(", ")}. There you may write the number as a word, as ${name} naturally would, and leave out its placeholder; keep every other placeholder.`;
    sections.push(`## How to translate

- Write ${name} the way Apple writes it on iOS. Use the exact names Apple's ${name} iOS gives its own apps, features and settings, such as Settings, Camera, Wallet, Lock Screen, Home Screen, Notifications, Location Services, Photos and iCloud, and Apple's ${name} wording for standard controls such as Cancel, Done, Edit, Delete, Save, Add, Allow and OK.
- Use the register of Apple's own ${name} iOS interface: the same level of formality and the same way of addressing the user, and Apple's ${name} conventions for capitalisation, punctuation and quotation marks in titles, buttons, alerts and permission prompts. Do not copy English title case if ${name} does not use it.
- Be concise. The strings appear in buttons, navigation bars, list rows, alerts and notifications on an iPhone. Keep each one about as long as the source, and never add explanations.
- Keep placeholders. Every placeholder in "placeholders" (such as %@, %lld, %d, %1$@, %%, %#@name@ and %arg) must appear in the translation as many times as in the source, character for character. You may move a placeholder; if two must change order, number them (%1$@, %2$@). Never translate, add or drop one. %% is a literal percent sign.
- Plurals. When "source" is {"plural": …}, the translation is {"plural": …} with exactly the categories in "pluralCategories": the plural categories ${name} needs, which can differ from English. Each form must read correctly for every number in its category and ${spellOut}
- Keep the shape of "source": a string for a string, a list for a list, and the same keys for {"device": …} and for {"format": …, "substitutions": …}.
- Leave untranslated: brand and product names, everything in the do-not-translate list above, and the user's own content.
- "comment" says where the string appears and what fills each placeholder. Use it, but do not translate it.
- A non-null "translation" in the input is the current one, which is missing parts, out of date, flagged for review or broken. Replace it with a correct translation, keeping its wording where that is already right.`);
    sections.push(`## Reply

Reply with the input document in the same JSON shape, every unit included once, with "catalogue" and "key" copied exactly and "translation" filled in. Each unit needs only those three fields:

{"targetLanguage": "${lang}", "units": [{"catalogue": "…", "key": "…", "translation": …}]}`);
    if (retry.general || retry.units.length > 0) {
        const lines = retry.units.map((note) => {
            const previous = note.translation === undefined ? "" : ` (you wrote ${JSON.stringify(note.translation)})`;
            return `- ${JSON.stringify(note.key)} in ${note.catalogue}: ${note.problems.join("; ")}${previous}`;
        });
        sections.push(`## Problems with your previous reply\n\n${[retry.general, ...lines].filter(Boolean).join("\n")}\n\nFix every problem in this reply.`);
    }
    sections.push(`## Input\n\n\`\`\`json\n${JSON.stringify(payload, null, 2)}\n\`\`\``);
    return `${sections.join("\n\n")}\n`;
}

// MARK: - Reply

export interface ReplyUnit {
    catalogue: string;
    key: string;
    translation: unknown;
}

/// Parses a reply as strict JSON. The only leniency is one code fence around
/// the whole reply, which models add even when told not to.
export function parseReply(reply: string, lang?: string): ReplyUnit[] {
    let text = reply.replace(/^\uFEFF/, "").trim();
    const fence = /^```[\w-]*[ \t]*\r?\n([\s\S]*?)\r?\n?```$/.exec(text);
    if (fence) text = fence[1].trim();
    let data: unknown;
    try {
        data = JSON.parse(text);
    } catch (error) {
        throw new Error(`the reply is not valid JSON (${(error as Error).message})`);
    }
    const units = Array.isArray(data) ? data : isObject(data) ? data.units : undefined;
    if (!Array.isArray(units)) throw new Error('the reply has no "units" list');
    if (lang && isObject(data) && typeof data.targetLanguage === "string" && canonicalLanguage(data.targetLanguage) !== lang) {
        throw new Error(`the reply is for ${data.targetLanguage}, not ${lang}`);
    }
    return units.map((unit: unknown, index: number) => {
        if (!isObject(unit) || typeof unit.catalogue !== "string" || typeof unit.key !== "string") {
            throw new Error(`unit ${index + 1} of the reply has no "catalogue" and "key"`);
        }
        return { catalogue: unit.catalogue, key: unit.key, translation: unit.translation };
    });
}

// MARK: - Running the AI

export const defaultAICommand =
    'claude -p --model fable --fallback-model opus --safe-mode --tools "" --strict-mcp-config ' +
    "--permission-mode dontAsk --permission-prompts none --no-session-persistence --disable-slash-commands " +
    '--system-prompt "You are an expert iOS localiser. Reply with JSON only."';

const runningGroups = new Set<number>();

function killGroup(pid: number, signal: NodeJS.Signals): void {
    try {
        process.kill(-pid, signal);
    } catch {
        // Already gone.
    }
}

/// Makes Ctrl-C stop every AI command still running, with everything each
/// one started, before the script exits.
export function stopAIOnInterrupt(): void {
    process.on("SIGINT", () => {
        for (const pid of runningGroups) killGroup(pid, "SIGTERM");
        process.exit(130);
    });
}

const tail = (output: string): string => output.trim().split("\n").slice(-5).join(" ");

/// Waits before asking again after the AI command itself failed. Failures under
/// load are usually throttling, so back off: about 10 s, then 20 s, plus jitter.
/// L10N_AI_BACKOFF_MS scales it (0 in tests).
const backoff = (attempt: number): Promise<void> => {
    const base = Number(process.env.L10N_AI_BACKOFF_MS ?? 10_000);
    const delay = base * 2 ** (attempt - 1) * (0.75 + Math.random() / 2);
    return new Promise((resolveDelay) => setTimeout(resolveDelay, delay));
};

/// Runs a shell command with the prompt on stdin and returns its stdout. The
/// command runs in its own process group so a timeout (macOS has no GNU
/// timeout) or Ctrl-C stops everything it started.
export function runCommand(command: string, input: string, timeoutMs: number, cwd: string): Promise<string> {
    return new Promise((resolvePromise, reject) => {
        const child = spawn("/bin/sh", ["-c", command], { cwd, detached: true, stdio: ["pipe", "pipe", "pipe"] });
        const pid = child.pid;
        if (pid === undefined) {
            reject(new Error(`could not start ${command}`));
            return;
        }
        runningGroups.add(pid);
        let stdout = "";
        let stderr = "";
        let timedOut = false;
        child.stdout.setEncoding("utf8").on("data", (chunk: string) => (stdout += chunk));
        child.stderr.setEncoding("utf8").on("data", (chunk: string) => (stderr += chunk));
        child.stdin.on("error", () => {
            // The command exited without reading all of its input; its exit status says why.
        });
        const timer = setTimeout(() => {
            timedOut = true;
            killGroup(pid, "SIGTERM");
            setTimeout(() => killGroup(pid, "SIGKILL"), 5000).unref();
        }, timeoutMs);
        child.on("error", (error) => {
            clearTimeout(timer);
            runningGroups.delete(pid);
            reject(error);
        });
        child.on("close", (code, signal) => {
            clearTimeout(timer);
            runningGroups.delete(pid);
            if (timedOut) reject(new Error(`timed out after ${Math.round(timeoutMs / 1000)} s`));
            // Some CLIs (claude -p among them) report API errors on stdout, so fall back to it.
            else if (code !== 0) reject(new Error(`exited with ${code ?? signal}: ${tail(stderr) || tail(stdout) || "no output"}`));
            else resolvePromise(stdout);
        });
        child.stdin.end(input);
    });
}

// MARK: - Translating

export interface TranslateOptions {
    languages: string[];
    force: boolean;
    jobs: number;
    batchSize: number;
    brief: string;
    notes: (lang: string) => string | undefined;
    ask: (prompt: string, lang: string) => Promise<string>;
    log: (line: string) => void;
}

export interface Failure {
    lang: string;
    catalogue: string;
    key: string;
    problems: string[];
}

export async function mapLimit<T, R>(items: T[], limit: number, work: (item: T) => Promise<R>): Promise<R[]> {
    const results: R[] = new Array(items.length);
    let next = 0;
    const worker = async (): Promise<void> => {
        while (next < items.length) {
            const index = next++;
            results[index] = await work(items[index]);
        }
    };
    await Promise.all(Array.from({ length: Math.max(1, Math.min(limit, items.length)) }, worker));
    return results;
}

/// One batch: ask, validate every unit, and ask again (up to twice) for the
/// units that failed, with the problems fed back.
async function translateBatch(units: Unit[], lang: string, label: string, options: TranslateOptions): Promise<{ done: Translation[]; failed: Failure[] }> {
    const done: Translation[] = [];
    let pending = units;
    let retry: { general?: string; units: RetryNote[] } = { units: [] };
    let lastFailure = "no usable reply";
    for (let attempt = 1; attempt <= 3 && pending.length > 0; attempt++) {
        const payload = payloadFor(pending, lang, pending[0].catalogue.doc.sourceLanguage);
        const prompt = buildPrompt(payload, options.brief, options.notes(lang), retry);
        options.log(`${label}: asking for ${pending.length} unit${pending.length === 1 ? "" : "s"} (attempt ${attempt} of 3)`);
        let reply: string;
        try {
            reply = await options.ask(prompt, lang);
        } catch (error) {
            // The command failed, so there is no reply to give feedback on: ask again as before.
            lastFailure = `the AI command failed: ${(error as Error).message}`;
            options.log(`${label}: ${lastFailure}`);
            if (attempt < 3) await backoff(attempt);
            continue;
        }
        let replyUnits: ReplyUnit[];
        try {
            replyUnits = parseReply(reply, lang);
        } catch (error) {
            lastFailure = (error as Error).message;
            options.log(`${label}: ${lastFailure}`);
            retry = { general: `Your previous reply could not be used: ${lastFailure}. Reply with the JSON object only.`, units: [] };
            continue;
        }
        const answers = new Map(replyUnits.map((answer) => [unitId(answer.catalogue, answer.key), answer]));
        const next: Unit[] = [];
        retry = { units: [] };
        for (const unit of pending) {
            const answer = answers.get(unitId(unit.catalogue.name, unit.key));
            const problems = answer ? validate(unit.source, answer.translation, lang).map((p) => p.message) : ["missing from your reply"];
            if (problems.length === 0) {
                done.push({ lang, unit, text: answer?.translation as Text });
            } else {
                next.push(unit);
                retry.units.push({ catalogue: unit.catalogue.name, key: unit.key, translation: answer?.translation, problems });
            }
        }
        pending = next;
    }
    const lastProblems = new Map(retry.units.map((note) => [unitId(note.catalogue, note.key), note.problems]));
    const failed = pending.map((unit) => ({
        lang,
        catalogue: unit.catalogue.name,
        key: unit.key,
        problems: lastProblems.get(unitId(unit.catalogue.name, unit.key)) ?? [lastFailure],
    }));
    return { done, failed };
}

/// Translates every language (a few at a time), then merges the results in
/// memory in a fixed order. Writing is left to the caller, once per catalogue.
export async function translate(catalogues: Catalogue[], options: TranslateOptions): Promise<{ translations: Translation[]; failures: Failure[] }> {
    const perLanguage = await mapLimit(options.languages, options.jobs, async (lang) => {
        const { ask: units, copies, twins } = planWork(catalogues, lang, options.force);
        if (units.length === 0 && copies.length === 0) {
            options.log(`${lang}: nothing to translate`);
            return { done: [] as Translation[], failed: [] as Failure[] };
        }
        if (copies.length > 0) {
            options.log(`${lang}: ${copies.length} copied from the same string in another catalogue`);
        }
        const batches: Unit[][] = [];
        for (let start = 0; start < units.length; start += options.batchSize) batches.push(units.slice(start, start + options.batchSize));
        const done: Translation[] = [...copies];
        const failed: Failure[] = [];
        for (const [index, batch] of batches.entries()) {
            const result = await translateBatch(batch, lang, `${lang} batch ${index + 1}/${batches.length}`, options);
            done.push(...result.done.flatMap((translation) => withTwins(translation, twins)));
            failed.push(...result.failed);
        }
        options.log(`${lang}: ${done.length} translated${failed.length > 0 ? `, ${failed.length} failed` : ""}`);
        return { done, failed };
    });
    const translations = perLanguage.flatMap((result) => result.done);
    translations.sort((a, b) => compareKeys(a.lang, b.lang) || compareKeys(a.unit.catalogue.name, b.unit.catalogue.name) || compareKeys(a.unit.key, b.unit.key));
    for (const { lang, unit, text } of translations) applyTranslation(unit, lang, text);
    return { translations, failures: perLanguage.flatMap((result) => result.failed) };
}

// MARK: - Importing

export interface ImportResult {
    applied: number;
    /// Translations given to twins of the units in the file, or copied from a
    /// twin that already had one.
    copied: number;
    skipped: number;
    problems: string[];
}

/// Applies a filled-in payload, validating each unit exactly as translate does.
/// A unit's translation goes to its twins too, and twins still missing one get
/// a copy, as translate gives them.
export function importReply(catalogues: Catalogue[], lang: string, reply: string): ImportResult {
    const result: ImportResult = { applied: 0, copied: 0, skipped: 0, problems: [] };
    const twins = twinsOf(catalogues);
    const units = new Map(catalogues.flatMap((catalogue) => unitsOf(catalogue).units).map((unit) => [unitId(unit.catalogue.name, unit.key), unit]));
    for (const answer of parseReply(reply, lang)) {
        const unit = units.get(unitId(answer.catalogue, answer.key));
        const label = `${answer.catalogue} ${JSON.stringify(answer.key)}`;
        if (!unit) {
            result.problems.push(`${label}: no such key to translate (removed, stale or marked do not translate)`);
        } else if (answer.translation === undefined || answer.translation === null) {
            result.skipped++;
        } else {
            const problems = validate(unit.source, answer.translation, lang);
            if (problems.length > 0) {
                result.problems.push(...problems.map((p) => `${label}: ${p.message}`));
            } else {
                for (const twin of withTwins({ lang, unit, text: answer.translation as Text }, twins)) {
                    applyTranslation(twin.unit, lang, twin.text);
                    if (twin.unit.catalogue.name !== unit.catalogue.name) result.copied++;
                }
                result.applied++;
            }
        }
    }
    for (const copy of planWork(catalogues, lang, false).copies) {
        applyTranslation(copy.unit, lang, copy.text);
        result.copied++;
    }
    return result;
}

// MARK: - Translating the project

function readBrief(project: Project): string {
    const path = join(project.l10n, "context.md");
    if (!existsSync(path)) throw new Error(`${relative(project.root, path)} is missing; the AI needs the translator brief`);
    return readFileSync(path, "utf8");
}

function readNotes(project: Project, lang: string): string | undefined {
    const path = join(project.l10n, "languages", `${lang}.md`);
    return existsSync(path) ? readFileSync(path, "utf8") : undefined;
}

export interface ProjectTranslationOptions {
    force: boolean;
    jobs: number;
    batchSize: number;
    log: (line: string) => void;
}

/// Translates the catalogues into the languages with the AI command, with the
/// translator brief (l10n/context.md) and each language's style guide
/// (l10n/languages/<code>.md), writes the catalogues that changed, and reports
/// what failed. Returns the exit code: 1 if any unit failed after three
/// attempts.
export async function translateProject(project: Project, catalogues: Catalogue[], languages: string[], options: ProjectTranslationOptions): Promise<number> {
    if (catalogues.length === 0) {
        options.log(`no String Catalogues under ${sourceFolders(project)}, nothing to translate`);
        return 0;
    }
    const command = process.env.L10N_AI_COMMAND || defaultAICommand;
    const timeout = positiveInteger(process.env.L10N_AI_TIMEOUT, 900, "L10N_AI_TIMEOUT") * 1000;
    const { translations, failures } = await translate(catalogues, {
        languages,
        force: options.force,
        jobs: options.jobs,
        batchSize: options.batchSize,
        brief: readBrief(project),
        notes: (lang) => readNotes(project, lang),
        ask: (prompt) => runCommand(command, prompt, timeout, project.root),
        log: options.log,
    });
    saveCatalogues(catalogues, options.log);
    for (const failure of failures) {
        console.error(`error: ${failure.catalogue} [${failure.lang}] ${JSON.stringify(failure.key)}: ${failure.problems.join("; ")}`);
    }
    console.log(`Translated ${translations.length} unit${translations.length === 1 ? "" : "s"}${failures.length > 0 ? `; ${failures.length} failed after 3 attempts` : ""}.`);
    return failures.length > 0 ? 1 : 0;
}
