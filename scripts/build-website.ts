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
// With --check-images it builds nothing and only says whether the British
// English page's images are there, which website.yml asks before it deploys;
// another language's page leaves out its images until they are composed, so
// it never shows another language's or version's pictures.
//
// Usage: node scripts/build-website.ts [--allow-missing-images] [--check-images] [--images <dir>] [--out <dir>]

import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { parseArgs } from "node:util";
import { runScript } from "./lib/command-line.ts";
import { sourceLocale } from "./lib/locales.ts";
import { readPNG, shrinkPNG, writePNG } from "./lib/png.ts";
import { readSite, renderSite, type Screenshot, screenshotSources, screenshotWidth } from "./lib/website.ts";

const repositoryRoot = join(import.meta.dirname, "..");

const usage = `Usage: node scripts/build-website.ts [--allow-missing-images] [--check-images] [--images <dir>] [--out <dir>]

Builds the website into Website/dist from the store listing, the changelog and the app.

Options:
  --allow-missing-images   Leave out App Store images that are not there yet, rather than stop
  --check-images           Build nothing; fail, listing them, while an image the British English page shows is missing
  --images <dir>           Take the App Store images from <dir>/<locale>/ rather than screenshots/store/, to preview new ones
  --out <dir>              Build into <dir> rather than Website/dist`;

export interface BuildOptions {
    /// The repository to build from.
    root?: string;
    /// Where to build it; emptied first.
    out?: string;
    allowMissingImages?: boolean;
    /// Where the App Store images are, in a folder for each locale; screenshots/store/ unless given.
    images?: string;
    log?: (line: string) => void;
}

/// The App Store images the British English page shows that are not there yet,
/// relative to the repository. The site deploys once there are none.
export function missingImages(site: ReturnType<typeof readSite>, root: string, images?: string): string[] {
    return screenshotSources(site, root, images)
        .filter((source) => source.locale === sourceLocale && !existsSync(source.source))
        .map((source) => relative(root, source.source));
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

    const sources = screenshotSources(site, root, options.images);
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
            "check-images": { type: "boolean", default: false },
            images: { type: "string" },
            out: { type: "string" },
            help: { type: "boolean", short: "h", default: false },
        },
    });
    if (values.help) {
        console.log(usage);
        return 0;
    }
    if (values["check-images"]) {
        const missing = missingImages(readSite(repositoryRoot), repositoryRoot, values.images ? resolve(values.images) : undefined);
        for (const image of missing) console.error(`missing: ${image}`);
        console.log(missing.length === 0 ? "Every App Store image the British English page shows is there." : `${missing.length} App Store images the British English page shows are missing.`);
        return missing.length === 0 ? 0 : 1;
    }
    buildWebsite({
        allowMissingImages: values["allow-missing-images"],
        ...(values.images ? { images: resolve(values.images) } : {}),
        ...(values.out ? { out: resolve(values.out) } : {}),
    });
    return 0;
}

if (import.meta.main) runScript("build-website", main);
