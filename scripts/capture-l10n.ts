// Screenshots every screen in each language and text size, for checking the
// translations by eye. Builds for testing once, then runs
// CardsUITests/CardsLocalisationScreenshotTests once per language and size,
// in the test language and region that -testLanguage and -testRegion set
// (zh-Hant in TW, pt-BR in BR), installing the app afresh each time so the
// location prompt shows, and writes the attachments to
// <out>/<language>/<size>/<screen>.png. It runs on a simulator of its own,
// whose system language it sets to each language in turn, so what iOS draws
// outside the app is in the language too. See docs/DEVELOPMENT.md, "Check
// the translations on screen".
//
// Usage: node scripts/capture-l10n.ts [options]
//   --lang <code>…    Languages (default: en and every language in knownRegions);
//                     one value may hold several, separated by spaces ("de ja")
//   --size <name>…    Text sizes: xs s m large xl xxl xxxl AX1…AX5 (default: large AX5),
//                     several to a value as for --lang
//   --device <type>   Simulator device type (default: the automated tests' iPhone 17,
//                     scripts/lib/test-devices.ts); the script keeps its own
//   --os <version>    Its iOS: a version, such as "27.0", or a major version, such as
//                     "27", for the newest installed (default: the automated tests' 26)
//   --out <dir>       Where the PNGs go (default: /tmp/cards-l10n-qa)
//   --no-build        Reuse the last build in <out>/.build

import { execFileSync, spawnSync } from "node:child_process";
import { cpSync, existsSync, mkdirSync, openSync, readdirSync, readFileSync, rmSync, statSync } from "node:fs";
import { basename, dirname, join } from "node:path";
import { parseArgs } from "node:util";
import { appLanguages } from "./lib/locales.ts";
import { findTestSimulator, setSystemLanguage } from "./lib/simulator.ts";
import { automatedTestSimulatorWith } from "./lib/test-devices.ts";
import { root, xcodeEnv } from "./lib/xcode.ts";

/// The Xcode in .xcode-version, as every script uses it.
const env = xcodeEnv();
const bundleID = "net.serby.Cards";
const testClass = "CardsUITests/CardsLocalisationScreenshotTests";

/// The size names people use, to the content size categories iOS takes.
const sizes: Record<string, string> = {
    xs: "UICTContentSizeCategoryXS",
    s: "UICTContentSizeCategoryS",
    m: "UICTContentSizeCategoryM",
    large: "UICTContentSizeCategoryL",
    xl: "UICTContentSizeCategoryXL",
    xxl: "UICTContentSizeCategoryXXL",
    xxxl: "UICTContentSizeCategoryXXXL",
    AX1: "UICTContentSizeCategoryAccessibilityM",
    AX2: "UICTContentSizeCategoryAccessibilityL",
    AX3: "UICTContentSizeCategoryAccessibilityXL",
    AX4: "UICTContentSizeCategoryAccessibilityXXL",
    AX5: "UICTContentSizeCategoryAccessibilityXXXL",
};

/// The region each language is checked in, where it is not the language's
/// most likely one: British English is the source, and Arabic follows the
/// Saudi locale, as the Arabic UI tests do. The rest come from the code
/// (pt-BR) or from likely subtags (ja → JP, zh-Hant → TW).
const regionOverrides: Record<string, string> = { en: "GB", ar: "SA" };

export function regionFor(language: string): string {
    const region = regionOverrides[language] ?? new Intl.Locale(language).maximize().region;
    if (!region) throw new Error(`No region for ${language}; add it to regionOverrides`);
    return region;
}

/// Attachment names as XCTest exports them, "<name>_<iteration>_<UUID>.png",
/// back to the name the test gave.
export function screenName(exported: string): string {
    return exported.replace(/_\d+_[0-9A-Fa-f-]{36}\.png$/, "");
}

function run(command: string, args: string[]): string {
    return execFileSync(command, args, { encoding: "utf8", env, maxBuffer: 64 * 1024 * 1024 });
}

/// Runs a command with its output in a log file, as xcodebuild's is long.
function runLogged(command: string, args: string[], log: string, extraEnv: Record<string, string> = {}): boolean {
    mkdirSync(dirname(log), { recursive: true });
    const fd = openSync(log, "w");
    const result = spawnSync(command, args, { env: { ...env, ...extraEnv }, stdio: ["ignore", fd, fd] });
    return result.status === 0;
}

interface Device {
    name: string;
    udid: string;
    state: string;
    isAvailable: boolean;
}

