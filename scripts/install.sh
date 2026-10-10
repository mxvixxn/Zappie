#!/bin/zsh
# Build a Release Zappie, sign it with this Mac's Apple Development certificate (or ad-hoc if
# none), and install it to /Applications, replacing the running copy.
set -e
cd "${0:A:h}/.."
xcodegen generate -q
xcodebuild -project Zappie.xcodeproj -scheme Zappie -configuration Release -destination 'platform=macOS' \
  -derivedDataPath build CODE_SIGN_IDENTITY="-" DEVELOPMENT_TEAM="" build | grep -E "error:|\*\* BUILD"
APP=build/Build/Products/Release/Zappie.app
IDENTITY=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ {print $2; exit}')
codesign --force --deep --options runtime --timestamp=none --sign "${IDENTITY:--}" "$APP"
codesign --verify --deep --strict "$APP"
pkill -x Zappie || true
sleep 1
rm -rf /Applications/Zappie.app
ditto "$APP" /Applications/Zappie.app
open /Applications/Zappie.app
echo "Installed /Applications/Zappie.app (signed: ${IDENTITY:-ad-hoc})"
