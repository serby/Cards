// The changelog: changelog.json is the source, and these read, check and
// render it for everything that shows it, so the app, the repository and the
// App Store always agree. The commands that use it:
//
//   node scripts/generate-changelog.ts      writes CHANGELOG.md and each store
//                                           locale's metadata/<locale>/release_notes.txt
//   node scripts/check-changelog.ts         fails if changelog.json is malformed,
//                                           its newest version is not the app's,
//                                           or a generated file is out of date (CI)
//   node scripts/print-release-notes.ts 1.3 [--locale es-MX]
//                                           prints a version's What's New, for the
//                                           release tag's message
//
// changelog.json lists versions newest first. Each change has a type (new,
// improved or fixed), its text in British English, and its translations as
// flat keys beside text. A key is one of the app's languages ("es", "de",
// "ja": the project's knownRegions), or a store locale (a folder in metadata/)
// of one of those languages or of English, where that listing's text differs:
// "en-US" for American English, "es-MX" for Mexican Spanish. A store locale's
// text is its own key's, else its language's, else, for English, text. The
// newest version needs a text for every store locale, because its What's New
// is generated for each; older ones may lack translations, and the app shows
// those in English. The app bundles changelog.json and shows it in Settings >
// What's New. Entries are written by the release skill
// (.claude/skills/release/SKILL.md).
//
// Usage: import { load, validate, staleOutputs } from "./lib/changelog.ts";

import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { appLanguages, languageOf, sourceLocale, storeLocales } from "./locales.ts";

const root = join(import.meta.dirname, "..", "..");
const types = ["new", "improved", "fixed"] as const;
type ChangeType = (typeof types)[number];
const headings: Record<ChangeType, string> = { new: "New", improved: "Improved", fixed: "Fixed" };
/// The store locale whose text is `text` itself, so it never has a key of its own.
const textLocale = sourceLocale;

export interface Change {
    type: ChangeType;
    /// British English.
    text: string;
    /// Translations and regional texts, keyed by app language or store locale.
    [translation: string]: string | undefined;
}

export interface Version {
    version: string;
    /// The day it was released on the App Store, or null while it is being prepared.
    date: string | null;
    changes: Change[];
}

export interface Changelog {
    versions: Version[];
}

/// What the translation keys may name.
export interface Locales {
    /// The listing's locales, the folders in metadata/.
    store: string[];
    /// The app's languages, the project's knownRegions less en and Base.
    app: string[];
}

/// A generated file and the text it should hold.
export interface Output {
    path: string;
    /// The path relative to the repository root, for messages.
    name: string;
    text: string;
}

export function readLocales(rootDir: string = root): Locales {
    return { store: storeLocales(rootDir), app: appLanguages(rootDir) };
}

/// A change's text for a store locale, or undefined when it has none.
export function textFor(change: Change, locale: string): string | undefined {
    const language = languageOf(locale);
    return change[locale] ?? change[language] ?? (language === "en" ? change.text : undefined);
}

/// The keys a change may carry besides type and text.
function translationKeys(locales: Locales): Set<string> {
    const languages = new Set(["en", ...locales.app]);
    const regional = locales.store.filter((locale) => locale !== textLocale && languages.has(languageOf(locale)));
    return new Set([...locales.app, ...regional]);
}

function excerpt(text: string): string {
    return JSON.stringify(text.length > 50 ? `${text.slice(0, 49)}…` : text);
}

/// Problems with the changelog's shape, empty when it is well formed.
export function validate(changelog: Changelog, locales: Locales = readLocales()): string[] {
    const problems: string[] = [];
    if (!Array.isArray(changelog.versions) || changelog.versions.length === 0) return ["changelog.json has no versions"];
    const allowed = translationKeys(locales);
    const seen = new Set<string>();
    changelog.versions.forEach((entry, index) => {
        const where = `versions[${index}] (${entry.version})`;
        if (!/^\d+(\.\d+){1,2}$/.test(entry.version ?? "")) problems.push(`${where}: version must look like 1.3 or 1.3.1`);
        if (seen.has(entry.version)) problems.push(`${where}: version listed twice`);
        seen.add(entry.version);
        if (entry.date !== null && !/^\d{4}-\d{2}-\d{2}$/.test(entry.date ?? "")) problems.push(`${where}: date must be YYYY-MM-DD or null`);
        if (entry.date === null && index > 0) problems.push(`${where}: only the newest version can be unreleased`);
        if (!Array.isArray(entry.changes) || entry.changes.length === 0) problems.push(`${where}: no changes`);
        for (const change of entry.changes ?? []) {
            if (!types.includes(change.type)) problems.push(`${where}: type must be one of ${types.join(", ")}, not ${change.type}`);
            if (typeof change.text !== "string" || !change.text.trim()) {
                problems.push(`${where}: a change has no text`);
                continue;
            }
            const which = `${where}: ${excerpt(change.text)}`;
            for (const [key, value] of Object.entries(change)) {
                if (key === "type" || key === "text") continue;
                if (key === textLocale) problems.push(`${which}: has an ${textLocale} text, but text is ${textLocale}'s`);
                else if (!allowed.has(key)) problems.push(`${which}: unknown field ${key}; translations are keyed by an app language or a store locale (${[...allowed].sort().join(", ")})`);
                if (typeof value !== "string" || !value.trim()) problems.push(`${which}: its ${key} text is empty`);
            }
            if (index === 0) {
                const missing = locales.store.filter((locale) => !textFor(change, locale)?.trim());
                if (missing.length > 0) problems.push(`${which}: no text for ${missing.join(", ")}; the newest version's What's New is generated for every store locale`);
            }
        }
    });
    const ordered = [...changelog.versions].sort((a, b) => compareVersions(b.version, a.version));
    if (ordered.some((entry, index) => entry !== changelog.versions[index])) problems.push("versions must be listed newest first");
    return problems;
}

