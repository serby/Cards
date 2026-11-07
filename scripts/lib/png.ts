// Reads, shrinks and writes PNG images with nothing but Node's own zlib, for
// the website: the App Store images are 1,320 pixels wide, several times what
// a web page shows, so scripts/build-website.ts shrinks them before it
// publishes them. Reads what Xcode and the store screenshot composer write:
// 8 bits a channel, greyscale, grey and alpha, RGB or RGBA, not interlaced.
// Shrinking averages each square of pixels, which keeps text and edges smooth.
//
// Usage: import { readPNG, shrinkPNG, writePNG } from "./lib/png.ts";

import { crc32, deflateSync, inflateSync } from "node:zlib";

/// Pixels in rows, top to bottom, each pixel `channels` bytes.
export interface Picture {
    width: number;
    height: number;
    /// 1 grey, 2 grey and alpha, 3 RGB, 4 RGBA.
    channels: number;
    pixels: Uint8Array;
}

const signature = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
/// PNG colour type for each channel count, and back.
const colourTypes: Record<number, number> = { 0: 1, 4: 2, 2: 3, 6: 4 };
const channelTypes: Record<number, number> = { 1: 0, 2: 4, 3: 2, 4: 6 };

function paeth(a: number, b: number, c: number): number {
    const p = a + b - c;
    const pa = Math.abs(p - a);
    const pb = Math.abs(p - b);
    const pc = Math.abs(p - c);
    return pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
}

/// The value a filter predicts for a byte from its left (a), upper (b) and upper-left (c) neighbours.
function predict(filter: number, a: number, b: number, c: number): number {
    switch (filter) {
        case 0:
            return 0;
        case 1:
            return a;
        case 2:
            return b;
        case 3:
            return (a + b) >> 1;
        case 4:
            return paeth(a, b, c);
        default:
            throw new Error(`unknown PNG filter ${filter}`);
    }
}

export function readPNG(data: Uint8Array, name = "the image"): Picture {
    const bytes = Buffer.from(data.buffer, data.byteOffset, data.byteLength);
    if (bytes.length < 8 || !bytes.subarray(0, 8).equals(signature)) throw new Error(`${name} is not a PNG`);
    let header: { width: number; height: number; channels: number } | undefined;
    const compressed: Buffer[] = [];
    for (let offset = 8; offset + 8 <= bytes.length;) {
        const length = bytes.readUInt32BE(offset);
        const type = bytes.toString("latin1", offset + 4, offset + 8);
        const body = bytes.subarray(offset + 8, offset + 8 + length);
        offset += 12 + length;
        if (type === "IHDR") {
            const [depth, colourType, , , interlace] = [body[8], body[9], body[10], body[11], body[12]];
            const channels = colourTypes[colourType ?? -1];
            if (depth !== 8 || channels === undefined || interlace !== 0) {
                throw new Error(`${name} is a PNG this reader does not handle (bit depth ${depth}, colour type ${colourType}, interlace ${interlace}); it reads 8-bit grey, RGB and their alpha forms, not interlaced`);
            }
            header = { width: body.readUInt32BE(0), height: body.readUInt32BE(4), channels };
        } else if (type === "IDAT") {
            compressed.push(body);
        } else if (type === "IEND") {
            break;
        }
    }
    if (!header) throw new Error(`${name} has no IHDR chunk`);
    const { width, height, channels } = header;
    const filtered = inflateSync(Buffer.concat(compressed));
    const stride = width * channels;
    if (filtered.length < height * (stride + 1)) throw new Error(`${name} has less image data than its size needs`);
    const pixels = new Uint8Array(height * stride);
    for (let y = 0; y < height; y++) {
        const filter = filtered[y * (stride + 1)] ?? 0;
        const source = y * (stride + 1) + 1;
        const row = y * stride;
        const above = row - stride;
        for (let x = 0; x < stride; x++) {
            const a = x >= channels ? (pixels[row + x - channels] ?? 0) : 0;
            const b = y > 0 ? (pixels[above + x] ?? 0) : 0;
            const c = x >= channels && y > 0 ? (pixels[above + x - channels] ?? 0) : 0;
            pixels[row + x] = ((filtered[source + x] ?? 0) + predict(filter, a, b, c)) & 0xff;
        }
    }
    return { width, height, channels, pixels };
}

