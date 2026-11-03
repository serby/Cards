// Translates the app's String Catalogues with AI, and checks they are complete.
//
// The languages are the project's knownRegions minus en and Base, and the
// catalogues are every *.xcstrings under Cards/ except Cards/Development, so
// there is no separate configuration. The AI is any shell command that reads a
// prompt on stdin and writes its reply on stdout: L10N_AI_COMMAND, or by default
// the local Claude Code CLI with no tools. Every reply is validated with the
// same rules as `check` before anything is written, and catalogues are written
// in Xcode's own format, so Xcode re-saving them changes nothing.
//
// Usage: node scripts/l10n.ts <command> [options]
//   status                          Translated, missing, needs-review and stale counts
//   check                           Fail if any language is incomplete or broken
//   translate [--lang <code>…]      Translate what needs it (--force: everything)
//   export --lang <code> --out <f>  Write the translation payload for a person or another AI
//   import --lang <code> <file>     Apply a filled-in payload, validated like translate
//   add-language <code>             Add a language to the project, then translate it
//   normalise [<file>…]             Rewrite catalogues in Xcode's format
// Options: --root <dir> (default: this repository), --jobs <n> (languages in
// parallel, default 3), --batch-size <n> (units per AI call, default 50).
// Environment: L10N_AI_COMMAND, L10N_AI_TIMEOUT (seconds per call, default 900).

