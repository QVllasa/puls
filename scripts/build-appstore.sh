#!/bin/zsh
# Baut die Mac-App-Store-Version (Sandbox, ohne private Schnittstellen), signiert sie und erstellt das .pkg.
# Voraussetzungen: Zertifikate „Apple Distribution“ und „3rd Party Mac Developer Installer“ im Schlüsselbund,
# Bereitstellungsprofil unter appstore/Puls_Mac_App_Store.provisionprofile.
# Aufruf: scripts/build-appstore.sh [version]
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM="QU9LB387VU"
BUNDLE_ID="com.vllasa.puls"
APP_IDENTITY="${APP_IDENTITY:-Apple Distribution: Vllasa Ventures UG (haftungsbeschraenkt) ($TEAM)}"
PKG_IDENTITY="${PKG_IDENTITY:-3rd Party Mac Developer Installer: Vllasa Ventures UG (haftungsbeschraenkt) ($TEAM)}"
PROFILE="appstore/Puls_Mac_App_Store.provisionprofile"
VERSION="${1:-$(cat VERSION)}"
BUILD="$(git rev-list --count HEAD)"
OUT="dist-store"
APP="$OUT/Puls.app"

echo "▸ Kompiliere Store-Version $VERSION (Build $BUILD) …"
for arch in arm64 x86_64; do
    swift build -c release --arch "$arch" --build-path .build-store \
        -Xswiftc -DAPPSTORE -Xcc -DAPPSTORE -Xswiftc -Osize >/dev/null
done

echo "▸ Setze App-Paket zusammen …"
rm -rf "$OUT" && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create -output "$APP/Contents/MacOS/Puls" \
    .build-store/arm64-apple-macosx/release/Puls .build-store/x86_64-apple-macosx/release/Puls
strip -x "$APP/Contents/MacOS/Puls"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" -e "s/io.github.qvllasa.puls/$BUNDLE_ID/" \
    -e "s/© 2026 Qendrim Vllasa · MIT-Lizenz/© 2026 Vllasa Ventures UG (haftungsbeschränkt)/" \
    Resources/Info.plist > "$APP/Contents/Info.plist"
plutil -insert ITSAppUsesNonExemptEncryption -bool NO "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
printf 'APPL????' > "$APP/Contents/PkgInfo"
cp "$PROFILE" "$APP/Contents/embedded.provisionprofile"

echo "▸ Prüfe auf private Schnittstellen …"
if nm -u "$APP/Contents/MacOS/Puls" | grep -E "IOHIDEvent|IOHIDService|IOServiceOpen|IOConnectCall|CGWindowListCreateImage"; then
    echo "✗ Private oder gesperrte Symbole gefunden – Abbruch"; exit 1
fi

echo "▸ Signiere …"
codesign --force --sign "$APP_IDENTITY" --entitlements appstore/Puls.entitlements --timestamp=none "$APP"
codesign --verify --strict --deep "$APP"
codesign -d --entitlements - "$APP" 2>/dev/null | grep -q "app-sandbox" || { echo "✗ Sandbox fehlt"; exit 1; }

echo "▸ Erstelle Installationspaket …"
productbuild --component "$APP" /Applications --sign "$PKG_IDENTITY" "$OUT/Puls-$VERSION.pkg"
pkgutil --check-signature "$OUT/Puls-$VERSION.pkg" | head -3
echo "✓ $OUT/Puls-$VERSION.pkg"