/// The script's own simulator of the device type `deviceType` on iOS `os`,
/// on the runtime the automated tests' simulator would use (lib/simulator.ts),
/// created if there is none, and booted. Its own, because each language
/// changes the simulator's system language, which nobody else's should get.
function simulator(deviceType: string, os: string): string {
    const name = `${deviceType} (Cards l10n QA)`;
    const { runtime, deviceType: typeID, version } = findTestSimulator(automatedTestSimulatorWith({ model: deviceType, os }));
    const list = JSON.parse(run("xcrun", ["simctl", "list", "-j", "devices"])) as { devices: Record<string, Device[]> };
    let udid = (list.devices[runtime] ?? []).find((device) => device.isAvailable && device.name === name)?.udid;
    if (!udid) {
        udid = run("xcrun", ["simctl", "create", name, typeID, runtime]).trim();
        console.log(`Created ${name} (iOS ${version}): ${udid}`);
    }
    boot(udid);
    return udid;
}

function boot(udid: string): void {
    spawnSync("xcrun", ["simctl", "boot", udid], { env, stdio: "ignore" });
    run("xcrun", ["simctl", "bootstatus", udid, "-b"]);
}

/// Builds the app and its tests, and copies the products with their
/// .xctestrun into `buildDir`, so a later build in the tree cannot change
/// what the runs test.
function buildForTesting(destination: string, buildDir: string, logs: string): string {
    const args = [
        "-project", join(root, "Cards.xcodeproj"), "-scheme", "Cards", "-destination", destination,
    ];
    console.log("==> Building for testing");
    if (!runLogged("xcodebuild", ["build-for-testing", ...args], join(logs, "build.log"))) {
        throw new Error(`The build failed; see ${join(logs, "build.log")}`);
    }
    // Never assume the products' location: it is a per-user Xcode setting
    // (docs/DEVELOPMENT.md, section 2).
    const settings = run("xcodebuild", [...args, "-showBuildSettings"]);
    const productsDir = /^\s*BUILT_PRODUCTS_DIR = (.+)$/m.exec(settings)?.[1];
    if (!productsDir) throw new Error("xcodebuild did not report BUILT_PRODUCTS_DIR");
    const productsRoot = dirname(productsDir);
    const testRun = readdirSync(productsRoot)
        .filter((name) => name.endsWith(".xctestrun"))
        .map((name) => join(productsRoot, name))
        .sort((a, b) => statSync(b).mtimeMs - statSync(a).mtimeMs)[0];
    if (!testRun) throw new Error(`No .xctestrun in ${productsRoot}`);
    rmSync(buildDir, { recursive: true, force: true });
    mkdirSync(buildDir, { recursive: true });
    cpSync(productsDir, join(buildDir, basename(productsDir)), { recursive: true, verbatimSymlinks: true });
    cpSync(testRun, join(buildDir, basename(testRun)));
    return join(buildDir, basename(testRun));
}

/// The locale for a language checked in a region: "zh-Hant_TW", "pt_BR".
export function appleLocale(language: string, region: string): string {
    const locale = new Intl.Locale(language);
    return `${[locale.language, locale.script].filter(Boolean).join("-")}_${region}`;
}

type TestTarget = Record<string, unknown>;

/// A copy of the .xctestrun beside it whose test runner runs in `language`
/// and `region`, as `xcodebuild test -testLanguage -testRegion` would set
/// them: with -xctestrun xcodebuild ignores both flags. The file's
/// TestLanguage reaches the test runner but not the app, so the app's own
/// language comes from the test, which reads CARDS_L10N_LANGUAGE and
/// CARDS_L10N_LOCALE (`capture`) and passes them as launch arguments: the
/// tests launch in British English unless their arguments name a language.
function testRunIn(testRun: string, label: string, language: string, region: string): string {
    const copy = join(dirname(testRun), `run-${label}.xctestrun`);
    cpSync(testRun, copy);
    const plist = JSON.parse(run("plutil", ["-convert", "json", "-o", "-", copy])) as {
        TestConfigurations?: { TestTargets: TestTarget[] }[];
        [target: string]: unknown;
    };
    // Format 1 keys the targets at the top level; format 2 lists them.
    const targets: [string, TestTarget][] = plist.TestConfigurations
        ? plist.TestConfigurations.flatMap((configuration, i) =>
            configuration.TestTargets.map((target, j): [string, TestTarget] => [`TestConfigurations.${i}.TestTargets.${j}`, target]))
        : Object.entries(plist)
            .filter(([key]) => key !== "__xctestrun_metadata__")
            .map(([key, target]): [string, TestTarget] => [key, target as TestTarget]);
    for (const [path] of targets) {
        run("plutil", ["-replace", `${path}.TestLanguage`, "-string", language, copy]);
        run("plutil", ["-replace", `${path}.TestRegion`, "-string", region, copy]);
    }
    return copy;
}

interface Manifest {
    attachments?: { exportedFileName: string; suggestedHumanReadableName?: string }[];
}

