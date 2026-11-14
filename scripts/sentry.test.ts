import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { dsymBundles, uploadUrl } from "./lib/sentry.ts";

test("upload dSYMs to the card-barcodes project's debug files", () => {
    assert.equal(uploadUrl(), "https://sentry.io/api/0/projects/paul-serby/card-barcodes/files/difs/");
});

test("find every dSYM in an archive, and none in an archive without them", () => {
    const archive = mkdtempSync(join(tmpdir(), "archive-"));
    try {
        assert.deepEqual(dsymBundles(archive), []);
        mkdirSync(join(archive, "dSYMs", "Cards.app.dSYM"), { recursive: true });
        mkdirSync(join(archive, "dSYMs", "CardsWidget.appex.dSYM"), { recursive: true });
        writeFileSync(join(archive, "dSYMs", "notes.txt"), "");
        assert.deepEqual(dsymBundles(archive), [join(archive, "dSYMs", "Cards.app.dSYM"), join(archive, "dSYMs", "CardsWidget.appex.dSYM")]);
    } finally {
        rmSync(archive, { recursive: true, force: true });
    }
});
