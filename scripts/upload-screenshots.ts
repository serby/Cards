// Replaces the App Store screenshots of the editable App Store version with
// the store images in screenshots/store/<locale>/*.png, in file-name order.
// The raw captures in screenshots/<locale>/, which CI compares against, are
// never uploaded.
//
// Each image's display type comes from its pixel size. For every display type
// it uploads, it first deletes what that set already holds, so a version
// created from the last one does not end up with both sets of images. Display
// types it has no images for are left alone.
//
// Usage: node scripts/upload-screenshots.ts [--version 1.2] [--dry-run]
// Needs ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_CONTENT (see scripts/asc.ts). In
// CI, run the "App Store listing" workflow, which has them.

import { createHash } from "node:crypto";
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { basename, join } from "node:path";
import { AppStoreConnect, AppStoreConnectError, editableVersions, errorMessage, findApp, versionState, type Resource } from "./asc.ts";

const root = join(import.meta.dirname, "..");
const screenshotsDir = join(root, "screenshots", "store");
const bundleId = process.env.BUNDLE_ID ?? "net.serby.Cards";

/// iPhone Duo is newer than the published API spec (4.5.1), which does not list
/// APP_IPHONE_DUO; App Store Connect accepts it all the same (November 2026).
/// ASC_DUO_DISPLAY_TYPE overrides it should Apple rename it.
const duoCandidates = [process.env.ASC_DUO_DISPLAY_TYPE ?? "APP_IPHONE_DUO"];

/// Pixel size to display type, from Apple's screenshot specifications.
function displayTypes(width: number, height: number): string[] {
    const [short, long] = [Math.min(width, height), Math.max(width, height)];
    const size = `${short}x${long}`;
    if (["1320x2868", "1290x2796", "1260x2736"].includes(size)) return ["APP_IPHONE_67"];
    if (["2064x2752", "2048x2732"].includes(size)) return ["APP_IPAD_PRO_3GEN_129"];
    if (["2007x2853", "1398x2034"].includes(size)) return duoCandidates;
    return [];
}

function pngSize(path: string): { width: number; height: number } {
    const header = readFileSync(path).subarray(0, 24);
    if (header.toString("latin1", 12, 16) !== "IHDR") throw new Error(`${path} is not a PNG`);
    return { width: header.readUInt32BE(16), height: header.readUInt32BE(20) };
}

interface Screenshot {
    fileName: string;
    assetDeliveryState?: { state: string; errors?: { code: string; description: string }[] };
    uploadOperations?: { method: string; url: string; offset: number; length: number; requestHeaders: { name: string; value: string }[] }[];
}

const args = process.argv.slice(2);
const dryRun = args.includes("--dry-run");
const versionArgument = args.includes("--version") ? args[args.indexOf("--version") + 1] : undefined;

async function main(): Promise<void> {
    if (!existsSync(screenshotsDir)) throw new Error(`No store screenshots: ${screenshotsDir} does not exist`);
    const asc = new AppStoreConnect();
    const app = await findApp(asc, bundleId);
    const versions = await editableVersions(asc, app.id);
    const version = versionArgument ? versions.find((candidate) => candidate.attributes.versionString === versionArgument) : versions[0];
    if (!version) throw new Error(`No editable App Store version${versionArgument ? ` ${versionArgument}` : ""}`);
    console.log(`==> ${bundleId} ${version.attributes.versionString} (${versionState(version)})${dryRun ? ", dry run" : ""}`);

    const localizations = await asc.all<{ locale: string }>(`/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations`);
    // Which of several candidate types App Store Connect accepted, so a rejected
    // guess is only tried once per run.
    const resolved = new Map<string, string | null>();

    for (const locale of readdirSync(screenshotsDir).filter((name) => statSync(join(screenshotsDir, name)).isDirectory()).sort()) {
        const localization = localizations.find((candidate) => candidate.attributes.locale === locale);
        if (!localization) {
            console.log(`!! ${locale}: the version has no such localisation; skipping`);
            continue;
        }
        console.log(`==> ${locale}`);
        const files = readdirSync(join(screenshotsDir, locale)).filter((name) => name.endsWith(".png")).sort();
        const byType = new Map<string[], string[]>();
        for (const file of files) {
            const { width, height } = pngSize(join(screenshotsDir, locale, file));
            const types = displayTypes(width, height);
            if (types.length === 0) {
                console.log(`!! ${file}: no display type for ${width}x${height}; skipping`);
                continue;
            }
            const key = [...byType.keys()].find((existing) => existing.join() === types.join()) ?? types;
            byType.set(key, [...(byType.get(key) ?? []), file]);
        }

        const sets = await asc.all<{ screenshotDisplayType: string }>(`/v1/appStoreVersionLocalizations/${localization.id}/appScreenshotSets`);
        for (const [types, group] of byType) {
            const set = await screenshotSet(asc, localization.id, sets, types, resolved);
            if (!set) {
                console.log(`!! ${group.join(", ")}: App Store Connect accepts none of ${types.join(", ")}; skipping`);
                continue;
            }
            await replaceScreenshots(asc, set, group.map((file) => join(screenshotsDir, locale, file)));
        }
    }
    console.log("Done. Check the version in App Store Connect.");
}

