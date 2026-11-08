// Tests for reading xctrace exports (scripts/lib/xctrace.ts). Run with:
// node --test scripts/xctrace.test.ts

import assert from "node:assert/strict";
import { describe, test } from "node:test";

import { framesOf, parseXml, readTable } from "./lib/xctrace.ts";

describe("parseXml", () => {
    test("reads elements, both quotes, entities and text, and skips the declaration", () => {
        const document = parseXml(`<?xml version="1.0"?>\n<a x="1 &amp; 2" y='it&apos;s'><b/>caf&#233; &lt;3<c z="&#x41;">in</c></a>`);
        const a = document.children[0];
        assert.equal(a?.name, "a");
        assert.deepEqual(a?.attributes, { x: "1 & 2", y: "it's" });
        assert.deepEqual(a?.children.map((child) => child.name), ["b", "c"]);
        assert.equal(a?.text.trim(), "café <3");
        assert.equal(a?.children[1]?.attributes.z, "A");
        assert.equal(a?.children[1]?.text, "in");
    });
});

/// Two tables of one schema, as xctrace exports them: the schema comes once,
/// and repeated values refer back by id.
const twoTables = `<?xml version="1.0"?>
<trace-query-result>
<node xpath='//trace-toc[1]/run[1]/data[1]/table[8]'><schema name="os-signpost"><col><mnemonic>time</mnemonic></col><col><mnemonic>thread</mnemonic></col><col><mnemonic>name</mnemonic></col><col><mnemonic>message</mnemonic></col></schema>
<row><event-time id="1" fmt="00:01.000.000">1000000000</event-time><thread id="2" fmt="Main Thread (0x1) (Cards, pid: 7)"><tid id="3" fmt="0x1">1</tid></thread><string id="4" fmt="Commit">Commit</string><sentinel/></row>
</node>
<node xpath='//trace-toc[1]/run[1]/data[1]/table[9]'>
<row><event-time id="5" fmt="00:01.500.000">1500000000</event-time><thread ref="2"/><string ref="4"/><string id="6" fmt="seed=3">seed=3</string></row>
</node>
</trace-query-result>`;

describe("readTable", () => {
    test("keeps the columns across tables of the same schema and resolves references", () => {
        const { rows } = readTable(twoTables);
        assert.equal(rows.length, 2);
        assert.equal(rows[0]?.time?.value, "1000000000");
        assert.equal(rows[0]?.time?.shown, "00:01.000.000");
        assert.equal(rows[1]?.thread?.shown, "Main Thread (0x1) (Cards, pid: 7)");
        assert.equal(rows[1]?.name?.shown, "Commit");
        assert.equal(rows[1]?.message?.shown, "seed=3");
    });

    test("leaves empty cells out", () => {
        const { rows } = readTable(twoTables);
        assert.equal(rows[0]?.message, undefined);
    });

    test("reads nothing from an export with no rows", () => {
        assert.deepEqual(readTable(`<trace-query-result><node xpath='x'><schema name="s"><col><mnemonic>time</mnemonic></col></schema></node></trace-query-result>`).rows, []);
    });
});

describe("framesOf", () => {
    const samples = `<trace-query-result><node xpath='x'><schema name="time-profile"><col><mnemonic>time</mnemonic></col><col><mnemonic>stack</mnemonic></col></schema>
<row><sample-time id="1" fmt="00:00.001">1000000</sample-time><tagged-backtrace id="2" fmt="body"><backtrace id="3"><frame id="4" name="CardListScreen.body.getter" addr="0x10"><binary id="5" name="Cards" path="/Cards.app/Cards"/></frame><frame id="6" name="0x1c95" addr="0x1c95"/><frame id="7" name="main" addr="0x20"><binary ref="5"/></frame></backtrace></tagged-backtrace></row>
<row><sample-time id="8" fmt="00:00.002">2000000</sample-time><tagged-backtrace id="9" fmt="body"><backtrace id="10"><frame id="11" name="objc_msgSend" addr="0x30"><binary id="12" name="libobjc.A.dylib"/></frame><frame ref="4"/><frame ref="7"/></backtrace></tagged-backtrace></row>
</node></trace-query-result>`;

    test("lists a backtrace's frames innermost first, with their binaries", () => {
        const table = readTable(samples);
        assert.deepEqual(framesOf(table.rows[0]?.stack, table), [
            { name: "CardListScreen.body.getter", binary: "Cards" },
            { name: "0x1c95" },
            { name: "main", binary: "Cards" },
        ]);
    });

    test("resolves frames that refer to earlier ones", () => {
        const table = readTable(samples);
        assert.deepEqual(framesOf(table.rows[1]?.stack, table).map((frame) => `${frame.name}@${frame.binary ?? "?"}`), [
            "objc_msgSend@libobjc.A.dylib",
            "CardListScreen.body.getter@Cards",
            "main@Cards",
        ]);
    });

    test("gives no frames for a missing cell", () => {
        assert.deepEqual(framesOf(undefined, readTable(samples)), []);
    });
});
