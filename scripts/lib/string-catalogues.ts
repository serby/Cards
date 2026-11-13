// The app's String Catalogues, for the scripts that check, report, translate,
// export, import and normalise them, and add or remove a language: the
// catalogue model, Xcode's file format, the project's languages
// (knownRegions), placeholder and plural validation, the units to translate,
// the check and status reports, and the arguments those scripts share.
// Translating with AI is in translation.ts.
//
// The languages are the project's knownRegions less en and Base, and the
// catalogues are every *.xcstrings under the targets' source folders, Cards/
// (the app), CardsWidget/ (the widget extension) and CardsWatch/ (the Apple
// Watch app), except Cards/Development,
// so there is no separate configuration. A string compiled into both targets
// is in both catalogues; it is translated once and must read the same in both.
// Catalogues are written in Xcode's own format, so Xcode re-saving them
// changes nothing.
//
// Usage: import { checkReport, languagesOf, loadCatalogues, projectFrom } from "./lib/string-catalogues.ts";

import { spawnSync } from "node:child_process";
import { existsSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { join, relative, resolve } from "node:path";
import { UsageError } from "./command-line.ts";
import { root as repositoryRoot } from "./xcode.ts";

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
    /// The folders whose files the targets compile, one per target that ships:
    /// each has its own bundle, so its own catalogues.
    sources: string[];
    development: string;
    l10n: string;
}

