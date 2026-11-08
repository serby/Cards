// Prints the Developer directory of the Xcode named in .xcode-version, for
// DEVELOPER_DIR, or fails if that Xcode is missing or another version. The
// Makefile and the GitHub workflows use it so they build with the same Xcode as
// the TypeScript scripts (scripts/lib/xcode.ts). With --run, it is the Xcode
// that test run uses here: on CI, a run's ciXcode where it names one
// (lib/test-devices.ts), as the Xcode 26.3 runs do.
//
// Usage: node scripts/select-xcode.ts [--run <key>]

import { parseArgs } from "node:util";
import { testRun, xcodeVersionFor } from "./lib/test-devices.ts";
import { developerDir, pinnedXcodeVersion, useXcodeVersion } from "./lib/xcode.ts";

try {
    const { values } = parseArgs({ options: { run: { type: "string" } }, allowPositionals: false });
    if (values.run) {
        const version = xcodeVersionFor(testRun(values.run), pinnedXcodeVersion());
        if (version !== pinnedXcodeVersion()) useXcodeVersion(version);
    }
    console.log(developerDir());
} catch (error) {
    console.error(`error: ${error instanceof Error ? error.message : String(error)}`);
    process.exit(1);
}
