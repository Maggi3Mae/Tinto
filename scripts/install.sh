#!/bin/bash
# Builds Tinto from source and installs it in /Applications.
# Compila Tinto desde el código y lo instala en /Aplicaciones.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="/Applications/Tinto.app"

bash "$ROOT/scripts/build.sh"

pkill -x Tinto 2>/dev/null || true
rm -rf "$DEST"
cp -R "$ROOT/build/Tinto.app" "$DEST"

echo "✅ Installed / Instalado: $DEST"
open "$DEST"
