// Tests for scripts/serve-website.ts, the local preview of the built website.
// Run with: node --test scripts/serve-website.test.ts

import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, describe, test } from "node:test";

import { fileFor, parseHeaders } from "./serve-website.ts";

describe("the preview", () => {
    const site = mkdtempSync(join(tmpdir(), "cards-serve-"));
    after(() => rmSync(site, { recursive: true, force: true }));
    for (const file of ["index.html", "add.html", "es/index.html", ".well-known/apple-app-site-association"]) {
        mkdirSync(join(site, file, ".."), { recursive: true });
        writeFileSync(join(site, file), file);
    }

    test("finds files as Cloudflare Pages does", () => {
        assert.equal(fileFor(site, "/"), join(site, "index.html"));
        assert.equal(fileFor(site, "/add"), join(site, "add.html"));
        assert.equal(fileFor(site, "/add.html"), join(site, "add.html"));
        assert.equal(fileFor(site, "/es/"), join(site, "es/index.html"));
        assert.equal(fileFor(site, "/es"), join(site, "es/index.html"));
        assert.equal(fileFor(site, "/.well-known/apple-app-site-association"), join(site, ".well-known/apple-app-site-association"));
        assert.equal(fileFor(site, "/missing"), undefined);
    });

    test("never serves a file outside the site", () => {
        assert.equal(fileFor(site, "/../index.html"), undefined);
        assert.equal(fileFor(site, "/es/../../etc/passwd"), undefined);
    });

    test("sets the headers _headers gives a path", () => {
        const headers = parseHeaders(readFileSync(join(import.meta.dirname, "..", "Website", "static", "_headers"), "utf8"));
        assert.deepEqual(headers.get("/.well-known/apple-app-site-association"), { "content-type": "application/json" });
        assert.throws(() => parseHeaders("  Content-Type: text/plain\n"), /is not a header under a path/);
    });
});
