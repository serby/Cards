// Captures the raw App Store screenshots by running the screenshot UI tests on
// a simulator, then extracting their attachments into screenshots/<locale>/.
// The images uploaded to the App Store are composed from them (make
// store-screenshots). This runs locally only; CI captures nothing.
//
// With no arguments it captures every device in every store locale (the
// folders in metadata/), which takes about a quarter of an hour a locale; with a
// device, one device in one locale (en-US unless given). Each locale runs in its
// language and region, filling in the likely region where the locale names
// none (ja runs in Japanese in Japan). The simulator itself is put in that
// language and region for the run, and back afterwards, so what iOS draws
// outside the app, the Home Screen and widget gallery the widget is captured
// on among it, is in the locale's language too. The app is uninstalled first, so the
// widget test adds the only widget to a clean Home Screen, and the status bar
// shows 9:41 with full signal and battery.
// Once every capture is done it runs check-screenshots.ts over the whole set:
// not after each one, because a newly added screen is only complete once every
// device and locale has it.
//
// Usage: node scripts/capture-screenshots.ts [<device> [<locale>]]
//   node scripts/capture-screenshots.ts                                  # every device, every store locale
//   node scripts/capture-screenshots.ts "iPhone 17 Pro Max" ja
//   node scripts/capture-screenshots.ts "iPad Pro 13-inch (M4)" en-GB
//   node scripts/capture-screenshots.ts "iPhone Duo" en-GB               # outer display, "_Duo" names

import { execFileSync } from "node:child_process";
import { copyFileSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync } from "node:fs";
import { join } from "node:path";
import { languageOf, regionOf, storeLocales } from "./lib/locales.ts";
import { bootSimulator, setSystemLanguage, type Simulator, systemLanguage } from "./lib/simulator.ts";
import { root, run } from "./lib/xcode.ts";

const devices = ["iPhone 17 Pro Max", "iPad Pro 13-inch (M4)", "iPhone Duo"];
const locales = storeLocales();
const bundleIdentifier = "net.serby.Cards";
const resultBundle = "/tmp/Cards-screenshots.xcresult";
const exportFolder = "/tmp/Cards-screenshots-export";
/// The screens the tests capture, before the device's suffix. check-screenshots.ts
/// lists the same screens.
const screens = ["01_CardList", "02_CardDetail", "03_EditCard", "04_LocationPicker", "05_Widget", "06_ShareCard"];

interface CaptureSet {
    /// The suffix the screenshot names carry, such as "_iPad".
    names: string;
    /// TEST_RUNNER_SCREENSHOT_SUFFIX: the suffix the test adds itself. It adds
    /// "_iPad" on an iPad without being told.
    testSuffix: string;
}

/// Which screenshots the tests take on a device, and the suffix in their names.
function captureSet(device: string): CaptureSet {
    if (device.startsWith("iPad")) return { names: "_iPad", testSuffix: "" };
    if (device === "iPhone Duo") return { names: "_Duo", testSuffix: "_Duo" };
    return { names: "", testSuffix: "" };
}

interface Attachment {
    exportedFileName?: string;
    suggestedHumanReadableName?: string;
}

/// Copies the device's screenshots out of the exported attachments into
/// `outFolder`, and throws if any is missing. manifest.json maps attachment
/// names to exported files. Apple suggests "<our-name>_<iter>_<UUID>.png", so
/// trimming from "_<iter>_" gets our name back.
function copyAttachments(outFolder: string, suffix: string): void {
    const expected = new Set(screens.map((name) => name + suffix));
    const seen = new Set<string>();
    const manifest = JSON.parse(readFileSync(join(exportFolder, "manifest.json"), "utf8")) as { attachments?: Attachment[] }[];
    for (const entry of manifest) {
        for (const attachment of entry.attachments ?? []) {
            const raw = attachment.suggestedHumanReadableName ?? attachment.exportedFileName ?? "";
            const name = raw.replace(/_\d+_[0-9A-Fa-f-]{36}\.png$/, "");
            if (!expected.has(name) || !attachment.exportedFileName) continue;
            copyFileSync(join(exportFolder, attachment.exportedFileName), join(outFolder, `${name}.png`));
            seen.add(name);
        }
    }
    const missing = [...expected].filter((name) => !seen.has(name));
    if (missing.length > 0) throw new Error(`Missing screenshot attachments: ${missing.join(", ")}`);
    console.log(`Copied: ${[...seen].sort().join(", ")}`);
}

