// Prepares the editable App Store version: gives it its version number and
// attaches a build.
//
//   --version 1.3   Work on version 1.3. If the editable version has another
//                   number, renumber it (App Store Connect allows that until it
//                   is submitted); if there is no editable version, create 1.3.
//   --build latest  Attach the newest processed (VALID) build whose version,
//                   its CFBundleShortVersionString, is the version's number. If
//                   the newest upload is still processing, wait for it, for up
//                   to 20 minutes.
//   --dry-run       Say what would change; write nothing and do not wait.
//
// With neither --version nor --build it reports the editable version and its
// build.
//
// Usage: node scripts/asc-version.ts [--version 1.3] [--build latest] [--dry-run]
// Needs ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_CONTENT (see scripts/asc.ts). In
// CI, the "App Store listing" workflow with "prepare version" ticked runs it
// with --version only: the release workflow uploads the build and attaches it.

import { parseArgs } from "node:util";
import {
    AppStoreConnect,
    AppStoreConnectError,
    editableVersions,
    errorMessage,
    findApp,
    query,
    versionState,
    type AppStoreVersionAttributes,
    type Resource,
    editableAppInfo,
} from "./asc.ts";

const bundleId = process.env.BUNDLE_ID ?? "net.serby.Cards";
const platform = "IOS";
const processingTimeoutMinutes = 20;
const pollSeconds = 30;

interface BuildAttributes {
    /// The build number, CFBundleVersion.
    version: string;
    uploadedDate?: string;
    processingState?: string;
    expired?: boolean;
    buildAudienceType?: string | null;
}

type Build = Resource<BuildAttributes>;

/// The version being prepared. It has no ID when a dry run would have created it.
interface PreparedVersion {
    id?: string;
    versionString: string;
}

let dryRun = false;

function sleep(seconds: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, seconds * 1_000));
}

function describeVersion(version: Resource<AppStoreVersionAttributes>): string {
    return `${version.attributes.versionString} (${versionState(version)})`;
}

function describeBuild(versionString: string, build: Build): string {
    const uploaded = build.attributes.uploadedDate ? `, uploaded ${new Date(build.attributes.uploadedDate).toISOString().slice(0, 16).replace("T", " ")} UTC` : "";
    return `${versionString} (${build.attributes.version}${uploaded})`;
}

function processingState(build: Build): string {
    return build.attributes.processingState ?? "UNKNOWN";
}

async function prepareVersion(asc: AppStoreConnect, appId: string, target: string | undefined): Promise<PreparedVersion> {
    const versions = await editableVersions(asc, appId, platform);
    if (versions.length > 1) {
        const match = target ? versions.find((version) => version.attributes.versionString === target) : undefined;
        if (!match) throw new Error(`Several editable versions (${versions.map(describeVersion).join(", ")}); pick one with --version`);
        console.log(`Version: ${describeVersion(match)}`);
        return { id: match.id, versionString: match.attributes.versionString };
    }

    const [current] = versions;
    if (!current) {
        if (!target) throw new Error("No editable App Store version; pass --version to create one");
        if (dryRun) {
            console.log(`Version: none is editable; would create ${target}`);
            return { versionString: target };
        }
        const created = await asc.post<Resource<AppStoreVersionAttributes>>("/v1/appStoreVersions", {
            data: {
                type: "appStoreVersions",
                attributes: { platform, versionString: target },
                relationships: { app: { data: { type: "apps", id: appId } } },
            },
        });
        console.log(`Version: none was editable; created ${describeVersion(created.data)}`);
        return { id: created.data.id, versionString: target };
    }

    if (!target || current.attributes.versionString === target) {
        console.log(`Version: ${describeVersion(current)}${target ? ", already numbered" : ""}`);
        return { id: current.id, versionString: current.attributes.versionString };
    }
    console.log(`Version: ${dryRun ? "would renumber" : "renumbering"} ${current.attributes.versionString} to ${target} (${versionState(current)})`);
    if (!dryRun) {
        await asc.patch(`/v1/appStoreVersions/${current.id}`, {
            data: { type: "appStoreVersions", id: current.id, attributes: { versionString: target } },
        });
    }
    return { id: current.id, versionString: target };
}

