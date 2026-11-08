// Composes the App Store images from vector templates. Each device has an SVG
// template, screenshots/templates/<device>.svg, drawn at the pixel size App
// Store Connect takes for it: the background in a card colour's gradient, a
// white panel for the caption, as the card face's panels hold the name, and
// the device itself, with the raw capture on its display. For each entry in a
// locale's captions.json the composer fills the template in (the caption's
// title, subtitle and chips, the capture, and the colours from
// card-colours.json, which a unit test keeps in step with the app's palette),
// lays it out in headless Chrome, which wraps and fits the text in the system
// font and scales the device into the space the caption leaves, and writes
// the PNG App Store Connect takes: the template's size, with no alpha channel.
//
// Usage: import { composeStoreImage, readCaptions, storeDevices } from "./lib/store-images.ts";

import { execFileSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { readPNG, writePNG, type Picture } from "./png.ts";

export const root = join(import.meta.dirname, "..", "..");
export const templatesDir = join(root, "screenshots", "templates");

/// A device the App Store takes images for: the suffix its files end in, the
/// pixel size, and its template.
export interface StoreDevice {
    name: string;
    suffix: string;
    width: number;
    height: number;
    template: string;
}

export const storeDevices: StoreDevice[] = [
    { name: "iPhone", suffix: "", width: 1320, height: 2868, template: "iPhone.svg" },
    { name: "iPad", suffix: "_iPad", width: 2064, height: 2752, template: "iPad.svg" },
    { name: "Duo", suffix: "_Duo", width: 1398, height: 2034, template: "Duo.svg" },
];

/// One App Store image, as a locale's captions.json lists it.
export interface StoreImageCaption {
    /// The image's file name, without the device suffix: "01_Places".
    file: string;
    /// The raw capture it shows, without the device suffix: "07_CardWhereYouAre".
    screen: string;
    /// The card colour its background takes, a CardColor raw value: "blue".
    color: string;
    title: string;
    subtitle?: string;
    /// Short facts shown as pills under the caption: "No account".
    chips?: string[];
}

/// The colours card-colours.json holds, from the app's palette.
export interface CardColours {
    accent: string;
    panel: { fill: string; ink: string; secondaryInkOpacity: number };
    cards: Record<string, { top: string; bottom: string; ink: string }>;
}

/// The entries of a captions.json, checked: `where` names the file in errors.
export function parseCaptions(json: string, where: string): StoreImageCaption[] {
    const entries: unknown = JSON.parse(json);
    if (!Array.isArray(entries)) throw new Error(`${where}: expected a list of images`);
    return entries.map((entry, index) => {
        const at = `${where}, image ${index + 1}`;
        if (typeof entry !== "object" || entry === null) throw new Error(`${at}: expected an object`);
        const value = entry as Record<string, unknown>;
        for (const key of ["file", "screen", "color", "title"]) {
            if (typeof value[key] !== "string" || (value[key] as string).trim() === "") throw new Error(`${at}: "${key}" must be a non-empty string`);
        }
        if (value.subtitle !== undefined && typeof value.subtitle !== "string") throw new Error(`${at}: "subtitle" must be a string`);
        if (value.chips !== undefined && !(Array.isArray(value.chips) && value.chips.every((chip) => typeof chip === "string" && chip.trim() !== ""))) {
            throw new Error(`${at}: "chips" must be a list of non-empty strings`);
        }
        return {
            file: value.file as string,
            screen: value.screen as string,
            color: value.color as string,
            title: value.title as string,
            ...(value.subtitle ? { subtitle: value.subtitle as string } : {}),
            ...(value.chips ? { chips: value.chips as string[] } : {}),
        };
    });
}

export function readCaptions(locale: string, rootDir: string = root): StoreImageCaption[] {
    const path = join(rootDir, "screenshots", "store", locale, "captions.json");
    return parseCaptions(readFileSync(path, "utf8"), path);
}

export function readCardColours(rootDir: string = root): CardColours {
    return JSON.parse(readFileSync(join(rootDir, "screenshots", "templates", "card-colours.json"), "utf8")) as CardColours;
}

/// "#1C1C1E" at `opacity` as a CSS colour.
function withOpacity(hex: string, opacity: number): string {
    const value = Number.parseInt(hex.slice(1), 16);
    return `rgba(${(value >> 16) & 255}, ${(value >> 8) & 255}, ${value & 255}, ${opacity})`;
}

/// The CSS variables a template draws with, for an image in card colour `color`.
export function variablesFor(color: string, colours: CardColours): Record<string, string> {
    const card = colours.cards[color];
    if (!card) throw new Error(`"${color}" is not a palette colour in card-colours.json: ${Object.keys(colours.cards).join(", ")}`);
    return {
        "--top": card.top,
        "--bottom": card.bottom,
        "--card-ink": card.ink,
        "--panel": colours.panel.fill,
        "--ink": colours.panel.ink,
        "--secondary-ink": withOpacity(colours.panel.ink, colours.panel.secondaryInkOpacity),
        "--accent": colours.accent,
    };
}

/// Lays a filled-in template out, in the page: the text wrapped and fitted,
/// the chips made, the panel grown round them and the device scaled below it.
/// The data attributes it reads are listed in the templates' own comment.
const layoutScript = String.raw`
// In a function of its own: top-level names such as top would clash with the window's.
(() => {
const data = JSON.parse(document.getElementById("data").textContent);
const svg = document.querySelector("svg");
const NS = "http://www.w3.org/2000/svg";
for (const [name, value] of Object.entries(data.variables)) svg.style.setProperty(name, value);
const number = (element, name, fallback) => element && element.dataset[name] !== undefined ? Number(element.dataset[name]) : fallback;
const width = Number(svg.getAttribute("width"));
const height = Number(svg.getAttribute("height"));

// Words for Latin scripts; for text without spaces, such as Japanese, each character.
function pieces(text) {
    return /\s/.test(text.trim()) || !/[　-鿿＀-￯]/.test(text) ? text.split(/\s+/).filter(Boolean) : Array.from(text);
}

function wrap(element, text) {
    const maxWidth = number(element, "width", width);
    const maxLines = number(element, "maxLines", 2);
    const lineHeight = number(element, "lineHeight", 1.2);
    const joiner = /\s/.test(text.trim()) ? " " : "";
    const words = pieces(text);
    const x = element.getAttribute("x");
    let size = Number(element.getAttribute("font-size"));
    for (;;) {
        element.setAttribute("font-size", String(size));
        element.textContent = "";
        const probe = document.createElementNS(NS, "tspan");
        element.appendChild(probe);
        const measure = (line) => { probe.textContent = line; return probe.getComputedTextLength(); };
        const breakAt = (limit) => {
            const lines = [];
            let line = "";
            for (const word of words) {
                const next = line ? line + joiner + word : word;
                if (line && measure(next) > limit) { lines.push(line); line = word; } else { line = next; }
            }
            if (line) lines.push(line);
            return lines;
        };
        let lines = breakAt(maxWidth);
        // Balanced, as CSS's text-wrap: balance: the narrowest width that
        // still takes as many lines, so no word is left on a line of its own.
        if (lines.length > 1) {
            let limit = maxWidth;
            while (limit > maxWidth / 2 && breakAt(limit * 0.97).length === lines.length) limit *= 0.97;
            lines = breakAt(limit);
        }
        const widest = Math.max(...lines.map(measure));
        element.removeChild(probe);
        if ((lines.length <= maxLines && widest <= maxWidth) || size <= 24) {
            lines.forEach((text, index) => {
                const span = document.createElementNS(NS, "tspan");
                span.setAttribute("x", x);
                span.setAttribute("dy", index === 0 ? "0" : String(size * lineHeight));
                span.textContent = text;
                element.appendChild(span);
            });
            return;
        }
        size = Math.floor(size * 0.95);
    }
}

// Moves an element so the top of what it draws is at y, and says where it ends.
function placeTop(element, y) {
    const box = element.getBBox();
    const current = element.transform.baseVal.consolidate();
    const dy = y - box.y + (current ? current.matrix.f : 0);
    const dx = current ? current.matrix.e : 0;
    element.setAttribute("transform", "translate(" + dx + " " + dy + ")");
    return y + box.height;
}

const panel = document.getElementById("panel");
const title = document.getElementById("title");
const subtitle = document.getElementById("subtitle");
const chips = document.getElementById("chips");
const chip = document.getElementById("chip");
const padding = number(panel, "padding", 56);
let y = Number(panel.getAttribute("y")) + padding;

wrap(title, data.title);
y = placeTop(title, y);
if (data.subtitle) {
    wrap(subtitle, data.subtitle);
    y = placeTop(subtitle, y + number(subtitle, "gap", 24));
} else {
    subtitle.remove();
}

if (data.chips && data.chips.length > 0) {
    chip.remove();
    const spacing = number(chips, "spacing", 16);
    const made = data.chips.map((text) => {
        const copy = chip.cloneNode(true);
        copy.removeAttribute("id");
        chips.appendChild(copy);
        const label = copy.querySelector("text");
        const rect = copy.querySelector("rect");
        label.textContent = text;
        const chipPadding = number(label, "padding", 36);
        const chipHeight = Number(rect.getAttribute("height"));
        const labelWidth = label.getComputedTextLength();
        rect.setAttribute("width", String(labelWidth + 2 * chipPadding));
        label.setAttribute("x", String(chipPadding + labelWidth / 2));
        label.setAttribute("y", String(chipHeight / 2 + Number(label.getAttribute("font-size")) * 0.35));
        return { copy, width: labelWidth + 2 * chipPadding };
    });
    const total = made.reduce((sum, item) => sum + item.width, 0) + spacing * (made.length - 1);
    let x = (width - total) / 2;
    for (const item of made) {
        item.copy.setAttribute("transform", "translate(" + x + " 0)");
        x += item.width + spacing;
    }
    y = placeTop(chips, y + number(chips, "gap", 24));
} else {
    chips.remove();
}

panel.setAttribute("height", String(y + padding - Number(panel.getAttribute("y"))));

const device = document.getElementById("device");
const deviceWidth = number(device, "width", width);
const deviceHeight = number(device, "height", height);
const top = y + padding + number(device, "gap", 48);
const room = height - number(device, "margin", 48) - top;
const scale = Math.min(room / deviceHeight, (width * 0.86) / deviceWidth);
device.setAttribute("transform", "translate(" + (width - deviceWidth * scale) / 2 + " " + top + ") scale(" + scale + ")");
const screen = document.getElementById("screen");
screen.setAttribute("href", data.screen);
screen.setAttributeNS("http://www.w3.org/1999/xlink", "xlink:href", data.screen);
})();
`;

/// The page Chrome renders: the template, the data to fill it with, and the
/// layout script. The SVG is the page, at its own size, with nothing round it.
export function pageFor(template: string, caption: StoreImageCaption, variables: Record<string, string>, screenPNG: Uint8Array): string {
    const data = {
        title: caption.title,
        subtitle: caption.subtitle ?? "",
        chips: caption.chips ?? [],
        variables,
        screen: `data:image/png;base64,${Buffer.from(screenPNG).toString("base64")}`,
    };
    // "</" would end the script element early.
    const json = JSON.stringify(data).replaceAll("</", "<\\/");
    const svg = template.replace(/^<\?xml[^>]*>\s*/, "");
    return `<!doctype html>
<html><head><meta charset="utf-8"><style>html, body { margin: 0; padding: 0; overflow: hidden; } svg { display: block; }</style></head>
<body>
${svg}
<script type="application/json" id="data">${json}</script>
<script>${layoutScript}</script>
</body></html>
`;
}

/// Google Chrome, which renders the pages: CHROME, or where macOS installs it.
export function findChrome(): string {
    const candidates = [process.env.CHROME, "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"].filter(Boolean) as string[];
    const found = candidates.find((path) => existsSync(path));
    if (!found) throw new Error("Composing the App Store images needs Google Chrome: install it, or set CHROME to its binary");
    return found;
}

/// The picture without its alpha channel, which App Store Connect refuses.
/// The pages are opaque, so the alpha is dropped rather than blended.
export function withoutAlpha(picture: Picture): Picture {
    if (picture.channels === 3) return picture;
    if (picture.channels !== 4) throw new Error(`expected an RGB or RGBA image, not ${picture.channels} channels`);
    const pixels = new Uint8Array(picture.width * picture.height * 3);
    for (let source = 0, target = 0; source < picture.pixels.length; source += 4, target += 3) {
        pixels[target] = picture.pixels[source] ?? 0;
        pixels[target + 1] = picture.pixels[source + 1] ?? 0;
        pixels[target + 2] = picture.pixels[source + 2] ?? 0;
    }
    return { width: picture.width, height: picture.height, channels: 3, pixels };
}

/// Renders `page` at width x height with headless Chrome and returns the PNG.
export function renderPage(page: string, width: number, height: number, chrome: string = findChrome()): Buffer {
    const work = mkdtempSync(join(tmpdir(), "cards-store-image-"));
    try {
        const pagePath = join(work, "page.html");
        const shot = join(work, "image.png");
        writeFileSync(pagePath, page);
        execFileSync(chrome, [
            "--headless=new",
            "--disable-gpu",
            "--hide-scrollbars",
            "--force-device-scale-factor=1",
            "--force-color-profile=srgb",
            `--user-data-dir=${join(work, "profile")}`,
            `--window-size=${width},${height}`,
            "--virtual-time-budget=5000",
            `--screenshot=${shot}`,
            `file://${pagePath}`,
        ], { stdio: ["ignore", "ignore", "pipe"], timeout: 60_000 });
        const picture = readPNG(readFileSync(shot), "Chrome's screenshot");
        if (picture.width !== width || picture.height !== height) {
            throw new Error(`Chrome drew the page ${picture.width} x ${picture.height}, not ${width} x ${height}`);
        }
        return writePNG(withoutAlpha(picture));
    } finally {
        rmSync(work, { recursive: true, force: true });
    }
}

/// The App Store image for `caption` on `device`, from the locale's raw capture.
export function composeStoreImage(caption: StoreImageCaption, device: StoreDevice, locale: string, rootDir: string = root): Buffer {
    const templatePath = join(rootDir, "screenshots", "templates", device.template);
    if (!existsSync(templatePath)) throw new Error(`No template for ${device.name} yet: ${templatePath}`);
    const capturePath = join(rootDir, "screenshots", locale, `${caption.screen}${device.suffix}.png`);
    if (!existsSync(capturePath)) throw new Error(`Missing the raw capture ${capturePath}: make capture-screenshots`);
    const template = readFileSync(templatePath, "utf8");
    const page = pageFor(template, caption, variablesFor(caption.color, readCardColours(rootDir)), readFileSync(capturePath));
    return renderPage(page, device.width, device.height);
}
