// The website, cards.serby.net: what it is built from and the pages made of
// it, for scripts/build-website.ts. Every fact comes from where the app or its
// App Store listing already keeps it, so the site never says something the
// app or the store does not:
//
//   name, subtitle, description,      metadata/<locale>/: the description's first paragraph
//   promise, copyright, URLs          is a sentence on what the app does, then the promise
//                                     (free, no ads, and it always will be); each later
//                                     paragraph is a feature, a heading line then its text
//   App Store images and captions     screenshots/store/<locale>/
//   languages                         British English and the project's knownRegions
//   What's New and every version      changelog.json, read as the app reads it
//   "What's New", "Version 1.3",      Cards/Localizable.xcstrings, the app's own words for
//   "New:", "Improved:", "Fixed:"     its What's New screen
//   the oldest iOS it runs on         IPHONEOS_DEPLOYMENT_TARGET in the project
//   colours                           Cards/UI/Theme/Colors.swift, and iOS's system colours
//   third-party code                  the Swift package pins in Package.resolved
//   the site's own words and links    Website/site.json, in every app language
//   page structure                    Website/templates/
//
// Each of the app's languages has a home page: British English at /, and each
// other language at /<language>/, made from the store listing of its main
// region (es-ES for Spanish, de-DE, ja), with hreflang links between them and
// a language switcher. The privacy policy is British English only, at the
// path of the listing's privacy URL. Versions show once released (they have a
// date), newest first; a change with no text in a page's language shows its
// British English, as the app shows it.
//
// Usage: import { readSite, renderSite, screenshotSources } from "./lib/website.ts";

import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { checkMetadata, hasErrors, type LocaleMetadata } from "../check-metadata.ts";
import { type Change, type Changelog, load as loadChangelog, readLocales, textFor, validate as validateChangelog, type Version } from "./changelog.ts";
import { appLanguages, languageOf, regionOf, sourceLocale, storeLocales } from "./locales.ts";
import { parseCatalogue, textOf } from "./string-catalogues.ts";

const root = join(import.meta.dirname, "..", "..");

/// The width the site serves the App Store images at: a third of the
/// iPhone images, three times the width a screenshot shows at, so it is sharp
/// on a Retina display.
export const screenshotWidth = 440;

/// The site's own words, each in every app language (Website/site.json).
export const siteStringKeys = [
    "download",
    "screenshots",
    "screenshotAlt",
    "features",
    "languages",
    "languagesIntro",
    "language",
    "earlierVersions",
    "getApp",
    "requirements",
    "privacy",
    "privacyPolicy",
    "contact",
] as const;
export type SiteStringKey = (typeof siteStringKeys)[number];

/// The app's What's New words, by their keys in Cards/Localizable.xcstrings.
const appWordKeys = {
    whatsNew: "What's New",
    version: "Version %@",
    new: "New: %@",
    improved: "Improved: %@",
    fixed: "Fixed: %@",
} as const;
export type AppWords = Record<keyof typeof appWordKeys, string>;

export interface SiteConfig {
    appStore: string;
    supportEmail: string;
    privacyEmail: string;
    privacyPage: { title: string; description: string };
    /// What each Swift package does, by its identity in Package.resolved.
    packages: Record<string, string>;
    strings: Record<string, Record<string, string>>;
}

export interface Page {
    /// The app language, such as "en" or "es".
    language: string;
    /// The store listing it is made from, such as "en-GB" or "es-ES".
    locale: string;
    /// Where it is served: "/" or "/es/".
    path: string;
    /// Its file in the built site: "index.html" or "es/index.html".
    file: string;
}

export interface Feature {
    heading: string;
    paragraphs: string[];
}

export interface Description {
    /// The first paragraph whole.
    intro: string;
    /// Its first sentence: what the app does.
    lead: string;
    /// The rest of it: free, no ads, and it always will be.
    promise: string;
    features: Feature[];
}

export interface Caption {
    file: string;
    title: string;
    subtitle: string;
}

/// An App Store image as a page shows it.
export interface Screenshot {
    src: string;
    width: number;
    height: number;
    alt: string;
}

/// An App Store image the site publishes: where it is and where it goes.
export interface ScreenshotSource {
    locale: string;
    /// The App Store image.
    source: string;
    /// Its path in the built site, such as "screenshots/en-GB/01_Cards.png".
    file: string;
    alt: string;
}