async function attachedBuild(asc: AppStoreConnect, versionId: string): Promise<Build | undefined> {
    try {
        return (await asc.get<Build | null>(`/v1/appStoreVersions/${versionId}/build`)).data ?? undefined;
    } catch (error) {
        // No build attached can come back as a 404 rather than null data.
        if (error instanceof AppStoreConnectError && error.status === 404) return undefined;
        throw error;
    }
}

/// Unexpired builds of this version that can go to the App Store, newest upload first.
async function buildsOf(asc: AppStoreConnect, appId: string, versionString: string): Promise<Build[]> {
    const page = await asc.get<Build[]>(
        `/v1/builds?${query({
            "filter[app]": appId,
            "filter[preReleaseVersion.version]": versionString,
            "filter[preReleaseVersion.platform]": platform,
            "filter[expired]": "false",
            sort: "-uploadedDate",
            include: "preReleaseVersion",
            limit: 50,
        })}`,
    );
    // The filter should already have done this; check, since App Store Connect
    // would only reject a build of another version later, at submission.
    const preReleaseVersions = new Map(
        (page.included ?? []).filter((resource) => resource.type === "preReleaseVersions").map((resource) => [resource.id, resource.attributes.version]),
    );
    const uploaded = (build: Build): number => Date.parse(build.attributes.uploadedDate ?? "") || 0;
    return page.data
        .filter((build) => {
            const link = build.relationships?.preReleaseVersion?.data;
            const id = link && !Array.isArray(link) ? link.id : undefined;
            // Builds for internal testing only can never be attached to an App Store version.
            return (id === undefined || preReleaseVersions.get(id) === versionString) && build.attributes.buildAudienceType !== "INTERNAL_ONLY";
        })
        .sort((left, right) => uploaded(right) - uploaded(left));
}

function noBuildError(versionString: string): Error {
    return new Error(`No unexpired App Store build of ${versionString}. Upload one with make deploy-testflight, or tag v${versionString}, whose release workflow uploads and attaches its own`);
}

async function waitForProcessing(asc: AppStoreConnect, versionString: string, build: Build): Promise<Build> {
    console.log(`Build: ${describeBuild(versionString, build)} is still processing; waiting up to ${processingTimeoutMinutes} minutes`);
    const started = Date.now();
    for (let poll = 1; ; poll++) {
        await sleep(pollSeconds);
        const current = (await asc.get<Build>(`/v1/builds/${build.id}`)).data;
        const minutes = Math.round((Date.now() - started) / 60_000);
        if (processingState(current) !== "PROCESSING") {
            console.log(`   ${processingState(current)} after ${minutes} min`);
            return current;
        }
        if (Date.now() - started >= processingTimeoutMinutes * 60_000) {
            throw new Error(`Build ${describeBuild(versionString, build)} was still processing after ${processingTimeoutMinutes} minutes; run again once Apple has finished`);
        }
        if (poll % 4 === 0) console.log(`   still processing after ${minutes} min`);
    }
}

