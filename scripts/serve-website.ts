// Serves the built website, Website/dist, at http://127.0.0.1:8788 to preview
// it as Cloudflare Pages serves it: a folder's index.html, a page without its
// .html (/add for add.html), and the headers Website/static/_headers sets for
// a path. It listens on this Mac's loopback address only, so nothing else on
// the network can reach it. Build first with node scripts/build-website.ts.
//
// Usage: node scripts/serve-website.ts [--port <port>]

import { existsSync, readFileSync, statSync } from "node:fs";
import { createServer } from "node:http";
import { extname, join, resolve, sep } from "node:path";
import { parseArgs } from "node:util";
import { positiveInteger, runScript, UsageError } from "./lib/command-line.ts";

const site = join(import.meta.dirname, "..", "Website", "dist");
const host = "127.0.0.1";

const usage = `Usage: node scripts/serve-website.ts [--port <port>]

Serves Website/dist at http://${host}:<port> (8788 by default), as Cloudflare Pages would.`;

const contentTypes: Record<string, string> = {
    ".html": "text/html; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".json": "application/json",
    ".png": "image/png",
    ".svg": "image/svg+xml",
    ".txt": "text/plain; charset=utf-8",
};

/// The headers a _headers file sets for each exact path. Cloudflare Pages
/// also takes wildcards, which this preview does not need.
export function parseHeaders(text: string): Map<string, Record<string, string>> {
    const rules = new Map<string, Record<string, string>>();
    let current: Record<string, string> | undefined;
    for (const line of text.split("\n")) {
        if (line.trim() === "" || line.trim().startsWith("#")) continue;
        if (!/^\s/.test(line)) {
            current = {};
            rules.set(line.trim(), current);
            continue;
        }
        const colon = line.indexOf(":");
        if (!current || colon < 0) throw new Error(`_headers: "${line.trim()}" is not a header under a path`);
        current[line.slice(0, colon).trim().toLowerCase()] = line.slice(colon + 1).trim();
    }
    return rules;
}

/// The file a request path serves, as Cloudflare Pages finds it, or undefined.
export function fileFor(root: string, path: string): string | undefined {
    const wanted = resolve(root, `.${path}`);
    if (wanted !== root && !wanted.startsWith(root + sep)) return undefined;
    const candidates = path.endsWith("/") ? [join(wanted, "index.html")] : [wanted, `${wanted}.html`, join(wanted, "index.html")];
    return candidates.find((candidate) => existsSync(candidate) && statSync(candidate).isFile());
}

function main(argv: string[]): number {
    const { values } = parseArgs({
        args: argv,
        options: {
            port: { type: "string" },
            help: { type: "boolean", short: "h", default: false },
        },
    });
    if (values.help) {
        console.log(usage);
        return 0;
    }
    const port = positiveInteger(values.port, 8788, "--port");
    if (!existsSync(join(site, "index.html"))) throw new UsageError("Website/dist has no site in it; run node scripts/build-website.ts first");
    const headersFile = join(site, "_headers");
    const headers = existsSync(headersFile) ? parseHeaders(readFileSync(headersFile, "utf8")) : new Map<string, Record<string, string>>();

    const server = createServer((request, response) => {
        let path: string;
        try {
            path = decodeURIComponent(new URL(request.url ?? "/", `http://${host}`).pathname);
        } catch {
            response.writeHead(400).end("Bad request");
            return;
        }
        const file = fileFor(site, path);
        if (!file || (request.method !== "GET" && request.method !== "HEAD")) {
            response.writeHead(file ? 405 : 404, { "content-type": "text/plain; charset=utf-8" }).end(file ? "Method not allowed" : "Not found");
            console.log(`${file ? 405 : 404} ${request.method} ${path}`);
            return;
        }
        response.writeHead(200, {
            "content-type": contentTypes[extname(file)] ?? "application/octet-stream",
            "cache-control": "no-store",
            ...headers.get(path),
        });
        response.end(request.method === "HEAD" ? undefined : readFileSync(file));
        console.log(`200 ${request.method} ${path}`);
    });
    server.listen(port, host, () => console.log(`Serving Website/dist at http://${host}:${port}/ (Ctrl-C stops it)`));
    return 0;
}

if (import.meta.main) runScript("serve-website", main);
