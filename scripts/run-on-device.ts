// Builds the Debug app for a device, then installs and launches it on Paul's
// test phone (scripts/lib/test-devices.ts) when it is connected, or else on the
// first connected iPhone, and says which it chose (scripts/lib/phone.ts).
// Signing uses the paid team and automatic provisioning, so Xcode registers the
// phone and creates the development profile if it must (docs/DEVELOPMENT.md,
// "Signing, teams and iCloud"). --dry-run only says which phone it would use.
//
// Usage: node scripts/run-on-device.ts [--dry-run]

import { parseArgs } from "node:util";
import { logger, runScript } from "./lib/command-line.ts";
import { buildForPhone, choosePhone, describePhoneChoice, installOnPhone, launchOnPhone } from "./lib/phone.ts";
import { testPhone } from "./lib/test-devices.ts";

const usage = `Usage: node scripts/run-on-device.ts [--dry-run]

Builds the Debug app and runs it on ${testPhone.name} when it is connected, or else on the first connected iPhone.

Options:
  --dry-run   Say which phone it would use, and build and install nothing`;

const log = logger("run-on-device");

function main(argv: string[]): number {
    const { values } = parseArgs({
        args: argv,
        options: {
            "dry-run": { type: "boolean", default: false },
            help: { type: "boolean", short: "h", default: false },
        },
    });
    if (values.help) {
        console.log(usage);
        return 0;
    }

    // Before the build, so a missing phone fails at once.
    const phone = choosePhone();
    if (!phone) throw new Error(`No iPhone connected. Connect ${testPhone.name}, or another iPhone, and unlock it`);
    log(describePhoneChoice(phone));
    if (values["dry-run"]) return 0;

    const app = buildForPhone();
    installOnPhone(phone, app);
    launchOnPhone(phone);
    return 0;
}

if (import.meta.main) runScript("run-on-device", main);
