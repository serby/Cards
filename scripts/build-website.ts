// Builds the website, cards.serby.net, into Website/dist from the app's own
// sources (scripts/lib/website.ts lists them): a home page in each of the
// app's languages, the privacy policy and the styles, from Website/templates,
// and each page's App Store images, shrunk for the web. Website/static is
// copied as it is: add.html (the share link page), demo.html (App Review's
// sample codes), _headers, .well-known/ (the universal link file) and the
// icon. It stops, writing nothing, if a source is broken, and while any
// caption's App Store image is missing, so a site that would show the wrong
// pictures is never deployed; --allow-missing-images leaves those out instead,
// to preview the site before the screenshots are refreshed.
// scripts/deploy-website.ts deploys the result and scripts/serve-website.ts
// serves it locally (docs/DEVELOPMENT.md, "Change the website").
//
// Usage: node scripts/build-website.ts [--allow-missing-images]

import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { parseArgs } from "node:util";
import { runScript } from "./lib/command-line.ts";
import { readPNG, shrinkPNG, writePNG } from "./lib/png.ts";
import { readSite, renderSite, type Screenshot, screenshotSources, screenshotWidth } from "./lib/website.ts";

const repositoryRoot = join(import.meta.dirname, "..");

const usage = `Usage: node scripts/build-website.ts [--allow-missing-images]

Builds the website into Website/dist from the store listing, the changelog and the app.

Options:
  --allow-missing-images   Leave out App Store images that are not there yet, rather than stop`;

export interface BuildOptions {
    /// The repository to build from.
    root?: string;
    /// Where to build it; emptied first.
    out?: string;
    allowMissingImages?: boolean;
    log?: (line: string) => void;
}

export interface BuildResult {
    /// Every file written, relative to the output folder, sorted.
    files: string[];
    /// App Store images left out because they are not there yet.
    skipped: string[];
}

function filesUnder(dir: string, base = dir): string[] {
    return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
        const path = join(dir, entry.name);
        return entry.isDirectory() ? filesUnder(path, base) : [relative(base, path)];
    });
}

export function buildWebsite(options: BuildOptions = {}): BuildResult {
    const root = options.root ?? repositoryRoot;
    const out = options.out ?? join(root, "Website", "dist");
    const log = options.log ?? ((line: string): void => console.log(line));
    const site = readSite(root);

    const sources = screenshotSources(site, root);
    const missing = sources.filter((source) => !existsSync(source.source));
    const skipped = missing.map((source) => relative(root, source.source));
    if (missing.length > 0 && !options.allowMissingImages) {
        throw new Error(`these App Store images are missing, so the site would show the wrong pictures:\n  ${skipped.join("\n  ")}\nRun make store-screenshots, or pass --allow-missing-images to preview the site without them.`);
    }
    const screenshots = new Map<string, Screenshot[]>();
    const generated = new Map<string, string | Buffer>();
    for (const source of sources.filter((candidate) => !missing.includes(candidate))) {
        const picture = readPNG(readFileSync(source.source), relative(root, source.source));
        const small = shrinkPNG(picture, Math.max(1, Math.round(picture.width / screenshotWidth)));
        generated.set(source.file, writePNG(small));
        const list = screenshots.get(source.locale) ?? [];
        list.push({ src: `/${source.file}`, width: small.width, height: small.height, alt: source.alt });
        screenshots.set(source.locale, list);
    }
    for (const [file, text] of renderSite(site, screenshots)) generated.set(file, text);

    const staticDir = join(root, "Website", "static");
    const staticFiles = filesUnder(staticDir);
    const clashes = staticFiles.filter((file) => generated.has(file));
    if (clashes.length > 0) throw new Error(`Website/static has ${clashes.join(", ")}, which the build generates; keep one of them`);

    rmSync(out, { recursive: true, force: true });
    cpSync(staticDir, out, { recursive: true });
    for (const [file, contents] of generated) {
        mkdirSync(dirname(join(out, file)), { recursive: true });
        writeFileSync(join(out, file), contents);
    }
    for (const image of skipped) log(`warning: left out ${image}, which is not there yet`);
    const pictures = [...generated.keys()].filter((file) => file.endsWith(".png")).length;
    log(`Built ${relative(root, out) || out}: ${site.pages.length} home pages (${site.pages.map((page) => page.path).join(" ")}), the privacy policy, ${pictures} App Store images and ${staticFiles.length} static files.`);
    return { files: [...staticFiles, ...generated.keys()].sort(), skipped };
}

function main(argv: string[]): number {
    const { values } = parseArgs({
        args: argv,
        options: {
            "allow-missing-images": { type: "boolean", default: false },
            help: { type: "boolean", short: "h", default: false },
        },
    });
    if (values.help) {
        console.log(usage);
        return 0;
    }
    buildWebsite({ allowMissingImages: values["allow-missing-images"] });
    return 0;
}

if (import.meta.main) runScript("build-website", main);
