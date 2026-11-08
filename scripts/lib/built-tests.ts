// The app and its tests, built once for the simulator by the Xcode in
// .xcode-version and kept in a folder that runs on any Mac: the products, the
// .xctestrun that runs them, and that Xcode's simulator test frameworks
// (XCTest, XCUIAutomation, Swift Testing and the libraries they load). The
// built tests carry no XCTest of their own: their .xctestrun loads the running
// Xcode's (__PLATFORMS__), so the copy here is changed to load the build
// Xcode's instead. Tests built by Xcode 27.1 then run on 27.1's XCTest whichever
// Xcode runs them, as on GitHub's macos-15 image, the only one with iOS 18,
// whose newest Xcode is 26.3. build-tests.ts makes one for CI's test jobs, and
// run-tests.ts makes one, or runs one it is given with --built.
//
// Usage: import { buildTests, testRunFile, withBuiltFrameworks } from "./lib/built-tests.ts";

import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { basename, dirname, join } from "node:path";
import { builtProductsDir, capture, developerDir, finished, pinnedXcodeVersion, projectArgs, start } from "./xcode.ts";

const destination = "generic/platform=iOS Simulator";
const buildSettings = ["ARCHS=arm64"];

/// The parts of the simulator platform's Developer folder the tests load, and
/// where the built tests keep them, as __TESTROOT__/TestPlatform/<part>.
const platformParts = ["Library/Frameworks", "Library/PrivateFrameworks", "usr/lib"];
const platformFolder = "TestPlatform";
const runningPlatform = "__PLATFORMS__/iPhoneSimulator.platform/Developer";

/// The .xctestrun in a folder of built tests.
export function testRunFile(folder: string): string {
    return join(folder, "Cards.xctestrun");
}

/// Builds the app and its tests for the simulator with the pinned Xcode, then
/// puts them in `folder`, in place of what was there.
export async function buildTests(folder: string): Promise<void> {
    await finished(start("xcodebuild", ["build-for-testing", ...projectArgs, "-destination", destination, "-enableCodeCoverage", "NO", ...buildSettings]), "xcodebuild build-for-testing");
    const products = builtProductsDir(destination, buildSettings);
    const sdk = capture("xcrun", ["--sdk", "iphonesimulator", "--show-sdk-version"]).trim();
    const xctestrun = join(dirname(products), `Cards_iphonesimulator${sdk}-arm64.xctestrun`);
    if (!existsSync(xctestrun)) throw new Error(`xcodebuild build-for-testing wrote no ${basename(xctestrun)} beside ${products}`);

    rmSync(folder, { recursive: true, force: true });
    mkdirSync(folder, { recursive: true });
    cpSync(products, join(folder, basename(products)), { recursive: true, verbatimSymlinks: true });
    const platform = join(developerDir(), "Platforms", "iPhoneSimulator.platform", "Developer");
    for (const part of platformParts) cpSync(join(platform, part), join(folder, platformFolder, part), { recursive: true, verbatimSymlinks: true });
    writeFileSync(testRunFile(folder), withBuiltFrameworks(readFileSync(xctestrun, "utf8")));
    writeFileSync(join(folder, "built-with.txt"), `Xcode ${pinnedXcodeVersion()}, iOS Simulator SDK ${sdk}\n`);
}

/// An .xctestrun that loads the test frameworks kept with the built tests
/// rather than the running Xcode's. It throws on any other reference to the
/// running Xcode's platform, which the built tests would not have.
export function withBuiltFrameworks(xctestrun: string): string {
    const changed = xctestrun.replaceAll(runningPlatform, `__TESTROOT__/${platformFolder}`);
    if (changed.includes("__PLATFORMS__")) throw new Error("The .xctestrun names more of the running Xcode than its test frameworks");
    for (const [, path] of changed.matchAll(new RegExp(`__TESTROOT__/${platformFolder}/([^:<]+)`, "g"))) {
        if (!platformParts.some((part) => path === part || path!.startsWith(`${part}/`))) {
            throw new Error(`The .xctestrun loads ${path} from Xcode's simulator platform, which the built tests do not keep`);
        }
    }
    return changed;
}
