#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="KFinder"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
OUT_DIR="$ROOT_DIR/release"

cd "$ROOT_DIR"

"$ROOT_DIR/scripts/build-app.sh"

codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")"
ARCHS="$(lipo -archs "$APP_DIR/Contents/MacOS/$APP_NAME" | tr ' ' '-')"
ZIP_NAME="$APP_NAME-$VERSION-macOS-$ARCHS.zip"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$OUT_DIR/$ZIP_NAME"
(cd "$OUT_DIR" && shasum -a 256 "$ZIP_NAME" > "$ZIP_NAME.sha256")

echo "Built release artifacts:"
echo "  $OUT_DIR/$ZIP_NAME"
echo "  $OUT_DIR/$ZIP_NAME.sha256"
echo
echo "Gatekeeper note:"
spctl --assess --type execute --verbose=4 "$APP_DIR" 2>&1 || true
