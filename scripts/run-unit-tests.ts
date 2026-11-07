// Builds the app and runs the unit tests (CardsTests) on the automated tests'
// simulator (scripts/lib/test-devices.ts), the iPhone 17 on iOS 26 that `make
// test` uses too, as CI does. The simulator is made ready (scripts/lib/simulator.ts)
// while the app and tests build for any iOS simulator, since each takes minutes
// on a fresh runner: where its iOS runtime is missing, as on GitHub's xcode-27
// image, it is downloaded from Apple and installed first, then the simulator
// is created if need be and booted. The tests then run on it without building
// again, retrying a failing test once. The result bundle is kept for CI to
// upload when the tests fail.
//
// Usage: node scripts/run-unit-tests.ts [--device <device type>] [--os <version>] [--result-bundle <path>]
//   --device         another device type for a one-off run, such as "iPhone 17 Pro"
//   --os             another iOS for a one-off run, such as "27"
//   --result-bundle  where the result bundle goes, /tmp/CardsTests.xcresult unless given

import { rmSync } from "node:fs";
import { resolve } from "node:path";
import { parseArgs } from "node:util";
import { bootTestSimulator } from "./lib/simulator.ts";
import { automatedTestSimulatorWith } from "./lib/test-devices.ts";
import { finished, projectArgs as project, start } from "./lib/xcode.ts";

const usage = "Usage: node scripts/run-unit-tests.ts [--device <device type>] [--os <version>] [--result-bundle <path>]";

let options: { device?: string; os?: string; "result-bundle": string };
try {
    options = parseArgs({
        options: {
            device: { type: "string" },
            os: { type: "string" },
            "result-bundle": { type: "string", default: "/tmp/CardsTests.xcresult" },
        },
        allowPositionals: false,
    }).values as typeof options;
} catch (error) {
    console.error(`${error instanceof Error ? error.message : String(error)}\n${usage}`);
    process.exit(2);
}
const resultBundle = resolve(options["result-bundle"]);

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
const booting = bootTestSimulator(automatedTestSimulatorWith({ model: options.device, os: options.os }), { log: (text) => (simulatorLog += text) });
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
