// The devices the app is tested on, in one place. By hand, Paul uses the
// iPhone 17 simulator, which `make sim` uses unless told otherwise, the iPhone
// SE (3rd generation) simulator for the small screen, and his own iPhone for
// checks on a device: run-in-simulator.ts, run-on-device.ts and
// initialize-cloudkit-schema.ts read them, through lib/simulator.ts and
// lib/phone.ts. The automated tests and every build for a simulator (`make
// build`, `make test` and the rest through select-test-simulator.ts, CI's
// run-unit-tests.ts, report-test-coverage.ts and capture-l10n.ts) run on one
// more, the iPhone 17 on iOS 26, the iOS most people have, so local runs and
// CI test the same device on the same iOS. The App Store screenshots are the
// exception: capture-screenshots.ts keeps the sizes the store asks for.
//
// It holds names, never UDIDs, which differ from Mac to Mac: the scripts look
// the devices up when they run.
//
// Usage: import { automatedTestSimulator, automatedTestSimulatorWith, defaultTestSimulator, describeTestSimulator, sameName, testPhone, testSimulator, testSimulators } from "./lib/test-devices.ts";

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
    /// "27", for the newest installed 27.x runtime that runs the model.
    os: string;
    /// What it is for, as the scripts and docs say it.
    purpose: string;
    /// The runtime to download from Apple where no `os` runtime is installed,
    /// such as "26.5", as on CI: GitHub's xcode-27 image has only iOS 27.
    /// Keep it the newest release of `os`, which is what a Mac that has
    /// `os` installed runs.
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
    os: "26",
    purpose: "for the automated tests and `make build`, on the iOS most people have",
    download: "26.5",
};

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