import { spawn } from "node:child_process";
import { existsSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { join, relative, resolve } from "node:path";
import { parseArgs } from "node:util";

// MARK: - Catalogue model

export interface StringUnit {
    state?: string;
    value?: string;
    [field: string]: unknown;
}

export interface Localisation {
    stringUnit?: StringUnit;
    stringSet?: { state?: string; values?: string[]; [field: string]: unknown };
    variations?: { plural?: Record<string, Localisation>; device?: Record<string, Localisation> };
    substitutions?: Record<string, Substitution>;
    [field: string]: unknown;
}

export interface Substitution {
    argNum?: number;
    formatSpecifier?: string;
    variations?: { plural?: Record<string, Localisation> };
    [field: string]: unknown;
}

export interface Entry {
    comment?: string;
    extractionState?: string;
    shouldTranslate?: boolean;
    localizations?: Record<string, Localisation>;
    [field: string]: unknown;
}

export interface CatalogueDocument {
    sourceLanguage: string;
    strings: Record<string, Entry>;
    version?: string;
    [field: string]: unknown;
}

export interface Catalogue {
    /** Path relative to the root, which is also how payloads name it. */
    name: string;
    path: string;
    doc: CatalogueDocument;
    original: string;
}

/// A localisation as the AI sees it: a string, a string set, plural forms,
/// device variants, or a format string with plural substitutions.
export type Text =
    | string
    | string[]
    | { plural: Record<string, Text> }
    | { device: Record<string, Text> }
    | { format: Text; substitutions: Record<string, { plural: Record<string, string> }> };

// MARK: - Xcode's file format

const collator = new Intl.Collator("en", { numeric: true });

/// The order Xcode's catalogue editor and `xcodebuild -exportLocalizations`
/// write keys in, at every level: like Finder sorts names, case-insensitive
/// with numbers by value ("2 items" before "10 items", "zh-Hans" before
/// "zh-HK"). That is ICU's English collation with numeric ordering, which Node
/// shares; code point order breaks the rare ties so the order is total.
/// (`xcstringstool` sorts by code point instead, so files it writes differ.)
export function compareKeys(a: string, b: string): number {
    return collator.compare(a, b) || Buffer.compare(Buffer.from(a, "utf8"), Buffer.from(b, "utf8"));
}

/// JSON exactly as Xcode writes a String Catalogue: two-space indent, " : "
/// between key and value, keys sorted by compareKeys, an empty line inside
/// empty containers, slashes and non-ASCII left as they are, and no newline at
/// the end. JSON.stringify escapes strings the same way Xcode does.
export function formatJSON(value: unknown, indent = ""): string {
    const inner = `${indent}  `;
    if (Array.isArray(value)) {
        if (value.length === 0) return `[\n\n${indent}]`;
        return `[\n${value.map((item) => inner + formatJSON(item, inner)).join(",\n")}\n${indent}]`;
    }
    if (value !== null && typeof value === "object") {
        const object = value as Record<string, unknown>;
        const keys = Object.keys(object).filter((key) => object[key] !== undefined).sort(compareKeys);
        if (keys.length === 0) return `{\n\n${indent}}`;
        const lines = keys.map((key) => `${inner}${JSON.stringify(key)} : ${formatJSON(object[key], inner)}`);
        return `{\n${lines.join(",\n")}\n${indent}}`;
    }
    return JSON.stringify(value);
}

/// What Xcode drops when it saves: the default `shouldTranslate: true`, and
/// empty `localizations` and `substitutions`.
export function canonicalise(doc: CatalogueDocument): CatalogueDocument {
    for (const entry of Object.values(doc.strings)) {
        if (entry.shouldTranslate === true) delete entry.shouldTranslate;
        if (entry.localizations && Object.keys(entry.localizations).length === 0) delete entry.localizations;
        for (const localisation of Object.values(entry.localizations ?? {})) {
            if (localisation.substitutions && Object.keys(localisation.substitutions).length === 0) {
                delete localisation.substitutions;
            }
        }
    }
    return doc;
}

export function formatCatalogue(doc: CatalogueDocument): string {
    return formatJSON(canonicalise(doc));
}

export function parseCatalogue(text: string, name: string): CatalogueDocument {
    let doc: unknown;
    try {
        doc = JSON.parse(text.replace(/^\uFEFF/, ""));
    } catch (error) {
        throw new Error(`${name} is not valid JSON: ${(error as Error).message}`);
    }
    if (!isObject(doc) || !isObject(doc.strings) || typeof doc.sourceLanguage !== "string") {
        throw new Error(`${name} is not a String Catalogue (no sourceLanguage or strings)`);
    }
    return doc as CatalogueDocument;
}

// MARK: - Project

export interface Project {
    root: string;
    pbxproj: string;
    sources: string;
    development: string;
    l10n: string;
}

export function projectAt(root: string): Project {
    return {
        root,
        pbxproj: join(root, "Cards.xcodeproj", "project.pbxproj"),
        sources: join(root, "Cards"),
        development: join(root, "Cards", "Development"),
        l10n: join(root, "l10n"),
    };
}

export function findCatalogues(project: Project): string[] {
    const found: string[] = [];
    const walk = (dir: string): void => {
        for (const name of readdirSync(dir)) {
            const path = join(dir, name);
            if (statSync(path).isDirectory()) {
                if (path !== project.development) walk(path);
            } else if (name.endsWith(".xcstrings")) {
                found.push(path);
            }
        }
    };
    if (existsSync(project.sources)) walk(project.sources);
    return found.sort(compareKeys);
}

export function loadCatalogues(project: Project, paths = findCatalogues(project)): Catalogue[] {
    return paths.map((path) => {
        const original = readFileSync(path, "utf8");
        const name = relative(project.root, path);
        return { name, path, doc: parseCatalogue(original, name), original };
    });
}

/// Writes the catalogue in Xcode's format if that changes the file.
export function saveCatalogue(catalogue: Catalogue): boolean {
    const text = formatCatalogue(catalogue.doc);
    if (text === catalogue.original) return false;
    writeFileSync(catalogue.path, text);
    catalogue.original = text;
    return true;
}

function unquote(item: string): string {
    return item.startsWith('"') && item.endsWith('"') ? item.slice(1, -1).replace(/\\(.)/g, "$1") : item;
}

/// Xcode leaves a value bare only when it is made of these characters; a
/// hyphenated code such as pt-BR has to be quoted.
export function pbxQuote(value: string): string {
    return /^[A-Za-z0-9_$/:.]+$/.test(value) ? value : `"${value.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;
}

const knownRegionsPattern = /^([\t ]*)knownRegions = \(([^)]*)\);/gm;

export function readKnownRegions(pbxproj: string): string[] {
    const regions: string[] = [];
    for (const match of pbxproj.matchAll(knownRegionsPattern)) {
        for (const item of match[2].split(",")) {
            const region = unquote(item.trim());
            if (region && !regions.includes(region)) regions.push(region);
        }
    }
    return regions;
}

/// Adds the code to the end of every knownRegions list that lacks it, as one
/// new line, so the diff is that line and nothing else.
export function addKnownRegion(pbxproj: string, code: string): { text: string; changed: boolean } {
    let changed = false;
    const text = pbxproj.replace(knownRegionsPattern, (whole: string, indent: string, body: string) => {
        const items = body.split(",").map((item) => unquote(item.trim())).filter(Boolean);
        if (items.includes(code)) return whole;
        changed = true;
        const itemIndent = /\n([\t ]+)\S/.exec(body)?.[1] ?? `${indent}\t`;
        let kept = body.replace(/\s+$/, "");
        if (kept.trim() !== "" && !kept.endsWith(",")) kept += ",";
        return `${indent}knownRegions = (${kept}\n${itemIndent}${pbxQuote(code)},\n${indent});`;
    });
    return { text, changed };
}

export function projectLanguages(pbxproj: string, sourceLanguage = "en"): string[] {
    return readKnownRegions(pbxproj).filter((region) => region !== "Base" && region !== "en" && region !== sourceLanguage);
}

// MARK: - Languages and plural rules

export function canonicalLanguage(code: string): string {
    let canonical: string | undefined;
    try {
        [canonical] = Intl.getCanonicalLocales(code.trim().replaceAll("_", "-"));
    } catch {
        canonical = undefined;
    }
    if (!canonical) throw new Error(`"${code}" is not a valid language code`);
    return canonical;
}

export function languageName(code: string): string | undefined {
    try {
        return new Intl.DisplayNames(["en-GB"], { type: "language", fallback: "none" }).of(code);
    } catch {
        return undefined;
    }
}

const pluralOrder = ["zero", "one", "two", "few", "many", "other"];
const byPluralOrder = (a: string, b: string): number => pluralOrder.indexOf(a) - pluralOrder.indexOf(b);

/// The CLDR plural categories a language needs, from the runtime's own data.
export function pluralCategories(lang: string): string[] {
    return [...new Intl.PluralRules(lang).resolvedOptions().pluralCategories].sort(byPluralOrder);
}

/// A source that spells out "zero" (say, "No cards") keeps it in every
/// language, as Foundation uses it for 0 whatever the language's rules.
export function requiredPluralCategories(lang: string, sourceForms: string[]): string[] {
    const categories = pluralCategories(lang);
    if (sourceForms.includes("zero") && !categories.includes("zero")) categories.push("zero");
    return categories.sort(byPluralOrder);
}

// MARK: - Placeholders

const specifierPattern =
    /%(?:%|(?:(\d+)\$)?#@(\w+)@|arg|(?:(\d+)\$)?([-+#0]*)(\d+|\*)?(?:\.(\d+|\*))?(hh|h|ll|l|q|L|z|t|j)?([@dDiuUxXoOfFeEgGcCsSpaA]))/g;

export interface Placeholder {
    raw: string;
    /** Position and specifier, so %@ %@ and %2$@ %1$@ compare equal. */
    key: string;
}

export function placeholders(text: string): Placeholder[] {
    const found: Placeholder[] = [];
    let next = 1;
    for (const match of text.matchAll(specifierPattern)) {
        const raw = match[0];
        if (raw === "%%" || raw === "%arg") {
            found.push({ raw, key: raw });
        } else if (match[2] !== undefined) {
            found.push({ raw, key: `#@${match[2]}@` });
        } else {
            const position = match[3] !== undefined ? Number(match[3]) : next++;
            const precision = match[6] !== undefined ? `.${match[6]}` : "";
            found.push({ raw, key: `${position}$${match[4]}${match[5] ?? ""}${precision}${match[7] ?? ""}${match[8]}` });
        }
    }
    return found;
}

