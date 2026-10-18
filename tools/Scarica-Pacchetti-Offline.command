#!/bin/zsh
# =============================================================================
# tools/Scarica-Pacchetti-Offline.command (macOS)
# Scarica i pacchetti Mac principali (.dmg / .pkg) sulla chiavetta USB
# (cartella 'installers/mac') per installazioni successive 100% offline.
# =============================================================================
cd "${0:a:h}" || exit 1

printf '\e]2;PC Facile Mac - Download Pacchetti Offline\a' 2>/dev/null || true
echo ""
echo "============================================================"
echo "  PC FACILE MAC - DOWNLOAD PACCHETTI OFFLINE"
echo "  Unieuro | Kit Autonomo da Banco"
echo "============================================================"
echo ""

xattr -d com.apple.quarantine "$0" 2>/dev/null || true
xattr -cr .. 2>/dev/null || true

zsh "${0:a:h}/../setup-mac.sh" --prepara-usb "$@"

echo ""
echo "============================================================"
echo "  Operazione completata. Premi INVIO per chiudere."
echo "============================================================"
read -r _
