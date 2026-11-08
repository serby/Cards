// The devices the app is tested on, in one place. By hand, Paul uses the
// iPhone 17 simulator, which `make sim` uses unless told otherwise, the iPhone
// SE (3rd generation) simulator for the small screen, and his own iPhone for
// checks on a device: run-in-simulator.ts, run-on-device.ts and
// initialize-cloudkit-schema.ts read them, through lib/simulator.ts and
// lib/phone.ts. The automated tests run on the simulators in testRuns, each on
// a pinned iOS release, so a Mac and CI test the same devices on the same iOS:
// the unit tests on the iPhone 17 on iOS 27.0, and the UI tests on the iPhone 17
// and the iPad mini on iOS 26.5 and the iPhone 16 on iOS 18.5, all built once
// by Xcode 27.1. run-tests.ts runs them, `make test` the unit tests and the
// first UI run, CI every one. `make build` and the rest (select-test-simulator.ts,
// report-test-coverage.ts, capture-l10n.ts) use the first UI run's iPhone 17
// on iOS 26.5, the iOS most people have. The App Store screenshots are the
// exception: capture-screenshots.ts keeps the sizes the store asks for.
//
// It holds names, never UDIDs, which differ from Mac to Mac: the scripts look
// the devices up when they run.
//
// Usage: import { automatedTestSimulator, automatedTestSimulatorWith, defaultTestSimulator, describeTestSimulator, everydayTestRuns, sameName, testPhone, testRun, testRuns, testSimulator, testSimulators } from "./lib/test-devices.ts";

import { UsageError } from "./command-line.ts";

/// A simulator the app is tested on.
export interface TestSimulator {
    /// What `make sim DEVICE=<key>` and run-in-simulator.ts's --device take.
    key: string;
    /// The device type. The simulator used is one of this type named the same,
    /// or the same followed by " (Default)", as Xcode names the ones it makes,
    /// so another project's simulators of the same type are never touched. When
    /// there is none, one is created with this name.
    model: string;
    /// The iOS runtime: a version, such as "27.0", or a major version, such as
    /// "27", for the newest installed 27.x runtime that runs the model and the
    /// SDK can build for.
    os: string;
    /// The iOS a Mac runs it on instead when no `os` runtime is installed, such
    /// as "18" for the newest iOS 18 there: Xcode 27 cannot download iOS 18, so
    /// a Mac keeps the one an older Xcode installed (18.1 on Paul's). CI always
    /// runs on `os`.
    localOs?: string;
    /// What it is for, as the scripts and docs say it.
    purpose: string;
    /// Only a simulator named exactly as the model, never "<model> (Default)",
    /// which Xcode makes and Paul tests on by hand: the test runs install and
    /// launch the app there, so they keep to simulators of their own.
    ownSimulator?: boolean;
    /// The runtime to download from Apple where no `os` runtime is installed,
    /// such as "26.5", on a Mac that lacks it. CI downloads nothing: each run
    /// is on a GitHub image that has its runtime.
    /// It is a version, not a build: xcodebuild says builds such as 23F77 are
    /// "not available for download". Neither Xcode 27 nor Xcode 26.6 offers an
    /// iOS 18 runtime, so the iOS 18 run uses the one GitHub's macos-15 image has.
    download?: string;
}

const iPhone17: TestSimulator = {
    key: "iphone-17",
    model: "iPhone 17",
    os: "27",
    purpose: "the default",
};

const iPhoneSE: TestSimulator = {
    key: "se",
    model: "iPhone SE (3rd generation)",
    os: "27.0",
    purpose: "for the small screen",
};

/// Where the automated tests run, locally and on CI, and what `make build`
/// builds for: iOS 26, the iOS on most devices (TelemetryDeck, 2 November 2026:
/// iOS 26 on 55%, iOS 27 on 36%, iOS 18 on 7%).
const automatedTests: TestSimulator = {
    key: "tests",
    model: "iPhone 17",
    os: "26.5",
    purpose: "for the UI tests and `make build`, on the iOS most people have",
    download: "26.5",
    ownSimulator: true,
};

/// A set of tests and the simulator they run on.
export interface TestRun {
    /// What run-tests.ts's --run and CI's matrix take.
    key: string;
    /// The unit tests (CardsTests) or the UI tests (CardsUITests).
    suite: "unit" | "ui";
    simulator: TestSimulator;
    /// The GitHub runner image CI runs it on.
    image: "xcode-27" | "macos-26" | "macos-15";
    /// The Xcode that runs its tests on CI, where not the one in .xcode-version.
    /// It builds nothing: every run takes the tests the pinned Xcode built once,
    /// which bring that Xcode's XCTest with them (lib/built-tests.ts). The iOS
    /// 18 run needs it, as only GitHub's macos-15 image has an iOS 18 runtime,
    /// which Xcode 27 cannot download, and its newest Xcode is 26.3; the iOS 26
    /// runs too, on the macos-26 image, whose iOS 26.5 comes with Xcode 26.6. A
    /// Mac runs every run with the pinned Xcode.
    ciXcode?: string;
}

