#!/usr/bin/env bash
# benchmark.sh - Times 4 build scenarios for a given build command
# Usage: ./tools/benchmark.sh [xcode|bazel]
set -euo pipefail

MODE="${1:-xcode}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESULTS_DIR="$PROJECT_DIR/.kiro/bazel-migration"
SIMULATOR_ID="5853D62C-B1F2-4FD1-B120-45C323725F94"  # iPhone 16 (18.1)
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"

# ── helpers ──────────────────────────────────────────────────────────────────

elapsed() {
  local start=$1 end=$2
  echo "$(echo "scale=1; ($end - $start) / 1000000000" | bc)s"
}

ns() { date +%s%N; }

dir_size() {
  du -sh "$1" 2>/dev/null | cut -f1
}

xcode_build() {
  xcodebuild \
    -project "$PROJECT_DIR/Cards.xcodeproj" \
    -scheme Cards \
    -destination "id=$SIMULATOR_ID" \
    -configuration Debug \
    "$@" 2>&1 | tail -3
}

bazel_build() {
  bazel build //Cards:Cards \
    --ios_simulator_device="iPhone 16" \
    --ios_simulator_version=18.1 \
    "$@" 2>&1 | tail -3
}

run_build() {
  if [[ "$MODE" == "xcode" ]]; then
    xcode_build "$@"
  else
    bazel_build "$@"
  fi
}

# ── scenario 1: clean build ───────────────────────────────────────────────────

echo "==> Scenario 1: Clean build"
if [[ "$MODE" == "xcode" ]]; then
  xcode_build clean > /dev/null 2>&1 || true
  # Remove derived data for this project
  find "$DERIVED_DATA" -maxdepth 1 -name "Cards-*" -exec rm -rf {} + 2>/dev/null || true
else
  bazel clean --expunge 2>&1 | tail -1
fi
T1=$(ns)
run_build build
T2=$(ns)
CLEAN_TIME=$(elapsed $T1 $T2)
echo "   Clean build: $CLEAN_TIME"

# ── scenario 2: no-change rebuild ────────────────────────────────────────────

echo "==> Scenario 2: No-change rebuild"
T1=$(ns)
run_build build
T2=$(ns)
NOCHANGE_TIME=$(elapsed $T1 $T2)
echo "   No-change rebuild: $NOCHANGE_TIME"

# ── scenario 3: single file change ───────────────────────────────────────────

echo "==> Scenario 3: Single Swift file change"
TOUCH_FILE="$PROJECT_DIR/Cards/Core/Services/PerformanceTracker.swift"
touch "$TOUCH_FILE"
T1=$(ns)
run_build build
T2=$(ns)
FILECHANGE_TIME=$(elapsed $T1 $T2)
echo "   Single file change: $FILECHANGE_TIME"

# ── scenario 4: SPM change (simulate by touching Package.resolved) ────────────

echo "==> Scenario 4: SPM-only change"
if [[ "$MODE" == "xcode" ]]; then
  # Xcode: invalidate SPM cache by touching resolved file
  touch "$PROJECT_DIR/Cards.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
  T1=$(ns)
  run_build build
  T2=$(ns)
else
  # Bazel: clean only external repos cache
  bazel clean 2>&1 | tail -1
  T1=$(ns)
  run_build build
  T2=$(ns)
fi
SPM_TIME=$(elapsed $T1 $T2)
echo "   SPM change rebuild: $SPM_TIME"

# ── sizes ─────────────────────────────────────────────────────────────────────

echo "==> Measuring sizes"
if [[ "$MODE" == "xcode" ]]; then
  DD_DIR=$(find "$DERIVED_DATA" -maxdepth 1 -name "Cards-*" 2>/dev/null | head -1)
  DD_SIZE=$(dir_size "$DD_DIR")
  APP_PATH=$(find "$DD_DIR" -name "Cards.app" 2>/dev/null | head -1)
  APP_SIZE=$(dir_size "$APP_PATH")
  OUTPUT_FILE="$RESULTS_DIR/benchmarks-xcode.md"
else
  CACHE_SIZE=$(dir_size "$HOME/bazel_disk_cache")
  OUTPUT_BASE=$(bazel info output_base 2>/dev/null)
  OUTPUT_BASE_SIZE=$(dir_size "$OUTPUT_BASE")
  APP_PATH=$(bazel cquery //Cards:Cards --output=files 2>/dev/null | head -1)
  APP_SIZE=$(dir_size "$APP_PATH")
  OUTPUT_FILE="$RESULTS_DIR/benchmarks-bazel.md"
fi

# ── write results ─────────────────────────────────────────────────────────────

mkdir -p "$RESULTS_DIR"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M")

if [[ "$MODE" == "xcode" ]]; then
cat > "$OUTPUT_FILE" << EOF
# Xcode Baseline Benchmarks

Captured: $TIMESTAMP
Simulator: iPhone 16 (iOS 18.1)
Configuration: Debug

## Build Times

| Scenario | Time |
|----------|------|
| 1. Clean build | $CLEAN_TIME |
| 2. No-change rebuild | $NOCHANGE_TIME |
| 3. Single file change | $FILECHANGE_TIME |
| 4. SPM change rebuild | $SPM_TIME |

## Sizes

| Metric | Size |
|--------|------|
| Derived Data | $DD_SIZE |
| .app bundle | $APP_SIZE |
EOF
else
cat > "$OUTPUT_FILE" << EOF
# Bazel Benchmarks

Captured: $TIMESTAMP
Simulator: iPhone 16 (iOS 18.1)
Configuration: Debug (fastbuild)

## Build Times

| Scenario | Time |
|----------|------|
| 1. Clean build | $CLEAN_TIME |
| 2. No-change rebuild | $NOCHANGE_TIME |
| 3. Single file change | $FILECHANGE_TIME |
| 4. SPM change rebuild | $SPM_TIME |

## Sizes

| Metric | Size |
|--------|------|
| Disk cache (~/bazel_disk_cache) | $CACHE_SIZE |
| Output base | $OUTPUT_BASE_SIZE |
| .app bundle | $APP_SIZE |
EOF
fi

echo ""
echo "Results written to $OUTPUT_FILE"
