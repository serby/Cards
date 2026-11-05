// Submits an uploaded build for App Store review through the App Store Connect
// API, in six steps:
//   1. resolve the app by its bundle ID;
//   2. wait for the build with CFBundleVersion BUILD_VERSION to finish
//      processing, polling every 30 seconds for up to 30 minutes;
//   3. find the App Store version MARKETING_VERSION, or create it;
//   4. attach the build to the version;
//   5. set What's New on every localisation of the version;
//   6. submit it for review: reuse the app's review submission that is ready for
//      review, or create one, add the version to it, and submit it.
//
// scripts/release-version.ts runs it on a v* tag, after uploading the build.
//
// Usage: MARKETING_VERSION=1.3 BUILD_VERSION=... WHATS_NEW=... node scripts/submit-for-review.ts [--dry-run]
//   MARKETING_VERSION  the App Store version, such as 1.3
//   BUILD_VERSION      CFBundleVersion of the uploaded build to attach
//   WHATS_NEW          the release notes
//   BUNDLE_ID          the app (default net.serby.Cards)
//   --dry-run          report what it would do, sending only GET requests and
//                      not waiting; BUILD_VERSION and WHATS_NEW are optional
// Needs ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_CONTENT (see scripts/lib/app-store-connect.ts).

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
} from "./lib/app-store-connect.ts";

const usage = "Usage: MARKETING_VERSION=1.3 BUILD_VERSION=<CFBundleVersion> WHATS_NEW=<release notes> node scripts/submit-for-review.ts [--dry-run]";

const platform = "IOS";
/// Apple's processing takes 5 to 30 minutes: 60 polls, 30 seconds apart.
const processingAttempts = 60;
const pollSeconds = 30;

export interface SubmissionOptions {
    /// The App Store version, such as 1.3.
    marketingVersion: string;
    /// CFBundleVersion of the uploaded build. Optional in a dry run.
    buildVersion?: string;
    /// The release notes. Optional in a dry run.
    whatsNew?: string;
    /// Default net.serby.Cards.
    bundleId?: string;
    /// Report what would happen, sending only GET requests and not waiting.
    dryRun?: boolean;
}

interface BuildAttributes {
    /// The build number, CFBundleVersion.
    version: string;
    processingState?: string | null;
    uploadedDate?: string;
}

interface LocalizationAttributes {
    locale: string;
    whatsNew?: string | null;
}

interface ReviewSubmissionAttributes {
    state?: string;
}

type Build = Resource<BuildAttributes>;

function sleep(seconds: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, seconds * 1_000));
}

/// App Store Connect's whole response, which for a refused submission holds the
/// reasons (errors[].meta.associatedErrors) that errorMessage() leaves out.
function responseText(error: unknown): string {
    if (!(error instanceof AppStoreConnectError)) return errorMessage(error);
    let body = error.body;
    try {
        body = JSON.stringify(JSON.parse(error.body), null, 2);
    } catch {
        // Not JSON; show it as it came.
    }
    return `${error.method} ${error.path} returned ${error.status}:\n${body}`;
}

/// From here on, any request but a GET fails, so a dry run cannot write by mistake.
function allowOnlyGet(asc: AppStoreConnect): void {
    const request = asc.request.bind(asc);
    asc.request = <T>(method: string, path: string, body?: unknown): Promise<T> =>
        method === "GET" ? request<T>(method, path, body) : Promise.reject(new Error(`dry run: refusing to send ${method} ${path}`));
}

async function buildsOf(asc: AppStoreConnect, appId: string, marketingVersion: string, buildVersion: string): Promise<Build[]> {
    const page = await asc.get<Build[] | undefined>(
        `/v1/builds?${query({
            "filter[app]": appId,
            "filter[version]": buildVersion,
            "filter[preReleaseVersion.version]": marketingVersion,
            limit: 10,
        })}`,
    );
    return page.data ?? [];
}

function stateOf(builds: Build[]): string {
    return builds[0]?.attributes.processingState ?? "MISSING";
}

function describeBuild(build: Build): string {
    const uploaded = build.attributes.uploadedDate ? `, uploaded ${new Date(build.attributes.uploadedDate).toISOString().slice(0, 16).replace("T", " ")} UTC` : "";
    return `${build.attributes.version} (${build.attributes.processingState ?? "MISSING"}${uploaded}, id ${build.id})`;
}

