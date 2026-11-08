// Tests for scripts/lib/website.ts and scripts/build-website.ts, which build
// the website from the app's own sources. They build from a copy of only the
// files the site reads, so a test can break one. Run with:
// node --test scripts/website.test.ts

import assert from "node:assert/strict";
import { cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { after, describe, test } from "node:test";

import { buildWebsite, missingImages } from "./build-website.ts";
import type { Changelog } from "./lib/changelog.ts";
import { writePNG } from "./lib/png.ts";
import {
    appearances,
    appWordsFrom,
    contrast,
    englishName,
    escapeHTML,
    fill,
    format,
    nativeName,
    pagesFor,
    paletteFrom,
    parseDescription,
    readSite,
    renderHome,
    renderPrivacy,
    renderStyle,
    screenshotSources,
    swiftColours,
} from "./lib/website.ts";

const repository = join(import.meta.dirname, "..");
/// Everything the site reads, besides the store images.
const sources = [
    "metadata",
    "changelog.json",
    "Cards.xcodeproj/project.pbxproj",
    "Cards.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved",
    "Cards/Localizable.xcstrings",
    "Cards/UI/Theme/Colors.swift",
    "Website/site.json",
    "Website/templates",
    "Website/static",
];
const temporary: string[] = [];
after(() => {
    for (const dir of temporary) rmSync(dir, { recursive: true, force: true });
});

/// A copy of the site's sources, with each store locale's captions but none of its images.
function copyOfSources(): string {
    const root = mkdtempSync(join(tmpdir(), "cards-website-"));
    temporary.push(root);
    for (const path of sources) cpSync(join(repository, path), join(root, path), { recursive: true });
    for (const locale of ["de-DE", "en-GB", "en-US", "es-ES", "es-MX", "ja"]) {
        cpSync(join(repository, "screenshots/store", locale, "captions.json"), join(root, "screenshots/store", locale, "captions.json"));
    }
    return root;
}

function edit(root: string, path: string, change: (text: string) => string): void {
    writeFileSync(join(root, path), change(readFileSync(join(root, path), "utf8")));
}

/// A small stand-in for every App Store image the site shows, 1,320 pixels wide as the real ones are.
function addStoreImages(root: string): void {
    const image = writePNG({ width: 1320, height: 6, channels: 3, pixels: new Uint8Array(1320 * 6 * 3).fill(200) });
    for (const source of screenshotSources(readSite(root), root)) {
        mkdirSync(dirname(source.source), { recursive: true });
        writeFileSync(source.source, image);
    }
}

describe("the pages", () => {
    test("are British English at / and each other language at its code, from its main region's listing", () => {
        const pages = pagesFor(["en", "es", "de", "ja"], ["de-DE", "en-GB", "en-US", "es-MX", "es-ES", "ja"]);
        assert.deepEqual(pages, [
            { language: "en", locale: "en-GB", path: "/", file: "index.html" },
            { language: "es", locale: "es-ES", path: "/es/", file: "es/index.html" },
            { language: "de", locale: "de-DE", path: "/de/", file: "de/index.html" },
            { language: "ja", locale: "ja", path: "/ja/", file: "ja/index.html" },
        ]);
        assert.equal(pagesFor(["es"], ["es-MX"])[0]?.locale, "es-MX");
        assert.throws(() => pagesFor(["en", "fr"], ["en-GB"]), /fr is one of the app's languages but has no App Store listing/);
    });

    test("name each language in itself and in English", () => {
        assert.deepEqual(["en", "es", "de", "ja"].map(nativeName), ["English", "Español", "Deutsch", "日本語"]);
        assert.deepEqual(["es", "de", "ja"].map(englishName), ["Spanish", "German", "Japanese"]);
    });
});

describe("a listing's description", () => {
    test("gives the lead, the promise and the features", () => {
        const description = parseDescription("Keeps your cards. It is free, and it always will be.\n\nREADY AT THE TILL\nOpen a card.\n\nPRIVATE\nNo ads.", "en-GB");
        assert.deepEqual(description, {
            intro: "Keeps your cards. It is free, and it always will be.",
            lead: "Keeps your cards.",
            promise: "It is free, and it always will be.",
            features: [
                { heading: "READY AT THE TILL", paragraphs: ["Open a card."] },
                { heading: "PRIVATE", paragraphs: ["No ads."] },
            ],
        });
    });

    test("splits Japanese sentences and drops the brackets round its headings", () => {
        const description = parseDescription("カードを入れます。無料です。これからも変わりません。\n\n【レジで】\nすぐに使えます。", "ja");
        assert.equal(description.lead, "カードを入れます。");
        assert.equal(description.promise, "無料です。これからも変わりません。");
        assert.equal(description.features[0]?.heading, "レジで");
    });

    test("fails when the promise or a feature's text is missing", () => {
        assert.throws(() => parseDescription("Keeps your cards.\n\nPRIVATE\nNo ads.", "en-GB"), /first paragraph must be a sentence on what the app does, then the promise/);
        assert.throws(() => parseDescription("Keeps your cards. Free.\n\nPRIVATE", "en-GB"), /"PRIVATE" is a paragraph of one line/);
        assert.throws(() => parseDescription("Keeps your cards. Free.", "en-GB"), /has no features/);
    });
});

describe("the colours", () => {
    const palette = paletteFrom(swiftColours(readFileSync(join(repository, "Cards/UI/Theme/Colors.swift"), "utf8")));

    test("are the app's", () => {
        assert.equal(palette.light.accent, "#D0185B");
        assert.equal(palette.dark.accent, "#FF6699");
        assert.equal(palette.light.secondaryText, "#636366");
        assert.throws(() => paletteFrom(new Map()), /Colors\.swift has no secondaryTextLightRGB, accentLightRGB/);
    });

    test("measure contrast as WCAG does", () => {
        assert.equal(contrast("#FFFFFF", "#000000"), 21);
        assert.equal(contrast("#777777", "#777777"), 1);
    });

    // Rule 5: never lower these thresholds; change the colour instead.
    for (const appearance of appearances) {
        test(`keep every text readable in ${appearance} appearance`, () => {
            const colours = palette[appearance];
            for (const surface of [colours.background, colours.groupedBackground]) {
                for (const [role, ink] of Object.entries({ text: colours.text, secondaryText: colours.secondaryText, accent: colours.accent })) {
                    assert.ok(contrast(ink, surface) >= 4.5, `${role} ${ink} on ${surface} is ${contrast(ink, surface).toFixed(2)}:1`);
                }
            }
            assert.ok(contrast(colours.accentInk, colours.accent) >= 4.5, `button text on ${colours.accent} is ${contrast(colours.accentInk, colours.accent).toFixed(2)}:1`);
            if (appearance.endsWith("Increased")) {
                assert.ok(contrast(colours.line, colours.groupedBackground) >= 3, `panel edges are ${contrast(colours.line, colours.groupedBackground).toFixed(2)}:1`);
            }
        });
    }
});

describe("templates", () => {
    test("escape {{values}}, insert {{{markup}}}, and fail on a name with no value", () => {
        assert.equal(fill("<p>{{a}}</p>{{{b}}}", { a: `Joe's <Market> & "Co"`, b: "<br>" }, "t"), "<p>Joe&#39;s &lt;Market&gt; &amp; &quot;Co&quot;</p><br>");
        assert.throws(() => fill("{{missing}}", {}, "page.html"), /page\.html uses \{\{missing\}\}, which nothing fills/);
        assert.equal(format("iOS {version} or later", { version: "18" }), "iOS 18 or later");
        assert.throws(() => format("{nope}"), /has \{nope\}, which nothing fills/);
        assert.equal(escapeHTML("a&b"), "a&amp;b");
    });

    test("take What's New's words from the app's catalogue", () => {
        const problems: string[] = [];
        const words = appWordsFrom(readFileSync(join(repository, "Cards/Localizable.xcstrings"), "utf8"), ["en", "de", "fr"], problems);
        assert.deepEqual(words.get("en"), { whatsNew: "What's New", version: "Version %@", new: "New: %@", improved: "Improved: %@", fixed: "Fixed: %@" });
        assert.equal(words.get("de")?.whatsNew, "Neue Funktionen");
        assert.ok(problems.some((problem) => problem.includes(`no fr text for "What's New"`)), problems.join("\n"));
    });
});

describe("the site", () => {
    const root = copyOfSources();
    const site = readSite(root);
    const page = (language: string) => site.pages.find((candidate) => candidate.language === language) ?? assert.fail(`no ${language} page`);

    test("has a home page per app language, linked to each other", () => {
        assert.deepEqual(site.pages.map((candidate) => candidate.path), ["/", "/de/", "/es/", "/ja/"]);
        const html = renderHome(site, page("es"), []);
        assert.match(html, /<html lang="es-ES">/);
        for (const path of ["/", "/de/", "/es/", "/ja/"]) assert.match(html, new RegExp(`<link rel="alternate" hreflang="\\w+" href="https://cards\\.serby\\.net${path}">`));
        assert.match(html, /<link rel="alternate" hreflang="x-default" href="https:\/\/cards\.serby\.net\/">/);
        assert.match(html, /<a href="\/es\/" lang="es" hreflang="es" aria-current="page">Español<\/a>/);
        assert.match(html, /<a href="\/privacy\.html" hreflang="en">Privacidad<\/a>/);
    });

    test("says the promise in the listing's own words", () => {
        const promise = readFileSync(join(root, "metadata/en-GB/description.txt"), "utf8").split("\n")[0]?.replace(/^[^.]*\.\s*/, "") ?? "";
        assert.match(promise, /always will be/);
        assert.ok(renderHome(site, page("en"), []).includes(`<p class="promise">${escapeHTML(promise)}</p>`));
    });

    test("shows released versions only, newest first, falling back to British English as the app does", () => {
        const changelog: Changelog = {
            versions: [
                { version: "2.1", date: null, changes: [{ type: "new", text: "Not out yet.", ja: "まだです。" }] },
                { version: "2.0", date: "2026-12-01", changes: [{ type: "new", text: "Translated.", ja: "翻訳済み。" }, { type: "fixed", text: "In English only." }] },
                { version: "1.9", date: "2026-10-01", changes: [{ type: "improved", text: "Older." }] },
            ],
        };
        const html = renderHome({ ...site, changelog }, page("ja"), []);
        assert.ok(!html.includes("バージョン2.1"), "an unreleased version is not shown");
        assert.ok(html.includes(`<h3>バージョン2.0</h3>\n        <p class="date"><time datetime="2026-12-01">2026年12月1日</time></p>`));
        assert.ok(html.includes("<li><strong>新機能：</strong>翻訳済み。</li>"));
        assert.ok(html.includes(`<li><strong>修正：</strong><span lang="en-GB">In English only.</span></li>`));
        assert.ok(html.indexOf("バージョン2.0") < html.indexOf("<summary>以前のバージョン</summary>"));
        assert.ok(html.indexOf("<summary>以前のバージョン</summary>") < html.indexOf("バージョン1.9"));
        const english = renderHome({ ...site, changelog }, page("en"), []);
        assert.ok(english.includes("<li><strong>Fixed: </strong>In English only.</li>"));
        assert.ok(english.includes(`<time datetime="2026-12-01">1 December 2026</time>`));
    });

    test("describes each App Store image with its caption", () => {
        const [shot] = screenshotSources(site, root).filter((source) => source.locale === "ja");
        const captions = JSON.parse(readFileSync(join(root, "screenshots/store/ja/captions.json"), "utf8")) as { file: string; title: string; subtitle: string }[];
        assert.equal(shot?.alt, `${captions[0]?.title}。${captions[0]?.subtitle}。`);
        assert.equal(shot?.file, `screenshots/ja/${captions[0]?.file}.png`);
        const html = renderHome(site, page("ja"), [{ src: "/a.png", width: 440, height: 956, alt: shot?.alt ?? "" }]);
        assert.match(html, /<img src="\/a\.png" width="440" height="956" alt="[^"]+。[^"]+。" loading="lazy"/);
        assert.ok(!renderHome(site, page("ja"), []).includes(`class="screenshots"`), "no images, no section");
    });

    test("lists the third-party code from the package pins in the privacy policy", () => {
        assert.match(renderPrivacy(site), /<a href="https:\/\/github\.com\/yeahdongcn\/RSBarcodes_Swift">RSBarcodes_Swift<\/a><\/strong>: an open-source library/);
    });

    test("fills the styles with the app's colours", () => {
        const css = renderStyle(site);
        assert.match(css, /--accent: #D0185B;/);
        assert.ok(!css.includes("{{"));
    });
});

describe("a broken source", () => {
    test("stops the build, naming every problem", () => {
        const root = copyOfSources();
        edit(root, "Website/site.json", (text) => {
            const config = JSON.parse(text) as { strings: Record<string, Record<string, string>>; packages: Record<string, string> };
            delete config.strings.download?.ja;
            config.strings.unused = { en: "Unused" };
            config.packages = { other: "Something" };
            return JSON.stringify(config);
        });
        edit(root, "metadata/de-DE/description.txt", (text) => text.replace(/^[^\n]*\n/, "Nur ein Satz.\n"));
        assert.throws(() => readSite(root), (error: Error) => {
            for (const expected of [
                `Website/site.json: "download" has no ja text`,
                `Website/site.json: strings has "unused", which no page uses`,
                "Website/site.json: packages describes other, which Package.resolved does not pin",
                "Website/site.json: packages has no description of rsbarcodes_swift",
                "metadata/de-DE/description.txt its first paragraph must be a sentence on what the app does, then the promise",
            ]) assert.ok(error.message.includes(expected), `missing "${expected}" in:\n${error.message}`);
            return true;
        });
    });

    test("includes a changelog that does not check", () => {
        const root = copyOfSources();
        edit(root, "changelog.json", (text) => text.replace(/"type": "new"/, `"type": "added"`));
        assert.throws(() => readSite(root), /changelog\.json: versions\[0\].*type must be one of new, improved, fixed/);
    });
});

describe("the build", () => {
    test("writes every page and image, and copies the static files unchanged", () => {
        const root = copyOfSources();
        addStoreImages(root);
        const out = join(root, "Website", "dist");
        const lines: string[] = [];
        const result = buildWebsite({ root, out, log: (line) => lines.push(line) });
        assert.deepEqual(result.skipped, []);
        for (const file of ["index.html", "de/index.html", "es/index.html", "ja/index.html", "privacy.html", "style.css", "screenshots/en-GB/01_Places.png"]) {
            assert.ok(result.files.includes(file), `${file} is built`);
        }
        for (const file of ["add.html", "demo.html", "_headers", ".well-known/apple-app-site-association", "icon.png"]) {
            assert.deepEqual(readFileSync(join(out, file)), readFileSync(join(repository, "Website/static", file)), `${file} is copied unchanged`);
        }
        assert.ok(result.files.every((file) => !file.startsWith("screenshots/en-US/") && !file.startsWith("screenshots/es-MX/")), "only the pages' listings' images");
        assert.match(readFileSync(join(out, "index.html"), "utf8"), /<img src="\/screenshots\/en-GB\/01_Places\.png" width="440" height="2"/);
        assert.match(lines.join("\n"), /4 home pages \(\/ \/de\/ \/es\/ \/ja\/\)/);
    });

    test("stops while an App Store image is missing, unless told to leave it out", () => {
        const root = copyOfSources();
        const out = join(root, "Website", "dist");
        assert.throws(() => buildWebsite({ root, out, log: () => undefined }), /these App Store images are missing[\s\S]*screenshots\/store\/en-GB\/01_Places_Duo\.png[\s\S]*--allow-missing-images/);
        const result = buildWebsite({ root, out, allowMissingImages: true, log: () => undefined });
        assert.ok(result.skipped.includes("screenshots/store/ja/01_Cards_Duo.png"));
        assert.ok(!readFileSync(join(out, "ja/index.html"), "utf8").includes(`class="screenshots"`));
    });

    test("asks before Google Analytics loads, in each page's language", () => {
        const root = copyOfSources();
        addStoreImages(root);
        const out = join(root, "Website", "dist");
        buildWebsite({ root, out, log: () => undefined });
        for (const [file, allow] of [["index.html", "Allow"], ["de/index.html", "Erlauben"], ["privacy.html", "Allow"]] as const) {
            const html = readFileSync(join(out, file), "utf8");
            assert.ok(!/<script[^>]+src="https:\/\/www\.googletagmanager\.com/.test(html), `${file} loads no Google script until it is allowed`);
            assert.match(html, /<div class="consent" id="consent"[^>]* hidden>/, `${file} has the banner, hidden until its script shows it`);
            assert.ok(html.includes(`data-consent="granted">${allow}</button>`), `${file} asks in its language`);
            assert.ok(html.includes("gtm.js?id=GTM-MD2TJFTZ"), `${file} loads the tag once allowed`);
        }
        for (const file of ["add.html", "demo.html"]) assert.ok(!readFileSync(join(out, file), "utf8").includes("googletagmanager"), `${file} never loads analytics`);
    });

    test("checks for the British English page's images, and only those", () => {
        const root = copyOfSources();
        const missing = missingImages(readSite(root), root);
        assert.ok(missing.some((image) => image.endsWith("en-GB/01_Places_Duo.png")));
        assert.ok(missing.every((image) => image.includes("/en-GB/")), "other languages' pages leave theirs out");
        addStoreImages(root);
        assert.deepEqual(missingImages(readSite(root), root), []);
    });

    test("refuses a static file the build would overwrite", () => {
        const root = copyOfSources();
        writeFileSync(join(root, "Website/static/privacy.html"), "old");
        assert.throws(() => buildWebsite({ root, out: join(root, "Website", "dist"), allowMissingImages: true, log: () => undefined }), /Website\/static has privacy\.html, which the build generates/);
    });
});