export interface ThirdPartyPackage {
    name: string;
    url: string;
    description: string;
}

export type Appearance = "light" | "dark" | "lightIncreased" | "darkIncreased";
export const appearances: readonly Appearance[] = ["light", "dark", "lightIncreased", "darkIncreased"];

/// The colours of one appearance, as CSS hex colours.
export interface Colours {
    background: string;
    /// Panels: iOS's grouped background.
    groupedBackground: string;
    text: string;
    secondaryText: string;
    accent: string;
    /// Text on the accent, as on the app's Add Card button: white in light, black in dark.
    accentInk: string;
    /// Separators, and panel edges with Increase Contrast; the panel colour otherwise, so unseen.
    line: string;
}

export interface Templates {
    page: string;
    home: string;
    privacy: string;
    style: string;
}

export interface Site {
    /// https://cards.serby.net, from the listing's marketing URL.
    origin: string;
    /// /privacy.html, from the listing's privacy URL.
    privacyPath: string;
    pages: Page[];
    listings: Map<string, LocaleMetadata>;
    descriptions: Map<string, Description>;
    copyright: string;
    changelog: Changelog;
    appWords: Map<string, AppWords>;
    /// The oldest iOS the app runs on, such as "18".
    minimumOS: string;
    palette: Record<Appearance, Colours>;
    packages: ThirdPartyPackage[];
    captions: Map<string, Caption[]>;
    config: SiteConfig;
    templates: Templates;
}

// MARK: - Reading the sources

function problemsError(problems: string[]): Error {
    return new Error(`the website's sources have problems:\n  ${problems.join("\n  ")}`);
}

/// The listing a language's page is made from: en-GB for British English, else
/// the listing of the language's main region, else its first.
export function listingFor(language: string, locales: string[]): string {
    if (language === languageOf(sourceLocale)) {
        if (!locales.includes(sourceLocale)) throw new Error(`there is no ${sourceLocale} listing in metadata/`);
        return sourceLocale;
    }
    const candidates = locales.filter((locale) => languageOf(locale) === language);
    const [first] = candidates;
    if (!first) throw new Error(`${language} is one of the app's languages but has no App Store listing; add metadata/<locale>/ as docs/DEVELOPMENT.md, "Add a language", says`);
    return candidates.find((locale) => regionOf(locale) === regionOf(language)) ?? first;
}

/// A page for each language: British English first at /, the rest under their codes.
export function pagesFor(languages: string[], locales: string[]): Page[] {
    return languages.map((language) => {
        const source = language === languageOf(sourceLocale);
        return {
            language,
            locale: listingFor(language, locales),
            path: source ? "/" : `/${language}/`,
            file: source ? "index.html" : `${language}/index.html`,
        };
    });
}

/// A listing's description, split into what the site shows. Throws when it
/// has lost the shape the site relies on.
export function parseDescription(text: string, locale: string): Description {
    const paragraphs = text.trim().split(/\n[ \t]*\n/).map((paragraph) => paragraph.trim()).filter(Boolean);
    const [intro, ...rest] = paragraphs;
    if (!intro) throw new Error("is empty");
    const [first] = new Intl.Segmenter(locale, { granularity: "sentence" }).segment(intro);
    const lead = first?.segment.trim() ?? "";
    const promise = intro.slice(first?.segment.length ?? 0).trim();
    if (!lead || !promise) throw new Error("its first paragraph must be a sentence on what the app does, then the promise that it is free with no ads, which the website shows on its own");
    const features = rest.map((paragraph): Feature => {
        const [heading = "", ...lines] = paragraph.split("\n").map((line) => line.trim());
        if (lines.length === 0) throw new Error(`"${heading}" is a paragraph of one line; each paragraph after the first is a feature, a heading line and then its text`);
        // Japanese listings bracket their headings 【like this】 in place of capitals.
        return { heading: heading.replace(/^【(.+)】$/u, "$1"), paragraphs: lines.filter(Boolean) };
    });
    if (features.length === 0) throw new Error("has no features after its first paragraph");
    return { intro, lead, promise, features };
}

/// The colours Colors.swift spells out as hex, by name: accentLight → #D0185B.
export function swiftColours(swift: string): Map<string, string> {
    return new Map([...swift.matchAll(/static let (\w+)RGB: UInt32 = 0x([0-9A-Fa-f]{6})\b/g)].map((match) => [match[1] ?? "", `#${(match[2] ?? "").toUpperCase()}`]));
}