/// The localisation's set for the first of `types` App Store Connect accepts,
/// creating it if needed.
async function screenshotSet(
    asc: AppStoreConnect,
    localizationId: string,
    sets: Resource<{ screenshotDisplayType: string }>[],
    types: string[],
    resolved: Map<string, string | null>,
): Promise<Resource<{ screenshotDisplayType: string }> | undefined> {
    const key = types.join();
    const known = resolved.get(key);
    const candidates = known === undefined ? types : known === null ? [] : [known];
    for (const type of candidates) {
        const existing = sets.find((set) => set.attributes.screenshotDisplayType === type);
        if (existing) {
            resolved.set(key, type);
            return existing;
        }
        if (dryRun) {
            console.log(`   would create a ${type} set`);
            return { type: "appScreenshotSets", id: "dry-run", attributes: { screenshotDisplayType: type } };
        }
        try {
            const created = await asc.post<Resource<{ screenshotDisplayType: string }>>("/v1/appScreenshotSets", {
                data: {
                    type: "appScreenshotSets",
                    attributes: { screenshotDisplayType: type },
                    relationships: { appStoreVersionLocalization: { data: { type: "appStoreVersionLocalizations", id: localizationId } } },
                },
            });
            console.log(`   created ${type} set`);
            resolved.set(key, type);
            return created.data;
        } catch (error) {
            if (!(error instanceof AppStoreConnectError) || error.status !== 409) throw error;
            console.log(`   ${type} rejected: ${error.body.replace(/\s+/g, " ").slice(0, 600)}`);
        }
    }
    resolved.set(key, null);
    return undefined;
}

async function replaceScreenshots(asc: AppStoreConnect, set: Resource<{ screenshotDisplayType: string }>, paths: string[]): Promise<void> {
    const type = set.attributes.screenshotDisplayType;
    if (dryRun) {
        console.log(`   ${type}: would replace with ${paths.map((path) => basename(path)).join(", ")}`);
        return;
    }
    const existing = await asc.all<Screenshot>(`/v1/appScreenshotSets/${set.id}/appScreenshots`);
    for (const screenshot of existing) {
        await asc.delete(`/v1/appScreenshots/${screenshot.id}`);
    }
    if (existing.length > 0) console.log(`   ${type}: deleted ${existing.length} old screenshot(s)`);

    const uploaded: string[] = [];
    for (const path of paths) {
        uploaded.push(await upload(asc, set.id, path));
        console.log(`   ${type}: ${basename(path)} ✓`);
    }
    // Upload order is display order, but say so explicitly.
    await asc.request("PATCH", `/v1/appScreenshotSets/${set.id}/relationships/appScreenshots`, {
        data: uploaded.map((id) => ({ type: "appScreenshots", id })),
    });
}

async function upload(asc: AppStoreConnect, setId: string, path: string): Promise<string> {
    const bytes = readFileSync(path);
    const reservation = await asc.post<Resource<Screenshot>>("/v1/appScreenshots", {
        data: {
            type: "appScreenshots",
            attributes: { fileName: basename(path), fileSize: bytes.length },
            relationships: { appScreenshotSet: { data: { type: "appScreenshotSets", id: setId } } },
        },
    });
    const screenshot = reservation.data;
    for (const operation of screenshot.attributes.uploadOperations ?? []) {
        const response = await fetch(operation.url, {
            method: operation.method,
            headers: Object.fromEntries(operation.requestHeaders.map((header) => [header.name, header.value])),
            body: bytes.subarray(operation.offset, operation.offset + operation.length),
        });
        if (!response.ok) throw new Error(`Uploading ${basename(path)} returned ${response.status}: ${await response.text()}`);
    }
    await asc.patch(`/v1/appScreenshots/${screenshot.id}`, {
        data: {
            type: "appScreenshots",
            id: screenshot.id,
            attributes: { uploaded: true, sourceFileChecksum: createHash("md5").update(bytes).digest("hex") },
        },
    });
    // Apple usually takes seconds, but sometimes minutes, so allow ten.
    for (let attempt = 1; attempt <= 120; attempt++) {
        const current = await asc.get<Resource<Screenshot>>(`/v1/appScreenshots/${screenshot.id}`);
        const state = current.data.attributes.assetDeliveryState;
        if (state?.state === "COMPLETE") return screenshot.id;
        if (state?.state === "FAILED") {
            throw new Error(`${basename(path)} failed processing: ${JSON.stringify(state.errors)}`);
        }
        await new Promise((resolve) => setTimeout(resolve, 5_000));
    }
    throw new Error(`${basename(path)} did not finish processing in ten minutes`);
}

try {
    await main();
} catch (error) {
    console.error(`error: ${errorMessage(error)}`);
    process.exitCode = 1;
}
