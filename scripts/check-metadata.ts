// Checks the App Store listing text in metadata/ against App Store Connect's
// limits, without touching the network, so a bad listing fails in CI rather than
// halfway through an upload.
//
// metadata/<locale>/<field>.txt holds one field per file (name, subtitle,
// keywords, description, promotional_text, release_notes, marketing_url,
// support_url, privacy_url), and metadata/copyright.txt the copyright line.
// Every folder is a store locale, and every locale must have the same set of
// files, except review_notes.txt: App Store Connect keeps one set of notes for
// App Review per version, so only en-GB has them, and the file in any other
// locale is an error. Lengths are in Unicode code points, except keywords,
// which App Store Connect limits in UTF-8 bytes. A name or subtitle with the
// word "free" in the listing's language is an error: App Store Review
// Guideline 2.3.7 keeps price words out of them (and out of the screenshot
// captions, which scripts/check-store-images.ts checks). A keyword that repeats
// a word of the name or subtitle is a warning, not an error: it is legal, but
// Apple already indexes those words, so it wastes bytes.
//
// Usage: node scripts/check-metadata.ts [metadata directory]
// Exits 1 if anything is an error. scripts/upload-metadata.ts runs the same
// checks before it uploads.

import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { basename, join } from "node:path";
import { parseArgs } from "node:util";
import { languageOf } from "./lib/locales.ts";

export const metadataDir = join(import.meta.dirname, "..", "metadata");

/// App Store Connect takes review notes once per version, not per locale, so only this locale has them.
export const reviewNotesLocale = "en-GB";

/// The word "free" in each listing language, which App Store Review Guideline
/// 2.3.7 keeps out of the name, subtitle and screenshot captions. Add a
/// language's words with its first listing.
const priceWords: Record<string, RegExp> = {
    en: /(?<![\p{L}\p{N}])free(?![\p{L}\p{N}])/iu,
    es: /(?<![\p{L}\p{N}])(gratis|gratuit[ao]s?)(?![\p{L}\p{N}])/iu,
    de: /(?<![\p{L}\p{N}])(kostenlos(e[mnrs]?)?|gratis|umsonst)(?![\p{L}\p{N}])/iu,
    ja: /無料/u,
};

/// The price word in text written for a store locale, if it has one.
export function priceWord(text: string, locale: string): string | undefined {
    return priceWords[languageOf(locale)]?.exec(text)?.[0];
}

export const fieldNames = [
    "name",
    "subtitle",
    "keywords",
    "promotional_text",
    "description",
    "release_notes",
    "review_notes",
    "marketing_url",
    "support_url",
    "privacy_url",
] as const;

export type Field = (typeof fieldNames)[number];

/// A locale's fields, trimmed. A field whose file is absent is undefined; an empty file is "".
export type LocaleMetadata = Partial<Record<Field, string>>;

interface Rule {
    min?: number;
    max?: number;
    /// The limit counts UTF-8 bytes rather than characters.
    bytes?: boolean;
    url?: boolean;
    singleLine?: boolean;
    /// App Store Connect will not submit a version without it.
    required?: boolean;
}

const rules: Record<Field, Rule> = {
    name: { min: 2, max: 30, singleLine: true, required: true },
    subtitle: { max: 30, singleLine: true },
    keywords: { max: 100, bytes: true, singleLine: true, required: true },
    promotional_text: { max: 170 },
    description: { max: 4000, required: true },
    release_notes: { max: 4000 },
    review_notes: { max: 4000 },
    marketing_url: { url: true, singleLine: true },
    support_url: { url: true, singleLine: true, required: true },
    privacy_url: { url: true, singleLine: true, required: true },
};

export interface Finding {
    level: "error" | "warning";
    /// A locale, or "all" for metadata/ itself.
    locale: string;
    field: string;
    message: string;
}

export interface Row {
    locale: string;
    field: string;
    /// Code points, or bytes for keywords; undefined when the file is missing.
    length?: number;
    limit: string;
    status: "ok" | "warning" | "error" | "missing";
}

export interface MetadataReport {
    dir: string;
    locales: Map<string, LocaleMetadata>;
    copyright?: string;
    rows: Row[];
    findings: Finding[];
}

export function hasErrors(report: MetadataReport): boolean {
    return report.findings.some((finding) => finding.level === "error");
}

function codePoints(text: string): number {
    return [...text].length;
}

function read(path: string): string {
    return readFileSync(path, "utf8").trim();
}

/// A word folded roughly as Apple's search matches it: case and a plural "s" ignored.
function fold(word: string): string {
    const lower = word.toLowerCase();
    return lower.length > 3 && lower.endsWith("s") ? lower.slice(0, -1) : lower;
}

function words(text: string): string[] {
    return text.match(/[\p{L}\p{N}]+/gu) ?? [];
}