/// iOS's systemBackground, secondarySystemBackground (the grouped panels) and label.
const systemColours = {
    light: { background: "#FFFFFF", groupedBackground: "#F2F2F7", text: "#000000" },
    dark: { background: "#000000", groupedBackground: "#1C1C1E", text: "#FFFFFF" },
};

/// The site's colours in each appearance, from the app's.
export function paletteFrom(colours: Map<string, string>): Record<Appearance, Colours> {
    const suffixes: Record<Appearance, string> = { light: "Light", dark: "Dark", lightIncreased: "IncreasedLight", darkIncreased: "IncreasedDark" };
    const missing: string[] = [];
    const colour = (name: string): string => {
        const value = colours.get(name);
        if (!value) missing.push(`${name}RGB`);
        return value ?? "";
    };
    const palette = Object.fromEntries(appearances.map((appearance): [Appearance, Colours] => {
        const dark = appearance === "dark" || appearance === "darkIncreased";
        const increased = appearance === "lightIncreased" || appearance === "darkIncreased";
        const system = dark ? systemColours.dark : systemColours.light;
        const secondaryText = colour(`secondaryText${suffixes[appearance]}`);
        return [appearance, {
            ...system,
            secondaryText,
            accent: colour(`accent${suffixes[appearance]}`),
            accentInk: dark ? "#000000" : "#FFFFFF",
            line: increased ? secondaryText : system.groupedBackground,
        }];
    })) as Record<Appearance, Colours>;
    if (missing.length > 0) throw new Error(`Cards/UI/Theme/Colors.swift has no ${[...new Set(missing)].join(", ")}`);
    return palette;
}

/// WCAG's contrast ratio between two hex colours.
export function contrast(a: string, b: string): number {
    const luminance = (hex: string): number => {
        const [red = 0, green = 0, blue = 0] = [1, 3, 5].map((start) => {
            const channel = Number.parseInt(hex.slice(start, start + 2), 16) / 255;
            return channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4;
        });
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue;
    };
    const [light, dark] = [luminance(a), luminance(b)].sort((x, y) => y - x);
    return ((light ?? 0) + 0.05) / ((dark ?? 0) + 0.05);
}

/// The app's What's New words in each language, from its catalogue.
export function appWordsFrom(catalogue: string, languages: string[], problems: string[]): Map<string, AppWords> {
    const doc = parseCatalogue(catalogue, "Cards/Localizable.xcstrings");
    return new Map(languages.map((language) => {
        const words = Object.fromEntries(Object.entries(appWordKeys).map(([name, key]) => {
            const entry = doc.strings[key];
            if (!entry) {
                problems.push(`Cards/Localizable.xcstrings has no "${key}", which the website's What's New uses`);
                return [name, key];
            }
            const text = textOf(entry.localizations?.[language]) ?? (language === doc.sourceLanguage ? key : undefined);
            if (typeof text !== "string" || text.includes("%@") !== key.includes("%@")) {
                problems.push(`Cards/Localizable.xcstrings has no ${language} text for "${key}"`);
                return [name, key];
            }
            return [name, text];
        })) as AppWords;
        return [language, words];
    }));
}

function readText(rootDir: string, path: string): string {
    return readFileSync(join(rootDir, path), "utf8");
}

function checkConfig(config: SiteConfig, languages: string[], problems: string[]): void {
    const where = "Website/site.json";
    try {
        if (new URL(config.appStore).protocol !== "https:") problems.push(`${where}: appStore must be an https URL`);
    } catch {
        problems.push(`${where}: appStore is not a URL`);
    }
    for (const field of ["supportEmail", "privacyEmail"] as const) {
        if (!/^[^@\s]+@[^@\s]+$/.test(config[field] ?? "")) problems.push(`${where}: ${field} is not an email address`);
    }
    if (!config.privacyPage?.title?.trim() || !config.privacyPage?.description?.trim()) problems.push(`${where}: privacyPage needs a title and a description`);
    for (const key of siteStringKeys) {
        const texts = config.strings?.[key];
        if (!texts) {
            problems.push(`${where}: strings has no "${key}"`);
            continue;
        }
        for (const language of languages) {
            if (!texts[language]?.trim()) problems.push(`${where}: "${key}" has no ${language} text`);
        }
    }
    for (const key of Object.keys(config.strings ?? {})) {
        if (!(siteStringKeys as readonly string[]).includes(key)) problems.push(`${where}: strings has "${key}", which no page uses; delete it`);
    }
}

