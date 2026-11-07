// The devices Paul tests the app on by hand, in one place: the iPhone 17
// simulator, which `make sim` uses unless told otherwise, the iPhone SE (3rd
// generation) simulator for the small screen, and his own iPhone for checks on
// a device. run-in-simulator.ts and run-on-device.ts read it, through
// lib/simulator.ts and lib/phone.ts.
//
// The automated tests run elsewhere: `make build` and `make test` use the
// Makefile's SIMULATOR_DEVICE on SIMULATOR_VERSION, an older iOS, so they test
// the oldest version the app supports. This list leaves them alone.
//
// It holds names, never UDIDs, which differ from Mac to Mac: the scripts look
// the devices up when they run.
//
// Usage: import { defaultTestSimulator, describeTestSimulator, sameName, testPhone, testSimulator, testSimulators } from "./lib/test-devices.ts";

import { UsageError } from "./command-line.ts";

/// A simulator Paul tests on.
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

/// The simulators, the default first.
export const testSimulators: readonly TestSimulator[] = [iPhone17, iPhoneSE];

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
