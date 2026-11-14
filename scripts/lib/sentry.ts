// Sentry's project and its debug-file upload, for readable crash stacks
// (PLAT-14). The org and project are Sentry's slugs; the auth token comes from
// the environment and never from the repository.
//
// Usage: import { dsymBundles, sentryProject, uploadUrl } from "./lib/sentry.ts";

import { existsSync, readdirSync } from "node:fs";
import { join } from "node:path";

/// The Sentry organisation and project the app reports to.
export const sentryProject = { org: "paul-serby", project: "card-barcodes" } as const;

/// Where Sentry takes a zip of debug files for the project.
export function uploadUrl(project: { org: string; project: string } = sentryProject, host = "https://sentry.io"): string {
    return `${host}/api/0/projects/${encodeURIComponent(project.org)}/${encodeURIComponent(project.project)}/files/difs/`;
}

/// The .dSYM bundles in an archive's dSYMs folder: the app's, its widget's,
/// its watch app's and its frameworks'. None when the archive has none.
export function dsymBundles(archivePath: string): string[] {
    const folder = join(archivePath, "dSYMs");
    if (!existsSync(folder)) return [];
    return readdirSync(folder)
        .filter((name) => name.endsWith(".dSYM"))
        .sort()
        .map((name) => join(folder, name));
}