function readPackages(rootDir: string, config: SiteConfig, problems: string[]): ThirdPartyPackage[] {
    const resolved = JSON.parse(readText(rootDir, "Cards.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved")) as { pins?: { identity: string; location: string }[] };
    const pins = resolved.pins ?? [];
    for (const identity of Object.keys(config.packages ?? {})) {
        if (!pins.some((pin) => pin.identity === identity)) problems.push(`Website/site.json: packages describes ${identity}, which Package.resolved does not pin; delete it`);
    }
    return pins.map((pin) => {
        const description = config.packages?.[pin.identity];
        if (!description?.trim()) problems.push(`Website/site.json: packages has no description of ${pin.identity}, which the app uses; the privacy policy lists every third-party package`);
        const name = pin.location.replace(/\/$/, "").split("/").pop()?.replace(/\.git$/, "") ?? pin.identity;
        return { name, url: pin.location.replace(/\.git$/, ""), description: description ?? "" };
    });
}

function minimumOSFrom(pbxproj: string): string {
    const targets = [...new Set([...pbxproj.matchAll(/IPHONEOS_DEPLOYMENT_TARGET = ([\d.]+);/g)].map((match) => match[1] ?? ""))];
    const [target] = targets;
    if (targets.length !== 1 || !target) throw new Error(`expected one IPHONEOS_DEPLOYMENT_TARGET in the project, found ${targets.join(", ") || "none"}`);
    return target.replace(/(\.0)+$/, "");
}

function readCaptions(rootDir: string, locale: string, problems: string[]): Caption[] {
    const path = join("screenshots", "store", locale, "captions.json");
    if (!existsSync(join(rootDir, path))) {
        problems.push(`${path} is missing`);
        return [];
    }
    const captions = JSON.parse(readText(rootDir, path)) as Partial<Caption>[];
    return captions.flatMap((caption, index) => {
        if (!caption.file || !caption.title?.trim() || !caption.subtitle?.trim()) {
            problems.push(`${path}: caption ${index + 1} needs a file, a title and a subtitle`);
            return [];
        }
        return [{ file: caption.file, title: caption.title, subtitle: caption.subtitle }];
    });
}

