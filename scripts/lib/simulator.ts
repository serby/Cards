// Boots an iOS simulator for the screenshots. It picks the newest iOS runtime
// that supports the requested device type and is no newer than the selected
// Xcode's iPhone simulator SDK (a runner can carry runtimes from a newer Xcode
// that this one cannot build for), creates or reuses a simulator named
// CI-<device>-<version>, boots it, sets the status bar and waits for it to
// settle.
//
// It also finds the simulators in lib/test-devices.ts, the ones Paul tests on
// by hand and the automated tests' one, creating one when it is missing,
// installs the automated tests' iOS runtime where it is missing (as on CI) and
// boots that simulator the same way. And it sets a simulator's own language
// and region, which is what iOS draws outside the app in (the Home Screen, the
// widget gallery, system prompts), and puts them back afterwards.
//
// Usage: import { bootSimulator, bootTestSimulator, createTestSimulator, findOrCreateTestSimulator, findTestSimulator, installTestRuntime, setSystemLanguage, systemLanguage } from "./lib/simulator.ts";
//
// Reusing one named simulator per device and runtime means repeat runs skip
// creating it. The wait after `simctl bootstatus` works round a GitHub macOS
// runner issue seen on 2026-06-18: CoreSimulatorService takes 10 to 15 seconds
// after bootstatus returns before xcodebuild can launch tests, and without the
// wait the run logs "Supported platforms ... is empty", sticks launching for
// 150 seconds and is interrupted.

import { sameName, type TestSimulator } from "./test-devices.ts";
import { capture, run, start } from "./xcode.ts";

/// A booted simulator.
export interface Simulator {
    /// The simulator's name, CI-<model>-<version>.
    device: string;
    /// The iOS runtime's major and minor version, such as "27.0".
    version: string;
    /// The device type's name, such as "iPhone 16 Pro Max".
    model: string;
    udid: string;
}

/// Where the simulator's progress and the simctl output go.
export type Log = (text: string) => void;

interface BootOptions {
    /// Where progress goes. Standard error by default.
    log?: Log;
}

interface DeviceType {
    name: string;
    identifier: string;
}

interface Runtime {
    identifier: string;
    version: string;
    platform: string;
    isAvailable?: boolean;
    supportedDeviceTypes?: DeviceType[];
}

interface Device {
    name: string;
    udid: string;
    isAvailable?: boolean;
    state?: string;
    deviceTypeIdentifier?: string;
}

/// Seconds to wait after the simulator has booted, for CoreSimulatorService to settle.
const settleSeconds = 15;

/// Boots a simulator of the device type named `model`, or of a plain iPhone
/// when no model is given, and returns it once it is ready for tests.
export async function bootSimulator(model?: string, options: BootOptions = {}): Promise<Simulator> {
    const log = options.log ?? ((text: string) => void process.stderr.write(text));

    const sdkVersion = (await xcrun(["--sdk", "iphonesimulator", "--show-sdk-version"], log)).trim();
    const list = JSON.parse(await xcrun(["simctl", "list", "-j", "devicetypes", "runtimes"], log)) as {
        devicetypes: DeviceType[];
        runtimes: Runtime[];
    };
    const pick = pickRuntime(list.devicetypes, list.runtimes, sdkVersion, model);
    log(`Picked: ${pick.model} (iOS ${pick.version}) runtime=${pick.runtime}\n`);

    const device = `CI-${pick.model}-${pick.version}`;
    let udid = await existingSimulator(device, log);
    if (udid) {
        log(`Reusing simulator ${device} (${udid})\n`);
    } else {
        udid = (await xcrun(["simctl", "create", device, pick.model, pick.runtime], log)).trim();
        log(`Created simulator ${device} (${udid})\n`);
    }

    await bootForTests(udid, log);
    return { device, version: pick.version, model: pick.model, udid };
}

/// Boots the automated tests' simulator, or another of lib/test-devices.ts,
/// for tests as bootSimulator does, first installing its iOS runtime where it
/// is missing and it names one to download (installTestRuntime).
export async function bootTestSimulator(choice: TestSimulator, options: BootOptions = {}): Promise<Simulator> {
    const log = options.log ?? ((text: string) => void process.stderr.write(text));
    await installTestRuntime(choice, log);
    const { pick, udid, created } = findOrCreateTestSimulator(choice);
    log(`${created ? "Created" : "Using"} simulator ${pick.name} on iOS ${pick.version} (${udid})\n`);
    await bootForTests(udid, log);
    return { device: pick.name, version: pick.version, model: choice.model, udid };
}

