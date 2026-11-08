// Tests for how built tests are made to load the test frameworks kept with
// them (scripts/lib/built-tests.ts). Run with:
// node --test scripts/built-tests.test.ts

import assert from "node:assert/strict";
import { describe, test } from "node:test";

import { withBuiltFrameworks } from "./lib/built-tests.ts";

/// The environment Xcode 27.1 writes in the .xctestrun for each test target.
const xctestrun = `<dict>
    <key>DYLD_FRAMEWORK_PATH</key>
    <string>__TESTROOT__/Debug-iphonesimulator:__TESTROOT__/Debug-iphonesimulator/PackageFrameworks:__PLATFORMS__/iPhoneSimulator.platform/Developer/Library/Frameworks</string>
    <key>DYLD_INSERT_LIBRARIES</key>
    <string>__TESTHOST__/Frameworks/libXCTestBundleInject.dylib:/usr/lib/libRPAC.dylib</string>
    <key>DYLD_LIBRARY_PATH</key>
    <string>__TESTROOT__/Debug-iphonesimulator:__PLATFORMS__/iPhoneSimulator.platform/Developer/usr/lib</string>
</dict>`;

describe("built tests", () => {
    test("load the test frameworks kept with them, not the running Xcode's", () => {
        const changed = withBuiltFrameworks(xctestrun);
        assert.ok(!changed.includes("__PLATFORMS__"));
        assert.match(changed, /PackageFrameworks:__TESTROOT__\/TestPlatform\/Library\/Frameworks<\/string>/);
        assert.match(changed, /Debug-iphonesimulator:__TESTROOT__\/TestPlatform\/usr\/lib<\/string>/);
        assert.match(changed, /__TESTHOST__\/Frameworks\/libXCTestBundleInject\.dylib/);
    });

    test("refuse anything else from the running Xcode, which they do not keep", () => {
        assert.throws(() => withBuiltFrameworks(xctestrun.replace("Developer/usr/lib", "Developer/Library/Xcode/Agents")), /Library\/Xcode\/Agents/);
        assert.throws(() => withBuiltFrameworks(`${xctestrun}<string>__PLATFORMS__/MacOSX.platform</string>`), /more of the running Xcode/);
    });
});
