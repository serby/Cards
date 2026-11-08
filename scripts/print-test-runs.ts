// Prints every test run in lib/test-devices.ts as JSON, for CI's test matrix:
// its key, the runner image it needs and a name for the job, so the workflow
// takes the devices and iOS versions from the same list as `make test`.
//
// Usage: node scripts/print-test-runs.ts

import { testRuns, xcodeVersionFor } from "./lib/test-devices.ts";
import { pinnedXcodeVersion } from "./lib/xcode.ts";

const pinned = pinnedXcodeVersion();
const runs = testRuns.map((run) => ({
    key: run.key,
    image: run.image,
    name: `${run.suite === "unit" ? "Unit" : "UI"} tests, ${run.simulator.model}, iOS ${run.simulator.download ?? run.simulator.os}, Xcode ${xcodeVersionFor(run, pinned, true)}`,
}));
console.log(JSON.stringify(runs));