function sameMultiset(a: Placeholder[], b: Placeholder[]): boolean {
    const keys = (list: Placeholder[]): string => list.map((p) => p.key).sort().join("\u0000");
    return a.length === b.length && keys(a) === keys(b);
}

function listPlaceholders(list: Placeholder[]): string {
    return list.length === 0 ? "none" : list.map((p) => p.raw).join(" ");
}

// MARK: - Text and localisations

function isObject(value: unknown): value is Record<string, unknown> {
    return value !== null && typeof value === "object" && !Array.isArray(value);
}

function hasKeys(value: Record<string, unknown> | undefined): value is Record<string, unknown> {
    return value !== undefined && Object.keys(value).length > 0;
}

function baseText(localisation: Localisation): Text | undefined {
    const plural = localisation.variations?.plural;
    if (hasKeys(plural)) return { plural: mapDefined(plural, baseText) };
    const device = localisation.variations?.device;
    if (hasKeys(device)) return { device: mapDefined(device, baseText) };
    if (localisation.stringSet) return [...(localisation.stringSet.values ?? [])];
    if (localisation.stringUnit) return localisation.stringUnit.value ?? "";
    return undefined;
}

function mapDefined<T, R>(record: Record<string, T>, transform: (value: T) => R | undefined): Record<string, R> {
    const result: Record<string, R> = {};
    for (const [key, value] of Object.entries(record)) {
        const mapped = transform(value);
        if (mapped !== undefined) result[key] = mapped;
    }
    return result;
}

export function textOf(localisation: Localisation | undefined): Text | undefined {
    if (!localisation) return undefined;
    const base = baseText(localisation);
    if (!hasKeys(localisation.substitutions)) return base;
    const substitutions: Record<string, { plural: Record<string, string> }> = {};
    for (const [name, substitution] of Object.entries(localisation.substitutions)) {
        substitutions[name] = { plural: mapDefined(substitution.variations?.plural ?? {}, (form) => form.stringUnit?.value) };
    }
    return { format: base ?? "", substitutions };
}

/// The state of every string in a localisation.
function statesOf(localisation: Localisation): string[] {
    const states: string[] = [];
    const visit = (node: Localisation): void => {
        if (node.stringUnit) states.push(node.stringUnit.state ?? "translated");
        if (node.stringSet) states.push(node.stringSet.state ?? "translated");
        for (const child of Object.values(node.variations?.plural ?? {})) visit(child);
        for (const child of Object.values(node.variations?.device ?? {})) visit(child);
        for (const substitution of Object.values(node.substitutions ?? {})) {
            for (const child of Object.values(substitution.variations?.plural ?? {})) visit(child);
        }
    };
    visit(localisation);
    return states;
}

