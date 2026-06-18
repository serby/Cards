#!/bin/bash
# Run the test suite against iPhone + iPad in a SHARED DerivedData,
# then stash the merged Coverage.profdata so the next run can't overwrite it.
#
# Re-running this is fast: shared DerivedData means incremental builds.
# Each run produces one .profdata in .coverage-stash/<timestamp>.profdata.
# Use scripts/coverage-report.sh N to merge the last N stashed files.
#
# Usage:
#   scripts/coverage-run.sh [-- extra-xcodebuild-args...]
#
# Examples:
#   scripts/coverage-run.sh
#   scripts/coverage-run.sh -- -only-testing:CardsUITests/CardsUITests/testLaunch
#   scripts/coverage-run.sh -- -test-iterations 3 -retry-tests-on-failure

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DD="$PROJECT_DIR/build/cov"
STASH_DIR="$PROJECT_DIR/.coverage-stash"
mkdir -p "$STASH_DIR"

# Allow extra xcodebuild args after `--`.
EXTRA=()
saw_dashdash=0
for arg in "$@"; do
    if [[ $saw_dashdash -eq 1 ]]; then
        EXTRA+=("$arg")
    elif [[ "$arg" == "--" ]]; then
        saw_dashdash=1
    else
        echo "Unknown arg before '--': $arg" >&2
        exit 2
    fi
done

cd "$PROJECT_DIR"

echo "Running tests with shared DerivedData at $DD ..." >&2
set +e
xcodebuild test \
    -project Cards.xcodeproj \
    -scheme Cards \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
    -enableCodeCoverage YES \
    -derivedDataPath "$DD" \
    -resultBundlePath "$DD/result-$(date +%s).xcresult" \
    -retry-tests-on-failure \
    -test-iterations 3 \
    ${EXTRA[@]+"${EXTRA[@]}"}
TEST_RC=$?
set -e

if [[ $TEST_RC -ne 0 ]]; then
    echo "warning: xcodebuild test exited $TEST_RC (some tests failed)" >&2
    echo "         stashing profdata anyway so partial coverage is preserved" >&2
fi

PROF=$(find "$DD/Build/ProfileData" -name 'Coverage.profdata' -type f 2>/dev/null \
    | xargs -I{} stat -f '%m %N' "{}" 2>/dev/null \
    | sort -rn | head -n 1 | sed -E 's/^[0-9.]+ //')

if [[ -z "$PROF" ]]; then
    echo "error: no Coverage.profdata under $DD/Build/ProfileData" >&2
    exit 1
fi

TS=$(date -u +%Y-%m-%dT%H-%M-%SZ)
DEST="$STASH_DIR/$TS.profdata"
cp "$PROF" "$DEST"

# Stash the matching binary too — llvm-cov requires PGO hashes to match the
# .profdata that produced them, so each profdata gets its own binary snapshot.
BIN=$(find "$DD/Build/Products" -path '*Cards.app/Cards' -type f 2>/dev/null | head -n 1)
if [[ -n "$BIN" ]]; then
    cp "$BIN" "$STASH_DIR/$TS.binary"
fi

echo
echo "Stashed: $DEST"
[[ -n "$BIN" ]] && echo "Binary:  $STASH_DIR/$TS.binary"
echo
echo "Stash now contains $(ls -1 "$STASH_DIR"/*.profdata 2>/dev/null | wc -l | tr -d ' ') profdata file(s)."
echo "Merge them: scripts/coverage-report.sh N --open"

exit $TEST_RC
