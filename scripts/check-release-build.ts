// Builds the app in Release and checks that no development-only code shipped
// in it.
//
// Builds Release for the simulator (unsigned) with the Xcode pinned in
// .xcode-version, for any simulator rather than the automated tests' one
// (scripts/lib/test-devices.ts), as it runs nothing and so needs no simulator
// or runtime: CI's release check downloads none. Then it looks in the binary for anything declared under
// Cards/Development: its types, and the static members it adds to production
// types (sample data, simulated effects). Also fails on SwiftUI preview
// registrations and on the UI-testing launch keys. See docs/DEVELOPMENT.md,
// "Development code never ships".
//
// Usage: node scripts/check-release-build.ts [--no-build]
//   --no-build  check the last Release build instead of building again

import { execFileSync } from "node:child_process";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { capture, root, run, xcodeEnv } from "./lib/xcode.ts";

const developmentDir = join(root, "Cards", "Development");
const xcodebuildArgs = [
    "-project", join(root, "Cards.xcodeproj"),
    "-scheme", "Cards",
    "-configuration", "Release",
    "-destination", "generic/platform=iOS Simulator",
    // A generic simulator build makes every architecture; one is enough to inspect.
    "ARCHS=arm64",
];

function swiftFiles(dir: string): string[] {
    return readdirSync(dir).flatMap((name) => {
        const path = join(dir, name);
        if (statSync(path).isDirectory()) return swiftFiles(path);
        return path.endsWith(".swift") ? [path] : [];
    });
}

/// What Cards/Development declares, as fragments of demangled symbol names.
function developmentDeclarations(): Map<string, string> {
    const found = new Map<string, string>();
    for (const file of swiftFiles(developmentDir)) {
        const source = readFileSync(file, "utf8");
        const where = relative(root, file);
        for (const match of source.matchAll(/^(?:public |internal |private |fileprivate |final |@\w+ )*(?:struct|class|enum|actor|protocol) (\w+)/gm)) {
            found.set(`Cards.${match[1]}`, where);
        }
        // Static members added to production types, e.g. `CardSummary.samples`.
        for (const block of source.matchAll(/^(?:public )?extension (\w+)[^{]*\{([\s\S]*?)^\}/gm)) {
            for (const member of (block[2] ?? "").matchAll(/static (?:let|var|func) (\w+)/g)) {
                found.set(`Cards.${block[1]}.${member[1]}`, where);
            }
        }
    }
    return found;
}

/// Plain strings that only development code uses.
const forbiddenStrings = ["CARDS_UI_TESTING", "CARDS_SCREENSHOT_SEED"];

if (!process.argv.includes("--no-build")) {
    console.log("==> Building Release");
    run("xcodebuild", [...xcodebuildArgs, "build", "CODE_SIGNING_ALLOWED=NO", "-quiet"]);
}

const settings = capture("xcodebuild", [...xcodebuildArgs, "-showBuildSettings"]);
const productsDir = settings.match(/^\s*BUILT_PRODUCTS_DIR = (.+)$/m)?.[1];
if (!productsDir) throw new Error("Could not find BUILT_PRODUCTS_DIR");
const binary = join(productsDir, "Cards.app", "Cards");

console.log(`==> Checking ${relative(root, binary)}`);
// capture() cannot feed a command its input, so this one passes the pinned Xcode itself.
const demangled = execFileSync("swift", ["demangle"], {
    input: capture("nm", ["-a", binary]),
    env: xcodeEnv(),
    encoding: "utf8",
    maxBuffer: 256 * 1024 * 1024,
});
const strings = capture("strings", ["-a", binary]);

const problems: string[] = [];
for (const [name, file] of developmentDeclarations()) {
    // Match whole names: Cards.Story must not match Cards.StoryKnob's prefix, and vice versa.
    const pattern = new RegExp(`${name.replaceAll(".", "\\.")}(?![\\w])`);
    if (pattern.test(demangled)) problems.push(`${name} (declared in ${file})`);
}
if (/PreviewRegistry/.test(demangled)) problems.push("SwiftUI previews (PreviewRegistry)");
for (const text of forbiddenStrings) {
    if (strings.includes(text)) problems.push(`string "${text}"`);
}

if (problems.length > 0) {
    console.error("Development code found in the release build:");
    for (const problem of problems) console.error(`  - ${problem}`);
    console.error("Move it under Cards/Development, or behind a DevelopmentHooks function.");
    process.exit(1);
}
console.log(`Release build is clean: ${developmentDeclarations().size} development declarations, none shipped.`);
