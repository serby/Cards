// A small App Store Connect API client shared by the TypeScript scripts.
//
// Credentials come from the environment, as in CI:
//   ASC_KEY_ID, ASC_ISSUER_ID, and ASC_KEY_CONTENT (the .p8 text), or a key file
//   at $API_PRIVATE_KEYS_DIR/AuthKey_<id>.p8 (default ~/.appstoreconnect/private_keys).

import { sign } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const API = "https://api.appstoreconnect.apple.com";
/// Apple allows 20 minutes; renew a little early so a long run never sends a stale one.
const TOKEN_LIFETIME_SECONDS = 15 * 60;

export interface Resource<Attributes = Record<string, unknown>> {
    type: string;
    id: string;
    attributes: Attributes;
    relationships?: Record<string, { data?: { type: string; id: string } | { type: string; id: string }[] }>;
}

interface Document<Data> {
    data: Data;
    included?: Resource[];
    links?: { next?: string };
}

export class AppStoreConnectError extends Error {
    readonly status: number;
    readonly method: string;
    readonly path: string;
    readonly body: string;

    constructor(status: number, method: string, path: string, body: string) {
        super(`${method} ${path} returned ${status}: ${body}`);
        this.status = status;
        this.method = method;
        this.path = path;
        this.body = body;
    }
}

/// One line for a failure, with App Store Connect's own explanation rather than its raw JSON.
export function errorMessage(error: unknown): string {
    if (error instanceof AppStoreConnectError) {
        let details: string[] = [];
        try {
            const parsed = JSON.parse(error.body) as { errors?: { code?: string; title?: string; detail?: string }[] };
            details = (parsed.errors ?? []).map((item) => item.detail ?? item.title ?? item.code ?? "").filter((detail) => detail !== "");
        } catch {
            // Not JSON; the body itself is the best explanation there is.
        }
        const explanation = details.length > 0 ? details.join("; ") : error.body.replace(/\s+/g, " ").slice(0, 600);
        return `${error.method} ${error.path} returned ${error.status}: ${explanation}`;
    }
    return error instanceof Error ? error.message : String(error);
}

function requireEnv(name: string): string {
    const value = process.env[name];
    if (!value) throw new Error(`${name} is not set; the App Store Connect API key needs ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_CONTENT`);
    return value;
}

function privateKey(keyId: string): string {
    const content = process.env.ASC_KEY_CONTENT;
    if (content) return content;
    const dir = process.env.API_PRIVATE_KEYS_DIR ?? join(homedir(), ".appstoreconnect", "private_keys");
    const file = join(dir, `AuthKey_${keyId}.p8`);
    if (!existsSync(file)) throw new Error(`No ASC_KEY_CONTENT and no key file at ${file}`);
    return readFileSync(file, "utf8");
}

function base64url(data: string | Buffer): string {
    return Buffer.from(data).toString("base64url");
}

export class AppStoreConnect {
    private readonly keyId = requireEnv("ASC_KEY_ID");
    private readonly issuerId = requireEnv("ASC_ISSUER_ID");
    private readonly key = privateKey(this.keyId);
    private token = "";
    private tokenExpiry = 0;

    private bearer(): string {
        const now = Math.floor(Date.now() / 1000);
        if (now < this.tokenExpiry - 60) return this.token;
        const header = base64url(JSON.stringify({ alg: "ES256", kid: this.keyId, typ: "JWT" }));
        const payload = base64url(JSON.stringify({ iss: this.issuerId, iat: now, exp: now + TOKEN_LIFETIME_SECONDS, aud: "appstoreconnect-v1" }));
        // JWT wants the raw r||s signature, not the DER that sign() returns by default.
        const signature = sign("sha256", Buffer.from(`${header}.${payload}`), { key: this.key, dsaEncoding: "ieee-p1363" });
        this.token = `${header}.${payload}.${base64url(signature)}`;
        this.tokenExpiry = now + TOKEN_LIFETIME_SECONDS;
        return this.token;
    }