function looksLikeLocale(name: string): boolean {
    // en-GB, fr-CA, zh-Hans, es-MX: what App Store Connect calls its locales.
    return /^[a-z]{2,3}(-[A-Z][a-z]{3})?(-[A-Z]{2})?$/.test(name);
}

function checkKeywords(value: string, locale: string, metadata: LocaleMetadata, findings: Finding[]): void {
    const add = (level: Finding["level"], message: string): void => {
        findings.push({ level, locale, field: "keywords", message });
    };
    if (value === "") return;
    if (/\s,|,\s/.test(value)) add("error", "has spaces around a comma; they count against the 100 bytes");
    const keywords = value.split(",").map((keyword) => keyword.trim());
    if (keywords.some((keyword) => keyword === "")) add("error", "has an empty keyword (two commas together, or a comma at either end)");
    const seen = new Set<string>();
    for (const keyword of keywords.filter((candidate) => candidate !== "")) {
        const key = keyword.toLowerCase();
        if (seen.has(key)) add("error", `repeats "${keyword}"`);
        seen.add(key);
    }
    const indexed: [string, string | undefined][] = [
        ["name", metadata.name],
        ["subtitle", metadata.subtitle],
    ];
    for (const keyword of keywords.filter((candidate) => candidate !== "")) {
        const folded = new Set(words(keyword).map(fold));
        const repeats = indexed.flatMap(([field, text]) => {
            const matches = [...new Set(words(text ?? "").filter((word) => folded.has(fold(word))))];
            return matches.length > 0 ? [`the ${field} (${matches.map((word) => `"${word}"`).join(", ")})`] : [];
        });
        if (repeats.length > 0) add("warning", `"${keyword}" is already in ${repeats.join(" and ")}, which Apple indexes anyway`);
    }
}

function checkField(field: Field, value: string, locale: string, metadata: LocaleMetadata, findings: Finding[]): Row {
    const rule = rules[field];
    const length = rule.bytes ? Buffer.byteLength(value, "utf8") : codePoints(value);
    const unit = rule.bytes ? "byte" : "character";
    const counted = `${length} ${unit}${length === 1 ? "" : "s"}`;
    const before = findings.length;
    const error = (message: string): void => {
        findings.push({ level: "error", locale, field, message });
    };

    if (value === "") {
        if (rule.required) error("is empty, and App Store Connect requires it");
    } else {
        if (rule.min !== undefined && length < rule.min) error(`is ${counted}; the minimum is ${rule.min}`);
        if (rule.max !== undefined && length > rule.max) error(`is ${counted}; the limit is ${rule.max}`);
    }
    if (rule.singleLine && /[\r\n]/.test(value)) error("must be a single line");
    if (rule.url && value !== "") {
        let url: URL | undefined;
        try {
            url = new URL(value);
        } catch {
            error(`"${value}" is not a URL`);
        }
        if (url && url.protocol !== "https:") error(`"${value}" must use https`);
    }
    if (field === "keywords") checkKeywords(value, locale, metadata, findings);
    if ((field === "name" || field === "subtitle") && looksLikeLocale(locale)) {
        const word = priceWord(value, locale);
        if (word) error(`has "${word}"; App Store Review Guideline 2.3.7 keeps price words out of the name and subtitle`);
    }

    const raised = findings.slice(before);
    const status = raised.some((finding) => finding.level === "error") ? "error" : raised.length > 0 ? "warning" : "ok";
    const limit = rule.url ? "https" : rule.max !== undefined ? `${rule.min !== undefined ? `${rule.min}-` : ""}${rule.max}${rule.bytes ? " bytes" : ""}` : "";
    return { locale, field, length, limit, status };
}

