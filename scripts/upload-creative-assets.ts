// Uploads each locale's creative assets, the product page header and the search
// result, screenshots/store/<locale>/<file>.png as its creative-asset.json names
// them, to the app's asset library in App Store Connect, and places each on the
// editable App Store version's localisation in its own place, which iOS 27 and
// iPadOS 27 show. App Store Connect API 4.5.1 added the asset
// library (https://developer.apple.com/documentation/appstoreconnectapi/uploading-and-managing-image-assets
// and .../placing-assets-on-your-app-store-surfaces). The placements go to
// App Review with the version.
//
// An image is reserved, uploaded and committed once, then placed. Its reference
// name carries a hash of its bytes, so a run after an unchanged asset uploads
// nothing. Which placement groups take it comes from App Store Connect's
// reference data: the groups mapped to the image specification its size meets
// for its placement (3840 x 1646 for the header, 3840 x 2560 for the search result). In each group a placement already showing this image is kept;
// any other is deleted, as a group holds one header asset, and a new one made.
// Images cannot be changed once committed, so older ones stay in the library.
//
// Usage: node scripts/upload-creative-assets.ts [--version 1.4] [--dry-run]
// Needs ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_CONTENT (see
// scripts/lib/app-store-connect.ts). In CI, run the "App Store listing"
// workflow, which has them.

import { createHash } from "node:crypto";
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { basename, join } from "node:path";
import { AppStoreConnect, editableVersions, errorMessage, findApp, query, versionState, type Resource } from "./lib/app-store-connect.ts";
import { creativeAssetKinds, parseCreativeAssets } from "./lib/store-images.ts";

const root = join(import.meta.dirname, "..");
const storeDir = join(root, "screenshots", "store");
const bundleId = process.env.BUNDLE_ID ?? "net.serby.Cards";
/// Where the assets go: the product page header and the search results.
const placementTypes = creativeAssetKinds.map((kind) => kind.placementType);
/// Image states in which an uploaded image can be placed, or already is.
const usableStates = ["PREPARE_FOR_SUBMISSION", "COMPLETE", "READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW", "ACCEPTED", "APPROVED"];

interface CreativeAsset {
    locale: string;
    /// Where it goes: the product page header or the search results.
    placementType: string;
    path: string;
    bytes: Buffer<ArrayBuffer>;
    width: number;
    height: number;
    /// Names this exact image in the library, so an unchanged one is found again.
    referenceName: string;
}

interface ImageSpec {
    specId: string;
    shortName?: string;
    dimensions?: { minWidth?: number; maxWidth?: number; minHeight?: number; maxHeight?: number };
    compatiblePlacementTypes?: string[];
    alphaAllowed?: boolean;
    maxFileSize?: number;
    universalAsset?: boolean;
}

interface RefData {
    imageSpecs?: ImageSpec[];
    placementTypes?: { placementTypeId: string; specMappings?: { placementGroupId?: string; specs?: string[] }[] }[];
}

interface LibraryImage {
    fileName?: string;
    referenceName?: string;
    specId?: string | null;
    state: string;
    stateDetails?: { code?: string; description?: string }[] | null;
    uploadOperations?: { method: string; url: string; offset: number; length: number; requestHeaders: { name: string; value: string }[] }[];
}

interface Placement {
    placementType: string;
    placementGroup?: string;
    state?: string;
}

const args = process.argv.slice(2);
// A mistyped flag (--dryrun) must not turn into a real upload.
for (const [index, arg] of args.entries()) {
    const isValue = index > 0 && args[index - 1] === "--version";
    if (!isValue && !["--version", "--dry-run"].includes(arg)) {
        console.error(`error: unknown argument ${arg}`);
        process.exit(1);
    }
}
const dryRun = args.includes("--dry-run");
const versionArgument = args.includes("--version") ? args[args.indexOf("--version") + 1] : undefined;

/// Every locale's creative asset, read from the repository.
function creativeAssets(): CreativeAsset[] {
    if (!existsSync(storeDir)) return [];
    const locales = readdirSync(storeDir).filter((name) => statSync(join(storeDir, name)).isDirectory()).sort();
    return locales.flatMap((locale): CreativeAsset[] => {
        const entryPath = join(storeDir, locale, "creative-asset.json");
        if (!existsSync(entryPath)) return [];
        const entries = parseCreativeAssets(readFileSync(entryPath, "utf8"), entryPath);
        return creativeAssetKinds.map((kind): CreativeAsset => {
            const { file } = entries[kind.key];
            const path = join(storeDir, locale, `${file}.png`);
            if (!existsSync(path)) throw new Error(`${locale}: ${file}.png is missing; run make store-screenshots`);
            const bytes = readFileSync(path);
            if (bytes.toString("latin1", 12, 16) !== "IHDR") throw new Error(`${path} is not a PNG`);
            const hash = createHash("sha256").update(bytes).digest("hex").slice(0, 12);
            return {
                locale,
                placementType: kind.placementType,
                path,
                bytes,
                width: bytes.readUInt32BE(16),
                height: bytes.readUInt32BE(20),
                referenceName: `Creative asset ${kind.key} ${locale} ${hash}`,
            };
        });
    });
}

