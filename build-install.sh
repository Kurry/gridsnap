#!/bin/bash
set -e

CERT="-"  # ad-hoc signing for local dev; CI uses Developer ID Application
PROJECT="GridSnap.xcodeproj"
SCHEME="GridSnap"
BUILD_DIR="/tmp/GridSnap-build"
APP="$BUILD_DIR/Build/Products/Release/GridSnap.app"

echo "Building..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "error:|warning:|BUILD SUCCEEDED|BUILD FAILED" | grep -v appintentsmetadataprocessor

echo "Signing..."
codesign --force --deep -s "$CERT" "$APP"

echo "Installing..."
pkill -x GridSnap 2>/dev/null || true
cp -R "$APP" /Applications/GridSnap.app

echo "Launching..."
open /Applications/GridSnap.app
echo "Done."
