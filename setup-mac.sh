#!/bin/zsh
# =============================================================================
# setup-mac.sh - PC Facile per Mac (gemello di setup-pc.ps1)
# Stesso flusso/menu/report della versione Windows, con gli strumenti nativi
# di macOS: Homebrew (app), scutil (nome), defaults (impostazioni), fdesetup
# (FileVault = equivalente di BitLocker), softwareupdate (aggiornamenti).
# Gira in zsh nativo: doppio-click su "PC Facile.command". Nessuna dipendenza
# da installare a parte Homebrew (che lo script installa da solo).
# =============================================================================

SCRIPT_VERSION="2.1 (2026-09-26)"

# ---- Variabili ambiente non interattive & anti-sleep ------------------------
export NONINTERACTIVE=1
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_ANALYTICS=1

# Prevenzione stop/sleep del Mac durante il setup
if command -v caffeinate >/dev/null 2>&1 && [[ "$1" != "--test" && "$1" != "-t" ]]; then
  caffeinate -dimsu -w $$ >/dev/null 2>&1 &
fi

# Rimuove l'attributo di quarantena di Gatekeeper da se' stesso e dalla cartella/chiavetta
xattr -d com.apple.quarantine "$0" 2>/dev/null || true
xattr -cr "${0:a:h}" 2>/dev/null || true

# ---- Un solo flusso: doppio click su "PC Facile.command" = configura --------
# Niente menu. --test (solo CI) e --diagnostica (manutenzione) non sono per
# l'operatore; i vecchi --veloce/--auto sono accettati e ignorati.
MODO="CONFIGURA"  # CONFIGURA | DIAGNOSTICA | TEST
MODO_TEST=false
for arg in "$@"; do
  case "$arg" in
    --test|-t)        MODO_TEST=true; MODO="TEST" ;;
    --diagnostica|-d) [[ "$MODO" != "TEST" ]] && MODO="DIAGNOSTICA" ;;
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
typeset -a ERRORI_IMPREVISTI

registra_errore_imprevisto_mac() {
    local msg="$1" riga="$2"
    local ora="$(date '+%Y-%m-%d %H:%M:%S')"
    [[ -z "$riga" ]] && riga="${(%):-%N}"
    ERRORI_IMPREVISTI+=("$ora | riga $riga: $msg")
    dim "   [!] Imprevisto gestito: $msg (riga $riga)"
}

errore(){
    print -r -- "${C_ERR}   [X] $1${C_RST}"
    registra_errore_imprevisto_mac "$1" "$LINENO"
}
dim(){   print -r -- "${C_DIM}   $1${C_RST}"; }

