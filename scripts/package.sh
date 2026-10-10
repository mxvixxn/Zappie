#!/bin/zsh
# Build a Release Zappie for sharing and zip it to build.noindex/release/Zappie-<version>.zip.
# Debug symbols are stripped (DEPLOYMENT_POSTPROCESSING) so no local build paths ship.
# Signed ad-hoc on purpose: the Apple Development certificate carries the owner's name and email,
# and without notarization Gatekeeper treats both the same ("그래도 열기" is needed either way).
set -e
cd "${0:A:h}/.."
xcodegen generate -q
xcodebuild -project Zappie.xcodeproj -scheme Zappie -configuration Release -destination 'platform=macOS' \
  -derivedDataPath build.noindex CODE_SIGN_IDENTITY="-" DEVELOPMENT_TEAM="" \
  DEPLOYMENT_POSTPROCESSING=YES build | grep -E "error:|\*\* BUILD"
APP=build.noindex/Build/Products/Release/Zappie.app
codesign --force --deep --options runtime --timestamp=none --sign - "$APP"
codesign --verify --deep --strict "$APP"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
OUT=build.noindex/release/Zappie-$VERSION.zip
mkdir -p build.noindex/release
rm -f "$OUT"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT"
shasum -a 256 "$OUT"
