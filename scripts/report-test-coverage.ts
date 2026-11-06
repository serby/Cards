// Runs the tests on an iPhone and an iPad simulator with code coverage, then
// writes an HTML coverage report to coverage-html/ and prints a summary.
//
// Both simulators test the same build in one DerivedData, build/cov, so a rerun
// builds incrementally, and the coverage both recorded is merged into one report.
// The build stays in build/cov even where Xcode is set to a custom build
// location, so a later `make build` cannot replace the binaries the coverage
// was recorded against. If tests fail, the report is still written from the
// coverage they recorded, and the script then exits with xcodebuild's status.
//
// --report-only skips the tests and reports the last run's coverage again.
// --open opens the report in the browser afterwards. Arguments after -- go to
// xcodebuild test, such as -only-testing:CardsTests. The simulators are
// $PHONE_SIM (default iPhone 16 Pro) and $IPAD_SIM (default iPad Pro 13-inch
// (M4)) on iOS $SIMULATOR_VERSION (default 18.1).
//
// Usage: node scripts/report-test-coverage.ts [--report-only] [--open] [-- xcodebuild-args...]

import { execFileSync } from "node:child_process";
import { existsSync, mkdtempSync, readdirSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { basename, join } from "node:path";
import { capture, developerDir, root, run } from "./lib/xcode.ts";

const derivedData = join(root, "build", "cov");
const profileDataDirectory = join(derivedData, "Build", "ProfileData");
const resultBundle = join(derivedData, "Tests.xcresult");
const reportDirectory = join(root, "coverage-html");
const simulatorVersion = process.env.SIMULATOR_VERSION ?? "18.1";
const simulators = [process.env.PHONE_SIM ?? "iPhone 16 Pro", process.env.IPAD_SIM ?? "iPad Pro 13-inch (M4)"];
const destinations = simulators.map((name) => `platform=iOS Simulator,name=${name},OS=${simulatorVersion}`);

/// Source paths left out of the report: the tests themselves, Swift packages and
/// the code Xcode generates, such as GeneratedAssetSymbols.swift.
const excludedPaths = ["/CardsTests/", "/CardsUITests/", "/SourcePackages/", "/DerivedSources/"];

/// The xcodebuild arguments every step shares. IDEBuildLocationStyle=Unique
/// overrides a custom build location preference, so products land in build/cov.
const projectArguments = ["-project", "Cards.xcodeproj", "-scheme", "Cards", "-derivedDataPath", derivedData, "-IDEBuildLocationStyle=Unique"];

const usage = "Usage: node scripts/report-test-coverage.ts [--report-only] [--open] [-- xcodebuild-args...]";

interface Options {
    reportOnly: boolean;
    open: boolean;
    xcodebuildArguments: string[];
}

function parseArguments(args: string[]): Options {
    const options: Options = { reportOnly: false, open: false, xcodebuildArguments: [] };
    for (const [index, arg] of args.entries()) {
        if (arg === "--") {
            options.xcodebuildArguments = args.slice(index + 1);
            break;
        }
        if (arg === "--report-only") options.reportOnly = true;
        else if (arg === "--open") options.open = true;
        else if (arg === "-h" || arg === "--help") {
            console.log(usage);
            process.exit(0);
        } else {
            console.error(`Unknown argument: ${arg}\n${usage}`);
            process.exit(2);
        }
    }
    if (options.reportOnly && options.xcodebuildArguments.length > 0) {
        console.error(`--report-only runs no tests, so it takes no xcodebuild arguments\n${usage}`);
        process.exit(2);
    }
    return options;
}

/// Runs the tests and returns xcodebuild's exit status. The last run's coverage
/// and results go first, so only this run's are reported.
function runTests(extraArguments: string[]): number {
    rmSync(profileDataDirectory, { recursive: true, force: true });
    rmSync(resultBundle, { recursive: true, force: true });
    console.error(`Running the tests on ${simulators.join(" and ")} (iOS ${simulatorVersion}) in ${derivedData}...`);
    try {
        run("xcodebuild", [
            "test",
            ...projectArguments,
            ...destinations.flatMap((destination) => ["-destination", destination]),
            "-enableCodeCoverage",
            "YES",
            "-resultBundlePath",
            resultBundle,
            "-retry-tests-on-failure",
            "-test-iterations",
            "3",
            ...extraArguments,
        ]);
        return 0;
    } catch (error) {
        const status = (error as { status?: number | null }).status;
        console.error(`warning: xcodebuild test failed (${typeof status === "number" ? `exit code ${status}` : String(error)})`);
        console.error("         reporting the coverage the tests recorded anyway");
        return typeof status === "number" && status !== 0 ? status : 1;
    }
}

/// Where the build products are, asked of xcodebuild rather than assumed.
function builtProductsDirectory(): string {
    const output = capture("xcodebuild", [...projectArguments, "-destination", destinations[0] ?? "", "-showBuildSettings", "-json"]);
    const targets = JSON.parse(output) as { target: string; buildSettings: Record<string, string> }[];
    const settings = (targets.find((entry) => entry.target === "Cards") ?? targets[0])?.buildSettings;
    if (!settings?.BUILT_PRODUCTS_DIR) throw new Error("xcodebuild -showBuildSettings gave no BUILT_PRODUCTS_DIR");
    return settings.BUILT_PRODUCTS_DIR;
}

/// The coverage the last run recorded. xcodebuild writes a Coverage.profdata per
/// destination, in Build/ProfileData/<simulator UDID>/.
function profileData(): string[] {
    if (!existsSync(profileDataDirectory)) return [];
    return readdirSync(profileDataDirectory)
        .map((entry) => join(profileDataDirectory, entry, "Coverage.profdata"))
        .filter((path) => existsSync(path));
}

/// The instrumented binaries: the app and each extension. Debug builds put a
/// target's code in <name>.debug.dylib and leave only a stub in the executable.
function instrumentedBinaries(productsDirectory: string): string[] {
    const app = join(productsDirectory, "Cards.app");
    const plugIns = join(app, "PlugIns");
    const bundles = [app, ...(existsSync(plugIns) ? readdirSync(plugIns).filter((name) => name.endsWith(".appex")).map((name) => join(plugIns, name)) : [])];
    return bundles.flatMap((bundle) => {
        const name = basename(bundle).replace(/\.(app|appex)$/, "");
        return [join(bundle, `${name}.debug.dylib`), join(bundle, name)].filter((path) => existsSync(path)).slice(0, 1);
    });
}

function escapeRegex(text: string): string {
    return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function writeReport(profiles: string[], binaries: string[], open: boolean): void {
    const work = mkdtempSync(join(tmpdir(), "cards-coverage-"));
    try {
        const merged = join(work, "merged.profdata");
        run("xcrun", ["llvm-profdata", "merge", "-sparse", ...profiles, "-o", merged]);

        // llvm-cov takes the first binary as an argument and the rest with -object=.
        const [primary, ...others] = binaries;
        const coverageArguments = [
            `-instr-profile=${merged}`,
            ...excludedPaths.map((path) => `--ignore-filename-regex=.*${escapeRegex(path)}.*`),
            ...others.map((binary) => `-object=${binary}`),
            primary ?? "",
        ];

        console.log(`\n=== Coverage summary (${binaries.map((binary) => basename(binary)).join(", ")}) ===`);
        run("xcrun", ["llvm-cov", "report", ...coverageArguments]);

        rmSync(reportDirectory, { recursive: true, force: true });
        run("xcrun", [
            "llvm-cov",
            "show",
            "--format=html",
            `--output-dir=${reportDirectory}`,
            "--show-line-counts-or-regions",
            ...coverageArguments,
        ]);
    } finally {
        rmSync(work, { recursive: true, force: true });
    }

    const index = join(reportDirectory, "index.html");
    console.log(`\nReport: ${index}`);
    if (open) execFileSync("open", [index], { stdio: "inherit" });
}

function main(): void {
    const options = parseArguments(process.argv.slice(2));
    developerDir(); // Stops here, with the reason, if the pinned Xcode is missing.

    const testStatus = options.reportOnly ? 0 : runTests(options.xcodebuildArguments);

    const profiles = profileData();
    if (profiles.length === 0) {
        throw new Error(
            options.reportOnly
                ? `No coverage in ${profileDataDirectory}. Run without --report-only first`
                : `The tests recorded no coverage in ${profileDataDirectory}`,
        );
    }
    console.error(`Coverage from:\n${profiles.map((path) => `  - ${path}`).join("\n")}`);

    const binaries = instrumentedBinaries(builtProductsDirectory());
    if (binaries.length === 0) throw new Error(`No Cards.app in the build products of ${derivedData}`);

    writeReport(profiles, binaries, options.open);
    process.exit(testStatus);
}

try {
    main();
} catch (error) {
    console.error(`error: ${error instanceof Error ? error.message : String(error)}`);
    process.exit(1);
}
