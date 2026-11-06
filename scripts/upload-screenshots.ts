// Replaces the App Store screenshots of the editable App Store version with
// the store images in screenshots/store/<locale>/*.png, in file-name order.
// The raw captures in screenshots/<locale>/, which CI compares against, are
// never uploaded.
//
// Each image's display type comes from its pixel size. For every display type
// it has images for, the set ends up holding exactly those, in order: images
// already there with the same name and checksum are kept, anything else is
// deleted, and the rest are sent. A run after a slow or stopped one therefore
// only sends what is missing, and then waits for Apple to process everything.
// Display types it has no images for are left alone.
//
// Usage: node scripts/upload-screenshots.ts [--version 1.3] [--dry-run] [--replace]
//   --replace  send every image again, even ones already there
// Needs ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_CONTENT (see
// scripts/lib/app-store-connect.ts). In CI, run the "App Store listing"
// workflow, which has them.

import { createHash } from "node:crypto";
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { basename, join } from "node:path";
import { AppStoreConnect, AppStoreConnectError, editableVersions, errorMessage, findApp, versionState, type Resource } from "./lib/app-store-connect.ts";

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
    sourceFileChecksum?: string | null;
    assetDeliveryState?: { state: string; errors?: { code: string; description: string }[] };
    uploadOperations?: { method: string; url: string; offset: number; length: number; requestHeaders: { name: string; value: string }[] }[];
}

const args = process.argv.slice(2);
// A mistyped flag (--dryrun) must not turn into a real upload.
for (const [index, arg] of args.entries()) {
    const isValue = index > 0 && args[index - 1] === "--version";
    if (!isValue && !["--version", "--dry-run", "--replace"].includes(arg)) {
        console.error(`error: unknown argument ${arg}`);
        process.exit(1);
    }
}
const dryRun = args.includes("--dry-run");
const replaceAll = args.includes("--replace");
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
            await syncScreenshots(asc, set, locale, group.map((file) => join(screenshotsDir, locale, file)));
        }
    }
    if (dryRun || processing.length === 0) {
        console.log("Done. Check the version in App Store Connect.");
        return;
    }

    // Wait for every set at once: Apple processes them in parallel, and on a slow
    // day one image can take a quarter of an hour.
    console.log(`==> Waiting for Apple to process ${processing.length} screenshot(s)`);
    const states = await waitForProcessing(asc, processing);
    for (const item of processing) {
        const state = states.get(item.id);
        console.log(`   ${item.locale} ${item.type}: ${item.name} ${state === "COMPLETE" ? "✓" : `!! ${state}`}`);
        if (state !== "COMPLETE") unfinishedScreenshots.push(`${item.locale} ${item.name} (${state})`);
    }
    console.log("Done. Check the version in App Store Connect.");
}

/// Screenshots uploaded or kept this run that Apple has not finished processing.
const processing: { id: string; name: string; locale: string; type: string }[] = [];

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

/// Makes the set hold exactly `paths`, in order. A screenshot already there
/// with the same file name and checksum is kept, whether processed or still
/// processing, so a run after a slow or stopped one only sends what is missing.
/// Anything else in the set, and any failed or half-uploaded copy, is deleted.
/// With --replace every screenshot is sent again.
async function syncScreenshots(
    asc: AppStoreConnect,
    set: Resource<{ screenshotDisplayType: string }>,
    locale: string,
    paths: string[],
): Promise<void> {
    const type = set.attributes.screenshotDisplayType;
    const existing = set.id === "dry-run" ? [] : await asc.all<Screenshot>(`/v1/appScreenshotSets/${set.id}/appScreenshots`);
    const reusable = (screenshot: Resource<Screenshot>, name: string, checksum: string) =>
        !replaceAll &&
        screenshot.attributes.fileName === name &&
        screenshot.attributes.sourceFileChecksum === checksum &&
        ["COMPLETE", "UPLOAD_COMPLETE"].includes(screenshot.attributes.assetDeliveryState?.state ?? "");

    const plan = paths.map((path) => {
        const name = basename(path);
        const checksum = createHash("md5").update(readFileSync(path)).digest("hex");
        const kept = existing.find((screenshot) => reusable(screenshot, name, checksum));
        return { path, name, kept };
    });
    const keptIds = new Set(plan.flatMap(({ kept }) => (kept ? [kept.id] : [])));
    const stale = existing.filter((screenshot) => !keptIds.has(screenshot.id));
    const toSend = plan.filter(({ kept }) => !kept);

    if (dryRun) {
        const summary = toSend.length === 0 && stale.length === 0
            ? "unchanged"
            : `would send ${toSend.map(({ name }) => name).join(", ") || "nothing"}${stale.length > 0 ? ` and delete ${stale.length} old` : ""}`;
        console.log(`   ${type}: ${summary}`);
        return;
    }
    for (const screenshot of stale) {
        await asc.delete(`/v1/appScreenshots/${screenshot.id}`);
    }
    if (stale.length > 0) console.log(`   ${type}: deleted ${stale.length} old screenshot(s)`);

    const ids: string[] = [];
    for (const item of plan) {
        const id = item.kept?.id ?? await upload(asc, set.id, item.path);
        ids.push(id);
        if (item.kept?.attributes.assetDeliveryState?.state !== "COMPLETE") {
            processing.push({ id, name: item.name, locale, type });
        }
    }
    console.log(`   ${type}: ${toSend.length === 0 ? "all already there" : `sent ${toSend.map(({ name }) => name).join(", ")}`}`);
    // Upload order is display order, but say so explicitly.
    await asc.request("PATCH", `/v1/appScreenshotSets/${set.id}/relationships/appScreenshots`, {
        data: ids.map((id) => ({ type: "appScreenshots", id })),
    });
}

/// Screenshots that had not processed when the wait ran out, reported at the end.
const unfinishedScreenshots: string[] = [];

/// Uploads one image and returns its ID, without waiting for Apple to process it.
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
    return screenshot.id;
}

/// Each screenshot's last delivery state, once all are COMPLETE or FAILED, or
/// after 25 minutes. Apple usually takes seconds, but sometimes many minutes.
async function waitForProcessing(asc: AppStoreConnect, screenshots: { id: string; name: string }[]): Promise<Map<string, string>> {
    const states = new Map<string, string>();
    const deadline = Date.now() + 25 * 60 * 1000;
    while (Date.now() < deadline) {
        for (const { id, name } of screenshots) {
            if (states.get(id) === "COMPLETE" || states.get(id) === "FAILED") continue;
            const current = await asc.get<Resource<Screenshot>>(`/v1/appScreenshots/${id}`);
            const delivery = current.data.attributes.assetDeliveryState;
            states.set(id, delivery?.state ?? "UNKNOWN");
            if (delivery?.state === "FAILED") {
                console.log(`   !! ${name} failed processing: ${JSON.stringify(delivery.errors)}`);
            }
        }
        if (screenshots.every(({ id }) => states.get(id) === "COMPLETE" || states.get(id) === "FAILED")) break;
        await new Promise((resolve) => setTimeout(resolve, 10_000));
    }
    return states;
}

try {
    await main();
    if (unfinishedScreenshots.length > 0) {
        throw new Error(`these screenshots did not finish processing: ${unfinishedScreenshots.join(", ")}`);
    }
} catch (error) {
    console.error(`error: ${errorMessage(error)}`);
    process.exitCode = 1;
}