async function main(): Promise<void> {
    const assets = creativeAssets();
    if (assets.length === 0) {
        console.log("No creative-asset.json in screenshots/store; nothing to upload.");
        return;
    }
    const asc = new AppStoreConnect();
    const app = await findApp(asc, bundleId);
    const versions = await editableVersions(asc, app.id);
    const version = versionArgument ? versions.find((candidate) => candidate.attributes.versionString === versionArgument) : versions[0];
    if (!version) throw new Error(`No editable App Store version${versionArgument ? ` ${versionArgument}` : ""}`);
    console.log(`==> ${bundleId} ${version.attributes.versionString} (${versionState(version)})${dryRun ? ", dry run" : ""}`);

    const localizations = await asc.all<{ locale: string }>(`/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations`);
    const library = (await asc.get<Resource>(`/v1/apps/${app.id}/assetLibrary`)).data;
    const refData = (await asc.all<RefData>(
        `/v1/appAssetLibraryRefData?${query({ "filter[placementTypes]": placementTypes.join(",") })}`,
    )).map((datum) => datum.attributes);

    for (const asset of assets) {
        const localization = localizations.find((candidate) => candidate.attributes.locale === asset.locale);
        if (!localization) {
            console.log(`!! ${asset.locale}: the version has no such localisation; skipping`);
            continue;
        }
        console.log(`==> ${asset.locale}: ${basename(asset.path)}`);
        const spec = specFor(refData, asset);
        const image = await libraryImage(asc, library.id, asset);
        const specId = image?.attributes.specId ?? spec.specId;
        if (image && specId !== spec.specId) {
            console.log(`   !! App Store Connect matched it to ${specId}, not ${spec.specId}`);
        }
        for (const group of placementGroups(refData, asset.placementType, specId)) {
            await place(asc, localization.id, asset.placementType, group, image?.id);
        }
    }
    console.log("Done. Check the version's product page in App Store Connect, and its preview of the header and search results.");
}

/// The image specification the asset matches for its placement, checked against
/// its limits: one made for that placement before a universal one.
function specFor(refData: RefData[], asset: CreativeAsset): ImageSpec {
    const specs = refData.flatMap((datum) => datum.imageSpecs ?? []);
    const fits = (spec: ImageSpec) => {
        const size = spec.dimensions ?? {};
        return asset.width >= (size.minWidth ?? 0) && asset.width <= (size.maxWidth ?? Infinity)
            && asset.height >= (size.minHeight ?? 0) && asset.height <= (size.maxHeight ?? Infinity);
    };
    const matching = specs.filter((candidate) => fits(candidate) && candidate.compatiblePlacementTypes?.includes(asset.placementType));
    const spec = matching.find((candidate) => candidate.universalAsset !== true) ?? matching[0];
    if (!spec) {
        const known = specs.map((candidate) => `${candidate.shortName ?? candidate.specId}${candidate.universalAsset ? " (universal)" : ""}`).join(", ");
        throw new Error(`no image specification takes ${asset.width} x ${asset.height} for ${asset.placementType}; App Store Connect has: ${known || "none"}`);
    }
    if (spec.maxFileSize !== undefined && asset.bytes.length > spec.maxFileSize) {
        throw new Error(`${asset.path} is ${asset.bytes.length} bytes, over the ${spec.maxFileSize} the specification allows`);
    }
    console.log(`   specification: ${spec.shortName ?? spec.specId}`);
    return spec;
}

/// The placement groups of `type` that take images of `specId`. A group id can
/// be absent, for a type with no groups.
function placementGroups(refData: RefData[], type: string, specId: string): (string | undefined)[] {
    const mappings = refData
        .flatMap((datum) => datum.placementTypes ?? [])
        .filter((placementType) => placementType.placementTypeId === type)
        .flatMap((placementType) => placementType.specMappings ?? [])
        .filter((mapping) => mapping.specs?.includes(specId));
    if (mappings.length === 0) throw new Error(`no ${type} placement group takes specification ${specId}`);
    return [...new Set(mappings.map((mapping) => mapping.placementGroupId))];
}

