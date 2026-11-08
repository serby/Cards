// Builds the app and its tests once for the simulator, with the Xcode in
// .xcode-version, into a folder that runs on any Mac (lib/built-tests.ts): CI's
// build job, whose folder every test job runs with run-tests.ts --built.
//
// Usage: node scripts/build-tests.ts [--out <dir>]
//   --out  where the built tests go, /tmp/cards-tests/built unless given

import { resolve } from "node:path";
import { parseArgs } from "node:util";
import { buildTests, testRunFile } from "./lib/built-tests.ts";

const usage = "Usage: node scripts/build-tests.ts [--out <dir>]";

let out: string;
try {
    const { values } = parseArgs({ options: { out: { type: "string", default: "/tmp/cards-tests/built" } }, allowPositionals: false });
    out = resolve(values.out!);
} catch (error) {
    console.error(`${error instanceof Error ? error.message : String(error)}\n${usage}`);
    process.exit(2);
}

try {
    await buildTests(out);
    console.log(`\nThe built tests are in ${out}, run by ${testRunFile(out)}`);
} catch (error) {
    console.error(`error: ${error instanceof Error ? error.message : String(error)}`);
    process.exit(1);
}