function isPlural(text: unknown): text is { plural: Record<string, Text> } {
    return isObject(text) && isObject(text.plural);
}

function isDevice(text: unknown): text is { device: Record<string, Text> } {
    return isObject(text) && isObject(text.device);
}

function isFormat(text: unknown): text is { format: Text; substitutions: Record<string, { plural: Record<string, string> }> } {
    return isObject(text) && "format" in text && isObject(text.substitutions);
}

const translated = (value: string): Localisation => ({ stringUnit: { state: "translated", value } });

/// The catalogue form of a validated translation. Substitutions take their
/// argument number and format specifier from the source.
export function localisationOf(text: Text, source?: Localisation): Localisation {
    if (typeof text === "string") return translated(text);
    if (Array.isArray(text)) return { stringSet: { state: "translated", values: [...text] } };
    if (isPlural(text)) {
        return { variations: { plural: Object.fromEntries(Object.entries(text.plural).map(([c, v]) => [c, localisationOf(v)])) } };
    }
    if (isDevice(text)) {
        return { variations: { device: Object.fromEntries(Object.entries(text.device).map(([d, v]) => [d, localisationOf(v)])) } };
    }
    const localisation = localisationOf(text.format, source);
    localisation.substitutions = {};
    for (const [name, substitution] of Object.entries(text.substitutions)) {
        const { variations: _variations, ...fields } = source?.substitutions?.[name] ?? {};
        localisation.substitutions[name] = {
            ...fields,
            variations: { plural: Object.fromEntries(Object.entries(substitution.plural).map(([c, v]) => [c, translated(v)])) },
        };
    }
    return localisation;
}

function strings(text: Text): string[] {
    if (typeof text === "string") return [text];
    if (Array.isArray(text)) return text;
    if (isPlural(text)) return Object.values(text.plural).flatMap(strings);
    if (isDevice(text)) return Object.values(text.device).flatMap(strings);
    return [...strings(text.format), ...Object.values(text.substitutions).flatMap((s) => Object.values(s.plural))];
}

function sourcePluralForms(text: Text): string[] | undefined {
    if (typeof text === "string" || Array.isArray(text)) return undefined;
    let forms: string[] | undefined;
    const add = (more: string[] | undefined): void => {
        if (more) forms = [...new Set([...(forms ?? []), ...more])];
    };
    if (isPlural(text)) add(Object.keys(text.plural));
    else if (isDevice(text)) Object.values(text.device).forEach((variant) => add(sourcePluralForms(variant)));
    else {
        add(sourcePluralForms(text.format));
        Object.values(text.substitutions).forEach((s) => add(Object.keys(s.plural)));
    }
    return forms;
}

// MARK: - Validation

export interface Problem {
    kind: "missing" | "invalid" | "review";
    message: string;
}

const missing = (message: string): Problem => ({ kind: "missing", message });
const invalid = (message: string): Problem => ({ kind: "invalid", message });

function validateString(candidates: string[], translation: string, at: string): Problem[] {
    if (translation.trim() === "" && candidates.some((candidate) => candidate.trim() !== "")) return [missing(`${at}empty translation`)];
    const got = placeholders(translation);
    if (candidates.some((candidate) => sameMultiset(placeholders(candidate), got))) return [];
    return [invalid(`${at}placeholders ${listPlaceholders(got)} do not match the source's ${listPlaceholders(placeholders(candidates[0]))}`)];
}

