#!/bin/bash
# Pick the highest-version iOS runtime + a "plain" iPhone (no Pro/Plus) that
# the runtime supports, ensure the device is created and booted, then write
# `device=...` and `version=...` to stdout for $GITHUB_OUTPUT.
#
# Workaround for two macos-26 runner issues seen on 2026-06-18:
#   1. rules_apple's test runner re-creates a simulator named
#      "New-<DEVICE>-<VERSION>" — pre-creating that name avoids its slow
#      creation/boot loop.
#   2. CoreSimulatorService takes ~10-15s after `simctl bootstatus` returns
#      before xcodebuild can launch tests; without a sleep we see
#      "Supported platforms ... is empty" + 150s stuck-launch + interrupt.
set -euo pipefail

PICK=$(xcrun simctl list -j devicetypes runtimes | python3 -c '
import json, re, sys
data = json.load(sys.stdin)
rts = [r for r in data["runtimes"]
       if r.get("isAvailable") and r["platform"] == "iOS"]
rts.sort(key=lambda r: tuple(int(x) for x in r["version"].split(".")), reverse=True)
rt = rts[0]
supported = {x["identifier"] for x in rt.get("supportedDeviceTypes", [])}
dts = [d for d in data["devicetypes"]
       if d["identifier"] in supported and "iPhone" in d["name"]]
plain = [d for d in dts if re.match(r"^iPhone \d+$", d["name"])]
dt = (plain or dts)[0]
major_minor = ".".join(rt["version"].split(".")[:2])
print("|".join([dt["name"], major_minor, rt["identifier"]]))
')
SIM_NAME="${PICK%%|*}"
REST="${PICK#*|}"
SIM_VERSION="${REST%%|*}"
SIM_RUNTIME="${REST#*|}"

echo "Picked: $SIM_NAME (iOS $SIM_VERSION) runtime=$SIM_RUNTIME" >&2

DEVICE_NAME="New-${SIM_NAME}-${SIM_VERSION}"

UDID=$(xcrun simctl list devices -j | python3 -c "
import json, sys
name = '$DEVICE_NAME'
for rt, ds in json.load(sys.stdin)['devices'].items():
    for d in ds:
        if d['name'] == name and d.get('isAvailable'):
            print(d['udid']); sys.exit()
")

if [ -z "$UDID" ]; then
    UDID=$(xcrun simctl create "$DEVICE_NAME" "$SIM_NAME" "$SIM_RUNTIME")
    echo "Created simulator $DEVICE_NAME ($UDID)" >&2
else
    echo "Reusing simulator $DEVICE_NAME ($UDID)" >&2
fi

xcrun simctl boot "$UDID" 2>/dev/null >&2 || true
xcrun simctl bootstatus "$UDID" -b 1>&2
sleep 15
xcrun simctl list devices booted >&2

# ONLY the GITHUB_OUTPUT key=value pairs go to stdout.
echo "device=$SIM_NAME"
echo "version=$SIM_VERSION"
