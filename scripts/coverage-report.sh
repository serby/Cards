#!/bin/bash
# Combine coverage from the last N stashed profdata files (or the live one) and emit a report.
#
# Usage:
#   scripts/coverage-report.sh [N] [--html] [--open] [--current-only]
#
# Sources of profdata, in order of preference:
#   1. .coverage-stash/*.profdata (created by scripts/coverage-stash.sh as a Test post-action)
#   2. The live $DerivedData/.../Build/ProfileData/<UUID>/Coverage.profdata (last test run only)
#
# To get true multi-run union semantics, set up the post-action so each test run
# stashes its profdata before the next run overwrites it.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
STASH_DIR="$PROJECT_DIR/.coverage-stash"

# Substring patterns to exclude. Translated into one --ignore-filename-regex per entry.
EXCLUDE_SUBSTRINGS=(
    "/CardsTests/"
    "/CardsUITests/"
    "/external/swiftpkg_"
    "/external/rules_swift_package_manager"
    ".generated.swift"
)

usage() {
    cat <<EOF
Usage: $(basename "$0") [N] [--html] [--open] [--current-only]

  N               How many of the most recent stashed .profdata files to merge (default: 2)
  --html          Render HTML report at coverage-html/index.html
  --open          Open the HTML report after generation (implies --html)
  --current-only  Skip the stash and use only the live profdata in DerivedData
                  (i.e. the most recent test run only).

Run scripts/coverage-stash.sh after each test pass to populate the stash.
You can wire it into the Cards scheme as a Test post-action.

Excluded path patterns (edit EXCLUDE_SUBSTRINGS in the script to change):
$(printf '  - %s\n' "${EXCLUDE_SUBSTRINGS[@]}")
EOF
}

N=2
WANT_HTML=0
WANT_OPEN=0
CURRENT_ONLY=0
for arg in "$@"; do
    case "$arg" in
        -h|--help) usage; exit 0 ;;
        --html) WANT_HTML=1 ;;
        --open) WANT_HTML=1; WANT_OPEN=1 ;;
        --current-only) CURRENT_ONLY=1 ;;
        *[!0-9]*) echo "Unknown arg: $arg" >&2; usage >&2; exit 2 ;;
        *) N="$arg" ;;
    esac
done

# Prefer the local build/cov DerivedData (created by `make test-coverage`), fall back
# to the user's global DerivedData (used by Xcode's ⌘U).
DD=""
if [[ -d "$PROJECT_DIR/build/cov/Build/ProfileData" ]]; then
    DD="$PROJECT_DIR/build/cov"
fi
if [[ -z "$DD" ]]; then
    DD=$(ls -td "$HOME"/Library/Developer/Xcode/DerivedData/Cards-* 2>/dev/null | head -n 1)
fi
if [[ -z "$DD" ]]; then
    echo "error: no Cards DerivedData found (local build/cov or ~/Library/.../Cards-*)" >&2
    exit 1
fi

# The binary is needed for llvm-cov. Use the live build product; llvm-cov requires
# it to match the profdata's PGO hashes, so use the most recent build.
BIN=$(find "$DD/Build/Products" -path '*Cards.app/Cards' -type f 2>/dev/null | head -n 1)
if [[ -z "$BIN" ]]; then
    BIN=$(find "$PROJECT_DIR/bazel-bin" -path '*Cards.app/Cards' -type f 2>/dev/null | head -n 1)
fi
if [[ -z "$BIN" ]]; then
    echo "error: no Cards binary in $DD/Build/Products or bazel-bin" >&2
    echo "       (build the app first with ⌘U or 'make build')" >&2
    exit 1
fi

PROFDATAS=()
if [[ $CURRENT_ONLY -eq 0 && -d "$STASH_DIR" ]]; then
    while IFS= read -r line; do
        PROFDATAS+=("$line")
    done < <(
        find "$STASH_DIR" -maxdepth 1 -name '*.profdata' -type f 2>/dev/null \
            | xargs -I{} stat -f '%m %N' "{}" 2>/dev/null \
            | sort -rn \
            | head -n "$N" \
            | sed -E 's/^[0-9.]+ //'
    )
