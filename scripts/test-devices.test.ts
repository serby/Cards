// Tests for the test devices list (scripts/lib/test-devices.ts) and how
// scripts/lib/simulator.ts and scripts/lib/phone.ts find them. Run with:
// node --test scripts/test-devices.test.ts

import assert from "node:assert/strict";
import { describe, test } from "node:test";

import { type ListedDevice, pickPhone } from "./lib/phone.ts";
import { pickTestSimulator, runtimeToInstall, type SimulatorList } from "./lib/simulator.ts";
import { automatedTestSimulator, automatedTestSimulatorWith, ciTestRuns, defaultTestSimulator, sameName, testSimulator, everydayTestRuns, testRun, testRuns, xcodeVersionFor } from "./lib/test-devices.ts";

const iPhone17Type = { name: "iPhone 17", identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-17" };
const seType = { name: "iPhone SE (3rd generation)", identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation" };
const duoType = { name: "iPhone Duo", identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-Duo" };
const iPhone16Type = { name: "iPhone 16", identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16" };

function runtime(version: string, types: { name: string; identifier: string }[]) {
    return {
        identifier: `com.apple.CoreSimulator.SimRuntime.iOS-${version.replaceAll(".", "-")}`,
        version,
        platform: "iOS",
        isAvailable: true,
        supportedDeviceTypes: types,
    };
}

function simulator(name: string, udid: string, type: { identifier: string }, state = "Shutdown") {
    return { name, udid, state, isAvailable: true, deviceTypeIdentifier: type.identifier };
}

/// This Mac on 2026-11-07, in part: iOS 27.1 runs only the iPhone Duo, and
/// other projects keep their own iPhone 17 simulators.
function thisMac(): SimulatorList {
    return {
        devicetypes: [iPhone17Type, seType, duoType],
        runtimes: [runtime("18.1", [seType]), runtime("26.5", [iPhone17Type, seType]), runtime("27.0", [iPhone17Type, seType]), runtime("27.1", [duoType])],
        devices: {
            "com.apple.CoreSimulator.SimRuntime.iOS-26-5": [simulator("iPhone 17", "OLD-17", iPhone17Type)],
            "com.apple.CoreSimulator.SimRuntime.iOS-27-0": [
                simulator("aiw-27 iPhone 17", "AIW-17", iPhone17Type),
                simulator("aiw-26 iPhone 17 (2)", "AIW-17-2", iPhone17Type, "Booted"),
                simulator("iPhone 17 (Default)", "DEFAULT-17", iPhone17Type),
                simulator("iPhone SE (3rd generation)", "SE", seType, "Booted"),
            ],
            "com.apple.CoreSimulator.SimRuntime.iOS-27-1": [simulator("iPhone Duo", "DUO", duoType)],
        },
    };
}

describe("device names", () => {
    test("match with straight or curly apostrophes, in any case and spacing", () => {
        assert.ok(sameName("Paul’s iPhone (2)", "Paul's iPhone (2)"));
        assert.ok(sameName("paul's  iphone (2) ", "Paul’s iPhone (2)"));
        assert.ok(!sameName("Paul’s iPhone", "Paul's iPhone (2)"));
    });
});

describe("test simulators", () => {
    test("default to the iPhone 17, and are found by key or model", () => {
        assert.equal(testSimulator(undefined), defaultTestSimulator);
        assert.equal(testSimulator("").model, "iPhone 17");
        assert.equal(testSimulator("se").model, "iPhone SE (3rd generation)");
        assert.equal(testSimulator("iPhone SE (3rd generation)").key, "se");
        assert.throws(() => testSimulator("ipad"), /se \(iPhone SE \(3rd generation\)\)/);
    });

    test("use the iPhone 17 (Default) on the newest iOS 27 that runs it, never another project's", () => {
        const pick = pickTestSimulator(testSimulator("iphone-17"), thisMac(), "27.1");
        assert.deepEqual(pick, {
            name: "iPhone 17 (Default)",
            udid: "DEFAULT-17",
            version: "27.0",
            runtime: "com.apple.CoreSimulator.SimRuntime.iOS-27-0",
            deviceType: iPhone17Type.identifier,
            booted: false,
        });
    });

    test("prefer a booted one, then the plain name", () => {
        const list = thisMac();
        list.devices["com.apple.CoreSimulator.SimRuntime.iOS-27-0"]?.push(simulator("iPhone 17", "PLAIN-17", iPhone17Type));
        assert.equal(pickTestSimulator(defaultTestSimulator, list, "27.1").udid, "PLAIN-17");
        list.devices["com.apple.CoreSimulator.SimRuntime.iOS-27-0"]?.push(simulator("iPhone 17 (Default)", "BOOTED-17", iPhone17Type, "Booted"));
        assert.equal(pickTestSimulator(defaultTestSimulator, list, "27.1").udid, "BOOTED-17");
    });

    test("move to a newer iOS 27 runtime once one runs the model, creating the simulator there", () => {
        const list = thisMac();
        list.runtimes.push(runtime("27.2", [iPhone17Type, seType]));
        const pick = pickTestSimulator(defaultTestSimulator, list, "27.2");
        assert.equal(pick.udid, undefined);
        assert.equal(pick.name, "iPhone 17");
        assert.equal(pick.version, "27.2");
        assert.equal(pick.runtime, "com.apple.CoreSimulator.SimRuntime.iOS-27-2");
    });

    test("never pick a runtime newer than the SDK for a major version", () => {
        const list = thisMac();
        list.runtimes.push(runtime("27.2", [iPhone17Type]));
        assert.equal(pickTestSimulator(defaultTestSimulator, list, "27.1").version, "27.0");
    });

    test("keep the SE on iOS 27.0", () => {
        const list = thisMac();
        list.runtimes.push(runtime("27.2", [iPhone17Type, seType]));
        const pick = pickTestSimulator(testSimulator("se"), list, "27.2");
        assert.equal(pick.udid, "SE");
        assert.equal(pick.version, "27.0");
        assert.equal(pick.booted, true);
    });

    test("say what to install when no runtime runs the model", () => {
        const list = thisMac();
        list.runtimes = list.runtimes.filter((candidate) => candidate.version !== "27.0");
        assert.throws(() => pickTestSimulator(defaultTestSimulator, list, "27.1"), /No installed iOS 27 runtime runs the iPhone 17/);
    });
});

describe("the automated tests' simulator", () => {
    test("is the iPhone 17 on the newest iOS 26, apart from Paul's on iOS 27", () => {
        assert.equal(testSimulator("tests"), automatedTestSimulator);
        const pick = pickTestSimulator(automatedTestSimulator, thisMac(), "27.1");
        assert.equal(pick.udid, "OLD-17");
        assert.equal(pick.version, "26.5");
        assert.notEqual(pick.udid, pickTestSimulator(defaultTestSimulator, thisMac(), "27.1").udid);
    });

    test("is created on iOS 26 when there is none there", () => {
        const list = thisMac();
        list.devices["com.apple.CoreSimulator.SimRuntime.iOS-26-5"] = [];
        const pick = pickTestSimulator(automatedTestSimulator, list, "27.1");
        assert.equal(pick.udid, undefined);
        assert.equal(pick.name, "iPhone 17");
        assert.equal(pick.runtime, "com.apple.CoreSimulator.SimRuntime.iOS-26-5");
    });

    test("downloads its runtime only where no iOS 26 one is installed, as on CI", () => {
        assert.equal(runtimeToInstall(automatedTestSimulator, thisMac(), "27.1"), undefined);
        const ci = thisMac();
        ci.runtimes = ci.runtimes.filter((candidate) => !candidate.version.startsWith("26."));
        assert.equal(runtimeToInstall(automatedTestSimulator, ci, "27.1"), "26.5");
        assert.throws(() => pickTestSimulator(automatedTestSimulator, ci, "27.1"), /xcodebuild -downloadPlatform iOS -buildVersion 26\.5/);
    });

    test("says what to add when a one-off iOS is missing, as it has nothing to download", () => {
        const choice = automatedTestSimulatorWith({ os: "25" });
        assert.equal(choice.download, undefined);
        assert.throws(() => runtimeToInstall(choice, thisMac(), "27.1"), /No installed iOS 25 runtime runs the iPhone 17/);
    });

    test("takes another model or iOS for a one-off run, and keeps its own for empty values", () => {
        assert.equal(automatedTestSimulatorWith({}), automatedTestSimulator);
        assert.equal(automatedTestSimulatorWith({ model: " ", os: "" }), automatedTestSimulator);
        const pro = automatedTestSimulatorWith({ model: "iPhone 17 Pro" });
        assert.equal(pro.model, "iPhone 17 Pro");
        assert.equal(pro.os, "26.5");
        assert.equal(pro.download, automatedTestSimulator.download);
        const newer = automatedTestSimulatorWith({ os: "27" });
        assert.equal(newer.model, "iPhone 17");
        // Never the (Default) one Paul tests on by hand: a one-off gets its own.
        assert.equal(pickTestSimulator(newer, thisMac(), "27.1").udid, undefined);
    });
});

function device(name: string, options: { reality?: string; deviceType?: string; state?: string; pairing?: string } = {}): ListedDevice {
    return {
        identifier: `ID-${name}`,
        properties: {
            connection: { pairingState: options.pairing ?? "paired", state: options.state ?? "disconnected" },
            hardware: { deviceType: options.deviceType ?? "iPhone", marketingName: "iPhone 17 Pro", reality: options.reality ?? "physical" },
            state: { name },
        },
    };
}

describe("the phone", () => {
    test("is the test phone when it is reachable, whichever apostrophe it has", () => {
        const devices = [device("Sam’s iPhone"), device("Paul’s iPhone (2)")];
        const phone = pickPhone(devices, "Paul's iPhone (2)");
        assert.equal(phone?.name, "Paul’s iPhone (2)");
        assert.equal(phone?.isTestPhone, true);
    });

    test("is otherwise the first reachable iPhone", () => {
        const devices = [
            device("iPhone 17 (Default)", { reality: "simulated", state: "connected" }),
            device("Paul’s iPad (2)", { deviceType: "iPad" }),
            device("Paul’s iPhone", { state: "unavailable" }),
            device("Paul’s iPhone (2)", { pairing: "unpaired" }),
            device("Sam’s iPhone", { state: "connected" }),
        ];
        const phone = pickPhone(devices, "Paul's iPhone (2)");
        assert.equal(phone?.name, "Sam’s iPhone");
        assert.equal(phone?.isTestPhone, false);
    });

    test("is missing when no iPhone is reachable", () => {
        assert.equal(pickPhone([device("Paul’s iPhone (2)", { state: "unavailable" })], "Paul's iPhone (2)"), undefined);
    });
});

describe("the test runs", () => {
    test("are named once each, and `make test` runs two of them", () => {
        const keys = testRuns.map((run) => run.key);
        assert.equal(new Set(keys).size, keys.length);
        assert.deepEqual([...everydayTestRuns], ["unit", "ui-iphone-26"]);
        for (const key of everydayTestRuns) assert.equal(testRun(key).key, key);
    });

    test("run the unit tests on the newest iOS and the UI tests on iOS 26, an iPad and iOS 18", () => {
        const described = testRuns.map((run) => `${run.suite} ${run.simulator.model} ${run.simulator.os} ${run.image} ${xcodeVersionFor(run, "27.1", true)}`);
        assert.deepEqual(described, [
            "unit iPhone 17 27.0 xcode-27 27.1",
            "ui iPhone 17 26.5 macos-26 26.6",
            "ui iPad mini (A17 Pro) 26.5 macos-26 26.6",
            "ui iPhone 16 18.5 macos-15 26.3",
        ]);
    });

    test("run each iOS on an image that has it, so CI downloads nothing, and never iOS 18", () => {
        assert.deepEqual(testRuns.map((run) => `${run.simulator.os} ${run.image}`), ["27.0 xcode-27", "26.5 macos-26", "26.5 macos-26", "18.5 macos-15"]);
        assert.equal(testRun("ui-iphone-18").simulator.download, undefined);
    });

    test("leave the iPad out of CI, which runs every other", () => {
        assert.deepEqual(ciTestRuns.map((run) => run.key), ["unit", "ui-iphone-26", "ui-iphone-18"]);
    });

    test("use the pinned Xcode off CI", () => {
        for (const run of testRuns) assert.equal(xcodeVersionFor(run, "27.1", false), "27.1");
    });

    test("says which runs there are for an unknown one", () => {
        assert.throws(() => testRun("ui-watch"), /The test runs are unit, ui-iphone-26, ui-ipad-26, ui-iphone-18/);
    });
});

describe("the iOS 18 run", () => {
    function ciImage(): SimulatorList {
        return {
            devicetypes: [iPhone16Type],
            runtimes: [runtime("18.5", [iPhone16Type]), runtime("18.6", [iPhone16Type])],
            devices: { "com.apple.CoreSimulator.SimRuntime.iOS-18-5": [simulator("iPhone 16", "CI-16", iPhone16Type)] },
        };
    }

    test("runs on iOS 18.5 on CI, though the image has 18.6 too", () => {
        const pick = pickTestSimulator(testRun("ui-iphone-18").simulator, ciImage(), "26.2", true);
        assert.equal(pick.version, "18.5");
        assert.equal(pick.udid, "CI-16");
    });

    test("runs on the newest iOS 18 a Mac has, and on CI fails without 18.5", () => {
        const mac: SimulatorList = { devicetypes: [iPhone16Type], runtimes: [runtime("18.1", [iPhone16Type])], devices: {} };
        assert.equal(pickTestSimulator(testRun("ui-iphone-18").simulator, mac, "27.1", false).version, "18.1");
        assert.throws(() => pickTestSimulator(testRun("ui-iphone-18").simulator, mac, "27.1", true), /No installed iOS 18\.5 runtime runs the iPhone 16/);
    });
});

describe("the test runs' simulators", () => {
    test("are their own, never the (Default) one Paul tests on by hand", () => {
        for (const run of testRuns) assert.equal(run.simulator.ownSimulator, true, run.key);
    });
});