/// Step 2. Returns the processed build, or in a dry run the build if it is
/// already processed.
async function waitForBuild(asc: AppStoreConnect, appId: string, options: SubmissionOptions): Promise<Build | undefined> {
    const { marketingVersion, buildVersion, dryRun } = options;
    if (dryRun) {
        console.log(`==> Checking build ${buildVersion ?? "(no BUILD_VERSION)"} of ${marketingVersion}`);
        if (!buildVersion) {
            const page = await asc.get<Build[] | undefined>(
                `/v1/builds?${query({ "filter[app]": appId, "filter[preReleaseVersion.version]": marketingVersion, sort: "-uploadedDate", limit: 5 })}`,
            );
            const recent = page.data ?? [];
            console.log(recent.length === 0
                ? `    No BUILD_VERSION given, and no build of ${marketingVersion} is uploaded yet`
                : `    No BUILD_VERSION given; the newest builds of ${marketingVersion}: ${recent.map(describeBuild).join("; ")}`);
            return undefined;
        }
        const builds = await buildsOf(asc, appId, marketingVersion, buildVersion);
        const ready = builds.find((build) => build.attributes.processingState === "VALID");
        if (ready) {
            console.log(`    Build ${buildVersion} ready (id ${ready.id})`);
            return ready;
        }
        console.log(`    Build ${buildVersion} is ${stateOf(builds)}; would wait up to ${(processingAttempts * pollSeconds) / 60} min for it to finish processing`);
        return undefined;
    }

    // Apple's processing pipeline takes 5-30 min. Poll until the build appears
    // with a valid processing state.
    console.log(`==> Waiting for build ${buildVersion} to finish processing`);
    for (let attempt = 1; attempt <= processingAttempts; attempt++) {
        const builds = await buildsOf(asc, appId, marketingVersion, buildVersion ?? "");
        const ready = builds.find((build) => build.attributes.processingState === "VALID");
        if (ready) {
            console.log(`    Build ${buildVersion} ready (id ${ready.id})`);
            return ready;
        }
        console.log(`    [${attempt}/${processingAttempts}] still ${stateOf(builds)}; sleeping ${pollSeconds}s`);
        await sleep(pollSeconds);
    }
    throw new Error(`Build ${buildVersion} did not finish processing within ${(processingAttempts * pollSeconds) / 60} min`);
}

