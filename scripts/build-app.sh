#!/bin/zsh
# Baut Puls.app (Universal: Apple Silicon + Intel), signiert ad hoc und packt ein ZIP.
# Aufruf: scripts/build-app.sh [version]
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-$(cat VERSION)}"
BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
APP="dist/Puls.app"

echo "▸ Kompiliere Puls $VERSION (Build $BUILD) …"
for arch in arm64 x86_64; do
    swift build -c release --arch "$arch" -Xswiftc -Osize >/dev/null
done

echo "▸ Setze App-Paket zusammen …"
rm -rf dist && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create -output "$APP/Contents/MacOS/Puls" \
    .build/arm64-apple-macosx/release/Puls \
    .build/x86_64-apple-macosx/release/Puls
strip -x "$APP/Contents/MacOS/Puls"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Resources/Info.plist > "$APP/Contents/Info.plist"
cp Resources/compiled/AppIcon.icns Resources/compiled/Assets.car "$APP/Contents/Resources/"
cp -R Resources/en.lproj Resources/de.lproj "$APP/Contents/Resources/"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "▸ Signiere (ad hoc) …"
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --strict "$APP"

echo "▸ Packe ZIP …"
ditto -c -k --sequesterRsrc --keepParent "$APP" "dist/Puls-$VERSION.zip"
shasum -a 256 "dist/Puls-$VERSION.zip" | tee "dist/Puls-$VERSION.zip.sha256"
lipo -archs "$APP/Contents/MacOS/Puls"
echo "✓ Fertig: $APP"