/// Checks a translation against its source: present, not empty, the same
/// shape, the same placeholders (as a multiset), and exactly the plural
/// categories the language needs.
export function validate(source: Text, translation: unknown, lang: string, path = ""): Problem[] {
    const at = path ? `${path}: ` : "";
    if (translation === undefined || translation === null) return [missing(`${at}no translation`)];

    if (typeof source === "string") {
        if (typeof translation !== "string") return [invalid(`${at}expected a string`)];
        return validateString([source], translation, at);
    }

    if (Array.isArray(source)) {
        if (!Array.isArray(translation) || !translation.every((value) => typeof value === "string")) {
            return [invalid(`${at}expected a list of strings`)];
        }
        if (translation.every((value: string) => value.trim() === "")) return [missing(`${at}empty translation`)];
        return translation.flatMap((value: string) => validateString(source.length > 0 ? source : [""], value, at));
    }

    if (isPlural(source)) {
        if (!isPlural(translation)) return [invalid(`${at}expected {"plural": …}`)];
        const required = requiredPluralCategories(lang, Object.keys(source.plural));
        const forms = translation.plural;
        const problems: Problem[] = [];
        const absent = required.filter((category) => forms[category] === undefined || forms[category] === null);
        if (absent.length > 0) problems.push(missing(`${at}missing plural ${absent.length === 1 ? "category" : "categories"} ${absent.join(", ")}`));
        const extra = Object.keys(forms).filter((category) => !required.includes(category));
        if (extra.length > 0) problems.push(invalid(`${at}unexpected plural ${extra.join(", ")} (${lang} uses ${required.join(", ")})`));
        for (const category of required) {
            const form = forms[category];
            if (form === undefined || form === null) continue;
            const candidates = [source.plural[category], source.plural.other ?? Object.values(source.plural)[0]].filter((c) => c !== undefined);
            const where = `${path ? `${path}.` : ""}${category}`;
            if (candidates.every((c) => typeof c === "string") && typeof form === "string") {
                problems.push(...validateString(candidates as string[], form, `${where}: `));
            } else {
                problems.push(...validate(candidates[0], form, lang, where));
            }
        }
        return problems;
    }

    if (isDevice(source)) {
        if (!isDevice(translation)) return [invalid(`${at}expected {"device": …}`)];
        const problems: Problem[] = [];
        for (const [device, variant] of Object.entries(source.device)) {
            problems.push(...validate(variant, translation.device[device], lang, `${path ? `${path}.` : ""}${device}`));
        }
        const extra = Object.keys(translation.device).filter((device) => !(device in source.device));
        if (extra.length > 0) problems.push(invalid(`${at}unexpected device ${extra.join(", ")}`));
        return problems;
    }

    if (!isFormat(translation)) return [invalid(`${at}expected {"format": …, "substitutions": …}`)];
    const problems = validate(source.format, translation.format, lang, `${path ? `${path}.` : ""}format`);
    for (const [name, substitution] of Object.entries(source.substitutions)) {
        problems.push(...validate({ plural: substitution.plural }, translation.substitutions[name], lang, `${path ? `${path}.` : ""}${name}`));
    }
    const extra = Object.keys(translation.substitutions).filter((name) => !(name in source.substitutions));
    if (extra.length > 0) problems.push(invalid(`${at}unexpected substitution ${extra.join(", ")}`));
    return problems;
}

// MARK: - Units

export interface Unit {
    catalogue: Catalogue;
    key: string;
    entry: Entry;
    source: Text;
}

export type Status = "translated" | "missing" | "review" | "invalid";

/// The units to translate in a catalogue, plus its stale keys (no longer in
/// the code) and the number marked shouldTranslate: false.
export function unitsOf(catalogue: Catalogue): { units: Unit[]; stale: string[]; untranslatable: number } {
    const units: Unit[] = [];
    const stale: string[] = [];
    let untranslatable = 0;
    for (const key of Object.keys(catalogue.doc.strings).sort(compareKeys)) {
        const entry = catalogue.doc.strings[key];
        if (entry.shouldTranslate === false) {
            untranslatable++;
            continue;
        }
        if (entry.extractionState === "stale") {
            stale.push(key);
            continue;
        }
        const text = textOf(entry.localizations?.[catalogue.doc.sourceLanguage]);
        const source = text === undefined || text === "" ? key : text;
        if (source === "") {
            untranslatable++;
            continue;
        }
        units.push({ catalogue, key, entry, source });
    }
    return { units, stale, untranslatable };
}

export function assess(unit: Unit, lang: string): { status: Status; problems: Problem[] } {
    const localisation = unit.entry.localizations?.[lang];
    const problems = validate(unit.source, textOf(localisation), lang);
    const states = localisation ? statesOf(localisation) : [];
    if (states.includes("new")) problems.unshift(missing("not translated yet (state new)"));
    if (problems.some((p) => p.kind === "missing")) return { status: "missing", problems };
    if (problems.length > 0) return { status: "invalid", problems };
    const unreviewed = states.find((state) => state !== "translated");
    if (unreviewed) return { status: "review", problems: [{ kind: "review", message: `needs review (state ${unreviewed})` }] };
    return { status: "translated", problems: [] };
}

