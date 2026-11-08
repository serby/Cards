// Records Instruments traces with xctrace and reads the tables they export.
//
// A recording starts before the app does something and runs for as long as
// that takes to settle, then saves itself; finished() waits for that. An
// export is XML: a table gives its columns once, in a <schema>, and each
// <row> a cell per column. A cell that repeats an earlier
// value refers to it (ref="12") instead of repeating it, inside backtraces too,
// so readTable resolves every reference.
//
// Usage: import { exportTable, framesOf, readTable, startRecording, traceStartDate } from "./lib/xctrace.ts";

import { existsSync } from "node:fs";
import { capture, start } from "./xcode.ts";

/// An element of an export, with its attributes, child elements and text.
export interface XmlElement {
    name: string;
    attributes: Record<string, string>;
    children: XmlElement[];
    text: string;
}

const namedEntities: Record<string, string> = { amp: "&", lt: "<", gt: ">", quot: "\"", apos: "'" };

function decodeEntities(text: string): string {
    return text.replace(/&(#x[0-9a-f]+|#\d+|\w+);/gi, (whole, entity: string) => {
        if (/^#x/i.test(entity)) return String.fromCodePoint(Number.parseInt(entity.slice(2), 16));
        if (entity.startsWith("#")) return String.fromCodePoint(Number.parseInt(entity.slice(1), 10));
        return namedEntities[entity] ?? whole;
    });
}

/// Parses the XML xctrace writes: elements, attributes in either quotes, text
/// and entities. It skips the declaration and comments, and needs no DTD.
export function parseXml(xml: string): XmlElement {
    const document: XmlElement = { name: "#document", attributes: {}, children: [], text: "" };
    const open = [document];
    const token = /<\?[^>]*\?>|<!--[\s\S]*?-->|<\/([\w:.-]+)\s*>|<([\w:.-]+)((?:\s+[\w:.-]+\s*=\s*(?:"[^"]*"|'[^']*'))*)\s*(\/?)>|([^<]+)/g;
    for (const [, closing, opening, attributeText, selfClosing, text] of xml.matchAll(token)) {
        const parent = open.at(-1) ?? document;
        if (closing) {
            if (open.length > 1) open.pop();
        } else if (opening) {
            const attributes: Record<string, string> = {};
            for (const [, name, double, single] of (attributeText ?? "").matchAll(/([\w:.-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')/g)) {
                if (name) attributes[name] = decodeEntities(double ?? single ?? "");
            }
            const element: XmlElement = { name: opening, attributes, children: [], text: "" };
            parent.children.push(element);
            if (!selfClosing) open.push(element);
        } else if (text) {
            parent.text += decodeEntities(text);
        }
    }
    return document;
}

/// One cell of a row.
export interface Cell {
    /// The value as Instruments shows it, such as "00:01.234.567" or "2.09 ms".
    shown: string;
    /// The raw value, such as a time in nanoseconds, or "" for a cell made of
    /// other elements, such as a thread or a backtrace.
    value: string;
    /// The cell's element, its references resolved.
    element: XmlElement;
}

/// A row: its cells by column mnemonic, such as "time" or "thread". An empty
/// cell (<sentinel/>) is left out.
export type Row = Record<string, Cell | undefined>;

/// An exported table's rows, and a way to resolve references inside a cell.
export interface Table {
    rows: Row[];
    resolve(element: XmlElement): XmlElement;
}

/// Reads the rows of every table in an export of `--xpath`. The columns come
/// from the last <schema>, as xctrace writes it once for several tables of the
/// same schema.
export function readTable(xml: string): Table {
    const document = parseXml(xml);
    const byId = new Map<string, XmlElement>();
    const index = (element: XmlElement): void => {
        const id = element.attributes.id;
        if (id !== undefined) byId.set(id, element);
        element.children.forEach(index);
    };
    index(document);
    const resolve = (element: XmlElement): XmlElement => {
        const ref = element.attributes.ref;
        return ref === undefined ? element : byId.get(ref) ?? element;
    };

    const rows: Row[] = [];
    let columns: string[] = [];
    const visit = (element: XmlElement): void => {
        if (element.name !== "node") {
            element.children.forEach(visit);
            return;
        }
        const schema = element.children.find((child) => child.name === "schema");
        if (schema) {
            columns = schema.children
                .filter((child) => child.name === "col")
                .map((column) => column.children.find((child) => child.name === "mnemonic")?.text.trim() ?? "");
        }
        for (const row of element.children.filter((child) => child.name === "row")) {
            const cells: Row = {};
            row.children.forEach((child, position) => {
                const column = columns[position];
                const cell = resolve(child);
                if (!column || cell.name === "sentinel") return;
                cells[column] = { shown: cell.attributes.fmt ?? cell.text.trim(), value: cell.text.trim(), element: cell };
            });
            rows.push(cells);
        }
    };
    visit(document);
    return { rows, resolve };
}

/// A frame of a backtrace: the function, or its address when Instruments
/// could not name it, and the binary it is in, when known.
export interface Frame {
    name: string;
    binary?: string;
}

/// The frames of a backtrace cell, innermost first, as xctrace lists them: a
/// <backtrace> or <tagged-backtrace> holding the frames, or one that holds a
/// <backtrace> that does.
export function framesOf(cell: Cell | undefined, table: Table): Frame[] {
    if (!cell) return [];
    const holdsFrames = (element: XmlElement) => element.children.some((child) => child.name === "frame");
    const backtrace = holdsFrames(cell.element)
        ? cell.element
        : cell.element.children.map(table.resolve).find((element) => element.name.endsWith("backtrace") && holdsFrames(element));
    if (!backtrace) return [];
    return backtrace.children
        .filter((child) => child.name === "frame")
        .map((child) => {
            const frame = table.resolve(child);
            const binary = frame.children.find((element) => element.name === "binary");
            const binaryName = binary ? table.resolve(binary).attributes.name : undefined;
            const name = frame.attributes.name ?? frame.attributes.addr ?? "?";
            return binaryName ? { name, binary: binaryName } : { name };
        });
}

/// Exports the tables `xpath` picks from a trace, as XML.
export function exportTable(trace: string, xpath: string): string {
    return capture("xcrun", ["xctrace", "export", "--input", trace, "--xpath", xpath]);
}

/// When the recording started, in milliseconds since 1970: the zero of every
/// time in the trace's tables. The table of contents gives it to the millisecond.
export function traceStartDate(trace: string): number {
    const toc = capture("xcrun", ["xctrace", "export", "--input", trace, "--toc"]);
    const match = /<start-date>([^<]+)<\/start-date>/.exec(toc);
    const date = match?.[1] ? Date.parse(match[1]) : Number.NaN;
    if (Number.isNaN(date)) throw new Error(`${trace} has no start date`);
    return date;
}

/// A recording in progress.
export interface Recording {
    /// Resolves once the recording has reached its time limit and the trace is saved.
    finished(): Promise<void>;
    /// Ends xctrace at once, without saving, and resolves once it has gone:
    /// for a run that failed, so nothing is left writing its trace.
    cancel(): Promise<void>;
}

/// How long to wait for xctrace to start recording, and to save once it stops.
const startTimeoutMs = 120_000;
const saveTimeoutMs = 300_000;

/// Starts `xctrace record` with `args` (the template, instruments, device and
/// target) for `durationMs`, writing to `output`, and resolves once it is
/// recording. It stops at a time limit rather than Ctrl-C: a process started
/// in the background inherits an ignored SIGINT, which xctrace keeps, so
/// Ctrl-C would never stop it there.
export function startRecording(args: string[], output: string, durationMs: number): Promise<Recording> {
    const child = start("xcrun", ["xctrace", "record", ...args, "--time-limit", `${Math.ceil(durationMs)}ms`, "--no-prompt", "--output", output], { stdio: ["ignore", "pipe", "pipe"] });
    let printed = "";
    let exited = false;
    const exit = new Promise<number | null>((resolve) => {
        child.on("exit", (code) => {
            exited = true;
            resolve(code);
        });
    });
    for (const stream of [child.stdout, child.stderr]) {
        stream?.setEncoding("utf8").on("data", (text: string) => {
            printed += text;
        });
    }

    const cancel = async (): Promise<void> => {
        if (!exited) child.kill("SIGKILL");
        // A process that never started never exits, so wait only so long.
        await Promise.race([exit, new Promise((resolve) => setTimeout(resolve, 10_000).unref())]);
    };
    const finished = async (): Promise<void> => {
        try {
            const code = await withTimeout(exit, durationMs + saveTimeoutMs, "xctrace did not stop and save the trace");
            if (code !== 0 || !existsSync(output)) throw new Error(`xctrace record failed (exit code ${code}):\n${printed.trim()}`);
        } catch (error) {
            await cancel();
            throw error;
        }
    };

    return new Promise((resolve, reject) => {
        const started = Date.now();
        const poll = setInterval(() => {
            if (printed.includes("Ctrl-C to stop")) {
                clearInterval(poll);
                resolve({ finished, cancel });
            } else if (exited || Date.now() - started > startTimeoutMs) {
                clearInterval(poll);
                void cancel().then(() => reject(new Error(`xctrace did not start recording:\n${printed.trim()}`)));
            }
        }, 50);
        child.on("error", (error) => {
            clearInterval(poll);
            reject(error);
        });
    });
}

function withTimeout<T>(promise: Promise<T>, milliseconds: number, message: string): Promise<T> {
    let timer: NodeJS.Timeout | undefined;
    const timeout = new Promise<never>((_resolve, reject) => {
        timer = setTimeout(() => reject(new Error(message)), milliseconds);
    });
    return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}
