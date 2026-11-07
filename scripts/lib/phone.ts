// Chooses the iPhone to run the app on, and builds, installs and launches the
// app there through devicectl. The phone is Paul's test phone
// (lib/test-devices.ts) when it is connected, otherwise the first connected
// iPhone. Builds are Debug, signed with the paid team and automatic
// provisioning, so Xcode registers the phone and creates the development
// profile if it must (docs/DEVELOPMENT.md, section 7). The phone must be
// unlocked for the app to launch.
//
// Usage: import { buildForPhone, choosePhone, describePhoneChoice, installOnPhone, launchOnPhone } from "./lib/phone.ts";

import { existsSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { sameName, testPhone } from "./test-devices.ts";
import { builtProductsDir, projectArgs, run } from "./xcode.ts";

const bundleIdentifier = "net.serby.Cards";

/// A physical iPhone devicectl can reach.
export interface Phone {
    /// devicectl's identifier for it, for --device.
    identifier: string;
    /// Its name, such as "Paul’s iPhone (2)".
    name: string;
    /// Its model, such as "iPhone 17 Pro".
    model: string;
    /// Whether it is the test phone in lib/test-devices.ts.
    isTestPhone: boolean;
}

/// A device as `devicectl list devices --json-output` lists it, in part.
export interface ListedDevice {
    identifier: string;
    properties?: {
        connection?: { pairingState?: string; state?: string };
        hardware?: { deviceType?: string; marketingName?: string; reality?: string };
        state?: { name?: string };
    };
}

/// The phone to use from devicectl's list: the one named `testPhoneName` when
/// it is reachable, else the first reachable iPhone. Reachable means physical,
/// paired and not "unavailable": a phone devicectl can see but has no tunnel to
/// yet is "disconnected" (its table says "available"), and devicectl opens the
/// tunnel when a command needs it. The simulators it also lists are left out.
export function pickPhone(devices: readonly ListedDevice[], testPhoneName: string = testPhone.name): Phone | undefined {
    const phones = devices
        .filter((device) => {
            const { connection, hardware } = device.properties ?? {};
            return hardware?.reality === "physical"
                && hardware.deviceType === "iPhone"
                && connection?.pairingState === "paired"
                && connection.state !== undefined
                && connection.state !== "unavailable";
        })
        .map((device): Phone => {
            const name = device.properties?.state?.name ?? device.identifier;
            return {
                identifier: device.identifier,
                name,
                model: device.properties?.hardware?.marketingName ?? "iPhone",
                isTestPhone: sameName(name, testPhoneName),
            };
        });
    return phones.find((phone) => phone.isTestPhone) ?? phones[0];
}

/// The phone to use now, from devicectl's list (pickPhone).
export function choosePhone(): Phone | undefined {
    const directory = mkdtempSync(join(tmpdir(), "cards-devices-"));
    try {
        const output = join(directory, "devices.json");
        run("xcrun", ["devicectl", "list", "devices", "--json-output", output], { stdio: "ignore" });
        const devices = (JSON.parse(readFileSync(output, "utf8")) as { result: { devices: ListedDevice[] } }).result.devices;
        return pickPhone(devices);
    } finally {
        rmSync(directory, { recursive: true, force: true });
    }
}

/// Says which phone was chosen, and why.
export function describePhoneChoice(phone: Phone): string {
    return phone.isTestPhone
        ? `Using ${phone.name} (${phone.model}), the test phone.`
        : `${testPhone.name} is not connected, so using ${phone.name} (${phone.model}), the first connected iPhone.`;
}

const destination = "generic/platform=iOS";
const debug = ["-configuration", "Debug"];

/// Builds the Debug app for a device and returns the path to its Cards.app.
export function buildForPhone(): string {
    run("xcodebuild", [...projectArgs, ...debug, "build", "-destination", destination, "-allowProvisioningUpdates"]);
    const app = join(builtProductsDir(destination, debug), "Cards.app");
    if (!existsSync(app)) throw new Error(`No Cards.app in ${app}`);
    return app;
}

/// Installs `app` on the phone, over any copy already there.
export function installOnPhone(phone: Phone, app: string): void {
    run("xcrun", ["devicectl", "device", "install", "app", "--device", phone.identifier, app]);
}

/// Launches the app on the phone and returns once it has started.
export function launchOnPhone(phone: Phone): void {
    run("xcrun", ["devicectl", "device", "process", "launch", "--device", phone.identifier, bundleIdentifier]);
}