/// Throws with every problem, if there are any.
export function throwIfProblems(problems: string[]): void {
    if (problems.length > 0) throw new Error(`changelog.json:\n  ${problems.join("\n  ")}`);
}

function compareVersions(a: string, b: string): number {
    const [x, y] = [a.split(".").map(Number), b.split(".").map(Number)];
    for (let index = 0; index < Math.max(x.length, y.length); index++) {
        const difference = (x[index] ?? 0) - (y[index] ?? 0);
        if (difference !== 0) return difference;
    }
    return 0;
}

/// A version's changes, new first, then improved, then fixed.
function grouped(version: Version): [ChangeType, Change[]][] {
    return types.map((type) => [type, version.changes.filter((change) => change.type === type)] as [ChangeType, Change[]])
        .filter(([, changes]) => changes.length > 0);
}

/// What's New for the App Store: one change a line, new first. Throws if a
/// change has no text for the locale, as an older version's may not.
export function releaseNotes(version: Version, locale: string): string {
    const changes = grouped(version).flatMap(([, list]) => list);
    const missing = changes.filter((change) => textFor(change, locale) === undefined);
    if (missing.length > 0) throw new Error(`${version.version} has no ${locale} text for ${missing.map((change) => excerpt(change.text)).join(", ")}`);
    return changes.map((change) => textFor(change, locale)).join("\n") + "\n";
}

export function markdown(changelog: Changelog): string {
    const lines = [
        "# Changelog",
        "",
        "Every version of Card Barcodes and what it changed, newest first. This file is generated from `changelog.json` by `node scripts/generate-changelog.ts`: edit that, not this. The app shows the same list in Settings > What's New.",
    ];
    for (const version of changelog.versions) {
        lines.push("", `## ${version.version}${version.date ? ` (${formatDate(version.date)})` : " (in preparation)"}`);
        for (const [type, changes] of grouped(version)) {
            lines.push("", `### ${headings[type]}`, "", ...changes.map((change) => `- ${change.text}`));
        }
    }
    return lines.join("\n") + "\n";
}

function formatDate(date: string): string {
    return new Date(`${date}T12:00:00Z`).toLocaleDateString("en-GB", { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" });
}

export function load(rootDir: string = root): Changelog {
    return JSON.parse(readFileSync(join(rootDir, "changelog.json"), "utf8")) as Changelog;
}

/// The app's version, from the project-level MARKETING_VERSION.
export function appVersion(rootDir: string = root): string {
    const project = readFileSync(join(rootDir, "Cards.xcodeproj/project.pbxproj"), "utf8");
    const versions = [...new Set([...project.matchAll(/MARKETING_VERSION = ([\d.]+);/g)].map((match) => match[1] ?? ""))];
    const [version] = versions;
    if (versions.length !== 1 || !version) throw new Error(`Expected one MARKETING_VERSION, found ${versions.join(", ") || "none"}`);
    return version;
}

/// Every generated file and the text it should hold.
function outputs(changelog: Changelog, locales: Locales, rootDir: string): Map<string, string> {
    const files = new Map([[join(rootDir, "CHANGELOG.md"), markdown(changelog)]]);
    const newest = changelog.versions[0];
    if (!newest) throw new Error("changelog.json has no versions");
    for (const locale of locales.store) {
        files.set(join(rootDir, "metadata", locale, "release_notes.txt"), releaseNotes(newest, locale));
    }
    return files;
}

/// The generated files that do not yet hold what the changelog makes them, in
/// the order they are generated.
export function staleOutputs(changelog: Changelog, locales: Locales = readLocales(), rootDir: string = root): Output[] {
    return [...outputs(changelog, locales, rootDir)]
        .filter(([path, text]) => (existsSync(path) ? readFileSync(path, "utf8") : undefined) !== text)
        .map(([path, text]) => ({ path, name: path.slice(rootDir.length + 1), text }));
}
