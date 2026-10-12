#!/bin/bash
# Builds Tinto and packages it as a drag-to-install .dmg in dist/
# Compila Tinto y lo empaqueta como .dmg en dist/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${VERSION:-$(cat VERSION)}"
VERSION="${VERSION#v}"
export VERSION

bash scripts/build.sh

STAGING="build/dmg"
DMG="dist/Tinto-$VERSION.dmg"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING" dist

cp -R build/Tinto.app "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "Tinto $VERSION" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGING"

echo "📦 $DMG"
