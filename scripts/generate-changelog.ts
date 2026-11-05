// Generates everything that shows changelog.json outside the app: CHANGELOG.md
// and each locale's metadata/<locale>/release_notes.txt, the App Store's What's
// New for the newest version. It fails, writing nothing, if changelog.json is
// malformed, and leaves files that are already up to date alone.
//
// Usage: node scripts/generate-changelog.ts

import { writeFileSync } from "node:fs";
import { load, staleOutputs, throwIfProblems, validate } from "./lib/changelog.ts";

function main(): void {
    if (process.argv.length > 2) throw new Error("Usage: node scripts/generate-changelog.ts");
    const changelog = load();
    throwIfProblems(validate(changelog));
    for (const output of staleOutputs(changelog)) {
        writeFileSync(output.path, output.text);
        console.log(`wrote ${output.name}`);
    }
}

try {
    main();
} catch (error) {
    console.error(`error: ${error instanceof Error ? error.message : String(error)}`);
    process.exitCode = 1;
}
