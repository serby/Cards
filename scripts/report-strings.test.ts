// Tests for scripts/report-strings.ts, run on a copy of the fixture project.
// Run with: node --test scripts/report-strings.test.ts

import assert from "node:assert/strict";
import { rmSync } from "node:fs";
import { describe, test } from "node:test";

import { assertUsage, projectCopy, runScript } from "./fixtures/string-catalogues/test-project.ts";

describe("report-strings", () => {
    test("counts each catalogue and language", () => {
        const root = projectCopy();
        try {
            const result = runScript("report-strings", root, []);
            assert.equal(result.status, 0);
            assert.match(result.stdout, /Cards\/Localizable.xcstrings: 3 to translate, 0 not translatable, 0 stale/);
            assert.match(result.stdout, /Cards\/Localizable.xcstrings\s+ja\s+0\s+3\s+0\s+0\s+0/);
            assert.ok(!result.stdout.includes("Storybook"));
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });

    test("prints its usage on --help, and exits 2 on a usage error", () => {
        assertUsage("report-strings");
    });
});
