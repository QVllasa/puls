#!/bin/zsh
# Übersetzt das Liquid-Glass-Symbol (Resources/AppIcon.icon, Icon-Composer-Format) nach
# Resources/compiled/{Assets.car,AppIcon.icns}. Braucht Xcode – lokal oder auf XCODE_HOST per SSH.
set -euo pipefail
cd "$(dirname "$0")/.."
ARGS=(--compile out --platform macosx --minimum-deployment-target 26.0 --app-icon AppIcon
      --output-partial-info-plist out/partial.plist --errors --warnings)
if xcode-select -p 2>/dev/null | grep -q Xcode.app; then
    rm -rf /tmp/pulsicon && mkdir -p /tmp/pulsicon/out && cp -R Resources/AppIcon.icon /tmp/pulsicon/
    (cd /tmp/pulsicon && xcrun actool AppIcon.icon "${ARGS[@]}")
    cp /tmp/pulsicon/out/Assets.car /tmp/pulsicon/out/AppIcon.icns Resources/compiled/
else
    HOST="${XCODE_HOST:-qendrimvllasa@100.117.69.64}"
    ssh "$HOST" 'rm -rf /tmp/pulsicon && mkdir -p /tmp/pulsicon/out'
    scp -q -r Resources/AppIcon.icon "$HOST:/tmp/pulsicon/"
    ssh "$HOST" "cd /tmp/pulsicon && xcrun actool AppIcon.icon ${ARGS[*]}"
    scp -q "$HOST:/tmp/pulsicon/out/Assets.car" "$HOST:/tmp/pulsicon/out/AppIcon.icns" Resources/compiled/
fi
cp Resources/compiled/AppIcon.icns Resources/AppIcon.icns
echo "✓ Symbol übersetzt"
