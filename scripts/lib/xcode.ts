// The Xcode this project builds with, and helpers to run its tools.
//
// .xcode-version names one Xcode version, so local builds and CI use the same
// one. developerDir() finds it: XCODE_APP if set, else
// /Applications/Xcode<version>.app, or Xcode_<version>.app as on GitHub's
// runners, or Xcode-<version>.app. It throws, rather than falling back to
// another Xcode, when that Xcode is missing or is a different version.

import { execFileSync, spawn, type ChildProcess, type StdioOptions } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

/// The repository root.
export const root = join(import.meta.dirname, "..", "..");

/// The version in .xcode-version, such as "27.1".
export function pinnedXcodeVersion(): string {
    return readFileSync(join(root, ".xcode-version"), "utf8").trim();
}

let cachedDeveloperDir: string | undefined;

/// The Developer directory of the pinned Xcode, for DEVELOPER_DIR.
export function developerDir(): string {
    if (cachedDeveloperDir) return cachedDeveloperDir;
    const version = pinnedXcodeVersion();
    const candidates = process.env.XCODE_APP
        ? [process.env.XCODE_APP]
        : [`Xcode${version}.app`, `Xcode_${version}.app`, `Xcode-${version}.app`].map((name) => join("/Applications", name));
    const app = candidates.find((path) => existsSync(path));
    if (!app) {
        throw new Error(
            process.env.XCODE_APP
                ? `XCODE_APP is ${process.env.XCODE_APP}, which does not exist`
                : `Xcode ${version}, from .xcode-version, is not installed in /Applications. Install it, or set XCODE_APP to it`,
        );
    }
    const xcodebuild = join(app, "Contents", "Developer", "usr", "bin", "xcodebuild");
    if (!existsSync(xcodebuild)) throw new Error(`${app} is not an Xcode`);
    const actual = execFileSync(xcodebuild, ["-version"], { encoding: "utf8" }).split("\n")[0]?.replace(/^Xcode /, "").trim();
    if (actual !== version) throw new Error(`${app} is Xcode ${actual}, but .xcode-version says ${version}`);
    cachedDeveloperDir = join(app, "Contents", "Developer");
    return cachedDeveloperDir;
}

/// The environment with DEVELOPER_DIR set to the pinned Xcode, for child processes.
export function xcodeEnv(extra: Record<string, string> = {}): NodeJS.ProcessEnv {
    return { ...process.env, DEVELOPER_DIR: developerDir(), ...extra };
}

interface RunOptions {
    cwd?: string;
    env?: Record<string, string>;
    /// Where output goes. Inherit by default, so it shows as the tool prints it.
    stdio?: StdioOptions;
}

/// Runs a command with the pinned Xcode and throws if it fails.
export function run(command: string, args: string[], options: RunOptions = {}): void {
    execFileSync(command, args, { cwd: options.cwd ?? root, env: xcodeEnv(options.env), stdio: options.stdio ?? "inherit" });
}

/// Runs a command with the pinned Xcode and returns what it printed.
export function capture(command: string, args: string[], options: Omit<RunOptions, "stdio"> = {}): string {
    return execFileSync(command, args, {
        cwd: options.cwd ?? root,
        env: xcodeEnv(options.env),
        encoding: "utf8",
        maxBuffer: 256 * 1024 * 1024,
        stdio: ["ignore", "pipe", "inherit"],
    });
}

/// Starts a command with the pinned Xcode without waiting for it.
export function start(command: string, args: string[], options: RunOptions = {}): ChildProcess {
    return spawn(command, args, { cwd: options.cwd ?? root, env: xcodeEnv(options.env), stdio: options.stdio ?? "inherit" });
}

/// Resolves when a started command exits, and rejects if it fails.
export function finished(child: ChildProcess, name: string): Promise<void> {
    return new Promise((resolve, reject) => {
        child.on("error", reject);
        child.on("exit", (code, signal) => {
            if (code === 0) resolve();
            else reject(new Error(`${name} failed (${signal ?? `exit code ${code}`})`));
        });
    });
}

/// The project and scheme every build of the app uses. There is no
/// -derivedDataPath: builds from the command line use Xcode's own DerivedData
/// and build location, as a build in Xcode does, so each carries on from the
/// other's products, intermediates, module cache and package checkouts.
export const projectArgs = ["-project", "Cards.xcodeproj", "-scheme", "Cards"];

/// Where xcodebuild puts the products for `destination`, built with the same
/// `extraArgs`, such as a -configuration. Never assume a path: the build
/// location is a per-user Xcode setting (a custom one on Paul's Mac, DerivedData
/// on CI), so ask it.
export function builtProductsDir(destination: string, extraArgs: string[] = []): string {
    const settings = capture("xcodebuild", [...projectArgs, ...extraArgs, "-destination", destination, "-showBuildSettings"]);
    const match = /^\s*BUILT_PRODUCTS_DIR = (.+)$/m.exec(settings);
    if (!match?.[1]) throw new Error(`xcodebuild did not report BUILT_PRODUCTS_DIR for ${destination}`);
    return match[1].trim();
}