/// Every test run, as CI runs them, each on a pinned iOS release. The unit
/// tests are the same everywhere, so they run once, on the newest iOS. The UI
/// tests run where layout and behaviour differ: the iOS most people have, on an
/// iPhone and an iPad, and the oldest iOS the app supports. No iPhone 17 runs
/// iOS 18, so the iOS 18 run uses the iPhone 16, the newest that does.
export const testRuns: readonly TestRun[] = [
    {
        key: "unit",
        suite: "unit",
        // On GitHub's xcode-27 image already, so CI downloads nothing for it.
        simulator: { key: "unit", model: "iPhone 17", os: "27.0", purpose: "for the unit tests, on the newest iOS", download: "27.0", ownSimulator: true },
        image: "xcode-27",
    },
    // On GitHub's macos-26 image, which has iOS 26.5, run by its Xcode 26.6.
    // On the xcode-27 image a downloaded iOS 26.5 never finished booting
    // ("Waiting on Data Migration", 8 November 2026), so no UI test ran.
    { key: "ui-iphone-26", suite: "ui", simulator: automatedTests, image: "macos-26", ciXcode: "26.6" },
    {
        key: "ui-ipad-26",
        suite: "ui",
        simulator: { key: "ui-ipad-26", model: "iPad mini (A17 Pro)", os: "26.5", purpose: "for the UI tests on an iPad", download: "26.5", ownSimulator: true },
        image: "macos-26",
        ciXcode: "26.6",
    },
    {
        key: "ui-iphone-18",
        suite: "ui",
        // On GitHub's macos-15 image, which has iOS 18.5 and 18.6, run by its
        // Xcode 26.3; on Paul's Mac the iOS 18.1 an older Xcode installed.
        simulator: { key: "ui-iphone-18", model: "iPhone 16", os: "18.5", localOs: "18", purpose: "for the UI tests on iOS 18", ownSimulator: true },
        image: "macos-15",
        ciXcode: "26.3",
    },
];

/// The Xcode version a test run uses here: its `ciXcode` on CI (the CI
/// environment variable is set), and otherwise the one in .xcode-version.
export function xcodeVersionFor(run: TestRun, pinned: string, onCI = Boolean(process.env.CI)): string {
    return onCI && run.ciXcode ? run.ciXcode : pinned;
}

/// What `make test` runs: the unit tests, and the UI tests on the iPhone on
/// the iOS most people have. CI and `make test-all` run every one.
export const everydayTestRuns: readonly string[] = ["unit", "ui-iphone-26"];

/// The test run a key names.
export function testRun(key: string): TestRun {
    const found = testRuns.find((run) => run.key === key.trim().toLowerCase());
    if (found) return found;
    throw new UsageError(`No test run called ${key}. The test runs are ${testRuns.map((run) => run.key).join(", ")}`);
}

/// The simulators, the default first.
export const testSimulators: readonly TestSimulator[] = [iPhone17, iPhoneSE, automatedTests];

/// The simulator the automated tests run on, and `make build` builds for.
export const automatedTestSimulator: TestSimulator = automatedTests;

/// The automated tests' simulator with another model or iOS for a one-off run,
/// as the Makefile's SIMULATOR_DEVICE and SIMULATOR_VERSION give them; an
/// empty or missing value keeps the default's. On another iOS there is nothing
/// to download.
export function automatedTestSimulatorWith(overrides: { model?: string; os?: string }): TestSimulator {
    const model = overrides.model?.trim() || automatedTests.model;
    const os = overrides.os?.trim() || automatedTests.os;
    if (model === automatedTests.model && os === automatedTests.os) return automatedTests;
    const { download, ...rest } = automatedTests;
    return { ...rest, key: "one-off", model, os, purpose: "a one-off run", ...(os === automatedTests.os && download ? { download } : {}) };
}

/// The simulator `make sim` uses when no DEVICE is given.
export const defaultTestSimulator: TestSimulator = iPhone17;

/// The phone Paul runs device checks on. The scripts use it when it is
/// connected and otherwise the first connected iPhone.
export const testPhone = {
    /// As devicectl lists it, which spells it with a curly apostrophe; sameName
    /// takes either.
    name: "Paul's iPhone (2)",
    purpose: "Paul's main phone for checks on a device",
} as const;

/// Whether two device names are the same as people read them: straight and
/// curly apostrophes alike, letter case and runs of spaces ignored.
export function sameName(a: string, b: string): boolean {
    return normalisedName(a) === normalisedName(b);
}

function normalisedName(name: string): string {
    return name.replace(/[‘’ʼ]/g, "'").replace(/\s+/g, " ").trim().toLowerCase();
}

/// The simulator in words, such as "iPhone 17 on the newest iOS 27, the default".
export function describeTestSimulator(simulator: TestSimulator): string {
    const os = simulator.os.includes(".") ? `iOS ${simulator.os}` : `the newest iOS ${simulator.os}`;
    return `${simulator.model} on ${os}, ${simulator.purpose}`;
}

/// The test simulator a key or model names, or the default for an empty one.
export function testSimulator(keyOrModel: string | undefined): TestSimulator {
    if (!keyOrModel) return defaultTestSimulator;
    const found = testSimulators.find((simulator) => simulator.key === keyOrModel.trim().toLowerCase() || sameName(simulator.model, keyOrModel));
    if (found) return found;
    const known = testSimulators.map((simulator) => `${simulator.key} (${simulator.model})`).join(", ");
    throw new UsageError(`No test simulator called ${keyOrModel}. The test simulators are ${known}`);
}
