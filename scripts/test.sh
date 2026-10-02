#!/bin/zsh
# Regenerate the Xcode project and run unit tests with local ad-hoc signing.
set -e
cd "${0:A:h}/.."
xcodegen generate -q
xcodebuild -project Zappie.xcodeproj -scheme Zappie -destination 'platform=macOS' \
  -derivedDataPath build CODE_SIGN_IDENTITY="-" DEVELOPMENT_TEAM="" test 2>&1 \
  | grep -E "error:|✘|✔ Test run|Test run with|\*\* TEST" || true
