// Installs an App Store provisioning profile for each bundle ID, creating or
// renewing it through the App Store Connect API when needed.
//
// Profiles are not secret (every .ipa embeds one), so CI fetches them fresh
// rather than keeping copies in secrets that go stale whenever a capability
// changes: Apple marks a profile invalid when its App ID changes, and this
// replaces it. Each profile is named "Cards CI App Store <bundle ID>", the name
// scripts/build-ipa.sh signs with.
//
// The App IDs and their App Group must already exist: Xcode registers them the
// first time someone builds for a device (`make device`). The API cannot assign
// App Groups, so this script does not try to create App IDs.
//
// Usage: KEYCHAIN_PATH=... node scripts/asc-profiles.ts net.serby.Cards net.serby.Cards.Widget
//   KEYCHAIN_PATH  keychain holding the Apple Distribution certificate to sign with

import { execFileSync } from "node:child_process";
import { X509Certificate } from "node:crypto";
import { mkdirSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { AppStoreConnect, query, type Resource } from "./asc.ts";

export const profileName = (bundleId: string): string => `Cards CI App Store ${bundleId}`;

interface BundleId {
    identifier: string;
    platform: string;
}

interface Certificate {
    serialNumber: string;
    certificateType: string;
    displayName: string;
}

interface Profile {
    name: string;
    profileState: "ACTIVE" | "INVALID";
    profileContent: string;
    uuid: string;
    expirationDate: string;
}

const normaliseSerial = (serial: string): string => serial.replace(/^0+/, "").toUpperCase();

/// Serial numbers of the distribution certificates in the keychain.
function keychainSerials(keychain: string | undefined): Set<string> {
    const pem = execFileSync(
        "security",
        ["find-certificate", "-a", "-c", "Apple Distribution", "-p", ...(keychain ? [keychain] : [])],
        { encoding: "utf8" },
    );
    const certificates = pem.match(/-----BEGIN CERTIFICATE-----[\s\S]+?-----END CERTIFICATE-----/g) ?? [];
    return new Set(certificates.map((text) => normaliseSerial(new X509Certificate(text).serialNumber)));
}

async function main(): Promise<void> {
    const bundleIds = process.argv.slice(2);
    if (bundleIds.length === 0) throw new Error("Usage: node scripts/asc-profiles.ts <bundle ID>...");
    const asc = new AppStoreConnect();

    const serials = keychainSerials(process.env.KEYCHAIN_PATH);
    if (serials.size === 0) throw new Error("No Apple Distribution certificate in the keychain");
    const certificates = await asc.all<Certificate>(
        `/v1/certificates?${query({ "filter[certificateType]": "DISTRIBUTION,IOS_DISTRIBUTION", limit: 200 })}`,
    );
    const certificate = certificates.find((candidate) => serials.has(normaliseSerial(candidate.attributes.serialNumber)));
    if (!certificate) {
        throw new Error(`None of the team's distribution certificates matches the keychain (${[...serials].join(", ")})`);
    }
    console.log(`Signing with ${certificate.attributes.displayName} (${certificate.id})`);

    const directory = join(homedir(), "Library", "MobileDevice", "Provisioning Profiles");
    mkdirSync(directory, { recursive: true });

    for (const identifier of bundleIds) {
        const bundles = await asc.all<BundleId>(`/v1/bundleIds?${query({ "filter[identifier]": identifier, limit: 200 })}`);
        // The filter matches prefixes too: net.serby.Cards also finds net.serby.Cards.Widget.
        const bundle = bundles.find((candidate) => candidate.attributes.identifier === identifier);
        if (!bundle) {
            throw new Error(`No App ID ${identifier}. Build for a device in Xcode once (make device) to register it.`);
        }

        const profile = await currentProfile(asc, bundle, certificate.id) ?? await createProfile(asc, bundle, certificate.id);
        const path = join(directory, `${profile.attributes.uuid}.mobileprovision`);
        writeFileSync(path, Buffer.from(profile.attributes.profileContent, "base64"));
        console.log(`${identifier}: "${profile.attributes.name}" (expires ${profile.attributes.expirationDate.slice(0, 10)})`);
    }
}

/// The named profile if it is still usable: active, not about to expire, and
/// signed by `certificateId`. Anything else under the name is deleted.
async function currentProfile(
    asc: AppStoreConnect,
    bundle: Resource<BundleId>,
    certificateId: string,
): Promise<Resource<Profile> | undefined> {
    const name = profileName(bundle.attributes.identifier);
    const profiles = await asc.all<Profile>(
        `/v1/bundleIds/${bundle.id}/profiles?${query({ "fields[profiles]": "name,profileState,profileContent,uuid,expirationDate,certificates", include: "certificates", limit: 200 })}`,
    );
    let usable: Resource<Profile> | undefined;
    for (const profile of profiles.filter((candidate) => candidate.attributes.name === name)) {
        const linked = profile.relationships?.certificates?.data;
        const certificateIds = Array.isArray(linked) ? linked.map((item) => item.id) : [];
        const expiresSoon = Date.parse(profile.attributes.expirationDate) - Date.now() < 7 * 24 * 60 * 60 * 1000;
        if (!usable && profile.attributes.profileState === "ACTIVE" && !expiresSoon && certificateIds.includes(certificateId)) {
            usable = profile;
        } else {
            console.log(`Deleting stale profile "${name}" (${profile.attributes.profileState})`);
            await asc.delete(`/v1/profiles/${profile.id}`);
        }
    }
    return usable;
}

async function createProfile(asc: AppStoreConnect, bundle: Resource<BundleId>, certificateId: string): Promise<Resource<Profile>> {
    const name = profileName(bundle.attributes.identifier);
    console.log(`Creating profile "${name}"`);
    const created = await asc.post<Resource<Profile>>("/v1/profiles", {
        data: {
            type: "profiles",
            attributes: { name, profileType: "IOS_APP_STORE" },
            relationships: {
                bundleId: { data: { type: "bundleIds", id: bundle.id } },
                certificates: { data: [{ type: "certificates", id: certificateId }] },
            },
        },
    });
    return created.data;
}

if (import.meta.main) {
    await main();
}