/// Reads and checks every source of the site. Throws with every problem found.
export function readSite(rootDir: string = root): Site {
    const problems: string[] = [];
    const languages = [languageOf(sourceLocale), ...appLanguages(rootDir)];
    const pages = pagesFor(languages, storeLocales(rootDir));

    const metadata = checkMetadata(join(rootDir, "metadata"));
    if (hasErrors(metadata)) {
        const errors = metadata.findings.filter((finding) => finding.level === "error");
        problems.push(...errors.map((finding) => `metadata/${finding.locale} ${finding.field}: ${finding.message}`));
    }
    const listings = metadata.locales;
    const source = listings.get(sourceLocale) ?? {};
    let origin = "";
    let privacyPath = "";
    try {
        const marketing = new URL(source.marketing_url ?? "");
        const privacy = new URL(source.privacy_url ?? "");
        origin = marketing.origin;
        privacyPath = privacy.pathname;
        if (privacy.origin !== origin || !/^\/[\w-]+\.html$/.test(privacyPath)) problems.push(`metadata/${sourceLocale}/privacy_url must be an .html page on ${origin}, where the website publishes the privacy policy`);
    } catch {
        problems.push(`metadata/${sourceLocale}'s marketing and privacy URLs are the website's address and its privacy policy's`);
    }
    for (const [locale, listing] of listings) {
        if (listing.privacy_url !== source.privacy_url) problems.push(`metadata/${locale}/privacy_url must be ${source.privacy_url}: the website has one privacy policy, in British English`);
    }

    const descriptions = new Map<string, Description>();
    for (const page of pages) {
        const listing = listings.get(page.locale);
        try {
            descriptions.set(page.locale, parseDescription(listing?.description ?? "", page.locale));
        } catch (error) {
            problems.push(`metadata/${page.locale}/description.txt ${(error as Error).message}`);
        }
        if (!listing?.name?.split(/[:：]/)[0]?.trim()) problems.push(`metadata/${page.locale}/name.txt has no name`);
    }

    const changelog = loadChangelog(rootDir);
    problems.push(...validateChangelog(changelog, readLocales(rootDir)).map((problem) => `changelog.json: ${problem}`));
    if (!changelog.versions?.some((version) => version.date !== null)) problems.push("changelog.json has no released version (one with a date) to show");

    const config = JSON.parse(readText(rootDir, "Website/site.json")) as SiteConfig;
    checkConfig(config, languages, problems);
    const appWords = appWordsFrom(readText(rootDir, "Cards/Localizable.xcstrings"), languages, problems);
    const packages = readPackages(rootDir, config, problems);
    const captions = new Map(pages.map((page) => [page.locale, readCaptions(rootDir, page.locale, problems)]));

    let minimumOS = "";
    let palette = {} as Record<Appearance, Colours>;
    try {
        minimumOS = minimumOSFrom(readText(rootDir, "Cards.xcodeproj/project.pbxproj"));
        palette = paletteFrom(swiftColours(readText(rootDir, "Cards/UI/Theme/Colors.swift")));
    } catch (error) {
        problems.push((error as Error).message);
    }

    const templates: Templates = {
        page: readText(rootDir, "Website/templates/page.html"),
        home: readText(rootDir, "Website/templates/home.html"),
        privacy: readText(rootDir, "Website/templates/privacy.html"),
        style: readText(rootDir, "Website/templates/style.css"),
    };

    if (problems.length > 0) throw problemsError(problems);
    return {
        origin,
        privacyPath,
        pages,
        listings,
        descriptions,
        copyright: metadata.copyright ?? "",
        changelog,
        appWords,
        minimumOS,
        palette,
        packages,
        captions,
        config,
        templates,
    };
}

// MARK: - Rendering

export function escapeHTML(text: string): string {
    return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;");
}

/// A template with {{name}} filled with the value escaped for HTML, and
/// {{{name}}} with the value as it is. Throws on a name it has no value for.
export function fill(template: string, values: Record<string, string>, name: string): string {
    return template.replace(/\{\{\{([\w.]+)\}\}\}|\{\{([\w.]+)\}\}/g, (_whole, raw: string | undefined, escaped: string | undefined) => {
        const key = raw ?? escaped ?? "";
        const value = values[key];
        if (value === undefined) throw new Error(`${name} uses ${raw ? `{{{${key}}}}` : `{{${key}}}`}, which nothing fills`);
        return raw ? value : escapeHTML(value);
    });
}

/// One of the site's strings with {name} filled in. Throws on a name it has no value for.
export function format(text: string, values: Record<string, string> = {}): string {
    return text.replace(/\{(\w+)\}/g, (_whole, key: string) => {
        const value = values[key];
        if (value === undefined) throw new Error(`"${text}" has {${key}}, which nothing fills`);
        return value;
    });
}

/// One of the app's strings with its %@ split out, so the value can be marked up between the halves.
function around(text: string): [string, string] {
    const [before = "", after = ""] = text.split("%@");
    return [before, after];
}

function siteWord(site: Site, page: Page, key: SiteStringKey): string {
    return site.config.strings[key]?.[page.language] ?? "";
}

function appWord(site: Site, page: Page, key: keyof AppWords): string {
    return site.appWords.get(page.language)?.[key] ?? "";
}

/// A language's name in itself, with the capital a list item takes: "Español".
export function nativeName(language: string): string {
    const name = new Intl.DisplayNames([language], { type: "language" }).of(language) ?? language;
    return name.charAt(0).toLocaleUpperCase(language) + name.slice(1);
}

export function englishName(language: string): string {
    return new Intl.DisplayNames([sourceLocale], { type: "language" }).of(language) ?? language;
}

