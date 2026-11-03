// Stands in for the AI command in scripts/l10n.test.ts. Reads the prompt on
// stdin, takes the payload from its Input section and replies with
// "[<lang>] <source>" for every unit, in the shape the payload asks for.
//
// FAKE_AI_MODE chooses a misbehaviour:
//   fence                   wrap the reply in a ```json code fence
//   drop-placeholders-once  drop every placeholder, unless the prompt reports problems
//   prose-once              reply with prose, unless the prompt reports problems
//   drop-placeholders       always drop placeholders
//   fail                    exit 1
// FAKE_AI_LOG, if set, is a file each prompt is appended to.

import { appendFileSync, readFileSync } from "node:fs";

type Text = string | string[] | Record<string, unknown>;

const prompt = readFileSync(0, "utf8");
if (process.env.FAKE_AI_LOG) appendFileSync(process.env.FAKE_AI_LOG, `${prompt}\n=====\n`);
const mode = process.env.FAKE_AI_MODE ?? "";
const retrying = prompt.includes("## Problems with your previous reply");

if (mode === "fail") {
    console.error("fake AI failure");
    process.exit(1);
}
if (mode === "prose-once" && !retrying) {
    console.log("Sure! Here are the translations you asked for.");
    process.exit(0);
}

const input = /```json\n([\s\S]*)\n```\s*$/.exec(prompt);
if (!input) throw new Error("no payload in the prompt");
const payload = JSON.parse(input[1]);
const lang: string = payload.targetLanguage;
const dropping = mode === "drop-placeholders" || (mode === "drop-placeholders-once" && !retrying);

function word(source: string): string {
    const text = `[${lang}] ${source}`;
    return dropping ? text.replace(/%(\d+\$)?(lld|ld|d|@)/g, "") : text;
}

function translate(source: Text, categories: string[]): Text {
    if (typeof source === "string") return word(source);
    if (Array.isArray(source)) return source.map(word);
    if ("plural" in source) {
        const forms = source.plural as Record<string, Text>;
        return { plural: Object.fromEntries(categories.map((c) => [c, translate(forms[c] ?? forms.other, categories)])) };
    }
    if ("device" in source) {
        const variants = source.device as Record<string, Text>;
        return { device: Object.fromEntries(Object.entries(variants).map(([d, v]) => [d, translate(v, categories)])) };
    }
    const substitutions = source.substitutions as Record<string, { plural: Record<string, string> }>;
    return {
        format: translate(source.format as Text, categories),
        substitutions: Object.fromEntries(
            Object.entries(substitutions).map(([name, s]) => [name, translate({ plural: s.plural }, categories)]),
        ),
    };
}

const reply = JSON.stringify({
    targetLanguage: lang,
    units: payload.units.map((unit: { catalogue: string; key: string; source: Text; pluralCategories?: string[] }) => ({
        catalogue: unit.catalogue,
        key: unit.key,
        translation: translate(unit.source, unit.pluralCategories ?? []),
    })),
});
console.log(mode === "fence" ? `\`\`\`json\n${reply}\n\`\`\`` : reply);
