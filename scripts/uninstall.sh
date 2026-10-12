#!/bin/bash
# Removes Tinto and restores normal sleep. (Also available in the app menu: "Uninstall Tinto…")
# Elimina Tinto y restaura el reposo normal. (También desde el menú: "Desinstalar Tinto…")
set -uo pipefail

DEST="/Applications/Tinto.app"

pkill -x Tinto 2>/dev/null || true
sleep 1

[ -x "$DEST/Contents/MacOS/Tinto" ] && "$DEST/Contents/MacOS/Tinto" --unregister-login

sudo /usr/bin/pmset -a disablesleep 0
sudo rm -f /etc/sudoers.d/tinto

rm -rf "$DEST"
defaults delete io.github.maggi3mae.tinto 2>/dev/null || true

echo "✅ Tinto removed, normal sleep restored. / Tinto eliminado, reposo normal restaurado."
