// Tests for the App Store listing scripts across store locales:
// check-metadata.ts (review notes only in en-GB, no price words in the name or
// subtitle), check-store-images.ts (captions), check-screenshots.ts (a raw
// capture folder for every store locale) and submit-for-review.ts (each
// localisation's What's New). Run with: node --test scripts/metadata.test.ts

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { describe, test } from "node:test";

import { checkMetadata, type Finding, priceWord } from "./check-metadata.ts";
import { checkStoreImages } from "./check-store-images.ts";
import { storeLocales } from "./lib/locales.ts";
import { whatsNewFor } from "./submit-for-review.ts";

/// A temporary directory holding these files, removed after `body`.
function withDir(files: Record<string, string>, body: (dir: string) => void): void {
    const dir = mkdtempSync(join(tmpdir(), "metadata-test-"));
    try {
        for (const [path, text] of Object.entries(files)) {
            mkdirSync(dirname(join(dir, path)), { recursive: true });
            writeFileSync(join(dir, path), text);
        }
        body(dir);
    } finally {
        rmSync(dir, { recursive: true, force: true });
    }
}

/// A complete listing for a locale, with these fields replaced.
function listing(locale: string, fields: Record<string, string> = {}): Record<string, string> {
    const all: Record<string, string> = {
        name: "Card Barcodes",
        subtitle: "Unlimited cards, no ads",
        keywords: "loyalty,wallet",
        description: "Keep your loyalty cards on your phone. Free to download.",
        promotional_text: "Free, with no ads.",
        release_notes: "Share a card.",
        support_url: "https://example.com/support",
        privacy_url: "https://example.com/privacy",
        ...fields,
    };
    return Object.fromEntries(Object.entries(all).map(([field, text]) => [`${locale}/${field}.txt`, text]));
}

const errors = (findings: Finding[]) => findings.filter((finding) => finding.level === "error").map((finding) => `${finding.locale} ${finding.field}: ${finding.message}`);

describe("review notes", () => {
    test("live only in en-GB, and no other locale needs them", () => {
        withDir({ "copyright.txt": "2026 Paul Serby", ...listing("en-GB", { review_notes: "Sign-in is not needed." }), ...listing("es-MX"), ...listing("ja") }, (dir) => {
            const report = checkMetadata(dir);
            assert.deepEqual(errors(report.findings), []);
            assert.ok(!report.rows.some((row) => row.field === "review_notes" && row.locale !== "en-GB"));
        });
    });

    test("in any other locale are an error", () => {
        withDir({ "copyright.txt": "2026 Paul Serby", ...listing("en-GB", { review_notes: "Notes." }), ...listing("en-US", { review_notes: "Notes." }) }, (dir) => {
            assert.deepEqual(errors(checkMetadata(dir).findings), [
                "en-US review_notes: only en-GB has review notes: App Store Connect keeps one set for the version, and uploads en-GB's, so delete this one",
            ]);
        });
    });
});

