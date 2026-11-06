// Releases the app from CI. release.yml runs it once signing is installed.
//
// With RELEASE_TAG, which release.yml sets on a push of a v* tag, it:
//   1. reads the tag's annotation as en-GB's What's New, and its name, less
//      the v, as the marketing version. The tag must be annotated with a
//      message; a lightweight tag stops the release before anything is built.
//      The other localisations take theirs from metadata/<locale>/release_notes.txt;
//   2. stamps a build number;
//   3. builds and uploads the app (scripts/upload-build.ts);
//   4. submits the version for review (scripts/submit-for-review.ts).
// Without it, as on a manual run of the workflow, it stamps a build number,
// builds and uploads, and submits nothing.
//
// Usage: [RELEASE_TAG=v1.3] node scripts/release-version.ts [--dry-run]
//   --dry-run  resolve the tag and the build number and say what would happen,
//              without building, uploading or submitting. It reads the tag as it
//              is in this clone rather than fetching it, so it can check a tag
//              before it is pushed.
// Needs ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_CONTENT, and takes build-ipa.ts's
// settings except BUILD_NUMBER, which it stamps itself.

import { execFileSync } from "node:child_process";
import { parseArgs } from "node:util";
import { errorMessage } from "./lib/app-store-connect.ts";
import { appVersion } from "./lib/changelog.ts";
import { root } from "./lib/xcode.ts";
import { submitForReview } from "./submit-for-review.ts";
import { uploadBuild } from "./upload-build.ts";

const usage = "Usage: [RELEASE_TAG=v1.3] node scripts/release-version.ts [--dry-run]";

/// 2026-01-01T00:00:00Z, in seconds since the epoch.
const buildNumberEpoch = 1767225600;

interface Release {
    /// The marketing version, such as 1.3.
    version: string;
    whatsNew: string;
}

function git(args: string[]): string {
    return execFileSync("git", args, { cwd: root, encoding: "utf8", stdio: ["ignore", "pipe", "inherit"] });
}

/// The version and What's New from an annotated tag.
export function readTag(tag: string, options: { fetch: boolean }): Release {
    const version = tag.replace(/^v/, "");
    if (options.fetch) {
        // actions/checkout points the tag straight at the commit, dropping the
        // annotation, so fetch the tag object itself before reading its message.
        execFileSync("git", ["fetch", "--force", "--no-tags", "--depth=1", "origin", `+refs/tags/${tag}:refs/tags/${tag}`], { cwd: root, stdio: "inherit" });
    }
    let type = "";
    try {
        type = git(["cat-file", "-t", `refs/tags/${tag}`]).trim();
    } catch {
        throw new Error(`There is no tag ${tag}`);
    }
    if (type !== "tag") throw new Error(`Tag ${tag} is lightweight. Use 'git tag -a ${tag} -m "release notes"'.`);

    // The annotation, without any signature block.
    const lines = git(["for-each-ref", `refs/tags/${tag}`, "--format=%(contents)"]).split("\n");
    const signature = lines.findIndex((line) => line.includes("-----BEGIN PGP SIGNATURE-----") || line.includes("-----BEGIN SSH SIGNATURE-----"));
    const whatsNew = (signature === -1 ? lines : lines.slice(0, signature)).join("\n").trimEnd();
    if (whatsNew.trim() === "") throw new Error(`Tag ${tag} is lightweight or has no message. Use 'git tag -a ${tag} -m "release notes"'.`);
    return { version, whatsNew };
}

/// A CFBundleVersion that rises with every run: minutes since 2026-01-01 UTC.
/// App Store Connect refuses a build number it has seen before (409
/// ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE, as on the first release attempt).
export function stampBuildNumber(now: number = Date.now()): string {
    return String(Math.floor((Math.floor(now / 1000) - buildNumberEpoch) / 60));
}

async function main(): Promise<void> {
    const { values } = parseArgs({
        args: process.argv.slice(2),
        options: { "dry-run": { type: "boolean", default: false }, help: { type: "boolean", short: "h", default: false } },
        strict: true,
        allowPositionals: false,
    });
    if (values.help) {
        console.log(usage);
        return;
    }
    const dryRun = values["dry-run"];
    const tag = process.env.RELEASE_TAG || undefined;

    let release: Release | undefined;
    if (tag) {
        release = readTag(tag, { fetch: !dryRun });
        // A build of another version would never match the tag, and the submit
        // step would only find out after half an hour of waiting for it.
        const projectVersion = appVersion();
        if (release.version !== projectVersion) {
            throw new Error(`Tag ${tag} is version ${release.version}, but the project's MARKETING_VERSION is ${projectVersion}`);
        }
        console.log(`Marketing version: ${release.version}`);
        console.log("What's New (en-GB; the other localisations from metadata/<locale>/release_notes.txt):");
        console.log(release.whatsNew);
    } else {
        console.log("No RELEASE_TAG: uploading only, not submitting for review");
    }

    const buildNumber = stampBuildNumber();
    console.log(`Setting CFBundleVersion to ${buildNumber}`);

    if (dryRun) {
        console.log(`Dry run: would build and upload build ${buildNumber}`);
        if (release) console.log(`Dry run: would then submit version ${release.version}, build ${buildNumber}, for review`);
        return;
    }

    uploadBuild({ buildNumber });

    // A manual run has no tag, and so no release notes: it uploads only.
    if (release) {
        await submitForReview({ marketingVersion: release.version, buildVersion: buildNumber, whatsNew: release.whatsNew, bundleId: process.env.BUNDLE_ID || undefined });
    }
}

if (import.meta.main) {
    try {
        await main();
    } catch (error) {
        // GitHub Actions shows ::error:: lines as annotations on the run.
        console.error(`${process.env.GITHUB_ACTIONS === "true" ? "::error::" : "error: "}${errorMessage(error)}`);
        process.exitCode = 1;
    }
}
