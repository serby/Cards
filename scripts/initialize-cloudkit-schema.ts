// Creates the app's CloudKit schema in the Development environment from a
// phone, before a version that adds stored fields ships (docs/DEVELOPMENT.md,
// section 8). It builds the Debug app, installs it on Paul's test phone, or the
// first connected iPhone, as run-on-device.ts chooses (scripts/lib/phone.ts),
// and launches it with -initializeCloudKitSchema (Cards/App/DevelopmentHooks.swift).
// It watches the app's log for the hook's result, closes the app, keeps the
// whole log in build/initialize-cloudkit-schema.log, and says what to do next
// in the CloudKit Console.
//
// Debug builds only reach the Development environment, so it never changes
// Production: deploying the schema there is Paul's step in the CloudKit
// Console. The phone must be unlocked and signed in to iCloud.
//
// Usage: node scripts/initialize-cloudkit-schema.ts [--timeout <seconds>]

import type { ChildProcess } from "node:child_process";
import { createWriteStream, mkdirSync } from "node:fs";
import { join } from "node:path";
import { parseArgs } from "node:util";
import { logger, positiveInteger, runScript } from "./lib/command-line.ts";
import { buildForPhone, choosePhone, describePhoneChoice, installOnPhone, type Phone, startOnPhoneWithConsole } from "./lib/phone.ts";
import { testPhone } from "./lib/test-devices.ts";
import { root } from "./lib/xcode.ts";

const usage = `Usage: node scripts/initialize-cloudkit-schema.ts [--timeout <seconds>]

Builds the Debug app, installs it on ${testPhone.name} (or the first connected iPhone) and launches it with -initializeCloudKitSchema, which creates the CloudKit schema in the Development environment. Then it says how to check the schema and deploy it to Production in the CloudKit Console.

Options:
  --timeout <seconds>   How long to wait for the app to report the result (default: 180)`;

/// What the hook logs (Cards/Development/CloudKitSchema.swift and
/// Cards/App/DevelopmentHooks.swift, Logger category CloudKitSchema).
const succeeded = "CloudKit schema initialised in the Development environment";
const failed = "CloudKit schema initialisation failed";

const logFile = join(root, "build", "initialize-cloudkit-schema.log");
const log = logger("initialize-cloudkit-schema");

const nextSteps = `The CloudKit schema is in the Development environment. Next, in the CloudKit Console:

1. Open https://icloud.developer.apple.com/dashboard/, choose iCloud.net.serby.Cards and the Development environment.
2. Under Schema > Record Types, open CD_CardItem and check it has a CD_<name> field for every stored property of CardItem (Cards/Core/Models/CardItem.swift), including those added since the last release.
3. Choose Deploy Schema Changes, check the changes it lists, and deploy them to Production.

Do this before the version that needs them goes to TestFlight or the App Store.`;

/// How the launch ended.
interface Result {
    outcome: "succeeded" | "failed" | "exited" | "timed out";
    /// The line that gave the result, if one did.
    line?: string;
    /// The last lines devicectl and the app printed.
    tail: string[];
}

async function main(argv: string[]): Promise<number> {
    const { values } = parseArgs({
        args: argv,
        options: {
            timeout: { type: "string" },
            help: { type: "boolean", short: "h", default: false },
        },
    });
    if (values.help) {
        console.log(usage);
        return 0;
    }
    const timeout = positiveInteger(values.timeout, 180, "--timeout");

    // Before the build, so a missing phone fails at once.
    const phone = choosePhone();
    if (!phone) throw new Error(`No iPhone connected. Connect ${testPhone.name}, or another iPhone, unlock it and run this again`);
    log(describePhoneChoice(phone));

    const app = buildForPhone();
    installOnPhone(phone, app);
    log(`Launching it with -initializeCloudKitSchema, and waiting up to ${timeout} seconds for the result. Keep ${phone.name} unlocked.`);
    const result = await launchAndWatch(phone, timeout);
    log(`The whole log is in ${logFile}.`);

    switch (result.outcome) {
        case "succeeded":
            log(`${phone.name} reported: ${succeeded}.`);
            console.log(nextSteps);
            return 0;
        case "failed":
            log(`${phone.name} reported: ${result.line ?? failed}`);
            log("Check the phone is signed in to iCloud with iCloud Drive on, then run this again. The schema is unchanged.");
            return 1;
        case "exited":
            printTail(result.tail);
            if (result.tail.some((line) => /locked|unlock/i.test(line))) {
                log(`${phone.name} is locked. Unlock it, keep it unlocked, and run this again.`);
            } else {
                log("The app stopped before it reported a result. The lines above say why.");
            }
            return 1;
        case "timed out":
            printTail(result.tail);
            log(`No result after ${timeout} seconds, so the app was closed. Check ${phone.name} is unlocked and online, then run this again, with a longer --timeout if CloudKit is slow.`);
            return 1;
    }
}

/// Launches the app with -initializeCloudKitSchema and resolves once it has
/// reported the result, or stopped, or `timeout` seconds have passed. It
/// closes the app once it knows, since devicectl --console waits for the app
/// to exit and passes a SIGINT on to it.
function launchAndWatch(phone: Phone, timeout: number): Promise<Result> {
    mkdirSync(join(root, "build"), { recursive: true });
    const file = createWriteStream(logFile);
    const child = startOnPhoneWithConsole(phone, ["-initializeCloudKitSchema"]);
    const tail: string[] = [];

    return new Promise((resolve, reject) => {
        let result: Result | undefined;
        const settle = (outcome: Result["outcome"], line?: string): void => {
            if (result) return;
            result = { outcome, line, tail };
            if (outcome !== "exited") close(child);
        };
        const timer = setTimeout(() => settle("timed out"), timeout * 1000);

        const read = (stream: NodeJS.ReadableStream | null): void => {
            let partial = "";
            stream?.setEncoding("utf8");
            stream?.on("data", (text: string) => {
                file.write(text);
                const lines = (partial + text).split("\n");
                partial = lines.pop() ?? "";
                for (const line of lines) {
                    tail.push(line);
                    if (tail.length > 40) tail.shift();
                    if (/CloudKit ?Schema/i.test(line)) log(`  ${line.trim()}`);
                    if (line.includes(succeeded)) settle("succeeded", line.trim());
                    else if (line.includes(failed)) settle("failed", line.trim());
                }
            });
        };
        read(child.stdout);
        read(child.stderr);

        child.on("error", (error) => {
            clearTimeout(timer);
            file.end();
            reject(error);
        });
        // "close", not "exit", so all of its output has been read.
        child.on("close", () => {
            clearTimeout(timer);
            settle("exited");
            file.end(() => resolve(result ?? { outcome: "exited", tail }));
        });
    });
}

/// Closes the app through devicectl, and devicectl itself if it lingers.
function close(child: ChildProcess): void {
    child.kill("SIGINT");
    setTimeout(() => {
        if (child.exitCode === null && child.signalCode === null) child.kill("SIGKILL");
    }, 15_000).unref();
}

function printTail(tail: string[]): void {
    const lines = tail.filter((line) => line.trim() !== "");
    if (lines.length === 0) return;
    console.error(lines.slice(-20).join("\n"));
}

if (import.meta.main) runScript("initialize-cloudkit-schema", main);
