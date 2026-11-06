// Builds the app for a device, then installs and launches it on the first
// connected iPhone. Signing uses the paid team and automatic provisioning, so
// Xcode registers the phone and creates the development profile if it must
// (docs/DEVELOPMENT.md, "Signing, teams and iCloud").
//
// Usage: node scripts/run-on-device.ts

import { existsSync, mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { builtProductsDir, projectArgs, run } from "./lib/xcode.ts";

const destination = "generic/platform=iOS";

interface Device {
    identifier: string;
    hardwareProperties?: { marketingName?: string; reality?: string };
    connectionProperties?: { tunnelState?: string };
}

/// The first physical iPhone that is connected now. devicectl lists booted
/// simulators as connected too, so they are left out.
function connectedIPhone(): Device | undefined {
    const output = join(mkdtempSync(join(tmpdir(), "cards-devices-")), "devices.json");
    run("xcrun", ["devicectl", "list", "devices", "--json-output", output], { stdio: "ignore" });
    const devices = (JSON.parse(readFileSync(output, "utf8")) as { result: { devices: Device[] } }).result.devices;
    return devices.find((device) =>
        device.hardwareProperties?.reality === "physical"
        && (device.hardwareProperties.marketingName ?? "").includes("iPhone")
        && device.connectionProperties?.tunnelState === "connected");
}

try {
    // Before the build, so a missing phone fails at once.
    const phone = connectedIPhone();
    if (!phone) throw new Error("No iPhone connected");
    run("xcodebuild", [...projectArgs, "build", "-destination", destination, "-allowProvisioningUpdates"]);
    const app = join(builtProductsDir(destination), "Cards.app");
    if (!existsSync(app)) throw new Error(`No Cards.app in ${app}`);
    run("xcrun", ["devicectl", "device", "install", "app", "--device", phone.identifier, app]);
    run("xcrun", ["devicectl", "device", "process", "launch", "--device", phone.identifier, "net.serby.Cards"]);
} catch (error) {
    console.error(`error: ${error instanceof Error ? error.message : String(error)}`);
    process.exit(1);
}
