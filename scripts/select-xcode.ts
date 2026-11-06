// Prints the Developer directory of the Xcode named in .xcode-version, for
// DEVELOPER_DIR, or fails if that Xcode is missing or another version. The
// Makefile and the GitHub workflows use it so they build with the same Xcode as
// the TypeScript scripts (scripts/lib/xcode.ts).
//
// Usage: node scripts/select-xcode.ts

import { developerDir } from "./lib/xcode.ts";

try {
    console.log(developerDir());
} catch (error) {
    console.error(`error: ${error instanceof Error ? error.message : String(error)}`);
    process.exit(1);
}