/// Boots a simulator, sets its status bar and waits for it to settle.
async function bootForTests(udid: string, log: Log): Promise<void> {
    // Booting fails when it is already booted, which is fine.
    await xcrun(["simctl", "boot", udid], log, { output: "log", errors: "discard", mayFail: true });
    await xcrun(["simctl", "bootstatus", udid, "-b"], log, { output: "log" });
    // Only for tidier screenshots: on a simulator just created on a freshly
    // installed runtime, as on CI, it can fail, which must not stop the tests.
    await xcrun(
        ["simctl", "status_bar", udid, "override", "--time", "14:34", "--batteryState", "charged", "--batteryLevel", "100", "--wifiBars", "3", "--cellularBars", "4"],
        log,
        { output: "log", mayFail: true },
    );
    await new Promise((resolve) => setTimeout(resolve, settleSeconds * 1000));
    await xcrun(["simctl", "list", "devices", "booted"], log, { output: "log" });
}

interface Pick {
    model: string;
    version: string;
    runtime: string;
}

/// The newest available iOS runtime no newer than the SDK that supports the
/// model, or, with no model, an iPhone: a plain "iPhone <n>" if there is one.
function pickRuntime(deviceTypes: DeviceType[], runtimes: Runtime[], sdkVersion: string, model?: string): Pick {
    const sdk = versionParts(sdkVersion);
    const candidates = runtimes
        .filter((runtime) => runtime.isAvailable && runtime.platform === "iOS" && compareVersions(versionParts(runtime.version).slice(0, sdk.length), sdk) <= 0)
        .sort((a, b) => compareVersions(versionParts(b.version), versionParts(a.version)));

    for (const runtime of candidates) {
        const supported = new Set((runtime.supportedDeviceTypes ?? []).map((type) => type.identifier));
        const types = deviceTypes.filter((type) => supported.has(type.identifier));
        let chosen: DeviceType | undefined;
        if (model) {
            chosen = types.find((type) => type.name === model);
        } else {
            const phones = types.filter((type) => type.name.includes("iPhone"));
            chosen = phones.find((type) => /^iPhone \d+$/.test(type.name)) ?? phones[0];
        }
        if (!chosen) continue;
        return { model: chosen.name, version: runtime.version.split(".").slice(0, 2).join("."), runtime: runtime.identifier };
    }
    throw new Error(`No available iOS runtime supports ${model || "an iPhone"}`);
}

/// The UDID of the available simulator called `name`, if there is one.
async function existingSimulator(name: string, log: Log): Promise<string | undefined> {
    const list = JSON.parse(await xcrun(["simctl", "list", "devices", "-j"], log)) as { devices: Record<string, Device[]> };
    for (const devices of Object.values(list.devices)) {
        const match = devices.find((device) => device.name === name && device.isAvailable);
        if (match) return match.udid;
    }
    return undefined;
}

function versionParts(version: string): number[] {
    return version.split(".").map((part) => Number.parseInt(part, 10));
}

/// Compares versions part by part, a shorter one first when it is a prefix of the other.
function compareVersions(a: number[], b: number[]): number {
    for (let index = 0; index < Math.min(a.length, b.length); index += 1) {
        const difference = (a[index] ?? 0) - (b[index] ?? 0);
        if (difference !== 0) return difference;
    }
    return a.length - b.length;
}

/// One of Paul's test simulators (lib/test-devices.ts) as found on this Mac,
/// or as it would be created.
export interface TestSimulatorPick {
    /// The simulator's name, such as "iPhone 17 (Default)".
    name: string;
    /// The runtime's major and minor version, such as "27.0".
    version: string;
    /// The runtime's identifier, to create it on.
    runtime: string;
    /// The device type's identifier, to create it from.
    deviceType: string;
    /// Its UDID, or undefined when there is none yet and it must be created.
    udid?: string;
    booted: boolean;
}

/// What `simctl list -j devicetypes runtimes devices` prints, in part.
export interface SimulatorList {
    devicetypes: DeviceType[];
    runtimes: Runtime[];
    devices: Record<string, Device[]>;
}

