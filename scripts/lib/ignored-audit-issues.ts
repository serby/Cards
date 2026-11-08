// The accessibility audit issues a test run ignored as known false positives,
// which the UI tests record in the result bundle as "Ignored audit issue: …"
// attachments (CardsUITests/AccessibilityAuditCase+KnownFalsePositives.swift),
// so every run's summary says which exceptions it used (AGENTS.md rule 8).
//
// Usage: import { ignoredAuditIssues, ignoredAuditIssueNames } from "./lib/ignored-audit-issues.ts";

import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { run } from "./xcode.ts";

interface Manifest {
    attachments: { suggestedHumanReadableName: string }[];
}

/// The ignored issues in an exported attachments manifest, each with how
/// many times it was ignored, as "dynamicType locationNameField ×2", sorted.
export function ignoredAuditIssueNames(manifest: Manifest[]): string[] {
    const counts = new Map<string, number>();
    for (const test of manifest) {
        for (const attachment of test.attachments) {
            // xcresulttool adds "_<index>_<UUID>" and the extension to a name.
            const match = /^Ignored audit issue:? (.+?)(?:_\d+_[0-9A-F-]{36})?(?:\.txt)?$/i.exec(attachment.suggestedHumanReadableName);
            if (match?.[1]) counts.set(match[1], (counts.get(match[1]) ?? 0) + 1);
        }
    }
    return [...counts].map(([name, count]) => (count > 1 ? `${name} ×${count}` : name)).sort();
}

/// The ignored issues in the result bundle at `bundle`, or none when it has
/// no attachments to read.
export function ignoredAuditIssues(bundle: string): string[] {
    const dir = mkdtempSync(join(tmpdir(), "cards-ignored-"));
    try {
        run("xcrun", ["xcresulttool", "export", "attachments", "--path", bundle, "--output-path", dir], { stdio: "ignore" });
        return ignoredAuditIssueNames(JSON.parse(readFileSync(join(dir, "manifest.json"), "utf8")) as Manifest[]);
    } catch {
        return [];
    } finally {
        rmSync(dir, { recursive: true, force: true });
    }
}
