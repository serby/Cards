#!/bin/bash
# Selects the Xcode named in .xcode-version, so local builds and CI build with
# the same version. Source it; do not run it. It sets DEVELOPER_DIR.
#
#   XCODE_APP set  -> that Xcode, which must be the pinned version
#   otherwise      -> /Applications/Xcode<version>.app, or Xcode_<version>.app
#                     as on GitHub's runners, or Xcode-<version>.app
#
# It fails, rather than falling back to another Xcode, when the pinned version
# is not installed or XCODE_APP is a different version.
XCODE_ENV_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCODE_VERSION="$(tr -d '[:space:]' < "$XCODE_ENV_ROOT/.xcode-version")"
if [[ -z "${XCODE_APP:-}" ]]; then
    for candidate in "/Applications/Xcode${XCODE_VERSION}.app" "/Applications/Xcode_${XCODE_VERSION}.app" "/Applications/Xcode-${XCODE_VERSION}.app"; do
        if [[ -d "$candidate" ]]; then
            XCODE_APP="$candidate"
            break
        fi
    done
fi
if [[ -z "${XCODE_APP:-}" ]]; then
    echo "error: Xcode $XCODE_VERSION, from .xcode-version, is not installed in /Applications. Install it, or set XCODE_APP to it." >&2
    return 1 2>/dev/null || exit 1
fi
if [[ ! -x "$XCODE_APP/Contents/Developer/usr/bin/xcodebuild" ]]; then
    echo "error: XCODE_APP is $XCODE_APP, which is not an Xcode." >&2
    return 1 2>/dev/null || exit 1
fi
XCODE_ACTUAL="$("$XCODE_APP/Contents/Developer/usr/bin/xcodebuild" -version | awk 'NR == 1 { print $2 }')"
if [[ "$XCODE_ACTUAL" != "$XCODE_VERSION" ]]; then
    echo "error: $XCODE_APP is Xcode $XCODE_ACTUAL, but .xcode-version says $XCODE_VERSION." >&2
    return 1 2>/dev/null || exit 1
fi
export DEVELOPER_DIR="$XCODE_APP/Contents/Developer"
