// Uploads the release archive's dSYMs to Sentry, so crash reports sent with
// Share Diagnostics on (PLAT-14) show the app's own function names and lines.
// Each .dSYM goes as a zip to the project's debug-file endpoint. Without a
// token it says so and does nothing, so a release never fails for want of one.
//
// Usage: SENTRY_AUTH_TOKEN=... node scripts/upload-dsyms.ts [--archive build/release/Cards.xcarchive]
// SENTRY_AUTH_TOKEN is a Sentry auth token with project:write, kept in the
// repository's secrets.

import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { basename, join } from "node:path";
import { parseArgs } from "node:util";
import { logger, runScript } from "./lib/command-line.ts";
import { dsymBundles, uploadUrl } from "./lib/sentry.ts";

const log = logger("upload-dsyms");

async function main(argv: string[]): Promise<number> {
    const { values } = parseArgs({ args: argv, options: { archive: { type: "string", default: join("build", "release", "Cards.xcarchive") } } });
    const token = process.env.SENTRY_AUTH_TOKEN?.trim();
    if (!token) {
        log("SENTRY_AUTH_TOKEN is not set, so no dSYMs were uploaded; crash stacks from this build will not be readable");
        return 0;
    }
    const bundles = dsymBundles(values.archive ?? "");
    if (bundles.length === 0) {
        log(`no dSYMs in ${values.archive}`);
        return 1;
    }
    const scratch = mkdtempSync(join(tmpdir(), "dsyms-"));
    try {
        for (const bundle of bundles) {
            const zip = join(scratch, `${basename(bundle)}.zip`);
            execFileSync("ditto", ["-c", "-k", "--keepParent", bundle, zip]);
            const form = new FormData();
            form.append("file", new Blob([readFileSync(zip)]), basename(zip));
            const response = await fetch(uploadUrl(), { method: "POST", headers: { Authorization: `Bearer ${token}` }, body: form });
            if (!response.ok) {
                log(`${basename(bundle)}: Sentry said ${response.status} ${await response.text()}`);
                return 1;
            }
            log(`uploaded ${basename(bundle)}`);
        }
    } finally {
        rmSync(scratch, { recursive: true, force: true });
    }
    return 0;
}

runScript("upload-dsyms", main);
