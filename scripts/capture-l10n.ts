// Screenshots every screen in each language and text size, for checking the
// translations by eye. Builds for testing once, then runs
// CardsUITests/CardsLocalisationScreenshotTests once per language and size,
// in the test language and region that -testLanguage and -testRegion set
// (zh-Hant in TW, pt-BR in BR), installing the app afresh each time so the
// location prompt shows, and writes the attachments to
// <out>/<language>/<size>/<screen>.png. See docs/DEVELOPMENT.md, "Check the
// translations on screen".
//
// Usage: node scripts/capture-l10n.ts [options]
//   --lang <code>…    Languages (default: en and every language in knownRegions)
//   --size <name>…    Text sizes: xs s m large xl xxl xxxl AX1…AX5 (default: large AX5)
//   --device <name>   Simulator (default: iPhone 16 Pro), created if missing
//   --os <version>    Its iOS version (default: 18.1)
//   --out <dir>       Where the PNGs go (default: /tmp/cards-l10n-qa)
//   --no-build        Reuse the last build in <out>/.build

import { execFileSync, spawnSync } from "node:child_process";
import { cpSync, existsSync, mkdirSync, openSync, readdirSync, readFileSync, rmSync, statSync } from "node:fs";
import { basename, dirname, join } from "node:path";
import { parseArgs } from "node:util";
import { projectAt, projectLanguages } from "./l10n.ts";

const root = join(import.meta.dirname, "..");
const xcodeApp = process.env.XCODE_APP ?? "/Applications/Xcode27.1.app";
const env = { ...process.env, DEVELOPER_DIR: `${xcodeApp}/Contents/Developer` };
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

/// The simulator called `name` on iOS `os`, created if there is none, booted.
function simulator(name: string, os: string): string {
    const runtimeID = `com.apple.CoreSimulator.SimRuntime.iOS-${os.replace(".", "-")}`;
    const list = JSON.parse(run("xcrun", ["simctl", "list", "-j", "devices"])) as { devices: Record<string, Device[]> };
    let udid = (list.devices[runtimeID] ?? []).find((device) => device.isAvailable && device.name === name)?.udid;
    if (!udid) {
        const types = JSON.parse(run("xcrun", ["simctl", "list", "-j", "devicetypes"])) as {
            devicetypes: { name: string; identifier: string }[];
        };
        const type = types.devicetypes.find((candidate) => candidate.name === name);
        if (!type) throw new Error(`No simulator device type called "${name}"`);
        udid = run("xcrun", ["simctl", "create", name, type.identifier, runtimeID]).trim();
        console.log(`Created ${name} (iOS ${os}): ${udid}`);
    }
    spawnSync("xcrun", ["simctl", "boot", udid], { env, stdio: "ignore" });
    run("xcrun", ["simctl", "bootstatus", udid, "-b"]);
    return udid;
}

/// Builds the app and its tests, and copies the products with their
/// .xctestrun into `buildDir`, so a later build in the tree cannot change
/// what the runs test.
function buildForTesting(destination: string, buildDir: string, logs: string): string {
    const args = [
        "-project", join(root, "Cards.xcodeproj"), "-scheme", "Cards",
        "-derivedDataPath", join(root, "build", "dd"), "-destination", destination,
    ];
    console.log("==> Building for testing");
    if (!runLogged("xcodebuild", ["build-for-testing", ...args], join(logs, "build.log"))) {
        throw new Error(`The build failed; see ${join(logs, "build.log")}`);
    }
    // Never assume the products' location: a custom build location
    // preference overrides -derivedDataPath (docs/DEVELOPMENT.md, section 2).
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

interface TestTarget {
    UITargetAppPath?: string;
    UITargetAppCommandLineArguments?: string[];
}

/// A copy of the .xctestrun beside it that runs in `language` and `region`,
/// as `xcodebuild test -testLanguage -testRegion` would: the targets' test
/// language and region, and the app launched in them. With -xctestrun
/// xcodebuild ignores both flags, and the file's TestLanguage alone reaches
/// the test runner but not the app, so the app gets the launch arguments a
/// scheme's App Language and App Region give it.
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
    for (const [path, target] of targets) {
        run("plutil", ["-replace", `${path}.TestLanguage`, "-string", language, copy]);
        run("plutil", ["-replace", `${path}.TestRegion`, "-string", region, copy]);
        if (!target.UITargetAppPath) continue;
        const launch = [
            ...(target.UITargetAppCommandLineArguments ?? []),
            "-AppleLanguages", `(${language})`, "-AppleLocale", appleLocale(language, region),
        ];
        run("plutil", ["-replace", `${path}.UITargetAppCommandLineArguments`, "-json", JSON.stringify(launch), copy]);
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
        { TEST_RUNNER_CARDS_L10N_CAPTURE: "1", TEST_RUNNER_CARDS_L10N_CONTENT_SIZE: sizes[size] },
    );

    let saved = 0;
    if (existsSync(results)) {
        run("xcrun", ["xcresulttool", "export", "attachments", "--path", results, "--output-path", exported]);
        const manifest = JSON.parse(readFileSync(join(exported, "manifest.json"), "utf8")) as Manifest[];
        mkdirSync(screens, { recursive: true });
        for (const attachment of manifest.flatMap((entry) => entry.attachments ?? [])) {
            const name = screenName(attachment.suggestedHumanReadableName ?? attachment.exportedFileName);
            if (!/^\d\d-[a-z-]+$/.test(name)) continue;
            cpSync(join(exported, attachment.exportedFileName), join(screens, `${name}.png`));
            saved += 1;
        }
    }
    return { saved, passed };
}

export function main(argv: string[]): number {
    const { values } = parseArgs({
        args: argv,
        options: {
            lang: { type: "string", multiple: true },
            size: { type: "string", multiple: true },
            device: { type: "string", default: "iPhone 16 Pro" },
            os: { type: "string", default: "18.1" },
            out: { type: "string", default: "/tmp/cards-l10n-qa" },
            "no-build": { type: "boolean", default: false },
        },
    });
    const pbxproj = readFileSync(projectAt(root).pbxproj, "utf8");
    const languages = values.lang?.length ? values.lang : ["en", ...projectLanguages(pbxproj)];
    const chosenSizes = values.size?.length ? values.size : ["large", "AX5"];
    const unknown = chosenSizes.filter((size) => !(size in sizes));
    if (unknown.length) {
        console.error(`Unknown text size ${unknown.join(", ")}; use one of ${Object.keys(sizes).join(" ")}`);
        return 2;
    }

    const out = values.out;
    const logs = join(out, ".logs");
    const buildDir = join(out, ".build");
    const udid = simulator(values.device, values.os);
    const testRun = values["no-build"]
        ? join(buildDir, readdirSync(buildDir).find((name) => name.endsWith(".xctestrun") && !name.startsWith("run-")) ?? "")
        : buildForTesting(`platform=iOS Simulator,id=${udid}`, buildDir, logs);

    const failures: string[] = [];
    for (const language of languages) {
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
