// Prints the xcodebuild destination of the simulator the automated tests run
// on and `make build` builds for (lib/test-devices.ts), the iPhone 17 on the
// newest installed iOS 26, as `platform=iOS Simulator,id=<UDID>`. The Makefile
// uses it, and run-tests.ts the same simulator for the UI tests' main run, so local runs and CI
// test the same device on the same iOS. It creates the simulator when there is
// none, saying so on standard error, and fails, saying how to install it, when
// no iOS 26 runtime is installed. --model and --os pick another for a one-off
// run (the Makefile's SIMULATOR_DEVICE and SIMULATOR_VERSION); an empty value
// keeps the default's.
//
// Usage: node scripts/select-test-simulator.ts [--model <device type>] [--os <version>]

import { parseArgs } from "node:util";
import { logger, runScript } from "./lib/command-line.ts";
import { findOrCreateTestSimulator } from "./lib/simulator.ts";
import { automatedTestSimulatorWith, describeTestSimulator } from "./lib/test-devices.ts";

const usage = `Usage: node scripts/select-test-simulator.ts [--model <device type>] [--os <version>]

Prints the xcodebuild destination of the ${describeTestSimulator(automatedTestSimulatorWith({}))}.

Options:
  --model <device type>  Another device type for a one-off run, such as "iPhone 17 Pro"
  --os <version>         Another iOS for a one-off run: a version, such as "27.0", or a major version, such as "27"`;

const log = logger("select-test-simulator");

function main(argv: string[]): number {
    const { values } = parseArgs({
        args: argv,
        options: {
            model: { type: "string" },
            os: { type: "string" },
            help: { type: "boolean", short: "h", default: false },
        },
    });
    if (values.help) {
        console.log(usage);
        return 0;
    }

    const { pick, udid, created } = findOrCreateTestSimulator(automatedTestSimulatorWith({ model: values.model, os: values.os }));
    if (created) log(`Created a simulator called ${pick.name} on iOS ${pick.version} (${udid}), as none existed.`);
    console.log(`platform=iOS Simulator,id=${udid}`);
    return 0;
}

if (import.meta.main) runScript("select-test-simulator", main);
