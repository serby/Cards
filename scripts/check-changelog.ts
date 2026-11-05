// Checks changelog.json, for CI: fails if it is malformed, if its newest
// version is not the app's MARKETING_VERSION, or if a file generated from it
// (CHANGELOG.md, metadata/<locale>/release_notes.txt) is out of date.
//
// Usage: node scripts/check-changelog.ts

import { appVersion, load, staleOutputs, throwIfProblems, validate } from "./lib/changelog.ts";

function main(): void {
    if (process.argv.length > 2) throw new Error("Usage: node scripts/check-changelog.ts");
    const changelog = load();
    const problems = validate(changelog);
    const version = appVersion();
    if (changelog.versions[0]?.version !== version) {
        problems.push(`the newest version in changelog.json is ${changelog.versions[0]?.version}, but the app is ${version}`);
    }
    throwIfProblems(problems);
    const stale = staleOutputs(changelog).map((output) => output.name);
    if (stale.length > 0) throw new Error(`out of date: ${stale.join(", ")}. Run node scripts/generate-changelog.ts`);
    console.log(`changelog.json is valid and the generated files are up to date (${changelog.versions.length} versions)`);
}

try {
    main();
} catch (error) {
    console.error(`error: ${error instanceof Error ? error.message : String(error)}`);
    process.exitCode = 1;
}
