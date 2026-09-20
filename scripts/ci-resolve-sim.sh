#!/bin/bash
# Pick the highest-version iOS runtime that supports the optional requested
# device type, ensure the simulator is created and booted, then write its exact
# name, runtime version, model, and UDID to stdout for $GITHUB_OUTPUT.
#
# Usage:
#   scripts/ci-resolve-sim.sh
#   scripts/ci-resolve-sim.sh "iPhone 16 Pro Max"
#   scripts/ci-resolve-sim.sh "iPad Pro 13-inch (M4)"
#
# Workaround for two macos-26 runner issues seen on 2026-06-18:
#   1. rules_apple's test runner re-creates a simulator named
#      "New-<DEVICE>-<VERSION>" — pre-creating that name avoids its slow
#      creation/boot loop.
#   2. CoreSimulatorService takes ~10-15s after `simctl bootstatus` returns
#      before xcodebuild can launch tests; without a sleep we see
#      "Supported platforms ... is empty" + 150s stuck-launch + interrupt.
set -euo pipefail

PREFERRED_DEVICE="${1:-}"

PICK=$(xcrun simctl list -j devicetypes runtimes | PREFERRED_DEVICE="$PREFERRED_DEVICE" python3 -c '
import json, os, re, sys
data = json.load(sys.stdin)
preferred = os.environ["PREFERRED_DEVICE"]
rts = [r for r in data["runtimes"]
       if r.get("isAvailable") and r["platform"] == "iOS"]
rts.sort(key=lambda r: tuple(int(x) for x in r["version"].split(".")), reverse=True)

for rt in rts:
    supported = {x["identifier"] for x in rt.get("supportedDeviceTypes", [])}
    dts = [d for d in data["devicetypes"] if d["identifier"] in supported]
    if preferred:
        matches = [d for d in dts if d["name"] == preferred]
        if not matches:
            continue
        dt = matches[0]
    else:
        phones = [d for d in dts if "iPhone" in d["name"]]
        plain = [d for d in phones if re.match(r"^iPhone \d+$", d["name"])]
        if not phones:
            continue
        dt = (plain or phones)[0]
    major_minor = ".".join(rt["version"].split(".")[:2])
    print("|".join([dt["name"], major_minor, rt["identifier"]]))
    sys.exit()

target = preferred or "an iPhone"
sys.exit(f"No available iOS runtime supports {target}")
')
SIM_NAME="${PICK%%|*}"
REST="${PICK#*|}"
SIM_VERSION="${REST%%|*}"
SIM_RUNTIME="${REST#*|}"

echo "Picked: $SIM_NAME (iOS $SIM_VERSION) runtime=$SIM_RUNTIME" >&2

DEVICE_NAME="CI-${SIM_NAME}-${SIM_VERSION}"

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
xcrun simctl status_bar "$UDID" override \
    --time 14:34 \
    --batteryState charged \
    --batteryLevel 100 \
    --wifiBars 3 \
    --cellularBars 4 1>&2
sleep 15
xcrun simctl list devices booted >&2

# ONLY the GITHUB_OUTPUT key=value pairs go to stdout.
echo "device=$DEVICE_NAME"
echo "version=$SIM_VERSION"
echo "model=$SIM_NAME"
echo "udid=$UDID"