/// Runs the screenshot test in one language and size; returns how many
/// screens it saved, or the failure.
function capture(options: {
    udid: string; testRun: string; language: string; size: string; out: string; logs: string;
}): { saved: number; passed: boolean } {
    const { udid, testRun, language, size, out, logs } = options;
    const label = `${language}-${size}`;
    const results = join(out, ".results", `${label}.xcresult`);
    const exported = join(out, ".results", `${label}-attachments`);
    const screens = join(out, language, size);
    rmSync(results, { recursive: true, force: true });
    rmSync(exported, { recursive: true, force: true });
    rmSync(screens, { recursive: true, force: true });

    // A fresh install, so the system asks for location access again; and
    // never install over a running copy, which can keep the old binary.
    spawnSync("xcrun", ["simctl", "terminate", udid, bundleID], { env, stdio: "ignore" });
    spawnSync("xcrun", ["simctl", "uninstall", udid, bundleID], { env, stdio: "ignore" });

    const passed = runLogged(
        "xcodebuild",
        [
            "test-without-building", "-xctestrun", testRunIn(testRun, label, language, regionFor(language)),
            "-destination", `platform=iOS Simulator,id=${udid}`,
            `-only-testing:${testClass}`,
            "-collect-test-diagnostics", "never",
            "-resultBundlePath", results,
        ],
        join(logs, `${label}.log`),
        {
            TEST_RUNNER_CARDS_L10N_CAPTURE: "1",
            TEST_RUNNER_CARDS_L10N_LANGUAGE: language,
            TEST_RUNNER_CARDS_L10N_LOCALE: appleLocale(language, regionFor(language)),
            TEST_RUNNER_CARDS_L10N_CONTENT_SIZE: sizes[size],
        },
    );

    let saved = 0;
    if (existsSync(results)) {
        run("xcrun", ["xcresulttool", "export", "attachments", "--path", results, "--output-path", exported]);
        const manifest = JSON.parse(readFileSync(join(exported, "manifest.json"), "utf8")) as Manifest[];
        mkdirSync(screens, { recursive: true });
        for (const attachment of manifest.flatMap((entry) => entry.attachments ?? [])) {
            const name = screenName(attachment.suggestedHumanReadableName ?? attachment.exportedFileName);
            if (!/^\d\d-[a-z0-9-]+$/.test(name)) continue;
            cpSync(join(exported, attachment.exportedFileName), join(screens, `${name}.png`));
            saved += 1;
        }
    }
    return { saved, passed };
}

/// The values of a repeatable option, each of which may hold several separated
/// by spaces or commas, as the Makefile passes LANGS and SIZES. An empty value
/// adds nothing.
export function list(values: string[] | undefined): string[] {
    return (values ?? []).flatMap((value) => value.split(/[\s,]+/)).filter(Boolean);
}

export function main(argv: string[]): number {
    const { values } = parseArgs({
        args: argv,
        options: {
            lang: { type: "string", multiple: true },
            size: { type: "string", multiple: true },
            device: { type: "string" },
            os: { type: "string" },
            out: { type: "string", default: "/tmp/cards-l10n-qa" },
            "no-build": { type: "boolean", default: false },
        },
    });
    const languages = list(values.lang).length ? list(values.lang) : ["en", ...appLanguages()];
    const chosenSizes = list(values.size).length ? list(values.size) : ["large", "AX5"];
    const unknown = chosenSizes.filter((size) => !(size in sizes));
    if (unknown.length) {
        console.error(`Unknown text size ${unknown.join(", ")}; use one of ${Object.keys(sizes).join(" ")}`);
        return 2;
    }

    const out = values.out;
    const logs = join(out, ".logs");
    const buildDir = join(out, ".build");
    const destination = automatedTestSimulatorWith({ model: values.device, os: values.os });
    const udid = simulator(destination.model, destination.os);
    const testRun = values["no-build"]
        ? join(buildDir, readdirSync(buildDir).find((name) => name.endsWith(".xctestrun") && !name.startsWith("run-")) ?? "")
        : buildForTesting(`platform=iOS Simulator,id=${udid}`, buildDir, logs);

    const failures: string[] = [];
    for (const language of languages) {
        // What iOS draws outside the app, the location prompt with the app's
        // reason for asking among it, follows the system's language, not the app's.
        setSystemLanguage(udid, { languages: [language], locale: appleLocale(language, regionFor(language)) });
        for (const size of chosenSizes) {
            const started = Date.now();
            const { saved, passed } = capture({ udid, testRun, language, size, out, logs });
            const seconds = Math.round((Date.now() - started) / 1000);
            console.log(`${passed ? "ok  " : "FAIL"} ${language} ${size}: ${saved} screens in ${seconds}s`);
            if (!passed) failures.push(`${language} ${size} (${join(logs, `${language}-${size}.log`)})`);
        }
    }
    console.log(`\nScreenshots in ${out}/<language>/<size>/`);
    if (failures.length) {
        console.error(`Failed: ${failures.join(", ")}`);
        return 1;
    }
    return 0;
}

if (import.meta.main) {
    process.exitCode = main(process.argv.slice(2));
}
