// Sets up code signing on a GitHub runner, for .github/actions/install-signing:
// imports the Apple Distribution certificate into a temporary keychain, then
// installs an App Store profile for each bundle ID through the App Store Connect
// API (scripts/install-signing-profiles.ts). --remove deletes the keychain;
// release.yml runs it at the end of every run, whatever happened.
//
// The keychain is $RUNNER_TEMP/app-signing.keychain-db, and it replaces the
// user's keychain search list so that codesign finds the certificate without
// asking. That suits a throwaway runner, not a Mac you use, so the script needs
// RUNNER_TEMP, which GitHub's runners set. On your own Mac, Xcode signs for you.
//
// Usage: node scripts/install-signing-certificate.ts <bundle ID>...
//        node scripts/install-signing-certificate.ts --remove
//   BUILD_CERTIFICATE_BASE64  the .p12 certificate, base64-encoded
//   P12_PASSWORD              its password
//   KEYCHAIN_PASSWORD         a password for the temporary keychain
// The profiles need ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_CONTENT too.

import { execFileSync } from "node:child_process";
import { existsSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { parseArgs } from "node:util";
import { installSigningProfiles } from "./install-signing-profiles.ts";
import { errorMessage } from "./lib/app-store-connect.ts";

const usage = `Usage: node scripts/install-signing-certificate.ts <bundle ID>...
       node scripts/install-signing-certificate.ts --remove`;

function runnerTemp(): string {
    const dir = process.env.RUNNER_TEMP;
    if (!dir) throw new Error("RUNNER_TEMP is not set. This script sets up signing on a GitHub runner; on your own Mac, Xcode signs for you");
    return dir;
}

/// The temporary keychain.
export function keychainPath(): string {
    return join(runnerTemp(), "app-signing.keychain-db");
}

function certificatePath(): string {
    return join(runnerTemp(), "build_certificate.p12");
}

/// Runs security(1). Its arguments include passwords, so a failure names only
/// the subcommand, never the command line.
function security(args: string[]): void {
    try {
        execFileSync("security", args, { stdio: ["ignore", "inherit", "inherit"] });
    } catch (error) {
        const status = (error as { status?: number | null }).status;
        throw new Error(`security ${args[0]} failed${status == null ? "" : ` (exit code ${status})`}`);
    }
}

/// Imports the certificate into the temporary keychain, then installs a profile per bundle ID.
export async function installSigningCertificate(bundleIds: string[]): Promise<void> {
    if (bundleIds.length === 0) throw new Error(`no bundle IDs. ${usage}`);
    const keychain = keychainPath();
    const p12 = certificatePath();
    const certificate = process.env.BUILD_CERTIFICATE_BASE64;
    if (!certificate) throw new Error("BUILD_CERTIFICATE_BASE64 is not set");
    const p12Password = process.env.P12_PASSWORD ?? "";
    const keychainPassword = process.env.KEYCHAIN_PASSWORD ?? "";

    const bytes = Buffer.from(certificate, "base64");
    if (bytes.length === 0) throw new Error("BUILD_CERTIFICATE_BASE64 is not base64");
    writeFileSync(p12, bytes, { mode: 0o600 });
    try {
        security(["create-keychain", "-p", keychainPassword, keychain]);
        security(["set-keychain-settings", "-lut", "21600", keychain]);
        security(["unlock-keychain", "-p", keychainPassword, keychain]);
        security(["import", p12, "-P", p12Password, "-A", "-t", "cert", "-f", "pkcs12", "-k", keychain]);
        security(["set-key-partition-list", "-S", "apple-tool:,apple:,codesign:", "-s", "-k", keychainPassword, keychain]);
        security(["list-keychain", "-d", "user", "-s", keychain]);
    } finally {
        rmSync(p12, { force: true });
    }
    console.log(`Imported the certificate into ${keychain}`);

    await installSigningProfiles(bundleIds, keychain);
}

/// Deletes the temporary keychain. Like the cleanup step it replaces, it never
/// fails the run: a keychain that is missing, or will not go, is only reported.
export function removeKeychain(): void {
    const keychain = keychainPath();
    rmSync(certificatePath(), { force: true });
    if (!existsSync(keychain)) {
        console.log(`No keychain at ${keychain}; nothing to remove`);
        return;
    }
    try {
        security(["delete-keychain", keychain]);
        console.log(`Removed ${keychain}`);
    } catch (error) {
        console.log(`warning: could not remove ${keychain}: ${errorMessage(error)}`);
    }
}

if (import.meta.main) {
    try {
        const { values, positionals } = parseArgs({
            args: process.argv.slice(2),
            options: { remove: { type: "boolean", default: false }, help: { type: "boolean", short: "h", default: false } },
            strict: true,
            allowPositionals: true,
        });
        if (values.help) {
            console.log(usage);
        } else if (values.remove) {
            if (positionals.length > 0) throw new Error(`--remove takes no bundle IDs. ${usage}`);
            removeKeychain();
        } else {
            await installSigningCertificate(positionals);
        }
    } catch (error) {
        console.error(`error: ${errorMessage(error)}`);
        process.exitCode = 1;
    }
}
