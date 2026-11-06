// Uploads the App Store listing text in metadata/ to the editable App Store
// version, after the checks in scripts/check-metadata.ts pass.
//
//   App info, per locale: name, subtitle, privacy_url
//   Version, per locale:  description, keywords, promotional_text,
//                         marketing_url, support_url, and release_notes as
//                         "What's New"
//   Version:              copyright.txt, and en-GB's review_notes as the notes
//                         for App Review
//
// A localisation App Store Connect lacks is created; one it has that metadata/
// lacks is left alone. Fields that already match are not sent, a field whose
// file is absent is not touched, and an empty file clears the field.
//
// Usage: node scripts/upload-metadata.ts [--version 1.3] [--dry-run]
// --version picks the editable version by its number (default: the only one).
// --dry-run shows each change, current against new, and writes nothing.
// Needs ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_CONTENT (see
// scripts/lib/app-store-connect.ts). In CI, run the "App Store listing"
// workflow, which has them.

import { parseArgs } from "node:util";
import {
    AppStoreConnect,
    AppStoreConnectError,
    editableVersions,
    errorMessage,
    findApp,
    versionState,
    type AppStoreVersionAttributes,
    type Resource,
    editableAppInfoStates,
} from "./lib/app-store-connect.ts";
import { checkMetadata, hasErrors, printReport, reviewNotesLocale, type Field, type LocaleMetadata } from "./check-metadata.ts";

const bundleId = process.env.BUNDLE_ID ?? "net.serby.Cards";
/// App info states in which its localisations can still be edited.
/// How much of a long value a change line shows.
const previewWidth = 56;

/// metadata/ field to App Store Connect attribute.
const appInfoFields: [Field, string][] = [
    ["name", "name"],
    ["subtitle", "subtitle"],
    ["privacy_url", "privacyPolicyUrl"],
];
const versionFields: [Field, string][] = [
    ["description", "description"],
    ["keywords", "keywords"],
    ["promotional_text", "promotionalText"],
    ["marketing_url", "marketingUrl"],
    ["support_url", "supportUrl"],
    ["release_notes", "whatsNew"],
];

type Attributes = Record<string, string | null>;
type AnyResource = Resource<Record<string, unknown>>;

let dryRun = false;
let changeCount = 0;

function quote(chars: string[], start: number): string {
    const end = Math.min(chars.length, start + previewWidth);
    return JSON.stringify(`${start > 0 ? "…" : ""}${chars.slice(start, end).join("")}${end < chars.length ? "…" : ""}`);
}

/// A change on one line: short values whole, long ones from just before where they first differ.
function describeChange(before: string, after: string): string {
    const old = [...before];
    const updated = [...after];
    const long = old.length > previewWidth || updated.length > previewWidth;
    if (old.length === 0) return `(empty) → ${quote(updated, 0)}${long ? ` (${updated.length} characters)` : ""}`;
    if (updated.length === 0) return `${quote(old, 0)} → (empty)`;
    let first = 0;
    while (first < old.length && first < updated.length && old[first] === updated[first]) first++;
    const start = long ? Math.max(0, first - 16) : 0;
    const lengths = old.length === updated.length ? `${old.length} characters` : `${old.length} → ${updated.length} characters`;
    const where = start > 0 ? `, first difference at character ${first + 1}` : "";
    return `${quote(old, start)} → ${quote(updated, start)}${long ? ` (${lengths}${where})` : ""}`;
}

/// The attributes metadata/ sets for these fields; an empty file clears its field.
function desired(metadata: LocaleMetadata, fields: [Field, string][]): Attributes {
    const attributes: Attributes = {};
    for (const [field, attribute] of fields) {
        const value = metadata[field];
        if (value !== undefined) attributes[attribute] = value === "" ? null : value;
    }
    return attributes;
}