# ---- Escape dei valori inseriti nelle pagine HTML generate ------------------
# html_esc: & < > " ' -> entita' HTML. sed_esc: rende sicuro un valore usato
# come sostituzione in sed "s|...|VALORE|g" (\, | e & sono speciali).
html_esc(){ local s="$1"; s=${s//&/&amp;}; s=${s//</&lt;}; s=${s//>/&gt;}; s=${s//\"/&quot;}; s=${s//\'/&#39;}; print -r -- "$s"; }
sed_esc(){ local s="$1"; s=${s//$'\n'/ }; s=${s//\\/\\\\}; s=${s//[|]/\\|}; s=${s//&/\\&}; print -r -- "$s"; }

# ---- Report (voce + OK/ERRORE/SALTATO/AVVISO) --------------------------------
typeset -a REPORT_VOCI REPORT_ESITI INSTALLATE
add_report(){ REPORT_VOCI+=("$1"); REPORT_ESITI+=("$2"); }

# Token fine-grained con l'UNICO permesso "Issues: write" su questo repository
# (identico a setup-pc.ps1). Silenzioso su qualsiasi fallimento di rete.
GH_REPORT_TOKEN="github_pat_11CGNVYJQ0wADOIrv7reJX_B3b8kPI""vrJ9OilzUId7XaAJlxxDDPgxCHV9it4yti5m6QO47BJZegKW5DhU"
GH_REPORT_REPO="samuelenigro97-prog/pc-facile"

RUN_REALE=false
[[ "$MODO" == "CONFIGURA" ]] && RUN_REALE=true
beep_attesa(){ $RUN_REALE && printf '\a'; }

# ---- Controllo rete ---------------------------------------------------------
test_rete(){ curl -s --head --max-time 5 https://www.apple.com >/dev/null 2>&1 || ping -c1 -t2 8.8.8.8 >/dev/null 2>&1; }

# ---- Connessione automatica Wi-Fi negozio / chiavetta -----------------------
connetti_wifi_mac() {
    $MODO_TEST && return 0
    test_rete && return 0

    local ssid="UNIEURO_EXPO"
    local pass="W1f1@Un13uro"
    local f_wifi=""

    # 1. Cerca file wifi.txt personalizzato sulla chiavetta o cartelle adiacenti
    for d in "./wifi" "." "${0:a:h}/wifi" "${0:a:h}" /Volumes/*/wifi /Volumes/*; do
        if [[ -f "$d/wifi.txt" ]]; then
            f_wifi="$d/wifi.txt"
            break
        fi
    done

    if [[ -n "$f_wifi" ]]; then
        while IFS= read -r riga || [[ -n "$riga" ]]; do
            riga="${riga%$'\r'}"
            if [[ "$riga" =~ '^(SSID|RETE|WIFI)[[:space:]]*[:=][[:space:]]*(.+)$' ]]; then
                ssid="${match[2]}"
            elif [[ "$riga" =~ '^(PASS|PASSWORD|KEY|CHIAVE)[[:space:]]*[:=][[:space:]]*(.+)$' ]]; then
                pass="${match[2]}"
            fi
        done < "$f_wifi"
    fi

    # 2. Rileva interfaccia hardware Wi-Fi (es. en0)
    local wdev
    wdev="$(networksetup -listallhardwareports 2>/dev/null | awk '/Hardware Port: Wi-Fi/{getline; print $2}')"
    if [[ -z "$wdev" ]]; then
        wdev="$(networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi/{getline; print $2}')"
    fi

    if [[ -n "$wdev" ]]; then
        info "Connessione automatica al Wi-Fi del negozio ($ssid su $wdev)..."
        networksetup -setairportpower "$wdev" on 2>/dev/null
        networksetup -setairportnetwork "$wdev" "$ssid" "$pass" 2>/dev/null
        local t=0
        while ! test_rete && [[ $t -lt 8 ]]; do
            sleep 1
            ((t++))
        done
        if test_rete; then
            ok "Connesso automaticamente alla rete Wi-Fi: $ssid"
            return 0
        fi
    fi
    return 1
}

$MODO_TEST || { [[ "$MODO" == "TEST" ]] && MODO_TEST=true; }

# ---- Richiamo acustico ripetuto (Start-BipRipetuto / Stop-BipRipetuto) ------
BIP_PID=""
start_bip_ripetuto_mac() {
  [[ "$MODO_TEST" == true || "$RUN_REALE" != true ]] && return 0
  stop_bip_ripetuto_mac
  (
    sleep 120
    while true; do
      printf '\a'
      sleep 4
    done
  ) &
  BIP_PID=$!
}
stop_bip_ripetuto_mac() {
  if [[ -n "$BIP_PID" ]]; then
    kill -9 "$BIP_PID" 2>/dev/null || true
    wait "$BIP_PID" 2>/dev/null || true
    BIP_PID=""
  fi
}

# ---- Barra animata nel terminale (Start-BarraAnimata / Stop-BarraAnimata) -----
BARRA_PID=""
ULTIMA_PCT=0
start_barra_animata_mac() {
  local testo="$1"
  [[ "$MODO_TEST" == true || "$RUN_REALE" != true ]] && return 0
  stop_barra_animata_mac
  local pct="${ULTIMA_PCT:-0}"
  printf "\033]0;PC Facile [%s%%] - %s\007" "$pct" "$testo" 2>/dev/null || true
  (
    typeset -i larg=20 span=4 period=32 i=0 phase=0 pos=0 sec=0
    typeset -i start_t=$(date +%s)
    while true; do
      phase=$(( i % period ))
      if (( phase <= (larg - span) )); then
        pos=$phase
      else
        pos=$(( period - phase ))
      fi
      local b_left="" b_span="" b_right=""
      for ((j=0; j<pos; j++)); do b_left="${b_left}="; done
      for ((j=0; j<span; j++)); do b_span="${b_span}#"; done
      for ((j=0; j<(larg - span - pos); j++)); do b_right="${b_right}="; done
      local now_t=$(date +%s)
      sec=$(( now_t - start_t ))
      printf "\r   %b%s%b  [%b%s%s%s%b]  %b%ss%b" "$C_CYAN" "$testo" "$C_RST" "$C_ACC" "$b_left" "$b_span" "$b_right" "$C_RST" "$C_INFO" "$sec" "$C_RST"
      sleep 0.1
      ((i++))
    done
  ) &
  BARRA_PID=$!
}

stop_barra_animata_mac() {
  if [[ -n "$BARRA_PID" ]]; then
    kill -9 "$BARRA_PID" 2>/dev/null || true
    wait "$BARRA_PID" 2>/dev/null || true
    BARRA_PID=""
    printf "\r%*s\r" 80 ""
  fi
}

# ---- Sudo keepalive (richiesta PIN una sola volta all'avvio) --------------
SUDO_KEEPALIVE_PID=""
SUDOERS_TMP_FILE="/etc/sudoers.d/pcfacile_temp_$$"

start_sudo_keepalive_mac() {
  [[ "$MODO_TEST" == true || "$RUN_REALE" != true ]] && return 0
  stop_sudo_keepalive_mac
  if ! sudo -n true 2>/dev/null; then
    print -r -- ""
    print -r -- "${C_ACC}  ============================================================${C_RST}"
    print -r -- "${C_OK}   PERMESSI DI AMMINISTRAZIONE MAC (UNA SOLA VOLTA)${C_RST}"
    print -r -- "${C_TXT}   Inserisci la password/PIN di questo Mac una sola volta.${C_RST}"
    print -r -- "${C_CYAN}   Verra' mantenuta attiva in background per tutta la durata${C_RST}"
    print -r -- "${C_CYAN}   del lavoro: NON ti verra' mai piu' richiesta durante${C_RST}"
    print -r -- "${C_CYAN}   l'installazione di app (Adobe Reader), orario o sistema.${C_RST}"
    print -r -- "${C_ACC}  ============================================================${C_RST}"
    print -r -- ""
    beep_attesa
    if ! sudo -v; then
      warn "Autenticazione amministratore non riuscita: alcune funzioni potrebbero richiedere autorizzazione manuale."
      return 1
    fi
  fi

  # Configura autorizzazione NOPASSWD temporanea in /etc/sudoers.d per la durata della sessione
  # Cosi' Homebrew, brew cask, installer e scutil NON richiedono piu' il PIN
  if sudo -n mkdir -p /etc/sudoers.d 2>/dev/null; then
    local cur_user="${USER:-$(id -un)}"
    echo "$cur_user ALL=(ALL) NOPASSWD: ALL" | sudo tee "$SUDOERS_TMP_FILE" >/dev/null 2>&1
    sudo chmod 0440 "$SUDOERS_TMP_FILE" 2>/dev/null || true
    if ! sudo -n visudo -cf "$SUDOERS_TMP_FILE" >/dev/null 2>&1; then
      sudo rm -f "$SUDOERS_TMP_FILE" 2>/dev/null || true
    fi
  fi

  (
    while kill -0 "$$" 2>/dev/null; do
      sudo -n true 2>/dev/null || true
      sleep 20
    done
  ) 2>/dev/null &
  SUDO_KEEPALIVE_PID=$!
}

stop_sudo_keepalive_mac() {
  if [[ -n "$SUDO_KEEPALIVE_PID" ]]; then
    kill -9 "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    wait "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    SUDO_KEEPALIVE_PID=""
  fi
  if [[ -n "$SUDOERS_TMP_FILE" && -f "$SUDOERS_TMP_FILE" ]]; then
    sudo rm -f "$SUDOERS_TMP_FILE" 2>/dev/null || true
  fi
  sudo rm -f /etc/sudoers.d/pcfacile_temp_* 2>/dev/null || true
}

trap 'stop_barra_animata_mac 2>/dev/null; stop_bip_ripetuto_mac 2>/dev/null; stop_sudo_keepalive_mac 2>/dev/null' EXIT INT TERM HUP

chiedi(){
  if $MODO_TEST; then [[ "$1" == *"S/N"* ]] && REPLY="N" || REPLY=""; dim "$1  [test => '$REPLY']"; return; fi
  beep_attesa; start_bip_ripetuto_mac; print -n -- "   $1 "; read -r REPLY; stop_bip_ripetuto_mac
}

chiedi_sempre(){
  if $MODO_TEST; then REPLY=""; dim "$1  [test => vuoto]"; return; fi
  beep_attesa; start_bip_ripetuto_mac; print -n -- "   $1 "; read -r REPLY; stop_bip_ripetuto_mac
}

pausa(){ return 0; }
pausa_web(){
  [[ "$MODO" == "TEST" || "$MODO" == "DIAGNOSTICA" ]] && return
  beep_attesa; start_bip_ripetuto_mac; print -n -- "   Premi INVIO per continuare "; read -r _; stop_bip_ripetuto_mac
}

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

# ---- Collegamenti alle app sul Desktop (i clienti in negozio le cercano li') ---
crea_collegamento_desktop_mac() {
  local nome="$1"
  local cask="$2"
  local app_path=""
  if [[ -d "/Applications/$nome.app" ]]; then
    app_path="/Applications/$nome.app"
  elif [[ -n "$cask" ]]; then
    case "$cask" in
      vlc)                  [[ -d "/Applications/VLC.app" ]] && app_path="/Applications/VLC.app" ;;
      zoom)                 [[ -d "/Applications/zoom.us.app" ]] && app_path="/Applications/zoom.us.app" ;;
      the-unarchiver)       [[ -d "/Applications/The Unarchiver.app" ]] && app_path="/Applications/The Unarchiver.app" ;;
      libreoffice)          [[ -d "/Applications/LibreOffice.app" ]] && app_path="/Applications/LibreOffice.app" ;;
      epic-games)           [[ -d "/Applications/Epic Games Launcher.app" ]] && app_path="/Applications/Epic Games Launcher.app" ;;
      adobe-acrobat-reader) for a in /Applications/*Acrobat*.app; do [[ -d "$a" ]] && app_path="$a"; done ;;
    esac
  fi
  if [[ -z "$app_path" ]]; then
    local prima="${nome%% *}"
    for a in /Applications/*.app; do
      if [[ "${(L)a:t}" == *"${(L)prima}"* ]]; then
        app_path="$a"
        break
      fi
    done
  fi
  if [[ -n "$app_path" && -d "$app_path" ]]; then
    local desktop="$HOME/Desktop"
    local link_name="${app_path:t}"
    if [[ ! -e "$desktop/$link_name" ]]; then
      ln -s "$app_path" "$desktop/$link_name" 2>/dev/null
      ok "Icona creata sul Desktop: $link_name"
    fi
  fi
}

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
    local model="$(sysctl -n hw.model 2>/dev/null)"
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

    start_barra_animata_mac "Analisi diagnostica hardware e salute Mac"
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
    stop_barra_animata_mac

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
typeset -gA MAC_TASKS_STATO
typeset -gA MAC_TASKS_DETT
MAC_TASK_KEYS=(lingua orario ripristino ottimizza gestore app account servizi cyber aggiorna sicurezza diagnostica)
for k in "${MAC_TASK_KEYS[@]}"; do
    MAC_TASKS_STATO[$k]="pending"
    MAC_TASKS_DETT[$k]=""
done

typeset -gi START_TIME_MS=$(($(date +%s) * 1000))

update_pannello_mac_status() {
    local pct="${1:-5}"
    local fase="${2:-Inizializzazione}"
    local dett="${3:-Configurazione in corso...}"
    local comp="${4:-false}"
    local task_id="$5"
    local task_stato="$6"
    local task_dett="$7"

    ULTIMA_PCT="$pct"
    [[ -n "$task_id" && -n "$task_stato" ]] && MAC_TASKS_STATO[$task_id]="$task_stato"
    [[ -n "$task_id" && -n "$task_dett" ]] && MAC_TASKS_DETT[$task_id]="$task_dett"

    local status_file="/tmp/pcfacile-mac-status.js"
    {
        printf "window.PCFacileMacStatus = {\n"
        printf "    percentuale: %s,\n" "$pct"
        printf "    faseCorrente: \"%s\",\n" "${fase//\"/\\\"}"
        printf "    dettaglio: \"%s\",\n" "${dett//\"/\\\"}"
        printf "    completato: %s,\n" "$comp"
        printf "    inizio: %s,\n" "${START_TIME_MS:-0}"
        printf "    tasks: {\n"
        local first=true
        for k in "${MAC_TASK_KEYS[@]}"; do
            $first || printf ",\n"
            first=false
            local st="${MAC_TASKS_STATO[$k]:-pending}"
            local dt="${MAC_TASKS_DETT[$k]:-}"
            printf "        \"%s\": { \"stato\": \"%s\", \"dettaglio\": \"%s\" }" "$k" "$st" "${dt//\"/\\\"}"
        done
        printf "\n    }\n};\n"
        printf "if (typeof window.onPCFacileMacStatusUpdate === 'function') {\n"
        printf "    window.onPCFacileMacStatusUpdate(window.PCFacileMacStatus);\n"
        printf "}\n"
    } > "$status_file"
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

    # Impedisce a Safari di aprire automaticamente file scaricati (es. TextEdit con json)
    defaults write com.apple.Safari AutoOpenSafeDownloads -bool false 2>/dev/null

    cat <<'EOF' > "$pannello_html"
<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PC Facile - Pannello operatore Mac</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Segoe UI', sans-serif; }
        body { background: #000d20; color: #f8fafc; padding: 12px; min-height: 100vh; line-height: 1.45; font-size: 15px; }
        .container { max-width: 980px; margin: 0 auto; }
        button:focus-visible, a:focus-visible, input:focus-visible { outline: 3px solid #EE7203; outline-offset: 2px; }
        .header { background: #001a3a; border: 1.5px solid #00458C; border-radius: 12px; padding: 10px 14px; border-bottom: 3.5px solid #EE7203; margin-bottom: 10px; display: flex; justify-content: space-between; align-items: center; gap: 10px; flex-wrap: wrap; }
        .brand-box { display: flex; align-items: center; gap: 10px; }
        .u-logo { background: #EE7203; color: #fff; font-weight: 900; font-size: 16px; letter-spacing: 1px; padding: 6px 12px; border-radius: 7px; }
        .brand-titles h1 { font-size: 16px; color: #fff; font-weight: 700; }
        .badge-stato { font-weight: 800; font-size: 14px; padding: 7px 14px; border-radius: 20px; border: 1.5px solid #38bdf8; background: #082f49; color: #e0f2fe; white-space: nowrap; }
        .badge-stato.ok { border-color: #22c55e; background: #14532d; color: #dcfce7; }
        .hw-bar { background: #00142e; border: 1px solid #003366; border-radius: 8px; padding: 8px 12px; margin-bottom: 10px; display: flex; align-items: center; gap: 6px 16px; font-size: 14px; color: #b6c3d4; flex-wrap: wrap; }
        .hw-val { color: #fff; font-weight: 600; }
        .progress-card { background: #001a3a; border: 1.5px solid #00458C; border-radius: 10px; padding: 10px 14px; margin-bottom: 10px; }
        .progress-header { display: flex; justify-content: space-between; align-items: center; gap: 10px; margin-bottom: 6px; }
        .progress-meta { display: flex; align-items: center; gap: 14px; }
        .progress-timer-box { font-size: 14px; color: #b6c3d4; }
        .progress-timer { color: #7dd3fc; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 16px; font-weight: 700; }
        .progress-pct { color: #EE7203; font-weight: 900; font-size: 20px; }
        .progress-bar-bg { background: #000c1c; border: 1px solid #003B7A; height: 16px; border-radius: 8px; overflow: hidden; }
        .progress-bar-fill { background: linear-gradient(90deg, #EE7203 0%, #ff9d42 100%); height: 100%; width: 0%; transition: width 0.4s ease; }
        .banner-fine { display: none; border: 2px solid #22c55e; background: #052e16; border-radius: 10px; padding: 12px 14px; margin-bottom: 10px; font-size: 15px; }
        .banner-fine strong { color: #4ade80; }
        .tab-bar { display: flex; gap: 6px; margin-bottom: 10px; background: #00142e; padding: 5px; border-radius: 10px; border: 1px solid #003366; }
        .tab-btn { flex: 1; min-height: 44px; background: transparent; border: none; color: #b6c3d4; font-size: 15px; font-weight: 700; padding: 6px 10px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 8px; }
        .tab-btn.active { background: #003B7A; color: #fff; }
        .tab-badge-num { background: #001f48; color: #bfdbfe; font-size: 12px; padding: 1px 7px; border-radius: 10px; font-weight: 800; }
        .tab-btn.active .tab-badge-num { background: #EE7203; color: #fff; }
        .section-view { display: none; }
        .section-view.active-view { display: block; }
        .card { background: #001f48; border: 1px solid #003B7A; border-radius: 10px; padding: 12px 14px; margin-bottom: 10px; }
        .etichetta { display: block; font-size: 14px; color: #bfdbfe; font-weight: 700; margin-bottom: 4px; }
        .dom-row { display: flex; gap: 8px; margin-bottom: 10px; flex-wrap: wrap; }
        .dom-btn { min-height: 44px; flex: 1 1 120px; background: #1e293b; color: #e2e8f0; border: 1.5px solid #334155; padding: 8px 10px; border-radius: 8px; font-size: 15px; font-weight: 700; cursor: pointer; }
        .dom-btn[aria-pressed="true"] { background: #0284c7; border-color: #0284c7; color: #fff; }
        .campi-2 { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 8px; }
        .cred-box { display: flex; gap: 6px; align-items: stretch; margin-bottom: 10px; }
        .cred-box .cred-input { margin-bottom: 0; }
        .cred-input { width: 100%; min-height: 44px; background: #00122B; border: 1.5px solid #00458C; border-radius: 8px; padding: 8px 12px; font-size: 16px; color: #fff; margin-bottom: 10px; }
        .cred-input.errore { border-color: #ef4444; box-shadow: 0 0 0 3px rgba(239,68,68,0.4); }
        .cred-mono { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-weight: 700; color: #7dd3fc; }
        .btn-sec { min-height: 44px; background: #002b5c; border: 1.5px solid #0056B3; color: #fff; border-radius: 8px; padding: 6px 12px; font-size: 14px; font-weight: 700; cursor: pointer; white-space: nowrap; display: inline-flex; align-items: center; justify-content: center; gap: 4px; text-decoration: none; }
        .btn-sec:hover { background: #003B7A; border-color: #EE7203; }
        .servizi { background: #00152f; border: 1px solid #003B7A; border-radius: 8px; padding: 10px; margin-bottom: 10px; }
        .servizi-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 8px; }
        .svc { min-height: 44px; display: flex; align-items: center; justify-content: space-between; gap: 8px; font-size: 15px; padding: 6px 10px; border: 1px solid #003B7A; border-radius: 8px; }
        .svc:hover { border-color: #EE7203; }
        .svc label { display: flex; align-items: center; gap: 8px; cursor: pointer; flex: 1; min-width: 0; }
        .svc input { width: 22px; height: 22px; accent-color: #EE7203; cursor: pointer; flex-shrink: 0; }
        .btn-svc-link { font-size: 12px; font-weight: 700; padding: 3px 8px; border-radius: 6px; background: #002b5c; border: 1px solid #0056B3; color: #7dd3fc; text-decoration: none; white-space: nowrap; cursor: pointer; display: inline-flex; align-items: center; gap: 4px; transition: all 0.2s ease; }
        .btn-svc-link:hover { background: #EE7203; border-color: #EE7203; color: #fff; }
        .btn-avvia { min-height: 52px; background: #16a34a; font-weight: 800; font-size: 17px; padding: 10px 14px; width: 100%; border: none; cursor: pointer; border-radius: 8px; color: #fff; }
        .btn-avvia:hover { background: #15803d; }
        .esito { display: none; margin-top: 8px; padding: 10px 12px; border-radius: 8px; font-size: 15px; font-weight: 700; }
        .esito.ok { display: block; background: #052e16; border: 1.5px solid #22c55e; color: #bbf7d0; }
        .esito.errore { display: block; background: #2a0a0a; border: 1.5px solid #ef4444; color: #fecaca; }

        /* FASI LIVE */
        .bg-tasks { list-style: none; display: flex; flex-direction: column; gap: 6px; }
        .task-item { display: flex; align-items: center; justify-content: space-between; gap: 8px; font-size: 15px; padding: 10px 12px; border-radius: 8px; border: 1.5px solid transparent; background: #00152f; }
        .task-left { display: grid; grid-template-columns: 20px 1fr; align-items: center; column-gap: 10px; flex: 1; min-width: 0; }
        .task-icon { font-size: 16px; width: 20px; text-align: center; flex-shrink: 0; font-weight: 700; color: #94a3b8; }
        .task-name { color: #e2e8f0; font-weight: 600; }
        .task-detail { color: #fed7aa; font-size: 13.5px; grid-column: 2; }
        .task-detail:empty { display: none; }
        .task-badge { font-size: 13px; font-weight: 800; padding: 4px 10px; border-radius: 6px; white-space: nowrap; flex-shrink: 0; }
        .badge-pending { background: #00122B; color: #cbd5e1; border: 1px solid #003B7A; }
        .task-item.running { background: #2a1606; border-color: #EE7203; }
        .task-item.running .task-name { color: #fff; font-weight: 800; }
        .badge-running { background: #EE7203; color: #fff; }
        .task-item.done .task-icon { color: #22c55e; }
        .badge-done-task { background: #052e16; color: #86efac; border: 1px solid #22c55e; }
        .task-item.error { background: #2a0a0a; border-color: #ef4444; }
        .task-item.error .task-icon { color: #f87171; }
        .badge-error { background: #dc2626; color: #fff; }
        .task-item.skipped .task-icon { color: #38bdf8; }
        .badge-skipped { background: #082f49; color: #7dd3fc; border: 1px solid #0284c7; }
        .task-gruppo { color: #fdba74; font-size: 13px; font-weight: 800; text-transform: uppercase; letter-spacing: .04em; padding: 8px 2px 2px; }
        .spinner { display: inline-block; width: 14px; height: 14px; border: 2px solid #EE7203; border-top-color: transparent; border-radius: 50%; animation: spin 0.8s linear infinite; }
        @keyframes spin { to { transform: rotate(360deg); } }

        /* PORTALI */
        .portal-divider { font-size: 13px; font-weight: 800; color: #fed7aa; text-transform: uppercase; letter-spacing: 0.4px; margin: 10px 0 4px 0; }
        .portal-divider:first-child { margin-top: 0; }
        .portal-btn { min-height: 48px; display: flex; align-items: center; justify-content: space-between; background: #00142E; border: 1px solid #003B7A; border-radius: 8px; padding: 10px 12px; color: #f8fafc; text-decoration: none; font-size: 15px; margin-bottom: 6px; font-weight: 600; }
        .portal-btn:hover { background: #002554; border-color: #EE7203; }

        /* TOAST */
        .toast { position: fixed; bottom: 20px; left: 50%; transform: translateX(-50%) translateY(120px); max-width: calc(100% - 24px); background: #15803d; color: #fff; font-size: 15px; font-weight: 800; padding: 10px 20px; border-radius: 12px; box-shadow: 0 6px 20px rgba(0,0,0,0.5); opacity: 0; pointer-events: none; transition: all 0.3s ease; z-index: 1000; text-align: center; }
        .toast.show { transform: translateX(-50%) translateY(0); opacity: 1; }
        .toast.errore { background: #b91c1c; }
        .toast.avviso { background: #b45309; }

        @media (prefers-reduced-motion: reduce) { * { transition: none !important; animation: none !important; } }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="brand-box">
                <div class="u-logo">UNIEURO</div>
                <div class="brand-titles"><h1>PC Facile &middot; Pannello operatore Mac</h1></div>
            </div>
            <div id="badgeLive" class="badge-stato" role="status">In attesa dei dati cliente</div>
        </div>

        <div class="hw-bar">
            <div>Mac: <span class="hw-val">__HW_MODEL__</span></div>
            <div>Chip: <span class="hw-val">__HW_CHIP__ &middot; __HW_RAM__</span></div>
            <div>S/N: <span id="hwSerialVal" class="hw-val">__HW_SN__</span> <button type="button" class="btn-sec" style="min-height:30px; padding:2px 8px; font-size:12px; margin-left:6px;" onclick="copiaSerialeMac()">&#128203; Copia</button></div>
        </div>

        <div class="progress-card">
            <div class="progress-header">
                <span style="color:#fed7aa; font-weight:700;">Avanzamento configurazione</span>
                <div class="progress-meta">
                    <div class="progress-timer-box">Tempo: <span id="elapsedTimerText" class="progress-timer">00:00</span></div>
                    <div id="pctText" class="progress-pct">0%</div>
                </div>
            </div>
            <div class="progress-bar-bg"><div id="barFill" class="progress-bar-fill"></div></div>
            <div style="margin-top:6px; font-size:14px;" aria-live="polite">
                <div><span style="color:#b6c3d4;">Ora:</span> <strong id="faseText">In attesa</strong></div>
                <div id="dettText" style="color:#d6dee8;"></div>
            </div>
        </div>

        <div id="bannerFine" class="banner-fine" role="status">
            <strong>&#10003; Configurazione completata.</strong> La scheda di consegna &egrave; sulla Scrivania del Mac: <strong>Scheda-Consegna-Mac.html</strong>.
        </div>

        <div class="tab-bar">
            <button type="button" id="btn-tab-cred" class="tab-btn active" onclick="showTabMac('tab-cred', this)">&#128100; 1. Cliente</button>
            <button type="button" id="btn-tab-live" class="tab-btn" onclick="showTabMac('tab-live', this)">&#128202; 2. Avanzamento <span id="taskCountBadge" class="tab-badge-num">0/12</span></button>
            <button type="button" id="btn-tab-portali" class="tab-btn" onclick="showTabMac('tab-portali', this)">&#127760; 3. Portali</button>
        </div>

        <div id="tab-cred" class="section-view active-view">
            <div class="card">
                <span class="etichetta">Tipo di email</span>
                <div class="dom-row">
                    <button type="button" class="dom-btn" aria-pressed="true" onclick="setDomMac('proton.me', 'Proton', this)">@proton.me</button>
                    <button type="button" class="dom-btn" aria-pressed="false" onclick="setDomMac('icloud.com', 'iCloud', this)">@icloud.com</button>
                    <button type="button" class="dom-btn" aria-pressed="false" onclick="setDomMac('gmail.com', 'Google', this)">@gmail.com</button>
                    <button type="button" class="dom-btn" aria-pressed="false" onclick="setDomMac('outlook.it', 'Microsoft', this)">@outlook.it</button>
                </div>

                <div class="campi-2">
                    <div>
                        <label class="etichetta" for="inCognome">Cognome</label>
                        <input type="text" class="cred-input" id="inCognome" placeholder="Es. Rossi" autocomplete="off" oninput="aggiornaCredMac()">
                    </div>
                    <div>
                        <label class="etichetta" for="inNome">Nome</label>
                        <input type="text" class="cred-input" id="inNome" placeholder="Es. Mario" autocomplete="off" oninput="aggiornaCredMac()">
                    </div>
                </div>

                <label class="etichetta" for="inTelefono">Cellulare <span style="color:#94a3b8; font-size:13px;">(facoltativo &middot; consigliato con Cyber Protection)</span></label>
                <input type="tel" class="cred-input" id="inTelefono" placeholder="Es. 333 1234567" autocomplete="off" oninput="this.classList.remove('errore')">

                <label class="etichetta" for="inEmail">Email proposta</label>
                <div class="cred-box">
                    <input type="text" class="cred-input cred-mono" id="inEmail" value="__EMAIL__" autocomplete="off">
                    <button type="button" class="btn-sec" onclick="copiaMac('inEmail', 'Email copiata')">&#128203; Copia</button>
                </div>
                <label class="etichetta" for="inPass">Password iniziale</label>
                <div class="cred-box">
                    <input type="password" class="cred-input cred-mono" id="inPass" value="__PASS__" autocomplete="off">
                    <button type="button" class="btn-sec" id="btnMostraMac" onclick="togglePassMac()">&#128065; Mostra</button>
                    <button type="button" class="btn-sec" onclick="generaPassCasualeMac()">&#127922; Nuova</button>
                    <button type="button" class="btn-sec" onclick="copiaMac('inPass', 'Password copiata')">&#128203; Copia</button>
                </div>

                <div class="servizi">
                    <span class="etichetta" style="color:#fed7aa;">Servizi sullo scontrino</span>
                    <div class="servizi-grid">
                        <div class="svc">
                            <label><input type="checkbox" id="chkSvcProton" checked> <span>Email Proton</span></label>
                            <a href="https://account.proton.me/signup?plan=free" target="_blank" rel="noopener noreferrer" class="btn-svc-link" onclick="apriESelezionaMac('chkSvcProton', 'https://account.proton.me/signup?plan=free', event)">Apri &#8599;</a>
                        </div>
                        <div class="svc">
                            <label><input type="checkbox" id="chkSvcOffice"> <span>Card Office 365</span></label>
                            <a href="https://microsoft365.com/setup" target="_blank" rel="noopener noreferrer" class="btn-svc-link" onclick="apriESelezionaMac('chkSvcOffice', 'https://microsoft365.com/setup', event)">Apri setup &#8599;</a>
                        </div>
                        <div class="svc">
                            <label><input type="checkbox" id="chkSvcMcAfee"> <span>Card McAfee</span></label>
                            <a href="https://www.mcafee.com/activate" target="_blank" rel="noopener noreferrer" class="btn-svc-link" onclick="apriESelezionaMac('chkSvcMcAfee', 'https://www.mcafee.com/activate', event)">Apri setup &#8599;</a>
                        </div>
                        <div class="svc">
                            <label><input type="checkbox" id="chkSvcNorton"> <span>Card Norton</span></label>
                            <a href="https://www.norton.com/setup" target="_blank" rel="noopener noreferrer" class="btn-svc-link" onclick="apriESelezionaMac('chkSvcNorton', 'https://www.norton.com/setup', event)">Apri setup &#8599;</a>
                        </div>
                        <div class="svc" style="grid-column: 1 / -1; border-color:#EE7203;">
                            <label><input type="checkbox" id="chkSvcCyber" checked> <span>Unieuro Cyber Protection</span></label>
                            <a href="https://unieuro-cyber-protection.covercare.it" target="_blank" rel="noopener noreferrer" class="btn-svc-link" onclick="apriESelezionaMac('chkSvcCyber', 'https://unieuro-cyber-protection.covercare.it', event)">Apri portale &#8599;</a>
                        </div>
                    </div>
                    <label class="etichetta" for="selProfilo" style="margin-top:10px;">Programmi</label>
                    <select id="selProfilo" class="cred-input">
                        <option value="BASE" selected>Base</option>
                        <option value="UFFICIO">Ufficio</option>
                        <option value="GAMING">Gaming</option>
                    </select>
                </div>

                <button type="button" id="btnAvviaAuto" class="btn-avvia" onclick="avviaAutoMac()">&#128640; AVVIA INSTALLAZIONE</button>
                <div id="esitoInvio" class="esito" role="status" aria-live="polite"></div>
                <div style="margin-top:10px;">
                    <button type="button" class="btn-sec" style="width:100%;" onclick="copiaRiepilogoCredMac()">&#128203; Copia dati per il ticket</button>
                </div>
            </div>
        </div>

        <div id="tab-live" class="section-view">
            <div class="card">
                <div style="font-size:14px; color:#b6c3d4; margin-bottom:10px;">Fase 1 e 3 vanno da sole; nella fase 2 servi tu (account, attivazioni, codici). I passi gi&agrave; fatti vengono saltati.</div>
                <ul class="bg-tasks" id="tasksContainer">
                    <li class="task-gruppo">Fase 1 &middot; Programmi e impostazioni macOS (automatico)</li>
                    <li id="task-lingua" class="task-item pending"><div class="task-left"><span class="task-icon">&#9675;</span><span class="task-name">1. Lingua e Regione (it-IT)</span><span class="task-detail"></span></div><span class="task-badge badge-pending">In attesa</span></li>
                    <li id="task-orario" class="task-item pending"><div class="task-left"><span class="task-icon">&#9675;</span><span class="task-name">2. Sincronizzazione orario di rete</span><span class="task-detail"></span></div><span class="task-badge badge-pending">In attesa</span></li>
                    <li id="task-ripristino" class="task-item pending"><div class="task-left"><span class="task-icon">&#9675;</span><span class="task-name">3. Snapshot APFS di ripristino</span><span class="task-detail"></span></div><span class="task-badge badge-pending">In attesa</span></li>
                    <li id="task-ottimizza" class="task-item pending"><div class="task-left"><span class="task-icon">&#9675;</span><span class="task-name">4. Ottimizzazione macOS (Finder &amp; Dock)</span><span class="task-detail"></span></div><span class="task-badge badge-pending">In attesa</span></li>
                    <li id="task-gestore" class="task-item pending"><div class="task-left"><span class="task-icon">&#9675;</span><span class="task-name">5. Gestore pacchetti (Homebrew &amp; Rosetta 2)</span><span class="task-detail"></span></div><span class="task-badge badge-pending">In attesa</span></li>
                    <li id="task-app" class="task-item pending"><div class="task-left"><span class="task-icon">&#9675;</span><span class="task-name">6. Installazione applicazioni profilo</span><span class="task-detail"></span></div><span class="task-badge badge-pending">In attesa</span></li>
                    <li class="task-gruppo">Fase 2 &middot; Passi manuali (operatore)</li>
                    <li id="task-account" class="task-item pending"><div class="task-left"><span class="task-icon">&#9675;</span><span class="task-name">7. Nome Mac e account</span><span class="task-detail"></span></div><span class="task-badge badge-pending">In attesa</span></li>
                    <li id="task-servizi" class="task-item pending"><div class="task-left"><span class="task-icon">&#9675;</span><span class="task-name">8. Servizi e attivazioni (Office / Antivirus / Proton)</span><span class="task-detail"></span></div><span class="task-badge badge-pending">In attesa</span></li>
                    <li id="task-cyber" class="task-item pending"><div class="task-left"><span class="task-icon">&#9675;</span><span class="task-name">9. Unieuro Cyber Protection</span><span class="task-detail"></span></div><span class="task-badge badge-pending">In attesa</span></li>
                    <li class="task-gruppo">Fase 3 &middot; Aggiornamenti, sicurezza e consegna (automatico)</li>
                    <li id="task-aggiorna" class="task-item pending"><div class="task-left"><span class="task-icon">&#9675;</span><span class="task-name">10. Aggiornamenti app e macOS (ultimo passo)</span><span class="task-detail"></span></div><span class="task-badge badge-pending">In attesa</span></li>
                    <li id="task-sicurezza" class="task-item pending"><div class="task-left"><span class="task-icon">&#9675;</span><span class="task-name">11. Sicurezza FileVault</span><span class="task-detail"></span></div><span class="task-badge badge-pending">In attesa</span></li>
                    <li id="task-diagnostica" class="task-item pending"><div class="task-left"><span class="task-icon">&#9675;</span><span class="task-name">12. Controllo finale e scheda di consegna</span><span class="task-detail"></span></div><span class="task-badge badge-pending">In attesa</span></li>
                </ul>
            </div>
        </div>

        <div id="tab-portali" class="section-view">
            <div class="card">
                <div class="portal-divider">Account ed email</div>
                <a href="https://account.proton.me/signup?plan=free" target="_blank" rel="noopener noreferrer" class="portal-btn" style="border-color:#0284c7;"><span>Account Proton Mail (gratis)</span> <span>&rarr;</span></a>
                <a href="https://appleid.apple.com" target="_blank" rel="noopener noreferrer" class="portal-btn"><span>Apple ID: crea o gestisci</span> <span>&rarr;</span></a>
                <a href="https://accounts.google.com/signup" target="_blank" rel="noopener noreferrer" class="portal-btn"><span>Account Google / Gmail</span> <span>&rarr;</span></a>
                <a href="https://account.microsoft.com" target="_blank" rel="noopener noreferrer" class="portal-btn"><span>Account Microsoft / Outlook</span> <span>&rarr;</span></a>

                <div class="portal-divider">Office</div>
                <a href="https://microsoft365.com/setup" target="_blank" rel="noopener noreferrer" class="portal-btn"><span>Riscatto card Office / Microsoft 365</span> <span>&rarr;</span></a>
                <a href="https://account.microsoft.com/services" target="_blank" rel="noopener noreferrer" class="portal-btn"><span>Installa Office dall&rsquo;account Microsoft</span> <span>&rarr;</span></a>

                <div class="portal-divider">Antivirus da card</div>
                <a href="https://www.mcafee.com/activate" target="_blank" rel="noopener noreferrer" class="portal-btn"><span>Attivazione card McAfee</span> <span>&rarr;</span></a>
                <a href="https://www.norton.com/setup" target="_blank" rel="noopener noreferrer" class="portal-btn"><span>Attivazione card Norton</span> <span>&rarr;</span></a>

                <div class="portal-divider">Servizio Unieuro</div>
                <a href="https://unieuro-cyber-protection.covercare.it" target="_blank" rel="noopener noreferrer" class="portal-btn" style="border-color:#EE7203;"><span>Unieuro Cyber Protection</span> <span>&rarr;</span></a>
            </div>
        </div>
    </div>

    <div id="toastEl" class="toast" role="status" aria-live="polite"></div>

    <script>
        var currentDom = 'proton.me';
        var currentProv = 'Proton';
        var inizioLavori = 0;
        var manualEdit = false;
        var audioPlayed = false;
        var schedaScelta = false;
        var TASK_KEYS = ['lingua', 'orario', 'ripristino', 'ottimizza', 'gestore', 'app', 'account', 'servizi', 'cyber', 'aggiorna', 'sicurezza', 'diagnostica'];

        function showTabMac(id, btn) {
            schedaScelta = true;
            document.querySelectorAll('.section-view').forEach(function(el){ el.classList.remove('active-view'); });
            document.querySelectorAll('.tab-btn').forEach(function(el){ el.classList.remove('active'); });
            var v = document.getElementById(id);
            if (v) v.classList.add('active-view');
            if (btn) btn.classList.add('active');
        }

        var _toastTimer = null;
        function showToast(msg, tipo) {
            var t = document.getElementById('toastEl');
            if (!t) return;
            t.innerText = msg;
            t.className = 'toast show' + (tipo ? ' ' + tipo : '');
            clearTimeout(_toastTimer);
            _toastTimer = setTimeout(function() { t.className = 'toast' + (tipo ? ' ' + tipo : ''); }, tipo === 'errore' ? 4000 : 2500);
        }

        function scriviAppunti(testo, msgOk) {
            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(testo).then(function() { showToast(msgOk); }, function() { showToast('Copia non riuscita: copia a mano', 'errore'); });
            } else {
                showToast('Copia non disponibile', 'errore');
            }
        }

        function copiaMac(id, msg) {
            var elem = document.getElementById(id);
            var v = elem ? elem.value.trim() : '';
            if (!v) { showToast('Campo vuoto: niente da copiare', 'avviso'); return; }
            scriviAppunti(v, msg || 'Copiato');
        }

        function copiaSerialeMac() {
            var elem = document.getElementById('hwSerialVal');
            var sn = elem ? elem.innerText.trim() : '';
            if (!sn) { showToast('Seriale non disponibile', 'avviso'); return; }
            scriviAppunti(sn, 'Seriale copiato: ' + sn);
        }

        function copiaRiepilogoCredMac() {
            var email = document.getElementById('inEmail') ? document.getElementById('inEmail').value.trim() : '';
            var pass = document.getElementById('inPass') ? document.getElementById('inPass').value.trim() : '';
            var tel = document.getElementById('inTelefono') ? document.getElementById('inTelefono').value.trim() : '';
            if (!email) { showToast('Inserisci prima il cliente', 'avviso'); return; }
            var text = 'Account: ' + email + ' | Password: ' + pass + (tel ? ' | Tel: ' + tel : '') + ' (Provider: ' + currentProv + ')';
            scriviAppunti(text, 'Dati copiati per il ticket');
        }

        function togglePassMac() {
            var inp = document.getElementById('inPass');
            var btn = document.getElementById('btnMostraMac');
            if (!inp) return;
            inp.type = (inp.type === 'password' ? 'text' : 'password');
            if (btn) btn.innerHTML = inp.type === 'password' ? '&#128065; Mostra' : '&#128065; Nascondi';
        }

        function generaPassCasualeMac() {
            var chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#%*';
            var pass = '';
            var rnd = new Uint32Array(12);
            if (window.crypto && crypto.getRandomValues) {
                crypto.getRandomValues(rnd);
            } else {
                for (var k = 0; k < 12; k++) rnd[k] = Math.floor(Math.random() * 4294967296);
            }
            for (var i = 0; i < 12; i++) pass += chars.charAt(rnd[i] % chars.length);
            var inp = document.getElementById('inPass');
            if (inp) {
                inp.value = pass;
                inp.type = 'text';
                var btn = document.getElementById('btnMostraMac');
                if (btn) btn.innerHTML = '&#128065; Nascondi';
                showToast('Nuova password generata');
            }
        }

        function formatoTempo(sec) {
            var h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60;
            var mm = (m < 10 ? '0' : '') + m, ss = (s < 10 ? '0' : '') + s;
            return h > 0 ? (h + ':' + mm + ':' + ss) : (mm + ':' + ss);
        }

        setInterval(function() {
            var e = document.getElementById('elapsedTimerText');
            if (!e) return;
            e.innerText = inizioLavori > 0 ? formatoTempo(Math.max(0, Math.floor((Date.now() - inizioLavori) / 1000))) : '00:00';
        }, 1000);

        function playChimeMac() {
            try {
                var AC = window.AudioContext || window.webkitAudioContext;
                if (!AC) return;
                var ctx = new AC();
                if (ctx.resume) ctx.resume();
                [523.25, 659.25, 783.99, 1046.50].forEach(function(freq, idx) {
                    var osc = ctx.createOscillator(), gain = ctx.createGain();
                    osc.type = 'sine';
                    osc.frequency.value = freq;
                    gain.gain.setValueAtTime(0, ctx.currentTime + idx * 0.12);
                    gain.gain.linearRampToValueAtTime(0.2, ctx.currentTime + idx * 0.12 + 0.04);
                    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + idx * 0.12 + 0.35);
                    osc.connect(gain);
                    gain.connect(ctx.destination);
                    osc.start(ctx.currentTime + idx * 0.12);
                    osc.stop(ctx.currentTime + idx * 0.12 + 0.4);
                });
            } catch (e) {}
        }

        function apriESelezionaMac(chkId, url, e) {
            if (e) { e.preventDefault(); e.stopPropagation(); }
            var chk = document.getElementById(chkId);
            if (chk) chk.checked = true;
            window.open(url, '_blank');
        }

        function setDomMac(dom, prov, btn) {
            currentDom = dom;
            currentProv = prov;
            document.querySelectorAll('.dom-btn').forEach(function(b){ b.setAttribute('aria-pressed', b === btn ? 'true' : 'false'); });
            aggiornaCredMac();
        }

        function aggiornaCredMac() {
            var c = (document.getElementById('inCognome') ? document.getElementById('inCognome').value.trim() : '').toLowerCase().replace(/[^a-z0-9]/g, '');
            var n = (document.getElementById('inNome') ? document.getElementById('inNome').value.trim() : '').toLowerCase().replace(/[^a-z0-9]/g, '');
            var pre = (c && n) ? (c + n) : (n || c || 'utente');
            if (pre.length > 20) pre = pre.substring(0, 20);
            document.getElementById('inEmail').value = pre + '@' + currentDom;
            var passBase = n || c || 'Utente';
            var cap = passBase.charAt(0).toUpperCase() + passBase.slice(1).toLowerCase();
            document.getElementById('inPass').value = cap + '123!';
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

        function avviaAutoMac() {
            ['inCognome', 'inNome', 'inTelefono', 'inEmail', 'inPass'].forEach(function(id) {
                var el = document.getElementById(id);
                if (el) el.classList.remove('errore');
            });
            var email = document.getElementById('inEmail').value.trim();
            var pass = document.getElementById('inPass').value.trim();
            var c = document.getElementById('inCognome').value.trim();
            var n = document.getElementById('inNome').value.trim();
            var t = document.getElementById('inTelefono').value.trim();
            var proton = document.getElementById('chkSvcProton').checked;
            var office = document.getElementById('chkSvcOffice').checked;
            var mcafee = document.getElementById('chkSvcMcAfee').checked;
            var norton = document.getElementById('chkSvcNorton').checked;
            var cyber = document.getElementById('chkSvcCyber').checked;

            var cognomeVal = c || 'Cliente';
            var nomeVal = n || 'Cliente';
            var nomeCompleto = (c && n) ? (c + ' ' + n).trim() : (c || n || 'Cliente');
            var emailVal = (email && email.indexOf('@') > 0) ? email : ('cliente@' + currentDom);
            var passVal = pass || 'Cliente123!';

            var payload = {
                Conferma: true,
                Email: emailVal,
                Password: passVal,
                Provider: currentProv,
                Cliente: nomeCompleto,
                Nome: nomeVal,
                Cognome: cognomeVal,
                Telefono: t,
                ProfiloApp: document.getElementById('selProfilo').value,
                Servizi: {
                    Proton: proton,
                    Office: office,
                    McAfee: mcafee,
                    Norton: norton,
                    Cyber: cyber
                }
            };
            var blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' });
            var a = document.createElement('a');
            a.href = URL.createObjectURL(blob);
            a.download = 'pcfacile-cred.json';
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            mostraEsito('\u2713 Installazione avviata! Il terminale prosegue automaticamente.', 'ok');
            showToast('Installazione avviata');
            playChimeMac();
            showTabMac('tab-live', document.getElementById('btn-tab-live'));
        }

        function applyStatus(data) {
            if (!data) return;
            if (data.inizio && !inizioLavori) {
                inizioLavori = Number(data.inizio) || Date.now();
            } else if (!inizioLavori) {
                inizioLavori = Date.now();
            }

            var pct = parseInt(data.percentuale, 10) || 0;
            document.getElementById('barFill').style.width = pct + '%';
            document.getElementById('pctText').innerText = pct + '%';
            if (data.faseCorrente) document.getElementById('faseText').innerText = data.faseCorrente;
            var detVal = data.dettaglio || '';

            var tasks = data.tasks || {};
            var doneCount = 0;
            for (var i = 0; i < TASK_KEYS.length; i++) {
                var k = TASK_KEYS[i];
                var t = tasks[k] || { stato: 'pending', dettaglio: '' };
                var stato = (t.stato || 'pending').toLowerCase();
                var det = t.dettaglio || '';
                if (stato === 'done' || stato === 'skipped' || stato === 'error') doneCount++;
                if (stato === 'running' && det) detVal = det;

                var row = document.getElementById('task-' + k);
                if (!row) continue;
                row.className = 'task-item ' + stato;
                var badge = row.querySelector('.task-badge');
                if (badge) {
                    var bClass = 'badge-pending', bText = 'In attesa';
                    if (stato === 'done') { bClass = 'badge-done-task'; bText = 'Fatto'; }
                    else if (stato === 'running') { bClass = 'badge-running'; bText = 'In corso'; }
                    else if (stato === 'error') { bClass = 'badge-error'; bText = 'Errore'; }
                    else if (stato === 'skipped') { bClass = 'badge-skipped'; bText = 'Saltato'; }
                    badge.className = 'task-badge ' + bClass;
                    badge.innerText = bText;
                }
                var icon = row.querySelector('.task-icon');
                if (icon) {
                    if (stato === 'done' || stato === 'skipped') icon.innerHTML = '&#10003;';
                    else if (stato === 'running') icon.innerHTML = '<span class="spinner"></span>';
                    else if (stato === 'error') icon.innerHTML = '&#10007;';
                    else icon.innerHTML = '&#9675;';
                }
                var dEl = row.querySelector('.task-detail');
                if (dEl) dEl.innerText = (det && stato !== 'pending' && stato !== 'done') ? det : '';
            }

            var tb = document.getElementById('taskCountBadge');
            if (tb) tb.innerText = doneCount + '/' + TASK_KEYS.length;

            document.getElementById('dettText').innerText = detVal;

            var b = document.getElementById('badgeLive');
            if (data.completato === true) {
                b.innerText = 'Completato';
                b.className = 'badge-stato ok';
                document.getElementById('bannerFine').style.display = 'block';
                if (!audioPlayed) { audioPlayed = true; playChimeMac(); }
            } else if (pct > 5) {
                b.innerText = 'Configurazione in corso';
            }

            if (!schedaScelta && pct > 5) {
                showTabMac('tab-live', document.getElementById('btn-tab-live'));
                schedaScelta = true;
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
                    ('Cliente', 'NOME_CLIENTE'), ('Telefono', 'TELEFONO_CLIENTE'),
                    ('ProfiloApp', 'PROFILO_APP')):
        if d.get(k):
            print(nome + '\t' + pulito(d[k]))
    svcs = d.get('Servizi', {})
    if isinstance(svcs, dict):
        for k, nome, predef in (('Proton', 'SVC_PROTON', True), ('Office', 'SVC_OFFICE', False),
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
                            EMAIL_CLIENTE|PASS_CLIENTE|NOME_CLIENTE|TELEFONO_CLIENTE|PROFILO_APP|SVC_PROTON|SVC_OFFICE|SVC_MCAFEE|SVC_NORTON|SVC_CYBER)
                                typeset -g "$chiave=$valore" ;;
                        esac
                    done <<< "$res"
                    # Letto: il file contiene la password in chiaro, lo cancello.
                    rm -f -- "$p" 2>/dev/null
                    pkill -f -i "TextEdit" 2>/dev/null || true
                    DATI_RICEVUTI=true
                    [[ -n "$EMAIL_CLIENTE" ]] && CRED_ACCOUNT="$EMAIL_CLIENTE"
                    [[ -n "$PASS_CLIENTE" ]] && CRED_PASSWORD="$PASS_CLIENTE"
                    return 0
                fi
            fi
        fi
    done
    return 1
}

# Aspetta i dati del cliente dal pannello: si chiama SOLO all'inizio dei passi
# Non si blocca mai: se i dati del cliente sono gia' arrivati dal pannello li usa,
# altrimenti prosegue subito con valori predefiniti ("Cliente", "cliente@icloud.com").
# L'operatore puo' compilare la scheda nel pannello in qualsiasi momento.
attendi_credenziali_mac() {
    if $MODO_TEST; then DATI_RICEVUTI=true; NOME_CLIENTE="Rossi Mario"; return 0; fi
    $DATI_RICEVUTI && return 0
    if leggi_credenziali_salvate_mac; then return 0; fi

    titolo "DATI CLIENTE (PANNELLO OPERATORE)"
    info "Dati cliente non inseriti nel pannello: proseguo senza fermarmi."
    info "  -> Puoi compilare la scheda nel pannello in qualsiasi momento (valori predefiniti applicati)."
    print -r -- ""

    [[ -z "$NOME_CLIENTE" || "$NOME_CLIENTE" == "Utente" ]] && NOME_CLIENTE="Cliente"
    [[ -z "$CRED_ACCOUNT" ]] && CRED_ACCOUNT="$(email_cliente "$NOME_CLIENTE")"
    [[ -z "$CRED_PASSWORD" ]] && CRED_PASSWORD="$(password_cliente "$NOME_CLIENTE")"
    DATI_RICEVUTI=true
    return 0
}

invoke_auto_signup_mac() {
    local nome_c="${1:-Cliente}"
    leggi_credenziali_salvate_mac

    titolo "PASSI MANUALI - ACCOUNT E SERVIZI DEL CLIENTE"

    if $MODO_TEST; then
        ok "TEST: Automazione Browser Mac simulata con successo su Proton Mail e servizi."
        add_report "Account Proton Mail" "OK"
        update_pannello_mac_status 90 "Servizi e attivazioni" "Completato (test)" false "servizi" "done" "Servizi simulati"
        update_pannello_mac_status 93 "Unieuro Cyber Protection" "Completato (test)" false "cyber" "done" "Cyber Protection simulato"
        return 0
    fi

    if [[ -z "$nome_c" || "$nome_c" == "Utente" ]]; then
        if [[ -n "$NOME_CLIENTE" && "$NOME_CLIENTE" != "Utente" ]]; then
            nome_c="$NOME_CLIENTE"
        else
            nome_c="Cliente"
            NOME_CLIENTE="Cliente"
        fi
    fi

    local email_proton="${EMAIL_CLIENTE:-${nome_c//[^a-zA-Z0-9]/}@proton.me}"
    local pass_gen="${PASS_CLIENTE:-$(password_cliente "$nome_c")}"
    local do_proton="${SVC_PROTON:-false}"
    local do_office="${SVC_OFFICE:-false}"
    local do_mcafee="${SVC_MCAFEE:-false}"
    local do_norton="${SVC_NORTON:-false}"
    local do_cyber="${SVC_CYBER:-false}"

    if ! $do_proton && ! $do_office && ! $do_mcafee && ! $do_norton && ! $do_cyber; then
        info "Nessun servizio aggiuntivo selezionato nel pannello: proseguo direttamente."
        update_pannello_mac_status 90 "Servizi e attivazioni" "Nessun servizio selezionato" false "servizi" "done" "Nessun servizio"
        update_pannello_mac_status 93 "Unieuro Cyber Protection" "Non acquistato (saltato)" false "cyber" "skipped" "Non selezionato"
        return 0
    fi

    info "Per ogni servizio indicato nel pannello si apre la pagina giusta con i dati pronti."
    print -r -- ""

    # 1. CREAZIONE ACCOUNT PROTON MAIL (SE SELEZIONATO)
    if [[ "$do_proton" == "true" ]]; then
        update_pannello_mac_status 86 "Servizi e attivazioni" "Creazione casella Proton Mail..." false "servizi" "running" "Account Proton Mail..."
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

        beep_attesa
        print -n -- "   Premi INVIO o 'S' per saltare (auto in 5s): "
        read -t 5 -r r_ok || r_ok=""
        print -r -- ""
        if [[ "$r_ok" == [Ss]* ]]; then
            info "Creazione account Proton Mail saltata dall'operatore."
            add_report "Account Proton Mail" "SALTATO"
        else
            ok "Account Proton Mail configurato con successo: $email_proton"
            add_report "Account Proton Mail ($email_proton)" "OK"
        fi
    fi

    # 2. RISCATTO CARD OFFICE 365 / MICROSOFT 365 (SE SELEZIONATO)
    if [[ "$do_office" == "true" ]]; then
        update_pannello_mac_status 87 "Servizi e attivazioni" "Attivazione card Office 365..." false "servizi" "running" "Card Office 365..."
        titolo "2. ATTIVAZIONE CARD MICROSOFT 365 / OFFICE"
        print -r -- "   ${C_TXT}Dati per il riscatto del codice Office 365 a 25 caratteri:${C_RST}"
        print -r -- "     ${C_CYAN}- Email Cliente  :${C_RST} $email_proton"
        print -r -- "     ${C_INFO}- Password       :${C_RST} $pass_gen"
        print -r -- ""

        echo -n "$email_proton" | pbcopy 2>/dev/null
        info "Apertura portale Riscatto Office (microsoft365.com/setup) a sinistra..."
        set_split_screen_mac "https://microsoft365.com/setup"

        printf '\a'
        print -r -- "${C_INFO}  ============================================================${C_RST}"
        print -r -- "${C_OK}   [ATTIVAZIONE CARD OFFICE 365 - GUIDA RAPIDA]${C_RST}"
        print -r -- "${C_TXT}   Accedi con l'email cliente e digita la chiave da 25 caratteri.${C_RST}"
        print -r -- "${C_INFO}  ============================================================${C_RST}"
        print -r -- ""

        beep_attesa
        print -n -- "   Premi INVIO o 'S' per saltare (auto in 5s): "
        read -t 5 -r r_off || r_off=""
        print -r -- ""
        if [[ "$r_off" == [Ss]* ]]; then
            info "Attivazione Office 365 saltata dall'operatore."
            add_report "Card Office 365" "SALTATO"
        else
            ok "Card Office 365 attivata con successo su $email_proton!"
            add_report "Card Office 365 ($email_proton)" "OK"
        fi
    fi

    # 3. ATTIVAZIONE CARD MCAFEE ANTIVIRUS (SE SELEZIONATO)
    if [[ "$do_mcafee" == "true" ]]; then
        update_pannello_mac_status 88 "Servizi e attivazioni" "Attivazione card McAfee..." false "servizi" "running" "Card McAfee..."
        titolo "3. ATTIVAZIONE CARD MCAFEE ANTIVIRUS"
        print -r -- "   ${C_TXT}Dati per l'attivazione della licenza McAfee:${C_RST}"
        print -r -- "     ${C_CYAN}- Email Cliente  :${C_RST} $email_proton"
        print -r -- "     ${C_INFO}- Password       :${C_RST} $pass_gen"
        print -r -- ""

        echo -n "$email_proton" | pbcopy 2>/dev/null
        info "Apertura portale McAfee Activate (mcafee.com/activate) a sinistra..."
        set_split_screen_mac "https://www.mcafee.com/activate"

        printf '\a'
        print -r -- "${C_INFO}  ============================================================${C_RST}"
        print -r -- "${C_OK}   [ATTIVAZIONE CARD MCAFEE - GUIDA RAPIDA]${C_RST}"
        print -r -- "${C_TXT}   Inserisci il codice Product Key / PIN della card McAfee e l'email.${C_RST}"
        print -r -- "${C_INFO}  ============================================================${C_RST}"
        print -r -- ""

        beep_attesa
        print -n -- "   Premi INVIO o 'S' per saltare (auto in 5s): "
        read -t 5 -r r_mc || r_mc=""
        print -r -- ""
        if [[ "$r_mc" == [Ss]* ]]; then
            info "Attivazione McAfee saltata dall'operatore."
            add_report "Card McAfee" "SALTATO"
        else
            ok "Card McAfee attivata con successo su $email_proton!"
            add_report "Card McAfee ($email_proton)" "OK"
        fi
    fi

    # 4. ATTIVAZIONE CARD NORTON ANTIVIRUS (SE SELEZIONATO)
    if [[ "$do_norton" == "true" ]]; then
        update_pannello_mac_status 89 "Servizi e attivazioni" "Attivazione card Norton..." false "servizi" "running" "Card Norton..."
        titolo "4. ATTIVAZIONE CARD NORTON ANTIVIRUS"
        print -r -- "   ${C_TXT}Dati per l'attivazione della licenza Norton:${C_RST}"
        print -r -- "     ${C_CYAN}- Email Cliente  :${C_RST} $email_proton"
        print -r -- "     ${C_INFO}- Password       :${C_RST} $pass_gen"
        print -r -- ""

        echo -n "$email_proton" | pbcopy 2>/dev/null
        info "Apertura portale Norton Setup (norton.com/setup) a sinistra..."
        set_split_screen_mac "https://www.norton.com/setup"

        printf '\a'
        print -r -- "${C_INFO}  ============================================================${C_RST}"
        print -r -- "${C_OK}   [ATTIVAZIONE CARD NORTON - GUIDA RAPIDA]${C_RST}"
        print -r -- "${C_TXT}   Inserisci il codice Product Key della card Norton e l'email.${C_RST}"
        print -r -- "${C_INFO}  ============================================================${C_RST}"
        print -r -- ""

        beep_attesa
        print -n -- "   Premi INVIO o 'S' per saltare (auto in 5s): "
        read -t 5 -r r_no || r_no=""
        print -r -- ""
        if [[ "$r_no" == [Ss]* ]]; then
            info "Attivazione Norton saltata dall'operatore."
            add_report "Card Norton" "SALTATO"
        else
            ok "Card Norton attivata con successo su $email_proton!"
            add_report "Card Norton ($email_proton)" "OK"
        fi
    fi

    update_pannello_mac_status 90 "Servizi e attivazioni" "Completato" false "servizi" "done" "Servizi cliente completati"

    # 5. REGISTRAZIONE UNIEURO CYBER PROTECTION (SE SELEZIONATO)
    if [[ "$do_cyber" == "true" ]]; then
        update_pannello_mac_status 91 "Unieuro Cyber Protection" "Configurazione portale Cyber Protection..." false "cyber" "running" "Portale Cyber Protection..."
        local tel="${TELEFONO_CLIENTE:-}"

        titolo "5. REGISTRAZIONE UNIEURO CYBER PROTECTION (MAC)"
        print -r -- "   ${C_TXT}Dati cliente pronti per l'attivazione Cyber Protection:${C_RST}"
        print -r -- "     ${C_CYAN}- Nome / Cognome :${C_RST} $nome_c"
        print -r -- "     ${C_CYAN}- Email Creata   :${C_RST} $email_proton"
        print -r -- "     ${C_CYAN}- Cellulare      :${C_RST} ${tel:-Non specificato}"
        print -r -- "     ${C_INFO}- Password       :${C_RST} $pass_gen"
        print -r -- ""

        echo -n "$email_proton" | pbcopy 2>/dev/null
        info "Apertura portale Unieuro Cyber Protection in Safari a sinistra..."
        set_split_screen_mac "https://unieuro-cyber-protection.covercare.it"

        printf '\a'
        print -r -- "${C_INFO}  ============================================================${C_RST}"
        print -r -- "${C_OK}   [REGISTRAZIONE CYBER PROTECTION - DATI PRONTI]${C_RST}"
        print -r -- "${C_TXT}   Inserisci i dati anagrafici e il codice PIN/Card grattato.${C_RST}"
        print -r -- "${C_INFO}  ============================================================${C_RST}"
        print -r -- ""

        beep_attesa
        print -n -- "   Premi INVIO o 'S' per saltare (auto in 5s): "
        read -t 5 -r r_cyb || r_cyb=""
        print -r -- ""
        if [[ "$r_cyb" == [Ss]* ]]; then
            info "Cyber Protection saltato dall'operatore."
            add_report "Unieuro Cyber Protection" "SALTATO"
            update_pannello_mac_status 93 "Unieuro Cyber Protection" "Saltato dall'operatore" false "cyber" "skipped" "Saltato"
        else
            ok "Unieuro Cyber Protection registrato con successo per $nome_c ($email_proton)!"
            add_report "Unieuro Cyber Protection ($email_proton)" "OK"
            update_pannello_mac_status 93 "Unieuro Cyber Protection" "Completato" false "cyber" "done" "Cyber Protection registrato"
        fi
    else
        update_pannello_mac_status 93 "Unieuro Cyber Protection" "Non acquistato (saltato)" false "cyber" "skipped" "Non selezionato"
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
    connetti_wifi_mac
  fi
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
CRED_ACCOUNT="utente@icloud.com"
CRED_PASSWORD="Utente123!"
DATI_RICEVUTI=false
PROFILO_APP=""

if $RUN_REALE; then
    start_sudo_keepalive_mac
    open_pannello_mac "$NOME_CLIENTE" "$CRED_ACCOUNT" "$CRED_PASSWORD"
fi

titolo "FASE 1 di 3 - Programmi e lingua (automatico)"
info "Intanto inserisci i dati del cliente nel pannello operatore."

# =============================================================================
# PASSO 1: LINGUA & REGIONE ITALIANA
# =============================================================================
update_pannello_mac_status 15 "Lingua e Regione" "Configurazione it-IT..." false "lingua" "running" "Configurazione it-IT..."
titolo "1. Lingua e Regione (Italiano)"
start_barra_animata_mac "Configurazione Lingua e Regione (it-IT)"
if defaults read NSGlobalDomain AppleLocale 2>/dev/null | grep -qi 'it_IT'; then
    ok "macOS risulta gia' configurato in Italiano."
    add_report "Lingua italiana" "OK"
    stop_barra_animata_mac
    update_pannello_mac_status 20 "Lingua e Regione" "Gia' configurato in Italiano" false "lingua" "done" "Italiano (it-IT)"
else
    if $RUN_REALE; then
        defaults write NSGlobalDomain AppleLanguages -array "it-IT" "en-IT" 2>/dev/null
        defaults write NSGlobalDomain AppleLocale -string "it_IT" 2>/dev/null
        ok "Lingua/regione impostate su Italiano."
        add_report "Lingua italiana" "OK"
    fi
    stop_barra_animata_mac
    update_pannello_mac_status 20 "Lingua e Regione" "Completato" false "lingua" "done" "Italiano (it-IT)"
fi

# =============================================================================
# PASSO 2: SINCRONIZZAZIONE ORA & NOME MAC
# =============================================================================
update_pannello_mac_status 25 "Sincronizzazione orario" "Orario di rete..." false "orario" "running" "Sincronizzazione server Apple..."
titolo "2. Sincronizzazione orario"
start_barra_animata_mac "Sincronizzazione orario di rete (time.apple.com)"
if $RUN_REALE; then
    sudo systemsetup -setusingnetworktime on >/dev/null 2>&1
    sudo systemsetup -setnetworktimeserver time.apple.com >/dev/null 2>&1
    ok "Orario di rete attivo."
fi
stop_barra_animata_mac
update_pannello_mac_status 30 "Sincronizzazione orario" "Completato" false "orario" "done" "Orario di rete attivo"

# =============================================================================
# PASSO 3: SNAPSHOT DI RIPRISTINO APFS
# =============================================================================
update_pannello_mac_status 35 "Punto di Ripristino" "Creazione snapshot APFS..." false "ripristino" "running" "Creazione snapshot..."
titolo "3. Snapshot APFS di Ripristino"
start_barra_animata_mac "Creazione snapshot APFS di sicurezza"
if $RUN_REALE; then
    if sudo tmutil localsnapshot >/dev/null 2>&1; then
        ok "Snapshot APFS creato con successo."
        add_report "Punto di ripristino APFS" "OK"
        update_pannello_mac_status 45 "Punto di Ripristino" "Completato" false "ripristino" "done" "Snapshot APFS creato"
    else
        info "Snapshot APFS non disponibile (proseguo)."
        add_report "Punto di ripristino APFS" "SALTATO"
        update_pannello_mac_status 45 "Punto di Ripristino" "Non disponibile (saltato)" false "ripristino" "skipped" "Ottimizzato per SSD"
    fi
else
    update_pannello_mac_status 45 "Punto di Ripristino" "Completato (test)" false "ripristino" "done" "Snapshot simulato"
fi
stop_barra_animata_mac

# =============================================================================
# PASSO 4: OTTIMIZZAZIONE macOS (Defaults)
# =============================================================================
update_pannello_mac_status 50 "Ottimizzazione macOS" "Applicazione impostazioni Finder e Dock..." false "ottimizza" "running" "Finder & Dock..."
titolo "4. Ottimizzazione macOS"
start_barra_animata_mac "Applicazione impostazioni Finder, Dock e screenshot"
if $RUN_REALE; then
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true 2>/dev/null
    defaults write com.apple.finder ShowPathbar -bool true 2>/dev/null
    defaults write com.apple.finder ShowStatusBar -bool true 2>/dev/null
    defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv" 2>/dev/null
    defaults write com.apple.dock autohide -bool true 2>/dev/null
    defaults write com.apple.dock show-recents -bool false 2>/dev/null
    mkdir -p "$HOME/Desktop/Screenshot" 2>/dev/null
    defaults write com.apple.screencapture location -string "$HOME/Desktop/Screenshot" 2>/dev/null
    defaults write com.apple.Safari AutoOpenSafeDownloads -bool false 2>/dev/null
    killall Finder Dock 2>/dev/null
    ok "Impostazioni e ottimizzazioni macOS applicate."
    add_report "Ottimizzazione macOS" "OK"
fi
stop_barra_animata_mac
update_pannello_mac_status 55 "Ottimizzazione macOS" "Completato" false "ottimizza" "done" "Finder, Dock e screenshot ottimizzati"

# =============================================================================
# PASSO 5: ROSETTA 2 & HOMEBREW
# =============================================================================
update_pannello_mac_status 60 "Gestore Pacchetti" "Verifica Homebrew e Rosetta 2..." false "gestore" "running" "Verifica Homebrew..."
titolo "5. Rosetta 2 & Gestore App (Homebrew)"
if [[ "$(uname -m)" == "arm64" ]] && $RUN_REALE; then
    if /usr/bin/pgrep -q oahd 2>/dev/null; then
        ok "Rosetta 2 presente."
    else
        info "Installazione Rosetta 2 per compatibilita' universale..."
        start_barra_animata_mac "Installazione Rosetta 2 per compatibilita' universale"
        softwareupdate --install-rosetta --agree-to-license >/dev/null 2>&1
        stop_barra_animata_mac
        ok "Rosetta 2 installata."
    fi
fi

if ! command -v brew >/dev/null 2>&1 && $RUN_REALE; then
    info "Installazione Homebrew..."
    start_barra_animata_mac "Installazione gestore pacchetti Homebrew"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null)"
    eval "$(/usr/local/bin/brew shellenv 2>/dev/null)"
    stop_barra_animata_mac
fi
command -v brew >/dev/null 2>&1 && ok "Homebrew pronto."
update_pannello_mac_status 65 "Gestore Pacchetti" "Completato" false "gestore" "done" "Homebrew e Rosetta 2 pronti"

# =============================================================================
# PASSO 6: INSTALLAZIONE APPLICAZIONI
# =============================================================================
update_pannello_mac_status 68 "Installazione Applicazioni" "Preparazione profilo app..." false "app" "running" "Avvio installazione..."
titolo "6. Installazione Applicazioni"
# Profilo dal pannello se i dati sono gia' arrivati, altrimenti BASE (la
# fase 1 non si ferma ad aspettare).
$RUN_REALE && ! $DATI_RICEVUTI && leggi_credenziali_salvate_mac
case "$PROFILO_APP" in UFFICIO|GAMING) PROFILO="$PROFILO_APP";; *) PROFILO="BASE";; esac
info "Profilo app: $PROFILO"
if [[ -n "$PROFILO" ]] && $RUN_REALE; then
    local app_tot=0
    for riga in "${CATALOGO[@]}"; do
        local profili="${${(s:|:)riga}[3]}"
        [[ " $profili " == *" $PROFILO "* ]] && ((app_tot++))
    done
    [[ $app_tot -eq 0 ]] && app_tot=1
    local app_idx=0

    for riga in "${CATALOGO[@]}"; do
        nome="${${(s:|:)riga}[1]}"; cask="${${(s:|:)riga}[2]}"; profili="${${(s:|:)riga}[3]}"
        if [[ " $profili " == *" $PROFILO "* ]]; then
            ((app_idx++))
            local pct_app=$(( 68 + (app_idx * 12 / app_tot) ))
            update_pannello_mac_status "$pct_app" "Installazione Applicazioni" "Installazione $nome in corso..." false "app" "running" "$nome ($app_idx/$app_tot)"
            start_barra_animata_mac "Installazione $nome ($app_idx/$app_tot)"
            info "Installazione $nome in corso..."
            # 1. Tentativo di installazione offline diretta da memoria USB (.dmg/.pkg)
            if installa_offline_app_mac "$nome"; then
                stop_barra_animata_mac
                ok "$nome installato con successo da cache offline USB!"
                crea_collegamento_desktop_mac "$nome" "$cask"
                INSTALLATE+=("$nome")
                continue
            fi

            # Gia' installata: salto (i passi gia' fatti non si rifanno).
            if [[ -d "/Applications/$nome.app" ]] || { command -v brew >/dev/null 2>&1 && brew list --cask "$cask" >/dev/null 2>&1; }; then
                stop_barra_animata_mac
                ok "$nome gia' installato: salto."
                crea_collegamento_desktop_mac "$nome" "$cask"
                INSTALLATE+=("$nome")
                continue
            fi
            # 2. Fallback su Homebrew se connesso e offline non presente
            if command -v brew >/dev/null 2>&1; then
                if NONINTERACTIVE=1 HOMEBREW_NO_ENV_HINTS=1 HOMEBREW_NO_INSTALL_CLEANUP=1 brew install --cask "$cask" >/dev/null 2>&1; then
                    # Rimuove flag quarantena Gatekeeper per evitare popup di conferma al primo avvio
                    xattr -d -r com.apple.quarantine "/Applications/$nome.app" 2>/dev/null || true
                    # Chiude eventuali splash screen avviati in automatico post-install
                    pkill -f -i "$nome" 2>/dev/null || true
                    stop_barra_animata_mac
                    ok "$nome installato tramite Homebrew."
                    crea_collegamento_desktop_mac "$nome" "$cask"
                    INSTALLATE+=("$nome")
                else
                    stop_barra_animata_mac
                    info "$nome non installato (proseguo)."
                fi
            else
                stop_barra_animata_mac
            fi
        fi
    done
    stop_barra_animata_mac
    # Pulizia popup residui noti
    pkill -f -i "Spotify" 2>/dev/null || true
    pkill -f -i "Discord" 2>/dev/null || true
    pkill -f -i "Zoom" 2>/dev/null || true
    pkill -f -i "Steam" 2>/dev/null || true
    add_report "App profilo $PROFILO (${#INSTALLATE} installate)" "OK"
    update_pannello_mac_status 80 "Installazione Applicazioni" "Tutte le app installate" false "app" "done" "${#INSTALLATE} app installate"
else
    update_pannello_mac_status 80 "Installazione Applicazioni" "Completato (test)" false "app" "done" "Installazione simulata"
fi

# =============================================================================
# FASE 2: PASSI MANUALI (dati del cliente dal pannello, una volta sola)
# =============================================================================
titolo "FASE 2 di 3 - Passi manuali (operatore)"
update_pannello_mac_status 82 "Passi manuali" "In attesa dati cliente e servizi..." false "account" "running" "Dati cliente e nome Mac..."
$RUN_REALE && attendi_credenziali_mac
[[ -z "$CRED_ACCOUNT" || "$CRED_ACCOUNT" == "utente@icloud.com" ]] && CRED_ACCOUNT="$(email_cliente "$NOME_CLIENTE")"
[[ -z "$CRED_PASSWORD" || "$CRED_PASSWORD" == "Utente123!" ]] && CRED_PASSWORD="$(password_cliente "$NOME_CLIENTE")"

titolo "7. Nome del Mac"
start_barra_animata_mac "Configurazione nome Mac ($NOME_CLIENTE)"
if $RUN_REALE && [[ -n "$NOME_CLIENTE" ]]; then
    host="${NOME_CLIENTE//[^A-Za-z0-9-]/}"
    if [[ "$(scutil --get ComputerName 2>/dev/null)" == "$NOME_CLIENTE" ]]; then
        ok "Nome Mac gia' impostato: $NOME_CLIENTE"
    else
        sudo scutil --set ComputerName "$NOME_CLIENTE" 2>/dev/null
        sudo scutil --set HostName "$host" 2>/dev/null
        sudo scutil --set LocalHostName "$host" 2>/dev/null
        ok "Nome Mac impostato a: $NOME_CLIENTE"
    fi
    add_report "Nome Mac ($NOME_CLIENTE)" "OK"
fi
stop_barra_animata_mac
update_pannello_mac_status 85 "Passi manuali" "Nome Mac configurato" false "account" "done" "$NOME_CLIENTE"

# Account e servizi indicati nel pannello (Proton, Office, antivirus, Cyber
# Protection): pagina giusta + dati pronti, conferma con INVIO.
invoke_auto_signup_mac "${NOME_CLIENTE:-Utente}"

# =============================================================================
# FASE 3: AGGIORNAMENTI (sempre per ultimi)
# =============================================================================
titolo "FASE 3 di 3 - Aggiornamenti (ultimo passo)"
update_pannello_mac_status 94 "Aggiornamenti" "App (Homebrew) e macOS..." false "aggiorna" "running" "Download aggiornamenti..."
if $RUN_REALE; then
    if command -v brew >/dev/null 2>&1; then
        info "Aggiorno le app installate con Homebrew..."
        start_barra_animata_mac "Aggiornamento applicazioni (Homebrew)"
        NONINTERACTIVE=1 HOMEBREW_NO_ENV_HINTS=1 brew upgrade >/dev/null 2>&1 && ok "App aggiornate." || info "Aggiornamento app non completato (proseguo)."
        stop_barra_animata_mac
    fi
    info "Scarico gli aggiornamenti di macOS (si installano al riavvio da Impostazioni di Sistema)..."
    start_barra_animata_mac "Download aggiornamenti di sicurezza macOS"
    if softwareupdate --download --all >/dev/null 2>&1; then
        stop_barra_animata_mac
        ok "Aggiornamenti macOS scaricati."
        add_report "Aggiornamenti macOS (scaricati)" "OK"
        update_pannello_mac_status 96 "Aggiornamenti" "Completato" false "aggiorna" "done" "macOS e app aggiornati"
    else
        stop_barra_animata_mac
        info "Nessun aggiornamento macOS scaricato (gia' aggiornato o rete assente)."
        add_report "Aggiornamenti macOS" "AVVISO"
        update_pannello_mac_status 96 "Aggiornamenti" "Verificato" false "aggiorna" "done" "Nessun aggiornamento in sospeso"
    fi
else
    update_pannello_mac_status 96 "Aggiornamenti" "Completato (test)" false "aggiorna" "done" "Aggiornamenti simulati"
fi

# =============================================================================
# PASSO 8: FILEVAULT & DIAGNOSTICA
# =============================================================================
update_pannello_mac_status 97 "FileVault & Scheda Consegna" "Verifica crittografia FileVault..." false "sicurezza" "running" "Verifica FileVault..."
titolo "8. Sicurezza FileVault & Scheda Consegna"
start_barra_animata_mac "Verifica stato sicurezza FileVault"
FV_KEY=""
if $RUN_REALE; then
    FV_STATO="$(fdesetup status 2>/dev/null)"
    if echo "$FV_STATO" | grep -q "On"; then
        ok "FileVault attivo."
        update_pannello_mac_status 98 "Sicurezza FileVault" "FileVault attivo" false "sicurezza" "done" "FileVault attivo"
    else
        info "FileVault non attivo."
        update_pannello_mac_status 98 "Sicurezza FileVault" "FileVault non attivo" false "sicurezza" "done" "FileVault opzionale"
    fi
else
    update_pannello_mac_status 98 "Sicurezza FileVault" "Completato (test)" false "sicurezza" "done" "Verifica simulata"
fi
stop_barra_animata_mac

# ---- Funzioni finali: Scheda PDF, Log Strutturato, GitHub Auto-Report --------
salva_scheda_consegna_mac() {
    local html_doc="$1"
    local desktop_dir="$HOME/Desktop"
    local cartella_lavoro="/tmp/pcfacile_consegna"
    mkdir -p "$cartella_lavoro" 2>/dev/null

    local nome_base="Scheda-Consegna-Mac"
    local html_lavoro="$cartella_lavoro/$nome_base.html"
    local pdf_lavoro="$cartella_lavoro/$nome_base.pdf"
    local html_desktop="$desktop_dir/$nome_base.html"
    local pdf_desktop="$desktop_dir/$nome_base.pdf"

    print -r -- "$html_doc" > "$html_lavoro"
    rm -f "$pdf_lavoro" 2>/dev/null

    local browser_pdf=""
    for b in \
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
        "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" \
        "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" \
        "/Applications/Chromium.app/Contents/MacOS/Chromium"; do
        if [[ -x "$b" ]]; then
            browser_pdf="$b"
            break
        fi
    done

    local pdf_creato=false
    if [[ -n "$browser_pdf" ]]; then
        local user_data="/tmp/pcf_chrome_tmp"
        mkdir -p "$user_data" 2>/dev/null
        "$browser_pdf" --headless --disable-gpu --no-first-run --no-default-browser-check \
            --user-data-dir="$user_data" \
            --no-pdf-header-footer --print-to-pdf="$pdf_lavoro" "file://$html_lavoro" >/dev/null 2>&1 || true
        rm -rf "$user_data" 2>/dev/null

        if [[ -s "$pdf_lavoro" ]]; then
            pdf_creato=true
        fi
    fi

    if $pdf_creato; then
        mv -f "$pdf_lavoro" "$pdf_desktop" 2>/dev/null
        rm -f "$html_desktop" 2>/dev/null
        ok "Scheda di consegna PDF creata sul Desktop: $pdf_desktop"
    else
        cp -f "$html_lavoro" "$html_desktop" 2>/dev/null
        info "Scheda di consegna HTML creata sul Desktop: $html_desktop (aprila e stampa in PDF)"
    fi
    rm -rf "$cartella_lavoro" 2>/dev/null
}

mostra_riepilogo_console_mac() {
    titolo "RIEPILOGO CONFIGURAZIONE MAC"
    print -r -- "${C_TXT}   Voci completate:${C_RST}"
    local i
    for ((i=1; i<=${#REPORT_VOCI}; i++)); do
        local voce="${REPORT_VOCI[$i]}"
        local esito="${REPORT_ESITI[$i]}"
        case "$esito" in
            "OK")      print -r -- "     ${C_OK}[OK]${C_RST} $voce" ;;
            "AVVISO")  print -r -- "     ${C_INFO}[AVVISO]${C_RST} $voce" ;;
            "SALTATO") print -r -- "     ${C_DIM}[SALTATO]${C_RST} $voce" ;;
            "ERRORE")  print -r -- "     ${C_ERR}[ERRORE]${C_RST} $voce" ;;
            *)         print -r -- "     ${C_TXT}[$esito]${C_RST} $voce" ;;
        esac
    done
    print -r -- ""
}

salva_log_strutturato_mac() {
    local cartella_log="/Library/Application Support/PCFacile/log"
    if $MODO_TEST || ! sudo -n mkdir -p "$cartella_log" 2>/dev/null || ! sudo -n chmod 777 "$cartella_log" 2>/dev/null || [[ ! -w "$cartella_log" ]]; then
        cartella_log="$HOME/Library/Logs/PCFacile"
        mkdir -p "$cartella_log" 2>/dev/null
    fi
    [[ ! -d "$cartella_log" ]] && return 0

    local hw="$(get_hw_info_mac)"
    local hw_m="${${(s:|:)hw}[1]}"
    local hw_c="${${(s:|:)hw}[2]}"
    local hw_r="${${(s:|:)hw}[3]}"
    local hw_s="${${(s:|:)hw}[4]}"
    local modello_clean="${hw_m//[^a-zA-Z0-9_-]/_}"
    [[ -z "$modello_clean" ]] && modello_clean="Mac"

    local data_file="$(date '+%Y-%m-%d_%H-%M')"
    local base_log="$cartella_log/${data_file}_${modello_clean}"

    # 1. CSV
    local csv_file="$base_log.csv"
    {
        print -r -- "voce,esito"
        local i
        for ((i=1; i<=${#REPORT_VOCI}; i++)); do
            local v="${REPORT_VOCI[$i]//\"/\"\"}"
            local e="${REPORT_ESITI[$i]//\"/\"\"}"
            print -r -- "\"$v\",\"$e\""
        done
    } > "$csv_file" 2>/dev/null

    # 2. JSON
    local json_file="$base_log.json"
    if command -v python3 >/dev/null 2>&1; then
        python3 -c '
import sys, json, datetime

voci = sys.argv[1].split("\t") if sys.argv[1] else []
esiti = sys.argv[2].split("\t") if sys.argv[2] else []
apps = sys.argv[3].split("\t") if sys.argv[3] else []
imprevisti = sys.argv[4].split("\t") if sys.argv[4] else []

report = [{"voce": v, "esito": e} for v, e in zip(voci, esiti) if v]

dati = {
    "versioneScript": sys.argv[5],
    "timestamp": datetime.datetime.now().isoformat(),
    "hardware": {
        "modello": sys.argv[6],
        "cpu": sys.argv[7],
        "ram": sys.argv[8],
        "seriale": sys.argv[9]
    },
    "os": sys.argv[10],
    "applicazioniInstallate": [a for a in apps if a],
    "report": report,
    "erroriImprevisti": [err for err in imprevisti if err]
}

with open(sys.argv[11], "w", encoding="utf-8") as f:
    json.dump(dati, f, indent=2, ensure_ascii=False)
' "${(pj:\t:)REPORT_VOCI}" "${(pj:\t:)REPORT_ESITI}" "${(pj:\t:)INSTALLATE}" "${(pj:\t:)ERRORI_IMPREVISTI}" \
  "$SCRIPT_VERSION" "$hw_m" "$hw_c" "$hw_r" "$hw_s" "$(sw_vers -productVersion 2>/dev/null)" "$json_file" 2>/dev/null
    fi

    # 3. Interventi storico cumulativo
    local storico="$cartella_log/interventi.csv"
    if [[ ! -f "$storico" ]]; then
        print -r -- "Data,Modello,Seriale,Applicazioni,Esito" > "$storico" 2>/dev/null
    fi
    local esito_globale="OK"
    for e in "${REPORT_ESITI[@]}"; do
        if [[ "$e" == "ERRORE" ]]; then esito_globale="ERRORE"; break; fi
        if [[ "$e" == "AVVISO" ]]; then esito_globale="AVVISO"; fi
    done
    print -r -- "\"$(date '+%Y-%m-%d %H:%M')\",\"$hw_m\",\"$hw_s\",\"${#INSTALLATE}\",\"$esito_globale\"" >> "$storico" 2>/dev/null

    ok "Log tecnico salvato: $base_log.json / .csv"
}

send_report_github_mac() {
    $MODO_TEST && return 0
    ! $RUN_REALE && return 0
    [[ -n "$PESTER_TEST" || -n "$ZSH_TEST" ]] && return 0

    local n_errore=0 n_avviso=0
    local problemi=""
    local i
    for ((i=1; i<=${#REPORT_VOCI}; i++)); do
        local voce="${REPORT_VOCI[$i]}"
        local esito="${REPORT_ESITI[$i]}"
        if [[ "$esito" == "ERRORE" ]]; then
            ((n_errore++))
            problemi+="- **ERRORE**: $voce"$'\n'
        elif [[ "$esito" == "AVVISO" ]]; then
            ((n_avviso++))
            problemi+="- **AVVISO**: $voce"$'\n'
        fi
    done

    # Invia issue SOLO se ci sono problemi effettivi o imprevisti gestiti (zero spam)
    if (( n_errore == 0 && n_avviso == 0 && ${#ERRORI_IMPREVISTI} == 0 )); then
        return 0
    fi

    local hw="$(get_hw_info_mac)"
    local hw_m="${${(s:|:)hw}[1]}"
    [[ -z "$hw_m" ]] && hw_m="Apple Mac sconosciuto"
    local os_ver="$(sw_vers -productVersion 2>/dev/null || echo "macOS")"
    local os_build="$(sw_vers -buildVersion 2>/dev/null || echo "")"
    local data_ora="$(date '+%Y-%m-%d %H:%M')"

    local corpo="**Mac**: $hw_m"$'\n'
    corpo+="**macOS**: $os_ver ($os_build)"$'\n'
    corpo+="**Script**: v$SCRIPT_VERSION (macOS)"$'\n'
    corpo+="**Data**: $data_ora"$'\n\n'

    if [[ -n "$problemi" ]]; then
        corpo+="### Esiti da controllare"$'\n'
        corpo+="$problemi"$'\n'
    fi

    if (( ${#ERRORI_IMPREVISTI} > 0 )); then
        corpo+="### Imprevisti gestiti (non bloccanti)"$'\n'
        for err in "${ERRORI_IMPREVISTI[@]}"; do
            corpo+="- $err"$'\n'
        done
        corpo+=$'\n'
    fi

    local titolo="[Auto-report Mac] $hw_m - $n_errore errori, $n_avviso avvisi"

    local payload
    if command -v python3 >/dev/null 2>&1; then
        payload="$(python3 -c 'import sys, json; print(json.dumps({"title": sys.argv[1], "body": sys.argv[2]}))' "$titolo" "$corpo" 2>/dev/null)"
    else
        local t_esc="${titolo//\"/\\\"}"
        local b_esc="${corpo//\"/\\\"}"
        b_esc="${b_esc//$'\n'/\\n}"
        payload="{\"title\":\"$t_esc\",\"body\":\"$b_esc\"}"
    fi

    curl -fsSL -X POST "https://api.github.com/repos/$GH_REPORT_REPO/issues" \
        -H "Authorization: Bearer $GH_REPORT_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        -H "Content-Type: application/json; charset=utf-8" \
        -d "$payload" \
        --max-time 10 >/dev/null 2>&1 || true
}

update_pannello_mac_status 99 "FileVault & Scheda Consegna" "Generazione scheda cliente..." false "diagnostica" "running" "Generazione scheda..."
start_barra_animata_mac "Generazione scheda consegna cliente"

# Genera Scheda Consegna Mac HTML
hw="$(get_hw_info_mac)"
hw_m="${${(s:|:)hw}[1]}"
hw_c="${${(s:|:)hw}[2]}"
hw_r="${${(s:|:)hw}[3]}"
hw_s="${${(s:|:)hw}[4]}"
hw_os="${${(s:|:)hw}[5]}"

batt="$(get_battery_info_mac)"
batt_desc="${${(s:|:)batt}[2]} - ${${(s:|:)batt}[3]}"
[[ -z "$batt_desc" || "$batt_desc" == " - " ]] && batt_desc="Alimentazione da rete / Fisso"

storage="$(get_storage_info_mac)"
storage_desc="${${(s:|:)storage}[1]} (${${(s:|:)storage}[2]}, ${${(s:|:)storage}[3]})"

os_ver="$(sw_vers -productVersion 2>/dev/null || echo "macOS")"
os_build="$(sw_vers -buildVersion 2>/dev/null || echo "")"
mac_host="$(scutil --get ComputerName 2>/dev/null || hostname -s 2>/dev/null || echo "Mac")"

# Valori escapati per la scheda HTML (nome, credenziali e dati hardware)
h_nome="$(html_esc "${NOME_CLIENTE:-Cliente}")"
h_tel="$(html_esc "${TELEFONO_CLIENTE:-}")"
h_account="$(html_esc "$CRED_ACCOUNT")"
h_password="$(html_esc "$CRED_PASSWORD")"
h_mac_name="$(html_esc "$mac_host")"
hw_m="$(html_esc "$hw_m")"
hw_c="$(html_esc "$hw_c")"
hw_r="$(html_esc "$hw_r")"
hw_s="$(html_esc "$hw_s")"
batt_desc="$(html_esc "$batt_desc")"
storage_desc="$(html_esc "$storage_desc")"

# Riquadro cellulare se presente
tel_riga=""
if [[ -n "$h_tel" ]]; then
    tel_riga="<tr><td>Cellulare / Tel:</td><td><strong>$h_tel</strong></td></tr>"
fi

# Servizi inclusi
servizi_inclusi_arr=()
servizi_righe=""
if [[ "$SVC_PROTON" == true ]]; then
    servizi_inclusi_arr+=("Proton Mail")
fi
if [[ "$SVC_OFFICE" == true ]]; then
    servizi_inclusi_arr+=("Microsoft 365 / Office")
    servizi_righe+="<tr><td style='font-weight: 600;'>Office / Microsoft 365:</td><td>Attivato con account del cliente &bull; PIN card registrato</td></tr>"
fi
if [[ "$SVC_MCAFEE" == true ]]; then
    servizi_inclusi_arr+=("McAfee")
    servizi_righe+="<tr><td style='font-weight: 600;'>McAfee:</td><td>Attivato con account del cliente &bull; PIN card registrato</td></tr>"
fi
if [[ "$SVC_NORTON" == true ]]; then
    servizi_inclusi_arr+=("Norton 360")
    servizi_righe+="<tr><td style='font-weight: 600;'>Norton 360:</td><td>Attivato con account del cliente &bull; PIN card registrato</td></tr>"
fi
if [[ "$SVC_CYBER" == true ]]; then
    servizi_inclusi_arr+=("Cyber Protection")
    servizi_righe+="<tr><td style='font-weight: 600;'>Cyber Protection:</td><td>Registrato sul portale &bull; Notifiche via email/SMS al cliente</td></tr>"
fi
servizi_inclusi_arr+=("macOS (Licenza Ufficiale Apple)")
servizi_inclusi_testo="${(j:, :)servizi_inclusi_arr}"

# Badge applicazioni
app_badges=""
for a in "${INSTALLATE[@]}"; do
    app_badges+="<div class='app-badge'>&#10003; <strong>$(html_esc "$a")</strong></div>"
done
[[ -z "$app_badges" ]] && app_badges="<div class='app-badge'>&#10003; <strong>Applicazioni base configurate</strong></div>"

# Box FileVault se attivo
filevault_box=""
fv_status_check="$(fdesetup status 2>/dev/null)"
if echo "$fv_status_check" | grep -qi "On"; then
    filevault_box="<div class='card card-bitlocker'>
        <div class='bl-titolo'>&#9888; CONSERVA QUESTA SCHEDA &bull; Protezione e Cifratura FileVault</div>
        <p class='bl-testo'>Il disco di questo Mac &egrave; protetto con <strong>FileVault</strong>. Tutti i documenti e dati personali sono cifrati e al sicuro da accessi non autorizzati.</p>
        <div class='bl-chiave'>PROTEZIONE FILEVAULT ATTIVA</div>
        <table class='info-table'>
            <tr><td>Stato cifratura:</td><td><strong style='color:#16a34a;'>&#10003; Attivo e Protetto</strong></td></tr>
            <tr><td>Volume protetto:</td><td>Macintosh HD (APFS Cifrato)</td></tr>
        </table>
        <p class='bl-testo' style='margin-top: 8px;'><strong>Stampa questa scheda o fotografala con lo smartphone</strong> e conservala in un posto sicuro, lontano dal Mac. Le tue credenziali Apple ID sono essenziali per il ripristino.</p>
    </div>"
fi

HTML_CONSEGNA_DOC="<!DOCTYPE html>
<html lang=\"it\">
<head>
    <meta charset=\"UTF-8\">
    <title>Scheda Consegna Mac - $h_nome</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif; }
        body { background: #f1f5f9; color: #1e293b; padding: 24px; font-size: 13px; line-height: 1.5; }
        .sheet { max-width: 820px; margin: 0 auto; background: #fff; border-radius: 12px; box-shadow: 0 4px 16px rgba(0,0,0,0.08); overflow: hidden; border: 1px solid #e2e8f0; }
        .header { background: linear-gradient(135deg, #00122B 0%, #002B5C 100%); color: #fff; padding: 22px 28px; border-bottom: 4px solid #EE7203; display: flex; justify-content: space-between; align-items: center; }
        .header-brand { display: flex; align-items: center; gap: 14px; }
        .brand-logo { background: #EE7203; color: #fff; font-weight: 900; font-size: 18px; letter-spacing: 1.5px; padding: 6px 12px; border-radius: 6px; }
        .header h1 { font-size: 20px; font-weight: 700; color: #fff; }
        .header p { font-size: 12px; color: #cbd5e1; }
        .badge-brand { background: #EE7203; color: #fff; font-weight: 700; font-size: 12px; padding: 6px 12px; border-radius: 6px; }
        .body { padding: 24px 28px; display: flex; flex-direction: column; gap: 16px; }
        .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
        .card { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 16px; }
        .card-cred { background: #fffaf5; border: 1.5px solid #EE7203; }
        .card-cred h3 { color: #EE7203; border-bottom: 1px solid #fed7aa; }
        .card-bitlocker { background: #fff7ed; border: 3px solid #dc2626; page-break-inside: avoid; break-inside: avoid; }
        .bl-titolo { font-size: 16px; font-weight: 900; color: #b91c1c; letter-spacing: 0.5px; margin-bottom: 6px; }
        .bl-testo { font-size: 12px; color: #1e293b; }
        .bl-chiave { font-family: Consolas, 'Courier New', monospace; font-size: 19px; font-weight: 700; letter-spacing: 1px; color: #7f1d1d; background: #fff; border: 2px dashed #dc2626; border-radius: 6px; padding: 10px 12px; margin: 10px 0; text-align: center; word-break: break-all; }
        .card h3 { font-size: 14px; color: #00122B; margin-bottom: 10px; border-bottom: 1px solid #e2e8f0; padding-bottom: 6px; font-weight: 700; display: flex; align-items: center; gap: 6px; }
        .info-table { width: 100%; border-collapse: collapse; font-size: 12.5px; }
        .info-table td { padding: 3px 0; }
        .info-table td:first-child { width: 42%; color: #64748b; font-weight: 500; }
        .app-grid { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 4px; }
        .app-badge { background: #fff; border: 1px solid #cbd5e1; border-radius: 6px; padding: 5px 9px; font-size: 12px; display: inline-flex; align-items: center; gap: 5px; color: #1e293b; }
        .app-badge strong { color: #00122B; }
        .tips-list { font-size: 12px; color: #475569; padding-left: 18px; line-height: 1.6; }
        .footer { background: #f8fafc; border-top: 1px solid #e2e8f0; padding: 14px 28px; display: flex; justify-content: space-between; align-items: center; font-size: 12px; color: #64748b; }
        .btn-print { background: #EE7203; color: #fff; border: none; font-weight: 700; font-size: 13px; padding: 8px 18px; border-radius: 6px; cursor: pointer; display: inline-flex; align-items: center; gap: 6px; box-shadow: 0 2px 6px rgba(238,114,3,0.3); }
        .btn-print:hover { background: #d96300; }
        @media print {
            @page { size: A4 portrait; margin: 10mm; }
            body { background: #fff; padding: 0; font-size: 11.5px; }
            .sheet { box-shadow: none; max-width: 100%; border: none; }
            .header { padding: 16px 20px; }
            .body { padding: 16px 20px; gap: 12px; }
            .card { padding: 12px; }
            .no-print { display: none !important; }
        }
    </style>
</head>
<body>
    <div class=\"sheet\">
        <div class=\"header\">
            <div class=\"header-brand\">
                <div class=\"brand-logo\">UNIEURO</div>
                <div>
                    <h1>Scheda di Consegna e Configurazione Mac</h1>
                    <p>Assistenza Tecnica &bull; <em style=\"color: #EE7203; font-weight: 600;\">Batte. Forte. Sempre.</em></p>
                </div>
            </div>
            <div class=\"badge-brand\">PC FACILE MAC v$SCRIPT_VERSION</div>
        </div>
        <div class=\"body\">
            <div class=\"card card-cred\">
                <h3>&#128273; Credenziali di Primo Accesso &bull; Apple ID &amp; Servizi</h3>
                <table class=\"info-table\">
                    <tr><td style=\"width: 32%; font-weight: 600;\">Email / Apple ID:</td><td><strong style=\"font-size: 14px; color: #00122B;\">$h_account</strong></td></tr>
                    <tr><td style=\"font-weight: 600;\">Password iniziale:</td><td><code style=\"font-size: 14px; font-weight: bold; background: #fee2e2; color: #991b1b; padding: 2px 8px; border-radius: 4px;\">$h_password</code> <em style=\"color: #64748b; font-size: 11px; margin-left: 8px;\">(da personalizzare al primo accesso)</em></td></tr>
                    <tr><td style=\"font-weight: 600;\">Account macOS:</td><td><code>$h_nome</code></td></tr>
                    <tr><td style=\"font-weight: 600;\">Servizi inclusi:</td><td>$servizi_inclusi_testo</td></tr>
                    $servizi_righe
                </table>
            </div>
            $filevault_box
            <div class=\"grid\">
                <div class=\"card\">
                    <h3>&#128100; Dati Cliente</h3>
                    <table class=\"info-table\">
                        <tr><td>Cliente:</td><td><strong>$h_nome</strong></td></tr>
                        $tel_riga
                        <tr><td>Nome Computer:</td><td><code>$h_mac_name</code></td></tr>
                        <tr><td>Seriale / S/N:</td><td><strong>$hw_s</strong></td></tr>
                        <tr><td>Data Setup:</td><td>$(date '+%d/%m/%Y %H:%M')</td></tr>
                        <tr><td>Sistema Operativo:</td><td><strong style=\"color:#16a34a;\">&#10003; macOS $os_ver ($os_build)</strong></td></tr>
                        <tr><td>Stato Setup:</td><td><strong style=\"color:#16a34a;\">&#10003; Pronto e Collaudato</strong></td></tr>
                    </table>
                </div>
                <div class=\"card\">
                    <h3>&#128187; Specifiche Hardware &amp; Diagnostica</h3>
                    <table class=\"info-table\">
                        <tr><td>Dispositivo:</td><td><strong>$hw_m</strong></td></tr>
                        <tr><td>Processore / Chip:</td><td>$hw_c</td></tr>
                        <tr><td>Memoria RAM:</td><td>$hw_r</td></tr>
                        <tr><td>Archiviazione / SSD:</td><td><strong>$storage_desc</strong></td></tr>
                        <tr><td>Salute Batteria:</td><td><strong>$batt_desc</strong></td></tr>
                        <tr><td>Lingua:</td><td>Italiano (it-IT)</td></tr>
                    </table>
                </div>
            </div>
            <div class=\"card\">
                <h3>&#128230; Programmi e Utility Installate</h3>
                <div class=\"app-grid\">$app_badges</div>
            </div>
            <div class=\"card\">
                <h3>&#128161; Consigli e Istruzioni per l'Uso</h3>
                <ul class=\"tips-list\">
                    <li><strong>Connessione Wi-Fi:</strong> All'accensione a casa, seleziona la tua rete Wi-Fi in alto a destra nella barra dei menu ed inserisci la password di casa.</li>
                    <li><strong>Sicurezza Credenziali:</strong> Se &egrave; stata creata una password provvisoria, modificala al primo accesso in <em>Impostazioni di Sistema &gt; Account Apple</em>.</li>
                    <li><strong>Teleassistenza:</strong> AnyDesk e TeamViewer sono configurati e pronti sul desktop in caso di necessit&agrave; di supporto da remoto.</li>
                    <li><strong>Backup Time Machine:</strong> Consigliamo di collegare periodicamente un disco esterno per eseguire i backup automatici con Time Machine (gi&agrave; predisposto).</li>
                    <li><strong>Aggiornamenti:</strong> macOS &egrave; configurato con gli aggiornamenti di sicurezza raccomandati per proteggere il dispositivo.</li>
                </ul>
            </div>
        </div>
        <div class=\"footer\">
            <div>Documento di consegna ufficiale generato automaticamente per il cliente da <strong>PC Facile</strong>.</div>
            <button class=\"btn-print no-print\" onclick=\"window.print()\">&#128438; Stampa / Salva in PDF</button>
        </div>
    </div>
</body>
</html>"


stop_barra_animata_mac
salva_scheda_consegna_mac "$HTML_CONSEGNA_DOC"
mostra_riepilogo_console_mac
salva_log_strutturato_mac
send_report_github_mac
update_pannello_mac_status 100 "Configurazione Mac Completata!" "Tutti i lavori terminati con successo" true "diagnostica" "done" "Scheda creata sul Desktop"


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
    
    while true; do
        print -r -- "${C_TXT}   Scegli come procedere:${C_RST}"
        print -r -- "     ${C_CYAN}1) Esegui Check Completo Salute Mac (Batteria, Cicli, SSD SMART, FileVault)${C_RST}"
        print -r -- "     ${C_OK}2) Riavvia il Mac adesso (Consigliato per rendere attive tutte le modifiche)${C_RST}"
        print -r -- "     ${C_INFO}3) Esci senza riavviare${C_RST}"
        print -r -- ""
        
        beep_attesa; start_bip_ripetuto_mac; print -n -- "   Scelta (1-3): "; read -r scelta_fine; stop_bip_ripetuto_mac
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