export function projectAt(root: string): Project {
    return {
        root,
        pbxproj: join(root, "Cards.xcodeproj", "project.pbxproj"),
        sources: [join(root, "Cards"), join(root, "CardsWidget"), join(root, "CardsWatch")],
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
    for (const sources of project.sources) {
        if (existsSync(sources)) walk(sources);
    }
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

/// Writes every catalogue that changed, and logs each one it wrote.
export function saveCatalogues(catalogues: Catalogue[], log: (line: string) => void): void {
    for (const catalogue of catalogues) {
        if (saveCatalogue(catalogue)) log(`wrote ${catalogue.name}`);
    }
}

// MARK: - The project's languages

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

/// Takes the code out of every knownRegions list that has it, as Xcode's
/// project editor does, so the diff is that line and nothing else.
export function removeKnownRegion(pbxproj: string, code: string): { text: string; changed: boolean } {
    let changed = false;
    const text = pbxproj.replace(knownRegionsPattern, (whole: string, indent: string, body: string) => {
        const lines = body.split("\n");
        const kept = lines.filter((line) => unquote(line.trim().replace(/,$/, "")) !== code);
        if (kept.length === lines.length) return whole;
        changed = true;
        return `${indent}knownRegions = (${kept.join("\n")});`;
    });
    return { text, changed };
}

export function projectLanguages(pbxproj: string, sourceLanguage = "en"): string[] {
    return readKnownRegions(pbxproj).filter((region) => region !== "Base" && region !== "en" && region !== sourceLanguage);
}

/// The project's languages, read from its project file.
export function languagesOf(project: Project): string[] {
    return projectLanguages(readFileSync(project.pbxproj, "utf8"));
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

/// The one whole number a plural category stands for in a language, if it
/// stands for exactly one: Arabic "zero", "one" and "two", English "one", but
/// not French "one" (0 and 1) or Russian "one" (1, 21, 31 …). "zero" always
/// means 0, because Foundation uses a source's "zero" form for 0 in every
/// language.
export function singleNumber(lang: string, category: string): number | undefined {
    if (category === "zero") return 0;
    const rules = new Intl.PluralRules(lang);
    const matches: number[] = [];
    for (let n = 0; n <= 1000 && matches.length < 2; n++) if (rules.select(n) === category) matches.push(n);
    return matches.length === 1 ? matches[0] : undefined;
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

export function isObject(value: unknown): value is Record<string, unknown> {
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

/// Every string in a text: its value, list items, forms and variants.
export function stringsIn(text: Text): string[] {
    if (typeof text === "string") return [text];
    if (Array.isArray(text)) return text;
    if (isPlural(text)) return Object.values(text.plural).flatMap(stringsIn);
    if (isDevice(text)) return Object.values(text.device).flatMap(stringsIn);
    return [...stringsIn(text.format), ...Object.values(text.substitutions).flatMap((s) => Object.values(s.plural))];
}

/// The plural categories a source text spells out, if it has plural forms.
export function sourcePluralForms(text: Text): string[] | undefined {
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

const isCount = (p: Placeholder): boolean => p.raw === "%arg" || /[dDiuU]$/.test(p.key);

/// A form for a single number may spell it out ("بطاقة واحدة", "One card") and
/// leave out the count, so long as every other placeholder keeps its position.
function withoutCount(list: Placeholder[]): Placeholder[][] {
    return list.flatMap((p, index) => (isCount(p) ? [[...list.slice(0, index), ...list.slice(index + 1)]] : []));
}

function validateString(candidates: string[], translation: string, at: string, mayDropCount = false): Problem[] {
    if (translation.trim() === "" && candidates.some((candidate) => candidate.trim() !== "")) return [missing(`${at}empty translation`)];
    const got = placeholders(translation);
    const accepted = candidates.flatMap((candidate) => {
        const expected = placeholders(candidate);
        return mayDropCount ? [expected, ...withoutCount(expected)] : [expected];
    });
    if (accepted.some((expected) => sameMultiset(expected, got))) return [];
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
                problems.push(...validateString(candidates as string[], form, `${where}: `, singleNumber(lang, category) !== undefined));
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

/// Puts a validated translation into the unit's entry.
export function applyTranslation(unit: Unit, lang: string, text: Text): void {
    const sourceLocalisation = unit.entry.localizations?.[unit.catalogue.doc.sourceLanguage];
    unit.entry.localizations ??= {};
    unit.entry.localizations[lang] = localisationOf(text, sourceLocalisation);
}

// MARK: - Strings in both targets

export interface Translation {
    lang: string;
    unit: Unit;
    text: Text;
}

/// Identifies a unit by catalogue and key: every unitsOf call makes new units.
export const unitId = (catalogue: string, key: string): string => `${catalogue}\u0000${key}`;

export function unitsNeedingWork(catalogues: Catalogue[], lang: string, force: boolean): Unit[] {
    return catalogues.flatMap((catalogue) => unitsOf(catalogue).units.filter((unit) => force || assess(unit, lang).status !== "translated"));
}

/// What makes units in different catalogues one string: the same key, source
/// and comment. A file compiled into the app and the widget puts its strings in
/// both targets' catalogues, as each bundle needs its own copy, so those twins
/// are translated once and must stay the same.
export function twinKey(unit: Unit): string {
    return formatJSON([unit.key, unit.source, unit.entry.comment ?? ""]);
}

/// Every unit of every catalogue, grouped with its twins.
export function twinsOf(catalogues: Catalogue[]): Map<string, Unit[]> {
    const groups = new Map<string, Unit[]>();
    for (const catalogue of catalogues) {
        for (const unit of unitsOf(catalogue).units) {
            const key = twinKey(unit);
            groups.set(key, [...(groups.get(key) ?? []), unit]);
        }
    }
    return groups;
}

/// The work for one language: one unit to ask for per string that needs it,
/// and copies for units whose twin is already translated, which are never
/// asked for again. With `force`, every string is asked for afresh.
export function planWork(catalogues: Catalogue[], lang: string, force: boolean): { ask: Unit[]; copies: Translation[]; twins: Map<string, Unit[]> } {
    const twins = twinsOf(catalogues);
    const needs = new Set(unitsNeedingWork(catalogues, lang, force).map((unit) => unitId(unit.catalogue.name, unit.key)));
    const needsWork = (unit: Unit): boolean => needs.has(unitId(unit.catalogue.name, unit.key));
    const ask: Unit[] = [];
    const copies: Translation[] = [];
    for (const group of twins.values()) {
        const needing = group.filter(needsWork);
        if (needing.length === 0) continue;
        const settled = force ? undefined : group.find((twin) => !needsWork(twin));
        if (settled) {
            const text = textOf(settled.entry.localizations?.[lang]) as Text;
            copies.push(...needing.map((twin) => ({ lang, unit: twin, text })));
        } else {
            ask.push(needing[0]);
        }
    }
    return { ask, copies, twins };
}

/// A translation of one unit, for it and each of its twins.
export function withTwins(translation: Translation, twins: Map<string, Unit[]>): Translation[] {
    const group = twins.get(twinKey(translation.unit)) ?? [translation.unit];
    return group.map((unit) => ({ ...translation, unit }));
}

// MARK: - Taking a language out and bringing it back

/// Deletes the language's translations from every catalogue, and says how many
/// there were.
export function removeLanguage(catalogues: Catalogue[], lang: string): number {
    let removed = 0;
    for (const catalogue of catalogues) {
        for (const entry of Object.values(catalogue.doc.strings)) {
            if (entry.localizations?.[lang] === undefined) continue;
            delete entry.localizations[lang];
            removed++;
        }
    }
    return removed;
}

/// Brings back the language's translations from `earlier`, the same catalogues
/// as they were in another commit, for every string whose English is unchanged,
/// which is every key still in use, as English is the key. Translations already
/// here are kept. Returns how many came back.
export function restoreLanguage(catalogues: Catalogue[], earlier: Map<string, CatalogueDocument>, lang: string): number {
    let restored = 0;
    for (const catalogue of catalogues) {
        const old = earlier.get(catalogue.name);
        if (!old) continue;
        for (const unit of unitsOf(catalogue).units) {
            const oldEntry = old.strings[unit.key];
            const localisation = oldEntry?.localizations?.[lang];
            if (!localisation || unit.entry.localizations?.[lang] !== undefined) continue;
            const oldText = textOf(oldEntry.localizations?.[old.sourceLanguage]);
            const oldSource = oldText === undefined || oldText === "" ? unit.key : oldText;
            if (formatJSON(oldSource) !== formatJSON(unit.source)) continue;
            unit.entry.localizations = { ...unit.entry.localizations, [lang]: localisation };
            restored++;
        }
    }
    return restored;
}

/// Whether `commit` names a commit in the project's repository.
export function isCommit(project: Project, commit: string): boolean {
    return spawnSync("git", ["rev-parse", "--verify", "--quiet", `${commit}^{commit}`], { cwd: project.root, encoding: "utf8" }).status === 0;
}

/// The catalogues as they were in `commit`, read with git, by catalogue name.
/// A catalogue the commit does not have is left out.
export function cataloguesAt(project: Project, catalogues: Catalogue[], commit: string): Map<string, CatalogueDocument> {
    const found = new Map<string, CatalogueDocument>();
    for (const catalogue of catalogues) {
        const show = spawnSync("git", ["show", `${commit}:${catalogue.name}`], { cwd: project.root, encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
        if (show.status === 0) found.set(catalogue.name, parseCatalogue(show.stdout, `${commit}:${catalogue.name}`));
    }
    return found;
}

// MARK: - Reports

function table(rows: string[][]): string {
    const widths = rows[0].map((_, column) => Math.max(...rows.map((row) => row[column].length)));
    return rows.map((row) => row.map((cell, column) => (column < 2 ? cell.padEnd(widths[column]) : cell.padStart(widths[column]))).join("  ").trimEnd()).join("\n");
}

/// Translated, missing, needs-review, invalid and stale counts for each
/// catalogue and language.
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

/// Every problem that makes a language incomplete or broken (errors), and the
/// stale keys (warnings).
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
    for (const catalogue of catalogues) {
        const leftover = new Map<string, number>();
        for (const entry of Object.values(catalogue.doc.strings)) {
            for (const lang of Object.keys(entry.localizations ?? {})) {
                if (lang !== catalogue.doc.sourceLanguage && !languages.includes(lang)) leftover.set(lang, (leftover.get(lang) ?? 0) + 1);
            }
        }
        for (const [lang, count] of leftover) {
            errors.push(`${catalogue.name} [${lang}]: ${count} translation${count === 1 ? "" : "s"} for a language the project does not have; take them out with node scripts/remove-language.ts ${lang}, or add it back with node scripts/add-language.ts ${lang}`);
        }
    }
    for (const group of twinsOf(catalogues).values()) {
        if (group.length < 2) continue;
        for (const lang of languages) {
            const texts = group.flatMap((unit) => {
                const text = textOf(unit.entry.localizations?.[lang]);
                return text === undefined ? [] : [formatJSON(text)];
            });
            if (new Set(texts).size > 1) {
                const names = group.map((unit) => unit.catalogue.name).join(" and ");
                errors.push(`${names} [${lang}] ${JSON.stringify(group[0].key)}: translated differently; it is one string, compiled into each of those targets`);
            }
        }
    }
    return { errors, warnings };
}

// MARK: - The scripts' arguments

/// The project at --root, or this repository.
export function projectFrom(rootOption: string | undefined): Project {
    return projectAt(resolve(rootOption ?? repositoryRoot));
}

/// The source folders, as messages name them: "Cards/ or CardsWidget/ or CardsWatch/".
export function sourceFolders(project: Project): string {
    return project.sources.map((path) => `${relative(project.root, path)}/`).join(" or ");
}

/// A language code from the command line, canonicalised (pt_br is pt-BR).
export function languageArgument(code: string): string {
    try {
        return canonicalLanguage(code);
    } catch (error) {
        throw new UsageError((error as Error).message);
    }
}

/// The codes in --lang values, each of which may hold several separated by
/// spaces or commas ("de ja"); none means every language.
export function languageArguments(values: string[] | undefined): string[] {
    return (values ?? []).flatMap((value) => value.split(/[\s,]+/)).filter(Boolean).map(languageArgument);
}

/// The requested codes, once each, if every one is a project language.
export function requireProjectLanguages(requested: string[], languages: string[]): string[] {
    for (const lang of requested) {
        if (!languages.includes(lang)) {
            throw new UsageError(`${lang} is not a project language (${languages.join(", ") || "none yet"}); add it with node scripts/add-language.ts`);
        }
    }
    return [...new Set(requested)];
}

/// The one project language that export-strings and import-strings need.
export function oneProjectLanguage(values: string[] | undefined, project: Project): string {
    const [lang, ...others] = requireProjectLanguages(languageArguments(values), languagesOf(project));
    if (!lang || others.length > 0) throw new UsageError("needs exactly one --lang");
    return lang;
}