/// Reads and checks metadata/. Never throws for bad content; everything wrong is a finding.
export function checkMetadata(dir: string = metadataDir): MetadataReport {
    const findings: Finding[] = [];
    const rows: Row[] = [];
    const locales = new Map<string, LocaleMetadata>();
    if (!existsSync(dir)) {
        findings.push({ level: "error", locale: "all", field: basename(dir), message: `${dir} does not exist` });
        return { dir, locales, rows, findings };
    }

    const entries = readdirSync(dir).filter((name) => !name.startsWith(".")).sort();
    const localeNames = entries.filter((name) => statSync(join(dir, name)).isDirectory());
    if (localeNames.length === 0) findings.push({ level: "error", locale: "all", field: "locales", message: "no locale directories" });

    // Which field files each locale has, so a file added to one locale and forgotten in another is caught.
    const filesByLocale = new Map<string, Set<string>>();
    for (const locale of localeNames) {
        if (!looksLikeLocale(locale)) {
            findings.push({ level: "error", locale, field: "-", message: `"${locale}" is not an App Store Connect locale such as en-GB` });
        }
        const metadata: LocaleMetadata = {};
        const files = new Set<string>();
        for (const name of readdirSync(join(dir, locale)).filter((file) => !file.startsWith(".")).sort()) {
            const field = fieldNames.find((candidate) => `${candidate}.txt` === name);
            if (!field) {
                findings.push({ level: "error", locale, field: name, message: `unknown file; expected one of ${fieldNames.map((known) => `${known}.txt`).join(", ")}` });
                continue;
            }
            files.add(name);
            metadata[field] = read(join(dir, locale, name));
        }
        filesByLocale.set(locale, files);
        locales.set(locale, metadata);
    }

    // Review notes are version-wide, so they are only in reviewNotesLocale.
    for (const [locale, files] of filesByLocale) {
        if (locale !== reviewNotesLocale && files.delete("review_notes.txt")) {
            findings.push({
                level: "error",
                locale,
                field: "review_notes",
                message: `only ${reviewNotesLocale} has review notes: App Store Connect keeps one set for the version, and uploads ${reviewNotesLocale}'s, so delete this one`,
            });
        }
    }
    const allFiles = new Set([...filesByLocale.values()].flatMap((files) => [...files]).filter((name) => name !== "review_notes.txt"));
    for (const [locale, files] of filesByLocale) {
        for (const file of [...allFiles].filter((name) => !files.has(name)).sort()) {
            const others = [...filesByLocale].filter(([, other]) => other.has(file)).map(([name]) => name);
            findings.push({ level: "error", locale, field: file.replace(/\.txt$/, ""), message: `missing; ${others.join(", ")} ${others.length === 1 ? "has" : "have"} it` });
        }
    }

    for (const [locale, metadata] of locales) {
        for (const field of fieldNames) {
            if (field === "review_notes" && locale !== reviewNotesLocale) continue;
            const value = metadata[field];
            if (value === undefined) {
                // Missing from every locale; a file missing from only some is reported above.
                if (rules[field].required && !allFiles.has(`${field}.txt`)) {
                    findings.push({ level: "error", locale, field, message: `${field}.txt is missing, and App Store Connect requires it` });
                }
                if (allFiles.has(`${field}.txt`) || rules[field].required) rows.push({ locale, field, limit: "", status: "missing" });
                continue;
            }
            rows.push(checkField(field, value, locale, metadata, findings));
        }
    }

    let copyright: string | undefined;
    const copyrightFile = join(dir, "copyright.txt");
    if (existsSync(copyrightFile)) {
        copyright = read(copyrightFile);
        const before = findings.length;
        if (copyright === "") findings.push({ level: "error", locale: "all", field: "copyright", message: "is empty" });
        if (/[\r\n]/.test(copyright)) findings.push({ level: "error", locale: "all", field: "copyright", message: "must be a single line" });
        rows.push({ locale: "all", field: "copyright", length: codePoints(copyright), limit: "", status: findings.length > before ? "error" : "ok" });
    } else {
        findings.push({ level: "error", locale: "all", field: "copyright", message: "copyright.txt is missing" });
        rows.push({ locale: "all", field: "copyright", limit: "", status: "missing" });
    }

    return { dir, locales, copyright, rows, findings };
}

export function printReport(report: MetadataReport): void {
    const header: [string, string, string, string, string] = ["Locale", "Field", "Length", "Limit", "Result"];
    const lines = report.rows.map((row): [string, string, string, string, string] => [
        row.locale,
        row.field,
        row.length === undefined ? "-" : String(row.length),
        row.limit || "-",
        row.status,
    ]);
    const widths = header.map((title, column) => Math.max(title.length, ...lines.map((line) => (line[column] ?? "").length)));
    const format = (line: string[]): string =>
        line.map((cell, column) => (column === 2 ? cell.padStart(widths[column] ?? 0) : cell.padEnd(widths[column] ?? 0))).join("  ").trimEnd();
    console.log(format(header));
    for (const line of lines) console.log(format(line));

    for (const level of ["error", "warning"] as const) {
        const found = report.findings.filter((finding) => finding.level === level);
        if (found.length === 0) continue;
        console.log(`\n${found.length} ${level}${found.length === 1 ? "" : "s"}:`);
        for (const finding of found) console.log(`  ${finding.locale} ${finding.field}: ${finding.message}`);
    }
    const errors = report.findings.filter((finding) => finding.level === "error").length;
    console.log(errors === 0 ? `\nmetadata/ is within App Store Connect's limits (${report.locales.size} locales).` : `\nmetadata/ has ${errors} error${errors === 1 ? "" : "s"}.`);
}

if (import.meta.main) {
    try {
        const { positionals } = parseArgs({ args: process.argv.slice(2), options: {}, allowPositionals: true, strict: true });
        if (positionals.length > 1) throw new Error("Usage: node scripts/check-metadata.ts [metadata directory]");
        const report = checkMetadata(positionals[0] ?? metadataDir);
        printReport(report);
        if (hasErrors(report)) process.exitCode = 1;
    } catch (error) {
        console.error(`error: ${error instanceof Error ? error.message : String(error)}`);
        process.exitCode = 1;
    }
}