/// Step 3. Returns the version's ID, or undefined when a dry run would create it.
async function findOrCreateVersion(asc: AppStoreConnect, appId: string, options: SubmissionOptions): Promise<string | undefined> {
    const { marketingVersion, dryRun } = options;
    console.log(`==> Finding or creating appStoreVersion ${marketingVersion}`);
    const page = await asc.get<Resource<AppStoreVersionAttributes>[] | undefined>(
        `/v1/apps/${appId}/appStoreVersions?${query({ "filter[versionString]": marketingVersion, "filter[platform]": platform })}`,
    );
    const existing = (page.data ?? [])[0];
    if (existing) {
        console.log(`    Reusing existing version ${marketingVersion} (id ${existing.id}, ${versionState(existing)})`);
        return existing.id;
    }
    if (dryRun) {
        console.log(`    Would create version ${marketingVersion}`);
        // App Store Connect keeps one editable version per platform, so creating
        // another fails while one with a different number is being prepared.
        for (const other of await editableVersions(asc, appId, platform)) {
            console.log(`    !! ${other.attributes.versionString} (${versionState(other)}) is already being prepared, so creating ${marketingVersion} would probably fail`);
        }
        return undefined;
    }
    const created = await asc.post<Resource<AppStoreVersionAttributes>>("/v1/appStoreVersions", {
        data: {
            type: "appStoreVersions",
            attributes: { platform, versionString: marketingVersion },
            relationships: { app: { data: { type: "apps", id: appId } } },
        },
    });
    console.log(`    Created version ${marketingVersion} (id ${created.data.id})`);
    return created.data.id;
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

/// Step 4.
async function attachBuild(asc: AppStoreConnect, versionId: string | undefined, build: Build | undefined, options: SubmissionOptions): Promise<void> {
    if (options.dryRun) {
        const name = build ? `${build.attributes.version} (id ${build.id})` : (options.buildVersion ?? "BUILD_VERSION");
        console.log(`==> Attaching build ${name} to version ${versionId ?? options.marketingVersion}`);
        const attached = versionId ? await attachedBuild(asc, versionId) : undefined;
        if (build && attached?.id === build.id) console.log("    Already attached; would attach it again");
        else console.log(`    Would attach it${build ? "" : " once it has processed"}${attached ? `, in place of build ${attached.attributes.version}` : ""}`);
        return;
    }
    if (!versionId || !build) throw new Error("No version or build to attach");
    console.log(`==> Attaching build ${build.id} to version ${versionId}`);
    await asc.request("PATCH", `/v1/appStoreVersions/${versionId}/relationships/build`, { data: { type: "builds", id: build.id } });
    console.log("    Attached");
}

/// Step 5.
async function setWhatsNew(asc: AppStoreConnect, versionId: string | undefined, options: SubmissionOptions): Promise<void> {
    const { whatsNew, dryRun } = options;
    console.log("==> Setting 'What's New' on all version localisations");
    if (!versionId) {
        console.log("    Would set it on every localisation of the new version");
        return;
    }
    const localizations = await asc.all<LocalizationAttributes>(`/v1/appStoreVersions/${versionId}/appStoreVersionLocalizations`);
    if (localizations.length === 0) console.log("    !! The version has no localisations");
    for (const localization of localizations) {
        const { locale } = localization.attributes;
        if (dryRun) {
            const current = localization.attributes.whatsNew ?? "";
            const note = whatsNew === undefined ? (current ? "it has one now" : "it is empty now") : current === whatsNew ? "it already reads that" : current ? "replacing what it has" : "it is empty now";
            console.log(`    ${locale}: would set What's New (${note})`);
            continue;
        }
        await asc.patch(`/v1/appStoreVersionLocalizations/${localization.id}`, {
            data: { type: "appStoreVersionLocalizations", id: localization.id, attributes: { whatsNew } },
        });
        console.log(`    ${locale} updated`);
    }
}

/// Step 6. Submission uses review submissions: one open submission per platform
/// holds the items to review, and setting submitted=true sends it to App Review.
/// (The older appStoreVersionSubmissions endpoint is deprecated.)
async function submit(asc: AppStoreConnect, appId: string, versionId: string | undefined, options: SubmissionOptions): Promise<void> {
    const { marketingVersion, dryRun } = options;
    console.log("==> Submitting version for review");
    const ready = await asc.get<Resource<ReviewSubmissionAttributes>[] | undefined>(
        `/v1/reviewSubmissions?${query({ "filter[app]": appId, "filter[platform]": platform, "filter[state]": "READY_FOR_REVIEW" })}`,
    );
    let submissionId = (ready.data ?? [])[0]?.id;

    if (dryRun) {
        if (submissionId) {
            console.log(`    Would reuse open review submission ${submissionId}`);
            await describeItems(asc, submissionId, versionId);
        } else {
            console.log("    Would create a review submission");
        }
        // Another submission still in progress may stop a new one being created.
        const all = await asc.all<ReviewSubmissionAttributes>(`/v1/reviewSubmissions?${query({ "filter[app]": appId, "filter[platform]": platform })}`);
        for (const other of all.filter((candidate) => !["READY_FOR_REVIEW", "COMPLETE"].includes(candidate.attributes.state ?? ""))) {
            console.log(`    !! Review submission ${other.id} is ${other.attributes.state ?? "in an unknown state"}`);
        }
        console.log(`    Would add version ${marketingVersion} to it and submit it for review`);
        return;
    }

    if (!versionId) throw new Error("No version to submit");
    if (!submissionId) {
        const created = await asc.post<Resource<ReviewSubmissionAttributes>>("/v1/reviewSubmissions", {
            data: {
                type: "reviewSubmissions",
                attributes: { platform },
                relationships: { app: { data: { type: "apps", id: appId } } },
            },
        });
        submissionId = created.data.id;
        console.log(`    Created review submission ${submissionId}`);
    } else {
        console.log(`    Reusing open review submission ${submissionId}`);
    }

    // A version already in this submission (a re-run) is fine, so a failure here
    // is reported but not fatal; the submit below fails loudly if nothing is in it.
    try {
        await asc.post("/v1/reviewSubmissionItems", {
            data: {
                type: "reviewSubmissionItems",
                relationships: {
                    reviewSubmission: { data: { type: "reviewSubmissions", id: submissionId } },
                    appStoreVersion: { data: { type: "appStoreVersions", id: versionId } },
                },
            },
        });
    } catch (error) {
        console.log("    Version not added (already in the submission?):");
        console.log(responseText(error));
    }

    try {
        await asc.patch(`/v1/reviewSubmissions/${submissionId}`, {
            data: { type: "reviewSubmissions", id: submissionId, attributes: { submitted: true } },
        });
    } catch (error) {
        throw new Error(`Submission failed; response below\n${responseText(error)}`);
    }
    console.log("    Submitted for review.");
    console.log("    Track at https://appstoreconnect.apple.com");
}

/// For a dry run: what an open review submission already holds.
async function describeItems(asc: AppStoreConnect, submissionId: string, versionId: string | undefined): Promise<void> {
    try {
        const items = await asc.get<Resource[] | undefined>(`/v1/reviewSubmissions/${submissionId}/items?${query({ include: "appStoreVersion" })}`);
        const versions = new Map(
            (items.included ?? []).filter((resource) => resource.type === "appStoreVersions").map((resource) => [resource.id, String(resource.attributes.versionString)]),
        );
        const held = (items.data ?? []).map((item) => {
            const link = item.relationships?.appStoreVersion?.data;
            const id = link && !Array.isArray(link) ? link.id : undefined;
            return id ? `version ${versions.get(id) ?? id}${id === versionId ? ", already in it" : ""}` : `a ${item.type} item`;
        });
        console.log(`    It holds ${held.length === 0 ? "nothing yet" : held.join(", ")}`);
    } catch (error) {
        console.log(`    Could not list its items: ${errorMessage(error)}`);
    }
}

/// Runs the six steps. Throws on any failure but adding the version to a review
/// submission, which a re-run expects.
export async function submitForReview(options: SubmissionOptions): Promise<void> {
    const dryRun = options.dryRun ?? false;
    const bundleId = options.bundleId || "net.serby.Cards";
    if (!options.marketingVersion) throw new Error("MARKETING_VERSION required (e.g. 1.1.0)");
    if (!dryRun && !options.buildVersion) throw new Error("BUILD_VERSION required (CFBundleVersion of the just-uploaded build)");
    if (!dryRun && !options.whatsNew) throw new Error("WHATS_NEW required (release notes text)");

    const asc = new AppStoreConnect();
    if (dryRun) {
        allowOnlyGet(asc);
        console.log("Dry run: only GET requests are sent, and nothing is written.");
    }

    console.log(`==> Resolving app for bundle ${bundleId}`);
    const app = await findApp(asc, bundleId);
    console.log(`    App ID: ${app.id}`);

    const build = await waitForBuild(asc, app.id, { ...options, dryRun });
    const versionId = await findOrCreateVersion(asc, app.id, { ...options, dryRun });
    await attachBuild(asc, versionId, build, { ...options, dryRun });
    await setWhatsNew(asc, versionId, { ...options, dryRun });
    await submit(asc, app.id, versionId, { ...options, dryRun });
    if (dryRun) console.log("Dry run: nothing was written.");
}

if (import.meta.main) {
    try {
        const { values } = parseArgs({
            args: process.argv.slice(2),
            options: { "dry-run": { type: "boolean", default: false }, help: { type: "boolean", short: "h", default: false } },
            strict: true,
            allowPositionals: false,
        });
        if (values.help) {
            console.log(usage);
        } else {
            await submitForReview({
                marketingVersion: process.env.MARKETING_VERSION ?? "",
                buildVersion: process.env.BUILD_VERSION || undefined,
                whatsNew: process.env.WHATS_NEW || undefined,
                bundleId: process.env.BUNDLE_ID || undefined,
                dryRun: values["dry-run"],
            });
        }
    } catch (error) {
        // GitHub Actions shows ::error:: lines as annotations on the run.
        console.error(`${process.env.GITHUB_ACTIONS === "true" ? "::error::" : "error: "}${errorMessage(error)}`);
        process.exitCode = 1;
    }
}
