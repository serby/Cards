// Tests for scripts/lib/png.ts, which shrinks the App Store images for the
// website. Run with: node --test scripts/png.test.ts

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, test } from "node:test";
import { deflateSync } from "node:zlib";

import { type Picture, readPNG, shrinkPNG, writePNG } from "./lib/png.ts";

/// A picture whose bytes vary in every direction, so each filter type gets chosen somewhere.
function pattern(width: number, height: number, channels: number): Picture {
    const pixels = new Uint8Array(width * height * channels);
    for (let index = 0; index < pixels.length; index++) pixels[index] = (index * 37 + Math.floor(index / (width * channels)) * 11 + (index % 7) * 50) & 0xff;
    return { width, height, channels, pixels };
}

describe("PNG", () => {
    test("reads back what it writes, in every channel layout", () => {
        for (const channels of [1, 2, 3, 4]) {
            const picture = pattern(23, 17, channels);
            const again = readPNG(writePNG(picture));
            assert.deepEqual({ ...again, pixels: [...again.pixels] }, { ...picture, pixels: [...picture.pixels] }, `${channels} channels`);
        }
    });

    test("reads an image another encoder wrote, the app icon", () => {
        const icon = readPNG(readFileSync(join(import.meta.dirname, "..", "DesignAssets", "Icon.png")));
        assert.deepEqual([icon.width, icon.height, icon.channels], [1024, 1024, 3]);
        assert.deepEqual([...readPNG(writePNG(icon)).pixels], [...icon.pixels]);
    });

    test("shrinks by averaging each square, dropping a part square at the edge", () => {
        const picture: Picture = { width: 5, height: 2, channels: 1, pixels: Uint8Array.from([0, 10, 100, 200, 255, 20, 30, 50, 51, 255]) };
        assert.deepEqual(shrinkPNG(picture, 2), { width: 2, height: 1, channels: 1, pixels: Uint8Array.from([15, 100]) });
        assert.deepEqual(shrinkPNG(picture, 1), picture);
        assert.throws(() => shrinkPNG(picture, 1.5), /whole number/);
    });

    test("refuses what it cannot read", () => {
        assert.throws(() => readPNG(Buffer.from("not a png"), "x.png"), /x\.png is not a PNG/);
        const sixteenBit = writePNG(pattern(2, 2, 3));
        sixteenBit[24] = 16;
        assert.throws(() => readPNG(sixteenBit, "deep.png"), /deep\.png is a PNG this reader does not handle \(bit depth 16/);
        const short = writePNG(pattern(4, 4, 1));
        const idat = short.indexOf("IDAT");
        const tooLittle = deflateSync(Buffer.from([0, 1, 2]));
        const length = Buffer.alloc(4);
        length.writeUInt32BE(tooLittle.length);
        // The reader does not check CRCs, so the chunk's can be anything.
        const truncated = Buffer.concat([short.subarray(0, idat - 4), length, Buffer.from("IDAT"), tooLittle, Buffer.alloc(4)]);
        assert.throws(() => readPNG(truncated, "short.png"), /less image data/);
    });
});