fi

if [[ ${#PROFDATAS[@]} -eq 0 ]]; then
    LIVE=$(find "$DD/Build/ProfileData" -name 'Coverage.profdata' -type f 2>/dev/null \
        | xargs -I{} stat -f '%m %N' "{}" 2>/dev/null \
        | sort -rn | head -n 1 | sed -E 's/^[0-9.]+ //')
    if [[ -z "$LIVE" ]]; then
        echo "error: no profdata found (stash empty and no live Coverage.profdata)" >&2
        echo "       run tests with code coverage enabled, then optionally stash" >&2
        exit 1
    fi
    echo "Using live profdata only (no stash):" >&2
    echo "  - $LIVE" >&2
    PROFDATAS=("$LIVE")
else
    echo "Using ${#PROFDATAS[@]} stashed profdata file(s):" >&2
    printf '  - %s\n' "${PROFDATAS[@]}" >&2
    if [[ ${#PROFDATAS[@]} -lt $N ]]; then
        echo "warning: requested $N but only ${#PROFDATAS[@]} available in stash" >&2
    fi
fi

WORK="$(mktemp -d -t cards-cov)"
trap 'rm -rf "$WORK"' EXIT

MERGED="$WORK/merged.profdata"
xcrun llvm-profdata merge -sparse "${PROFDATAS[@]}" -o "$MERGED"

# Build an -object list. Use the binary stashed alongside each profdata when it
# exists (function hashes match perfectly). Fall back to the live $BIN otherwise.
OBJECTS=()
for p in "${PROFDATAS[@]}"; do
    paired="${p%.profdata}.binary"
    if [[ -f "$paired" ]]; then
        OBJECTS+=("$paired")
    fi
done
# Always include the live binary too; it may carry coverage maps the older
# stashed binaries don't (e.g. files added since).
OBJECTS+=("$BIN")

# llvm-cov takes one binary as positional, the rest as -object=. Deduplicate.
declare -a UNIQ_OBJECTS=()
seen=""
for o in "${OBJECTS[@]}"; do
    case ":$seen:" in
        *":$o:"*) continue ;;
    esac
    UNIQ_OBJECTS+=("$o")
    seen="$seen:$o"
done

PRIMARY_BIN="${UNIQ_OBJECTS[0]}"
OBJECT_ARGS=()
for ((i=1; i<${#UNIQ_OBJECTS[@]}; i++)); do
    OBJECT_ARGS+=( "-object=${UNIQ_OBJECTS[$i]}" )
done

IGNORE_ARGS=()
for s in "${EXCLUDE_SUBSTRINGS[@]}"; do
    # Escape regex metacharacters except '.' (we want '.' to match literally enough).
    esc=$(printf '%s' "$s" | sed 's/[][().+*?^$|\\]/\\&/g')
    IGNORE_ARGS+=( "--ignore-filename-regex=.*${esc}.*" )
done

echo
echo "=== Coverage summary (${#UNIQ_OBJECTS[@]} binary/binaries, ${#PROFDATAS[@]} profdata) ==="
xcrun llvm-cov report \
    "-instr-profile=$MERGED" \
    "${IGNORE_ARGS[@]}" \
    "${OBJECT_ARGS[@]}" \
    "$PRIMARY_BIN"

if [[ $WANT_HTML -eq 1 ]]; then
    OUT="$PROJECT_DIR/coverage-html"
    rm -rf "$OUT"
    echo
    echo "Rendering HTML to $OUT ..." >&2
    xcrun llvm-cov show \
        "-instr-profile=$MERGED" \
        "${IGNORE_ARGS[@]}" \
        "${OBJECT_ARGS[@]}" \
        --format=html \
        --output-dir="$OUT" \
        --show-line-counts-or-regions \
        "$PRIMARY_BIN"
    echo "Open: $OUT/index.html"
    if [[ $WANT_OPEN -eq 1 ]]; then
        open "$OUT/index.html"
    fi
fi