    async request<T>(method: string, path: string, body?: unknown): Promise<T> {
        const url = path.startsWith("https://") ? path : `${API}${path}`;
        for (let attempt = 1; ; attempt++) {
            const response = await fetch(url, {
                method,
                headers: {
                    Authorization: `Bearer ${this.bearer()}`,
                    ...(body === undefined ? {} : { "Content-Type": "application/json" }),
                },
                body: body === undefined ? undefined : JSON.stringify(body),
            });
            const text = await response.text();
            // Rate limits and Apple's occasional 5xx are worth a few retries.
            if ((response.status === 429 || response.status >= 500) && attempt < 4) {
                await new Promise((resolve) => setTimeout(resolve, attempt * 5_000));
                continue;
            }
            if (!response.ok) throw new AppStoreConnectError(response.status, method, path, text);
            return (text ? JSON.parse(text) : undefined) as T;
        }
    }

    get<T>(path: string): Promise<Document<T>> {
        return this.request("GET", path);
    }

    /// Every page of a list.
    async all<Attributes>(path: string): Promise<Resource<Attributes>[]> {
        const results: Resource<Attributes>[] = [];
        let next: string | undefined = path;
        while (next) {
            const page: Document<Resource<Attributes>[]> = await this.get(next);
            results.push(...page.data);
            next = page.links?.next;
        }
        return results;
    }

    post<T>(path: string, body: unknown): Promise<Document<T>> {
        return this.request("POST", path, body);
    }

    patch<T>(path: string, body: unknown): Promise<Document<T>> {
        return this.request("PATCH", path, body);
    }

    async delete(path: string): Promise<void> {
        await this.request("DELETE", path);
    }
}

/// `filter[x]=y` query strings, with the brackets App Store Connect expects.
export function query(params: Record<string, string | number>): string {
    return Object.entries(params)
        .map(([key, value]) => `${key}=${encodeURIComponent(String(value))}`)
        .join("&");
}

/// App Store version states in which the version, its listing and its build can still be changed.
export const editableVersionStates = ["PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY"];

export interface AppStoreVersionAttributes {
    platform?: string;
    versionString: string;
    appVersionState?: string;
    /// Deprecated in favour of appVersionState; read only as a fallback.
    appStoreState?: string;
    copyright?: string | null;
}

export function versionState(version: Resource<AppStoreVersionAttributes>): string {
    return version.attributes.appVersionState ?? version.attributes.appStoreState ?? "unknown state";
}

/// The app with this bundle ID.
export async function findApp(asc: AppStoreConnect, bundleId: string): Promise<Resource<{ bundleId: string; name: string }>> {
    const apps = await asc.all<{ bundleId: string; name: string }>(`/v1/apps?${query({ "filter[bundleId]": bundleId })}`);
    const app = apps.find((candidate) => candidate.attributes.bundleId === bundleId);
    if (!app) throw new Error(`No app with bundle ID ${bundleId} in App Store Connect`);
    return app;
}

/// The app's App Store versions that can still be edited. App Store Connect
/// keeps at most one per platform; callers still check rather than assume it.
export function editableVersions(asc: AppStoreConnect, appId: string, platform = "IOS"): Promise<Resource<AppStoreVersionAttributes>[]> {
    return asc.all<AppStoreVersionAttributes>(
        `/v1/apps/${appId}/appStoreVersions?${query({ "filter[appVersionState]": editableVersionStates.join(","), "filter[platform]": platform })}`,
    );
}

/// App info states in which its localisations and age rating can still be changed.
export const editableAppInfoStates = ["PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED"];

/// The app info being prepared alongside the editable version, if there is one.
export async function editableAppInfo(asc: AppStoreConnect, appId: string): Promise<Resource<{ state?: string; appStoreState?: string }> | undefined> {
    const infos = await asc.all<{ state?: string; appStoreState?: string }>(`/v1/apps/${appId}/appInfos`);
    return infos.find((info) => editableAppInfoStates.includes(info.attributes.state ?? info.attributes.appStoreState ?? ""));
}
