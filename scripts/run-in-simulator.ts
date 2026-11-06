// Builds the app, boots a simulator, opens Device Hub to show it, then installs
// and launches the app there. Xcode 27 has no Simulator.app; Device Hub shows
// the simulator's screen.
//
// Usage: node scripts/run-in-simulator.ts [--device "iPhone 16 Pro"] [--os 18.1]

import { existsSync } from "node:fs";
import { join } from "node:path";
import { parseArgs } from "node:util";
import { builtProductsDir, capture, developerDir, projectArgs, run } from "./lib/xcode.ts";

const { values } = parseArgs({
    options: {
        device: { type: "string", default: "iPhone 16 Pro" },
        os: { type: "string", default: "18.1" },
    },
});
const device = values.device;
const os = values.os;
const destination = `platform=iOS Simulator,name=${device},OS=${os}`;

interface Simulator {
    udid: string;
    name: string;
    state: string;
    isAvailable: boolean;
}

/// The simulator to use: one named `device` on iOS `os`, a booted one first.
function findSimulator(): Simulator | undefined {
    const list = JSON.parse(capture("xcrun", ["simctl", "list", "devices", "available", "-j"])) as { devices: Record<string, Simulator[]> };
    const runtime = `iOS-${os.replaceAll(".", "-")}`;
    const matches = Object.entries(list.devices)
        .filter(([identifier]) => identifier.endsWith(runtime))
        .flatMap(([, simulators]) => simulators)
        .filter((simulator) => simulator.isAvailable && simulator.name === device);
    return matches.find((simulator) => simulator.state === "Booted") ?? matches[0];
}

try {
    const simulator = findSimulator();
    if (!simulator) throw new Error(`No ${device} simulator on iOS ${os} available`);
    const deviceHub = join(developerDir(), "..", "Applications", "DeviceHub.app");
    if (!existsSync(deviceHub)) throw new Error(`Device Hub not found at ${deviceHub}`);

    run("xcodebuild", [...projectArgs, "build", "-destination", destination]);
    try {
        run("xcrun", ["simctl", "boot", simulator.udid], { stdio: "ignore" });
    } catch {
        // Already booted.
    }
    run("xcrun", ["simctl", "bootstatus", simulator.udid, "-b"]);
    run("open", [deviceHub]);

    const app = join(builtProductsDir(destination), "Cards.app");
    if (!existsSync(app)) throw new Error(`No Cards.app in ${app}`);
    run("xcrun", ["simctl", "install", simulator.udid, app]);
    run("xcrun", ["simctl", "launch", "--terminate-running-process", simulator.udid, "net.serby.Cards"]);
} catch (error) {
    console.error(`error: ${error instanceof Error ? error.message : String(error)}`);
    process.exit(1);
}
