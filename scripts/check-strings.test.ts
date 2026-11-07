// Tests for scripts/check-strings.ts, run on a copy of the fixture project.
// Run with: node --test scripts/check-strings.test.ts
// The other string scripts' tests run it after each change they make.

import assert from "node:assert/strict";
import { rmSync } from "node:fs";
import { describe, test } from "node:test";

import { assertUsage, projectCopy, runScript } from "./fixtures/string-catalogues/test-project.ts";

describe("check-strings", () => {
    test("fails on a language not yet translated, naming every key, and sums up", () => {
        const root = projectCopy();
        try {
            const result = runScript("check-strings", root, []);
            assert.equal(result.status, 1);
            assert.match(result.stderr, /error: Cards\/Localizable.xcstrings \[ja\] "Settings": no translation/);
            assert.equal(result.stdout, "Checked 3 keys in 1 catalogue × 1 language: 3 errors, 0 warnings.\n");
        } finally {
            rmSync(root, { recursive: true, force: true });
        }
    });

    test("prints its usage on --help, and exits 2 on a usage error", () => {
        assertUsage("check-strings");
    });
});
