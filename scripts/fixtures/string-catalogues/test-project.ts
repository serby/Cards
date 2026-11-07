// What the string scripts' tests share: catalogues built in memory, copies of
// the fixture project (project/, a repository with one catalogue and ja in its
// knownRegions) in a temporary directory, and the scripts run on a copy with
// fake-ai.ts standing in for the AI.
//
// Usage: import { projectCopy, runScript } from "./fixtures/string-catalogues/test-project.ts";

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { cpSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { type Catalogue, type CatalogueDocument, formatCatalogue } from "../../lib/string-catalogues.ts";

/// This folder: the format and pbxproj fixtures, the fixture project and the fake AI.
export const fixtures = import.meta.dirname;
const scripts = join(fixtures, "..", "..");
const fakeAI = join(fixtures, "fake-ai.ts");
const repoBrief = join(scripts, "..", "l10n", "context.md");

/// A catalogue that exists only in memory, named as the app's.
export function catalogueOf(strings: CatalogueDocument["strings"], name = "Cards/Localizable.xcstrings"): Catalogue {
    const doc: CatalogueDocument = { sourceLanguage: "en", strings, version: "1.0" };
    return { name, path: join(tmpdir(), "unused.xcstrings"), doc, original: "" };
}

export const unit = (value: string, state = "translated") => ({ stringUnit: { state, value } });

export const readJSON = (path: string) => JSON.parse(readFileSync(path, "utf8"));

/// Every object's keys reversed, so a formatter that does not sort would fail.
export function scramble(value: unknown): unknown {
    if (Array.isArray(value)) return value.map(scramble);
    if (value && typeof value === "object") {
        return Object.fromEntries(Object.entries(value).reverse().map(([k, v]) => [k, scramble(v)]));
    }
    return value;
}

/// A copy of the fixture project in a temporary directory, with the real brief.
export function projectCopy(): string {
    const root = mkdtempSync(join(tmpdir(), "string-catalogues-test-"));
    cpSync(join(fixtures, "project"), root, { recursive: true });
    cpSync(repoBrief, join(root, "l10n", "context.md"));
    return root;
}

/// The fixture project with a widget catalogue beside the app's: "Settings"
/// is a twin of the app's, as a file compiled into both targets makes it,
/// and "Find Nearest Card" is the widget's own.
export function projectWithWidget(): string {
    const root = projectCopy();
    mkdirSync(join(root, "CardsWidget"), { recursive: true });
    writeFileSync(
        join(root, "CardsWidget", "Localizable.xcstrings"),
        formatCatalogue({
            sourceLanguage: "en",
            strings: {
                "Find Nearest Card": { comment: "Title of the widget's refresh action." },
                "Settings": { comment: "Tab bar item and navigation title of the Settings screen." },
            },
            version: "1.0",
        }),
    );
    return root;
}

/// Runs scripts/<script>.ts on the project at `root`, with the fake AI.
export function runScript(script: string, root: string, args: string[], env: Record<string, string> = {}) {
    const result = spawnSync(process.execPath, [join(scripts, `${script}.ts`), "--root", root, ...args], {
        encoding: "utf8",
        env: { ...process.env, L10N_AI_BACKOFF_MS: "0", L10N_AI_COMMAND: `"${process.execPath}" "${fakeAI}"`, ...env },
    });
    return { status: result.status, stdout: result.stdout, stderr: result.stderr };
}

/// The script prints its own usage on --help, and exits 2 on an option it
/// does not take, pointing at --help.
export function assertUsage(script: string): void {
    const path = join(scripts, `${script}.ts`);
    const help = spawnSync(process.execPath, [path, "--help"], { encoding: "utf8" });
    assert.equal(help.status, 0, help.stderr);
    assert.ok(help.stdout.startsWith(`Usage: node scripts/${script}.ts`), help.stdout);
    const wrong = spawnSync(process.execPath, [path, "--no-such-option"], { encoding: "utf8" });
    assert.equal(wrong.status, 2, wrong.stderr);
    assert.match(wrong.stderr, new RegExp(`Run node scripts/${script}\\.ts --help for usage`));
}
