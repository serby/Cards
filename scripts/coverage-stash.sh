#!/bin/bash
# Stash the current coverage .profdata so it survives the next test run's overwrite.
# Run this AFTER a ⌘U test pass and BEFORE the next one.
#
# Stashes to: ./.coverage-stash/<timestamp>.profdata (gitignored).
#
# Wire it into the Cards scheme as a Test post-action to automate:
#   Edit Scheme → Test → Post-actions → New Run Script → "$SRCROOT/scripts/coverage-stash.sh"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
STASH_DIR="$PROJECT_DIR/.coverage-stash"
mkdir -p "$STASH_DIR"

DD=$(ls -td "$HOME"/Library/Developer/Xcode/DerivedData/Cards-* 2>/dev/null | head -n 1)
if [[ -z "$DD" ]]; then
    echo "error: no Cards-* DerivedData found" >&2
    exit 1
fi

PROF=$(find "$DD/Build/ProfileData" -name 'Coverage.profdata' -type f 2>/dev/null \
    | xargs -I{} stat -f '%m %N' "{}" 2>/dev/null \
    | sort -rn | head -n 1 | sed -E 's/^[0-9.]+ //')

if [[ -z "$PROF" ]]; then
    echo "error: no Coverage.profdata under $DD/Build/ProfileData" >&2
    echo "       (run tests with code coverage enabled first)" >&2
    exit 1
fi

TS=$(date -u +%Y-%m-%dT%H-%M-%SZ)
DEST="$STASH_DIR/$TS.profdata"
cp "$PROF" "$DEST"

# Also stash the binary that produced it — llvm-cov needs the matching binary.
BIN=$(find "$DD/Build/Products" -path '*Cards.app/Cards' -type f 2>/dev/null | head -n 1)
if [[ -n "$BIN" ]]; then
    cp "$BIN" "$STASH_DIR/$TS.binary"
fi

echo "Stashed: $DEST"
[[ -n "$BIN" ]] && echo "Binary:  $STASH_DIR/$TS.binary"
