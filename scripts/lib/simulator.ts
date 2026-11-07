// Boots an iOS simulator for the unit tests and the screenshots. It picks the
// newest iOS runtime that supports the requested device type and is no newer
// than the selected Xcode's iPhone simulator SDK (a runner can carry runtimes
// from a newer Xcode that this one cannot build for), creates or reuses a
// simulator named CI-<device>-<version>, boots it, sets the status bar and
// waits for it to settle.
//
// It also sets a simulator's own language and region, which is what iOS
// draws outside the app in (the Home Screen, the widget gallery, system
// prompts), and puts them back afterwards.
//
// Usage: import { bootSimulator, setSystemLanguage, systemLanguage } from "./lib/simulator.ts";
//
// Reusing one named simulator per device and runtime means repeat runs skip
// creating it. The wait after `simctl bootstatus` works round a GitHub macOS
// runner issue seen on 2026-06-18: CoreSimulatorService takes 10 to 15 seconds
// after bootstatus returns before xcodebuild can launch tests, and without the
// wait the run logs "Supported platforms ... is empty", sticks launching for
// 150 seconds and is interrupted.

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

    // Booting fails when it is already booted, which is fine.
    await xcrun(["simctl", "boot", udid], log, { output: "log", errors: "discard", mayFail: true });
    await xcrun(["simctl", "bootstatus", udid, "-b"], log, { output: "log" });
    await xcrun(
        ["simctl", "status_bar", udid, "override", "--time", "14:34", "--batteryState", "charged", "--batteryLevel", "100", "--wifiBars", "3", "--cellularBars", "4"],
        log,
        { output: "log" },
    );
    await new Promise((resolve) => setTimeout(resolve, settleSeconds * 1000));
    await xcrun(["simctl", "list", "devices", "booted"], log, { output: "log" });

    return { device, version: pick.version, model: pick.model, udid };
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