/// The library's image for this asset: one already uploaded with the same
/// bytes, or a new one, uploaded and processed. Undefined in a dry run that
/// would upload it.
async function libraryImage(asc: AppStoreConnect, libraryId: string, asset: CreativeAsset): Promise<Resource<LibraryImage> | undefined> {
    const existing = await asc.all<LibraryImage>(
        `/v1/appAssetLibraries/${libraryId}/images?${query({ "filter[referenceName]": asset.referenceName })}`,
    );
    const ready = existing.find((image) => usableStates.includes(image.attributes.state));
    if (ready) {
        console.log(`   already in the library (${ready.attributes.state})`);
        return ready;
    }
    const pending = existing.find((image) => image.attributes.state === "UPLOAD_COMPLETE");
    if (pending) return await waitForProcessing(asc, pending.id);
    if (existing.some((image) => image.attributes.state === "REJECTED")) {
        throw new Error(`App Review rejected this exact image (${asset.referenceName}); change the asset before uploading it again`);
    }
    if (dryRun) {
        console.log(`   would upload ${asset.bytes.length.toLocaleString("en-GB")} bytes`);
        return undefined;
    }
    // Abandoned or failed copies of this image would only clutter the library.
    for (const stale of existing.filter((image) => ["AWAITING_UPLOAD", "FAILED"].includes(image.attributes.state))) {
        await asc.delete(`/v1/appAssetLibraryImages/${stale.id}`);
    }

    const reservation = await asc.post<Resource<LibraryImage>>("/v1/appAssetLibraryImages", {
        data: {
            type: "appAssetLibraryImages",
            attributes: { fileName: basename(asset.path), fileSize: asset.bytes.length, category: "CREATIVE_ASSETS", referenceName: asset.referenceName },
            relationships: { assetLibrary: { data: { type: "appAssetLibraries", id: libraryId } } },
        },
    });
    const image = reservation.data;
    for (const operation of image.attributes.uploadOperations ?? []) {
        const response = await fetch(operation.url, {
            method: operation.method,
            headers: Object.fromEntries(operation.requestHeaders.map((header) => [header.name, header.value])),
            body: asset.bytes.subarray(operation.offset, operation.offset + operation.length),
        });
        if (!response.ok) throw new Error(`Uploading ${basename(asset.path)} returned ${response.status}: ${await response.text()}`);
    }
    await asc.patch(`/v1/appAssetLibraryImages/${image.id}`, {
        data: { type: "appAssetLibraryImages", id: image.id, attributes: { uploaded: true } },
    });
    console.log(`   uploaded ${asset.bytes.length.toLocaleString("en-GB")} bytes`);
    return await waitForProcessing(asc, image.id);
}

/// The image once App Store Connect has processed it, which tells which
/// specification it matched. Throws if processing fails or takes over 25 minutes.
async function waitForProcessing(asc: AppStoreConnect, id: string): Promise<Resource<LibraryImage>> {
    const deadline = Date.now() + 25 * 60 * 1000;
    while (Date.now() < deadline) {
        const image = (await asc.get<Resource<LibraryImage>>(`/v1/appAssetLibraryImages/${id}`)).data;
        const { state, stateDetails } = image.attributes;
        if (usableStates.includes(state)) {
            console.log(`   processed (${state})`);
            return image;
        }
        if (state === "FAILED" || state === "REJECTED") {
            throw new Error(`App Store Connect could not use the image (${state}): ${JSON.stringify(stateDetails ?? [])}`);
        }
        await new Promise((resolve) => setTimeout(resolve, 10_000));
    }
    throw new Error("the image was still processing after 25 minutes; run this again later, and it will pick it up");
}

/// Makes the localisation's `type` placement in `group` show the image: kept if
/// it already does, otherwise any placement there is deleted and a new one made.
async function place(asc: AppStoreConnect, localizationId: string, type: string, group: string | undefined, imageId: string | undefined): Promise<void> {
    const label = `${type}${group ? ` ${group}` : ""}`;
    const filters: Record<string, string> = { "filter[placementType]": type, include: "image" };
    if (group) filters["filter[placementGroup]"] = group;
    const placements = await asc.all<Placement>(`/v1/appStoreVersionLocalizations/${localizationId}/placements?${query(filters)}`);
    const showsImage = (placement: Resource<Placement>) => {
        const data = placement.relationships?.image?.data;
        return imageId !== undefined && !Array.isArray(data) && data?.id === imageId;
    };
    const kept = placements.find(showsImage);
    const stale = placements.filter((placement) => placement !== kept);
    if (dryRun) {
        console.log(`   ${label}: ${kept ? "unchanged" : `would place the image${stale.length > 0 ? ` and remove ${stale.length} old` : ""}`}`);
        return;
    }
    for (const placement of stale) {
        await asc.delete(`/v1/appAssetLibraryPlacements/${placement.id}`);
    }
    if (kept) {
        console.log(`   ${label}: already placed (${kept.attributes.state ?? "unknown state"})`);
        return;
    }
    if (!imageId) throw new Error("no image to place");
    await asc.post("/v1/appAssetLibraryPlacements", {
        data: {
            type: "appAssetLibraryPlacements",
            attributes: { placementType: type, ...(group ? { placementGroup: group } : {}) },
            relationships: {
                image: { data: { type: "appAssetLibraryImages", id: imageId } },
                appStoreVersionLocalization: { data: { type: "appStoreVersionLocalizations", id: localizationId } },
            },
        },
    });
    console.log(`   ${label}: placed${stale.length > 0 ? `, replacing ${stale.length} old` : ""}`);
}

try {
    await main();
} catch (error) {
    console.error(`error: ${errorMessage(error)}`);
    process.exitCode = 1;
}