/// Where the test simulator `choice` is in `list`: on the runtime it asks for
/// (the newest that runs its model and that the SDK can build for, when it
/// gives a major version only), or off CI its `localOs` one where that is
/// missing, the available one of its type named as its
/// model, or that followed by " (Default)". A booted one comes first, then the
/// plain name. Another project's simulators, such as "aiw-27 iPhone 17", never
/// match. With none, the pick has no UDID, for createTestSimulator.
export function pickTestSimulator(choice: TestSimulator, list: SimulatorList, sdkVersion: string, onCI = Boolean(process.env.CI)): TestSimulatorPick {
    const type = list.devicetypes.find((deviceType) => deviceType.name === choice.model);
    if (!type) throw new Error(`This Xcode has no ${choice.model} simulator`);

    const runtime = testRuntime(choice, list, sdkVersion, onCI);
    if (!runtime) {
        const command = choice.download ? `, or with xcodebuild -downloadPlatform iOS -buildVersion ${choice.download}` : "";
        throw new Error(`No installed iOS ${choice.os} runtime runs the ${choice.model}. Add one in Xcode > Settings > Components${command}`);
    }
    const version = runtime.version.split(".").slice(0, 2).join(".");

    const defaultName = `${choice.model} (Default)`;
    const rank = (simulator: Device): number => (simulator.state === "Booted" ? 0 : 2) + (sameName(simulator.name, choice.model) ? 0 : 1);
    const found = (list.devices[runtime.identifier] ?? [])
        .filter((simulator) => simulator.isAvailable !== false
            && (simulator.deviceTypeIdentifier ?? type.identifier) === type.identifier
            && (sameName(simulator.name, choice.model) || (!choice.ownSimulator && sameName(simulator.name, defaultName))))
        .sort((a, b) => rank(a) - rank(b))[0];

    const pick = { version, runtime: runtime.identifier, deviceType: type.identifier };
    return found
        ? { ...pick, name: found.name, udid: found.udid, booted: found.state === "Booted" }
        : { ...pick, name: choice.model, booted: false };
}

/// The newest available iOS runtime that `choice` asks for and that runs its
/// model, if one is installed: off CI, its `localOs` one where none is. A major
/// version alone takes none newer than the SDK; a version such as "26.5" is
/// taken as given, as Xcode 26.3 (SDK 26.2) runs iOS 26.5 on CI.
function testRuntime(choice: TestSimulator, list: SimulatorList, sdkVersion: string, onCI = Boolean(process.env.CI)): Runtime | undefined {
    const type = list.devicetypes.find((deviceType) => deviceType.name === choice.model);
    const sdk = versionParts(sdkVersion);
    const newest = (os: string) => {
        const wanted = versionParts(os);
        return list.runtimes
            .filter((candidate) => {
                const version = versionParts(candidate.version);
                return candidate.isAvailable === true
                    && candidate.platform === "iOS"
                    && compareVersions(version.slice(0, wanted.length), wanted) === 0
                    && (wanted.length > 1 || compareVersions(version.slice(0, sdk.length), sdk) <= 0)
                    && (candidate.supportedDeviceTypes ?? []).some((supported) => supported.identifier === type?.identifier);
            })
            .sort((a, b) => compareVersions(versionParts(b.version), versionParts(a.version)))[0];
    };
    return newest(choice.os) ?? (!onCI && choice.localOs ? newest(choice.localOs) : undefined);
}

/// What runs `choice` where its iOS runtime is missing: nothing when one is
/// installed; its download version, such as "26.5", when it names one; and
/// otherwise an error saying to install one.
export function runtimeToInstall(choice: TestSimulator, list: SimulatorList, sdkVersion: string, onCI = Boolean(process.env.CI)): string | undefined {
    if (testRuntime(choice, list, sdkVersion, onCI)) return undefined;
    if (!choice.download) {
        throw new Error(`No installed iOS ${choice.os} runtime runs the ${choice.model}, and it names none to download. Add one in Xcode > Settings > Components`);
    }
    return choice.download;
}

/// Installs the iOS runtime `choice` runs on when none is installed, as on CI,
/// where GitHub's xcode-27 image has only iOS 27: xcodebuild -downloadPlatform
/// downloads its download version from Apple (about 8.5 GB) and installs it.
/// Does nothing when one is there.
export async function installTestRuntime(choice: TestSimulator, log: Log): Promise<void> {
    const list = async (): Promise<{ list: SimulatorList; sdkVersion: string }> => ({
        sdkVersion: (await xcrun(["--sdk", "iphonesimulator", "--show-sdk-version"], log)).trim(),
        list: JSON.parse(await xcrun(["simctl", "list", "-j", "devicetypes", "runtimes", "devices"], log)) as SimulatorList,
    });
    const before = await list();
    const version = runtimeToInstall(choice, before.list, before.sdkVersion);
    if (!version) return;

    log(`No iOS ${choice.os} runtime is installed: downloading iOS ${version} from Apple\n`);
    const started = Date.now();
    // Its progress is a line per update; only the lines that say what it did
    // are kept. Some runtimes, such as iOS 18.6, come only as "universal", so
    // where there is no arm64 one it asks for that.
    const download = async (variant: string, mayFail: boolean): Promise<void> => {
        const printed = await xcrun(["xcodebuild", "-downloadPlatform", "iOS", "-buildVersion", version, "-architectureVariant", variant], log, { mayFail });
        for (const line of printed.split(/[\r\n]+/).filter((text) => text.trim() && !text.includes("%"))) log(`${line.trim()}\n`);
    };
    if (process.arch === "arm64") {
        await download("arm64", true);
        const now = await list();
        if (runtimeToInstall(choice, now.list, now.sdkVersion)) await download("universal", false);
    } else {
        await download("universal", false);
    }

    const after = await list();
    if (runtimeToInstall(choice, after.list, after.sdkVersion)) {
        throw new Error(`xcodebuild downloaded iOS ${version}, but no installed iOS ${choice.os} runtime runs the ${choice.model} yet`);
    }
    log(`Installed iOS ${version} in ${Math.round((Date.now() - started) / 1000)} seconds\n`);
}

