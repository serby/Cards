// Builds the app and runs it in one of Paul's test simulators
// (scripts/lib/test-devices.ts): the iPhone 17 unless --device names another,
// such as `se` for the iPhone SE. It finds that simulator on the runtime the
// list gives, and creates it, saying so, when there is none. Then it boots it,
// opens Device Hub to show it (Xcode 27 has no Simulator.app), and installs
// and launches the app. --dry-run only says which simulator it would use, and
// prints its UDID, if it has one, on standard output; it creates, boots and
// builds nothing.
//
// The automated tests' simulator, the iPhone 17 on iOS 26, is in the list too,
// as `tests`, for a look at what they run on; the default stays Paul's iPhone 17
// on iOS 27.
//
// Usage: node scripts/run-in-simulator.ts [--device iphone-17|se|tests] [--dry-run]

import { existsSync } from "node:fs";
import { join } from "node:path";
import { parseArgs } from "node:util";
import { logger, runScript } from "./lib/command-line.ts";
import { createTestSimulator, findTestSimulator } from "./lib/simulator.ts";
import { defaultTestSimulator, describeTestSimulator, testSimulator, testSimulators } from "./lib/test-devices.ts";
import { builtProductsDir, developerDir, projectArgs, run } from "./lib/xcode.ts";

const usage = `Usage: node scripts/run-in-simulator.ts [--device <key>] [--dry-run]

Builds the app and runs it in a test simulator, ${defaultTestSimulator.key} unless --device names another.

Options:
  --device <key>   ${testSimulators.map((simulator) => `${simulator.key}: ${describeTestSimulator(simulator)}`).join("\n                   ")}
  --dry-run        Say which simulator it would use and print its UDID, and create, boot and build nothing`;

const log = logger("run-in-simulator");

function main(argv: string[]): number {
    const { values } = parseArgs({
        args: argv,
        options: {
            device: { type: "string" },
            "dry-run": { type: "boolean", default: false },
            help: { type: "boolean", short: "h", default: false },
        },
    });
    if (values.help) {
        console.log(usage);
        return 0;
    }

    const choice = testSimulator(values.device);
    const pick = findTestSimulator(choice);
    const where = `${pick.name}, iOS ${pick.version}`;
    if (values["dry-run"]) {
        if (pick.udid) {
            log(`Would run on ${where} (${pick.udid})${pick.booted ? ", which is booted" : ""}.`);
            console.log(pick.udid);
        } else {
            log(`Would create a simulator called ${pick.name} on iOS ${pick.version}, as none exists, and run on it.`);
        }
        return 0;
    }

    let udid = pick.udid;
    if (!udid) {
        udid = createTestSimulator(pick);
        log(`Created a simulator called ${pick.name} on iOS ${pick.version} (${udid}), as none existed.`);
    }
    log(`Running on ${where} (${udid}).`);

    const deviceHub = join(developerDir(), "..", "Applications", "DeviceHub.app");
    if (!existsSync(deviceHub)) throw new Error(`Device Hub not found at ${deviceHub}`);
    const destination = `platform=iOS Simulator,id=${udid}`;
    run("xcodebuild", [...projectArgs, "build", "-destination", destination]);
    // -b boots it first if it is not booted yet.
    run("xcrun", ["simctl", "bootstatus", udid, "-b"]);
    run("open", [deviceHub]);

    const app = join(builtProductsDir(destination), "Cards.app");
    if (!existsSync(app)) throw new Error(`No Cards.app in ${app}`);
    run("xcrun", ["simctl", "install", udid, app]);
    run("xcrun", ["simctl", "launch", "--terminate-running-process", udid, "net.serby.Cards"]);
    return 0;
}

if (import.meta.main) runScript("run-in-simulator", main);