async function capture(device: string, locale: string): Promise<void> {
    const outFolder = join(root, "screenshots", locale);
    const set = captureSet(device);
    const language = languageOf(locale);
    const region = regionOf(locale);

    console.log("==> Resolving simulator");
    const simulator = await bootSimulator(device);

    try {
        run("xcrun", ["simctl", "uninstall", simulator.udid, bundleIdentifier], { stdio: ["ignore", "inherit", "ignore"] });
    } catch {
        // It was not installed.
    }
    const original = systemLanguage(simulator.udid);
    console.log(`==> Setting the simulator to ${language}, ${region}`);
    setSystemLanguage(simulator.udid, { languages: [language], locale: `${language}_${region}` });
    try {
        runTests(simulator, set, language, region);
    } finally {
        console.log("==> Setting the simulator back to its own language and region");
        setSystemLanguage(simulator.udid, original);
    }

    console.log("==> Extracting attachments");
    run("xcrun", ["xcresulttool", "export", "attachments", "--path", resultBundle, "--output-path", exportFolder]);
    mkdirSync(outFolder, { recursive: true });
    copyAttachments(outFolder, set.names);

    console.log(`\n==> Screenshots in ${outFolder}:`);
    for (const name of readdirSync(outFolder).filter((file) => file.endsWith(".png")).sort()) {
        console.log(`  ${name}  ${statSync(join(outFolder, name)).size.toLocaleString("en-GB")} bytes`);
    }
}

/// Runs the screenshot tests on the simulator, which is already in the locale's
/// language and region, with the status bar at 9:41.
function runTests(simulator: Simulator, set: CaptureSet, language: string, region: string): void {
    run("xcrun", [
        "simctl", "status_bar", simulator.udid, "override",
        "--time", "9:41",
        "--dataNetwork", "wifi",
        "--wifiMode", "active",
        "--wifiBars", "3",
        "--cellularMode", "active",
        "--cellularBars", "4",
        "--batteryState", "charged",
        "--batteryLevel", "100",
    ]);

    console.log(`==> Running screenshot test on ${simulator.device} (iOS ${simulator.version}) in ${language}, ${region}`);
    rmSync(resultBundle, { recursive: true, force: true });
    rmSync(exportFolder, { recursive: true, force: true });
    run(
        "xcodebuild",
        [
            "test",
            "-project", "Cards.xcodeproj",
            "-scheme", "Cards",
            "-destination", `platform=iOS Simulator,id=${simulator.udid}`,
            "-only-testing:CardsUITests/CardsScreenshotTests/testCaptureScreenshots",
            "-only-testing:CardsUITests/CardsScreenshotTests/testCaptureShareScreenshot",
            "-only-testing:CardsUITests/CardsWidgetScreenshotTests/testCaptureWidgetScreenshot",
            "-testLanguage", language,
            "-testRegion", region,
            "-enableCodeCoverage", "NO",
            "-collect-test-diagnostics", "never",
            "-resultBundlePath", resultBundle,
        ],
        // The widget test finds SpringBoard's buttons by their words in this language.
        { env: { TEST_RUNNER_SCREENSHOT_SUFFIX: set.testSuffix, TEST_RUNNER_SYSTEM_LANGUAGE: language } },
    );
}

const args = process.argv.slice(2);
if (args.length > 2) {
    console.error("Usage: node scripts/capture-screenshots.ts [<device> [<locale>]]");
    process.exit(2);
}
const device = args[0];
if (args[1] !== undefined && !locales.includes(args[1])) {
    console.error(`error: ${args[1]} is not a store locale (${locales.join(", ")})`);
    process.exit(2);
}
const runs = device
    ? [{ device, locale: args[1] ?? "en-US" }]
    : locales.flatMap((locale) => devices.map((each) => ({ device: each, locale })));

try {
    for (const { device: each, locale } of runs) {
        await capture(each, locale);
    }
    console.log("\n==> Checking the whole set");
    execFileSync(process.execPath, [join(root, "scripts", "check-screenshots.ts")], { stdio: "inherit" });
} catch (error) {
    console.error(`error: ${error instanceof Error ? error.message : String(error)}`);
    process.exit(1);
}
console.log("\nLook at every changed image, then run make store-screenshots to compose the App Store images from them.");