/// The attributes that differ from App Store Connect's, each logged on its own line.
function changes(label: string, current: Record<string, unknown>, wanted: Attributes): Attributes {
    const result: Attributes = {};
    for (const [attribute, value] of Object.entries(wanted)) {
        const raw = current[attribute];
        const before = typeof raw === "string" ? raw : "";
        if (before === (value ?? "")) continue;
        result[attribute] = value;
        console.log(`   ${label ? `${label} ` : ""}${attribute}: ${describeChange(before, value ?? "")}`);
    }
    changeCount += Object.keys(result).length;
    return result;
}

/// Brings one kind of localisation (app info or version) in line with metadata/.
async function syncLocalizations(
    asc: AppStoreConnect,
    type: "appInfoLocalizations" | "appStoreVersionLocalizations",
    parent: { relationship: string; type: string; id: string },
    fields: [Field, string][],
    locales: Map<string, LocaleMetadata>,
): Promise<void> {
    const parentPath = `/v1/${parent.type}/${parent.id}/${type}`;
    const existing = await asc.all<Record<string, unknown>>(parentPath);
    for (const [locale, metadata] of locales) {
        const wanted = desired(metadata, fields);
        const current = existing.find((candidate) => candidate.attributes.locale === locale);
        if (!current) {
            console.log(`   ${locale}: not in App Store Connect; ${dryRun ? "would create it" : "creating it"}`);
            const update = changes(locale, {}, wanted);
            if (dryRun) continue;
            const attributes = Object.fromEntries(Object.entries(update).filter(([, value]) => value !== null));
            await asc.post(`/v1/${type}`, {
                data: {
                    type,
                    attributes: { locale, ...attributes },
                    relationships: { [parent.relationship]: { data: { type: parent.type, id: parent.id } } },
                },
            });
            continue;
        }
        const update = changes(locale, current.attributes, wanted);
        if (Object.keys(update).length === 0) {
            console.log(`   ${locale}: unchanged`);
            continue;
        }
        if (!dryRun) await asc.patch(`/v1/${type}/${current.id}`, { data: { type, id: current.id, attributes: update } });
    }
    for (const extra of existing.filter((candidate) => !locales.has(String(candidate.attributes.locale)))) {
        console.log(`   ${String(extra.attributes.locale)}: not in metadata/; left alone`);
    }
}

async function chooseVersion(asc: AppStoreConnect, appId: string, versionString: string | undefined): Promise<Resource<AppStoreVersionAttributes>> {
    const versions = await editableVersions(asc, appId);
    const listed = versions.map((version) => `${version.attributes.versionString} (${versionState(version)})`).join(", ") || "none";
    if (versionString) {
        const match = versions.find((version) => version.attributes.versionString === versionString);
        if (!match) {
            throw new Error(`No editable App Store version ${versionString} (editable: ${listed}). Prepare it with: node scripts/prepare-app-store-version.ts --version ${versionString}`);
        }
        return match;
    }
    const [only, ...others] = versions;
    if (!only) throw new Error("No editable App Store version. Create one with: node scripts/prepare-app-store-version.ts --version <number>");
    if (others.length > 0) throw new Error(`Several editable App Store versions (${listed}); pick one with --version`);
    return only;
}

async function updateAppInfo(asc: AppStoreConnect, appId: string, locales: Map<string, LocaleMetadata>): Promise<void> {
    const infos = await asc.all<{ state?: string; appStoreState?: string }>(`/v1/apps/${appId}/appInfos`);
    const state = (info: Resource<{ state?: string; appStoreState?: string }>): string => info.attributes.state ?? info.attributes.appStoreState ?? "unknown";
    const info = infos.find((candidate) => editableAppInfoStates.includes(state(candidate)));
    if (!info) throw new Error(`No editable app info (app infos are ${infos.map(state).join(", ") || "missing"})`);
    console.log(`App info localisations (app info ${state(info)})`);
    await syncLocalizations(asc, "appInfoLocalizations", { relationship: "appInfo", type: "appInfos", id: info.id }, appInfoFields, locales);
}

