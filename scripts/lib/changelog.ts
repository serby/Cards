// The changelog: changelog.json is the source, and these read, check and
// render it for everything that shows it, so the app, the repository and the
// App Store always agree. The commands that use it:
//
//   node scripts/generate-changelog.ts      writes CHANGELOG.md and each locale's
//                                           metadata/<locale>/release_notes.txt
//   node scripts/check-changelog.ts         fails if changelog.json is malformed,
//                                           its newest version is not the app's,
//                                           or a generated file is out of date (CI)
//   node scripts/print-release-notes.ts 1.3 [--locale en-US]
//                                           prints a version's What's New, for the
//                                           release tag's message
//
// changelog.json lists versions newest first. Each change has a type (new,
// improved or fixed), its text in British English, and an "en-US" text where
// American English differs. The app bundles changelog.json and shows it in
// Settings > What's New. Entries are written by the release skill
// (.claude/skills/release/SKILL.md).
//
// Usage: import { load, validate, staleOutputs } from "./lib/changelog.ts";

import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

const root = join(import.meta.dirname, "..", "..");
const changelogPath = join(root, "changelog.json");
const markdownPath = join(root, "CHANGELOG.md");
export const locales = ["en-GB", "en-US"] as const;
export type Locale = (typeof locales)[number];
const types = ["new", "improved", "fixed"] as const;
type ChangeType = (typeof types)[number];
const headings: Record<ChangeType, string> = { new: "New", improved: "Improved", fixed: "Fixed" };

export interface Change {
    type: ChangeType;
    text: string;
    "en-US"?: string;
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

/// A generated file and the text it should hold.
export interface Output {
    path: string;
    /// The path relative to the repository root, for messages.
    name: string;
    text: string;
}

export function isLocale(value: string): value is Locale {
    return (locales as readonly string[]).includes(value);
}

export function textFor(change: Change, locale: Locale): string {
    return locale === "en-US" ? change["en-US"] ?? change.text : change.text;
}

/// Problems with the changelog's shape, empty when it is well formed.
export function validate(changelog: Changelog): string[] {
    const problems: string[] = [];
    if (!Array.isArray(changelog.versions) || changelog.versions.length === 0) return ["changelog.json has no versions"];
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
            if (!change.text?.trim()) problems.push(`${where}: a change has no text`);
            if (change["en-US"] !== undefined && !change["en-US"].trim()) problems.push(`${where}: an en-US text is empty`);
            const extra = Object.keys(change).filter((key) => !["type", "text", "en-US"].includes(key));
            if (extra.length > 0) problems.push(`${where}: unknown fields ${extra.join(", ")}`);
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

/// What's New for the App Store: one change a line, new first.
export function releaseNotes(version: Version, locale: Locale): string {
    return grouped(version).flatMap(([, changes]) => changes.map((change) => textFor(change, locale))).join("\n") + "\n";
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

export function load(): Changelog {
    return JSON.parse(readFileSync(changelogPath, "utf8")) as Changelog;
}

/// The app's version, from the project-level MARKETING_VERSION.
export function appVersion(): string {
    const project = readFileSync(join(root, "Cards.xcodeproj/project.pbxproj"), "utf8");
    const versions = [...new Set([...project.matchAll(/MARKETING_VERSION = ([\d.]+);/g)].map((match) => match[1] ?? ""))];
    const [version] = versions;
    if (versions.length !== 1 || !version) throw new Error(`Expected one MARKETING_VERSION, found ${versions.join(", ") || "none"}`);
    return version;
}

/// Every generated file and the text it should hold.
function outputs(changelog: Changelog): Map<string, string> {
    const files = new Map([[markdownPath, markdown(changelog)]]);
    const newest = changelog.versions[0];
    if (!newest) throw new Error("changelog.json has no versions");
    for (const locale of locales) {
        files.set(join(root, "metadata", locale, "release_notes.txt"), releaseNotes(newest, locale));
    }
    return files;
}

/// The generated files that do not yet hold what the changelog makes them, in
/// the order they are generated.
export function staleOutputs(changelog: Changelog): Output[] {
    return [...outputs(changelog)]
        .filter(([path, text]) => (existsSync(path) ? readFileSync(path, "utf8") : undefined) !== text)
        .map(([path, text]) => ({ path, name: path.slice(root.length + 1), text }));
}
