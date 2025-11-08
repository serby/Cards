#!/bin/bash
SWIFT_LINT=/opt/homebrew/bin/swiftlint
if $SWIFT_LINT > /dev/null; then
  $SWIFT_LINT
else
  echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi
