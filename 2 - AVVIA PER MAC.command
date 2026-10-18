#!/bin/zsh
# =============================================================================
# PC Facile.command - launcher doppio-click per setup-mac.sh (macOS)
# Gemello di "PC Facile.bat". Scarica SEMPRE l'ultima versione da GitHub e la
# esegue solo se il suo SHA256 combacia con setup-mac.sh.sha256; altrimenti usa
# la copia accanto (fallback offline). Doppio-click dal Finder.
# =============================================================================
cd "$(dirname "$0")" || exit 1

# Sblocca automaticamente la cartella ed elimina l'avviso "malware" / quarantena di macOS Gatekeeper
xattr -d com.apple.quarantine "$0" 2>/dev/null || true
xattr -cr . 2>/dev/null || true

# Auto-connessione Wi-Fi Negozio (se non ancora connesso a Internet)
connetti_wifi_launcher_mac() {
    (curl -s --head --max-time 3 https://www.apple.com >/dev/null 2>&1 || ping -c1 -t2 8.8.8.8 >/dev/null 2>&1) && return 0

    local ssid="UNIEURO_EXPO"
    local pass="W1f1@Un13uro"
    local f_wifi=""
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

    local wdev
    wdev="$(networksetup -listallhardwareports 2>/dev/null | awk '/Hardware Port: Wi-Fi/{getline; print $2}')"
    if [[ -z "$wdev" ]]; then
        wdev="$(networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi/{getline; print $2}')"
    fi

    if [[ -n "$wdev" ]]; then
        echo "Connessione automatica al Wi-Fi del negozio ($ssid)..."
        networksetup -setairportpower "$wdev" on 2>/dev/null
        networksetup -setairportnetwork "$wdev" "$ssid" "$pass" 2>/dev/null
        for ((i=0; i<8; i++)); do
            sleep 1
            if curl -s --head --max-time 2 https://www.apple.com >/dev/null 2>&1 || ping -c1 -t2 8.8.8.8 >/dev/null 2>&1; then
                echo "  [OK] Connesso alla rete Wi-Fi: $ssid"
                return 0
            fi
        done
    fi
}
connetti_wifi_launcher_mac

BASE="https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/feat/mac-full-parity-and-progress-bars"
BASE_MAIN="https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main"
BASE_CDN="https://cdn.jsdelivr.net/gh/samuelenigro97-prog/pc-facile@main"
# File temporaneo univoco (mktemp), non un percorso fisso e prevedibile in /tmp.
TMP="$(mktemp -t setup-mac.XXXXXX)" || { echo "Impossibile creare un file temporaneo."; exit 1; }
trap 'rm -f -- "$TMP"' EXIT

scarica_verificato() {
    local t atteso reale base
    t="$(date +%s)"
    for base in "$BASE" "$BASE_MAIN" "$BASE_CDN"; do
        if curl -fsSL "$base/setup-mac.sh?t=$t" -o "$TMP" 2>/dev/null; then
            xattr -d com.apple.quarantine "$TMP" 2>/dev/null || true
            chmod +x "$TMP" 2>/dev/null || true
            atteso="$(curl -fsSL "$base/setup-mac.sh.sha256?t=$t" 2>/dev/null | awk '{print tolower($1); exit}')"
            reale="$(shasum -a 256 "$TMP" 2>/dev/null | awk '{print tolower($1)}')"
            if [[ "$atteso" =~ '^[0-9a-f]{64}$' && "$reale" == "$atteso" ]]; then
                return 0
            fi
        fi
    done
    return 1
}

# Aggiornamento automatico della chiavetta: scarica manifest.txt e ogni file
# elencato (raw, poi jsDelivr), ne verifica lo SHA256 e solo allora sostituisce
# la copia accanto (file temporaneo + mv, atomico). In wifi/ scrive solo
# wifi.txt e UNIEURO_EXPO.xml (se elencati nel manifest). Se qualcosa fallisce restano i file attuali. Il manifest arriva
# dallo stesso posto dei file: protegge da corruzioni, non da manomissioni.
# Su macOS mv sostituisce il file (nuovo inode): anche questo .command, pur in
# esecuzione, si aggiorna senza problemi.
aggiorna_chiavetta() {
    # Solo se questa e' una cartella PC Facile (chiavetta o copia offline).
    [[ -f "./setup-mac.sh" || -f "./setup-pc.ps1" || "$PWD" == /Volumes/* || "${PWD:t}" == *"PC Facile"* || "${PWD:t}" == *"pc facile"* ]] || return 0
    local man t riga hash nome dest tmpf base url ok
    man="$(mktemp -t pcf-manifest.XXXXXX)" || return 0
    t="$(date +%s)"
    for base in "$BASE" "$BASE_MAIN" "$BASE_CDN"; do
        if curl -fsSL "$base/manifest.txt?t=$t" -o "$man" 2>/dev/null; then
            break
        fi
    done
    if [[ ! -s "$man" ]]; then
        rm -f -- "$man"; echo "Aggiornamento chiavetta saltato (manifest non raggiungibile)."; return 0
    fi
    echo "Aggiorno i file della chiavetta (manifest.txt)..."
    while IFS= read -r riga || [[ -n "$riga" ]]; do
        riga="${riga%$'\r'}"
        [[ -z "$riga" || "$riga" == \#* ]] && continue
        [[ "$riga" =~ '^[0-9a-fA-F]{64} [ *].+$' ]] || continue
        hash="${(L)riga[1,64]}"
        nome="${riga[67,-1]}"
        # Percorsi sicuri soltanto: niente assoluti, "..", ":"; in wifi/ solo i file Wi-Fi previsti.
        [[ "$nome" == /* || "$nome" == *..* || "$nome" == *:* ]] && continue
        if [[ "${(L)nome}" == wifi/* && "${(L)nome}" != "wifi/wifi.txt" && "${(L)nome}" != "wifi/unieuro_expo.xml" ]]; then continue; fi
        dest="./$nome"
        if [[ -f "$dest" && "$(shasum -a 256 "$dest" 2>/dev/null | awk '{print tolower($1)}')" == "$hash" ]]; then
            continue
        fi
        mkdir -p -- "$(dirname -- "$dest")" 2>/dev/null
        tmpf="$dest.pcfacile-tmp"
        ok=false
        for base in "$BASE" "$BASE_MAIN" "$BASE_CDN"; do
            url="$base/${nome// /%20}?t=$t"
            if curl -fsSL "$url" -o "$tmpf" 2>/dev/null &&
               [[ "$(shasum -a 256 "$tmpf" 2>/dev/null | awk '{print tolower($1)}')" == "$hash" ]]; then
                ok=true; break
            fi
        done
        if $ok; then
            [[ "$nome" == *.command || "$nome" == *.sh ]] && chmod +x "$tmpf" 2>/dev/null
            xattr -d com.apple.quarantine "$tmpf" 2>/dev/null || true
            if mv -f -- "$tmpf" "$dest" 2>/dev/null; then echo "  aggiornato: $nome"; else rm -f -- "$tmpf"; fi
        else
            rm -f -- "$tmpf"
            echo "  non aggiornato (download o verifica SHA256 non riusciti): $nome"
        fi
    done < "$man"
    rm -f -- "$man"
}

# --- Rilevamento file preinstallati su chiavetta USB o cartella locale ---
SCRIPT_LOCALE=""
if [[ "$1" == "--aggiorna" || "$1" == "-u" ]]; then
    SCRIPT_LOCALE=""
elif [[ -f "./setup-mac.sh" ]]; then
    SCRIPT_LOCALE="./setup-mac.sh"
else
    for v in /Volumes/*; do
        if [[ -f "$v/setup-mac.sh" ]]; then
            SCRIPT_LOCALE="$v/setup-mac.sh"
            break
        elif [[ -f "$v/PC Facile/setup-mac.sh" ]]; then
            SCRIPT_LOCALE="$v/PC Facile/setup-mac.sh"
            break
        elif [[ -f "$v/PC-Facile-Kit-USB/setup-mac.sh" ]]; then
            SCRIPT_LOCALE="$v/PC-Facile-Kit-USB/setup-mac.sh"
            break
        fi
    done
fi

if [[ -n "$SCRIPT_LOCALE" ]]; then
    ver_script=""
    if grep -q 'SCRIPT_VERSION=' "$SCRIPT_LOCALE" 2>/dev/null; then
        ver_script="$(grep 'SCRIPT_VERSION=' "$SCRIPT_LOCALE" | head -n1 | cut -d'"' -f2)"
    fi
    echo "============================================================"
    echo "  PC FACILE MAC - File preinstallati trovati su chiavetta!"
    echo "  Posizione: $SCRIPT_LOCALE"
    [[ -n "$ver_script" ]] && echo "  Versione:  v$ver_script"
    echo "  Tutti i file sono gia' presenti: nessun download eseguito."
    echo "  Avvio immediato della configurazione..."
    echo "============================================================"
    chmod +x "$SCRIPT_LOCALE" 2>/dev/null || true
    xattr -d com.apple.quarantine "$SCRIPT_LOCALE" 2>/dev/null || true
    zsh "$SCRIPT_LOCALE"
elif scarica_verificato; then
    echo "Configuro e scarico automaticamente tutti i file nella chiavetta (SHA256)..."
    aggiorna_chiavetta
    if [[ -f "./setup-mac.sh" ]]; then
        zsh "./setup-mac.sh"
    else
        zsh "$TMP"
    fi
else
    echo "Impossibile scaricare o verificare lo script e nessuna copia locale su chiavetta: controlla la rete."
fi

echo ""
echo "============================================================"
echo "  Operazione terminata. Premi INVIO per chiudere."
echo "============================================================"
read -r _
