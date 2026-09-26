#!/bin/zsh
# Baut Puls.app (Universal: Apple Silicon + Intel), signiert mit Developer ID, lässt es von Apple
# notarisieren (falls Zertifikat und API-Schlüssel vorhanden, sonst ad hoc) und packt ein ZIP.
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

KEYCHAIN="$HOME/.appstore-puls/puls-signing.keychain-db"
DEVID="Developer ID Application: Vllasa Ventures UG (haftungsbeschraenkt) (QU9LB387VU)"
if [[ -f "$KEYCHAIN" ]] && security find-identity -v -p codesigning "$KEYCHAIN" | grep -q "Developer ID Application"; then
    echo "▸ Signiere mit Developer ID (gehärtete Laufzeit) …"
    security unlock-keychain -p "$(cat "$HOME/.appstore-puls/keychain.pw")" "$KEYCHAIN"
    codesign --force --options runtime --timestamp --keychain "$KEYCHAIN" --sign "$DEVID" "$APP"
    codesign --verify --strict --deep "$APP"

    if [[ -f "$HOME/.appstore-puls/env.sh" ]]; then
        source "$HOME/.appstore-puls/env.sh"
        echo "▸ Notarisierung bei Apple …"
        ditto -c -k --keepParent "$APP" "dist/notarize.zip"
        xcrun notarytool submit "dist/notarize.zip" --key "${ASC_KEY_FILE/#\~/$HOME}" \
            --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID" --wait --timeout 30m | tail -3
        rm -f "dist/notarize.zip"
        xcrun stapler staple "$APP"
        spctl --assess --type execute --verbose=2 "$APP"
    fi
else
    echo "▸ Signiere (ad hoc, keine Developer ID gefunden) …"
    codesign --force --sign - --timestamp=none "$APP"
    codesign --verify --strict "$APP"
fi

echo "▸ Packe ZIP …"
ditto -c -k --sequesterRsrc --keepParent "$APP" "dist/Puls-$VERSION.zip"
shasum -a 256 "dist/Puls-$VERSION.zip" | tee "dist/Puls-$VERSION.zip.sha256"
lipo -archs "$APP/Contents/MacOS/Puls"
echo "✓ Fertig: $APP"
