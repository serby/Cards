// Tests for scripts/lib/translation.ts. Run with: node --test scripts/translation.test.ts

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { describe, test } from "node:test";

import { catalogueOf, unit } from "./fixtures/string-catalogues/test-project.ts";
import { formatCatalogue, unitsOf } from "./lib/string-catalogues.ts";
import { buildPrompt, parseReply, payloadFor, runCommand, translate } from "./lib/translation.ts";

describe("replies", () => {
    const body = '{"targetLanguage": "ja", "units": [{"catalogue": "Cards/Localizable.xcstrings", "key": "Settings", "translation": "設定"}]}';
    const expected = [{ catalogue: "Cards/Localizable.xcstrings", key: "Settings", translation: "設定" }];

    test("parse as strict JSON", () => {
        assert.deepEqual(parseReply(body, "ja"), expected);
        assert.deepEqual(parseReply(`\n  ${body}\n`, "ja"), expected);
        assert.deepEqual(parseReply(JSON.stringify(expected)), expected);
    });

    test("tolerate one code fence around the whole reply", () => {
        assert.deepEqual(parseReply(`\`\`\`json\n${body}\n\`\`\``, "ja"), expected);
        assert.deepEqual(parseReply(`\`\`\`\n${body}\n\`\`\`\n`, "ja"), expected);
    });

    test("refuse anything else", () => {
        assert.throws(() => parseReply(`Here you go:\n${body}`, "ja"), /not valid JSON/);
        assert.throws(() => parseReply(`\`\`\`json\n${body}\n\`\`\`\nHope that helps!`, "ja"), /not valid JSON/);
        assert.throws(() => parseReply('{"translations": []}', "ja"), /no "units" list/);
        assert.throws(() => parseReply(body, "ko"), /for ja, not ko/);
        assert.throws(() => parseReply('{"units": [{"key": "Settings"}]}', "ja"), /unit 1 .*"catalogue"/);
    });
});

describe("the prompt", () => {
    const catalogue = catalogueOf({
        "%lld cards": { comment: "How many cards", localizations: { en: { variations: { plural: { one: unit("%lld card"), other: unit("%lld cards") } } } } },
        "At %@": { comment: "A place name", localizations: { ja: unit("at", "needs_review") } },
    });
    const payload = payloadFor(unitsOf(catalogue).units, "ja");

    test("the payload carries what a translator needs", () => {
        assert.equal(payload.targetLanguageName, "Japanese");
        assert.deepEqual(payload.units, [
            { catalogue: "Cards/Localizable.xcstrings", key: "%lld cards", comment: "How many cards", source: { plural: { one: "%lld card", other: "%lld cards" } }, placeholders: ["%lld"], pluralCategories: ["other"], translation: null },
            { catalogue: "Cards/Localizable.xcstrings", key: "At %@", comment: "A place name", source: "At %@", placeholders: ["%@"], translation: "at" },
        ]);
    });

    test("includes the brief, the language notes, Apple's conventions and any problems", () => {
        const prompt = buildPrompt(payload, "BRIEF TEXT", "NOTES TEXT", { units: [{ catalogue: "Cards/Localizable.xcstrings", key: "At %@", translation: "で", problems: ["placeholders none do not match the source's %@"] }] });
        for (const part of ["BRIEF TEXT", "## Notes for Japanese", "NOTES TEXT", "Apple", "Lock Screen", "Wallet", "formality", "pluralCategories", "## Problems with your previous reply", 'you wrote "で"']) {
            assert.ok(prompt.includes(part), `prompt should include ${part}`);
        }
        const input = /```json\n([\s\S]*)\n```\n$/.exec(prompt);
        assert.ok(input);
        assert.deepEqual(JSON.parse(input[1]), payload);
    });
});

describe("translate", () => {
    test("merges in a fixed order, however the languages finish", async () => {
        const make = () => [catalogueOf({ "Add": {}, "%lld cards": { localizations: { en: { variations: { plural: { one: unit("%lld card"), other: unit("%lld cards") } } } } } })];
        const answer = (prompt: string, lang: string) => {
            const payload = JSON.parse(/```json\n([\s\S]*)\n```\n$/.exec(prompt)![1]);
            const units = payload.units.map((u: { catalogue: string; key: string; pluralCategories?: string[] }) => ({
                catalogue: u.catalogue,
                key: u.key,
                translation: u.pluralCategories ? { plural: Object.fromEntries(u.pluralCategories.map((c) => [c, `%lld ${lang}`])) } : `${u.key} ${lang}`,
            }));
            return JSON.stringify({ targetLanguage: lang, units });
        };
        const run = async (delays: Record<string, number>) => {
            const catalogues = make();
            await translate(catalogues, {
                languages: ["de", "fr", "ja"],
                force: false,
                jobs: 3,
                batchSize: 50,
                brief: "",
                notes: () => undefined,
                ask: (prompt, lang) => new Promise((resolve) => setTimeout(() => resolve(answer(prompt, lang)), delays[lang])),
                log: () => {},
            });
            return formatCatalogue(catalogues[0].doc);
        };
        const first = await run({ de: 30, fr: 1, ja: 15 });
        assert.equal(await run({ de: 1, fr: 30, ja: 15 }), first);
        assert.equal(Object.keys(JSON.parse(first).strings.Add.localizations).join(), "de,fr,ja");
    });
});

describe("the AI command", () => {
    test("is stopped, with everything it started, when it times out", async () => {
        const marker = `${Date.now() % 100000}.${process.pid}`;
        const started = Date.now();
        await assert.rejects(runCommand(`sleep 30 & sleep ${marker}; wait`, "", 300, tmpdir()), /timed out/);
        assert.ok(Date.now() - started < 5000);
        await new Promise((resolve) => setTimeout(resolve, 200));
        assert.notEqual(spawnSync("pgrep", ["-f", `sleep ${marker}`]).status, 0, "no sleep left running");
    });

    test("reports a failure with its stderr", async () => {
        await assert.rejects(runCommand("cat >/dev/null; echo broken >&2; exit 3", "prompt", 5000, tmpdir()), /exited with 3: broken/);
        assert.equal(await runCommand("tr a-z A-Z", "prompt", 5000, tmpdir()), "PROMPT");
    });
});