// MARK: - Payload, prompt and reply

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
        placeholders: [...new Set(strings(unit.source).flatMap((s) => placeholders(s).map((p) => p.raw)))],
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
    sections.push(`## How to translate

- Write ${name} the way Apple writes it on iOS. Use the exact names Apple's ${name} iOS gives its own apps, features and settings, such as Settings, Camera, Wallet, Lock Screen, Home Screen, Notifications, Location Services, Photos and iCloud, and Apple's ${name} wording for standard controls such as Cancel, Done, Edit, Delete, Save, Add, Allow and OK.
- Use the register of Apple's own ${name} iOS interface: the same level of formality and the same way of addressing the user, and Apple's ${name} conventions for capitalisation, punctuation and quotation marks in titles, buttons, alerts and permission prompts. Do not copy English title case if ${name} does not use it.
- Be concise. The strings appear in buttons, navigation bars, list rows, alerts and notifications on an iPhone. Keep each one about as long as the source, and never add explanations.
- Keep placeholders. Every placeholder in "placeholders" (such as %@, %lld, %d, %1$@, %%, %#@name@ and %arg) must appear in the translation as many times as in the source, character for character. You may move a placeholder; if two must change order, number them (%1$@, %2$@). Never translate, add or drop one. %% is a literal percent sign.
- Plurals. When "source" is {"plural": …}, the translation is {"plural": …} with exactly the categories in "pluralCategories": the plural categories ${name} needs, which can differ from English. Each form must read correctly for every number in its category and keep the number's placeholder.
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
            else if (code !== 0) reject(new Error(`exited with ${code ?? signal}: ${stderr.trim().split("\n").slice(-5).join(" ") || "no output"}`));
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

export interface Translation {
    lang: string;
    unit: Unit;
    text: Text;
}

export function unitsNeedingWork(catalogues: Catalogue[], lang: string, force: boolean): Unit[] {
    return catalogues.flatMap((catalogue) => unitsOf(catalogue).units.filter((unit) => force || assess(unit, lang).status !== "translated"));
}

const unitId = (catalogue: string, key: string): string => `${catalogue}\u0000${key}`;

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
        const units = unitsNeedingWork(catalogues, lang, options.force);
        if (units.length === 0) {
            options.log(`${lang}: nothing to translate`);
            return { done: [] as Translation[], failed: [] as Failure[] };
        }
        const batches: Unit[][] = [];
        for (let start = 0; start < units.length; start += options.batchSize) batches.push(units.slice(start, start + options.batchSize));
        const done: Translation[] = [];
        const failed: Failure[] = [];
        for (const [index, batch] of batches.entries()) {
            const result = await translateBatch(batch, lang, `${lang} batch ${index + 1}/${batches.length}`, options);
            done.push(...result.done);
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

export function applyTranslation(unit: Unit, lang: string, text: Text): void {
    const sourceLocalisation = unit.entry.localizations?.[unit.catalogue.doc.sourceLanguage];
    unit.entry.localizations ??= {};
    unit.entry.localizations[lang] = localisationOf(text, sourceLocalisation);
}

// MARK: - Commands

function table(rows: string[][]): string {
    const widths = rows[0].map((_, column) => Math.max(...rows.map((row) => row[column].length)));
    return rows.map((row) => row.map((cell, column) => (column < 2 ? cell.padEnd(widths[column]) : cell.padStart(widths[column]))).join("  ").trimEnd()).join("\n");
}

export function statusReport(catalogues: Catalogue[], languages: string[]): string {
    const rows = [["Catalogue", "Language", "Translated", "Missing", "Needs review", "Invalid", "Stale"]];
    const notes: string[] = [];
    for (const catalogue of catalogues) {
        const { units, stale, untranslatable } = unitsOf(catalogue);
        notes.push(`${catalogue.name}: ${units.length} to translate, ${untranslatable} not translatable, ${stale.length} stale`);
        for (const lang of languages) {
            const counts: Record<Status, number> = { translated: 0, missing: 0, review: 0, invalid: 0 };
            for (const unit of units) counts[assess(unit, lang).status]++;
            const staleHere = stale.filter((key) => catalogue.doc.strings[key].localizations?.[lang] !== undefined).length;
            rows.push([catalogue.name, lang, counts.translated, counts.missing, counts.review, counts.invalid, staleHere].map(String));
        }
    }
    return `${notes.join("\n")}\n\n${table(rows)}`;
}

export function checkReport(catalogues: Catalogue[], languages: string[]): { errors: string[]; warnings: string[] } {
    const errors: string[] = [];
    const warnings: string[] = [];
    for (const catalogue of catalogues) {
        const { units, stale } = unitsOf(catalogue);
        if (stale.length > 0) {
            warnings.push(`${catalogue.name}: ${stale.length} stale key${stale.length === 1 ? "" : "s"} no longer in the code: ${stale.map((k) => JSON.stringify(k)).join(", ")}`);
        }
        for (const lang of languages) {
            for (const unit of units) {
                for (const problem of assess(unit, lang).problems) {
                    errors.push(`${catalogue.name} [${lang}] ${JSON.stringify(unit.key)}: ${problem.message}`);
                }
            }
        }
    }
    return { errors, warnings };
}

export interface ImportResult {
    applied: number;
    skipped: number;
    problems: string[];
}

/// Applies a filled-in payload, validating each unit exactly as translate does.
export function importReply(catalogues: Catalogue[], lang: string, reply: string): ImportResult {
    const result: ImportResult = { applied: 0, skipped: 0, problems: [] };
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
                applyTranslation(unit, lang, answer.translation as Text);
                result.applied++;
            }
        }
    }
    return result;
}

const usage = `Usage: node scripts/l10n.ts <command> [options]

Commands:
  status                            Translated, missing, needs-review and stale counts
  check                             Fail if any language is incomplete or broken
  translate [--lang <code>…] [--force]
                                    Translate what needs it (all languages by default)
  export --lang <code> --out <file> [--force]
                                    Write the payload for a person or another AI
  import --lang <code> <file>       Apply a filled-in payload
  add-language <code>               Add a language to the project, then translate it
  normalise [<file>…]               Rewrite catalogues in Xcode's format

Options:
  --root <dir>        Repository root (default: the one holding this script)
  --jobs <n>          Languages translated in parallel (default 3)
  --batch-size <n>    Units per AI call (default 50)

Environment:
  L10N_AI_COMMAND     Shell command: prompt on stdin, reply on stdout
                      (default: ${defaultAICommand})
  L10N_AI_TIMEOUT     Seconds allowed per call (default 900)`;

class UsageError extends Error {}

function positiveInteger(value: string | undefined, fallback: number, option: string): number {
    if (value === undefined) return fallback;
    const number = Number(value);
    if (!Number.isInteger(number) || number < 1) throw new UsageError(`${option} needs a whole number above 0`);
    return number;
}

function cliLanguage(code: string): string {
    try {
        return canonicalLanguage(code);
    } catch (error) {
        throw new UsageError((error as Error).message);
    }
}

function languageArguments(values: string[] | undefined): string[] {
    return (values ?? []).flatMap((value) => value.split(/[\s,]+/)).filter(Boolean).map(cliLanguage);
}

function requireProjectLanguages(requested: string[], languages: string[]): string[] {
    for (const lang of requested) {
        if (!languages.includes(lang)) {
            throw new UsageError(`${lang} is not a project language (${languages.join(", ") || "none yet"}); add it with add-language`);
        }
    }
    return [...new Set(requested)];
}

function readBrief(project: Project): string {
    const path = join(project.l10n, "context.md");
    if (!existsSync(path)) throw new Error(`${relative(project.root, path)} is missing; the AI needs the translator brief`);
    return readFileSync(path, "utf8");
}

function readNotes(project: Project, lang: string): string | undefined {
    const path = join(project.l10n, "languages", `${lang}.md`);
    return existsSync(path) ? readFileSync(path, "utf8") : undefined;
}

const log = (line: string): void => console.error(`l10n: ${line}`);

async function runTranslate(project: Project, catalogues: Catalogue[], languages: string[], force: boolean, jobs: number, batchSize: number): Promise<number> {
    if (catalogues.length === 0) {
        log("no String Catalogues under Cards/, nothing to translate");
        return 0;
    }
    const command = process.env.L10N_AI_COMMAND || defaultAICommand;
    const timeout = positiveInteger(process.env.L10N_AI_TIMEOUT, 900, "L10N_AI_TIMEOUT") * 1000;
    const { translations, failures } = await translate(catalogues, {
        languages,
        force,
        jobs,
        batchSize,
        brief: readBrief(project),
        notes: (lang) => readNotes(project, lang),
        ask: (prompt) => runCommand(command, prompt, timeout, project.root),
        log,
    });
    for (const catalogue of catalogues) {
        if (saveCatalogue(catalogue)) log(`wrote ${catalogue.name}`);
    }
    for (const failure of failures) {
        console.error(`error: ${failure.catalogue} [${failure.lang}] ${JSON.stringify(failure.key)}: ${failure.problems.join("; ")}`);
    }
    console.log(`Translated ${translations.length} unit${translations.length === 1 ? "" : "s"}${failures.length > 0 ? `; ${failures.length} failed after 3 attempts` : ""}.`);
    return failures.length > 0 ? 1 : 0;
}

export async function main(argv: string[]): Promise<number> {
    const { values, positionals } = parseArgs({
        args: argv,
        allowPositionals: true,
        options: {
            root: { type: "string" },
            lang: { type: "string", multiple: true },
            force: { type: "boolean", default: false },
            out: { type: "string" },
            jobs: { type: "string" },
            "batch-size": { type: "string" },
            help: { type: "boolean", short: "h", default: false },
        },
    });
    const [command, ...rest] = positionals;
    if (values.help || !command) {
        console.log(usage);
        return command || values.help ? 0 : 2;
    }
    const project = projectAt(resolve(values.root ?? join(import.meta.dirname, "..")));
    const jobs = positiveInteger(values.jobs, 3, "--jobs");
    const batchSize = positiveInteger(values["batch-size"], 50, "--batch-size");
    const pbxproj = (): string => readFileSync(project.pbxproj, "utf8");
    const noArguments = (): void => {
        if (rest.length > 0) throw new UsageError(`${command} takes no arguments (got ${rest.join(" ")})`);
    };

    switch (command) {
        case "status": {
            noArguments();
            const catalogues = loadCatalogues(project);
            const languages = projectLanguages(pbxproj());
            if (catalogues.length === 0) console.log("No String Catalogues under Cards/.");
            else console.log(statusReport(catalogues, languages));
            return 0;
        }
        case "check": {
            noArguments();
            const catalogues = loadCatalogues(project);
            const languages = projectLanguages(pbxproj());
            if (catalogues.length === 0) console.error("warning: no String Catalogues under Cards/");
            if (languages.length === 0) console.error("warning: the project has no languages besides en and Base");
            const { errors, warnings } = checkReport(catalogues, languages);
            for (const warning of warnings) console.error(`warning: ${warning}`);
            for (const error of errors) console.error(`error: ${error}`);
            const units = catalogues.reduce((sum, catalogue) => sum + unitsOf(catalogue).units.length, 0);
            console.log(`Checked ${units} key${units === 1 ? "" : "s"} in ${catalogues.length} catalogue${catalogues.length === 1 ? "" : "s"} × ${languages.length} language${languages.length === 1 ? "" : "s"}: ${errors.length} error${errors.length === 1 ? "" : "s"}, ${warnings.length} warning${warnings.length === 1 ? "" : "s"}.`);
            return errors.length > 0 ? 1 : 0;
        }
        case "translate": {
            noArguments();
            const languages = projectLanguages(pbxproj());
            const requested = languageArguments(values.lang);
            const chosen = requested.length > 0 ? requireProjectLanguages(requested, languages) : languages;
            return runTranslate(project, loadCatalogues(project), chosen, values.force, jobs, batchSize);
        }
        case "export": {
            noArguments();
            const [lang, ...others] = requireProjectLanguages(languageArguments(values.lang), projectLanguages(pbxproj()));
            if (!lang || others.length > 0) throw new UsageError("export needs exactly one --lang");
            if (!values.out) throw new UsageError("export needs --out <file> (- for stdout)");
            const catalogues = loadCatalogues(project);
            const units = unitsNeedingWork(catalogues, lang, values.force);
            const text = `${JSON.stringify(payloadFor(units, lang, catalogues[0]?.doc.sourceLanguage), null, 2)}\n`;
            if (values.out === "-") process.stdout.write(text);
            else writeFileSync(values.out, text);
            log(`exported ${units.length} unit${units.length === 1 ? "" : "s"} for ${lang}${values.out === "-" ? "" : ` to ${values.out}`}`);
            return 0;
        }
        case "import": {
            const [file, ...others] = rest;
            if (!file || others.length > 0) throw new UsageError("import needs one file: import --lang <code> <file>");
            const [lang, ...extra] = requireProjectLanguages(languageArguments(values.lang), projectLanguages(pbxproj()));
            if (!lang || extra.length > 0) throw new UsageError("import needs exactly one --lang");
            const catalogues = loadCatalogues(project);
            const result = importReply(catalogues, lang, readFileSync(file, "utf8"));
            for (const catalogue of catalogues) {
                if (saveCatalogue(catalogue)) log(`wrote ${catalogue.name}`);
            }
            for (const problem of result.problems) console.error(`error: ${problem}`);
            console.log(`Imported ${result.applied} translation${result.applied === 1 ? "" : "s"} for ${lang}; ${result.skipped} left empty; ${result.problems.length} problem${result.problems.length === 1 ? "" : "s"}.`);
            return result.problems.length > 0 ? 1 : 0;
        }
        case "add-language": {
            const [code, ...others] = rest;
            if (!code || others.length > 0) throw new UsageError("add-language needs one language code, such as fr or pt-BR");
            const lang = cliLanguage(code);
            const name = languageName(lang);
            if (!name) throw new UsageError(`${lang} is not a language the system knows`);
            const catalogues = loadCatalogues(project);
            const source = catalogues[0]?.doc.sourceLanguage ?? "en";
            if (lang === "en" || lang === source) throw new UsageError(`${lang} is the source language`);
            const edit = addKnownRegion(pbxproj(), lang);
            if (edit.changed) {
                writeFileSync(project.pbxproj, edit.text);
                console.log(`Added ${lang} (${name}) to knownRegions in ${relative(project.root, project.pbxproj)}.`);
            } else {
                console.log(`${lang} (${name}) is already a project language.`);
            }
            return runTranslate(project, catalogues, [lang], values.force, jobs, batchSize);
        }
        case "normalise": {
            const paths = rest.length > 0 ? rest.map((path) => resolve(path)) : findCatalogues(project);
            for (const catalogue of loadCatalogues(project, paths)) {
                console.log(saveCatalogue(catalogue) ? `Rewrote ${catalogue.name} in Xcode's format.` : `${catalogue.name} is already in Xcode's format.`);
            }
            return 0;
        }
        default:
            throw new UsageError(`unknown command ${command}`);
    }
}

if (import.meta.main) {
    process.on("SIGINT", () => {
        for (const pid of runningGroups) killGroup(pid, "SIGTERM");
        process.exit(130);
    });
    main(process.argv.slice(2)).then(
        (code) => process.exit(code),
        (error: unknown) => {
            const usageProblem = error instanceof UsageError || (error as { code?: string }).code?.startsWith("ERR_PARSE_ARGS");
            console.error(`l10n: ${(error as Error).message}`);
            if (usageProblem) console.error("Run node scripts/l10n.ts --help for usage.");
            process.exit(usageProblem ? 2 : 1);
        },
    );
}
