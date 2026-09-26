#!/bin/zsh
# Legt das öffentliche GitHub-Repository an (falls nötig), pusht und erstellt das Release mit der App.
# Voraussetzung: `gh auth login` ist erledigt. Aufruf: scripts/publish.sh
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="QVllasa/puls"
VERSION="$(cat VERSION)"
TAG="v$VERSION"

gh auth status >/dev/null

if ! gh repo view "$REPO" >/dev/null 2>&1; then
    echo "▸ Lege $REPO an …"
    gh repo create "$REPO" --public \
        --description "Schlanker Systemmonitor für die macOS-Menüleiste im Liquid-Glass-Design – CPU, GPU, Speicher, Netzwerk, Sensoren, Akku." \
        --homepage "https://github.com/$REPO/releases/latest"
    gh repo edit "$REPO" --add-topic macos --add-topic menubar --add-topic system-monitor \
        --add-topic swiftui --add-topic liquid-glass --add-topic istat-menus-alternative
fi

git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/$REPO.git"
gh auth setup-git
git push -u origin main

[[ -f "dist/Puls-$VERSION.zip" ]] || scripts/build-app.sh "$VERSION"

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    echo "▸ Release $TAG existiert – ersetze Dateien …"
    gh release upload "$TAG" "dist/Puls-$VERSION.zip" "dist/Puls-$VERSION.zip.sha256" --repo "$REPO" --clobber
else
    echo "▸ Erstelle Release $TAG …"
    gh release create "$TAG" "dist/Puls-$VERSION.zip" "dist/Puls-$VERSION.zip.sha256" \
        --repo "$REPO" --title "Puls $VERSION" --notes-file "releases/$VERSION.md"
fi
echo "✓ https://github.com/$REPO"
