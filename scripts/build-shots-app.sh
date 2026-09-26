#!/bin/zsh
# Baut eine Store-Variante mit Screenshot-Modus als App-Paket (eigene Bundle-ID, damit Einstellungen getrennt bleiben).
set -euo pipefail
cd "$(dirname "$0")/.."
# Aufruf: scripts/build-shots-app.sh [store|github]
FLAVOR="${1:-store}"
if [[ "$FLAVOR" == store ]]; then
    swift build -c release --build-path .build-shots -Xswiftc -DAPPSTORE -Xswiftc -DSNAPSHOTS -Xcc -DAPPSTORE >/dev/null
    BIN=.build-shots/release/Puls; ID=com.vllasa.puls.shots; APP=dist-shots/PulsShots.app
else
    swift build -c release >/dev/null
    BIN=.build/release/Puls; ID=io.github.qvllasa.puls.shots; APP=dist-shots/PulsShotsGitHub.app
fi
rm -rf "$APP" && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Puls"
sed -e "s/__VERSION__/$(cat VERSION)/" -e "s/__BUILD__/1/" -e "s/io.github.qvllasa.puls/$ID/" Resources/Info.plist > "$APP/Contents/Info.plist"
cp Resources/compiled/AppIcon.icns Resources/compiled/Assets.car "$APP/Contents/Resources/"
cp -R Resources/en.lproj Resources/de.lproj "$APP/Contents/Resources/"
codesign -f -s - "$APP" 2>/dev/null
echo "$APP"
