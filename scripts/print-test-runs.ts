// Prints the test runs CI runs (ciTestRuns in lib/test-devices.ts) as JSON, for CI's test matrix:
// its key, the runner image it needs and a name for the job, so the workflow
// takes the devices and iOS versions from the same list as `make test`. The
// name gives the Xcode that runs the tests where it is not the one that built
// them.
//
// Usage: node scripts/print-test-runs.ts

import { ciTestRuns } from "./lib/test-devices.ts";

const runs = ciTestRuns.map((run) => ({
    key: run.key,
    image: run.image,
    name: `${run.suite === "unit" ? "Unit" : "UI"} tests, ${run.simulator.model}, iOS ${run.simulator.download ?? run.simulator.os}${run.ciXcode ? `, run by Xcode ${run.ciXcode}` : ""}`,
}));
console.log(JSON.stringify(runs));