describe("price words", () => {
    test('are "free" in the listing\'s language, as a whole word', () => {
        assert.equal(priceWord("Card Barcodes Free", "en-GB"), "Free");
        assert.equal(priceWord("Ad-free cards", "en-US"), "free");
        assert.equal(priceWord("Freedom from paper cards", "en-GB"), undefined);
        assert.equal(priceWord("Tarjetas gratis", "es-MX"), "gratis");
        assert.equal(priceWord("Una app gratuita", "es-ES"), "gratuita");
        assert.equal(priceWord("Kostenlose Kundenkarten", "de-DE"), "Kostenlose");
        assert.equal(priceWord("Alles umsonst", "de-DE"), "umsonst");
        assert.equal(priceWord("無料のポイントカード", "ja"), "無料");
        assert.equal(priceWord("free", "ja"), undefined, "each listing is checked for its own language's words");
    });

    test("are every form of the word in French, and in Arabic also after the prefixes joined to it", () => {
        assert.equal(priceWord("Une app gratuite", "fr-FR"), "gratuite");
        assert.equal(priceWord("Cartes gratuites et illimitées", "fr-FR"), "gratuites");
        assert.equal(priceWord("Gratuit pour toujours", "fr-CA"), "Gratuit");
        assert.equal(priceWord("Téléchargez-la gratuitement", "fr-FR"), "gratuitement");
        assert.equal(priceWord("Totalement gratis", "fr-FR"), "gratis");
        assert.equal(priceWord("Cartes illimitées, sans pub", "fr-FR"), undefined);
        assert.equal(priceWord("تطبيق مجاني", "ar-SA"), "مجاني");
        assert.equal(priceWord("بطاقات مجانية بلا إعلانات", "ar-SA"), "مجانية");
        assert.equal(priceWord("حمّله مجانًا", "ar-SA"), "مجانًا", "with a tanween");
        assert.equal(priceWord("حمّله مجانا", "ar-SA"), "مجانا");
        assert.equal(priceWord("تطبيق مجانى", "ar-SA"), "مجانى", "ending in alef maqsura, as it is often written");
        assert.equal(priceWord("تطبيق مَجَّانِيّ", "ar-SA"), "مَجَّانِيّ", "with every short vowel written");
        assert.equal(priceWord("التطبيق السهل والمجاني", "ar-SA"), "والمجاني", "joined to و and the article");
        assert.equal(priceWord("احصل عليه بالمجان", "ar-SA"), "بالمجان");
        assert.equal(priceWord("سريع وبالمجان", "ar-SA"), "وبالمجان");
        assert.equal(priceWord("حكايات المجانين", "ar-SA"), undefined, "مجانين, madmen, is another word on the same letters");
        assert.equal(priceWord("بلا حدود ولا إعلانات", "ar-SA"), undefined);
        assert.equal(priceWord("مجاني", "fr-FR"), undefined, "each listing is checked for its own language's words");
    });

    test("in a French or Arabic name or subtitle are errors, and in the description are allowed", () => {
        const files = {
            "copyright.txt": "2026 Paul Serby",
            ...listing("en-GB"),
            ...listing("fr-FR", { subtitle: "Cartes gratuites, sans pub", description: "L’app est gratuite." }),
            ...listing("ar-SA", { name: "Card Barcodes: بطاقات مجانية", description: "إنه مجاني." }),
        };
        withDir(files, (dir) => {
            assert.deepEqual(errors(checkMetadata(dir).findings), [
                'ar-SA name: has "مجانية"; App Store Review Guideline 2.3.7 keeps price words out of the name and subtitle',
                'fr-FR subtitle: has "gratuites"; App Store Review Guideline 2.3.7 keeps price words out of the name and subtitle',
            ]);
        });
    });

    test("in a name or subtitle are errors, and in the description or promotional text are allowed", () => {
        const files = {
            "copyright.txt": "2026 Paul Serby",
            ...listing("en-GB", { name: "Free Card Barcodes" }),
            ...listing("es-MX", { subtitle: "Tarjetas gratis, sin anuncios" }),
            ...listing("ja", { description: "無料でダウンロード。" }),
        };
        withDir(files, (dir) => {
            assert.deepEqual(errors(checkMetadata(dir).findings), [
                'en-GB name: has "Free"; App Store Review Guideline 2.3.7 keeps price words out of the name and subtitle',
                'es-MX subtitle: has "gratis"; App Store Review Guideline 2.3.7 keeps price words out of the name and subtitle',
            ]);
        });
    });

    test("in a screenshot caption's title or subtitle are errors, beside any missing image", () => {
        const captions = (title: string, subtitle: string) => JSON.stringify([{ file: "01_Cards", screen: "01_CardList", color: "blue", layout: "screen", title, subtitle }]);
        const images = (locale: string) => Object.fromEntries(["", "_iPad", "_Duo"].map((suffix) => [`screenshots/store/${locale}/01_Cards${suffix}.png`, "png"]));
        const files = {
            "metadata/de-DE/name.txt": "Kundenkarten",
            "metadata/en-GB/name.txt": "Card Barcodes",
            "metadata/ja/name.txt": "カード",
            "screenshots/store/de-DE/captions.json": captions("Alle Karten", "Kostenlos und ohne Werbung"),
            ...images("de-DE"),
            "screenshots/store/en-GB/captions.json": captions("Free for ever", "No ads"),
            ...images("en-GB"),
        };
        withDir(files, (root) => {
            const report = checkStoreImages(root);
            assert.equal(report.found, 6);
            assert.deepEqual(report.missing, ["screenshots/store/ja/captions.json"]);
            assert.deepEqual(report.problems, [
                'screenshots/store/de-DE/captions.json: 01_Cards\'s subtitle has "Kostenlos"; App Store Review Guideline 2.3.7 keeps price words out of screenshots and their captions',
                'screenshots/store/en-GB/captions.json: 01_Cards\'s title has "Free"; App Store Review Guideline 2.3.7 keeps price words out of screenshots and their captions',
            ]);
        });
    });
});

describe("What's New on submission", () => {
    test("is the tag's for en-GB, each other locale's release_notes.txt, and the tag's where a locale has none", () => {
        withDir({ "en-GB/release_notes.txt": "From the changelog.\n", "es-MX/release_notes.txt": "Comparte una tarjeta.\n", "ja/release_notes.txt": "\n" }, (dir) => {
            assert.deepEqual(whatsNewFor("en-GB", "From the tag.", dir), { text: "From the tag.", source: "WHATS_NEW" });
            assert.deepEqual(whatsNewFor("es-MX", "From the tag.", dir), { text: "Comparte una tarjeta.", source: "metadata/es-MX/release_notes.txt" });
            assert.deepEqual(whatsNewFor("de-DE", "From the tag.", dir), { text: "From the tag.", source: "WHATS_NEW, as there is no metadata/de-DE/release_notes.txt" });
            assert.equal(whatsNewFor("ja", "From the tag.", dir).text, "From the tag.", "an empty file counts as none");
        });
    });
});

describe("raw captures", () => {
    test("need a folder for every store locale", () => {
        withDir({ "store/en-GB/captions.json": "[]" }, (folder) => {
            const result = spawnSync(process.execPath, [join(import.meta.dirname, "check-screenshots.ts"), folder], { encoding: "utf8" });
            assert.equal(result.status, 1);
            assert.match(result.stderr, new RegExp(`locale folders: expected \\[${storeLocales().join(", ")}\\], found \\[\\]`));
        });
    });
});
