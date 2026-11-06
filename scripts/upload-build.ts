// Archives the app with scripts/build-ipa.ts and uploads the .ipa to App Store
// Connect with altool. Once Apple has processed it, the build is on TestFlight
// and can be attached to an App Store version and submitted for review
// (scripts/submit-for-review.ts). It replaces deploy-testflight.sh and
// deploy-appstore.sh, which were this one upload under two names.
// scripts/release-version.ts imports uploadBuild().
//
// The API key comes from ASC_KEY_CONTENT (the .p8 text) or ASC_KEY_FILE (a path
// to it), written to a private temporary directory for altool and deleted after
// the upload. Without either, altool looks for AuthKey_<ASC_KEY_ID>.p8 in
// ./private_keys, ~/private_keys, ~/.private_keys, ~/.appstoreconnect/private_keys
// and $API_PRIVATE_KEYS_DIR. The key is checked before the build starts. The
// build takes build-ipa.ts's settings, BUILD_NUMBER among them.
//
// Usage: ASC_KEY_ID=... ASC_ISSUER_ID=... ASC_KEY_CONTENT=... node scripts/upload-build.ts

import { copyFileSync, existsSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";
import { parseArgs } from "node:util";
import { buildIpa, type BuildOptions } from "./build-ipa.ts";
import { root, run } from "./lib/xcode.ts";

const usage = "Usage: ASC_KEY_ID=... ASC_ISSUER_ID=... ASC_KEY_CONTENT=... node scripts/upload-build.ts (or ASC_KEY_FILE=<path to the .p8> instead of ASC_KEY_CONTENT)";

function requireEnv(name: string): string {
    const value = process.env[name];
    if (!value) throw new Error(`${name} is not set; uploading needs ASC_KEY_ID, ASC_ISSUER_ID, and ASC_KEY_CONTENT or ASC_KEY_FILE`);
    return value;
}

interface AltoolKey {
    /// Environment for altool, so it finds the key.
    env: Record<string, string>;
    /// Deletes any copy of the key made for altool.
    remove(): void;
}

/// Makes the API key findable by altool, or fails if it cannot be found.
function altoolKey(keyId: string): AltoolKey {
    const fileName = `AuthKey_${keyId}.p8`;
    const content = process.env.ASC_KEY_CONTENT;
    const file = process.env.ASC_KEY_FILE;
    if (content || file) {
        if (!content && file && !existsSync(file)) throw new Error(`ASC_KEY_FILE is ${file}, which does not exist`);
        // mkdtemp makes the directory readable by this user only.
        const dir = mkdtempSync(join(tmpdir(), "cards-asc-key-"));
        const remove = (): void => rmSync(dir, { recursive: true, force: true });
        try {
            if (content) writeFileSync(join(dir, fileName), content.endsWith("\n") ? content : `${content}\n`, { mode: 0o600 });
            else if (file) copyFileSync(file, join(dir, fileName));
        } catch (error) {
            remove();
            throw error;
        }
        return { env: { API_PRIVATE_KEYS_DIR: dir }, remove };
    }
    // Where altool itself looks, in its own order; ./ is the repository, where it runs.
    const searched = [
        join(root, "private_keys"),
        join(homedir(), "private_keys"),
        join(homedir(), ".private_keys"),
        join(homedir(), ".appstoreconnect", "private_keys"),
        ...(process.env.API_PRIVATE_KEYS_DIR ? [process.env.API_PRIVATE_KEYS_DIR] : []),
    ];
    if (!searched.some((dir) => existsSync(join(dir, fileName)))) {
        throw new Error(`No API key: set ASC_KEY_CONTENT or ASC_KEY_FILE, or put ${fileName} in one of ${searched.join(", ")}`);
    }
    return { env: {}, remove: () => undefined };
}

/// Builds the .ipa and uploads it to App Store Connect. Returns the .ipa's path.
export function uploadBuild(options: BuildOptions = {}): string {
    const keyId = requireEnv("ASC_KEY_ID");
    const issuerId = requireEnv("ASC_ISSUER_ID");
    const key = altoolKey(keyId);
    try {
        console.log("Building for distribution...");
        const ipa = buildIpa(options);
        console.log(`Built: ${ipa}`);

        console.log("Uploading to App Store Connect...");
        try {
            run("xcrun", ["altool", "--upload-app", "-f", ipa, "--type", "ios", "--apiKey", keyId, "--apiIssuer", issuerId], { env: key.env });
        } catch (error) {
            const status = (error as { status?: number | null }).status;
            throw new Error(`altool could not upload ${ipa}${status == null ? "" : ` (exit code ${status})`}; its output is above`);
        }

        console.log("Done. Build uploaded to App Store Connect. Once Apple has processed it, it is on TestFlight and can be submitted for review.");
        console.log("Track it at: https://appstoreconnect.apple.com");
        return ipa;
    } finally {
        key.remove();
    }
}

if (import.meta.main) {
    try {
        const { values } = parseArgs({ args: process.argv.slice(2), options: { help: { type: "boolean", short: "h", default: false } }, strict: true, allowPositionals: false });
        if (values.help) {
            console.log(usage);
        } else {
            uploadBuild();
        }
    } catch (error) {
        console.error(`error: ${error instanceof Error ? error.message : String(error)}`);
        process.exitCode = 1;
    }
}
