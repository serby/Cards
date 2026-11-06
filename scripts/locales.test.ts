// Tests for scripts/lib/locales.ts. Run with: node --test scripts/locales.test.ts

import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { describe, test } from "node:test";

import { appLanguages, languageOf, regionOf, storeLocales } from "./lib/locales.ts";

/// A temporary repository holding these files, removed after `body`.
function withRoot(files: Record<string, string>, body: (root: string) => void): void {
    const root = mkdtempSync(join(tmpdir(), "locales-test-"));
    try {
        for (const [path, text] of Object.entries(files)) {
            mkdirSync(dirname(join(root, path)), { recursive: true });
            writeFileSync(join(root, path), text);
        }
        body(root);
    } finally {
        rmSync(root, { recursive: true, force: true });
    }
}

describe("store locales", () => {
    test("are the folders in metadata/, sorted, and nothing else", () => {
        withRoot({
            "metadata/copyright.txt": "2026 Paul Serby",
            "metadata/ja/name.txt": "カード",
            "metadata/es-MX/name.txt": "Tarjetas",
            "metadata/en-GB/name.txt": "Cards",
            "metadata/.hidden/name.txt": "",
        }, (root) => {
            assert.deepEqual(storeLocales(root), ["en-GB", "es-MX", "ja"]);
        });
    });

    test("give their language, with its script, and their region, or the likely one", () => {
        const parts = (code: string) => [languageOf(code), regionOf(code)];
        assert.deepEqual(parts("ja"), ["ja", "JP"]);
        assert.deepEqual(parts("es-MX"), ["es", "MX"]);
        assert.deepEqual(parts("es-ES"), ["es", "ES"]);
        assert.deepEqual(parts("de-DE"), ["de", "DE"]);
        assert.deepEqual(parts("en-US"), ["en", "US"]);
        assert.deepEqual(parts("zh-Hant"), ["zh-Hant", "TW"]);
        assert.deepEqual(parts("pt-BR"), ["pt", "BR"]);
    });
});

describe("app languages", () => {
    test("are the project's knownRegions less en and Base", () => {
        const pbxproj = `\t\t\tknownRegions = (\n\t\t\t\ten,\n\t\t\t\tBase,\n\t\t\t\tde,\n\t\t\t\tes,\n\t\t\t\tja,\n\t\t\t\t"pt-BR",\n\t\t\t);\n`;
        withRoot({ "Cards.xcodeproj/project.pbxproj": pbxproj }, (root) => {
            assert.deepEqual(appLanguages(root), ["de", "es", "ja", "pt-BR"]);
        });
    });
});
