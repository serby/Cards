// Archives the app in Release and exports a signed distribution .ipa.
//
// Prints the path to the exported .ipa on stdout, as its last and only line;
// progress and xcodebuild's output go to stderr. So callers can capture it:
//
//   IPA=$(node scripts/build-ipa.ts)
//
// or import buildIpa(), as scripts/upload-build.ts does.
//
// Signing is manual, against the App Store profiles scripts/install-signing-profiles.ts
// installs into ~/Library/MobileDevice/Provisioning Profiles: one each for the app,
// its widget and its Apple Watch app. Override with:
//   CARDS_APP_PROFILE      the app's profile name (default "Cards CI App Store net.serby.Cards")
//   CARDS_WIDGET_PROFILE   the widget's profile name (default "Cards CI App Store net.serby.Cards.Widget")
//   CARDS_WATCH_PROFILE    the watch app's profile name (default "Cards CI App Store net.serby.Cards.watchkitapp")
//   CODE_SIGN_IDENTITY     signing identity (default "Apple Distribution")
//   DEVELOPMENT_TEAM       team ID (default ZMBFPG86J4), passed so archives do not depend on the project's
//   EXPORT_METHOD          app-store-connect | release-testing | debugging (default app-store-connect)
//   BUILD_NUMBER           CFBundleVersion for the app, widget and watch app (default: the project's)
//   XCODE_APP              the Xcode to build with (default: the one in .xcode-version, see scripts/lib/xcode.ts)
//
// Usage: node scripts/build-ipa.ts

import { existsSync, mkdirSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { parseArgs } from "node:util";
import { profileName } from "./install-signing-profiles.ts";
import { root, run } from "./lib/xcode.ts";

const appId = "net.serby.Cards";
const widgetId = "net.serby.Cards.Widget";
const watchId = "net.serby.Cards.watchkitapp";

const usage = "Usage: node scripts/build-ipa.ts (settings come from the environment; see the comment at the top of the script)";

export interface BuildOptions {
    /// CFBundleVersion for the app, widget and watch app. Default: BUILD_NUMBER, else the project's.
    buildNumber?: string;
}

/// Like the shell's ${NAME:-fallback}: an empty variable counts as unset.
function setting(name: string, fallback: string): string {
    return process.env[name] || fallback;
}

function escapeXml(value: string): string {
    return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

/// Runs xcodebuild with its output on stderr, keeping stdout for the .ipa path.
function xcodebuild(step: string, args: string[]): void {
    try {
        run("xcodebuild", args, { stdio: ["inherit", 2, 2] });
    } catch (error) {
        const status = (error as { status?: number | null }).status;
        throw new Error(`xcodebuild ${step} failed${status == null ? "" : ` (exit code ${status})`}; its output is above`);
    }
}

/// Archives and exports the app, and returns the path to the .ipa.
export function buildIpa(options: BuildOptions = {}): string {
    const teamId = setting("DEVELOPMENT_TEAM", "ZMBFPG86J4");
    const appProfile = setting("CARDS_APP_PROFILE", profileName(appId));
    const widgetProfile = setting("CARDS_WIDGET_PROFILE", profileName(widgetId));
    const watchProfile = setting("CARDS_WATCH_PROFILE", profileName(watchId));
    const identity = setting("CODE_SIGN_IDENTITY", "Apple Distribution");
    const method = setting("EXPORT_METHOD", "app-store-connect");
    const buildNumber = options.buildNumber ?? process.env.BUILD_NUMBER ?? "";

    const buildDir = join(root, "build", "release");
    const archivePath = join(buildDir, "Cards.xcarchive");
    const exportDir = join(buildDir, "export");
    const exportOptions = join(buildDir, "ExportOptions.plist");

    rmSync(archivePath, { recursive: true, force: true });
    rmSync(exportDir, { recursive: true, force: true });
    mkdirSync(buildDir, { recursive: true });

    // Generated rather than checked in: it embeds the team and profile name, and we
    // want env overrides to take effect without editing a tracked file.
    writeFileSync(
        exportOptions,
        `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>${escapeXml(method)}</string>
	<key>teamID</key>
	<string>${escapeXml(teamId)}</string>
	<key>signingStyle</key>
	<string>manual</string>
	<key>signingCertificate</key>
	<string>${escapeXml(identity)}</string>
	<key>provisioningProfiles</key>
	<dict>
		<key>${appId}</key>
		<string>${escapeXml(appProfile)}</string>
		<key>${widgetId}</key>
		<string>${escapeXml(widgetProfile)}</string>
		<key>${watchId}</key>
		<string>${escapeXml(watchProfile)}</string>
	</dict>
	<key>stripSwiftSymbols</key>
	<true/>
	<key>uploadSymbols</key>
	<true/>
	<key>destination</key>
	<string>export</string>
</dict>
</plist>
`,
    );

    // The app, the widget and the watch app must carry the same CFBundleVersion, so it
    // is set once, for every target, rather than in any Info.plist.
    const versionArgs = buildNumber ? [`CURRENT_PROJECT_VERSION=${buildNumber}`] : [];

    console.error("==> Archiving (Release)");
    xcodebuild("archive", [
        "archive",
        "-project", "Cards.xcodeproj",
        "-scheme", "Cards",
        "-configuration", "Release",
        "-destination", "generic/platform=iOS",
        "-archivePath", archivePath,
        // The one build with DerivedData of its own, build/release/dd, and
        // IDEBuildLocationStyle=Unique to keep a custom build location out of it
        // too: what goes to the App Store reuses nothing a development build left
        // behind, locally as on CI's fresh runner.
        "-derivedDataPath", join(buildDir, "dd"),
        "-IDEBuildLocationStyle=Unique",
        "CODE_SIGN_STYLE=Manual",
        `DEVELOPMENT_TEAM=${teamId}`,
        `CARDS_APP_PROFILE=${appProfile}`,
        `CARDS_WIDGET_PROFILE=${widgetProfile}`,
        `CARDS_WATCH_PROFILE=${watchProfile}`,
        `CODE_SIGN_IDENTITY=${identity}`,
        ...versionArgs,
    ]);

    console.error("==> Exporting .ipa");
    xcodebuild("-exportArchive", [
        "-exportArchive",
        "-archivePath", archivePath,
        "-exportOptionsPlist", exportOptions,
        "-exportPath", exportDir,
    ]);

    const ipa = (existsSync(exportDir) ? readdirSync(exportDir) : [])
        .filter((name) => name.endsWith(".ipa"))
        .sort()
        .map((name) => join(exportDir, name))
        .find((path) => statSync(path).isFile());
    if (!ipa) throw new Error(`no .ipa produced in ${exportDir}`);
    return ipa;
}

if (import.meta.main) {
    try {
        const { values } = parseArgs({ args: process.argv.slice(2), options: { help: { type: "boolean", short: "h", default: false } }, strict: true, allowPositionals: false });
        if (values.help) {
            console.log(usage);
        } else {
            console.log(buildIpa());
        }
    } catch (error) {
        console.error(`error: ${error instanceof Error ? error.message : String(error)}`);
        process.exitCode = 1;
    }
}
