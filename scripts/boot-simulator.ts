// Boots an iOS simulator for tests (scripts/lib/simulator.ts): the newest iOS
// runtime that supports the device type and that the selected Xcode's SDK can
// build for, in a simulator named CI-<device>-<version> that is created once and
// then reused. It prints the simulator's name, runtime version, model and UDID
// on standard output as key=value lines for $GITHUB_OUTPUT, and its progress on
// standard error. With no device type it picks an iPhone.
//
// Usage: node scripts/boot-simulator.ts [<device type>]
//   node scripts/boot-simulator.ts "iPhone 16 Pro Max"
//   node scripts/boot-simulator.ts "iPad Pro 13-inch (M4)"

import { bootSimulator } from "./lib/simulator.ts";

const args = process.argv.slice(2);
if (args.length > 1) {
    console.error('Usage: node scripts/boot-simulator.ts [<device type>], such as "iPhone 16 Pro Max"');
    process.exit(2);
}

try {
    const simulator = await bootSimulator(args[0]);
    // Only these lines go to standard output.
    console.log(`device=${simulator.device}`);
    console.log(`version=${simulator.version}`);
    console.log(`model=${simulator.model}`);
    console.log(`udid=${simulator.udid}`);
} catch (error) {
    console.error(`error: ${error instanceof Error ? error.message : String(error)}`);
    process.exit(1);
}