async function attachLatestBuild(asc: AppStoreConnect, appId: string, version: PreparedVersion): Promise<void> {
    const { versionString } = version;
    const attached = version.id ? await attachedBuild(asc, version.id) : undefined;
    const builds = await buildsOf(asc, appId, versionString);
    let newest = builds[0];
    if (!newest) throw noBuildError(versionString);

    if (processingState(newest) === "PROCESSING") {
        if (dryRun) {
            console.log(`Build: ${describeBuild(versionString, newest)} is still processing; would wait up to ${processingTimeoutMinutes} minutes, then attach it`);
            return;
        }
        newest = await waitForProcessing(asc, versionString, newest);
    }

    const chosen = processingState(newest) === "VALID" ? newest : builds.find((build) => processingState(build) === "VALID");
    if (chosen !== newest) {
        console.log(`!! The newest build, ${describeBuild(versionString, newest)}, is ${processingState(newest)}`);
    }
    if (!chosen) throw new Error(`No valid build of ${versionString} to attach`);
    if (attached?.id === chosen.id) {
        console.log(`Build: ${describeBuild(versionString, chosen)}, already attached`);
        return;
    }
    const replacing = attached ? ` in place of build ${attached.attributes.version}` : "";
    console.log(`Build: ${dryRun ? "would attach" : "attaching"} ${describeBuild(versionString, chosen)}${replacing}`);
    if (!dryRun && version.id) {
        await asc.request("PATCH", `/v1/appStoreVersions/${version.id}/relationships/build`, { data: { type: "builds", id: chosen.id } });
    }
}

/// Answers App Store Connect can do without: overrides and links, not questions.
const optionalAgeRatingFields = new Set([
    "kidsAgeBand", "ageRatingOverride", "ageRatingOverrideV2", "koreaAgeRatingOverride",
    "gracRatingClassificationNumber", "developerAgeRatingInfoUrl", "socialMediaAgeRestricted",
]);

/// Reports age rating questions still unanswered. App Store Connect refuses to
/// submit a version while any is, as it did on 3 November 2026 for socialMedia.
async function reportAgeRating(asc: AppStoreConnect, appId: string): Promise<void> {
    const info = await editableAppInfo(asc, appId);
    if (!info) {
        console.log("Age rating: no app info is being prepared");
        return;
    }
    const declaration = await asc.get<Resource<Record<string, unknown>>>(`/v1/appInfos/${info.id}/ageRatingDeclaration`);
    const fields = Object.entries(declaration.data.attributes);
    const unanswered = fields.filter(([name, value]) => value === null && !optionalAgeRatingFields.has(name)).map(([name]) => name);
    console.log(unanswered.length === 0
        ? `Age rating: all ${fields.length - optionalAgeRatingFields.size} questions answered`
        : `Age rating: ${unanswered.length} unanswered: ${unanswered.join(", ")}`);
}

async function main(): Promise<void> {
    const { values } = parseArgs({
        args: process.argv.slice(2),
        options: { version: { type: "string" }, build: { type: "string" }, "dry-run": { type: "boolean", default: false } },
        strict: true,
        allowPositionals: false,
    });
    dryRun = values["dry-run"];
    const target = values.version;
    if (target !== undefined && !/^\d+(\.\d+){0,2}$/.test(target)) throw new Error(`--version ${target} is not a version number such as 1.3 or 1.3.1`);
    if (values.build !== undefined && values.build !== "latest") throw new Error(`--build takes "latest", not "${values.build}"`);

    const asc = new AppStoreConnect();
    const app = await findApp(asc, bundleId);
    console.log(`==> ${bundleId}${dryRun ? ", dry run: nothing will be written" : ""}`);
    // Look before renumbering, so a mistyped version number changes nothing.
    if (values.build === "latest" && target && (await buildsOf(asc, app.id, target)).length === 0) throw noBuildError(target);
    const version = await prepareVersion(asc, app.id, target);

    if (values.build === "latest") {
        await attachLatestBuild(asc, app.id, version);
    } else if (version.id) {
        const attached = await attachedBuild(asc, version.id);
        console.log(`Build: ${attached ? `build ${attached.attributes.version} attached` : "none attached"}`);
    }
    await reportAgeRating(asc, app.id);
    console.log(dryRun ? "Dry run: nothing was written." : "Done.");
}

try {
    await main();
} catch (error) {
    console.error(`error: ${errorMessage(error)}`);
    process.exitCode = 1;
}
