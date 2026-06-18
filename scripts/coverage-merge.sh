#!/bin/bash
# Merge an explicit list of .profdata files and emit a coverage report.
#
# Usage:
#   scripts/coverage-merge.sh [--html] [--open] -- profdata1 [profdata2 ...]
#
# Each argument can be:
#   - a path to a .profdata file
#   - a path to an .xcresult bundle (we'll skip; bundle profdata isn't extractable
#     from modern Xcode bundles — use scripts/coverage-stash.sh between test runs
#     and then scripts/coverage-report.sh to merge stashed files)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

EXCLUDE_SUBSTRINGS=(
    "/CardsTests/"
    "/CardsUITests/"
    "/external/swiftpkg_"
    "/external/rules_swift_package_manager"
    ".generated.swift"
)

usage() {
    cat <<EOF
Usage: $(basename "$0") [--html] [--open] -- profdata1 [profdata2 ...]

  --html    Render HTML report at coverage-html/index.html
  --open    Open the HTML report when done (implies --html)

Pass one or more .profdata file paths after '--'.

Excluded path patterns (edit EXCLUDE_SUBSTRINGS in the script to change):
$(printf '  - %s\n' "${EXCLUDE_SUBSTRINGS[@]}")
EOF
}

WANT_HTML=0
WANT_OPEN=0
INPUTS=()
saw_dashdash=0
for arg in "$@"; do
    if [[ $saw_dashdash -eq 1 ]]; then
        INPUTS+=("$arg")
        continue
    fi
    case "$arg" in
        -h|--help) usage; exit 0 ;;
        --html) WANT_HTML=1 ;;
        --open) WANT_HTML=1; WANT_OPEN=1 ;;
        --) saw_dashdash=1 ;;
        *) INPUTS+=("$arg") ;;
    esac
done

if [[ ${#INPUTS[@]} -lt 1 ]]; then
    echo "error: pass at least one .profdata file" >&2
    usage >&2
    exit 2
fi

PROFDATAS=()
for p in "${INPUTS[@]}"; do
    if [[ "$p" == *.xcresult ]]; then
        echo "warning: skipping xcresult bundle (cannot extract profdata): $p" >&2
        continue
    fi
    if [[ ! -f "$p" ]]; then
        echo "error: not a file: $p" >&2
        exit 1
    fi
    if ! xcrun llvm-profdata show "$p" >/dev/null 2>&1; then
        echo "error: not a valid profdata file: $p" >&2
        exit 1
    fi
    PROFDATAS+=("$p")
done

if [[ ${#PROFDATAS[@]} -eq 0 ]]; then
    echo "error: no usable .profdata files supplied" >&2
    exit 1
fi

# Find a binary that matches.
DD=$(ls -td "$HOME"/Library/Developer/Xcode/DerivedData/Cards-* 2>/dev/null | head -n 1)
BIN=""
if [[ -n "$DD" ]]; then
    BIN=$(find "$DD/Build/Products" -path '*Cards.app/Cards' -type f 2>/dev/null | head -n 1)
fi
if [[ -z "$BIN" ]]; then
    BIN=$(find "$PROJECT_DIR/bazel-bin" -path '*Cards.app/Cards' -type f 2>/dev/null | head -n 1)
fi
if [[ -z "$BIN" ]]; then
    echo "error: no Cards binary in DerivedData or bazel-bin" >&2
    exit 1
fi

WORK="$(mktemp -d -t cards-cov)"
trap 'rm -rf "$WORK"' EXIT

MERGED="$WORK/merged.profdata"
echo "Merging ${#PROFDATAS[@]} profdata file(s) ..." >&2
xcrun llvm-profdata merge -sparse "${PROFDATAS[@]}" -o "$MERGED"

IGNORE_ARGS=()
for s in "${EXCLUDE_SUBSTRINGS[@]}"; do
    esc=$(printf '%s' "$s" | sed 's/[][().+*?^$|\\]/\\&/g')
    IGNORE_ARGS+=( "--ignore-filename-regex=.*${esc}.*" )
done

echo
echo "=== Coverage summary ==="
xcrun llvm-cov report \
    "-instr-profile=$MERGED" \
    "${IGNORE_ARGS[@]}" \
    "$BIN"

if [[ $WANT_HTML -eq 1 ]]; then
    OUT="$PROJECT_DIR/coverage-html"
    rm -rf "$OUT"
    echo
    echo "Rendering HTML to $OUT ..." >&2
    xcrun llvm-cov show \
        "-instr-profile=$MERGED" \
        "${IGNORE_ARGS[@]}" \
        --format=html \
        --output-dir="$OUT" \
        --show-line-counts-or-regions \
        "$BIN"
    echo "Open: $OUT/index.html"
    if [[ $WANT_OPEN -eq 1 ]]; then
        open "$OUT/index.html"
    fi
fi
