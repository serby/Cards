// Builds the app and runs the unit tests (CardsTests) on a simulator, as CI
// does. The simulator boots (scripts/lib/simulator.ts) while the app and tests
// build for any iOS simulator, since each takes minutes on a fresh runner; then
// the tests run on it without building again, retrying a failing test once.
// The result bundle is kept for CI to upload when the tests fail.
//
// Usage: node scripts/run-unit-tests.ts [--device <device type>] [--result-bundle <path>]
//   --device         the simulator's device type, "iPhone 16 Pro Max" unless given
//   --result-bundle  where the result bundle goes, /tmp/CardsTests.xcresult unless given

import { rmSync } from "node:fs";
import { resolve } from "node:path";
import { parseArgs } from "node:util";
import { bootSimulator } from "./lib/simulator.ts";
import { finished, start } from "./lib/xcode.ts";

const usage = "Usage: node scripts/run-unit-tests.ts [--device <device type>] [--result-bundle <path>]";

let options: { device: string; "result-bundle": string };
try {
    options = parseArgs({
        options: {
            device: { type: "string", default: "iPhone 16 Pro Max" },
            "result-bundle": { type: "string", default: "/tmp/CardsTests.xcresult" },
        },
        allowPositionals: false,
    }).values as typeof options;
} catch (error) {
    console.error(`${error instanceof Error ? error.message : String(error)}\n${usage}`);
    process.exit(2);
}
const resultBundle = resolve(options["result-bundle"]);
const project = ["-project", "Cards.xcodeproj", "-scheme", "Cards", "-derivedDataPath", "build/dd"];

function message(error: unknown): string {
    return error instanceof Error ? error.message : String(error);
}

/// Runs xcodebuild with the pinned Xcode without blocking, so the simulator keeps booting.
function xcodebuild(args: string[]): Promise<void> {
    return finished(start("xcodebuild", args), `xcodebuild ${args[0]}`);
}

// The simulator's progress is held back until the build is done, so it does
// not interleave with the build's output.
let simulatorLog = "";
const booting = bootSimulator(options.device, { log: (text) => (simulatorLog += text) });
const building = xcodebuild(["build-for-testing", ...project, "-destination", "generic/platform=iOS Simulator", "-enableCodeCoverage", "NO", "ARCHS=arm64"]);
const [built, booted] = await Promise.allSettled([building, booting]);

console.log(`\n==> Simulator\n${simulatorLog}`);
const failures = [built, booted].filter((result) => result.status === "rejected").map((result) => message(result.reason));
if (built.status === "rejected" || booted.status === "rejected") {
    for (const failure of failures) console.error(`error: ${failure}`);
    process.exit(1);
}

// xcodebuild will not write over an earlier result bundle.
rmSync(resultBundle, { recursive: true, force: true });
try {
    await xcodebuild([
        "test-without-building",
        ...project,
        "-destination", `id=${booted.value.udid}`,
        "-only-testing:CardsTests",
        "-resultBundlePath", resultBundle,
        "-testLanguage", "en",
        "-testRegion", "US",
        "-enableCodeCoverage", "NO",
        "-collect-test-diagnostics", "never",
        "-retry-tests-on-failure",
        "-test-iterations", "2",
    ]);
} catch (error) {
    console.error(`error: ${message(error)}. The result bundle is ${resultBundle}`);
    process.exit(1);
}
