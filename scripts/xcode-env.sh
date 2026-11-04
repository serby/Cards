#!/bin/bash
# Picks the Xcode the scripts build with. Source it; do not run it.
#
#   XCODE_APP set              -> that Xcode
#   Xcode 27.1 installed       -> /Applications/Xcode27.1.app (the local default)
#   neither                    -> whatever xcode-select points at, as on CI runners
if [[ -n "${XCODE_APP:-}" ]]; then
    export DEVELOPER_DIR="$XCODE_APP/Contents/Developer"
elif [[ -d /Applications/Xcode27.1.app ]]; then
    export DEVELOPER_DIR="/Applications/Xcode27.1.app/Contents/Developer"
fi
