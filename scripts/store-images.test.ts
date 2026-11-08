// Tests for lib/store-images.ts: reading captions, the colours a template is
// filled with, the page Chrome renders, dropping the alpha channel, and that
// every template has what the composer fills in. Rendering itself needs
// Chrome and is checked by eye (make store-screenshots).
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, test } from "node:test";
import { capturesNamed, creativeAssetKinds, pageFor, parseCaptions, parseCreativeAssets, readCardColours, root, storeDevices, templatesDir, variablesFor, withoutAlpha } from "./lib/store-images.ts";

describe("parseCaptions", () => {
    test("reads an image with a subtitle, and one with chips", () => {
        const captions = parseCaptions(JSON.stringify([
            { file: "01_Places", screen: "07_CardWhereYouAre", color: "blue", title: "Your card", subtitle: "When you arrive" },
            { file: "03_Privacy", screen: "08_Privacy", color: "graphite", title: "Yours", chips: ["No account", "No tracking"] },
        ]), "captions.json");
        assert.deepEqual(captions[0], { file: "01_Places", screen: "07_CardWhereYouAre", color: "blue", title: "Your card", subtitle: "When you arrive" });
        assert.deepEqual(captions[1]?.chips, ["No account", "No tracking"]);
        assert.equal(captions[1]?.subtitle, undefined);
    });

    test("names the file and the image when something is missing", () => {
        assert.throws(() => parseCaptions(JSON.stringify([{ file: "01", screen: "07", color: "blue" }]), "en-GB/captions.json"), /en-GB\/captions.json, image 1: "title"/);
        assert.throws(() => parseCaptions(JSON.stringify([{ file: "01", screen: "07", color: "blue", title: "T", chips: [""] }]), "x"), /"chips"/);
        assert.throws(() => parseCaptions("{}", "x"), /a list of images/);
    });
});

describe("variablesFor", () => {
    const colours = readCardColours();

    test("takes a palette colour's gradient and the panel's inks", () => {
        const variables = variablesFor("blue", colours);
        assert.equal(variables["--top"], colours.cards.blue?.top);
        assert.equal(variables["--bottom"], colours.cards.blue?.bottom);
        assert.equal(variables["--ink"], colours.panel.ink);
        assert.equal(variables["--accent"], colours.accent);
        assert.match(variables["--secondary-ink"] ?? "", /^rgba\(28, 28, 30, 0\.7\)$/);
    });

    test("refuses a colour the palette doesn't have", () => {
        assert.throws(() => variablesFor("chartreuse", colours), /"chartreuse" is not a palette colour/);
    });
});

describe("pageFor", () => {
    test("carries the caption as data, so text that looks like markup stays text", () => {
        const page = pageFor("<svg width=\"10\" height=\"10\"></svg>", { file: "f", screen: "s", color: "blue", title: "A </script> B" }, {}, new Uint8Array([1, 2, 3]));
        assert.ok(!page.includes("A </script> B"));
        assert.ok(page.includes("A <\\/script> B"));
        assert.ok(page.includes("data:image/png;base64,AQID"));
    });
});

describe("withoutAlpha", () => {
    test("drops the fourth channel and keeps the colour", () => {
        const picture = withoutAlpha({ width: 2, height: 1, channels: 4, pixels: new Uint8Array([10, 20, 30, 255, 40, 50, 60, 128]) });
        assert.equal(picture.channels, 3);
        assert.deepEqual([...picture.pixels], [10, 20, 30, 40, 50, 60]);
    });
});

describe("templates", () => {
    for (const device of storeDevices.filter((candidate) => existsSync(join(templatesDir, candidate.template)))) {
        test(`${device.template} is ${device.width} x ${device.height} and has every part the composer fills in`, () => {
            const svg = readFileSync(join(templatesDir, device.template), "utf8");
            assert.match(svg, new RegExp(`<svg[^>]* width="${device.width}" height="${device.height}"`));
            for (const id of ["panel", "title", "subtitle", "chips", "chip", "device", "screen"]) {
                assert.match(svg, new RegExp(`id="${id}"`), `${device.template} has no #${id}`);
            }
            assert.match(svg, /id="device"[^>]* data-width="\d+" data-height="\d+"/);
        });
    }

    test("every image in every captions.json takes a palette colour", () => {
        const colours = readCardColours();
        const store = join(root, "screenshots", "store");
        const captions = parseCaptions(readFileSync(join(store, "en-GB", "captions.json"), "utf8"), "en-GB");
        for (const caption of captions) assert.ok(colours.cards[caption.color], `${caption.file}: ${caption.color}`);
    });
});

describe("parseCreativeAssets", () => {
    test("reads the header and the search result", () => {
        const assets = parseCreativeAssets(JSON.stringify({
            header: { file: "Header", color: "pink", title: "Your card, ready when you arrive" },
            search: { file: "Search", color: "pink", title: "Your loyalty cards, ready to scan" },
        }), "creative-asset.json");
        assert.equal(assets.header.file, "Header");
        assert.equal(assets.search.title, "Your loyalty cards, ready to scan");
    });

    test("names what is missing", () => {
        assert.throws(() => parseCreativeAssets(JSON.stringify({ header: { file: "Header", color: "pink", title: "T" } }), "ja/creative-asset.json"), /ja\/creative-asset.json: "search" must be an object/);
        assert.throws(() => parseCreativeAssets(JSON.stringify({ header: { file: "Header", color: "pink" }, search: {} }), "x"), /header's "title"/);
    });
});

describe("the creative asset templates", () => {
    for (const kind of creativeAssetKinds) {
        test(`${kind.template} is ${kind.width} x ${kind.height}, with a title and only the captures there are`, () => {
            const svg = readFileSync(join(templatesDir, kind.template), "utf8");
            assert.match(svg, new RegExp(`<svg[^>]* width="${kind.width}" height="${kind.height}"`));
            assert.match(svg, /id="title"[^>]* data-middle="\d+"/);
            for (const name of capturesNamed(svg)) assert.ok(existsSync(join(root, "screenshots", "en-GB", `${name}_Duo.png`)), `${kind.template} crops ${name}`);
        });
    }
});