async function updateVersionLocalizations(asc: AppStoreConnect, versionId: string, locales: Map<string, LocaleMetadata>): Promise<void> {
    console.log("Version localisations");
    await syncLocalizations(asc, "appStoreVersionLocalizations", { relationship: "appStoreVersion", type: "appStoreVersions", id: versionId }, versionFields, locales);
}

async function updateReviewNotes(asc: AppStoreConnect, versionId: string, notes: string | undefined): Promise<void> {
    console.log(`Review notes (from ${reviewNotesLocale})`);
    if (notes === undefined) {
        console.log(`   no ${reviewNotesLocale}/review_notes.txt; left alone`);
        return;
    }
    let detail: AnyResource | undefined;
    try {
        detail = (await asc.get<AnyResource | null>(`/v1/appStoreVersions/${versionId}/appStoreReviewDetail`)).data ?? undefined;
    } catch (error) {
        // A version that has never had review details answers 404.
        if (!(error instanceof AppStoreConnectError && error.status === 404)) throw error;
    }
    const update = changes("", detail?.attributes ?? {}, { notes: notes === "" ? null : notes });
    if (Object.keys(update).length === 0) {
        console.log("   unchanged");
        return;
    }
    if (dryRun) return;
    if (detail) {
        await asc.patch(`/v1/appStoreReviewDetails/${detail.id}`, { data: { type: "appStoreReviewDetails", id: detail.id, attributes: update } });
    } else {
        await asc.post("/v1/appStoreReviewDetails", {
            data: {
                type: "appStoreReviewDetails",
                attributes: update,
                relationships: { appStoreVersion: { data: { type: "appStoreVersions", id: versionId } } },
            },
        });
    }
}

async function updateCopyright(asc: AppStoreConnect, version: Resource<AppStoreVersionAttributes>, copyright: string | undefined): Promise<void> {
    console.log("Version");
    if (copyright === undefined) {
        console.log("   no copyright.txt; left alone");
        return;
    }
    const update = changes("", { copyright: version.attributes.copyright }, { copyright: copyright === "" ? null : copyright });
    if (Object.keys(update).length === 0) {
        console.log("   copyright: unchanged");
        return;
    }
    if (!dryRun) await asc.patch(`/v1/appStoreVersions/${version.id}`, { data: { type: "appStoreVersions", id: version.id, attributes: update } });
}

async function main(): Promise<void> {
    const { values } = parseArgs({
        args: process.argv.slice(2),
        options: { version: { type: "string" }, "dry-run": { type: "boolean", default: false } },
        strict: true,
        allowPositionals: false,
    });
    dryRun = values["dry-run"];

    const report = checkMetadata();
    printReport(report);
    if (hasErrors(report)) throw new Error("metadata/ has errors (listed above), so nothing was uploaded");
    console.log("");

    const asc = new AppStoreConnect();
    const app = await findApp(asc, bundleId);
    const version = await chooseVersion(asc, app.id, values.version);
    console.log(`==> ${bundleId} ${version.attributes.versionString} (${versionState(version)})${dryRun ? ", dry run: nothing will be written" : ""}`);

    await updateAppInfo(asc, app.id, report.locales);
    await updateVersionLocalizations(asc, version.id, report.locales);
    await updateReviewNotes(asc, version.id, report.locales.get(reviewNotesLocale)?.review_notes);
    await updateCopyright(asc, version, report.copyright);

    const counted = `${changeCount} change${changeCount === 1 ? "" : "s"}`;
    if (changeCount === 0) console.log("Done: App Store Connect already matches metadata/.");
    else if (dryRun) console.log(`Dry run: ${counted} would be made; nothing was written.`);
    else console.log(`Done: ${counted} made. Check the version in App Store Connect.`);
}

try {
    await main();
} catch (error) {
    console.error(`error: ${errorMessage(error)}`);
    process.exitCode = 1;
}