/// Finds the test simulator `choice` on this Mac, creating it when there is
/// none, and says whether it did.
export function findOrCreateTestSimulator(choice: TestSimulator): { pick: TestSimulatorPick; udid: string; created: boolean } {
    const pick = findTestSimulator(choice);
    return pick.udid ? { pick, udid: pick.udid, created: false } : { pick, udid: createTestSimulator(pick), created: true };
}

/// Finds the test simulator `choice` on this Mac. It creates nothing: a pick
/// with no UDID goes to createTestSimulator.
export function findTestSimulator(choice: TestSimulator): TestSimulatorPick {
    const sdkVersion = capture("xcrun", ["--sdk", "iphonesimulator", "--show-sdk-version"]).trim();
    const list = JSON.parse(capture("xcrun", ["simctl", "list", "-j", "devicetypes", "runtimes", "devices"])) as SimulatorList;
    return pickTestSimulator(choice, list, sdkVersion);
}

/// Creates the simulator a pick found missing, and returns its UDID.
export function createTestSimulator(pick: TestSimulatorPick): string {
    return capture("xcrun", ["simctl", "create", pick.name, pick.deviceType, pick.runtime]).trim();
}

interface XcrunOptions {
    /// Whether to return what it prints (the default) or send it to the log.
    output?: "return" | "log";
    /// Whether its errors go to the log (the default) or nowhere.
    errors?: "log" | "discard";
    /// Whether to carry on when it fails.
    mayFail?: boolean;
}

/// Runs xcrun with the pinned Xcode without blocking, so the simulator can
/// boot while something else runs, and resolves with what it printed.
function xcrun(args: string[], log: Log, options: XcrunOptions = {}): Promise<string> {
    const { output = "return", errors = "log", mayFail = false } = options;
    return new Promise((resolve, reject) => {
        const child = start("xcrun", args, { stdio: ["ignore", "pipe", "pipe"] });
        let printed = "";
        child.stdout?.setEncoding("utf8").on("data", (text: string) => {
            if (output === "log") log(text);
            else printed += text;
        });
        child.stderr?.setEncoding("utf8").on("data", (text: string) => {
            if (errors === "log") log(text);
        });
        child.on("error", reject);
        // "close", not "exit", so all of its output has been read.
        child.on("close", (code, signal) => {
            if (code === 0 || mayFail) resolve(printed);
            else reject(new Error(`xcrun ${args.join(" ")} failed (${signal ?? `exit code ${code}`})`));
        });
    });
}

/// A simulator's own language and region, as `defaults` holds them in the
/// global domain; undefined where it holds none, as on a new simulator.
export interface SystemLanguage {
    /// AppleLanguages, such as ["de"].
    languages?: string[];
    /// AppleLocale, such as "de_DE".
    locale?: string;
}

/// The simulator's language and region now, to put back afterwards. It must be booted.
export function systemLanguage(udid: string): SystemLanguage {
    const read = (key: string): string | undefined => {
        try {
            return capture("xcrun", ["simctl", "spawn", udid, "defaults", "read", "-g", key]).trim();
        } catch {
            return undefined;
        }
    };
    // defaults prints an array as ( "de", "en" ).
    const languages = read("AppleLanguages")?.match(/"([^"]+)"|([A-Za-z][\w-]*)/g)?.map((item) => item.replaceAll('"', ""));
    return { languages, locale: read("AppleLocale") };
}

/// Sets the simulator's own language and region, then restarts it so
/// SpringBoard takes them, and waits until it has booted again. Undefined
/// values are deleted, as on a new simulator.
export function setSystemLanguage(udid: string, language: SystemLanguage): void {
    const write = (key: string, value: string[] | string | undefined): void => {
        if (value === undefined) {
            try {
                run("xcrun", ["simctl", "spawn", udid, "defaults", "delete", "-g", key], { stdio: "ignore" });
            } catch {
                // It was not set.
            }
        } else if (Array.isArray(value)) {
            run("xcrun", ["simctl", "spawn", udid, "defaults", "write", "-g", key, "-array", ...value]);
        } else {
            run("xcrun", ["simctl", "spawn", udid, "defaults", "write", "-g", key, "-string", value]);
        }
    };
    write("AppleLanguages", language.languages);
    write("AppleLocale", language.locale);
    run("xcrun", ["simctl", "shutdown", udid]);
    run("xcrun", ["simctl", "boot", udid]);
    run("xcrun", ["simctl", "bootstatus", udid, "-b"], { stdio: "ignore" });
}