function formatDate(date: string, locale: string): string {
    return new Intl.DateTimeFormat(locale, { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" }).format(new Date(`${date}T12:00:00Z`));
}

/// The App Store images each page shows, with where they go in the site.
export function screenshotSources(site: Site, rootDir: string = root): ScreenshotSource[] {
    return site.pages.flatMap((page) => (site.captions.get(page.locale) ?? []).map((caption): ScreenshotSource => ({
        locale: page.locale,
        source: join(rootDir, "screenshots", "store", page.locale, `${caption.file}.png`),
        file: `screenshots/${page.locale}/${caption.file}.png`,
        alt: format(siteWord(site, page, "screenshotAlt"), { title: caption.title, subtitle: caption.subtitle }),
    })));
}

function renderChange(site: Site, page: Page, change: Change): string {
    const [before, after] = around(appWord(site, page, change.type));
    const own = textFor(change, page.locale);
    const text = own === undefined ? `<span lang="${sourceLocale}">${escapeHTML(change.text)}</span>` : escapeHTML(own);
    return `          <li><strong>${escapeHTML(before)}</strong>${text}${escapeHTML(after)}</li>`;
}

function renderVersion(site: Site, page: Page, version: Version, indent = ""): string {
    const [before, after] = around(appWord(site, page, "version"));
    const lines = [
        `      <div class="version">`,
        `        <h3>${escapeHTML(`${before}${version.version}${after}`)}</h3>`,
        ...(version.date ? [`        <p class="date"><time datetime="${version.date}">${escapeHTML(formatDate(version.date, page.locale))}</time></p>`] : []),
        `        <ul class="changes">`,
        ...version.changes.map((change) => renderChange(site, page, change)),
        `        </ul>`,
        `      </div>`,
    ];
    return lines.map((line) => indent + line).join("\n");
}

/// The released versions: the current one, then the earlier ones behind a disclosure.
function renderVersions(site: Site, page: Page): string {
    const [current, ...earlier] = site.changelog.versions.filter((version) => version.date !== null);
    if (!current) return "";
    const parts = [renderVersion(site, page, current)];
    if (earlier.length > 0) {
        parts.push(
            `      <details>`,
            `        <summary>${escapeHTML(siteWord(site, page, "earlierVersions"))}</summary>`,
            ...earlier.map((version) => renderVersion(site, page, version, "  ")),
            `      </details>`,
        );
    }
    return parts.join("\n");
}

function renderScreenshots(site: Site, page: Page, screenshots: Screenshot[]): string {
    if (screenshots.length === 0) return "";
    return [
        ``,
        `    <section class="screenshots" aria-labelledby="screenshots-title">`,
        `      <h2 id="screenshots-title" class="visually-hidden">${escapeHTML(siteWord(site, page, "screenshots"))}</h2>`,
        `      <ul>`,
        ...screenshots.map((shot) => `        <li><img src="${escapeHTML(shot.src)}" width="${shot.width}" height="${shot.height}" alt="${escapeHTML(shot.alt)}" loading="lazy" decoding="async"></li>`),
        `      </ul>`,
        `    </section>`,
        ``,
    ].join("\n");
}

function renderFeatures(description: Description): string {
    return description.features.map((feature) => [
        `        <div class="feature">`,
        `          <h3>${escapeHTML(feature.heading)}</h3>`,
        ...feature.paragraphs.map((paragraph) => `          <p>${escapeHTML(paragraph)}</p>`),
        `        </div>`,
    ].join("\n")).join("\n");
}

function renderLanguages(site: Site, page: Page): string {
    return site.pages.map((other) => {
        const english = other.language === languageOf(sourceLocale)
            ? ""
            : `<span class="english-name"${page.language === languageOf(sourceLocale) ? "" : ` lang="${languageOf(sourceLocale)}"`}>${escapeHTML(englishName(other.language))}</span>`;
        return `        <li><a href="${other.path}" lang="${other.language}" hreflang="${other.language}">${escapeHTML(nativeName(other.language))}</a>${english}</li>`;
    }).join("\n");
}

function renderLanguageNav(site: Site, page: Page): string {
    return [
        `    <nav class="language" aria-label="${escapeHTML(siteWord(site, page, "language"))}">`,
        `      <ul>`,
        ...site.pages.map((other) => `        <li><a href="${other.path}" lang="${other.language}" hreflang="${other.language}"${other === page ? ` aria-current="page"` : ""}>${escapeHTML(nativeName(other.language))}</a></li>`),
        `      </ul>`,
        `    </nav>`,
    ].join("\n");
}

interface Layout {
    page: Page;
    title: string;
    description: string;
    path: string;
    alternates: string;
    languageNav: string;
    content: string;
}

function renderLayout(site: Site, layout: Layout): string {
    const { page } = layout;
    const english = page.language === languageOf(sourceLocale);
    const name = site.listings.get(page.locale)?.name ?? "";
    return fill(site.templates.page, {
        lang: page.locale,
        title: layout.title,
        description: layout.description,
        url: `${site.origin}${layout.path}`,
        origin: site.origin,
        alternates: layout.alternates,
        ogLocale: `${languageOf(page.locale)}_${regionOf(page.locale)}`,
        home: page.path,
        appName: name.split(/[:：]/)[0]?.trim() ?? name,
        whatsNew: appWord(site, page, "whatsNew"),
        privacyPath: site.privacyPath,
        // The policy is in British English, so links to it from other languages say so.
        privacyHreflang: english ? "" : ` hreflang="${languageOf(sourceLocale)}"`,
        privacy: siteWord(site, page, "privacy"),
        privacyPolicy: siteWord(site, page, "privacyPolicy"),
        supportEmail: site.config.supportEmail,
        contact: siteWord(site, page, "contact"),
        copyright: site.copyright,
        languageNav: layout.languageNav,
        content: layout.content,
    }, "Website/templates/page.html");
}

export function renderHome(site: Site, page: Page, screenshots: Screenshot[]): string {
    const listing = site.listings.get(page.locale) ?? {};
    const description = site.descriptions.get(page.locale);
    if (!description) throw new Error(`no description for ${page.locale}`);
    const name = listing.name ?? "";
    const content = fill(site.templates.home, {
        appName: name.split(/[:：]/)[0]?.trim() ?? name,
        subtitle: listing.subtitle ?? "",
        lead: description.lead,
        promise: description.promise,
        appStore: site.config.appStore,
        download: siteWord(site, page, "download"),
        screenshots: renderScreenshots(site, page, screenshots),
        featuresTitle: siteWord(site, page, "features"),
        features: renderFeatures(description),
        languagesTitle: siteWord(site, page, "languages"),
        languagesIntro: siteWord(site, page, "languagesIntro"),
        languages: renderLanguages(site, page),
        whatsNew: appWord(site, page, "whatsNew"),
        versions: renderVersions(site, page),
        getApp: siteWord(site, page, "getApp"),
        requirements: format(siteWord(site, page, "requirements"), { version: site.minimumOS }),
    }, "Website/templates/home.html");
    const [main] = site.pages;
    const alternates = [
        ...site.pages.map((other) => `  <link rel="alternate" hreflang="${other.language}" href="${site.origin}${other.path}">`),
        `  <link rel="alternate" hreflang="x-default" href="${site.origin}${main?.path ?? "/"}">`,
    ].join("\n");
    return renderLayout(site, {
        page,
        title: name,
        description: description.intro,
        path: page.path,
        alternates,
        languageNav: renderLanguageNav(site, page),
        content,
    });
}

export function renderPrivacy(site: Site): string {
    const [page] = site.pages;
    if (!page) throw new Error("the site has no pages");
    const content = fill(site.templates.privacy, {
        thirdPartyCode: site.packages.map((pkg) => `          <li><strong><a href="${escapeHTML(pkg.url)}">${escapeHTML(pkg.name)}</a></strong>: ${escapeHTML(pkg.description)}</li>`).join("\n"),
        privacyEmail: site.config.privacyEmail,
    }, "Website/templates/privacy.html");
    return renderLayout(site, {
        page,
        title: site.config.privacyPage.title,
        description: site.config.privacyPage.description,
        path: site.privacyPath,
        alternates: "",
        languageNav: "",
        content,
    });
}

export function renderStyle(site: Site): string {
    const values = Object.fromEntries(appearances.flatMap((appearance) => Object.entries(site.palette[appearance]).map(([role, value]) => [`${appearance}.${role}`, value])));
    return fill(site.templates.style, values, "Website/templates/style.css");
}

/// Every generated file of the site, by its path in the built site. The
/// screenshots are each page's App Store images, as many as were found.
export function renderSite(site: Site, screenshots: Map<string, Screenshot[]>): Map<string, string> {
    const files = new Map<string, string>();
    for (const page of site.pages) files.set(page.file, renderHome(site, page, screenshots.get(page.locale) ?? []));
    files.set(site.privacyPath.slice(1), renderPrivacy(site));
    files.set("style.css", renderStyle(site));
    return files;
}