/// The picture a whole number of times smaller in each direction, each new
/// pixel the average of the square it replaces. A part square left over at
/// the right or bottom edge is dropped.
export function shrinkPNG(picture: Picture, factor: number): Picture {
    if (!Number.isInteger(factor) || factor < 1) throw new Error(`a picture shrinks by a whole number, not ${factor}`);
    const { channels } = picture;
    const width = Math.floor(picture.width / factor);
    const height = Math.floor(picture.height / factor);
    const pixels = new Uint8Array(width * height * channels);
    const area = factor * factor;
    const sums = new Float64Array(width * channels);
    for (let y = 0; y < height; y++) {
        sums.fill(0);
        for (let dy = 0; dy < factor; dy++) {
            const row = (y * factor + dy) * picture.width * channels;
            for (let x = 0; x < width * factor; x++) {
                const target = Math.floor(x / factor) * channels;
                for (let channel = 0; channel < channels; channel++) {
                    sums[target + channel] = (sums[target + channel] ?? 0) + (picture.pixels[row + x * channels + channel] ?? 0);
                }
            }
        }
        for (let index = 0; index < sums.length; index++) pixels[y * width * channels + index] = Math.round((sums[index] ?? 0) / area);
    }
    return { width, height, channels, pixels };
}

function chunk(type: string, body: Uint8Array): Buffer {
    const typed = Buffer.concat([Buffer.from(type, "latin1"), body]);
    const framed = Buffer.alloc(typed.length + 8);
    framed.writeUInt32BE(body.length, 0);
    typed.copy(framed, 4);
    framed.writeUInt32BE(crc32(typed) >>> 0, typed.length + 4);
    return framed;
}

/// A PNG of the picture. Each row takes whichever filter leaves the smallest
/// bytes, as most encoders choose, before deflating at the highest level.
export function writePNG(picture: Picture): Buffer {
    const { width, height, channels, pixels } = picture;
    const colourType = channelTypes[channels];
    if (colourType === undefined) throw new Error(`a PNG has 1 to 4 channels, not ${channels}`);
    if (pixels.length !== width * height * channels) throw new Error(`${width} x ${height} x ${channels} needs ${width * height * channels} bytes, not ${pixels.length}`);
    const stride = width * channels;
    const filtered = Buffer.alloc(height * (stride + 1));
    const candidate = new Uint8Array(stride);
    for (let y = 0; y < height; y++) {
        const row = y * stride;
        const above = row - stride;
        let best = { filter: 0, cost: Infinity };
        for (let filter = 0; filter <= 4; filter++) {
            let cost = 0;
            for (let x = 0; x < stride; x++) {
                const a = x >= channels ? (pixels[row + x - channels] ?? 0) : 0;
                const b = y > 0 ? (pixels[above + x] ?? 0) : 0;
                const c = x >= channels && y > 0 ? (pixels[above + x - channels] ?? 0) : 0;
                const value = ((pixels[row + x] ?? 0) - predict(filter, a, b, c)) & 0xff;
                cost += value < 128 ? value : 256 - value;
            }
            if (cost < best.cost) best = { filter, cost };
        }
        for (let x = 0; x < stride; x++) {
            const a = x >= channels ? (pixels[row + x - channels] ?? 0) : 0;
            const b = y > 0 ? (pixels[above + x] ?? 0) : 0;
            const c = x >= channels && y > 0 ? (pixels[above + x - channels] ?? 0) : 0;
            candidate[x] = ((pixels[row + x] ?? 0) - predict(best.filter, a, b, c)) & 0xff;
        }
        filtered[y * (stride + 1)] = best.filter;
        filtered.set(candidate, y * (stride + 1) + 1);
    }
    const header = Buffer.alloc(13);
    header.writeUInt32BE(width, 0);
    header.writeUInt32BE(height, 4);
    header.set([8, colourType, 0, 0, 0], 8);
    return Buffer.concat([signature, chunk("IHDR", header), chunk("IDAT", deflateSync(filtered, { level: 9 })), chunk("IEND", new Uint8Array(0))]);
}
