// A small App Store Connect API client shared by the TypeScript release scripts.
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
    readonly body: string;

    constructor(status: number, method: string, path: string, body: string) {
        super(`${method} ${path} returned ${status}: ${body}`);
        this.status = status;
        this.body = body;
    }
}

function requireEnv(name: string): string {
    const value = process.env[name];
    if (!value) throw new Error(`${name} is not set`);
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
