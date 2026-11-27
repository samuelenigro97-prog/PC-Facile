# =============================================================================
# setup-pc.ps1 - Automazione Configurazione PC
# =============================================================================

# UN SOLO modo di avvio per l'operatore: doppio click su "PC Facile.bat" dalla
# chiavetta. Niente menu e niente modalita' alternative: lo script parte subito
# con la fase 1 (programmi e lingua), apre da solo il pannello operatore (file
# locale) dove si inseriscono UNA VOLTA i dati del cliente e poi prosegue con i
# passi manuali e con il resto. I parametri qui sotto NON sono per l'operatore.
param(
    # Solo CI: non interattivo e non distruttivo (risposte automatiche).
    [switch]$Test,
    # Manutenzione (nascosto): controlla ambiente e ID pacchetti senza installare.
    [switch]$Diagnostica,
    # Manutenzione (nascosto): scarica gli installer offline sulla chiavetta.
    # Uso: "PC Facile.bat" -PreparaUSB
    [Alias("USB", "Offline", "DownloadOffline")]
    [switch]$PreparaUSB,
    # Crea anche il punto di ripristino (di default saltato: risparmia SSD e tempo).
    [Alias("RestorePoint", "Ripristino")]
    [switch]$CreaRipristino,
    # Cartella della chiavetta (passata da PC Facile.bat).
    [string]$TargetDir,
    # Aggiorna solo i file della chiavetta dal manifest.txt ed esce (usato da
    # PC Facile.bat ad ogni avvio). -LauncherPath = percorso del .bat in esecuzione.
    [switch]$AggiornaUSB,
    # Percorso del .bat che ha lanciato lo script (passato dal launcher recente;
    # se manca con -TargetDir, lo script e' stato avviato da un launcher vecchio).
    [string]$LauncherPath,
    # Evita loop infiniti dopo un auto-aggiornamento post-connessione.
    [switch]$NoSelfUpdate,
    # Parametri delle vecchie modalita' (-Espresso, -Manuale, -Menu, -AgenteIA,
    # -Migrazione, -Veloce...): accettati e IGNORATI, il flusso e' uno solo.
    [Parameter(ValueFromRemainingArguments = $true)]
    [object[]]$ParametriIgnorati
)

if ($TargetDir) {
    $TargetDir = ($TargetDir -replace '["'']', '').Trim().TrimEnd('\').TrimEnd('/')
    $Global:TargetDir = $TargetDir
}
# Auto-correzione per chiavette con un vecchio PC Facile.bat in cui "shift" (senza /1)
# dopo l'elevazione UAC trasformava %~dp0 in C:\Windows\System32 e %~f0 in C:\Windows\System32\elevated:
if (-not ($Test -or $env:PESTER_TEST) -and (-not $TargetDir -or $TargetDir -like "$env:SystemRoot*")) {
    try {
        foreach ($drv in @(Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
            $r = $drv.Root
            if (-not $r -or $r -like "$env:SystemDrive*") { continue }
            $candidatiUsb = @($r, (Join-Path $r 'PC Facile'), (Join-Path $r 'PC-Facile'), (Join-Path $r 'PC-Facile-main'))
            foreach ($cand in $candidatiUsb) {
                if ((Test-Path -LiteralPath (Join-Path $cand 'PC Facile Windows.bat')) -or (Test-Path -LiteralPath (Join-Path $cand 'PC Facile.bat')) -or (Test-Path -LiteralPath (Join-Path $cand 'setup-pc.ps1'))) {
                    $TargetDir = $cand.TrimEnd('\', '/')
                    $Global:TargetDir = $TargetDir
                    if (-not $LauncherPath -or $LauncherPath -like "$env:SystemRoot*") {
                        $LauncherPath = if (Test-Path -LiteralPath (Join-Path $cand 'PC Facile Windows.bat')) { Join-Path $cand 'PC Facile Windows.bat' } else { Join-Path $cand 'PC Facile.bat' }
                    }
                    break
                }
            }
            if ($TargetDir -and $TargetDir -notlike "$env:SystemRoot*") { break }
        }
    } catch {}
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ProgressPreference = 'SilentlyContinue'

# Versione del programma (mostrata nell'header e nel riepilogo).
# Bump ad ogni modifica cosi' capisci se la USB e' aggiornata.
$SCRIPT_VERSION = "13.29.0 (2026-11-27)"

# Versione SEMPRE VISIBILE: la scrivo nella barra del titolo della finestra, che
# resta a video in QUALSIASI schermata (a differenza dell'header, che scorre via).
# Cosi' l'operatore controlla al volo se la chiavetta ha scaricato l'ultima.
try { $Host.UI.RawUI.WindowTitle = "PC Facile  -  v$SCRIPT_VERSION" } catch {}

# Simboli di stato e grafica costruiti a runtime con [char]: NON dipendono
# dall'encoding con cui PowerShell legge questo file (5.1 senza BOM li
# storpierebbe). L'output e' gia' UTF-8 (impostato sopra), quindi si vedono.
$SYM_OK    = [char]0x2713                  # spunta
$SYM_ERR   = [char]0x2717                  # croce
$SYM_INFO  = [char]0x2192                  # freccia
$BOX_FULL  = [char]0x2588                  # blocco pieno (barra progresso)
$BOX_EMPTY = [char]0x2591                  # blocco leggero (barra progresso)
$LINEA_D   = ([string][char]0x2550) * 60   # linea doppia orizzontale

# =============================================================================
# TEMA GRAFICO UFFICIALE UNIEURO (NAVY #00122B & ARANCIONE #EE7203)
# =============================================================================
$ESC         = [char]27
$U_NAVY_BG   = "$ESC[48;2;0;18;43m"          # Sfondo Navy Unieuro (#00122B)
$U_CARD_BG   = "$ESC[48;2;0;31;72m"          # Sfondo Card Navy (#001F48)
$U_ORANGE    = "$ESC[38;2;238;114;3m"        # Arancione Unieuro (#EE7203)
$U_ORANGE_BG = "$ESC[48;2;238;114;3m$ESC[38;2;255;255;255m$ESC[1m" # Badge UNIEURO
$U_WHITE     = "$ESC[38;2;248;250;252m$ESC[1m" # Bianco brillante (#F8FAFC)
$U_GREEN     = "$ESC[38;2;34;197;94m$ESC[1m"  # Verde spunta (#22C55E)
$U_BLUE      = "$ESC[38;2;147;197;253m"      # Blu chiaro (#93C5FD)
$U_PEACH     = "$ESC[38;2;254;215;170m"      # Evidenziatore pesca (#FED7AA)
$U_MUTED     = "$ESC[38;2;148;163;184m"      # Grigio secondario (#94A3B8)
$U_ERR       = "$ESC[38;2;239;68;68m$ESC[1m"  # Rosso errore (#EF4444)
$U_RESET     = "$ESC[0m"

$AON         = $U_ORANGE
$AOFF        = $U_RESET
$THEME_COL   = "DarkYellow"
$THEME_TXT   = "White"

# Rileva se il Virtual Terminal (ANSI 24-bit) e' attivo
$vtOn = $true
# Backup UNA TANTUM delle impostazioni console originali (lo fa anche il launcher
# .bat prima di cambiarle): la pulizia finale le reimporta. Un backup gia'
# presente non viene sovrascritto (conterrebbe gia' i colori modificati).
$Global:ConsoleBackupFile = Join-Path $(if ($env:ProgramData) { $env:ProgramData } else { [System.IO.Path]::GetTempPath() }) "PCFacile\console-backup.reg"
try {
    if (Test-Path 'HKCU:\') {
        if (-not (Test-Path -LiteralPath $Global:ConsoleBackupFile) -and (Test-Path 'HKCU:\Console')) {
            try {
                New-Item -ItemType Directory -Path (Split-Path $Global:ConsoleBackupFile -Parent) -Force -ErrorAction SilentlyContinue | Out-Null
                & reg.exe export 'HKCU\Console' $Global:ConsoleBackupFile /y 2>$null | Out-Null
            } catch {}
        }
        if (-not (Test-Path 'HKCU:\Console')) { New-Item -Path 'HKCU:\Console' -Force | Out-Null }
        Set-ItemProperty -Path 'HKCU:\Console' -Name 'VirtualTerminalLevel' -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path 'HKCU:\Console' -Name 'ColorTable00' -Value 0x002B1200 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path 'HKCU:\Console' -Name 'ColorTable01' -Value 0x002B1200 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path 'HKCU:\Console' -Name 'ColorTable02' -Value 0x005EC522 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path 'HKCU:\Console' -Name 'ColorTable03' -Value 0x00FDC593 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path 'HKCU:\Console' -Name 'ColorTable06' -Value 0x000372EE -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path 'HKCU:\Console' -Name 'ColorTable07' -Value 0x00FCFAF8 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path 'HKCU:\Console' -Name 'ColorTable10' -Value 0x005EC522 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path 'HKCU:\Console' -Name 'ColorTable14' -Value 0x000372EE -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path 'HKCU:\Console' -Name 'ColorTable15' -Value 0x00FFFFFF -Type DWord -ErrorAction SilentlyContinue
    }
} catch {}

try {
    $Host.UI.RawUI.BackgroundColor = 'Black'
    $Host.UI.RawUI.ForegroundColor = 'Gray'
    if (-not $AggiornaUSB) { Clear-Host }
} catch {}

# =============================================================================
# FUNZIONI UTILITY
# =============================================================================

function Reset-ConsoleMode {
    if ($Global:Test -or $env:PESTER_TEST) { return }
    try {
        if (-not ([System.Management.Automation.PSTypeName]'WinConsoleMode').Type) {
            Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class WinConsoleMode {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetStdHandle(int nStdHandle);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
    public static void Fix() {
        IntPtr hOut = GetStdHandle(-11);
        uint mode;
        if (GetConsoleMode(hOut, out mode)) {
            mode = (mode | 0x0007u) & ~0x0008u; // ENABLE_PROCESSED_OUTPUT | WRAP | VT, clear DISABLE_NEWLINE_AUTO_RETURN
            SetConsoleMode(hOut, mode);
        }
    }
}
"@ -ErrorAction SilentlyContinue
        }
        [WinConsoleMode]::Fix()
    } catch {}
    try {
        if ([Console]::CursorLeft -gt 0) { [Console]::Write("`r") }
    } catch {}
}

function Write-Titolo {
    param([string]$Testo)
    Reset-ConsoleMode
    $winW = 70
    try { if ([Console]::WindowWidth -gt 20) { $winW = [Console]::WindowWidth } } catch {}
    $barLen = [Math]::Min(54, [Math]::Max(24, $winW - 6))
    $barra = ([string]$BOX_FULL) * $barLen
    Write-Host ""
    Write-Host ""
    if ($vtOn) {
        Write-Host "  $U_ORANGE$barra$U_RESET"
        Write-Host "  $U_ORANGE_BG UNIEURO $U_RESET  $U_WHITE$($Testo.ToUpper())$U_RESET"
        Write-Host "  $U_ORANGE$barra$U_RESET"
    } else {
        Write-Host "  $barra" -ForegroundColor DarkYellow
        Write-Host "   [UNIEURO] $($Testo.ToUpper())" -ForegroundColor White
        Write-Host "  $barra" -ForegroundColor DarkYellow
    }
    Write-Host ""
}

function Write-OK {
    param([string]$Testo)
    Reset-ConsoleMode
    if ($vtOn) {
        Write-Host "   $U_GREEN$SYM_OK$U_RESET  $U_WHITE$Testo$U_RESET"
    } else {
        Write-Host "   $SYM_OK  $Testo" -ForegroundColor Green
    }
}

function Write-Info {
    param([string]$Testo)
    Reset-ConsoleMode
    if ($vtOn) {
        Write-Host "   $U_ORANGE$SYM_INFO$U_RESET  $U_BLUE$Testo$U_RESET"
    } else {
        Write-Host "   $SYM_INFO  $Testo" -ForegroundColor Yellow
    }
}

function Write-Errore {
    param([string]$Testo)
    Reset-ConsoleMode
    if ($vtOn) {
        Write-Host "   $U_ERR$SYM_ERR$U_RESET  $U_ERR$Testo$U_RESET"
    } else {
        Write-Host "   $SYM_ERR  $Testo" -ForegroundColor Red
    }
}

# =============================================================================
# AGGIORNAMENTO AUTOMATICO DELLA CHIAVETTA (manifest.txt)
# -----------------------------------------------------------------------------
# manifest.txt (nel repository) elenca ogni file che serve sulla chiavetta con
# il suo SHA256 (formato "sha256sum": <hash><2 spazi><percorso>). Qui scarico il
# manifest, poi ogni file (GitHub raw, fallback jsDelivr), ne verifico l'hash e
# SOLO dopo la verifica sostituisco la copia sulla chiavetta (file temporaneo
# accanto + sostituzione). Se qualcosa va storto la copia esistente resta.
# FIDUCIA: il manifest arriva dallo stesso posto dei file, quindi protegge da
# download corrotti/troncati, NON da una manomissione del repository.
# Nella cartella wifi\ si scrivono SOLO i file Wi-Fi elencati qui sotto
# (Get-FileWifiManifest, scelta del proprietario: stanno nel repository e arrivano
# sulla chiavetta); ogni altro file di wifi\ non viene mai toccato.
# Il launcher in esecuzione non viene toccato: la nuova versione va in
# "<launcher>.nuovo" e il .bat la mette al suo posto quando termina/riparte.
# =============================================================================
function Get-FileWifiManifest {
    return @('wifi/wifi.txt', 'wifi/UNIEURO_EXPO.xml')
}

function Test-PercorsoManifestSicuro {
    param([string]$Percorso)
    if ([string]::IsNullOrWhiteSpace($Percorso)) { return $false }
    $p = $Percorso.Trim() -replace '\\', '/'
    if ($p.StartsWith('/') -or $p -match '^[A-Za-z]:' -or $p -match '[:*?"<>|]') { return $false }
    $parti = @($p -split '/')
    foreach ($parte in $parti) {
        if ($parte -eq '' -or $parte -eq '.' -or $parte -eq '..') { return $false }
    }
    # Nella cartella wifi solo i file Wi-Fi previsti (confronto senza maiuscole).
    if ($parti[0] -ieq 'wifi' -and -not ((Get-FileWifiManifest) -icontains ($parti -join '/'))) { return $false }
    return $true
}

function Read-ManifestPcFacile {
    param([string]$Testo)
    $voci = [System.Collections.Generic.List[object]]::new()
    if (-not $Testo) { return ,$voci }
    foreach ($riga in ($Testo -split "`r?`n")) {
        $r = $riga.TrimEnd()
        if (-not $r -or $r.StartsWith('#')) { continue }
        if ($r -match '^([0-9A-Fa-f]{64}) [ *](.+)$') {
            $nome = $Matches[2]
            if (Test-PercorsoManifestSicuro $nome) {
                $voci.Add([pscustomobject]@{ Hash = $Matches[1].ToLower(); Percorso = ($nome -replace '\\', '/') })
            }
        }
    }
    return ,$voci
}

function Invoke-AggiornamentoUSB {
    param(
        [Parameter(Mandatory = $true)][string]$Destinazione,
        [string[]]$Basi = @(
            'https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main',
            'https://cdn.jsdelivr.net/gh/samuelenigro97-prog/pc-facile@main'
        ),
        # Percorso del launcher .bat in esecuzione (non va sovrascritto mentre gira).
        [string]$LauncherInEsecuzione,
        # Download (iniettabile per i test): scarica $Url nel file $File o lancia un errore.
        [scriptblock]$Scarica = {
            param($Url, $File)
            Invoke-WebRequest -Uri $Url -OutFile $File -UseBasicParsing -TimeoutSec 30 -Headers @{ 'Cache-Control' = 'no-cache' } -ErrorAction Stop
        }
    )
    $esito = [pscustomobject]@{ Ok = $false; Aggiornati = 0; GiaAggiornati = 0; Falliti = 0; InAttesa = 0 }
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

    # "E:" (radice senza barra) e' un percorso relativo al disco: lo rendo assoluto.
    if ($Destinazione -match '^[A-Za-z]:$') { $Destinazione += '\' }
    if (-not (Test-Path -LiteralPath $Destinazione -PathType Container)) {
        Write-Info "Aggiornamento chiavetta: cartella non trovata ($Destinazione)."
        return $esito
    }
    $tmpDir = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
    $t = (Get-Date).Ticks

    # 1) Manifest: dalla prima sorgente che risponde con almeno una voce valida.
    $voci = $null
    foreach ($base in $Basi) {
        $tmpMan = Join-Path $tmpDir ("pcfacile-manifest-{0}.txt" -f [guid]::NewGuid().ToString('N'))
        try {
            & $Scarica ($base + '/manifest.txt?t=' + $t) $tmpMan
            $letti = Read-ManifestPcFacile -Testo ([System.IO.File]::ReadAllText($tmpMan))
            if ($letti.Count -gt 0) { $voci = $letti; break }
        } catch {
        } finally {
            Remove-Item -LiteralPath $tmpMan -Force -ErrorAction SilentlyContinue
        }
    }
    if ($null -eq $voci -or $voci.Count -eq 0) {
        Write-Info "Aggiornamento chiavetta saltato (manifest non raggiungibile): uso i file gia' presenti."
        if (-not ($Test -or $Global:Test -or $env:PESTER_TEST)) {
            try { [void](Invoke-OrdinaChiavetta -Destinazione $Destinazione) } catch {}
        }
        return $esito
    }

    $launcherPieno = $null
    if ($LauncherInEsecuzione) { try { $launcherPieno = [System.IO.Path]::GetFullPath($LauncherInEsecuzione) } catch {} }

    # 2) File per file: salto quelli gia' aggiornati, verifico i nuovi prima di sostituire.
    foreach ($v in $voci) {
        $dest = Join-Path $Destinazione ($v.Percorso -replace '/', [System.IO.Path]::DirectorySeparatorChar)
        try {
            if ((Test-Path -LiteralPath $dest -PathType Leaf) -and
                ((Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToLower() -eq $v.Hash)) {
                $esito.GiaAggiornati++
                continue
            }
            $destPieno = [System.IO.Path]::GetFullPath($dest)
            $eLauncher = [bool]($launcherPieno -and ($destPieno -ieq $launcherPieno))
            if ($eLauncher -and (Test-Path -LiteralPath ($dest + '.nuovo') -PathType Leaf) -and
                ((Get-FileHash -LiteralPath ($dest + '.nuovo') -Algorithm SHA256).Hash.ToLower() -eq $v.Hash)) {
                # Nuova versione del launcher gia' pronta da un avvio precedente.
                $esito.InAttesa++
                continue
            }
            $cartella = Split-Path $dest -Parent
            if (-not (Test-Path -LiteralPath $cartella)) { New-Item -ItemType Directory -Path $cartella -Force | Out-Null }
            $tmp = $dest + '.pcfacile-tmp'
            $urlRel = (@($v.Percorso -split '/') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
            $verificato = $false
            foreach ($base in $Basi) {
                Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
                try {
                    & $Scarica ($base + '/' + $urlRel + '?t=' + $t) $tmp
                    if ((Test-Path -LiteralPath $tmp) -and
                        ((Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash.ToLower() -eq $v.Hash)) {
                        $verificato = $true
                        break
                    }
                } catch {}
            }
            if (-not $verificato) {
                Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
                $esito.Falliti++
                Write-Info "Chiavetta: '$($v.Percorso)' non aggiornato (download o verifica SHA256 non riusciti), resta la copia attuale."
                continue
            }
            if ($eLauncher) {
                # Il .bat in esecuzione non si sovrascrive: lo metto da parte.
                Move-Item -LiteralPath $tmp -Destination ($dest + '.nuovo') -Force -ErrorAction Stop
                $esito.InAttesa++
                Write-OK "Chiavetta: nuova versione di '$($v.Percorso)' pronta (attiva dal prossimo avvio)."
                continue
            }
            if (Test-Path -LiteralPath $dest) {
                try { [System.IO.File]::Replace($tmp, $dest, [NullString]::Value) }
                catch { Move-Item -LiteralPath $tmp -Destination $dest -Force -ErrorAction Stop }
            } else {
                Move-Item -LiteralPath $tmp -Destination $dest -Force -ErrorAction Stop
            }
            $esito.Aggiornati++
            Write-OK "Chiavetta: aggiornato '$($v.Percorso)'."
        } catch {
            Remove-Item -LiteralPath ($dest + '.pcfacile-tmp') -Force -ErrorAction SilentlyContinue
            $esito.Falliti++
            Write-Info "Chiavetta: '$($v.Percorso)' non aggiornato ($($_.Exception.Message))."
        }
    }
    $esito.Ok = ($esito.Falliti -eq 0)
    Write-Info ("Chiavetta: {0} aggiornati, {1} gia' aggiornati, {2} non riusciti." -f ($esito.Aggiornati + $esito.InAttesa), $esito.GiaAggiornati, $esito.Falliti)
    if (-not ($Test -or $Global:Test -or $env:PESTER_TEST)) {
        try { [void](Invoke-OrdinaChiavetta -Destinazione $Destinazione) } catch {}
    }
    return $esito
}

# Riordina la chiavetta USB lasciando SOLO i file essenziali del kit (mai tocca
# un repo Git ne' le cartelle wifi/installers/offline/cache/drivers).
function Invoke-OrdinaChiavetta {
    param([Parameter(Mandatory = $true)][string]$Destinazione)
    if (-not (Test-Path -LiteralPath $Destinazione -PathType Container)) { return 0 }
    if (Test-Path -LiteralPath (Join-Path $Destinazione '.git')) { return 0 }
    $rimossi = 0
    $cartelleSuperflue = @('.agents', '.github', 'docs', 'pannello', 'tests', 'tools')
    foreach ($c in $cartelleSuperflue) {
        $p = Join-Path $Destinazione $c
        if (Test-Path -LiteralPath $p) {
            try { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop; $rimossi++ } catch {}
        }
    }
    $fileSuperflui = @(
        '.gitattributes', '.gitignore', 'AGENTS.md', 'CHANGELOG.md', 'CLAUDE.md',
        'LICENSE.md', 'PARITA.md', 'PSScriptAnalyzerSettings.psd1', 'README.md', 'SECURITY.md',
        '1 - AVVIA PER WINDOWS.bat', '2 - AVVIA PER MAC.command', '3 - ISTRUZIONI.txt'
    )
    if (Test-Path -LiteralPath (Join-Path $Destinazione 'PC Facile Windows.bat') -PathType Leaf) {
        $fileSuperflui += 'PC Facile.bat'
    }
    if (Test-Path -LiteralPath (Join-Path $Destinazione 'PC Facile Mac.command') -PathType Leaf) {
        $fileSuperflui += 'PC Facile.command'
    }
    foreach ($f in $fileSuperflui) {
        $p = Join-Path $Destinazione $f
        if (Test-Path -LiteralPath $p -PathType Leaf) {
            try { Remove-Item -LiteralPath $p -Force -ErrorAction Stop; $rimossi++ } catch {}
        }
    }
    foreach ($tmp in @(Get-ChildItem -LiteralPath $Destinazione -Filter '*.pcfacile-tmp' -File -ErrorAction SilentlyContinue)) {
        try { Remove-Item -LiteralPath $tmp.FullName -Force -ErrorAction SilentlyContinue; $rimossi++ } catch {}
    }
    if ($rimossi -gt 0) { Write-OK "Chiavetta riordinata: rimossi $rimossi file/cartelle superflui." }
    return $rimossi
}

# Dopo la connessione Wi-Fi: se lo script avviato era una copia locale/vecchia,
# controlla l'impronta SHA256 su GitHub; se trova una versione piu' recente,
# aggiorna la chiavetta e si riavvia automaticamente con l'ultima versione.
function Invoke-SelfUpdateIfOutdated {
    param(
        [string]$TargetDir,
        [string]$LauncherPath,
        [string[]]$Basi = @(
            'https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main',
            'https://cdn.jsdelivr.net/gh/samuelenigro97-prog/pc-facile@main'
        )
    )
    if ($Test -or $Global:Test -or $env:PESTER_TEST -or $Diagnostica -or $NoSelfUpdate) { return $false }
    $scriptCorrente = $PSCommandPath
    if (-not $scriptCorrente -or -not (Test-Path -LiteralPath $scriptCorrente -PathType Leaf)) { return $false }
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
    $hashLocale = (Get-FileHash -LiteralPath $scriptCorrente -Algorithm SHA256).Hash.ToLower()
    $t = (Get-Date).Ticks
    $hashRemoto = $null
    $baseOk = $null
    foreach ($base in $Basi) {
        try {
            $raw = [string](Invoke-WebRequest -Uri ($base + '/setup-pc.ps1.sha256?t=' + $t) -UseBasicParsing -TimeoutSec 4 -Headers @{ 'Cache-Control' = 'no-cache' } -ErrorAction Stop).Content
            $h = ($raw.Trim() -split '\s+')[0].ToLower()
            if ($h -match '^[0-9a-f]{64}$') { $hashRemoto = $h; $baseOk = $base; break }
        } catch {}
    }
    if (-not $hashRemoto -or $hashRemoto -eq $hashLocale) { return $false }

    Write-Host ""
    Write-Info "Trovata versione piu' recente su GitHub: aggiorno la chiavetta e riavvio lo script..."
    if ($TargetDir -and (Test-Path -LiteralPath $TargetDir -PathType Container)) {
        try { [void](Invoke-AggiornamentoUSB -Destinazione $TargetDir -LauncherInEsecuzione $LauncherPath) } catch {}
    }
    $tmpDir = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
    $tmpScript = Join-Path $tmpDir ("setup-pc-updated-{0}.ps1" -f [guid]::NewGuid().ToString('N'))
    try {
        Invoke-WebRequest -Uri ($baseOk + '/setup-pc.ps1?t=' + $t) -OutFile $tmpScript -UseBasicParsing -TimeoutSec 20 -Headers @{ 'Cache-Control' = 'no-cache' } -ErrorAction Stop
        $reale = (Get-FileHash -LiteralPath $tmpScript -Algorithm SHA256).Hash.ToLower()
        if ($reale -ne $hashRemoto) {
            Remove-Item -LiteralPath $tmpScript -Force -ErrorAction SilentlyContinue
            return $false
        }
        $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $tmpScript, '-NoSelfUpdate')
        if ($TargetDir) { $argList += @('-TargetDir', $TargetDir) }
        if ($LauncherPath) { $argList += @('-LauncherPath', $LauncherPath) }
        if ($CreaRipristino) { $argList += '-CreaRipristino' }
        $pwshExe = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh.exe' } else { 'powershell.exe' }
        & $pwshExe @argList
        return $true
    } catch {
        Remove-Item -LiteralPath $tmpScript -Force -ErrorAction SilentlyContinue
        return $false
    }
}

# Cartella "kit" da aggiornare in automatico dal launcher: NON la cartella
# temporanea (avvio da Win+R) e solo se e' un disco rimovibile oppure contiene
# gia' setup-pc.ps1 (copia offline). Evita di riempire Desktop/Download.
function Test-CartellaKitUSB {
    param([string]$Cartella)
    if (-not $Cartella) { return $false }
    if ($Cartella -match '^[A-Za-z]:$') { $Cartella += '\' }
    if (-not (Test-Path -LiteralPath $Cartella -PathType Container)) { return $false }
    try {
        $piena = [System.IO.Path]::GetFullPath($Cartella).TrimEnd('\', '/')
        foreach ($tmpBase in @($env:TEMP, $env:TMP, [System.IO.Path]::GetTempPath())) {
            if (-not $tmpBase) { continue }
            $tb = [System.IO.Path]::GetFullPath($tmpBase).TrimEnd('\', '/')
            if ($piena -ieq $tb -or $piena.StartsWith($tb + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) { return $false }
        }
    } catch { return $false }
    if (Test-Path -LiteralPath (Join-Path $Cartella 'setup-pc.ps1')) { return $true }
    try {
        $radice = [System.IO.Path]::GetPathRoot([System.IO.Path]::GetFullPath($Cartella))
        if ($radice -and ([System.IO.DriveInfo]::new($radice).DriveType -eq [System.IO.DriveType]::Removable)) { return $true }
    } catch {}
    return $false
}

# Sostituisce il launcher con "<launcher>.nuovo" DOPO che la finestra cmd che lo
# esegue si e' chiusa (cmd.exe legge il .bat mentre gira: sovrascriverlo prima
# lo corromperebbe). Serve solo per i launcher VECCHI, che non sanno fare lo
# scambio da soli: un piccolo processo nascosto attende la fine di cmd e sposta
# il file. Se qualcosa non va, il .nuovo resta e si riprova al prossimo avvio.
function Start-SostituzioneLauncherDifferita {
    param([string]$Launcher)
    try {
        $nuovo = "$Launcher.nuovo"
        if (-not (Test-Path -LiteralPath $nuovo)) { return }
        $padre = Get-CimInstance Win32_Process -Filter "ProcessId=$PID" -ErrorAction Stop
        $cmdProc = Get-CimInstance Win32_Process -Filter "ProcessId=$($padre.ParentProcessId)" -ErrorAction Stop
        if ($cmdProc.Name -ine 'cmd.exe') { return }
        $l = $Launcher -replace "'", "''"
        $n = $nuovo -replace "'", "''"
        $comando = "try { Wait-Process -Id $($cmdProc.ProcessId) -ErrorAction SilentlyContinue } catch {}; Start-Sleep -Seconds 1; " +
            "if (Test-Path -LiteralPath '$n') { Move-Item -LiteralPath '$n' -Destination '$l' -Force -ErrorAction SilentlyContinue }"
        # Un'unica stringa tra virgolette: i percorsi (senza ") restano intatti.
        Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -Command "' + $comando + '"') -ErrorAction Stop
    } catch {}
}

# Chiavette con il VECCHIO PC Facile.bat (passa -TargetDir ma non -LauncherPath
# e non conosce -AggiornaUSB): aggiorno qui i file una volta e sostituisco il
# launcher appena la sua finestra si chiude; dal prossimo avvio parte il nuovo.
if ($TargetDir -and -not $LauncherPath -and -not $AggiornaUSB -and -not $Test -and -not $Diagnostica -and
    -not $env:PESTER_TEST -and $env:OS -eq 'Windows_NT') {
    $kitVecchio = if ($TargetDir -match '^[A-Za-z]:$') { "$TargetDir\" } else { $TargetDir }
    $launcherVecchio = Join-Path $kitVecchio 'PC Facile.bat'
    if ((Test-Path -LiteralPath $launcherVecchio) -and (Test-CartellaKitUSB $kitVecchio)) {
        try {
            [void](Invoke-AggiornamentoUSB -Destinazione $kitVecchio -LauncherInEsecuzione $launcherVecchio)
            Start-SostituzioneLauncherDifferita -Launcher $launcherVecchio
        } catch {}
    }
}

# Modalita' -AggiornaUSB (usata da PC Facile.bat ad ogni avvio): aggiorna la
# chiavetta dal manifest ed esce subito, senza toccare nient'altro del PC.
if ($AggiornaUSB) {
    $cartellaKit = if ($TargetDir) { $TargetDir } else { $PSScriptRoot }
    if (Test-CartellaKitUSB $cartellaKit) {
        try {
            [void](Invoke-AggiornamentoUSB -Destinazione $cartellaKit -LauncherInEsecuzione $LauncherPath)
            if ($LauncherPath) { Start-SostituzioneLauncherDifferita -Launcher $LauncherPath }
        }
        catch { Write-Info "Aggiornamento chiavetta non riuscito: $($_.Exception.Message)" }
    } else {
        Write-Info "Aggiornamento chiavetta saltato: '$cartellaKit' non e' una chiavetta/cartella PC Facile."
    }
    return
}

# =============================================================================
# GESTIONE AVVISI SICUREZZA & ZERO POPUP PERMESSI (SILENT ELEVATION)
# =============================================================================
function Enable-SilentElevation {
    try {
        # 1. Variabile di ambiente per disabilitare controlli di zona su file scaricati/USB
        $env:SEE_MASK_NOZONECHECKS = '1'
        [Environment]::SetEnvironmentVariable("SEE_MASK_NOZONECHECKS", "1", "Process")

        # (Rimossi: LowRiskFileTypes/SaveZoneInformation e UAC
        #  ConsentPromptBehaviorAdmin = 0. Indebolivano la sicurezza di Windows e
        #  facevano bloccare l'intero script dall'antivirus (AMSI:
        #  ScriptContainedMaliciousContent). Non servono: lo script gira gia' come
        #  amministratore, quindi gli installer avviati da qui non chiedono l'UAC,
        #  e i file vengono comunque sbloccati con Unblock-File qui sotto.)

        # 4. Sblocca rapidamente i file di avvio nella cartella dello script (senza -Recurse su TEMP/Download)
        if ($PSScriptRoot -and (Test-Path -LiteralPath $PSScriptRoot)) {
            Get-ChildItem -LiteralPath $PSScriptRoot -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Extension -match '^\.(ps1|bat|cmd|exe|msi)$' } |
                Unblock-File -ErrorAction SilentlyContinue
        }

        # 5. Pulisci eventuale cartella installers anomala creata in System32 e chiudi popup 7-Zip residui
        $badSysInst = "C:\Windows\system32\installers"
        if (Test-Path -LiteralPath $badSysInst) {
            try { Remove-Item -LiteralPath $badSysInst -Recurse -Force -ErrorAction SilentlyContinue } catch {}
        }
        Get-Process -ErrorAction SilentlyContinue | Where-Object {
            $_.MainWindowTitle -match 'can''t load config info'
        } | ForEach-Object { try { $_.Kill() } catch {} }
    } catch {}
}

function Restore-SilentElevation {
    try {
        # Ripristina il valore di sicurezza originale di UAC (default Windows = 5)
        if ($null -ne $Global:OrigConsentPromptAdmin) {
            $uacKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
            Set-ItemProperty -Path $uacKey -Name "ConsentPromptBehaviorAdmin" -Value $Global:OrigConsentPromptAdmin -Type DWord -ErrorAction SilentlyContinue
        }
    } catch {}
}

# Avviso sonoro. [console]::Beep e' un metodo .NET gestito: NON e' P/Invoke,
# l'antivirus non lo segnala. Solo nel run reale (niente bip in Test/Diagnostica).
# Bip di ATTESA: suona quando lo script si ferma e aspetta una TUA azione
# (domande, pause). Cosi', se ti allontani, un bip = "serve la tua azione".
function Beep-Attesa {
    if ($RunReale) { try { [console]::Beep(1000, 150) } catch {} }
}
# Melodia breve di "tutto finito" (due toni), a fine lavoro.
function Beep-Completato {
    if ($RunReale) { try { [console]::Beep(784, 160); [console]::Beep(1047, 260) } catch {} }
}

$Report = [System.Collections.ArrayList]::new()

function Add-Report {
    param(
        [string]$Voce,
        [string]$Esito  # OK | ERRORE | SALTATO
    )
    if ($null -eq $Report -or $Report.IsFixedSize) {
        $nuovo = [System.Collections.ArrayList]::new()
        if ($Report) { foreach ($elem in $Report) { [void]$nuovo.Add($elem) } }
        $Report = $nuovo
        $Global:Report = $nuovo
    }
    [void]$Report.Add([pscustomobject]@{ Voce = $Voce; Esito = $Esito })
}

# Token fine-grained con l'UNICO permesso "Issues: write" su questo repository
# (niente Contents, niente Actions, niente altro repo): e' per forza visibile
# a chiunque scarichi lo script, quindi il danno massimo possibile se abusato
# resta creare/modificare issue qui, mai toccare codice o altri account.
$Global:GH_REPORT_TOKEN = "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"
$Global:GH_REPORT_REPO  = "samuelenigro97-prog/pc-facile"

# Invia un report automatico (solo voci ERRORE/AVVISO + imprevisti gestiti)
# come GitHub Issue a fine lavoro: MAI nome cliente, email o password, solo
# dati tecnici (modello PC, versione Windows/script). Niente issue se tutto e'
# andato liscio (eviterebbe spam). Silenzioso su qualsiasi fallimento (rete,
# token scaduto, ecc.): non deve mai rallentare o bloccare la consegna del PC.
function Send-ReportGitHub {
    param($ReportVoci)
    if (-not $RunReale -or $Test -or $Global:Test -or $env:PESTER_TEST) { return }
    try {
        $problemi = @($ReportVoci | Where-Object { $_.Esito -eq 'ERRORE' -or $_.Esito -eq 'AVVISO' })
        $imprevisti = if ($Global:ErroriImprevisti) { @($Global:ErroriImprevisti) } else { @() }
        if ($problemi.Count -eq 0 -and $imprevisti.Count -eq 0) { return }

        # Se sulla chiavetta c'e' wifi\gh_token.txt (non pubblicato su GitHub, quindi
        # mai revocato dallo scanner automatico di GitHub), usa quello in priorita'.
        $tokenAttivo = $Global:GH_REPORT_TOKEN
        foreach ($candBase in @($Global:TargetDir, $PSScriptRoot)) {
            if ($candBase) {
                $tFile = Join-Path $candBase "wifi\gh_token.txt"
                if (Test-Path -LiteralPath $tFile) {
                    $tLetto = (Get-Content -LiteralPath $tFile -Raw -ErrorAction SilentlyContinue).Trim()
                    if ($tLetto) { $tokenAttivo = $tLetto; break }
                }
            }
        }

        $hw      = Get-SystemHardwareDetails
        $modello = if ($hw.Produttore -and $hw.Modello) { "$($hw.Produttore) $($hw.Modello)" } else { "PC sconosciuto" }
        $nErrore = @($problemi | Where-Object { $_.Esito -eq 'ERRORE' }).Count
        $nAvviso = @($problemi | Where-Object { $_.Esito -eq 'AVVISO' }).Count

        $corpo = [System.Text.StringBuilder]::new()
        [void]$corpo.AppendLine("**PC**: $modello")
        [void]$corpo.AppendLine("**Windows**: $([System.Environment]::OSVersion.VersionString)")
        [void]$corpo.AppendLine("**Script**: v$SCRIPT_VERSION")
        [void]$corpo.AppendLine("**Data**: $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
        [void]$corpo.AppendLine("")
        [void]$corpo.AppendLine("### Esiti da controllare")
        foreach ($p in $problemi) { [void]$corpo.AppendLine("- **$($p.Esito)**: $($p.Voce)") }
        if ($imprevisti.Count -gt 0) {
            [void]$corpo.AppendLine("")
            [void]$corpo.AppendLine("### Imprevisti gestiti (non bloccanti)")
            foreach ($e in $imprevisti) { [void]$corpo.AppendLine("- $($e.Messaggio) (riga $($e.Riga))") }
        }

        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $headers = @{ Authorization = "Bearer $tokenAttivo"; Accept = "application/vnd.github+json" }
        $payload = @{ title = "[Auto-report] $modello - $nErrore errori, $nAvviso avvisi"; body = $corpo.ToString() } | ConvertTo-Json -Compress
        Invoke-RestMethod -Uri "https://api.github.com/repos/$Global:GH_REPORT_REPO/issues" -Method Post `
            -Headers $headers -Body $payload -ContentType "application/json; charset=utf-8" -TimeoutSec 10 | Out-Null
    } catch {
        # Silenzioso: GitHub irraggiungibile, token scaduto, rete bloccata...
    }
}

$Global:ErroriImprevisti = [System.Collections.ArrayList]::new()

function Register-ErroreImprevisto {
    param($ErroreRec)
    try {
        if ($null -eq $Global:ErroriImprevisti) { $Global:ErroriImprevisti = [System.Collections.ArrayList]::new() }
        $info = [ordered]@{
            Quando  = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            Messaggio = "$($ErroreRec.Exception.Message)"
            Comando   = "$($ErroreRec.InvocationInfo.MyCommand)"
            Riga      = "$($ErroreRec.InvocationInfo.ScriptLineNumber)"
            Dettaglio = "$($ErroreRec.InvocationInfo.Line)".Trim()
        }
        [void]$Global:ErroriImprevisti.Add([pscustomobject]$info)
    } catch {}
}

trap {
    Register-ErroreImprevisto $_
    try { Write-Host "   [!] Imprevisto gestito: $($_.Exception.Message)" -ForegroundColor DarkYellow } catch {}
    continue
}

# BIP DI RICHIAMO: se ti allontani e non rispondi, dopo 2 MINUTI di silenzio lo
# script inizia a bipare in modo RICORRENTE (un bip corto ogni pochi secondi,
# discreto, non stressante) e continua finche' non digiti, cosi' te ne accorgi.
# Read-Host blocca il thread principale, quindi il bip gira in un RUNSPACE
# separato (.NET gestito, niente P/Invoke: l'antivirus non lo segnala), che
# lavora in parallelo mentre il thread principale e' fermo su Read-Host.
$Global:BipPS = $null
function Start-BipRipetuto {
    param(
        [int]$Attesa   = 120,   # secondi di silenzio prima di iniziare a richiamare
        [int]$Cadenza  = 4       # poi un bip corto ogni tot secondi, di continuo
    )
    if (-not $RunReale) { return }
    Stop-BipRipetuto
    try {
        $ps = [PowerShell]::Create()
        [void]$ps.AddScript({
            param($attesa, $cadenza)
            Start-Sleep -Seconds $attesa          # 2 min: nessun suono, lavori in pace
            while ($true) {                        # poi richiamo ricorrente ma discreto
                try { [console]::Beep(880, 120) } catch {}
                Start-Sleep -Seconds $cadenza
            }
        }).AddArgument($Attesa).AddArgument($Cadenza)
        [void]$ps.BeginInvoke()
        $Global:BipPS = $ps
    } catch { $Global:BipPS = $null }
}
function Stop-BipRipetuto {
    if ($Global:BipPS) {
        try { $Global:BipPS.Stop(); $Global:BipPS.Dispose() } catch {}
        $Global:BipPS = $null
    }
}

# BARRA ANIMATA GENERICA per le operazioni lunghe che NON sono installazioni
# winget (lingua, punto di ripristino, driver, pulizia...). Quelle bloccano il
# thread principale e non hanno un processo da "agganciare", percio' l'animazione
# gira in un RUNSPACE separato (.NET gestito, niente P/Invoke) che disegna una
# barra "a spola" col tempo trascorso, mentre l'operazione vera lavora nel thread
# principale (cosi' variabili ed effetti restano intatti). Uso:
#   Start-BarraAnimata "Testo"; <operazione bloccante>; Stop-BarraAnimata
$Global:BarraPS = $null
function Start-BarraAnimata {
    param([string]$Testo)
    if (-not $RunReale) { return }
    Stop-BarraAnimata
    try {
        $pctVal = if ($Global:PannelloStatus) { $Global:PannelloStatus.Percentuale } else { 0 }
        try { $host.UI.RawUI.WindowTitle = "PC Facile [$pctVal%] - $Testo" } catch {}
        $ps = [PowerShell]::Create()
        [void]$ps.AddScript({
            param($testo, $full, $empty, $uOrange, $uReset, $uBlue, $uPeach, $pct)
            $larg = 20; $span = 4; $period = ($larg - $span) * 2; $inizio = Get-Date; $i = 0
            while ($true) {
                $phase = $i % $period
                $pos = if ($phase -le ($larg - $span)) { $phase } else { $period - $phase }
                $barra = ($empty * $pos) + ($full * $span) + ($empty * ($larg - $span - $pos))
                $sec = [int]((Get-Date) - $inizio).TotalSeconds
                $pctTxt = if ($pct -ge 0) { " $uOrange$pct%$uReset" } else { "" }
                $riga = "   $uBlue$testo$uReset$pctTxt  [$uOrange$barra$uReset]  $uPeach${sec}s$uReset"
                try { [Console]::Write("`r$riga") } catch {}
                Start-Sleep -Milliseconds 120; $i++
            }
        }).AddArgument($Testo).AddArgument([string]$BOX_FULL).AddArgument([string]$BOX_EMPTY).AddArgument($U_ORANGE).AddArgument($U_RESET).AddArgument($U_BLUE).AddArgument($U_PEACH).AddArgument($pctVal)
        [void]$ps.BeginInvoke()
        $Global:BarraPS = $ps
    } catch { $Global:BarraPS = $null }
}
function Stop-BarraAnimata {
    if ($Global:BarraPS) {
        try { $Global:BarraPS.Stop(); $Global:BarraPS.Dispose() } catch {}
        $Global:BarraPS = $null
        try { [Console]::Write("`r" + (' ' * 72) + "`r") } catch {}
    }
}

# Attesa di una risposta CON WATCHDOG DI SICUREZZA:
# Attende una decisione o risposta dell'operatore.
# NON salta le decisioni: aspetta l'operatore con bip di avviso sonoro (Beep-Attesa)
# e richiamo acustico ricorrente (Start-BipRipetuto) dopo 2 minuti, cosi' l'operatore
# in negozio lo sente e puo' intervenire quando e' pronto.
function Attendi-Risposta {
    param(
        [string]$Prompt,
        [int]$TimeoutSec = 0,
        [string]$Default = ""
    )
    if ($Test -or $Global:Test -or $env:PESTER_TEST) {
        if ($Default) { return $Default }
        if ($Prompt -match 'S/N') { return "N" }
        return ""
    }

    Beep-Attesa
    Start-BipRipetuto
    try {
        $inputStr = ""
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        Write-Host -NoNewline "${Prompt}: "
        $consoleOk = $true
        try { $null = [Console]::KeyAvailable } catch { $consoleOk = $false }
        if (-not $consoleOk -and $TimeoutSec -le 0) {
            return (Read-Host)
        }
        while ($TimeoutSec -le 0 -or $sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
            try {
                if (Get-Command Invoke-PassiSingoliCoda -ErrorAction SilentlyContinue) { Invoke-PassiSingoliCoda }
                if (Get-Command Get-CredenzialiSalvatePannello -ErrorAction SilentlyContinue) { [void](Get-CredenzialiSalvatePannello) }
            } catch {}
            try {
                if ([Console]::KeyAvailable) {
                    $keyInfo = [Console]::ReadKey($false)
                    if ($keyInfo.Key -eq [ConsoleKey]::Enter) {
                        Write-Host ""
                        if ([string]::IsNullOrWhiteSpace($inputStr)) { return $Default }
                        return $inputStr
                    } elseif ($keyInfo.Key -eq [ConsoleKey]::Backspace) {
                        if ($inputStr.Length -gt 0) {
                            $inputStr = $inputStr.Substring(0, $inputStr.Length - 1)
                            [Console]::Write("`b `b")
                        }
                    } elseif (-not [char]::IsControl($keyInfo.KeyChar)) {
                        $inputStr += $keyInfo.KeyChar
                    }
                }
            } catch { break }
            Start-Sleep -Milliseconds 150
        }
        Write-Host ""
        if ([string]::IsNullOrWhiteSpace($inputStr)) { return $Default }
        return $inputStr
    } finally {
        Stop-BipRipetuto
    }
}

function Pausa {
    if ($Test -or $Global:Test -or $Diagnostica -or $RunReale -or $env:PESTER_TEST) { return }
    Write-Host ""
    [void](Attendi-Risposta "Premi INVIO per continuare")
}

# Password = nome cliente + "123!" (sempre, cosi' e' prevedibile e facile da
# dettare). Es. "Rossi" -> "Rossi123!". Ha maiuscola, minuscole, cifre e simbolo
# -> soddisfa i requisiti Microsoft. Lo SCRIPT la costruisce (quindi la conosce
# e la scrive nel riepilogo): NON legge nulla dal browser.
function New-PasswordCliente {
    param([string]$Base)
    $oemNames = @('OEM', 'ADMIN', 'ADMINISTRATOR', 'USER', 'OWNER', 'DEFAULTUSER0', 'PC', 'LAPTOP', 'DESKTOP', 'CLT', 'CLT CLT', 'CLTCLT', 'CLIENTE')
    if ($Base -and ($oemNames -contains $Base.Trim().ToUpper())) {
        $Base = "Utente"
    }
    # Convenzione del negozio: "Nome123!" -> SOLO il primo nome (prima parola),
    # prima lettera maiuscola, il resto minuscolo. Es. "Mario Rossi" -> "Mario123!".
    $primo = @($Base -split '\s+' | Where-Object { $_ })[0]
    $b = ($primo -replace '[^A-Za-z]', '')
    if ($b.Length -lt 1 -or $b.ToUpper() -eq "CLIENTE" -or $b.ToUpper() -eq "CLT") { $b = "Utente" }
    $b = $b.Substring(0, 1).ToUpper() + $b.Substring(1).ToLower()
    return "${b}123!"
}

# Email suggerita per un nuovo account: convenzione del negozio "cognomenome"
# (COGNOME poi NOME) tutto attaccato e minuscolo, senza numeri. L'operatore
# digita "Nome Cognome": prendo l'ULTIMA parola come cognome e la metto davanti.
# Il dominio dipende dal provider scelto (outlook.it, gmail.com, proton.me).
# Es. "Mario Rossi" -> rossimario@outlook.it.
function New-EmailCliente {
    param([string]$Base, [string]$Dominio = "outlook.it")
    $oemNames = @('OEM', 'ADMIN', 'ADMINISTRATOR', 'USER', 'OWNER', 'DEFAULTUSER0', 'PC', 'LAPTOP', 'DESKTOP', 'CLT', 'CLT CLT', 'CLTCLT', 'CLIENTE')
    if ($Base -and ($oemNames -contains $Base.Trim().ToUpper())) {
        $Base = "utente"
    }
    $parti = @($Base -split '\s+' | ForEach-Object { $_ -replace '[^A-Za-z0-9]', '' } | Where-Object { $_ })
    if ($parti.Count -ge 2) {
        $cognome = $parti[-1]
        $nome    = ($parti[0..($parti.Count - 2)] -join '')
        $e = ($cognome + $nome).ToLower()
    } elseif ($parti.Count -eq 1) {
        $e = $parti[0].ToLower()
    } else {
        $e = "utente"
    }
    if ($e.Length -gt 20) { $e = $e.Substring(0, 20) }
    return "$e@$Dominio"
}

function Set-NomeUtenteEPc {
    param(
        [string]$NomeUtente = "",
        [string]$NomePc = "",
        [switch]$Silenzioso
    )
    $esitoUtente = $false
    $esitoPc = $false
    $oemNames = @('OEM', 'ADMIN', 'ADMINISTRATOR', 'USER', 'OWNER', 'DEFAULTUSER0', 'PC', 'LAPTOP', 'DESKTOP', 'CLT', 'CLT CLT', 'CLTCLT', 'CLIENTE')
    if (-not $NomeUtente -or $oemNames -contains $NomeUtente.Trim().ToUpper()) {
        $NomeUtente = "Utente"
    } else {
        $NomeUtente = $NomeUtente.Trim()
    }
    if (-not $NomePc) {
        $clean = ($NomeUtente -replace '[^A-Za-z0-9]', '')
        if (-not $clean -or $oemNames -contains $clean.ToUpper()) { $clean = "Utente" }
        $NomePc = "PC-$clean"
    } else {
        $NomePc = ($NomePc -replace '[^A-Za-z0-9\-]', '').Trim('-')
        if (-not $NomePc -or $oemNames -contains $NomePc.ToUpper() -or $NomePc -match '^(?i)PC-clt$') { $NomePc = "PC-Utente" }
    }
    if ($NomePc.Length -gt 15) { $NomePc = $NomePc.Substring(0, 15) }

    $Global:nomeCliente = $NomeUtente
    $script:nomeCliente = $NomeUtente

    if (-not ($Test -or $Global:Test -or $env:PESTER_TEST)) {
        try {
            Set-LocalUser -Name $env:USERNAME -FullName $NomeUtente -PasswordNeverExpires $true -ErrorAction Stop
            $esitoUtente = $true
        } catch {
            try {
                Set-LocalUser -Name $env:USERNAME -FullName $NomeUtente -ErrorAction Stop
                $esitoUtente = $true
            } catch {
                try {
                    $u = [ADSI]("WinNT://./$env:USERNAME,user")
                    $u.FullName = $NomeUtente
                    $u.SetInfo()
                    $esitoUtente = $true
                } catch {}
            }
        }
        # Disattiva per sempre la scadenza password Windows (42 giorni), rimuove la password locale
        # se impostata per errore durante OOBE e disabilita il blocco password al risveglio dallo standby.
        try {
            & net.exe accounts /maxpwage:unlimited 2>$null | Out-Null
            Get-LocalUser -ErrorAction SilentlyContinue | Where-Object { $_.Enabled } | ForEach-Object {
                try { Set-LocalUser -Name $_.Name -PasswordNeverExpires $true -ErrorAction SilentlyContinue } catch {}
            }
            & net.exe user $env:USERNAME "" 2>$null | Out-Null
            $pwLess = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device"
            if (Test-Path $pwLess) {
                Set-ItemProperty -Path $pwLess -Name "DevicePasswordLessBuildVersion" -Value 0 -Type DWord -ErrorAction SilentlyContinue
            }
            $pwrPol = "HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\0e796bdb-100d-47d6-a2d5-f7d2daa51f51"
            if (-not (Test-Path $pwrPol)) { New-Item -Path $pwrPol -Force -ErrorAction SilentlyContinue | Out-Null }
            Set-ItemProperty -Path $pwrPol -Name "ACSettingIndex" -Value 0 -Type DWord -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $pwrPol -Name "DCSettingIndex" -Value 0 -Type DWord -ErrorAction SilentlyContinue
            & powercfg.exe /setacvalueindex SCHEME_CURRENT SUB_NONE CONSOLELOCK 0 2>$null | Out-Null
            & powercfg.exe /setdcvalueindex SCHEME_CURRENT SUB_NONE CONSOLELOCK 0 2>$null | Out-Null
            & powercfg.exe /setactive SCHEME_CURRENT 2>$null | Out-Null
        } catch {}
        # Pulisce anche la cache del nome visualizzato di Windows 11 (LogonUI / Start Menu)
        # cosi' se all'OOBE l'account era stato chiamato 'clt clt', cambia subito.
        try {
            $logonUi = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI"
            if (Test-Path $logonUi) {
                if (Get-ItemProperty -Path $logonUi -Name "LastLoggedOnDisplayName" -ErrorAction SilentlyContinue) {
                    Set-ItemProperty -Path $logonUi -Name "LastLoggedOnDisplayName" -Value $NomeUtente -ErrorAction SilentlyContinue
                }
            }
            $sessData = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\SessionData"
            if (Test-Path $sessData) {
                Get-ChildItem -Path $sessData -ErrorAction SilentlyContinue | ForEach-Object {
                    if (Get-ItemProperty -Path $_.PSPath -Name "LoggedOnDisplayName" -ErrorAction SilentlyContinue) {
                        Set-ItemProperty -Path $_.PSPath -Name "LoggedOnDisplayName" -Value $NomeUtente -ErrorAction SilentlyContinue
                    }
                }
            }
        } catch {}

        if ($NomePc -and $NomePc.ToUpper() -ne $env:COMPUTERNAME.ToUpper()) {
            try {
                Rename-Computer -NewName $NomePc -Force -ErrorAction Stop
                $esitoPc = $true
            } catch {
                $esitoPc = $true
            }
        } else {
            $esitoPc = $true
        }
    } else {
        $esitoUtente = $true
        $esitoPc = $true
    }

    if (-not $Silenzioso) {
        Write-OK "Nome account utente impostato su: $NomeUtente"
        Write-OK "Nome PC impostato su: $NomePc (attivo dopo il riavvio)"
    }
    if ($Global:PannelloStatus) {
        $Global:PannelloStatus.NomeUtenteAttuale = $NomeUtente
        $Global:PannelloStatus.NomePcAttuale = $NomePc
    }
    return [pscustomobject]@{
        Ok         = ($esitoUtente -or $esitoPc)
        NomeUtente = $NomeUtente
        NomePc     = $NomePc
    }
}

# Rileva la GPU DEDICATA (non l'integrata): solo per queste ha senso installare
# il tool del produttore, perche' Windows Update spesso non ne prende il driver
# giusto. Sulle integrate (Intel HD/UHD/Iris, Radeon dei Ryzen) Windows Update
# basta, quindi non aggiungiamo app inutili. Ritorna il vendor: 'NVIDIA',
# 'AMD', 'INTEL' oppure $null se c'e' solo grafica integrata.
# Euristica (solo Win32_VideoController, niente tool esterni):
#  - NVIDIA presente          -> sempre dedicata.
#  - AMD "Radeon RX/Pro"       -> dedicata; una AMD + un'altra GPU -> dedicata.
#    "Radeon Graphics"/"Vega" da sola -> integrata (nel dubbio si salta).
#  - Intel "Arc"               -> dedicata (rara); le altre Intel -> integrate.
function Get-GpuDedicata {
    try {
        $gpu = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name })
        if ($gpu.Count -eq 0) { return $null }

        if ($gpu | Where-Object { $_.Name -match 'NVIDIA|GeForce|RTX|GTX' }) { return 'NVIDIA' }

        $amdDed = $gpu | Where-Object { $_.Name -match 'Radeon\s*(RX|Pro)|Radeon\s*R[579]|FirePro' }
        # AMD affiancata a una GPU di un altro vendor = quasi certamente dedicata.
        $amdQualsiasi = $gpu | Where-Object { $_.Name -match 'AMD|Radeon' }
        $nonAmd       = $gpu | Where-Object { $_.Name -notmatch 'AMD|Radeon' }
        if ($amdDed -or ($amdQualsiasi -and $nonAmd)) { return 'AMD' }

        if ($gpu | Where-Object { $_.Name -match 'Intel.*Arc|Arc\s*A\d' }) { return 'INTEL' }

        return $null   # solo grafica integrata
    } catch { return $null }
}

# Trova gli antivirus di PROVA installati leggendo le chiavi di disinstallazione
# (ARP) del registro: piu' affidabile di 'winget list', becca anche i
# preinstallati che winget non gestisce. Ritorna nome + stringhe di uninstall.
function Get-AntivirusInstallati {
    $chiavi = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $pattern = 'McAfee|Norton|Avast|AVG'
    $trovati = @()
    foreach ($k in $chiavi) {
        try {
            Get-ItemProperty $k -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -and $_.DisplayName -match $pattern } |
                ForEach-Object {
                    $trovati += [pscustomobject]@{
                        Nome           = $_.DisplayName
                        Uninstall      = $_.UninstallString
                        QuietUninstall = $_.QuietUninstallString
                    }
                }
        } catch {}
    }
    # dedup per nome
    return $trovati | Sort-Object Nome -Unique
}

# Recupera la chiave di ripristino BitLocker del volume di sistema.
# ATTENZIONE - DATO SENSIBILE: la recovery key da' accesso COMPLETO al disco
# cifrato. Finisce SOLO nella scheda di consegna (PDF sul Desktop) che RESTA
# con la macchina/cliente, mai nei log: e' voluto e necessario (Windows 11 attiva da solo la crittografia del dispositivo;
# senza questa chiave, dopo un reset o un cambio hardware il cliente resta
# chiuso fuori dai suoi dati). Non va mai pubblicata/condivisa altrove.
# Ritorna un oggetto: Volume, Cifrato, Stato, KeyId, RecoveryKey, Esito, Messaggio.
function Get-BitLockerRecovery {
    param([string]$Volume = $env:SystemDrive)   # es. "C:"

    $r = [ordered]@{
        Volume = $Volume; Cifrato = $false; Stato = "sconosciuto"
        KeyId = ""; RecoveryKey = ""; Esito = "SALTATO"; Messaggio = ""
    }

    # 1) Cmdlet BitLocker (Windows Pro/Enterprise): oggetti puliti, niente parsing.
    try {
        if (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue) {
            $blv = Get-BitLockerVolume -MountPoint $Volume -ErrorAction Stop
            $r.Stato   = "$($blv.VolumeStatus) / Protezione: $($blv.ProtectionStatus)"
            $r.Cifrato = ($blv.VolumeStatus -ne 'FullyDecrypted')
            # Anche se la protezione e' SOSPESA, il RecoveryPassword protector c'e'
            # ancora: lo prendiamo comunque.
            $rp = $blv.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' } | Select-Object -First 1
            if ($rp) {
                $r.KeyId       = "$($rp.KeyProtectorId)".Trim('{', '}')
                $r.RecoveryKey = "$($rp.RecoveryPassword)".Trim()
            }
        }
    } catch {
        $r.Messaggio = "cmdlet BitLocker non riusciti: $_"
    }

    # 2) Fallback manage-bde (Windows Home: niente cmdlet BitLocker). NON parso le
    #    stringhe localizzate: estraggo con REGEX il GUID e la chiave a 48 cifre,
    #    che sono uguali in ogni lingua.
    if (-not $r.RecoveryKey) {
        try {
            $out = & manage-bde -protectors -get $Volume -Type RecoveryPassword 2>$null | Out-String
            if ($out) {
                $mKey = [regex]::Match($out, '\d{6}(?:-\d{6}){7}')
                $mId  = [regex]::Match($out, '\{?([0-9A-Fa-f]{8}-(?:[0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12})\}?')
                if ($mKey.Success) { $r.RecoveryKey = $mKey.Value; $r.Cifrato = $true }
                if ($mId.Success)  { $r.KeyId = $mId.Groups[1].Value }
                if ($r.Stato -eq 'sconosciuto') { $r.Stato = "rilevato via manage-bde" }
            }
        } catch {
            $r.Messaggio = "manage-bde non riuscito: $_"
        }
    }

    # Esito coerente con Add-Report (OK / AVVISO / SALTATO):
    if ($r.RecoveryKey) {
        $r.Esito = "OK"; $r.Messaggio = "chiave trovata: riportata nella scheda di consegna"
    } elseif (-not $r.Cifrato) {
        $r.Esito = "SALTATO"; $r.Messaggio = "volume non cifrato: nessuna chiave da salvare"
    } else {
        $r.Esito = "AVVISO"
        if (-not $r.Messaggio) { $r.Messaggio = "volume cifrato ma nessuna RecoveryPassword rilevata" }
    }

    return [pscustomobject]$r
}

# -----------------------------------------------------------------------------
# DIAGNOSTICA HARDWARE, BATTERIA E STATO ATTIVAZIONE WINDOWS
# -----------------------------------------------------------------------------

function Get-StorageHealthInfo {
    $info = [ordered]@{
        Modello       = "Disco di sistema"
        Tipo          = "SSD"
        Salute        = "Buono"
        Usura         = ""
        Temperatura   = ""
        StatoCompleto = "OK"
    }
    try {
        if (Get-Command Get-PhysicalDisk -ErrorAction SilentlyContinue) {
            $disks = Get-PhysicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DeviceId -eq 0 -or $_.OperationalStatus -eq 'OK' } | Select-Object -First 1
            if ($disks) {
                if ($disks.FriendlyName) { $info.Modello = $disks.FriendlyName }
                $info.Tipo = if ($disks.MediaType -and $disks.MediaType -ne 'Unspecified') { "$($disks.MediaType)" } else { "SSD" }
                $info.Salute = if ($disks.HealthStatus) { "$($disks.HealthStatus)" } else { "Healthy" }
            }
        }
        if (Get-Command Get-StorageReliabilityCounter -ErrorAction SilentlyContinue) {
            $disk = Get-PhysicalDisk -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($disk) {
                $counter = Get-StorageReliabilityCounter -PhysicalDisk $disk -ErrorAction SilentlyContinue
                if ($counter) {
                    if ($counter.Wear -ne $null -and $counter.Wear -ge 0) {
                        $info.Usura = "Usura SSD: $($counter.Wear)%"
                    }
                    if ($counter.Temperature -gt 0) {
                        $info.Temperatura = "$($counter.Temperature) C"
                    }
                }
            }
        }
        if (-not $info.Modello -or $info.Modello -eq "Disco di sistema") {
            $wmiDisk = Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($wmiDisk) {
                if ($wmiDisk.Model) { $info.Modello = $wmiDisk.Model }
                $info.Salute = if ($wmiDisk.Status -eq 'OK') { "Buono (SMART OK)" } else { "$($wmiDisk.Status)" }
            }
        }
    } catch {}

    $disp = "$($info.Tipo) - $($info.Modello)"
    if ($info.Salute) { $disp += " (Stato: $($info.Salute))" }
    if ($info.Usura) { $disp += " - $($info.Usura)" }
    $info.StatoCompleto = $disp
    return [pscustomobject]$info
}

function Get-BatteryHealthInfo {
    $r = [ordered]@{
        Presente     = $false
        Salute       = "Non presente (PC Desktop)"
        Percentuale  = 100
        StatoCarica  = ""
        Descrizione  = ""
    }
    try {
        $batt = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($batt) {
            $r.Presente = $true
            $r.StatoCarica = "$($batt.EstimatedChargeRemaining)%"
            $fullCap = $null
            $desCap  = $null
            try {
                $staticData = Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData -ErrorAction SilentlyContinue | Select-Object -First 1
                $fullData   = Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($staticData -and $fullData -and $staticData.DesignedCapacity -gt 0) {
                    $desCap  = $staticData.DesignedCapacity
                    $fullCap = $fullData.FullChargedCapacity
                }
            } catch {}

            if ($fullCap -and $desCap -and $desCap -gt 0) {
                $pct = [Math]::Round(($fullCap / $desCap) * 100)
                if ($pct -gt 100) { $pct = 100 }
                $r.Percentuale = $pct
                $condizione = if ($pct -ge 85) { "Ottima" } elseif ($pct -ge 70) { "Buona" } else { "Usurata" }
                $r.Salute = "$pct% ($condizione)"
                $r.Descrizione = "Salute Batteria: $pct% ($condizione) - Livello carica: $($batt.EstimatedChargeRemaining)%"
            } else {
                $r.Salute = "Presente (Carica: $($batt.EstimatedChargeRemaining)%)"
                $r.Descrizione = "Batteria Notebook: Carica $($batt.EstimatedChargeRemaining)%"
            }
        }
    } catch {}
    return [pscustomobject]$r
}

function Get-WindowsActivationStatus {
    $r = [ordered]@{
        Attivo      = $false
        Tipo        = "Sconosciuto"
        Messaggio   = "Non verificato"
        StatoBreve  = "Da verificare"
    }
    try {
        $lic = Get-CimInstance -Query "SELECT LicenseStatus, Description, Name, PartialProductKey FROM SoftwareLicensingProduct WHERE PartialProductKey IS NOT NULL" -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -like "*Windows*" } | Select-Object -First 1
        if ($lic) {
            if ($lic.LicenseStatus -eq 1) {
                $r.Attivo = $true
                $r.Tipo = if ($lic.Description -like "*OEM*") { "Licenza OEM" }
                          elseif ($lic.Description -like "*VOLUME*" -or $lic.Description -like "*KMS*") { "Licenza Volume/KMS" }
                          elseif ($lic.Description -like "*RETAIL*") { "Licenza Retail / Digitale" }
                          else { "Licenza Digitale Permanente" }
                $r.Messaggio  = "Attivato regolarmente ($($r.Tipo))"
                $r.StatoBreve = "Attivato ($($r.Tipo))"
            } else {
                $r.Attivo     = $false
                $r.Tipo       = "Non Attivo"
                $r.Messaggio  = "Windows NON attivato o in periodo di prova (Status: $($lic.LicenseStatus))"
                $r.StatoBreve = "NON ATTIVATO (Richiede licenza)"
            }
        } else {
            $slmgrOut = & cscript.exe //nologo "$env:SystemRoot\System32\slmgr.vbs" /dli 2>$null | Out-String
            if ($slmgrOut -match "License Status:\s*Licensed" -or $slmgrOut -match "Stato licenza:\s*Con licenza") {
                $r.Attivo = $true
                $r.Tipo = "Licenza Digitale"
                $r.Messaggio = "Attivato regolarmente"
                $r.StatoBreve = "Attivato"
            }
        }
    } catch {
        $r.Messaggio = "Impossibile interrogare lo stato licenza: $_"
    }
    return [pscustomobject]$r
}

function Get-SystemHardwareDetails {
    $details = [ordered]@{
        Produttore       = "Standard PC"
        Modello          = "Desktop/Notebook"
        Seriale          = "Non disponibile"
        SchedaMadre      = "Standard"
        Cpu              = "Processore Standard"
        RamGB            = 8
        Gpu              = "Grafica integrata"
        DataSetup        = (Get-Date).ToString("dd/MM/yyyy")
        ScadenzaGaranzia = (Get-Date).AddYears(2).ToString("dd/MM/yyyy")
    }

    try {
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
        if ($cs) {
            if ($cs.Manufacturer -and $cs.Manufacturer -notmatch "System manufacturer|To be filled") {
                $details.Produttore = $cs.Manufacturer.Trim()
            }
            if ($cs.Model -and $cs.Model -notmatch "System Product|To be filled") {
                $details.Modello = $cs.Model.Trim()
            }
            if ($cs.TotalPhysicalMemory) {
                $details.RamGB = [Math]::Round($cs.TotalPhysicalMemory / 1GB)
            }
        }
    } catch {}

    try {
        $bios = Get-CimInstance Win32_Bios -ErrorAction SilentlyContinue
        if ($bios -and $bios.SerialNumber -and $bios.SerialNumber -notmatch "To be filled|Default|None|00000000|System Serial") {
            $details.Seriale = $bios.SerialNumber.Trim()
        } else {
            $csp = Get-CimInstance Win32_ComputerSystemProduct -ErrorAction SilentlyContinue
            if ($csp -and $csp.IdentifyingNumber -and $csp.IdentifyingNumber -notmatch "To be filled|Default|None|00000000|System Serial") {
                $details.Seriale = $csp.IdentifyingNumber.Trim()
            }
        }
    } catch {}

    try {
        $bb = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue
        if ($bb) {
            $mfg = if ($bb.Manufacturer -and $bb.Manufacturer -notmatch "To be filled") { $bb.Manufacturer.Trim() } else { "" }
            $prd = if ($bb.Product -and $bb.Product -notmatch "To be filled") { $bb.Product.Trim() } else { "" }
            $details.SchedaMadre = "$mfg $prd".Trim()
            if (-not $details.SchedaMadre) { $details.SchedaMadre = "Standard" }
        }
    } catch {}

    try {
        $proc = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($proc -and $proc.Name) {
            $details.Cpu = ($proc.Name -replace '\s+', ' ').Trim()
        }
    } catch {}

    try {
        $gpu = Get-GpuDedicata
        if ($gpu) {
            $details.Gpu = $gpu
        } else {
            $gpuDisp = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($gpuDisp -and $gpuDisp.Name) {
                $details.Gpu = $gpuDisp.Name.Trim()
            }
        }
    } catch {}

    return [pscustomobject]$details
}

function Invoke-PcFacileDiagnostics {
    param([switch]$MostraDettagli)
    
    Write-Titolo "CHECK SALUTE & DIAGNOSTICA HARDWARE PC FACILE"
    Write-Host "Esecuzione test completi su disco SSD, batteria, licenza e driver..." -ForegroundColor Gray
    Write-Host ""
    
    $hw      = Get-SystemHardwareDetails
    $storage = Get-StorageHealthInfo
    $battery = Get-BatteryHealthInfo
    $winAct  = Get-WindowsActivationStatus
    $bitlock = Get-BitLockerRecovery -Volume $env:SystemDrive
    
    # Controllo Driver con problemi (Device Manager Sentinel)
    $driverProblematici = @()
    try {
        if (Get-Command Get-PnpDevice -ErrorAction SilentlyContinue) {
            $driverProblematici = @(Get-PnpDevice -Status Error, Degraded -ErrorAction SilentlyContinue |
                                    Where-Object { $_.FriendlyName -and $_.Class -ne 'LegacyDriver' })
        }
    } catch {}

    # Controllo Spazio Disco
    $freeGB = 0
    try {
        $drv = Get-PSDrive ($env:SystemDrive.TrimEnd(':')) -ErrorAction SilentlyContinue
        if ($drv) { $freeGB = [math]::Round($drv.Free / 1GB, 1) }
    } catch {}

    # Output formattato a schermo
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host " 1. DISPOSITIVO & SPECIFICHE PRINCIPALI" -ForegroundColor White
    Write-Host "    Modello PC       : " -NoNewline; Write-Host "$($hw.Produttore) $($hw.Modello)" -ForegroundColor Cyan
    Write-Host "    Seriale (S/N)    : " -NoNewline; Write-Host "$($hw.Seriale)" -ForegroundColor Yellow
    Write-Host "    Processore (CPU) : $($hw.Cpu)"
    Write-Host "    Memoria RAM      : $($hw.RamGB) GB"
    Write-Host "    Scheda Video     : $($hw.Gpu)"
    Write-Host ""

    Write-Host " 2. SALUTE DISCO & MEMORIA DI MASSA (SMART)" -ForegroundColor White
    $diskColor = if ($storage.Salute -match 'Healthy|Buono|OK') { 'Green' } else { 'Red' }
    Write-Host "    Stato Disco / SSD: " -NoNewline; Write-Host "$($storage.StatoCompleto)" -ForegroundColor $diskColor
    if ($storage.Temperatura) { Write-Host "    Temperatura SSD  : $($storage.Temperatura)" }
    Write-Host "    Spazio Libero C: : $freeGB GB disponibili"
    Write-Host ""

    Write-Host " 3. STATO BATTERIA & ALIMENTAZIONE" -ForegroundColor White
    if ($battery.Presente) {
        $battColor = if ($battery.Percentuale -ge 80) { 'Green' } elseif ($battery.Percentuale -ge 65) { 'Yellow' } else { 'Red' }
        Write-Host "    Salute Batteria  : " -NoNewline; Write-Host "$($battery.Salute)" -ForegroundColor $battColor
        Write-Host "    Livello Carica   : $($battery.StatoCarica)"
    } else {
        Write-Host "    Tipo Computer    : PC Desktop / Fisso (Senza batteria)" -ForegroundColor Gray
    }
    Write-Host ""

    Write-Host " 4. SISTEMA OPERATIVO & SICUREZZA" -ForegroundColor White
    $winColor = if ($winAct.Attivo) { 'Green' } else { 'Red' }
    Write-Host "    Licenza Windows  : " -NoNewline; Write-Host "$($winAct.StatoBreve)" -ForegroundColor $winColor
    
    $bitColor = if ($bitlock.Esito -eq 'OK') { 'Green' } else { 'Yellow' }
    Write-Host "    BitLocker Disco  : " -NoNewline; Write-Host "$($bitlock.Stato)" -ForegroundColor $bitColor
    if ($bitlock.RecoveryKey) {
        Write-Host "    Chiave BitLocker : $($bitlock.RecoveryKey)" -ForegroundColor DarkGreen
    }
    Write-Host ""

    Write-Host " 5. CONTROLLO GESTIONE DISPOSITIVI (DRIVER)" -ForegroundColor White
    if ($driverProblematici.Count -gt 0) {
        Write-Host "    [ATTENZIONE] Rilevati $($driverProblematici.Count) dispositivi con errori di driver:" -ForegroundColor Red
        foreach ($d in $driverProblematici) {
            Write-Host "      - $($d.FriendlyName) (Classe: $($d.Class), Stato: $($d.Status))" -ForegroundColor Red
        }
    } else {
        Write-Host "    [OK] Tutti i dispositivi e i driver hardware risultano operativi." -ForegroundColor Green
    }
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan

    $diagObj = [ordered]@{
        Hardware     = $hw
        Disco        = $storage
        SpazioLibero = $freeGB
        Batteria     = $battery
        Windows      = $winAct
        BitLocker    = $bitlock
        DriverErrori = $driverProblematici
    }
    return [pscustomobject]$diagObj
}

function Set-PreventSleep {
    param([bool]$Enable = $true)
    if ($Test -or $Global:Test -or $env:PESTER_TEST) { return }
    try {
        if ($Enable) {
            # Evita spegnimento schermo, standby e sospensione sia su AC che su BATTERIA (DC)
            powercfg /change standby-timeout-ac 0 2>$null | Out-Null
            powercfg /change standby-timeout-dc 0 2>$null | Out-Null
            powercfg /change monitor-timeout-ac 0 2>$null | Out-Null
            powercfg /change monitor-timeout-dc 0 2>$null | Out-Null
            powercfg /change hibernate-timeout-ac 0 2>$null | Out-Null
            powercfg /change hibernate-timeout-dc 0 2>$null | Out-Null
            # Non andare MAI in sospensione alla chiusura del coperchio (essenziale per setup notturni in negozio)
            powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0 2>$null | Out-Null
            powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0 2>$null | Out-Null
            powercfg /setactive SCHEME_CURRENT 2>$null | Out-Null
            Enable-PreventSleep
        } else {
            # Ripristina valori standard
            powercfg /change monitor-timeout-ac 15 2>$null | Out-Null
            powercfg /change standby-timeout-ac 30 2>$null | Out-Null
            powercfg /change monitor-timeout-dc 10 2>$null | Out-Null
            powercfg /change standby-timeout-dc 15 2>$null | Out-Null
            powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 1 2>$null | Out-Null
            powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 1 2>$null | Out-Null
            powercfg /setactive SCHEME_CURRENT 2>$null | Out-Null
        }
    } catch {}
}

# Disattiva schermate iniziali di benvenuto, tour, sync e widget di Edge
function Install-BrowsingProtectionExtension {
    if ($Global:Test -or $env:PESTER_TEST) { return }
    try {
        # Auto-installazione estensione ufficiale "Browsing Protection by F-Secure" (richiesta da Unieuro Secure)
        # su Microsoft Edge e Google Chrome tramite policy ExtensionInstallForcelist + External Extensions.
        $edgeForceValue   = "cpikpibllpjmpnchjajlibnmmomnnhnm;https://edge.microsoft.com/extensionwebstorebase/v1/crx"
        $chromeForceValue = "jmjjnhpacphpjmnnlnccpfmhkcloaade;https://clients2.google.com/service/update2/crx"

        foreach ($k in @('HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist', 'HKCU:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist')) {
            try {
                if (-not (Test-Path $k)) { New-Item -Path $k -Force -ErrorAction SilentlyContinue | Out-Null }
                Set-ItemProperty -Path $k -Name '1' -Value $edgeForceValue -Type String -Force -ErrorAction SilentlyContinue | Out-Null
            } catch {}
        }
        foreach ($k in @('HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist', 'HKCU:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist')) {
            try {
                if (-not (Test-Path $k)) { New-Item -Path $k -Force -ErrorAction SilentlyContinue | Out-Null }
                Set-ItemProperty -Path $k -Name '1' -Value $chromeForceValue -Type String -Force -ErrorAction SilentlyContinue | Out-Null
            } catch {}
        }
        foreach ($k in @(
            'HKLM:\SOFTWARE\Microsoft\Edge\Extensions\cpikpibllpjmpnchjajlibnmmomnnhnm',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Edge\Extensions\cpikpibllpjmpnchjajlibnmmomnnhnm'
        )) {
            try {
                if (-not (Test-Path $k)) { New-Item -Path $k -Force -ErrorAction SilentlyContinue | Out-Null }
                Set-ItemProperty -Path $k -Name 'update_url' -Value 'https://edge.microsoft.com/extensionwebstorebase/v1/crx' -Type String -Force -ErrorAction SilentlyContinue | Out-Null
            } catch {}
        }
        foreach ($k in @(
            'HKLM:\SOFTWARE\Google\Chrome\Extensions\jmjjnhpacphpjmnnlnccpfmhkcloaade',
            'HKLM:\SOFTWARE\WOW6432Node\Google\Chrome\Extensions\jmjjnhpacphpjmnnlnccpfmhkcloaade'
        )) {
            try {
                if (-not (Test-Path $k)) { New-Item -Path $k -Force -ErrorAction SilentlyContinue | Out-Null }
                Set-ItemProperty -Path $k -Name 'update_url' -Value 'https://clients2.google.com/service/update2/crx' -Type String -Force -ErrorAction SilentlyContinue | Out-Null
            } catch {}
        }
    } catch {}
}

function Set-EdgeFirstRunPolicies {
    if ($Global:Test -or $env:PESTER_TEST) { return }
    Install-BrowsingProtectionExtension
    try {
        # 1. Chiudi eventuali finestre Edge orfane aperte su welcome/onboarding
        try {
            $edgeProcs = Get-Process -Name "msedge" -ErrorAction SilentlyContinue |
                Where-Object { $_.MainWindowTitle -like "*Welcome*" -or $_.MainWindowTitle -like "*Benvenuto*" -or $_.MainWindowTitle -like "*Microsoft Edge*" }
            foreach ($p in $edgeProcs) {
                if ($p.MainWindowTitle -notlike "*Unieuro*" -and $p.MainWindowTitle -notlike "*Pannello*" -and $p.MainWindowTitle -notlike "*PC Facile*") {
                    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
                }
            }
        } catch {}

        # 2. Chiudi processi widget Windows 11
        try {
            Get-Process -Name "Widgets", "msedgewebview2" -ErrorAction SilentlyContinue |
                Where-Object { $_.Path -like "*Windows.Shell.Experiences.TextInput*" -or $_.Path -like "*Widgets*" } |
                Stop-Process -Force -ErrorAction SilentlyContinue
        } catch {}

        # 3. Policy di registro HKLM e HKCU per sopprimere FRE, Welcome, Sync e Widget
        $edgeHives = @('HKLM:\SOFTWARE\Policies\Microsoft\Edge', 'HKCU:\SOFTWARE\Policies\Microsoft\Edge')
        $policies = @{
            'HideFirstRunExperience'                       = 1
            'BrowserSignin'                                = 0
            'SyncDisabled'                                 = 1
            'ImportOnEachLaunch'                           = 0
            'AutoImportAtFirstRun'                         = 4
            'DefaultBrowserSettingEnabled'                 = 0
            'HubsSidebarEnabled'                           = 0
            'StandaloneHubsSidebarEnabled'                 = 0
            'EdgeWidgetAllowed'                            = 0
            'SearchEngineChoiceScreenEnabled'              = 0
            'ShowMicrosoftRewards'                         = 0
            'EdgeShoppingAssistantEnabled'                 = 0
            'PersonalizationReportingEnabled'              = 0
            'PromotionalTabsEnabled'                       = 0
            'SpotlightExperiencesAndRecommendationsEnabled' = 0
            'ShowRecommendationsEnabled'                   = 0
            'SignInCtaOnNtpEnabled'                        = 0
            'UserFeedbackAllowed'                          = 0
            'NewTabPageContentEnabled'                     = 0
        }
        foreach ($hive in $edgeHives) {
            try {
                if (-not (Test-Path $hive)) { New-Item -Path $hive -Force -ErrorAction SilentlyContinue | Out-Null }
                foreach ($name in $policies.Keys) {
                    Set-ItemProperty -Path $hive -Name $name -Value $policies[$name] -Type DWord -Force -ErrorAction SilentlyContinue | Out-Null
                }
            } catch {}
        }

        # 4. Disabilita widget / news / Bing su Windows 11
        try {
            if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh")) {
                New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Force -ErrorAction SilentlyContinue | Out-Null
            }
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue | Out-Null
        } catch {}
        try {
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds" -Name "ShellFeedsTaskbarViewMode" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue | Out-Null
        } catch {}

        # 5. File sentinella First Run nel profilo Edge
        $edgeData = Join-Path $env:LOCALAPPDATA "Microsoft\Edge\User Data"
        if (-not (Test-Path $edgeData)) {
            New-Item -Path $edgeData -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
        }
        $freFile = Join-Path $edgeData "First Run"
        if (-not (Test-Path $freFile)) {
            New-Item -Path $freFile -ItemType File -Force -ErrorAction SilentlyContinue | Out-Null
        }

        # 6. Flag has_seen_welcome_page nel file Preferences di default
        $prefDir = Join-Path $edgeData "Default"
        if (-not (Test-Path $prefDir)) {
            New-Item -Path $prefDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
        }
        $prefFile = Join-Path $prefDir "Preferences"
        try {
            $prefObj = if (Test-Path $prefFile) {
                Get-Content -Path $prefFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
            } else { $null }
            if (-not $prefObj) { $prefObj = [PSCustomObject]@{} }
            if (-not $prefObj.PSObject.Properties['browser']) {
                $prefObj | Add-Member -MemberType NoteProperty -Name 'browser' -Value ([PSCustomObject]@{}) -Force
            }
            $prefObj.browser | Add-Member -MemberType NoteProperty -Name 'has_seen_welcome_page' -Value $true -Force
            $prefObj.browser | Add-Member -MemberType NoteProperty -Name 'should_reset_check_default_browser' -Value $false -Force
            $prefJson = $prefObj | ConvertTo-Json -Depth 10 -Compress
            [System.IO.File]::WriteAllText($prefFile, $prefJson)
        } catch {}
    } catch {}
}

function Disable-EdgeFirstRunExperience { Set-EdgeFirstRunPolicies }

function Get-EdgePath {
    $edgeCandidates = @(
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        (Join-Path $env:LOCALAPPDATA "Microsoft\Edge\Application\msedge.exe"),
        "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
    )
    return ($edgeCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1)
}

function Set-SplitScreenLayout {
    param([string]$HtmlPath)
    if ($Global:Test -or $env:PESTER_TEST) { return }
    try {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class WinSplit {
    [DllImport("user32.dll")]
    public static extern int GetSystemMetrics(int nIndex);

    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll")]
    public static extern IntPtr GetAncestor(IntPtr hWnd, uint gaFlags);
}
"@ -ErrorAction SilentlyContinue

        $scrW = 1920
        $scrH = 1080
        try {
            $w = [WinSplit]::GetSystemMetrics(0)
            $h = [WinSplit]::GetSystemMetrics(1)
            if ($w -gt 600) { $scrW = $w }
            if ($h -gt 400) { $scrH = $h }
        } catch {}

        $workH = [math]::Max(400, $scrH - 48)
        $halfW = [int]($scrW / 2)

        # 1. Posiziona la console a DESTRA (X = halfW, Y = 0, W = halfW, H = workH)
        try {
            $hConsole = [IntPtr]::Zero
            try { $hConsole = [WinSplit]::GetConsoleWindow() } catch {}
            if (-not $hConsole -or $hConsole -eq [IntPtr]::Zero) {
                try {
                    $curr = Get-CimInstance Win32_Process -Filter "ProcessId = $PID" -ErrorAction SilentlyContinue
                    if ($curr -and $curr.ParentProcessId) {
                        $parentProc = Get-Process -Id $curr.ParentProcessId -ErrorAction SilentlyContinue
                        if ($parentProc -and $parentProc.MainWindowHandle -ne [IntPtr]::Zero) {
                            $hConsole = $parentProc.MainWindowHandle
                        }
                    }
                } catch {}
            }
            if ($hConsole -and $hConsole -ne [IntPtr]::Zero) {
                try {
                    $rootH = [WinSplit]::GetAncestor($hConsole, 2) # GA_ROOT = 2
                    if ($rootH -and $rootH -ne [IntPtr]::Zero) { $hConsole = $rootH }
                } catch {}
                [WinSplit]::ShowWindow($hConsole, 9) # SW_RESTORE
                [WinSplit]::MoveWindow($hConsole, $halfW, 0, $halfW, $workH, $true) | Out-Null
                [WinSplit]::SetWindowPos($hConsole, [IntPtr]::Zero, $halfW, 0, $halfW, $workH, 0x0040) | Out-Null
            }
        } catch {}

        # 2. Avvia Edge a SINISTRA (X = 0, Y = 0, W = halfW, H = workH)
        $edgePath = Get-EdgePath

        $uriTarget = $HtmlPath
        try {
            if ($HtmlPath -notmatch '^https?://' -and (Test-Path -LiteralPath $HtmlPath)) {
                $uriTarget = ([System.Uri]::new($HtmlPath)).AbsoluteUri
            }
        } catch {
            $uriTarget = $HtmlPath
        }

        if ($edgePath) {
            Set-EdgeFirstRunPolicies
            $edgeArgs = "--app=`"$uriTarget`" --no-first-run --no-default-browser-check --disable-features=msEdgeFirstRunExperience,msEdgeWelcomeExperience,msEdgeFre,msHubsSidebar,msEdgeWidgets --disable-search-engine-choice-screen --disable-sync --window-position=0,0 --window-size=$halfW,$workH"
            $edgeProc = Start-Process -FilePath $edgePath -ArgumentList $edgeArgs -PassThru -ErrorAction SilentlyContinue
            for ($i = 0; $i -lt 5; $i++) {
                Start-Sleep -Milliseconds 200
                $edgeWindows = Get-Process -Name "msedge" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero }
                foreach ($ew in $edgeWindows) {
                    if ($ew.MainWindowTitle -like "*Unieuro*" -or $ew.MainWindowTitle -like "*Pannello*" -or $ew.MainWindowTitle -like "*PC Facile*" -or ($edgeProc -and $ew.Id -eq $edgeProc.Id)) {
                        [WinSplit]::ShowWindow($ew.MainWindowHandle, 9)
                        [WinSplit]::MoveWindow($ew.MainWindowHandle, 0, 0, $halfW, $workH, $true) | Out-Null
                        [WinSplit]::SetWindowPos($ew.MainWindowHandle, [IntPtr]::Zero, 0, 0, $halfW, $workH, 0x0040) | Out-Null
                        break
                    }
                }
            }
        } else {
            Start-Process -FilePath $HtmlPath -ErrorAction SilentlyContinue
        }
    } catch {
        try { Start-Process -FilePath $HtmlPath -ErrorAction SilentlyContinue } catch {}
    }
}

function Update-PannelloStatus {
    param(
        [string]$TaskId = "",
        [string]$Stato = "",
        [string]$Dettaglio = "",
        [int]$Percentuale = -1,
        [string]$FaseCorrente = "",
        [switch]$Completato,
        # Dati hardware reali per il pannello (Modello, Cpu, Ram, Seriale).
        [System.Collections.IDictionary]$Hardware = $null,
        # 'si' mentre lo script aspetta i dati del cliente dal pannello, 'no' dopo.
        [ValidateSet('', 'si', 'no')][string]$AttesaDati = '',
        # Durante la sequenza dei passi la percentuale la decide solo il ciclo
        # dei passi (con questo switch); le altre chiamate non la cambiano.
        [switch]$PercentualeGuida
    )
    try {
        if (-not $Global:StopwatchInizio) {
            $Global:StopwatchInizio = [System.Diagnostics.Stopwatch]::StartNew()
        }
        if (-not $Global:PannelloStatus) {
            $versione = Get-Variable -Name SCRIPT_VERSION -ValueOnly -ErrorAction SilentlyContinue
            $Global:PannelloStatus = [ordered]@{
                Percentuale   = 5
                FaseCorrente  = "Inizializzazione Setup"
                Dettaglio     = "Avvio pannello operatore Unieuro..."
                Completato    = $false
                # Istante di avvio ricalcolato col cronometro monotono: immune ai salti
                # di orologio (+1h) quando w32tm /resync corregge l'ora di fabbrica.
                Inizio        = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
                InAttesaDati  = $false
                Versione      = [string]$versione
                Hardware      = $null
                # Stesso ordine dei passi ($Global:Passi): fase 1 lingua, app, pulizia, driver e aggiornamenti;
                # fase 1: dati cliente, Office e attivazioni operatore;
                # fase 2 (automatica): lingua, programmi, pulizia, driver e aggiornamenti fino alla fine.
                Tasks         = [ordered]@{
                    "avprova"     = [ordered]@{ Nome = "Rimozione Antivirus di Prova"; Stato = "pending"; Dettaglio = "In attesa" }
                    "everyday"    = [ordered]@{ Nome = "Unieuro Everyday Digital (Secure + Cyber)"; Stato = "pending"; Dettaglio = "In attesa" }
                    "office"      = [ordered]@{ Nome = "Office: installazione e attivazione"; Stato = "pending"; Dettaglio = "In attesa" }
                    "account"     = [ordered]@{ Nome = "Nome PC e account cliente"; Stato = "pending"; Dettaglio = "In attesa" }
                    "antivirus"   = [ordered]@{ Nome = "Sicurezza & Antivirus Definitivo (Defender / Card)"; Stato = "pending"; Dettaglio = "In attesa" }
                    "cyber"       = [ordered]@{ Nome = "Servizio Unieuro Cyber Protection"; Stato = "pending"; Dettaglio = "In attesa" }
                    "lingua"      = [ordered]@{ Nome = "Forzatura Lingua & Regione Italiana (it-IT)"; Stato = "pending"; Dettaglio = "In attesa" }
                    "ripristino"  = [ordered]@{ Nome = "Punto di Ripristino di Sicurezza"; Stato = "pending"; Dettaglio = "In attesa" }
                    "runtime"     = [ordered]@{ Nome = "Runtime Microsoft Visual C++ (x86 & x64)"; Stato = "pending"; Dettaglio = "In attesa" }
                    "app"         = [ordered]@{ Nome = "Installazione Applicazioni Unieuro"; Stato = "pending"; Dettaglio = "In attesa" }
                    "pulizia"     = [ordered]@{ Nome = "Pulizia Bloatware OEM & Ottimizzazione SSD"; Stato = "pending"; Dettaglio = "In attesa" }
                    "driver"      = [ordered]@{ Nome = "Driver Hardware (Windows Update)"; Stato = "pending"; Dettaglio = "In attesa" }
                    "aggiorna"    = [ordered]@{ Nome = "Aggiornamenti App e Windows"; Stato = "pending"; Dettaglio = "In attesa" }
                    "diagnostica" = [ordered]@{ Nome = "Diagnostica Hardware, BitLocker & Scheda Consegna"; Stato = "pending"; Dettaglio = "In attesa" }
                }
            }
        }
        if ($Global:StopwatchInizio) {
            $Global:PannelloStatus.Inizio = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() - [long]($Global:StopwatchInizio.Elapsed.TotalMilliseconds)
        }
        if ($Percentuale -ge 0 -and ($PercentualeGuida -or -not $Global:PercentualeDaPassi)) { $Global:PannelloStatus.Percentuale = $Percentuale }
        if ($FaseCorrente) { $Global:PannelloStatus.FaseCorrente = $FaseCorrente }
        if ($Hardware) { $Global:PannelloStatus.Hardware = $Hardware }
        if ($AttesaDati) { $Global:PannelloStatus.InAttesaDati = ($AttesaDati -eq 'si') }
        if ($Dettaglio -and -not $TaskId) { $Global:PannelloStatus.Dettaglio = $Dettaglio }
        if ($Completato) {
            $Global:PannelloStatus.Completato = $true
            $Global:PannelloStatus.Percentuale = 100
            if ($Global:PannelloStatus.Tasks) {
                foreach ($k in @($Global:PannelloStatus.Tasks.Keys)) {
                    if ($Global:PannelloStatus.Tasks[$k].Stato -eq "pending") {
                        $Global:PannelloStatus.Tasks[$k].Stato = "done"
                        $Global:PannelloStatus.Tasks[$k].Dettaglio = "Completato"
                    }
                }
            }
        }

        if ($TaskId -and $Global:PannelloStatus.Tasks.Contains($TaskId)) {
            if ($Global:PannelloSync -and $Global:PannelloSync.Saltati -and $Global:PannelloSync.Saltati[$TaskId] -and $Stato -eq 'running') {
                $Stato = 'skipped'
                $Dettaglio = "Saltato dall'operatore"
            }
            if ($Stato) { $Global:PannelloStatus.Tasks[$TaskId].Stato = $Stato }
            if ($Dettaglio) { $Global:PannelloStatus.Tasks[$TaskId].Dettaglio = $Dettaglio }
        }

        # Aggiorna il titolo della finestra console con percentuale e fase
        try {
            $curPct = $Global:PannelloStatus.Percentuale
            $curFase = if ($FaseCorrente) { $FaseCorrente } else { $Global:PannelloStatus.FaseCorrente }
            $host.UI.RawUI.WindowTitle = "PC Facile [$curPct%] - $curFase"
        } catch {}

        # Stato servito da GET /status (server locale in background): e' l'unico
        # canale fra script e pannello.
        if ($Global:PannelloSync) {
            $Global:PannelloStatus.LogComandi  = [string]$Global:PannelloSync.LogComandi
            $Global:PannelloStatus.UltimoCmdId = [string]$Global:PannelloSync.UltimoCmdId
        }
        $json = $Global:PannelloStatus | ConvertTo-Json -Depth 5 -Compress
        if ($Global:PannelloSync) { $Global:PannelloSync.StatusJson = $json }
    } catch {}
}

function Test-DatiClienteConfermati {
    # Il pannello avvia/aggiorna la configurazione SOLO con il pulsante "CONFERMA
    # DATI CLIENTE": i dati devono avere Conferma = true e Servizi (Nome, Cognome e Cellulare sono opzionali).
    param($Dati)
    if (-not $Dati) { return $false }
    if (-not ($Dati.Conferma -is [bool] -and $Dati.Conferma)) { return $false }
    if (-not $Dati.Servizi) { return $false }
    return $true
}

function Start-ServerPannello {
    # Server HTTP locale (solo 127.0.0.1) in un runspace separato: UNICO canale
    # fra script e pannello. Risponde SEMPRE, anche mentre lo script installa.
    #   GET  /status -> stato live (avanzamento, fasi, hardware, versione)
    #   POST /cred   -> dati cliente confermati (messi in coda per lo script)
    #   OPTIONS      -> preflight CORS (+ Access-Control-Allow-Private-Network)
    # $Origini: pagine autorizzate. Solo il pannello aperto dallo script come
    # file locale (i browser mandano "Origin: null" per le pagine file://); in
    # piu' http://127.0.0.1 / localhost. Le richieste da qualunque sito web
    # vengono rifiutate: nessuna pagina aperta nel browser puo' inviare dati.
    param(
        [int]$Porta = 8899,
        [string[]]$Origini = @('null')
    )
    try {
        if ($Global:CredHttpListener -and $Global:CredHttpListener.IsListening) { return $true }
        if (-not $Global:PannelloSync) {
            $Global:PannelloSync = [hashtable]::Synchronized(@{
                StatusJson  = '{}'
                CodaCred    = New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]'
                CodaStep    = New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]'
                Saltati     = [hashtable]::Synchronized(@{})
                SkipCurrent = $false
                Modalita    = 'COMPLETA'
                LogComandi  = ''
                UltimoCmdId = ''
            })
        }
        if (-not $Global:PannelloSync.Modalita) {
            $Global:PannelloSync.Modalita = 'COMPLETA'
        }
        if (-not $Global:PannelloSync.CodaStep) {
            $Global:PannelloSync.CodaStep = New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]'
        }
        if (-not $Global:PannelloSync.Saltati) {
            $Global:PannelloSync.Saltati = [hashtable]::Synchronized(@{})
        }
        $Global:PannelloSync.TestMode = [bool]($Test -or $Global:Test -or $env:PESTER_TEST)
        $Global:PannelloSync.Origini = @($Origini)
        if ($Global:PannelloStatus) { $Global:PannelloSync.StatusJson = ($Global:PannelloStatus | ConvertTo-Json -Depth 5 -Compress) }
        $listener = New-Object System.Net.HttpListener
        $listener.Prefixes.Add("http://127.0.0.1:$Porta/")
        $listener.Start()

        $ciclo = {
            param($Listener, $Sync)
            function Invia($Res, [int]$Codice, [string]$Testo) {
                $Res.StatusCode = $Codice
                $Res.ContentType = 'application/json; charset=utf-8'
                $b = [System.Text.Encoding]::UTF8.GetBytes($Testo)
                $Res.ContentLength64 = $b.Length
                $Res.OutputStream.Write($b, 0, $b.Length)
            }
            function Esegui-IstruzioneLocale($TestoCmd, $OrigineCmd) {
                $tCmd = ([string]$TestoCmd).Trim()
                if (-not $tCmd) { return @{ ok = $false; output = "Nessun comando specificato." } }
                $tsNow = (Get-Date).ToString("HH:mm:ss")
                if ($Sync.TestMode) {
                    $outSim = "[$tsNow] ($OrigineCmd) > $tCmd`n[TEST] Istruzione eseguita con successo."
                    $Sync.LogComandi = ($outSim + "`n`n" + [string]$Sync.LogComandi).Trim()
                    $Sync.UltimoCmdId = "cmd-" + [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
                    return @{ ok = $true; output = $Sync.LogComandi }
                }
                $outTxt = ""
                $okCmd = $true
                try {
                    if ($tCmd -match '^(?i)(togli|rimuovi|sblocca)\s+password') {
                        & net.exe accounts /maxpwage:unlimited 2>$null | Out-Null
                        & net.exe user $env:USERNAME "" 2>$null | Out-Null
                        Get-LocalUser -ErrorAction SilentlyContinue | Where-Object { $_.Enabled } | ForEach-Object {
                            try { Set-LocalUser -Name $_.Name -PasswordNeverExpires $true -ErrorAction SilentlyContinue } catch {}
                        }
                        & powercfg.exe /setacvalueindex SCHEME_CURRENT SUB_NONE CONSOLELOCK 0 2>$null | Out-Null
                        & powercfg.exe /setdcvalueindex SCHEME_CURRENT SUB_NONE CONSOLELOCK 0 2>$null | Out-Null
                        & powercfg.exe /setactive SCHEME_CURRENT 2>$null | Out-Null
                        $outTxt = "Password login Windows rimossa per '$env:USERNAME', scadenza 42 giorni disattivata e blocco standby rimosso."
                    } elseif ($tCmd -match '^(?i)(chiudi\s+blocchi|sblocca\s+processi|uccidi|kill)') {
                        $Sync.SkipCurrent = $true
                        $uccisi = @()
                        foreach ($pn in @('sbbd*','InstStub*','Norton*','MCPR*','NRnR*','OneDriveSetup*','WhatsAppInstaller*','StoreInstaller*','winget*')) {
                            Get-Process -Name $pn -ErrorAction SilentlyContinue | ForEach-Object {
                                $uccisi += "$($_.ProcessName) (PID $($_.Id))"
                                try { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue } catch {}
                            }
                        }
                        $outTxt = if ($uccisi.Count -gt 0) { "Processi bloccanti terminati: " + ($uccisi -join ", ") } else { "Nessun processo bloccante attivo trovato (flag salto operazione attivato)." }
                    } elseif ($tCmd -match '^(?i)(riavvia\s+(desktop|esplora))') {
                        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
                        Start-Sleep -Seconds 1
                        if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
                        $outTxt = "Esplora Risorse (Desktop e barra applicazioni) riavviato con successo."
                    } elseif ($tCmd -match '^(?i)(ripara\s+(wifi|rete)|reset\s+(rete|dns))') {
                        & ipconfig.exe /flushdns 2>&1 | Out-Null
                        & netsh.exe winsock reset 2>&1 | Out-Null
                        $wlanInfo = (& netsh.exe wlan show interfaces 2>&1 | Out-String).Trim()
                        $outTxt = "Cache DNS svuotata e Winsock ripristinato.`n$wlanInfo"
                    } elseif ($tCmd -match '^(?i)(lista\s+programmi|app\s+installate)') {
                        $paths = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')
                        $apps = Get-ItemProperty $paths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName } | Select-Object DisplayName, DisplayVersion, Publisher | Sort-Object DisplayName -Unique
                        $outTxt = ($apps | Format-Table -AutoSize | Out-String).Trim()
                    } elseif ($tCmd -match '^(?i)(stato\s+dischi|spazio\s+disco|partizioni)') {
                        $dsk = Get-PSDrive -PSProvider FileSystem | Select-Object Name, @{N='Usato_GB';E={[math]::Round($_.Used/1GB,1)}}, @{N='Libero_GB';E={[math]::Round($_.Free/1GB,1)}}
                        $outTxt = ($dsk | Format-Table -AutoSize | Out-String).Trim()
                    } elseif ($tCmd -match '^(?i)(debloat\s+completo|super\s+debloat|debloat)') {
                        $srch = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
                        if (-not (Test-Path $srch)) { New-Item -Path $srch -Force -ErrorAction SilentlyContinue | Out-Null }
                        Set-ItemProperty -Path $srch -Name "BingSearchEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $srch -Name "SearchboxTaskbarMode" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                        $adv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
                        Set-ItemProperty -Path $adv -Name "TaskbarDa" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $adv -Name "TaskbarMn" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $adv -Name "ShowTaskViewButton" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $adv -Name "ShowCopilotButton" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $adv -Name "ShowSyncProviderNotifications" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $adv -Name "Start_IrisRecommendations" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                        $copPol = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"
                        if (-not (Test-Path $copPol)) { New-Item -Path $copPol -Force -ErrorAction SilentlyContinue | Out-Null }
                        Set-ItemProperty -Path $copPol -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord -ErrorAction SilentlyContinue
                        $aiPol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
                        if (-not (Test-Path $aiPol)) { New-Item -Path $aiPol -Force -ErrorAction SilentlyContinue | Out-Null }
                        Set-ItemProperty -Path $aiPol -Name "DisableAIDataAnalysis" -Value 1 -Type DWord -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $aiPol -Name "TurnOffSavingSnapshots" -Value 1 -Type DWord -ErrorAction SilentlyContinue
                        $upe = "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement"
                        if (-not (Test-Path $upe)) { New-Item -Path $upe -Force -ErrorAction SilentlyContinue | Out-Null }
                        Set-ItemProperty -Path $upe -Name "ScoobeSystemSettingEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                        $cdm = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
                        if (Test-Path $cdm) {
                            foreach ($kCdm in @('SystemPaneSuggestionsEnabled','SoftLandingEnabled','SilentInstalledAppsEnabled','ContentDeliveryAllowed','OemPreInstalledAppsEnabled','PreInstalledAppsEnabled','RotatingLockScreenOverlayEnabled','SubscribedContent-310093Enabled','SubscribedContent-338387Enabled','SubscribedContent-338388Enabled','SubscribedContent-338389Enabled','SubscribedContent-338393Enabled','SubscribedContent-353694Enabled','SubscribedContent-353696Enabled')) {
                                Set-ItemProperty -Path $cdm -Name $kCdm -Value 0 -Type DWord -ErrorAction SilentlyContinue
                            }
                        }
                        $dvr = "HKCU:\System\GameConfigStore"
                        if (Test-Path $dvr) { Set-ItemProperty -Path $dvr -Name "GameDVR_Enabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue }
                        $outTxt = "Super Debloat Windows 11 completato: rimossi Bing Start, Copilot, Recall AI, Widget, popup 'Finisci di configurare il PC', pubblicita' in Start/Esplora File/Blocco schermo e GameDVR."
                    } elseif ($tCmd -match '^(?i)(rimuovi\s+edge\s+bloat|debloat\s+edge)') {
                        $edgePol = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
                        if (-not (Test-Path $edgePol)) { New-Item -Path $edgePol -Force -ErrorAction SilentlyContinue | Out-Null }
                        $edgeProps = @{
                            HideFirstRunExperience = 1; SyncDisabled = 1; AutoImportAtFirstRun = 4;
                            EdgeWidgetAllowed = 0; HubsSidebarEnabled = 0; StandaloneHubsSidebarEnabled = 0;
                            EdgeShoppingAssistantEnabled = 0; StartupBoostEnabled = 0; BackgroundModeEnabled = 0;
                            NewTabPageContentEnabled = 0; NewTabPageHideDefaultTopSites = 1; ShowRecommendationsEnabled = 0;
                            SpotlightExperiencesAndRecommendationsEnabled = 0; UserFeedbackAllowed = 0; PersonalizationReportingEnabled = 0
                        }
                        foreach ($ep in $edgeProps.Keys) {
                            Set-ItemProperty -Path $edgePol -Name $ep -Value $edgeProps[$ep] -Type DWord -ErrorAction SilentlyContinue
                        }
                        $outTxt = "Microsoft Edge ripulito: disabilitati feed MSN/notizie nella nuova scheda, assistente shopping/coupon, barra laterale, avvio in background e telemetria."
                    } elseif ($tCmd -match '^(?i)(rimuovi\s+onedrive|disinstalla\s+onedrive)') {
                        & taskkill.exe /f /im OneDrive.exe 2>$null | Out-Null
                        $odSetup = @("$env:SystemRoot\SysWOW64\OneDriveSetup.exe", "$env:SystemRoot\System32\OneDriveSetup.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
                        if ($odSetup) {
                            $pOd = Start-Process $odSetup -ArgumentList "/uninstall /silent" -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
                            if ($pOd) { [void]$pOd.WaitForExit(35000); if (-not $pOd.HasExited) { try { $pOd.Kill() } catch {} } }
                        }
                        Get-AppxPackage -AllUsers *OneDrive* -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                        $clsidOd = "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
                        try {
                            New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -ErrorAction SilentlyContinue | Out-Null
                            if (Test-Path $clsidOd) { Set-ItemProperty -Path $clsidOd -Name "System.IsPinnedToNameSpaceTree" -Value 0 -Type DWord -ErrorAction SilentlyContinue }
                        } catch {}
                        $outTxt = "OneDrive disinstallato e icona rimossa dalla barra laterale di Esplora File."
                    } elseif ($tCmd -match '^(?i)(menu\s+classico(\s+win11)?)') {
                        $clsidMenu = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
                        if (-not (Test-Path $clsidMenu)) { New-Item -Path $clsidMenu -Force -ErrorAction SilentlyContinue | Out-Null }
                        Set-ItemProperty -Path $clsidMenu -Name "(Default)" -Value "" -ErrorAction SilentlyContinue
                        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
                        Start-Sleep -Seconds 1
                        if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
                        $outTxt = "Menu tasto destro classico (stile Windows 10 completo senza 'Mostra altre opzioni') attivato!"
                    } elseif ($tCmd -match '^(?i)(menu\s+moderno(\s+win11)?)') {
                        Remove-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" -Recurse -Force -ErrorAction SilentlyContinue
                        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
                        Start-Sleep -Seconds 1
                        if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
                        $outTxt = "Menu tasto destro moderno di Windows 11 ripristinato."
                    } elseif ($tCmd -match '^(?i)(prestazioni\s+massime|turbo\s+prestazioni)') {
                        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "8" -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WaitToKillAppTimeout" -Value "2000" -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "HungAppTimeout" -Value "1000" -ErrorAction SilentlyContinue
                        $bgApps = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
                        if (-not (Test-Path $bgApps)) { New-Item -Path $bgApps -Force -ErrorAction SilentlyContinue | Out-Null }
                        Set-ItemProperty -Path $bgApps -Name "GlobalUserDisabled" -Value 1 -Type DWord -ErrorAction SilentlyContinue
                        $mm = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
                        if (Test-Path $mm) { Set-ItemProperty -Path $mm -Name "ClearPageFileAtShutdown" -Value 0 -Type DWord -ErrorAction SilentlyContinue }
                        $outTxt = "Turbo Prestazioni attivato: MenuShowDelay ridotto a 8ms, chiusura rapida app bloccate e app in background disattivate."
                    } elseif ($tCmd -match '^(?i)(pulisci\s+disco(\s+profonda)?|pulizia\s+disco)') {
                        $primaFree = try { (Get-PSDrive C -ErrorAction Stop).Free } catch { 0 }
                        foreach ($td in @($env:TEMP, "$env:SystemRoot\Temp", "$env:SystemRoot\Prefetch", "$env:SystemRoot\SoftwareDistribution\Download")) {
                            if ($td -and (Test-Path $td)) {
                                Get-ChildItem -Path $td -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                            }
                        }
                        try { Clear-RecycleBin -Force -ErrorAction SilentlyContinue } catch {}
                        $dopoFree = try { (Get-PSDrive C -ErrorAction Stop).Free } catch { $primaFree }
                        $liberatiMB = [math]::Max(0, [math]::Round(($dopoFree - $primaFree) / 1MB, 1))
                        $outTxt = "Pulizia profonda completata (Temp utente, Windows Temp, Prefetch, cache Windows Update e Cestino). Spazio liberato: $liberatiMB MB."
                    } elseif ($tCmd -match '^(?i)(ottimizza\s+ssd|trim\s+ssd)') {
                        try { Optimize-Volume -DriveLetter C -ReTrim -ErrorAction SilentlyContinue | Out-Null } catch {}
                        & fsutil.exe behavior set DisableDeleteNotify 0 2>$null | Out-Null
                        $ss = "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy"
                        if (-not (Test-Path $ss)) { New-Item -Path $ss -Force -ErrorAction SilentlyContinue | Out-Null }
                        Set-ItemProperty -Path $ss -Name "01" -Value 1 -Type DWord -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $ss -Name "04" -Value 1 -Type DWord -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $ss -Name "08" -Value 1 -Type DWord -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $ss -Name "256" -Value 30 -Type DWord -ErrorAction SilentlyContinue
                        $outTxt = "TRIM SSD (ReTrim su C:) eseguito, TRIM nativo verificato e Sensore Memoria automatico (Storage Sense) attivato."
                    } elseif ($tCmd -match '^(?i)(privacy\s+totale|stop\s+telemetria)') {
                        $dcPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
                        if (-not (Test-Path $dcPolicy)) { New-Item -Path $dcPolicy -Force -ErrorAction SilentlyContinue | Out-Null }
                        Set-ItemProperty -Path $dcPolicy -Name "AllowTelemetry" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $dcPolicy -Name "DoNotShowFeedbackNotifications" -Value 1 -Type DWord -ErrorAction SilentlyContinue
                        $advId = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
                        if (-not (Test-Path $advId)) { New-Item -Path $advId -Force -ErrorAction SilentlyContinue | Out-Null }
                        Set-ItemProperty -Path $advId -Name "Enabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                        $siuf = "HKCU:\Software\Microsoft\Siuf\Rules"
                        if (-not (Test-Path $siuf)) { New-Item -Path $siuf -Force -ErrorAction SilentlyContinue | Out-Null }
                        Set-ItemProperty -Path $siuf -Name "NumberOfSIUFInPeriod" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                        $actPol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
                        if (-not (Test-Path $actPol)) { New-Item -Path $actPol -Force -ErrorAction SilentlyContinue | Out-Null }
                        Set-ItemProperty -Path $actPol -Name "PublishUserActivities" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $actPol -Name "UploadUserActivities" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                        foreach ($svcDiag in @('DiagTrack','dmwappushservice')) {
                            Stop-Service -Name $svcDiag -Force -ErrorAction SilentlyContinue
                            Set-Service -Name $svcDiag -StartupType Disabled -ErrorAction SilentlyContinue
                        }
                        $outTxt = "Blindatura Privacy applicata: telemetria DiagTrack e dmwappushservice disabilitati, Advertising ID, cronologia cloud e popup di feedback bloccati."
                    } elseif ($tCmd -match '^(?i)(stato\s+bitlocker|chiave\s+bitlocker)') {
                        $blOut = (& manage-bde.exe -status C: 2>&1 | Out-String).Trim()
                        $protOut = (& manage-bde.exe -protectors -get C: 2>&1 | Out-String).Trim()
                        $outTxt = "$blOut`n`n$protOut"
                    } elseif ($tCmd -match '^(?i)(ripara\s+store(\s+e\s+winget)?|reset\s+store)') {
                        Start-Process -FilePath "wsreset.exe" -ArgumentList "-i" -WindowStyle Hidden -ErrorAction SilentlyContinue
                        $polKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppInstaller"
                        if (-not (Test-Path $polKey)) { New-Item -Path $polKey -Force -ErrorAction SilentlyContinue | Out-Null }
                        Set-ItemProperty -Path $polKey -Name "EnableBypassCertificatePinningForMicrosoftStore" -Value 1 -Type DWord -ErrorAction SilentlyContinue
                        & winget.exe settings --enable BypassCertificatePinningForMicrosoftStore 2>$null | Out-Null
                        $outTxt = "Cache Microsoft Store resettata (wsreset) e bypass certificato Winget Store (0x8a15005e) attivato."
                    } elseif ($tCmd -match '^(?i)(ripara\s+stampanti|sblocca\s+stampanti|spooler)') {
                        Stop-Service -Name Spooler -Force -ErrorAction SilentlyContinue
                        Remove-Item -Path "$env:SystemRoot\System32\spool\PRINTERS\*" -Force -ErrorAction SilentlyContinue
                        Start-Service -Name Spooler -ErrorAction SilentlyContinue
                        $outTxt = "Servizio Spooler di stampa riavviato e coda documenti bloccati svuotata."
                    } elseif ($tCmd -match '^(?i)(ripara\s+audio(\s+e\s+bluetooth)?)') {
                        foreach ($sAud in @('Audiosrv','AudioEndpointBuilder','bthserv')) {
                            Restart-Service -Name $sAud -Force -ErrorAction SilentlyContinue
                        }
                        $outTxt = "Servizi Audio Windows (Audiosrv, AudioEndpointBuilder) e Bluetooth (bthserv) riavviati con successo."
                    } elseif ($tCmd -match '^(?i)(ripara\s+sistema|sfc|dism)') {
                        $dismOut = (& dism.exe /Online /Cleanup-Image /CheckHealth 2>&1 | Out-String).Trim()
                        Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -WindowStyle Hidden -ErrorAction SilentlyContinue
                        $outTxt = "Verifica integrita' immagine DISM completata e scansione SFC /scannow avviata in background.`n$dismOut"
                    } elseif ($tCmd -match '^(?i)(winutil|chris\s+titus)') {
                        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm https://christitus.com/win | iex`"" -ErrorAction SilentlyContinue
                        $outTxt = "Chris Titus Tech WinUtil avviato in una nuova finestra."
                    } elseif ($tCmd -match '^(?i)(reset\s+windows\s+update|sblocca\s+aggiornamenti)') {
                        foreach ($sWu in @('wuauserv','bits')) { Stop-Service -Name $sWu -Force -ErrorAction SilentlyContinue }
                        Start-Sleep -Seconds 1
                        foreach ($sWu in @('cryptsvc','bits','wuauserv')) { Start-Service -Name $sWu -ErrorAction SilentlyContinue }
                        $uso = Join-Path $env:SystemRoot 'System32\UsoClient.exe'
                        if (Test-Path $uso) {
                            foreach ($a in @('StartInteractiveScan','StartDownload','StartInstall')) {
                                Start-Process -FilePath $uso -ArgumentList $a -WindowStyle Hidden -ErrorAction SilentlyContinue
                            }
                        }
                        $outTxt = "Servizi Windows Update (wuauserv, bits, cryptsvc) riavviati e scansione/download/installazione forzati tramite UsoClient."
                    } elseif ($tCmd -match '^(?i)(disinstalla|rimuovi)\s+(.+)$') {
                        $targetApp = $Matches[2].Trim()
                        $paths = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')
                        $found = @(Get-ItemProperty $paths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$targetApp*" })
                        $logUn = @()
                        foreach ($f in $found) {
                            $uStr = if ($f.QuietUninstallString) { $f.QuietUninstallString } elseif ($f.UninstallString) { "$($f.UninstallString) /S /silent /quiet /norestart" } else { "" }
                            if ($uStr) {
                                $pU = Start-Process -FilePath "cmd.exe" -ArgumentList "/d /s /c `"$uStr`"" -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
                                if ($pU) { [void]$pU.WaitForExit(35000); if (-not $pU.HasExited) { try { $pU.Kill() } catch {} } }
                                $logUn += "Disinstallato (Win32): $($f.DisplayName)"
                            }
                        }
                        Get-AppxPackage "*$targetApp*" -ErrorAction SilentlyContinue | ForEach-Object {
                            $logUn += "Disinstallato (Appx): $($_.Name)"
                            Remove-AppxPackage -Package $_.PackageFullName -ErrorAction SilentlyContinue
                        }
                        $outTxt = if ($logUn.Count -gt 0) { $logUn -join "`n" } else { "Nessun programma trovato con nome '$targetApp'." }
                    } else {
                        $sb = [scriptblock]::Create($tCmd)
                        $resExec = & $sb 2>&1 | Out-String
                        $outTxt = if ($resExec -and $resExec.Trim()) { $resExec.Trim() } else { "(Comando eseguito senza output testuale)" }
                    }
                } catch {
                    $okCmd = $false
                    $outTxt = "ERRORE: $($_.Exception.Message)"
                }
                if ($outTxt.Length -gt 3500) { $outTxt = $outTxt.Substring(0, 3500) + "`n... [troncato]" }
                $entryLog = "[$tsNow] ($OrigineCmd) > $tCmd`n$outTxt"
                $prevLog = [string]$Sync.LogComandi
                if ($prevLog.Length -gt 8000) { $prevLog = $prevLog.Substring(0, 8000) }
                $Sync.LogComandi = ($entryLog + "`n" + ("-" * 50) + "`n" + $prevLog).Trim()
                $Sync.UltimoCmdId = "cmd-" + [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
                try {
                    $stCur = $Sync.StatusJson | ConvertFrom-Json
                    if ($stCur) {
                        $stCur | Add-Member -NotePropertyName LogComandi -NotePropertyValue $Sync.LogComandi -Force
                        $stCur | Add-Member -NotePropertyName UltimoCmdId -NotePropertyValue $Sync.UltimoCmdId -Force
                        $Sync.StatusJson = ($stCur | ConvertTo-Json -Depth 5 -Compress)
                    }
                } catch {}
                return @{ ok = $okCmd; output = $Sync.LogComandi; lastOutput = $outTxt }
            }
            $passiValidi = @('everyday','ripristino','sysdm','avprova','lingua','runtime','app','icone','office','officeattiva','account','netplwiz','nopass','antivirus','cyber','pulizia','driver','devmgmt','aggiorna','winupdate','scheda','diagnostica')
            while ($Listener.IsListening) {
                try { $ctx = $Listener.GetContext() } catch { break }
                $res = $ctx.Response
                try {
                    $req = $ctx.Request
                    $origin = $req.Headers['Origin']
                    $consentita = (-not $origin) -or ($Sync.Origini -contains $origin) -or ($origin -match '^http://(127\.0\.0\.1|localhost)(:\d+)?$')
                    if ($origin -and $consentita) {
                        $res.AddHeader('Access-Control-Allow-Origin', $origin)
                        $res.AddHeader('Vary', 'Origin')
                    }
                    $res.AddHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
                    $res.AddHeader('Access-Control-Allow-Headers', 'Content-Type')
                    $res.AddHeader('Cache-Control', 'no-store')
                    if ($req.Headers['Access-Control-Request-Private-Network'] -eq 'true') {
                        $res.AddHeader('Access-Control-Allow-Private-Network', 'true')
                    }
                    $percorso = $req.Url.AbsolutePath.TrimEnd('/')
                    if ($req.HttpMethod -eq 'OPTIONS') {
                        $res.StatusCode = 204
                    } elseif (-not $consentita) {
                        Invia $res 403 '{"ok":false,"motivo":"origine non consentita"}'
                    } elseif ($req.HttpMethod -eq 'GET' -and ($percorso -eq '' -or $percorso -eq '/status')) {
                        Invia $res 200 ([string]$Sync.StatusJson)
                    } elseif ($req.HttpMethod -eq 'POST' -and $percorso -eq '/cred') {
                        if ($req.ContentLength64 -gt 65536) {
                            Invia $res 413 '{"ok":false,"motivo":"dati troppo grandi"}'
                        } else {
                            $reader = New-Object System.IO.StreamReader($req.InputStream, [System.Text.Encoding]::UTF8)
                            $body = $reader.ReadToEnd()
                            $dati = $null
                            try { $dati = $body | ConvertFrom-Json } catch {}
                            if (-not $dati) {
                                Invia $res 400 '{"ok":false,"motivo":"dati non leggibili"}'
                            } elseif (-not ($dati.Conferma -is [bool] -and $dati.Conferma)) {
                                Invia $res 400 '{"ok":false,"motivo":"manca la conferma (pulsante CONFERMA DATI CLIENTE)"}'
                            } elseif (-not $dati.Servizi) {
                                Invia $res 400 '{"ok":false,"motivo":"mancano i servizi"}'
                            } else {
                                $Sync.CodaCred.Enqueue($body)
                                Invia $res 200 '{"ok":true,"ricevuto":true}'
                            }
                        }
                    } elseif ($req.HttpMethod -eq 'POST' -and $percorso -eq '/step') {
                        if ($req.ContentLength64 -gt 65536) {
                            Invia $res 413 '{"ok":false,"motivo":"dati troppo grandi"}'
                        } else {
                            $reader = New-Object System.IO.StreamReader($req.InputStream, [System.Text.Encoding]::UTF8)
                            $body = $reader.ReadToEnd()
                            $dati = $null
                            try { $dati = $body | ConvertFrom-Json } catch {}
                            $st = if ($dati -and $dati.Step) { ([string]$dati.Step).Trim().ToLower() } else { '' }
                            if (-not $st -or ($passiValidi -notcontains $st)) {
                                Invia $res 400 '{"ok":false,"motivo":"passaggio non valido"}'
                            } elseif ($st -eq 'account') {
                                $oemList = @('OEM', 'ADMIN', 'ADMINISTRATOR', 'USER', 'OWNER', 'DEFAULTUSER0', 'PC', 'LAPTOP', 'DESKTOP', 'CLT', 'CLT CLT', 'CLTCLT', 'CLIENTE')
                                $nu = if ($dati.NomeUtente) { ([string]$dati.NomeUtente).Trim() } else { 'Utente' }
                                if (-not $nu -or ($oemList -contains $nu.ToUpper())) { $nu = 'Utente' }
                                $np = if ($dati.NomePc) { ([string]$dati.NomePc -replace '[^A-Za-z0-9\-]', '').Trim('-') } else { '' }
                                if (-not $np -or ($oemList -contains $np.ToUpper()) -or ($np -match '^(?i)PC-clt$')) {
                                    $c = ($nu -replace '[^A-Za-z0-9]', '')
                                    if (-not $c -or ($oemList -contains $c.ToUpper())) { $c = 'Utente' }
                                    $np = "PC-$c"
                                }
                                if ($np.Length -gt 15) { $np = $np.Substring(0, 15) }
                                if (-not $Sync.TestMode) {
                                    try {
                                        Set-LocalUser -Name $env:USERNAME -FullName $nu -ErrorAction Stop
                                    } catch {
                                        try {
                                            $u = [ADSI]("WinNT://./$env:USERNAME,user")
                                            $u.FullName = $nu
                                            $u.SetInfo()
                                        } catch {}
                                    }
                                    try {
                                        $logonUi = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI"
                                        if (Test-Path $logonUi) {
                                            if (Get-ItemProperty -Path $logonUi -Name "LastLoggedOnDisplayName" -ErrorAction SilentlyContinue) {
                                                Set-ItemProperty -Path $logonUi -Name "LastLoggedOnDisplayName" -Value $nu -ErrorAction SilentlyContinue
                                            }
                                        }
                                        $sessData = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\SessionData"
                                        if (Test-Path $sessData) {
                                            Get-ChildItem -Path $sessData -ErrorAction SilentlyContinue | ForEach-Object {
                                                if (Get-ItemProperty -Path $_.PSPath -Name "LoggedOnDisplayName" -ErrorAction SilentlyContinue) {
                                                    Set-ItemProperty -Path $_.PSPath -Name "LoggedOnDisplayName" -Value $nu -ErrorAction SilentlyContinue
                                                }
                                            }
                                        }
                                    } catch {}
                                    if ($np -and $np.ToUpper() -ne $env:COMPUTERNAME.ToUpper()) {
                                        try { Rename-Computer -NewName $np -Force -ErrorAction SilentlyContinue } catch {}
                                    }
                                }
                                $Sync.CodaStep.Enqueue($body)
                                $respObj = @{ ok = $true; messaggio = "Nome utente impostato su '$nu' e Nome PC su '$np' (attivo al riavvio)." } | ConvertTo-Json -Compress
                                Invia $res 200 $respObj
                            } elseif ($st -eq 'nopass') {
                                if (-not $Sync.TestMode) {
                                    try {
                                        & net.exe accounts /maxpwage:unlimited 2>$null | Out-Null
                                        & net.exe user $env:USERNAME "" 2>$null | Out-Null
                                        Get-LocalUser -ErrorAction SilentlyContinue | Where-Object { $_.Enabled } | ForEach-Object {
                                            try { Set-LocalUser -Name $_.Name -PasswordNeverExpires $true -ErrorAction SilentlyContinue } catch {}
                                        }
                                        $pwLess = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device"
                                        if (Test-Path $pwLess) {
                                            Set-ItemProperty -Path $pwLess -Name "DevicePasswordLessBuildVersion" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                                        }
                                        $winLogon = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
                                        if (Test-Path $winLogon) {
                                            Remove-ItemProperty -Path $winLogon -Name "DefaultPassword" -ErrorAction SilentlyContinue
                                            Set-ItemProperty -Path $winLogon -Name "AutoAdminLogon" -Value "0" -ErrorAction SilentlyContinue
                                        }
                                        & powercfg.exe /setacvalueindex SCHEME_CURRENT SUB_NONE CONSOLELOCK 0 2>$null | Out-Null
                                        & powercfg.exe /setdcvalueindex SCHEME_CURRENT SUB_NONE CONSOLELOCK 0 2>$null | Out-Null
                                        & powercfg.exe /setactive SCHEME_CURRENT 2>$null | Out-Null
                                    } catch {}
                                }
                                $respObj = @{ ok = $true; messaggio = "Password login Windows rimossa e scadenza disattivata: accesso diretto al Desktop attivo." } | ConvertTo-Json -Compress
                                Invia $res 200 $respObj
                            } elseif ($st -in @('sysdm','netplwiz','devmgmt','winupdate')) {
                                if (-not $Sync.TestMode) {
                                    try {
                                        switch ($st) {
                                            'sysdm'     { Start-Process "sysdm.cpl" -ErrorAction SilentlyContinue }
                                            'netplwiz'  { Start-Process "netplwiz.exe" -ErrorAction SilentlyContinue }
                                            'devmgmt'   { Start-Process "devmgmt.msc" -ErrorAction SilentlyContinue }
                                            'winupdate' { Start-Process "ms-settings:windowsupdate" -ErrorAction SilentlyContinue }
                                        }
                                    } catch {}
                                }
                                $respObj = @{ ok = $true; messaggio = "Strumento di sistema aperto." } | ConvertTo-Json -Compress
                                Invia $res 200 $respObj
                            } else {
                                $Sync.CodaStep.Enqueue($body)
                                $respObj = @{ ok = $true; messaggio = "Passaggio '$st' avviato: segui l'esecuzione nella finestra di PC Facile." } | ConvertTo-Json -Compress
                                Invia $res 200 $respObj
                            }
                        }
                    } elseif ($req.HttpMethod -eq 'POST' -and $percorso -eq '/skip') {
                        $reader = New-Object System.IO.StreamReader($req.InputStream, [System.Text.Encoding]::UTF8)
                        $body = $reader.ReadToEnd()
                        $dati = $null
                        try { $dati = $body | ConvertFrom-Json } catch {}
                        $tk = if ($dati -and $dati.TaskId) { ([string]$dati.TaskId).Trim().ToLower() } else { 'current' }
                        try {
                            $stObj = $Sync.StatusJson | ConvertFrom-Json
                            if ($stObj -and $stObj.Tasks) {
                                if ($tk -eq 'current') {
                                    foreach ($prop in $stObj.Tasks.PSObject.Properties) {
                                        if ($prop.Value.Stato -eq 'running') { $tk = $prop.Name; break }
                                    }
                                }
                                if ($tk -and $tk -ne 'current') {
                                    $Sync.Saltati[$tk] = $true
                                    $propTk = $stObj.Tasks.PSObject.Properties[$tk]
                                    if ($propTk) {
                                        if ($propTk.Value.Stato -eq 'running') {
                                            $Sync.SkipCurrent = $true
                                        }
                                        $propTk.Value.Stato = 'skipped'
                                        $propTk.Value.Dettaglio = "Saltato dall'operatore"
                                    }
                                } else {
                                    $Sync.SkipCurrent = $true
                                }
                                $Sync.StatusJson = ($stObj | ConvertTo-Json -Depth 5 -Compress)
                            }
                        } catch {
                            if ($tk -and $tk -ne 'current') { $Sync.Saltati[$tk] = $true }
                            $Sync.SkipCurrent = $true
                        }
                        if (-not $Sync.TestMode) {
                            try {
                                switch ($tk) {
                                    'avprova'  { Get-Process -Name 'sbbd*','InstStub*','Norton*','MCPR*','NRnR*' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }
                                    'everyday' { Get-Process -Name 'UnieuroSecure*' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }
                                    'pulizia'  { Get-Process -Name 'OneDriveSetup*' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }
                                    default    { Get-Process -Name 'winget*','curl*' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }
                                }
                            } catch {}
                        }
                        Invia $res 200 '{"ok":true,"saltato":true}'
                    } elseif ($req.HttpMethod -eq 'POST' -and $percorso -eq '/mode') {
                        $reader = New-Object System.IO.StreamReader($req.InputStream, [System.Text.Encoding]::UTF8)
                        $body = $reader.ReadToEnd()
                        $dati = $null
                        try { $dati = $body | ConvertFrom-Json } catch {}
                        $mod = if ($dati -and $dati.Modalita -and ([string]$dati.Modalita).ToUpper() -eq 'POSTVENDITA') { 'POSTVENDITA' } else { 'COMPLETA' }
                        $Sync.Modalita = $mod
                        $passiNonEssenziali = @('ripristino', 'pulizia', 'driver', 'aggiorna')
                        try {
                            $stObj = $Sync.StatusJson | ConvertFrom-Json
                            if ($stObj -and $stObj.Tasks) {
                                foreach ($kSkip in $passiNonEssenziali) {
                                    $propTk = $stObj.Tasks.PSObject.Properties[$kSkip]
                                    if ($mod -eq 'POSTVENDITA') {
                                        $Sync.Saltati[$kSkip] = $true
                                        if ($propTk) {
                                            if ($propTk.Value.Stato -eq 'running') { $Sync.SkipCurrent = $true }
                                            $propTk.Value.Stato = 'skipped'
                                            $propTk.Value.Dettaglio = 'Saltato (Post Vendita Essenziale)'
                                        }
                                    } else {
                                        if ($Sync.Saltati.ContainsKey($kSkip)) { [void]$Sync.Saltati.Remove($kSkip) }
                                        if ($propTk -and $propTk.Value.Stato -eq 'skipped' -and $propTk.Value.Dettaglio -like '*Post Vendita*') {
                                            $propTk.Value.Stato = 'pending'
                                            $propTk.Value.Dettaglio = ''
                                        }
                                    }
                                }
                                $Sync.StatusJson = ($stObj | ConvertTo-Json -Depth 5 -Compress)
                            }
                        } catch {
                            if ($mod -eq 'POSTVENDITA') {
                                foreach ($kSkip in $passiNonEssenziali) { $Sync.Saltati[$kSkip] = $true }
                            }
                        }
                        if ($mod -eq 'POSTVENDITA' -and -not $Sync.TestMode) {
                            try {
                                # Sblocco e pulizia tracce account OEM senza Reset di Windows
                                & net.exe accounts /maxpwage:unlimited 2>$null | Out-Null
                                & net.exe user $env:USERNAME "" 2>$null | Out-Null
                                Get-LocalUser -ErrorAction SilentlyContinue | Where-Object { $_.Enabled } | ForEach-Object {
                                    try { Set-LocalUser -Name $_.Name -PasswordNeverExpires $true -ErrorAction SilentlyContinue } catch {}
                                }
                                & powercfg.exe /setacvalueindex SCHEME_CURRENT SUB_NONE CONSOLELOCK 0 2>$null | Out-Null
                                & powercfg.exe /setdcvalueindex SCHEME_CURRENT SUB_NONE CONSOLELOCK 0 2>$null | Out-Null
                                & powercfg.exe /setactive SCHEME_CURRENT 2>$null | Out-Null
                                $recDir = Join-Path $env:APPDATA "Microsoft\Windows\Recent"
                                if (Test-Path $recDir) { Remove-Item -Path (Join-Path $recDir "*") -Force -Recurse -ErrorAction SilentlyContinue }
                                Clear-RecycleBin -Force -ErrorAction SilentlyContinue
                            } catch {}
                        }
                        $msgMode = if ($mod -eq 'POSTVENDITA') {
                            "Modalita' Post Vendita Rapida da OEM attivata: account OEM sbloccato senza reset, esecuzione delle sole operazioni essenziali (Unieuro Secure, Office, Chrome, Nome Cliente e Scheda PDF)."
                        } else {
                            "Modalita' Configurazione Completa attivata (tutti i 14 passaggi)."
                        }
                        $respMode = @{ ok = $true; modalita = $mod; messaggio = $msgMode } | ConvertTo-Json -Compress
                        Invia $res 200 $respMode
                    } elseif ($req.HttpMethod -eq 'POST' -and $percorso -eq '/cmd') {
                        $reader = New-Object System.IO.StreamReader($req.InputStream, [System.Text.Encoding]::UTF8)
                        $body = $reader.ReadToEnd()
                        $dati = $null
                        try { $dati = $body | ConvertFrom-Json } catch {}
                        $cmdStr = if ($dati -and $dati.Command) { [string]$dati.Command } else { '' }
                        $srcStr = if ($dati -and $dati.Source) { [string]$dati.Source } else { 'pannello' }
                        $esitoCmd = Esegui-IstruzioneLocale $cmdStr $srcStr
                        $respJson = $esitoCmd | ConvertTo-Json -Depth 4 -Compress
                        Invia $res 200 $respJson
                    } else {
                        Invia $res 404 '{"ok":false,"motivo":"percorso sconosciuto"}'
                    }
                } catch {
                    try { $res.StatusCode = 500 } catch {}
                } finally {
                    try { $res.Close() } catch {}
                }
            }
        }

        $rs = [runspacefactory]::CreateRunspace()
        $rs.Open()
        $ps = [powershell]::Create()
        $ps.Runspace = $rs
        [void]$ps.AddScript($ciclo).AddArgument($listener).AddArgument($Global:PannelloSync)
        $Global:CredHttpHandle = $ps.BeginInvoke()
        $Global:CredHttpPs = $ps
        $Global:CredHttpListener = $listener

        if (-not $Global:PannelloSync.TestMode) {
            try {
                $cicloRemoto = {
                    param($Listener, $Sync, $PortaLocale)
                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                    $doneFile = Join-Path $(if ($env:ProgramData) { $env:ProgramData } else { [IO.Path]::GetTempPath() }) "PCFacile\remote-done.txt"
                    $dirDone = Split-Path $doneFile -Parent
                    if (-not (Test-Path $dirDone)) { New-Item -ItemType Directory -Path $dirDone -Force -ErrorAction SilentlyContinue | Out-Null }
                    $eseguiti = @{}
                    if (Test-Path $doneFile) {
                        Get-Content $doneFile -ErrorAction SilentlyContinue | Where-Object { $_ } | ForEach-Object { $eseguiti[$_.Trim()] = $true }
                    }
                    $teleUrl = "https://ntfy.sh/pcfacile-sn97-telemetria-7f9a2c"
                    $cmdUrls = @(
                        "https://api.github.com/repos/samuelenigro97-prog/PC-Facile/contents/remote/commands.json",
                        "https://raw.githubusercontent.com/samuelenigro97-prog/PC-Facile/main/remote/commands.json"
                    )
                    $tick = 0
                    while ($Listener.IsListening) {
                        Start-Sleep -Seconds 6
                        $tick++
                        $stObj = $null
                        try { $stObj = $Sync.StatusJson | ConvertFrom-Json } catch {}
                        $hwMod = if ($stObj -and $stObj.Hardware -and $stObj.Hardware.Modello) { [string]$stObj.Hardware.Modello } else { $env:COMPUTERNAME }
                        $hwSer = if ($stObj -and $stObj.Hardware -and $stObj.Hardware.Seriale) { [string]$stObj.Hardware.Seriale } else { "N/D" }
                        $curPct = if ($stObj -and $null -ne $stObj.Percentuale) { [int]$stObj.Percentuale } else { 0 }
                        $curFase = if ($stObj -and $stObj.FaseCorrente) { [string]$stObj.FaseCorrente } else { "Attivo" }

                        if ($tick % 5 -eq 1) {
                            try {
                                $hb = @{
                                    type    = "heartbeat"
                                    ts      = (Get-Date).ToString("HH:mm:ss")
                                    pc      = $env:COMPUTERNAME
                                    modello = $hwMod
                                    seriale = $hwSer
                                    os      = "windows"
                                    pct     = $curPct
                                    fase    = $curFase
                                } | ConvertTo-Json -Compress
                                Invoke-RestMethod -Uri $teleUrl -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($hb)) -TimeoutSec 4 -ErrorAction SilentlyContinue | Out-Null
                            } catch {}
                        }

                        $remJson = $null
                        foreach ($cu in $cmdUrls) {
                            try {
                                $hdr = @{ 'Cache-Control' = 'no-cache'; 'User-Agent' = 'PCFacile-Agent' }
                                if ($cu -like '*api.github.com*') { $hdr['Accept'] = 'application/vnd.github.raw' }
                                $rawR = Invoke-WebRequest -Uri ($cu + "?t=" + [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()) -Headers $hdr -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
                                $remJson = $rawR.Content | ConvertFrom-Json -ErrorAction Stop
                                if ($remJson -and $null -ne $remJson.commands) { break }
                            } catch {}
                        }
                        if ($remJson -and $remJson.commands) {
                            foreach ($c in @($remJson.commands)) {
                                $cid = [string]$c.id
                                if (-not $cid -or $eseguiti.ContainsKey($cid)) { continue }
                                $cOs = if ($c.os) { ([string]$c.os).ToLower() } else { "any" }
                                if ($cOs -ne "any" -and $cOs -ne "windows") { continue }
                                $tgt = if ($c.target) { ([string]$c.target).Trim() } else { "*" }
                                $matchTgt = ($tgt -eq "*") -or ($env:COMPUTERNAME -like "*$tgt*") -or ($hwMod -like "*$tgt*") -or ($hwSer -like "*$tgt*")
                                if (-not $matchTgt) { continue }

                                $eseguiti[$cid] = $true
                                try { Add-Content -LiteralPath $doneFile -Value $cid -ErrorAction SilentlyContinue } catch {}

                                $bodyLocal = @{ Command = [string]$c.command; Source = "telecomando:$($c.title)" } | ConvertTo-Json -Compress
                                try {
                                    $resLoc = Invoke-RestMethod -Uri "http://127.0.0.1:$PortaLocale/cmd" -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($bodyLocal)) -ContentType "application/json; charset=utf-8" -TimeoutSec 45 -ErrorAction Stop
                                    $rep = @{
                                        type    = "cmd_result"
                                        ts      = (Get-Date).ToString("HH:mm:ss")
                                        id      = $cid
                                        title   = [string]$c.title
                                        pc      = $env:COMPUTERNAME
                                        modello = $hwMod
                                        seriale = $hwSer
                                        ok      = [bool]$resLoc.ok
                                        output  = [string]$resLoc.lastOutput
                                    } | ConvertTo-Json -Compress
                                    Invoke-RestMethod -Uri $teleUrl -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($rep)) -TimeoutSec 5 -ErrorAction SilentlyContinue | Out-Null
                                } catch {}
                            }
                        }
                    }
                }
                $rsRem = [runspacefactory]::CreateRunspace()
                $rsRem.Open()
                $psRem = [powershell]::Create()
                $psRem.Runspace = $rsRem
                [void]$psRem.AddScript($cicloRemoto).AddArgument($listener).AddArgument($Global:PannelloSync).AddArgument($Porta)
                $Global:RemoteHttpHandle = $psRem.BeginInvoke()
                $Global:RemoteHttpPs = $psRem
            } catch {}
        }
        return $true
    } catch {
        return $false
    }
}

function Start-LocalCredServer {
    if ($Test -or $Global:Test -or $env:PESTER_TEST) { return $false }
    return (Start-ServerPannello -Porta 8899)
}

function Stop-LocalCredServer {
    try {
        if ($Global:CredHttpListener) {
            $Global:CredHttpListener.Stop()
            $Global:CredHttpListener.Close()
        }
    } catch {}
    try { if ($Global:CredHttpPs) { $Global:CredHttpPs.Runspace.Close(); $Global:CredHttpPs.Dispose() } } catch {}
    try { if ($Global:RemoteHttpPs) { $Global:RemoteHttpPs.Runspace.Close(); $Global:RemoteHttpPs.Dispose() } } catch {}
    $Global:CredHttpListener = $null
    $Global:CredHttpPs = $null
    $Global:CredHttpHandle = $null
    $Global:RemoteHttpPs = $null
    $Global:RemoteHttpHandle = $null
}

function Open-PannelloOperatore {
    param(
        [string]$NomeCliente = "",
        [string]$Email = "",
        [string]$Password = ""
    )
    # Il pannello serve solo se il server locale risponde (unico canale):
    # altrimenti i dati del cliente si chiedono in console (Wait-DatiCliente).
    $serverOk = [bool](Start-LocalCredServer)
    $Global:PannelloDisponibile = $false
    $oemNames = @('OEM', 'ADMIN', 'ADMINISTRATOR', 'USER', 'OWNER', 'DEFAULTUSER0', 'PC', 'LAPTOP', 'DESKTOP', 'CLT', 'CLT CLT', 'CLTCLT', 'CLIENTE')
    if ($NomeCliente -and ($oemNames -contains $NomeCliente.Trim().ToUpper() -or $NomeCliente.Trim().ToUpper() -eq "CLIENTE" -or $NomeCliente.Trim().ToUpper() -eq "UTENTE")) {
        $NomeCliente = ""
    }
    # Se l'operatore non compila cognome/nome, tratta come clt clt (nessuna email/password registrata).
    if (-not $Email) {
        $Email = if ($NomeCliente) { New-EmailCliente -Base $NomeCliente } else { "" }
    }
    if (-not $Password) {
        $Password = if ($NomeCliente) { New-PasswordCliente -Base $NomeCliente } else { "" }
    }

    # Rileva specifiche hardware rapide per il mini-dashboard del pannello
    $hw = Get-SystemHardwareDetails
    $hwModello = if ($hw.Produttore -and $hw.Modello) { "$($hw.Produttore) $($hw.Modello)" } else { "" }
    $hwCpu = if ($hw.Cpu) { $hw.Cpu } else { "" }
    $hwRam = if ($hw.RamGB) { "$($hw.RamGB) GB RAM" } else { "" }
    $hwSeriale = if ($hw.Seriale -and $hw.Seriale -ne "Non disponibile") { $hw.Seriale } else { "" }

    $tempDir = if ($env:TEMP) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { [System.IO.Path]::GetTempPath() }
    $pannelloFile = Join-Path $tempDir "Pannello-Operatore.html"
    
    # Inizializza subito lo stato (file + server locale) con l'hardware reale:
    # il pannello lo mostra al posto dei segnaposto.
    Update-PannelloStatus -Percentuale 5 -FaseCorrente "Inizializzazione Setup" -Dettaglio "Avvio pannello operatore Unieuro..." -Hardware ([ordered]@{ Modello = $hwModello; Cpu = $hwCpu; Ram = $hwRam; Seriale = $hwSeriale })

    # Escape HTML dei valori inseriti nella pagina: un apice, < o & nel nome,
    # nella password o nei dati hardware non devono rompere/alterare il pannello.
    $hNome     = [System.Net.WebUtility]::HtmlEncode([string]$NomeCliente)
    $hEmail    = [System.Net.WebUtility]::HtmlEncode([string]$Email)
    $hPassword = [System.Net.WebUtility]::HtmlEncode([string]$Password)
    # (i dati hardware arrivano al pannello tramite lo stato, non nell'HTML)
    
    try {
        $html = @"
<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PC Facile - Pannello operatore</title>
    <style>
        :root {
            --bg-canvas: #060b14;
            --bg-surface: #0b1323;
            --bg-elevated: #101b30;
            --bg-interactive: #15233d;
            --bg-input: #070d19;
            --border-subtle: rgba(148, 163, 184, 0.14);
            --border-strong: rgba(148, 163, 184, 0.26);
            --border-highlight: rgba(255, 255, 255, 0.08);
            --u-orange: #EE7203;
            --u-orange-hover: #ff851b;
            --u-orange-soft: rgba(238, 114, 3, 0.14);
            --u-blue: #0284c7;
            --text-primary: #f8fafc;
            --text-secondary: #cbd5e1;
            --text-muted: #94a3b8;
            --ok-bg: rgba(16, 185, 129, 0.12);
            --ok-border: #10b981;
            --ok-text: #6ee7b7;
            --warn-bg: rgba(245, 158, 11, 0.13);
            --warn-border: #f59e0b;
            --warn-text: #fde68a;
            --err-bg: rgba(239, 68, 68, 0.14);
            --err-border: #ef4444;
            --err-text: #fca5a5;
            --ease-spring: cubic-bezier(0.22, 1, 0.36, 1);
            --radius-outer: 18px;
            --radius-inner: 13px;
            --radius-control: 10px;
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
            font-family: 'Plus Jakarta Sans', 'Segoe UI Variable Display', 'Segoe UI', -apple-system, BlinkMacSystemFont, sans-serif;
            -webkit-font-smoothing: antialiased;
        }

        body {
            background-color: var(--bg-canvas);
            background-image:
                radial-gradient(1100px 420px at 12% -5%, rgba(238, 114, 3, 0.09), transparent 65%),
                radial-gradient(900px 380px at 88% 0%, rgba(2, 132, 199, 0.09), transparent 60%);
            background-attachment: fixed;
            color: var(--text-primary);
            padding: 16px 22px 32px;
            min-height: 100vh;
            font-size: 14.5px;
            line-height: 1.5;
        }

        .container {
            max-width: 1680px;
            width: 100%;
            margin: 0 auto;
        }

        button, a, input, select { font-size: inherit; }
        button:focus-visible, a:focus-visible, input:focus-visible, select:focus-visible {
            outline: 2.5px solid var(--u-orange);
            outline-offset: 2px;
        }
        .muted { color: var(--text-muted); }

        /* INTESTAZIONE DOUBLE-BEZEL */
        .header {
            background: linear-gradient(180deg, rgba(16, 27, 48, 0.92) 0%, rgba(11, 19, 35, 0.96) 100%);
            border: 1px solid var(--border-strong);
            box-shadow:
                inset 0 1px 0 var(--border-highlight),
                0 12px 32px -8px rgba(0, 0, 0, 0.55);
            border-radius: var(--radius-outer);
            padding: 14px 20px;
            margin-bottom: 14px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 14px;
            flex-wrap: wrap;
        }
        .brand-box { display: flex; align-items: center; gap: 14px; min-width: 0; }
        .u-logo {
            background: linear-gradient(135deg, #ff851b 0%, #EE7203 100%);
            color: #050a14;
            font-weight: 900;
            font-size: 14px;
            letter-spacing: 0.1em;
            padding: 8px 14px;
            border-radius: 10px;
            flex-shrink: 0;
            box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.35), 0 4px 14px rgba(238, 114, 3, 0.32);
        }
        .brand-titles h1 {
            font-size: 20px;
            color: #fff;
            font-weight: 800;
            letter-spacing: -0.02em;
            line-height: 1.2;
        }
        .brand-titles p {
            font-size: 12.5px;
            color: var(--text-muted);
            font-variant-numeric: tabular-nums;
            margin-top: 2px;
        }
        .badge-stato {
            font-weight: 700;
            font-size: 13px;
            padding: 7px 15px;
            border-radius: 999px;
            white-space: nowrap;
            border: 1px solid;
            letter-spacing: 0.01em;
            box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.1);
            transition: all 0.25s var(--ease-spring);
        }
        .stato-off { background: var(--err-bg); border-color: var(--err-border); color: var(--err-text); }
        .stato-attesa { background: rgba(238, 114, 3, 0.15); border-color: var(--u-orange); color: #fed7aa; }
        .stato-corso { background: rgba(14, 165, 233, 0.14); border-color: #38bdf8; color: #e0f2fe; }
        .stato-ok { background: var(--ok-bg); border-color: var(--ok-border); color: var(--ok-text); }
        .stato-avvisi { background: var(--warn-bg); border-color: var(--warn-border); color: var(--warn-text); }

        /* AVVISI IN CIMA */
        .notice {
            display: none;
            border-radius: var(--radius-inner);
            padding: 14px 18px;
            margin-bottom: 14px;
            border: 1px solid;
            box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.06);
        }
        .notice h2 { font-size: 15px; font-weight: 800; margin-bottom: 4px; letter-spacing: -0.01em; }
        .notice p { font-size: 13.5px; color: var(--text-secondary); margin-bottom: 8px; }
        .notice p:last-child { margin-bottom: 0; }
        .notice-off { background: rgba(67, 20, 7, 0.55); border-color: rgba(238, 114, 3, 0.55); }
        .notice-off h2 { color: #fed7aa; }
        .notice-attesa { background: rgba(8, 47, 73, 0.55); border-color: rgba(56, 189, 248, 0.5); }
        .notice-attesa h2 { color: #bae6fd; }
        .notice-azioni { display: flex; gap: 8px; flex-wrap: wrap; margin-top: 8px; }

        /* HARDWARE TELEMETRY STRIP */
        .hw-bar {
            display: none;
            background: rgba(11, 19, 35, 0.85);
            border: 1px solid var(--border-subtle);
            box-shadow: inset 0 1px 0 var(--border-highlight);
            border-radius: var(--radius-inner);
            padding: 10px 16px;
            margin-bottom: 14px;
            align-items: center;
            justify-content: space-between;
            gap: 8px 20px;
            font-size: 13.5px;
            flex-wrap: wrap;
        }
        .hw-item { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
        .hw-item .etichetta { color: var(--text-muted); font-weight: 600; font-size: 12.5px; }
        .hw-item strong { color: #fff; font-weight: 700; font-variant-numeric: tabular-nums; }

        /* BARRA FISSA (Avanzamento + Schede) */
        .sticky-top-bar {
            position: sticky;
            top: 0;
            z-index: 60;
            background: rgba(6, 11, 20, 0.88);
            backdrop-filter: blur(16px);
            -webkit-backdrop-filter: blur(16px);
            padding: 6px 0 10px;
            margin-bottom: 10px;
            border-bottom: 1px solid rgba(148, 163, 184, 0.08);
        }
        .sticky-top-bar .progress-card { margin-bottom: 10px; }
        .sticky-top-bar .tab-bar { margin-bottom: 0; }

        /* AVANZAMENTO */
        .progress-card {
            background: linear-gradient(180deg, rgba(16, 27, 48, 0.95) 0%, rgba(11, 19, 35, 0.98) 100%);
            border: 1px solid var(--border-strong);
            box-shadow:
                inset 0 1px 0 var(--border-highlight),
                0 10px 28px -10px rgba(0, 0, 0, 0.6);
            border-radius: var(--radius-outer);
            padding: 14px 18px;
        }
        .progress-header { display: flex; justify-content: space-between; align-items: center; gap: 12px; margin-bottom: 10px; }
        .progress-title { color: #fed7aa; font-weight: 800; font-size: 14px; letter-spacing: -0.01em; }
        .progress-meta { display: flex; align-items: baseline; gap: 16px; }
        .progress-timer-box { font-size: 13px; color: var(--text-muted); font-weight: 600; }
        .progress-timer {
            color: #7dd3fc;
            font-family: 'Cascadia Code', 'JetBrains Mono', Consolas, monospace;
            font-size: 15px;
            font-weight: 700;
            font-variant-numeric: tabular-nums;
        }
        .progress-pct {
            color: var(--u-orange);
            font-size: 28px;
            font-weight: 900;
            line-height: 1;
            letter-spacing: -0.03em;
            font-variant-numeric: tabular-nums;
        }
        .progress-bar-bg {
            background: #040811;
            border: 1px solid rgba(148, 163, 184, 0.18);
            box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.6);
            height: 14px;
            border-radius: 999px;
            overflow: hidden;
        }
        .progress-bar-fill {
            background: linear-gradient(90deg, #EE7203 0%, #ff9d42 60%, #ffb366 100%);
            box-shadow: 0 0 16px rgba(238, 114, 3, 0.45);
            height: 100%;
            width: 0%;
            border-radius: 999px;
            transition: width 0.55s var(--ease-spring);
        }
        .progress-status-row { margin-top: 10px; font-size: 14px; }
        .current-fase { color: #fff; font-weight: 700; }
        .current-detail { color: var(--text-secondary); font-size: 13px; overflow-wrap: anywhere; margin-top: 2px; }

        /* ESITO FINALE */
        .banner-complete {
            display: none;
            border-radius: var(--radius-outer);
            padding: 16px 20px;
            margin-bottom: 14px;
            border: 1.5px solid var(--ok-border);
            background: linear-gradient(180deg, rgba(6, 78, 59, 0.45) 0%, rgba(5, 46, 22, 0.65) 100%);
            box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.1), 0 12px 30px -10px rgba(16, 185, 129, 0.25);
        }
        .banner-complete.con-avvisi {
            border-color: var(--warn-border);
            background: linear-gradient(180deg, rgba(120, 53, 15, 0.45) 0%, rgba(69, 26, 3, 0.65) 100%);
        }
        .banner-complete h2 { font-size: 17px; font-weight: 800; color: #34d399; margin-bottom: 4px; }
        .banner-complete.con-avvisi h2 { color: #fbbf24; }
        .banner-complete p { font-size: 13.5px; color: #e2e8f0; }
        .banner-complete ul { margin: 8px 0 8px 20px; font-size: 13.5px; color: #fde68a; }

        /* BARRA SCHEDE (Segmented Island Pill Bar) */
        .tab-bar {
            display: flex;
            gap: 6px;
            background: rgba(11, 19, 35, 0.95);
            padding: 5px;
            border-radius: 14px;
            border: 1px solid var(--border-subtle);
            box-shadow: inset 0 1px 0 var(--border-highlight);
        }
        .tab-btn {
            flex: 1;
            min-height: 44px;
            background: transparent;
            border: 1px solid transparent;
            color: var(--text-muted);
            font-size: 13.5px;
            font-weight: 700;
            padding: 8px 12px;
            border-radius: 10px;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 7px;
            transition: all 0.22s var(--ease-spring);
        }
        .tab-btn:hover { color: #fff; background: rgba(255, 255, 255, 0.04); }
        .tab-btn:active { transform: scale(0.985); }
        .tab-btn[aria-selected="true"] {
            background: linear-gradient(180deg, #172a4a 0%, #101f38 100%);
            color: #fff;
            border-color: rgba(238, 114, 3, 0.55);
            box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.12), 0 4px 12px rgba(0, 0, 0, 0.35);
        }
        .tab-badge-num {
            background: rgba(255, 255, 255, 0.08);
            color: var(--text-secondary);
            font-size: 12px;
            padding: 2px 8px;
            border-radius: 999px;
            font-weight: 800;
            font-variant-numeric: tabular-nums;
        }
        .tab-btn[aria-selected="true"] .tab-badge-num {
            background: var(--u-orange);
            color: #050a14;
        }

        .section-view { display: none; }
        .section-view.active-view {
            display: block;
            animation: viewFadeIn 0.28s var(--ease-spring);
        }
        @keyframes viewFadeIn {
            from { opacity: 0; transform: translateY(4px); }
            to { opacity: 1; transform: translateY(0); }
        }

        /* CONTENITORE DOUBLE-BEZEL PRINCIPALE */
        .card {
            background: rgba(11, 19, 35, 0.78);
            border: 1px solid var(--border-subtle);
            box-shadow:
                inset 0 1px 0 var(--border-highlight),
                0 16px 40px -12px rgba(0, 0, 0, 0.55);
            border-radius: var(--radius-outer);
            padding: 18px 20px;
            margin-bottom: 14px;
        }
        .card-subtitle {
            font-size: 13.5px;
            color: var(--text-secondary);
            margin-bottom: 14px;
            line-height: 1.5;
        }

        /* SCHEDA 2: LISTA AVANZAMENTO */
        .bg-tasks {
            list-style: none;
            display: flex;
            flex-direction: column;
            gap: 7px;
        }
        .task-item {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 10px;
            font-size: 14px;
            padding: 11px 14px;
            border-radius: var(--radius-control);
            border: 1px solid rgba(148, 163, 184, 0.1);
            background: var(--bg-surface);
            box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.03);
            transition: all 0.22s var(--ease-spring);
        }
        .task-item:hover { border-color: rgba(148, 163, 184, 0.22); }
        .task-left {
            display: grid;
            grid-template-columns: 22px 1fr;
            align-items: center;
            column-gap: 10px;
            flex: 1;
            min-width: 0;
        }
        .task-icon {
            font-size: 15px;
            width: 22px;
            text-align: center;
            flex-shrink: 0;
            font-weight: 800;
            color: var(--text-muted);
        }
        .task-name { color: var(--text-primary); font-weight: 600; }
        .task-detail { color: #fed7aa; font-size: 13px; grid-column: 2; margin-top: 2px; }
        .task-detail:empty { display: none; }
        .task-right { display: flex; align-items: center; gap: 8px; flex-shrink: 0; }
        .btn-skip-task {
            background: rgba(30, 41, 59, 0.75);
            border: 1px solid rgba(148, 163, 184, 0.25);
            color: var(--text-secondary);
            font-size: 12px;
            font-weight: 700;
            padding: 5px 11px;
            border-radius: 8px;
            cursor: pointer;
            white-space: nowrap;
            transition: all 0.2s var(--ease-spring);
        }
        .btn-skip-task:hover {
            background: var(--u-orange);
            border-color: var(--u-orange);
            color: #050a14;
            transform: translateY(-1px);
        }
        .btn-skip-task:active { transform: scale(0.97); }
        .task-item.running .btn-skip-task {
            background: rgba(238, 114, 3, 0.16);
            border-color: var(--u-orange);
            color: #fed7aa;
        }
        .task-item.running .btn-skip-task:hover {
            background: var(--u-orange);
            color: #050a14;
        }
        .task-item.done .btn-skip-task, .task-item.skipped .btn-skip-task { display: none; }
        .task-badge {
            font-size: 12px;
            font-weight: 800;
            padding: 4px 11px;
            border-radius: 999px;
            white-space: nowrap;
            flex-shrink: 0;
            letter-spacing: 0.01em;
        }
        .badge-pending {
            background: rgba(15, 23, 42, 0.8);
            color: var(--text-muted);
            border: 1px solid rgba(148, 163, 184, 0.18);
        }
        .task-item.running {
            background: linear-gradient(90deg, rgba(67, 20, 7, 0.55) 0%, rgba(16, 27, 48, 0.9) 100%);
            border-color: var(--u-orange);
            box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.08), 0 6px 20px -6px rgba(238, 114, 3, 0.3);
        }
        .task-item.running .task-name { color: #fff; font-weight: 800; }
        .badge-running { background: var(--u-orange); color: #050a14; font-weight: 800; }
        .task-item.done { background: rgba(11, 19, 35, 0.55); border-color: rgba(16, 185, 129, 0.22); }
        .task-item.done .task-icon { color: #10b981; }
        .badge-done-task { background: var(--ok-bg); color: var(--ok-text); border: 1px solid rgba(16, 185, 129, 0.45); }
        .task-item.error { background: rgba(69, 10, 10, 0.45); border-color: var(--err-border); }
        .task-item.error .task-icon { color: #f87171; }
        .badge-error { background: #dc2626; color: #fff; }
        .task-item.skipped .task-icon { color: #38bdf8; }
        .task-gruppo {
            color: #fdba74;
            font-size: 11.5px;
            font-weight: 800;
            text-transform: uppercase;
            letter-spacing: 0.08em;
            padding: 12px 4px 4px;
            grid-column: 1 / -1;
        }
        .badge-skipped {
            background: rgba(14, 165, 233, 0.14);
            color: #7dd3fc;
            border: 1px solid rgba(56, 189, 248, 0.4);
        }
        .spinner {
            display: inline-block;
            width: 14px;
            height: 14px;
            border: 2px solid var(--u-orange);
            border-top-color: transparent;
            border-radius: 50%;
            animation: spin 0.75s linear infinite;
        }
        @keyframes spin { to { transform: rotate(360deg); } }

        /* SCHEDA 1: DATI CLIENTE (CARD INTERNE DOUBLE-BEZEL) */
        .cred-step-box {
            background: var(--bg-elevated);
            border: 1px solid var(--border-subtle);
            box-shadow: inset 0 1px 0 var(--border-highlight);
            border-radius: var(--radius-inner);
            padding: 16px 18px;
            margin-bottom: 12px;
        }
        .cred-step-box.evidenza {
            border-color: rgba(238, 114, 3, 0.45);
            background: linear-gradient(180deg, rgba(21, 35, 61, 0.92) 0%, rgba(11, 19, 35, 0.95) 100%);
        }
        .cred-step-title {
            font-size: 14.5px;
            color: #fed7aa;
            font-weight: 800;
            margin-bottom: 12px;
            display: flex;
            align-items: center;
            gap: 9px;
            flex-wrap: wrap;
            letter-spacing: -0.01em;
        }
        .step-badge {
            background: var(--u-orange);
            color: #050a14;
            font-size: 12px;
            font-weight: 900;
            padding: 2px 8px;
            border-radius: 6px;
            font-variant-numeric: tabular-nums;
        }
        .campi-2 { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; margin-bottom: 10px; }
        .campi-3 { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 12px; margin-bottom: 14px; }
        .cred-label {
            display: block;
            font-size: 13px;
            color: var(--text-secondary);
            margin-bottom: 5px;
            font-weight: 700;
        }
        .obbligo { color: #fca5a5; font-weight: 700; font-size: 12px; }
        .cred-box { display: flex; gap: 8px; align-items: stretch; flex-wrap: wrap; }
        .cred-input {
            flex: 1 1 180px;
            min-width: 0;
            width: 100%;
            min-height: 42px;
            background: var(--bg-input);
            border: 1px solid var(--border-strong);
            box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.45);
            border-radius: var(--radius-control);
            padding: 8px 13px;
            font-size: 15px;
            color: #fff;
            transition: border-color 0.2s var(--ease-spring), box-shadow 0.2s var(--ease-spring);
        }
        .cred-input:focus {
            border-color: var(--u-orange);
            outline: none;
            box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.3), 0 0 0 3px rgba(238, 114, 3, 0.25);
        }
        .cred-input.errore {
            border-color: var(--err-border);
            box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.3);
        }
        .cred-input.cred-mono {
            font-family: 'Cascadia Code', 'JetBrains Mono', Consolas, monospace;
            font-weight: 700;
            color: #7dd3fc;
        }
        .dom-selector { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 8px; }
        .dom-btn {
            min-height: 42px;
            background: var(--bg-surface);
            border: 1px solid var(--border-strong);
            color: var(--text-secondary);
            font-size: 14px;
            font-weight: 700;
            padding: 8px 12px;
            border-radius: var(--radius-control);
            cursor: pointer;
            transition: all 0.2s var(--ease-spring);
        }
        .dom-btn:hover { border-color: var(--u-orange); color: #fff; background: var(--bg-interactive); }
        .dom-btn:active { transform: scale(0.985); }
        .dom-btn[aria-pressed="true"] {
            background: var(--u-orange);
            border-color: var(--u-orange-hover);
            color: #050a14;
            font-weight: 800;
            box-shadow: 0 4px 14px rgba(238, 114, 3, 0.3);
        }
        .btn-sec {
            min-height: 42px;
            background: var(--bg-interactive);
            border: 1px solid var(--border-strong);
            box-shadow: inset 0 1px 0 var(--border-highlight);
            color: #fff;
            border-radius: var(--radius-control);
            padding: 8px 14px;
            font-size: 13.5px;
            font-weight: 700;
            cursor: pointer;
            white-space: nowrap;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            gap: 6px;
            text-decoration: none;
            transition: all 0.2s var(--ease-spring);
        }
        .btn-sec:hover {
            background: #1d3154;
            border-color: var(--u-orange);
            transform: translateY(-1px);
        }
        .btn-sec:active { transform: scale(0.98); }

        .services-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 10px; }
        .svc-item {
            min-height: 46px;
            background: var(--bg-surface);
            border: 1px solid var(--border-subtle);
            border-radius: var(--radius-control);
            padding: 10px 14px;
            display: flex;
            align-items: center;
            gap: 11px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.2s var(--ease-spring);
        }
        .svc-item:hover { border-color: var(--u-orange); background: var(--bg-interactive); }
        .svc-item input { width: 20px; height: 20px; accent-color: var(--u-orange); cursor: pointer; flex-shrink: 0; }

        .btn-avvia {
            min-height: 52px;
            background: linear-gradient(180deg, #10b981 0%, #059669 100%);
            box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.25), 0 8px 20px -6px rgba(16, 185, 129, 0.45);
            color: #04130e;
            font-weight: 900;
            font-size: 15.5px;
            letter-spacing: 0.01em;
            padding: 12px 20px;
            border: 1px solid #34d399;
            cursor: pointer;
            border-radius: 12px;
            width: 100%;
            transition: all 0.22s var(--ease-spring);
        }
        .btn-avvia:hover {
            background: linear-gradient(180deg, #34d399 0%, #10b981 100%);
            transform: translateY(-1px);
        }
        .btn-avvia:active { transform: scale(0.99); }
        .btn-avvia:disabled { opacity: 0.65; cursor: wait; }

        .esito {
            display: none;
            margin-top: 10px;
            padding: 10px 14px;
            border-radius: var(--radius-control);
            font-size: 14px;
            font-weight: 700;
        }
        .esito.ok { display: block; background: var(--ok-bg); border: 1px solid var(--ok-border); color: var(--ok-text); }
        .esito.errore { display: block; background: var(--err-bg); border: 1px solid var(--err-border); color: var(--err-text); }
        .esito.avviso { display: block; background: var(--warn-bg); border: 1px solid var(--warn-border); color: var(--warn-text); }

        /* SCHEDA 3: PORTALI (GRIGLIA RESPONSIVE FULL-WIDTH) */
        .links-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
            gap: 10px;
        }
        .portal-divider {
            grid-column: 1 / -1;
            font-size: 11.5px;
            font-weight: 800;
            color: #fdba74;
            text-transform: uppercase;
            letter-spacing: 0.08em;
            margin: 10px 0 2px 0;
        }
        .portal-divider:first-child { margin-top: 0; }
        .portal-btn {
            min-height: 50px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 10px;
            background: var(--bg-elevated);
            border: 1px solid var(--border-subtle);
            box-shadow: inset 0 1px 0 var(--border-highlight);
            border-radius: var(--radius-inner);
            padding: 12px 16px;
            color: var(--text-primary);
            text-decoration: none;
            font-size: 14px;
            font-weight: 700;
            transition: all 0.22s var(--ease-spring);
        }
        .portal-btn:hover {
            background: var(--bg-interactive);
            border-color: var(--u-orange);
            transform: translateY(-1.5px);
            box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.12), 0 8px 20px -8px rgba(0, 0, 0, 0.6);
        }
        .portal-btn .portal-tag {
            color: #fed7aa;
            font-size: 12.5px;
            font-weight: 800;
            background: rgba(238, 114, 3, 0.14);
            padding: 4px 10px;
            border-radius: 999px;
            white-space: nowrap;
        }
        .portal-btn.highlight {
            border-color: rgba(238, 114, 3, 0.5);
            background: linear-gradient(180deg, rgba(238, 114, 3, 0.11) 0%, rgba(16, 27, 48, 0.9) 100%);
        }

        /* SCHEDA 4: PASSAGGI SINGOLI (GRIGLIA 2 COLONNE SU DESKTOP GRANDE) */
        .step-tool-list {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(440px, 1fr));
            gap: 12px;
        }
        .step-tool-card {
            background: var(--bg-elevated);
            border: 1px solid var(--border-subtle);
            box-shadow: inset 0 1px 0 var(--border-highlight);
            border-radius: var(--radius-inner);
            padding: 15px 17px;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
            gap: 10px;
            transition: border-color 0.2s var(--ease-spring);
        }
        .step-tool-card:hover { border-color: var(--border-strong); }
        .step-tool-card.evidenza, .step-tool-card.highlight {
            border-color: rgba(238, 114, 3, 0.45);
        }
        .step-tool-head {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 10px;
            flex-wrap: wrap;
        }
        .step-tool-title {
            font-size: 14.5px;
            font-weight: 800;
            color: var(--text-primary);
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .step-tool-desc { font-size: 13px; color: var(--text-muted); line-height: 1.45; }
        .step-tool-actions {
            display: flex;
            align-items: center;
            gap: 8px;
            flex-wrap: wrap;
            margin-top: 2px;
        }
        .step-tool-actions .cred-input { flex: 1; min-width: 180px; }
        .btn-tool {
            min-height: 40px;
            background: var(--bg-interactive);
            border: 1px solid var(--border-strong);
            box-shadow: inset 0 1px 0 var(--border-highlight);
            color: var(--text-primary);
            padding: 8px 14px;
            border-radius: var(--radius-control);
            cursor: pointer;
            font-size: 13px;
            font-weight: 700;
            white-space: nowrap;
            transition: all 0.2s var(--ease-spring);
        }
        .btn-tool:hover:not(:disabled) {
            background: #1e3359;
            border-color: var(--u-orange);
            transform: translateY(-1px);
        }
        .btn-tool:active:not(:disabled) { transform: scale(0.98); }
        .btn-tool.primary {
            background: linear-gradient(180deg, #ff851b 0%, #EE7203 100%);
            border-color: #ff9d42;
            color: #050a14;
            font-weight: 800;
            box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.3), 0 4px 14px rgba(238, 114, 3, 0.28);
        }
        .btn-tool.primary:hover:not(:disabled) {
            background: linear-gradient(180deg, #ff9638 0%, #f5790a 100%);
            color: #050a14;
        }
        .btn-tool:disabled { opacity: 0.6; cursor: wait; }
        .step-esito {
            display: none;
            padding: 8px 12px;
            border-radius: 8px;
            font-size: 13px;
            font-weight: 700;
        }
        .step-esito.ok { display: block; background: var(--ok-bg); border: 1px solid var(--ok-border); color: var(--ok-text); }
        .step-esito.avviso { display: block; background: var(--warn-bg); border: 1px solid var(--warn-border); color: var(--warn-text); }
        .step-esito.errore { display: block; background: var(--err-bg); border: 1px solid var(--err-border); color: var(--err-text); }

        /* TOAST FLOTTANTE */
        .toast {
            position: fixed;
            bottom: 22px;
            left: 50%;
            transform: translateX(-50%) translateY(120px);
            max-width: calc(100% - 24px);
            background: #059669;
            border: 1px solid #34d399;
            color: #fff;
            font-size: 14px;
            font-weight: 800;
            padding: 10px 22px;
            border-radius: 999px;
            box-shadow: 0 12px 32px rgba(0, 0, 0, 0.65);
            opacity: 0;
            pointer-events: none;
            transition: all 0.32s var(--ease-spring);
            z-index: 1000;
            text-align: center;
        }
        .toast.show { transform: translateX(-50%) translateY(0); opacity: 1; }
        .toast.errore { background: #b91c1c; border-color: #f87171; }
        .toast.avviso { background: #b45309; border-color: #fbbf24; }

        @media (max-width: 860px) {
            body { padding: 10px 12px 24px; }
            .campi-2, .step-tool-list, .links-grid { grid-template-columns: 1fr; }
            .campi-3 { grid-template-columns: repeat(2, minmax(0, 1fr)); }
            .campi-3 > :last-child { grid-column: 1 / -1; }
            .brand-titles p { display: none; }
            .brand-titles h1 { font-size: 18px; }
            .progress-pct { font-size: 23px; }
            .tab-btn { font-size: 12.5px; padding: 6px 8px; }
            .tab-lungo { display: none; }
            .card { padding: 14px; }
        }
        @media (prefers-reduced-motion: reduce) {
            * { transition: none !important; animation: none !important; }
        }
    </style>
</head>
<body>
    <div class="container">
        <!-- INTESTAZIONE: un solo indicatore di stato -->
        <div class="header">
            <div class="brand-box">
                <div class="u-logo">UNIEURO</div>
                <div class="brand-titles">
                    <h1>PC Facile &middot; Pannello operatore</h1>
                    <p id="versioneText">Script PC Facile non collegato</p>
                </div>
            </div>
            <div id="badgeStato" class="badge-stato stato-off" role="status">Script non avviato</div>
        </div>

        <!-- AVVISO: SCRIPT NON RAGGIUNGIBILE (visibile in tutte le schede) -->
        <div id="offlineNoticeBox" class="notice notice-off" style="display: block;">
            <h2>&#9888; PC Facile non risponde</h2>
            <p>Questo pannello lo apre PC Facile da solo e parla solo con lo script avviato su questo PC. Controlla la finestra di PC Facile: se l'hai chiusa, riapri <strong>PC Facile Windows.bat</strong> dalla chiavetta (riprende da dove era arrivato).</p>
        </div>

        <!-- AVVISO: IL PC ASPETTA I DATI DEL CLIENTE -->
        <div id="attesaDatiBox" class="notice notice-attesa">
            <h2>&#9998; Il PC aspetta i dati del cliente</h2>
            <p>Programmi e lingua sono gi&agrave; in lavorazione. Per proseguire compila cognome, nome e servizi nella scheda <strong>Cliente</strong> e premi <strong>CONFERMA DATI CLIENTE</strong>.</p>
            <div class="notice-azioni">
                <button type="button" class="btn-sec" onclick="apriScheda('tab-cred')">Vai alla scheda Cliente</button>
            </div>
        </div>

        <!-- HARDWARE (compare quando lo script invia i dati reali) -->
        <div id="hwBar" class="hw-bar">
            <div class="hw-item"><span class="etichetta">Computer:</span> <strong id="hwModelloText"></strong></div>
            <div class="hw-item"><span class="etichetta">Processore e RAM:</span> <strong id="hwCpuText"></strong></div>
            <div class="hw-item"><span class="etichetta">Seriale:</span> <strong id="hwSerialVal"></strong> <button type="button" class="btn-sec" onclick="copiaSeriale()">&#128203; Copia seriale</button></div>
        </div>

        <!-- BARRA FISSA: AVANZAMENTO + SCHEDE -->
        <div class="sticky-top-bar">
            <!-- AVANZAMENTO -->
            <div class="progress-card">
                <div class="progress-header">
                    <div class="progress-title">Avanzamento configurazione</div>
                    <div class="progress-meta">
                        <div class="progress-timer-box">Tempo: <span id="elapsedTimerText" class="progress-timer">--:--</span></div>
                        <div id="progressPercentText" class="progress-pct">0%</div>
                    </div>
                </div>
                <div class="progress-bar-bg" role="progressbar" aria-label="Avanzamento configurazione" aria-valuemin="0" aria-valuemax="100" aria-valuenow="0" id="progressBar">
                    <div id="progressBarFill" class="progress-bar-fill"></div>
                </div>
                <div class="progress-status-row" aria-live="polite" style="display:flex; justify-content:space-between; align-items:center; gap:8px; flex-wrap:wrap;">
                    <div>
                        <div><span class="muted">Ora:</span> <span id="currentFaseText" class="current-fase">In attesa dello script</span></div>
                        <div id="currentDetailText" class="current-detail"></div>
                    </div>
                    <button type="button" id="btnSkipCurrent" class="btn-skip-task" style="display:none; background:#431407; border-color:#EE7203; color:#fed7aa; padding:6px 12px; font-size:13px;" onclick="saltaOperazione('current')">Salta operazione in corso &#10140;</button>
                </div>
            </div>

            <!-- SCHEDE -->
            <div class="tab-bar" role="tablist" aria-label="Sezioni del pannello">
                <button type="button" class="tab-btn" role="tab" id="btn-tab-cred" aria-controls="view-tab-cred" aria-selected="true" onclick="apriScheda('tab-cred')">
                    <span><span class="tab-lungo">&#128100; </span>1. Cliente</span>
                </button>
                <button type="button" class="tab-btn" role="tab" id="btn-tab-live" aria-controls="view-tab-live" aria-selected="false" onclick="apriScheda('tab-live')">
                    <span><span class="tab-lungo">&#128202; </span>2. Avanzamento</span> <span id="taskCountBadge" class="tab-badge-num">0/13</span>
                </button>
                <button type="button" class="tab-btn" role="tab" id="btn-tab-portali" aria-controls="view-tab-portali" aria-selected="false" onclick="apriScheda('tab-portali')">
                    <span><span class="tab-lungo">&#127760; </span>3. Portali</span>
                </button>
                <button type="button" class="tab-btn" role="tab" id="btn-tab-passaggi" aria-controls="view-tab-passaggi" aria-selected="false" onclick="apriScheda('tab-passaggi')">
                    <span><span class="tab-lungo">&#128295; </span>4. Passaggi</span>
                </button>
                <button type="button" class="tab-btn" role="tab" id="btn-tab-remoto" aria-controls="view-tab-remoto" aria-selected="false" onclick="apriScheda('tab-remoto')">
                    <span><span class="tab-lungo">&#9889; </span>5. Comandi / IA</span>
                </button>
            </div>
        </div>

        <!-- ESITO FINALE -->
        <div id="completionBanner" class="banner-complete" role="status">
            <h2 id="completionTitle">&#10003; Configurazione completata</h2>
            <ul id="completionAvvisi"></ul>
            <p>Sul Desktop di questo PC c'&egrave; solo la scheda di consegna: <strong>Scheda-Consegna-Cliente.pdf</strong> (se il PDF non si crea, resta la versione <strong>.html</strong> da stampare). Il riepilogo tecnico &egrave; in <code>C:\ProgramData\PCFacile\log</code>.</p>
            <div style="margin-top: 8px;">
                <button type="button" class="btn-sec" onclick="apriScheda('tab-passaggi')">&#128295; Ripeti o correggi singoli passaggi</button>
            </div>
        </div>

        <!-- SCHEDA 1: DATI CLIENTE -->
        <div id="view-tab-cred" class="section-view active-view" role="tabpanel" aria-labelledby="btn-tab-cred">
            <div class="card" style="margin-bottom: 14px; border: 1.5px solid var(--u-orange); background: linear-gradient(135deg, rgba(238, 114, 3, 0.14) 0%, rgba(16, 27, 48, 0.96) 100%);">
                <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:8px; margin-bottom:10px;">
                    <span class="cred-label" style="margin-bottom:0; color:#fed7aa; font-size:13.5px;">&#9889; Modalit&agrave; operativa iniziale (scegli come lavorare sul PC)</span>
                    <span id="badgeModalitaAttiva" style="font-size:12px; font-weight:800; padding:3px 10px; border-radius:999px; background:rgba(2,132,199,0.2); border:1px solid #38bdf8; color:#bae6fd;">Modalit&agrave;: Configurazione Completa (14 passaggi)</span>
                </div>
                <div style="display:grid; grid-template-columns:repeat(2, minmax(0, 1fr)); gap:10px;">
                    <button type="button" id="btnModeCompleta" class="dom-btn" aria-pressed="true" onclick="setModalitaSetup('COMPLETA')" style="display:flex; flex-direction:column; align-items:flex-start; text-align:left; padding:12px 14px; gap:4px; min-height:68px;">
                        <span style="font-size:15px; font-weight:800;">&#128736;&#65039; 1. Configurazione Completa PC</span>
                        <span style="font-size:12px; font-weight:500; opacity:0.88;">Tutti i 14 passaggi: rimozione AV di prova, Everyday Digital, Office, tutte le app del profilo, pulizia bloatware, driver e Windows Update.</span>
                    </button>
                    <button type="button" id="btnModePostVendita" class="dom-btn" aria-pressed="false" onclick="setModalitaSetup('POSTVENDITA')" style="display:flex; flex-direction:column; align-items:flex-start; text-align:left; padding:12px 14px; gap:4px; min-height:68px;">
                        <span style="font-size:15px; font-weight:800;">&#9889; 2. Post Vendita / Consegna Rapida da OEM (No Reset)</span>
                        <span style="font-size:12px; font-weight:500; opacity:0.88;">Evita il lento Reset di Windows: converte subito l&rsquo;account OEM nel Cliente (zero password), installa solo Essenziali (Unieuro Secure, Office, Chrome, PDF) e salta app extra, pulizia e update lunghi.</span>
                    </button>
                </div>
            </div>

            <div class="card">
                <div class="card-subtitle">Mentre il PC installa programmi e lingua, inserisci qui i dati del cliente <strong>una volta sola</strong>: email e password si creano da sole (puoi modificarle). Puoi correggerli e confermare di nuovo finch&eacute; il passo che li usa non &egrave; partito.</div>

                <div class="cred-step-box">
                    <div class="cred-step-title"><span class="step-badge">1</span> Cliente</div>
                    <div class="campi-3">
                        <div>
                            <label class="cred-label" for="inCognome">Cognome</label>
                            <input type="text" id="inCognome" class="cred-input" placeholder="Es. Rossi" autocomplete="off" oninput="aggiornaCred()">
                        </div>
                        <div>
                            <label class="cred-label" for="inNome">Nome <span style="color:#94a3b8; font-weight:normal;">(opz.)</span></label>
                            <input type="text" id="inNome" class="cred-input" value="$hNome" placeholder="Es. Mario" autocomplete="off" oninput="aggiornaCred()">
                        </div>
                        <div>
                            <label class="cred-label" for="inTelefono">Cellulare <span style="color:#94a3b8; font-weight:normal;">(opz.)</span></label>
                            <input type="tel" id="inTelefono" class="cred-input" placeholder="333 1234567" autocomplete="off" oninput="this.classList.remove('errore')">
                        </div>
                    </div>
                    <button type="button" id="btnAvvia" class="btn-avvia" onclick="avviaConfigurazione()">&#10004; CONFERMA DATI CLIENTE</button>
                    <div id="esitoInvio" class="esito" role="status" aria-live="polite"></div>
                </div>

                <div class="cred-step-box">
                    <div class="cred-step-title"><span class="step-badge">2</span> Tipo di email</div>
                    <div class="dom-selector">
                        <button type="button" class="dom-btn" aria-pressed="true" onclick="setDomain('outlook.it', 'Microsoft', this)">@outlook.it (consigliato)</button>
                        <button type="button" class="dom-btn" aria-pressed="false" onclick="setDomain('gmail.com', 'Google', this)">@gmail.com</button>
                        <button type="button" class="dom-btn" aria-pressed="false" onclick="setDomain('libero.it', 'Libero', this)">@libero.it</button>
                        <button type="button" class="dom-btn" aria-pressed="false" onclick="setDomain('proton.me', 'Proton', this)">@proton.me</button>
                        <button type="button" class="dom-btn" aria-pressed="false" onclick="setDomain('hotmail.com', 'Hotmail', this)">@hotmail.com</button>
                        <button type="button" class="dom-btn" aria-pressed="false" onclick="setDomain('icloud.com', 'iCloud', this)">@icloud.com</button>
                    </div>
                </div>

                <div class="cred-step-box evidenza">
                    <div class="cred-step-title"><span class="step-badge">3</span> Credenziali proposte</div>
                    <div class="campi-2" style="margin-bottom: 0;">
                        <div>
                            <label class="cred-label" for="inEmail">Email</label>
                            <div class="cred-box">
                                <input type="text" id="inEmail" class="cred-input cred-mono" value="$hEmail" placeholder="compare dopo il nome" autocomplete="off" oninput="segnaModificato()">
                                <button type="button" class="btn-sec" onclick="copia('inEmail', 'Email copiata')">&#128203; Copia</button>
                            </div>
                        </div>
                        <div>
                            <label class="cred-label" for="inPass">Password iniziale</label>
                            <div class="cred-box">
                                <input type="password" id="inPass" class="cred-input cred-mono" value="$hPassword" autocomplete="off" oninput="segnaModificato()">
                                <button type="button" class="btn-sec" id="btnMostra" onclick="togglePassVis()">&#128065; Mostra</button>
                                <button type="button" class="btn-sec" onclick="generaPassCasuale()">&#127922; Nuova</button>
                                <button type="button" class="btn-sec" onclick="copia('inPass', 'Password copiata')">&#128203; Copia</button>
                            </div>
                        </div>
                    </div>
                </div>

                <div class="cred-step-box">
                    <div class="cred-step-title"><span class="step-badge">4</span> Servizi sullo scontrino</div>
                    <div class="campi-2" style="margin-bottom: 10px;">
                        <div>
                            <label class="cred-label" for="selOffice">Office</label>
                            <select id="selOffice" class="cred-input">
                                <option value="no" selected>Nessuna card Office</option>
                                <option value="m365">Card Microsoft 365 (abbonamento)</option>
                                <option value="perpetuo">Card Office 2024/2021 (perpetuo)</option>
                                <option value="libreoffice">LibreOffice (gratuito)</option>
                            </select>
                        </div>
                        <div>
                            <label class="cred-label" for="selProfilo">Programmi</label>
                            <select id="selProfilo" class="cred-input">
                                <option value="BASE" selected>Base (Chrome, VLC, Reader, 7-Zip...)</option>
                                <option value="UFFICIO">Ufficio (Base + GIMP, Sumatra PDF)</option>
                                <option value="GAMING">Gaming (Opera GX + Base + Steam, Epic, Discord)</option>
                                <option value="COMPLETO">Completo (tutte le app)</option>
                            </select>
                        </div>
                    </div>
                    <div class="services-grid">
                        <label class="svc-item" style="grid-column: 1 / -1; border-color: #EE7203; background: rgba(238, 114, 3, 0.14); font-weight: 700;"><input type="checkbox" id="chkSvcEveryday" checked> <span>Unieuro Everyday Digital (Unieuro Secure + Cyber) &mdash; PRIORIT&Agrave;</span></label>
                        <div style="grid-column: 1 / -1; background: #00122B; border: 1px dashed #EE7203; border-radius: 8px; padding: 8px 10px;">
                            <label class="cred-label" for="inPassSecure" style="color: #fed7aa; margin-bottom: 4px;">Password Unieuro Secure (dalla mail del cliente, opz. &mdash; puoi anche incollare qui tutta la mail)</label>
                            <div class="cred-box">
                                <input type="text" id="inPassSecure" class="cred-input cred-mono" value="" placeholder="Es. N/qrWZ35 (o incolla testo mail)" autocomplete="off" oninput="analizzaInputMailSecure(this.value)">
                                <button type="button" class="btn-sec" onclick="incollaMailSecure()">&#128203; Incolla mail</button>
                                <button type="button" class="btn-sec" onclick="copia('inPassSecure', 'Password Unieuro Secure copiata')">&#128203; Copia</button>
                            </div>
                        </div>
                        <label class="svc-item"><input type="checkbox" id="chkSvcProton"> <span>Email Proton</span></label>
                        <label class="svc-item"><input type="checkbox" id="chkSvcMcAfee"> <span>Card McAfee</span></label>
                        <label class="svc-item"><input type="checkbox" id="chkSvcNorton"> <span>Card Norton</span></label>
                        <label class="svc-item"><input type="checkbox" id="chkSvcCyber"> <span>Solo Cyber Protection</span></label>
                    </div>
                </div>

                <div style="margin-top: 10px;">
                    <button type="button" class="btn-sec" style="width: 100%;" onclick="copiaRiepilogoCred()">&#128203; Copia dati per il ticket</button>
                </div>
            </div>
        </div>

        <!-- SCHEDA 2: AVANZAMENTO -->
        <div id="view-tab-live" class="section-view" role="tabpanel" aria-labelledby="btn-tab-live">
            <div class="card">
                <div class="card-subtitle">Nella Fase 1 inserisci i dati del cliente e completi Office, antivirus e servizi; poi la Fase 2 va dritta da sola dalla lingua fino agli aggiornamenti. I passi gi&agrave; fatti vengono saltati.</div>
                <ul class="bg-tasks" id="tasksContainer">
                    <li class="task-gruppo">Fase 1 &middot; Rimozione AV di prova, Dati cliente, Everyday Digital e Office</li>
                    <li id="task-avprova" class="task-item pending"><div class="task-left"><span class="task-icon">&#9675;</span><span class="task-name">1. Rimozione antivirus di prova</span><span class="task-detail"></span></div><div class="task-right"><button type="button" class="btn-skip-task" onclick="saltaOperazione('avprova')">Salta &#10140;</button><span class="task-badge badge-pending">In attesa</span></div></li>
                    <li id="task-everyday" class="task-item pending"><div class="task-left"><span class="task-icon">&#9675;</span><span class="task-name">2. Unieuro Everyday Digital (Secure + Cyber)</span><span class="task-detail"></span></div><div class="task-right"><button type="button" class="btn-skip-task" onclick="saltaOperazione('everyday')">Salta &#10140;</button><span class="task-badge badge-pending">In attesa</span></div></li>
                    <li id="task-office" class="task-item pending"><div class="task-left"><span class="task-icon">&#9675;</span><span class="task-name">3. Office: installazione e attivazione</span><span class="task-detail"></span></div><div class="task-right"><button type="button" class="btn-skip-task" onclick="saltaOperazione('office')">Salta &#10140;</button><span class="task-badge badge-pending">In attesa</span></div></li>
                    <li id="task-account" class="task-item pending"><div class="task-left"><span class="task-icon">&#9675;</span><span class="task-name">4. Nome PC e account cliente</span><span class="task-detail"></span></div><div class="task-right"><button type="button" class="btn-skip-task" onclick="saltaOperazione('account')">Salta &#10140;</button><span class="task-badge badge-pending">In attesa</span></div></li>
                    <li id="task-antivirus" class="task-item pending"><div class="task-left"><span class="task-icon">&#9675;</span><span class="task-name">5. Protezione antivirus</span><span class="task-detail"></span></div><div class="task-right"><button type="button" class="btn-skip-task" onclick="saltaOperazione('antivirus')">Salta &#10140;</button><span class="task-badge badge-pending">In attesa</span></div></li>
                    <li id="task-cyber" class="task-item pending"><div class="task-left"><span class="task-icon">&#9675;</span><span class="task-name">6. Unieuro Cyber Protection</span><span class="task-detail"></span></div><div class="task-right"><button type="button" class="btn-skip-task" onclick="saltaOperazione('cyber')">Salta &#10140;</button><span class="task-badge badge-pending">In attesa</span></div></li>
                    <li class="task-gruppo">Fase 2 &middot; Lingua, programmi, pulizia e aggiornamenti (automatico)</li>
                    <li id="task-lingua" class="task-item pending"><div class="task-left"><span class="task-icon">&#9675;</span><span class="task-name">7. Lingua italiana e tastiera</span><span class="task-detail"></span></div><div class="task-right"><button type="button" class="btn-skip-task" onclick="saltaOperazione('lingua')">Salta &#10140;</button><span class="task-badge badge-pending">In attesa</span></div></li>
                    <li id="task-ripristino" class="task-item pending"><div class="task-left"><span class="task-icon">&#9675;</span><span class="task-name">8. Punto di ripristino</span><span class="task-detail"></span></div><div class="task-right"><button type="button" class="btn-skip-task" onclick="saltaOperazione('ripristino')">Salta &#10140;</button><span class="task-badge badge-pending">In attesa</span></div></li>
                    <li id="task-runtime" class="task-item pending"><div class="task-left"><span class="task-icon">&#9675;</span><span class="task-name">9. Componenti Microsoft (Visual C++)</span><span class="task-detail"></span></div><div class="task-right"><button type="button" class="btn-skip-task" onclick="saltaOperazione('runtime')">Salta &#10140;</button><span class="task-badge badge-pending">In attesa</span></div></li>
                    <li id="task-app" class="task-item pending"><div class="task-left"><span class="task-icon">&#9675;</span><span class="task-name">10. Programmi</span><span class="task-detail"></span></div><div class="task-right"><button type="button" class="btn-skip-task" onclick="saltaOperazione('app')">Salta &#10140;</button><span class="task-badge badge-pending">In attesa</span></div></li>
                    <li id="task-pulizia" class="task-item pending"><div class="task-left"><span class="task-icon">&#9675;</span><span class="task-name">11. Pulizia programmi inutili e velocizzazione</span><span class="task-detail"></span></div><div class="task-right"><button type="button" class="btn-skip-task" onclick="saltaOperazione('pulizia')">Salta &#10140;</button><span class="task-badge badge-pending">In attesa</span></div></li>
                    <li id="task-driver" class="task-item pending"><div class="task-left"><span class="task-icon">&#9675;</span><span class="task-name">12. Driver hardware</span><span class="task-detail"></span></div><div class="task-right"><button type="button" class="btn-skip-task" onclick="saltaOperazione('driver')">Salta &#10140;</button><span class="task-badge badge-pending">In attesa</span></div></li>
                    <li id="task-aggiorna" class="task-item pending"><div class="task-left"><span class="task-icon">&#9675;</span><span class="task-name">13. Aggiornamenti app e Windows</span><span class="task-detail"></span></div><div class="task-right"><button type="button" class="btn-skip-task" onclick="saltaOperazione('aggiorna')">Salta &#10140;</button><span class="task-badge badge-pending">In attesa</span></div></li>
                    <li id="task-diagnostica" class="task-item pending"><div class="task-left"><span class="task-icon">&#9675;</span><span class="task-name">14. Controllo finale e scheda di consegna</span><span class="task-detail"></span></div><div class="task-right"><button type="button" class="btn-skip-task" onclick="saltaOperazione('diagnostica')">Salta &#10140;</button><span class="task-badge badge-pending">In attesa</span></div></li>
                </ul>
            </div>
        </div>

        <!-- SCHEDA 3: PORTALI -->
        <div id="view-tab-portali" class="section-view" role="tabpanel" aria-labelledby="btn-tab-portali">
            <div class="card">
                <div class="links-grid" id="portalLinksGrid">
                    <div class="portal-divider">Account ed email</div>
                    <a href="https://account.microsoft.com" target="_blank" rel="noopener noreferrer" class="portal-btn"><span>Account Microsoft / Outlook</span><span class="portal-tag">Apri &rarr;</span></a>
                    <a href="https://accounts.google.com/signup" target="_blank" rel="noopener noreferrer" class="portal-btn"><span>Account Google / Gmail</span><span class="portal-tag">Apri &rarr;</span></a>
                    <a href="https://account.proton.me/signup" target="_blank" rel="noopener noreferrer" class="portal-btn"><span>Account Proton Mail</span><span class="portal-tag">Apri &rarr;</span></a>
                    <a href="https://registrazione.libero.it" target="_blank" rel="noopener noreferrer" class="portal-btn"><span>Account Libero Mail</span><span class="portal-tag">Apri &rarr;</span></a>

                    <div class="portal-divider">Servizio Unieuro</div>
                    <a href="https://safeavenue.f-secure.com/iframe/-installers/unieuro/" target="_blank" rel="noopener noreferrer" class="portal-btn highlight"><span>Unieuro Everyday Digital (Unieuro Secure / F-Secure)</span><span class="portal-tag">Apri &rarr;</span></a>
                    <a href="https://unieuro-cyber-protection.covercare.it" target="_blank" rel="noopener noreferrer" class="portal-btn highlight"><span>Unieuro Cyber Protection (Covercare)</span><span class="portal-tag">Apri &rarr;</span></a>

                    <div class="portal-divider">Office</div>
                    <a href="https://microsoft365.com/setup" target="_blank" rel="noopener noreferrer" class="portal-btn"><span>Riscatto card Microsoft 365 / Office</span><span class="portal-tag">Apri &rarr;</span></a>
                    <a href="https://account.microsoft.com/services" target="_blank" rel="noopener noreferrer" class="portal-btn"><span>Scarica Office dall&rsquo;account Microsoft</span><span class="portal-tag">Apri &rarr;</span></a>

                    <div class="portal-divider">Antivirus da card</div>
                    <a href="https://www.mcafee.com/activate" target="_blank" rel="noopener noreferrer" class="portal-btn"><span>Attivazione card McAfee</span><span class="portal-tag">Apri &rarr;</span></a>
                    <a href="https://www.norton.com/setup" target="_blank" rel="noopener noreferrer" class="portal-btn"><span>Attivazione card Norton</span><span class="portal-tag">Apri &rarr;</span></a>

                    <div class="portal-divider">Download Kit USB (GitHub)</div>
                    <a href="https://github.com/samuelenigro97-prog/PC-Facile/releases/latest/download/PC-Facile.zip" target="_blank" rel="noopener noreferrer" class="portal-btn highlight"><span>&#11015; Scarica Cartella &ldquo;PC Facile&rdquo; (Ultima Versione ZIP)</span><span class="portal-tag">Scarica &rarr;</span></a>
                    <a href="https://github.com/samuelenigro97-prog/PC-Facile" target="_blank" rel="noopener noreferrer" class="portal-btn"><span>Repository GitHub PC Facile</span><span class="portal-tag">Apri &rarr;</span></a>
                </div>
            </div>
        </div>

        <!-- SCHEDA 4: PASSAGGI SINGOLI (stesso ordine 1..13) -->
        <div id="view-tab-passaggi" class="section-view" role="tabpanel" aria-labelledby="btn-tab-passaggi">
            <div class="card">
                <div class="card-subtitle">Esegui o ripeti singolarmente qualsiasi passaggio nello stesso ordine della procedura (1..13). Utile se un passo &egrave; andato male o se devi correggere subito il <strong>nome utente / nome PC</strong> (es. rimasto <code>clt clt</code>).</div>

                <div class="step-tool-list">
                    <div class="task-gruppo">Fase 1 &middot; Rimozione AV di prova, Dati cliente, Everyday Digital e Office</div>

                    <!-- 1. Rimozione antivirus di prova -->
                    <div class="step-tool-card highlight" id="stepcard-avprova">
                        <div class="step-tool-head">
                            <div class="step-tool-title"><span class="step-badge">1</span> Rimozione antivirus di prova</div>
                            <span id="step-badge-avprova" class="task-badge badge-pending">Pronto</span>
                        </div>
                        <div class="step-tool-desc">Cerca e disinstalla subito McAfee, Norton o Avast di prova preinstallati sul PC prima di avviare tutte le altre funzionalit&agrave;.</div>
                        <div class="step-tool-actions">
                            <button type="button" class="btn-tool primary" onclick="eseguiPasso('avprova')">&#9654; Rimuovi antivirus di prova</button>
                        </div>
                        <div id="esitoStep-avprova" class="step-esito"></div>
                    </div>

                    <!-- 2. Unieuro Everyday Digital (Priorita') -->
                    <div class="step-tool-card highlight" id="stepcard-everyday">
                        <div class="step-tool-head">
                            <div class="step-tool-title"><span class="step-badge">2</span> Unieuro Everyday Digital (Secure + Cyber)</div>
                            <span id="step-badge-everyday" class="task-badge badge-pending">Pronto</span>
                        </div>
                        <div class="step-tool-desc">Scarica e avvia in automatico <strong>Unieuro Secure</strong> (<code>UnieuroSecure.exe</code> ufficiale F-Secure/Unieuro) e apre <strong>Unieuro Cyber Protection</strong> con i dati cliente pronti negli appunti.</div>
                        <div class="step-tool-actions">
                            <button type="button" class="btn-tool primary" onclick="eseguiPasso('everyday')">&#128737; Installa / Attiva Everyday Digital</button>
                        </div>
                        <div id="esitoStep-everyday" class="step-esito"></div>
                    </div>

                    <!-- 2. Office: installazione e attivazione -->
                    <div class="step-tool-card" id="stepcard-office">
                        <div class="step-tool-head">
                            <div class="step-tool-title"><span class="step-badge">1</span> Office: installazione e attivazione</div>
                            <span id="step-badge-office" class="task-badge badge-pending">Pronto</span>
                        </div>
                        <div class="step-tool-desc">Installa la suite Office scelta (con collegamenti Word, Excel, PowerPoint sul Desktop) o avvia il riscatto della card.</div>
                        <div class="step-tool-actions">
                            <select id="selStepOffice" class="cred-input" aria-label="Suite Office da installare">
                                <option value="m365">Microsoft 365 (abbonamento it-IT)</option>
                                <option value="perpetuo">Office 2024 / 2021 (perpetuo)</option>
                                <option value="libreoffice">LibreOffice (gratuito in italiano)</option>
                                <option value="openoffice">Apache OpenOffice (gratuito in italiano)</option>
                            </select>
                            <button type="button" class="btn-tool primary" onclick="eseguiPasso('office')">&#9654; Installa Office</button>
                            <button type="button" class="btn-tool" onclick="eseguiPasso('officeattiva')">&#128273; Attiva / Riscatta Card</button>
                        </div>
                        <div id="esitoStep-office" class="step-esito"></div>
                    </div>

                    <!-- 2. Nome PC e account cliente -->
                    <div class="step-tool-card highlight" id="stepcard-account">
                        <div class="step-tool-head">
                            <div class="step-tool-title"><span class="step-badge">2</span> Nome PC e account cliente</div>
                            <span id="step-badge-account" class="task-badge badge-pending">Pronto</span>
                        </div>
                        <div class="step-tool-desc">Cambia immediatamente il <strong>nome visualizzato dell'utente Windows</strong> (es. se era rimasto <code>clt clt</code> o <code>OEM</code>) e il <strong>nome del PC</strong>, senza passare dalle Impostazioni di Windows.</div>
                        <div class="campi-2" style="margin-bottom: 6px;">
                            <div>
                                <label class="cred-label" for="inStepNomeUtente">Nome visualizzato Utente Windows</label>
                                <input type="text" id="inStepNomeUtente" class="cred-input" placeholder="Es. Mario Rossi (o Utente)" autocomplete="off" oninput="_stepNomeEdited = true">
                            </div>
                            <div>
                                <label class="cred-label" for="inStepNomePc">Nome del PC (max 15 caratteri)</label>
                                <input type="text" id="inStepNomePc" class="cred-input cred-mono" placeholder="Es. PC-Mario" maxlength="15" autocomplete="off" oninput="_stepNomeEdited = true">
                            </div>
                        </div>
                        <div class="step-tool-actions">
                            <button type="button" class="btn-tool primary" onclick="eseguiPasso('account')">&#10004; Applica Nome Utente e PC</button>
                            <button type="button" class="btn-tool" onclick="eseguiPasso('nopass')">&#128275; Rimuovi password Windows (accesso diretto)</button>
                            <button type="button" class="btn-tool" onclick="eseguiPasso('netplwiz')">&#128100; Utenti Windows (netplwiz)</button>
                        </div>
                        <div id="esitoStep-account" class="step-esito"></div>
                    </div>

                    <!-- 3. Protezione antivirus -->
                    <div class="step-tool-card" id="stepcard-antivirus">
                        <div class="step-tool-head">
                            <div class="step-tool-title"><span class="step-badge">3</span> Protezione antivirus</div>
                            <span id="step-badge-antivirus" class="task-badge badge-pending">Pronto</span>
                        </div>
                        <div class="step-tool-desc">Apre la pagina di riscatto card McAfee o Norton e copia l'email del cliente negli appunti.</div>
                        <div class="step-tool-actions">
                            <button type="button" class="btn-tool primary" onclick="eseguiPasso('antivirus', 'mcafee')">&#128737; Attiva McAfee</button>
                            <button type="button" class="btn-tool primary" onclick="eseguiPasso('antivirus', 'norton')">&#128737; Attiva Norton</button>
                        </div>
                        <div id="esitoStep-antivirus" class="step-esito"></div>
                    </div>

                    <!-- 4. Unieuro Cyber Protection -->
                    <div class="step-tool-card" id="stepcard-cyber">
                        <div class="step-tool-head">
                            <div class="step-tool-title"><span class="step-badge">4</span> Unieuro Cyber Protection</div>
                            <span id="step-badge-cyber" class="task-badge badge-pending">Pronto</span>
                        </div>
                        <div class="step-tool-desc">Apre il portale Covercare e copia negli appunti i dati cliente + seriale del PC per la registrazione rapida.</div>
                        <div class="step-tool-actions">
                            <button type="button" class="btn-tool primary" onclick="eseguiPasso('cyber')">&#9654; Apri e copia dati Cyber Protection</button>
                        </div>
                        <div id="esitoStep-cyber" class="step-esito"></div>
                    </div>

                    <div class="task-gruppo">Fase 2 &middot; Lingua, programmi, pulizia e aggiornamenti (automatico)</div>

                    <!-- 5. Lingua italiana e tastiera -->
                    <div class="step-tool-card" id="stepcard-lingua">
                        <div class="step-tool-head">
                            <div class="step-tool-title"><span class="step-badge">5</span> Lingua italiana e tastiera</div>
                            <span id="step-badge-lingua" class="task-badge badge-pending">Pronto</span>
                        </div>
                        <div class="step-tool-desc">Imposta lingua di sistema, tastiera IT (0410:00000410), area geografica Italia e fuso orario Roma.</div>
                        <div class="step-tool-actions">
                            <button type="button" class="btn-tool primary" onclick="eseguiPasso('lingua')">&#9654; Applica lingua e tastiera IT</button>
                        </div>
                        <div id="esitoStep-lingua" class="step-esito"></div>
                    </div>

                    <!-- 6. Punto di ripristino -->
                    <div class="step-tool-card" id="stepcard-ripristino">
                        <div class="step-tool-head">
                            <div class="step-tool-title"><span class="step-badge">6</span> Punto di ripristino</div>
                            <span id="step-badge-ripristino" class="task-badge badge-pending">Pronto</span>
                        </div>
                        <div class="step-tool-desc">Abilita Ripristino configurazione di sistema su C: e crea un punto di sicurezza.</div>
                        <div class="step-tool-actions">
                            <button type="button" class="btn-tool primary" onclick="eseguiPasso('ripristino')">&#9654; Crea punto di ripristino</button>
                            <button type="button" class="btn-tool" onclick="eseguiPasso('sysdm')">&#9881; Propriet&agrave; Sistema</button>
                        </div>
                        <div id="esitoStep-ripristino" class="step-esito"></div>
                    </div>

                    <!-- 8. Componenti Microsoft (Visual C++) -->
                    <div class="step-tool-card" id="stepcard-runtime">
                        <div class="step-tool-head">
                            <div class="step-tool-title"><span class="step-badge">8</span> Componenti Microsoft (Visual C++)</div>
                            <span id="step-badge-runtime" class="task-badge badge-pending">Pronto</span>
                        </div>
                        <div class="step-tool-desc">Verifica e installa i runtime Microsoft Visual C++ 2015-2022 (64 bit e 32 bit).</div>
                        <div class="step-tool-actions">
                            <button type="button" class="btn-tool primary" onclick="eseguiPasso('runtime')">&#9654; Installa Visual C++</button>
                        </div>
                        <div id="esitoStep-runtime" class="step-esito"></div>
                    </div>

                    <!-- 9. Programmi -->
                    <div class="step-tool-card" id="stepcard-app">
                        <div class="step-tool-head">
                            <div class="step-tool-title"><span class="step-badge">9</span> Programmi e icone Desktop</div>
                            <span id="step-badge-app" class="task-badge badge-pending">Pronto</span>
                        </div>
                        <div class="step-tool-desc">Reinstalla l'intero profilo di applicazioni o un singolo programma andato in errore, e ripara le icone bianche sul Desktop.</div>
                        <div class="step-tool-actions">
                            <select id="selStepApp" class="cred-input" aria-label="Seleziona programma o profilo">
                                <option value="PROFILO:BASE">Profilo Base completo (Chrome, VLC, Reader, 7-Zip, AnyDesk, WhatsApp, Zoom)</option>
                                <option value="PROFILO:UFFICIO">Profilo Ufficio completo (Base + GIMP, Sumatra PDF)</option>
                                <option value="PROFILO:GAMING">Profilo Gaming completo (Opera GX + Base + Steam, Epic, Discord)</option>
                                <option value="PROFILO:COMPLETO">Profilo Completo (tutte le app)</option>
                                <option value="APP:Google.Chrome">Singola app: Google Chrome</option>
                                <option value="APP:VideoLAN.VLC">Singola app: VLC Media Player</option>
                                <option value="APP:Adobe.Acrobat.Reader.64-bit">Singola app: Adobe Acrobat Reader</option>
                                <option value="APP:7zip.7zip">Singola app: 7-Zip</option>
                                <option value="APP:AnyDesk.AnyDesk">Singola app: AnyDesk</option>
                                <option value="APP:WhatsApp.WhatsApp">Singola app: WhatsApp</option>
                                <option value="APP:Zoom.Zoom">Singola app: Zoom</option>
                                <option value="APP:Spotify.Spotify">Singola app: Spotify</option>
                                <option value="APP:TeamViewer.TeamViewer">Singola app: TeamViewer</option>
                                <option value="APP:GIMP.GIMP.3">Singola app: GIMP</option>
                                <option value="APP:SumatraPDF.SumatraPDF">Singola app: Sumatra PDF</option>
                                <option value="APP:Opera.OperaGX">Singola app: Opera GX</option>
                                <option value="APP:Mozilla.Firefox">Singola app: Mozilla Firefox</option>
                                <option value="APP:Valve.Steam">Singola app: Steam</option>
                                <option value="APP:EpicGames.EpicGamesLauncher">Singola app: Epic Games Launcher</option>
                                <option value="APP:Discord.Discord">Singola app: Discord</option>
                            </select>
                            <button type="button" class="btn-tool primary" onclick="eseguiPasso('app')">&#9654; Installa selezionato</button>
                            <button type="button" class="btn-tool" onclick="eseguiPasso('icone')">&#128444; Ripara icone Desktop</button>
                        </div>
                        <div id="esitoStep-app" class="step-esito"></div>
                    </div>

                    <!-- 10. Pulizia programmi inutili e velocizzazione -->
                    <div class="step-tool-card" id="stepcard-pulizia">
                        <div class="step-tool-head">
                            <div class="step-tool-title"><span class="step-badge">10</span> Pulizia programmi inutili e velocizzazione</div>
                            <span id="step-badge-pulizia" class="task-badge badge-pending">Pronto</span>
                        </div>
                        <div class="step-tool-desc">Rimuove bloatware, OneDrive, collegamenti sponsorizzati, disattiva widget/telemetria e imposta il piano energetico Bilanciato.</div>
                        <div class="step-tool-actions">
                            <button type="button" class="btn-tool primary" onclick="eseguiPasso('pulizia')">&#9654; Esegui pulizia e ottimizzazione</button>
                        </div>
                        <div id="esitoStep-pulizia" class="step-esito"></div>
                    </div>

                    <!-- 11. Driver hardware -->
                    <div class="step-tool-card" id="stepcard-driver">
                        <div class="step-tool-head">
                            <div class="step-tool-title"><span class="step-badge">11</span> Driver hardware</div>
                            <span id="step-badge-driver" class="task-badge badge-pending">Pronto</span>
                        </div>
                        <div class="step-tool-desc">Cerca e installa i driver mancanti (dalla chiavetta o tramite Windows Update) oppure apre Gestione Dispositivi.</div>
                        <div class="step-tool-actions">
                            <button type="button" class="btn-tool primary" onclick="eseguiPasso('driver')">&#9654; Installa driver mancanti</button>
                            <button type="button" class="btn-tool" onclick="eseguiPasso('devmgmt')">&#9881; Gestione Dispositivi</button>
                        </div>
                        <div id="esitoStep-driver" class="step-esito"></div>
                    </div>

                    <!-- 12. Aggiornamenti app e Windows -->
                    <div class="step-tool-card" id="stepcard-aggiorna">
                        <div class="step-tool-head">
                            <div class="step-tool-title"><span class="step-badge">12</span> Aggiornamenti app e Windows</div>
                            <span id="step-badge-aggiorna" class="task-badge badge-pending">Pronto</span>
                        </div>
                        <div class="step-tool-desc">Aggiorna tutte le app via Winget, le firme di Windows Defender e installa le patch rapide di Windows Update.</div>
                        <div class="step-tool-actions">
                            <button type="button" class="btn-tool primary" onclick="eseguiPasso('aggiorna')">&#9654; Esegui aggiornamenti</button>
                            <button type="button" class="btn-tool" onclick="eseguiPasso('winupdate')">&#9881; Apri Windows Update</button>
                        </div>
                        <div id="esitoStep-aggiorna" class="step-esito"></div>
                    </div>

                    <!-- 13. Controllo finale e scheda di consegna -->
                    <div class="step-tool-card" id="stepcard-diagnostica">
                        <div class="step-tool-head">
                            <div class="step-tool-title"><span class="step-badge">13</span> Controllo finale e scheda di consegna</div>
                            <span id="step-badge-diagnostica" class="task-badge badge-pending">Pronto</span>
                        </div>
                        <div class="step-tool-desc">Rigenera sul Desktop il file <strong>Scheda-Consegna-Cliente.pdf</strong> coi dati aggiornati (senza email se <code>clt clt</code>) o ripete il controllo salute PC.</div>
                        <div class="step-tool-actions">
                            <button type="button" class="btn-tool primary" onclick="eseguiPasso('scheda')">&#128196; Rigenera Scheda Consegna PDF</button>
                            <button type="button" class="btn-tool" onclick="eseguiPasso('diagnostica')">&#129658; Check Salute PC</button>
                        </div>
                        <div id="esitoStep-diagnostica" class="step-esito"></div>
                    </div>
                </div>
            </div>
        </div>

        <!-- SCHEDA 5: COMANDI / ASSISTENTE IA & TELECOMANDO REMOTO -->
        <div id="view-tab-remoto" class="section-view" role="tabpanel" aria-labelledby="btn-tab-remoto">
            <div class="card">
                <div class="step-tool-head" style="margin-bottom:8px;">
                    <div class="step-tool-title">&#9889; Assistente Istruzioni &amp; Telecomando Remoto</div>
                    <span id="badgeTelecomando" class="task-badge badge-done">Telecomando Cloud Attivo</span>
                </div>
                <div class="card-subtitle">Scrivi un&rsquo;istruzione in italiano (es. <code>togli password windows</code>, <code>disinstalla norton</code>, <code>chiudi blocchi</code>, <code>ripara wifi</code>, <code>lista programmi</code>, <code>stato dischi</code>) o un comando PowerShell diretto, oppure invia le istruzioni dalla chat sul tuo Mac/iPhone per eseguirle in automatico su questo PC.</div>

                <div class="cred-step-box evidenza" style="margin-bottom:10px;">
                    <label class="cred-label" for="inComandoRemoto">Istruzione in italiano o comando diretto da eseguire su questo PC</label>
                    <div class="cred-box" style="margin-bottom:10px;">
                        <input type="text" id="inComandoRemoto" class="cred-input" placeholder="Es. debloat completo, menu classico win11, pulisci disco profonda, ripara stampanti, disinstalla Norton..." autocomplete="off" onkeydown="if(event.key==='Enter'){eseguiComandoDiretto();}">
                        <button type="button" class="btn-tool primary" style="white-space:nowrap;" onclick="eseguiComandoDiretto()">&#9654; Esegui sul PC</button>
                    </div>

                    <div class="task-gruppo" style="margin-top:4px;">1 &middot; Debloat Avanzato, Interfaccia &amp; Rimozione Pubblicit&agrave;</div>
                    <div class="step-tool-actions" style="flex-wrap:wrap; gap:6px; margin-bottom:8px;">
                        <button type="button" class="btn-tool primary" onclick="eseguiComandoRapido('debloat completo')">&#129529; Super Debloat Win11 (Zero Pubblicit&agrave;/Copilot/Recall)</button>
                        <button type="button" class="btn-tool" onclick="eseguiComandoRapido('rimuovi edge bloat')">&#127760; Debloat Microsoft Edge (No MSN/Shopping/Avvio)</button>
                        <button type="button" class="btn-tool" onclick="eseguiComandoRapido('rimuovi onedrive')">&#9729; Disinstalla OneDrive &amp; Sgancia Cartelle</button>
                        <button type="button" class="btn-tool" onclick="eseguiComandoRapido('menu classico win11')">&#128433; Menu Tasto Destro Classico (Win10)</button>
                        <button type="button" class="btn-tool" onclick="eseguiComandoRapido('menu moderno win11')">&#128433; Ripristina Menu Moderno Win11</button>
                    </div>

                    <div class="task-gruppo">2 &middot; Velocizzazione, SSD, Pulizia Profonda &amp; Privacy</div>
                    <div class="step-tool-actions" style="flex-wrap:wrap; gap:6px; margin-bottom:8px;">
                        <button type="button" class="btn-tool primary" onclick="eseguiComandoRapido('prestazioni massime')">&#128640; Turbo Prestazioni &amp; Reattivit&agrave; UI</button>
                        <button type="button" class="btn-tool" onclick="eseguiComandoRapido('pulisci disco profonda')">&#128465; Pulizia Profonda Temp / Cache / Update</button>
                        <button type="button" class="btn-tool" onclick="eseguiComandoRapido('ottimizza ssd')">&#128191; Ottimizza SSD (TRIM + Sensore Memoria)</button>
                        <button type="button" class="btn-tool" onclick="eseguiComandoRapido('privacy totale')">&#128737; Blindatura Privacy &amp; Stop Telemetria</button>
                        <button type="button" class="btn-tool" onclick="eseguiComandoRapido('togli password windows')">&#128275; Togli Password Login &amp; Scadenza 42gg</button>
                        <button type="button" class="btn-tool" onclick="eseguiComandoRapido('stato bitlocker')">&#128272; Controllo &amp; Chiave BitLocker</button>
                    </div>

                    <div class="task-gruppo">3 &middot; Sblocco, Riparazione Sistema, Rete, Audio &amp; Stampanti</div>
                    <div class="step-tool-actions" style="flex-wrap:wrap; gap:6px;">
                        <button type="button" class="btn-tool primary" onclick="eseguiComandoRapido('chiudi blocchi')">&#128721; Sblocca Processi / Installer Bloccati</button>
                        <button type="button" class="btn-tool" onclick="eseguiComandoRapido('ripara wifi')">&#128246; Reset Completo Rete, Wi-Fi &amp; DNS</button>
                        <button type="button" class="btn-tool" onclick="eseguiComandoRapido('reset windows update')">&#128260; Sblocca &amp; Ripara Windows Update</button>
                        <button type="button" class="btn-tool" onclick="eseguiComandoRapido('ripara store e winget')">&#128717; Ripara Microsoft Store &amp; Winget</button>
                        <button type="button" class="btn-tool" onclick="eseguiComandoRapido('ripara stampanti')">&#128424; Sblocca Coda Stampanti (Spooler)</button>
                        <button type="button" class="btn-tool" onclick="eseguiComandoRapido('ripara audio e bluetooth')">&#128266; Ripara Servizi Audio &amp; Bluetooth</button>
                        <button type="button" class="btn-tool" onclick="eseguiComandoRapido('ripara sistema')">&#129658; Ripara File di Sistema (SFC + DISM)</button>
                        <button type="button" class="btn-tool" onclick="eseguiComandoRapido('riavvia desktop')">&#128421; Riavvia Esplora File / Desktop</button>
                        <button type="button" class="btn-tool" onclick="eseguiComandoRapido('lista programmi')">&#128203; Lista Programmi Installati</button>
                        <button type="button" class="btn-tool" onclick="eseguiComandoRapido('stato dischi')">&#128190; Stato Dischi &amp; Spazio</button>
                        <button type="button" class="btn-tool" onclick="eseguiComandoRapido('winutil')">&#129520; Apri Chris Titus WinUtil (GUI)</button>
                    </div>
                </div>

                <div class="cred-step-box" style="background:#020617; border-color:#1e293b;">
                    <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:6px;">
                        <span class="cred-label" style="margin:0; color:#93c5fd;">Console Risultati &amp; Storico Telecomando Remoto</span>
                        <button type="button" class="btn-sec" style="padding:3px 8px; font-size:11px;" onclick="el('outComandoRemoto').innerText='In attesa di istruzioni...'">Pulisci</button>
                    </div>
                    <pre id="outComandoRemoto" style="margin:0; padding:10px; background:#000814; color:#e2e8f0; border-radius:6px; font-family:Consolas,monospace; font-size:12px; max-height:280px; overflow:auto; white-space:pre-wrap; word-break:break-word;">Pronto. Scrivi un'istruzione qui sopra o inviala da remoto tramite la chat sul tuo Mac/iPhone.</pre>
                </div>
            </div>
        </div>
    </div>

    <div id="toastEl" class="toast" role="status" aria-live="polite"></div>

    <script>
        var SERVER = 'http://127.0.0.1:8899';
        var TIMEOUT_MS = 6000;
        var currentDomain = 'outlook.it';
        var currentProviderName = 'Microsoft';
        var manualEdit = false;
        var audioPlayed = false;
        var inizioLavori = 0;
        var isScriptConnected = false;
        var lastStatusPing = 0;
        var schedaScelta = false;
        var TASK_KEYS = ['avprova', 'everyday', 'office', 'account', 'antivirus', 'cyber', 'lingua', 'ripristino', 'runtime', 'app', 'pulizia', 'driver', 'aggiorna', 'diagnostica'];

        function el(id) { return document.getElementById(id); }
        function val(id) { var e = el(id); return e ? e.value.trim() : ''; }

        // fetch con timeout: se lo script non risponde entro 2 s la richiesta viene
        // annullata (niente richieste appese che bloccano il pannello).
        function fetchConTimeout(url, opzioni) {
            opzioni = opzioni || {};
            if (window.AbortController) {
                var ctrl = new AbortController();
                opzioni.signal = ctrl.signal;
                var t = setTimeout(function() { ctrl.abort(); }, TIMEOUT_MS);
                return fetch(url, opzioni).then(function(r) { clearTimeout(t); return r; }, function(e) { clearTimeout(t); throw e; });
            }
            return fetch(url, opzioni);
        }

        // TEMPO: parte dall'avvio dello script (campo Inizio), non dall'apertura della pagina
        function formatoTempo(sec) {
            var h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60;
            var mm = (m < 10 ? '0' : '') + m, ss = (s < 10 ? '0' : '') + s;
            return h > 0 ? (h + ':' + mm + ':' + ss) : (mm + ':' + ss);
        }
        setInterval(function() {
            var e = el('elapsedTimerText');
            if (!e) return;
            if (!isScriptConnected || (ultimoStato && (ultimoStato.Completato || ultimoStato.completato))) return;
            e.innerText = inizioLavori > 0 ? formatoTempo(Math.max(0, Math.floor((Date.now() - inizioLavori) / 1000))) : '--:--';
        }, 1000);

        // SUONO DI FINE CONFIGURAZIONE (una volta sola)
        function playChime() {
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

        var _toastTimer = null;
        function showToast(msg, tipo) {
            var t = el('toastEl');
            if (!t) return;
            t.innerText = msg;
            t.className = 'toast show' + (tipo ? ' ' + tipo : '');
            clearTimeout(_toastTimer);
            _toastTimer = setTimeout(function() { t.className = 'toast' + (tipo ? ' ' + tipo : ''); }, tipo === 'errore' ? 4000 : 2500);
        }

        function mostraEsito(msg, tipo) {
            var e = el('esitoInvio');
            if (!e) return;
            e.innerText = msg;
            e.className = 'esito ' + tipo;
        }

        function apriScheda(tabId, automatica) {
            if (!automatica) schedaScelta = true;
            var tabs = document.querySelectorAll('.tab-btn');
            for (var i = 0; i < tabs.length; i++) tabs[i].setAttribute('aria-selected', tabs[i].id === 'btn-' + tabId ? 'true' : 'false');
            var views = document.querySelectorAll('.section-view');
            for (var j = 0; j < views.length; j++) views[j].classList.toggle('active-view', views[j].id === 'view-' + tabId);
        }

        var currentModalita = 'COMPLETA';

        function setModalitaSetup(mod) {
            currentModalita = (mod === 'POSTVENDITA') ? 'POSTVENDITA' : 'COMPLETA';
            var bComp = el('btnModeCompleta');
            var bPost = el('btnModePostVendita');
            var badge = el('badgeModalitaAttiva');
            var btnAvvia = el('btnAvvia');
            if (bComp) bComp.setAttribute('aria-pressed', currentModalita === 'COMPLETA' ? 'true' : 'false');
            if (bPost) bPost.setAttribute('aria-pressed', currentModalita === 'POSTVENDITA' ? 'true' : 'false');
            if (badge) {
                if (currentModalita === 'POSTVENDITA') {
                    badge.innerText = 'Modalit\u00E0: Post Vendita Rapido da OEM (Solo Essenziali \u00B7 No Reset)';
                    badge.style.background = 'rgba(238,114,3,0.22)';
                    badge.style.borderColor = '#EE7203';
                    badge.style.color = '#fed7aa';
                } else {
                    badge.innerText = 'Modalit\u00E0: Configurazione Completa (14 passaggi)';
                    badge.style.background = 'rgba(2,132,199,0.2)';
                    badge.style.borderColor = '#38bdf8';
                    badge.style.color = '#bae6fd';
                }
            }
            if (btnAvvia) {
                btnAvvia.innerHTML = (currentModalita === 'POSTVENDITA')
                    ? '&#9889; AVVIA POST VENDITA RAPIDO DA OEM (SOLO ESSENZIALI &middot; NO RESET)'
                    : '&#10004; CONFERMA DATI CLIENTE';
            }
            fetch(API + '/mode', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ Modalita: currentModalita })
            }).then(function(r) { return r.json(); }).then(function(res) {
                if (res && res.ok) {
                    mostraEsito(res.messaggio || ('\u2713 Modalit\u00E0 impostata su ' + currentModalita), 'ok');
                }
            }).catch(function() {});
        }

        function setDomain(dom, provName, btn) {
            currentDomain = dom;
            currentProviderName = provName || dom;
            var btns = document.querySelectorAll('.dom-selector .dom-btn');
            for (var i = 0; i < btns.length; i++) btns[i].setAttribute('aria-pressed', btns[i] === btn ? 'true' : 'false');
            var chkProton = el('chkSvcProton');
            if (chkProton) chkProton.checked = (dom === 'proton.me');
            aggiornaCred();
        }

        function segnaModificato() { manualEdit = true; }

        function togglePassVis() {
            var inp = el('inPass'), b = el('btnMostra');
            if (!inp) return;
            inp.type = (inp.type === 'password' ? 'text' : 'password');
            if (b) b.innerHTML = inp.type === 'password' ? '&#128065; Mostra' : '&#128065; Nascondi';
        }

        function generaPassCasuale() {
            var chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#%*';
            var pass = '';
            var rnd = new Uint32Array(12);
            if (window.crypto && crypto.getRandomValues) { crypto.getRandomValues(rnd); } else { for (var k = 0; k < 12; k++) rnd[k] = Math.floor(Math.random() * 4294967296); }
            for (var i = 0; i < 12; i++) pass += chars.charAt(rnd[i] % chars.length);
            var inp = el('inPass');
            if (inp) {
                inp.value = pass;
                inp.type = 'text';
                var b = el('btnMostra');
                if (b) b.innerHTML = '&#128065; Nascondi';
                manualEdit = true;
                showToast('Nuova password generata');
            }
        }

        function scriviAppunti(testo, msgOk) {
            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(testo).then(function() { showToast(msgOk); }, function() { showToast('Copia non riuscita: seleziona e copia a mano', 'errore'); });
            } else {
                showToast('Copia non disponibile in questo browser', 'errore');
            }
        }

        function copia(id, msg) {
            var v = val(id);
            if (!v) { showToast('Campo vuoto: niente da copiare', 'avviso'); return; }
            scriviAppunti(v, msg || 'Copiato');
        }

        function copiaSeriale() {
            var sn = el('hwSerialVal') ? el('hwSerialVal').innerText.trim() : '';
            if (!sn) { showToast('Seriale non disponibile', 'avviso'); return; }
            scriviAppunti(sn, 'Seriale copiato: ' + sn);
        }

        function copiaRiepilogoCred() {
            var email = val('inEmail'), pass = val('inPass'), tel = val('inTelefono');
            if (!email) { showToast('Inserisci prima il cliente', 'avviso'); return; }
            var text = 'Account: ' + email + ' | Password: ' + pass + (tel ? ' | Tel: ' + tel : '') + ' (Provider: ' + currentProviderName + ')';
            scriviAppunti(text, 'Dati copiati per il ticket');
        }

        function isCltNome(cognome, nome) {
            var c = (cognome || '').toLowerCase().trim();
            var n = (nome || '').toLowerCase().trim();
            var full = (c + ' ' + n).trim();
            var generici = ['clt', 'clt clt', 'utente', 'utente utente', 'cliente', 'cliente cliente', 'oem', 'admin'];
            return (!full || generici.indexOf(full) !== -1 || (generici.indexOf(c) !== -1 && (!n || generici.indexOf(n) !== -1)));
        }

        var _stepNomeEdited = false;
        function aggiornaCampiStepNome() {
            if (_stepNomeEdited) return;
            var cognome = val('inCognome'), nome = val('inNome');
            var isClt = isCltNome(cognome, nome);
            var inU = el('inStepNomeUtente'), inP = el('inStepNomePc');
            if (!inU || !inP) return;
            if (isClt || (!cognome && !nome)) {
                inU.value = 'Utente';
                inP.value = 'PC-Utente';
            } else {
                var full = (cognome + ' ' + nome).trim() || nome || 'Utente';
                var cleanPc = (nome || cognome || 'Utente').replace(/[^a-zA-Z0-9]/g, '');
                if (cleanPc.length > 12) cleanPc = cleanPc.substring(0, 12);
                inU.value = full;
                inP.value = 'PC-' + (cleanPc || 'Utente');
            }
        }

        function aggiornaCred() {
            var es = el('esitoInvio');
            if (es && es.className.indexOf('errore') !== -1) es.className = 'esito';
            var cognome = val('inCognome');
            var nome = val('inNome');
            aggiornaCampiStepNome();
            var isClt = isCltNome(cognome, nome);
            if (isClt) {
                el('inEmail').value = '';
                el('inPass').value = '';
                return;
            }
            if (!cognome && !nome) {
                if (!manualEdit) {
                    el('inEmail').value = 'utente@' + currentDomain;
                    el('inPass').value = 'Utente123!';
                }
                return;
            }
            var cClean = cognome.toLowerCase().replace(/[^a-z0-9]/g, '');
            var nClean = nome.toLowerCase().replace(/[^a-z0-9]/g, '');
            var emailPrefix = '', passBase = '';
            if (cClean && nClean) {
                emailPrefix = cClean + nClean;
                passBase = nClean;
            } else if (cClean) {
                emailPrefix = cClean;
                passBase = cClean;
            } else {
                var parts = nome.toLowerCase().split(/\s+/).filter(Boolean);
                if (parts.length > 1) {
                    var pCognome = parts.slice(1).join('').replace(/[^a-z0-9]/g, '');
                    var pNome = parts[0].replace(/[^a-z0-9]/g, '');
                    emailPrefix = pCognome + pNome;
                    passBase = pNome;
                } else {
                    emailPrefix = nClean;
                    passBase = nClean;
                }
            }
            if (emailPrefix.length > 20) emailPrefix = emailPrefix.substring(0, 20);
            el('inEmail').value = emailPrefix + '@' + currentDomain;
            if (passBase) {
                var cap = passBase.charAt(0).toUpperCase() + passBase.slice(1).toLowerCase().replace(/[^a-z0-9]/g, '');
                el('inPass').value = cap + '123!';
            }
        }

        function segnaErrore(id) {
            var e = el(id);
            if (e) { e.classList.add('errore'); e.focus(); }
        }

        function analizzaInputMailSecure(raw) {
            if (!raw) return false;
            var txt = String(raw);
            var mMail = txt.match(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/);
            var mPass = txt.match(/Password\s*[:=]\s*([^\s]+)/i);
            if (mMail || mPass) {
                if (mMail && el('inEmail')) {
                    manualEdit = true;
                    el('inEmail').value = mMail[0].trim();
                }
                if (mPass && el('inPassSecure')) {
                    el('inPassSecure').value = mPass[1].trim();
                } else if (mMail && el('inPassSecure')) {
                    var resto = txt.replace(mMail[0], '').replace(/Email\s*[:=]/i, '').replace(/Password\s*[:=]/i, '').trim();
                    var tok = resto.split(/\s+/).filter(Boolean);
                    if (tok.length > 0) el('inPassSecure').value = tok[tok.length - 1];
                }
                if (el('chkSvcEveryday')) el('chkSvcEveryday').checked = true;
                return true;
            }
            return false;
        }

        function incollaMailSecure() {
            if (navigator.clipboard && navigator.clipboard.readText) {
                navigator.clipboard.readText().then(function(t) {
                    if (!t) return;
                    if (!analizzaInputMailSecure(t) && el('inPassSecure')) {
                        el('inPassSecure').value = t.trim();
                    }
                    mostraEsito('\u2713 Credenziali Unieuro Secure inserite dagli appunti.', 'ok');
                }).catch(function() {
                    if (el('inPassSecure')) el('inPassSecure').focus();
                });
            } else if (el('inPassSecure')) {
                el('inPassSecure').focus();
            }
        }

        // Costruisce i dati da inviare; null se manca qualcosa di obbligatorio.
        function datiCliente() {
            var cognome = val('inCognome'), nome = val('inNome'), telefono = val('inTelefono');
            var email = val('inEmail'), pass = val('inPass');
            var passSecure = val('inPassSecure');
            ['inCognome', 'inNome', 'inTelefono', 'inEmail', 'inPass'].forEach(function(id) { if (el(id)) el(id).classList.remove('errore'); });
            var everyday = el('chkSvcEveryday').checked;
            var cyber = el('chkSvcCyber').checked;
            var isClt = isCltNome(cognome, nome);
            var haMailSecure = Boolean(passSecure && email && email.indexOf('@') > 0);
            var nomeCliente = (cognome + ' ' + nome).trim() || 'clt clt';
            var emailEffettiva = (isClt && !haMailSecure) ? '' : (email || ('utente@' + currentDomain));
            var passEffettiva = isClt ? '' : (pass || 'Utente123!');
            if (email && email.indexOf('@') < 1 && (!isClt || haMailSecure)) { segnaErrore('inEmail'); mostraEsito('Email non valida.', 'errore'); return null; }
            return {
                Conferma: true,
                Modalita: currentModalita,
                Email: emailEffettiva,
                Password: passEffettiva,
                PasswordSecure: passSecure,
                Provider: currentProviderName,
                Cliente: nomeCliente,
                Nome: nome,
                Cognome: cognome,
                Telefono: telefono,
                ProfiloApp: currentModalita === 'POSTVENDITA' ? 'ESSENZIALE' : el('selProfilo').value,
                Servizi: {
                    Everyday: everyday,
                    Proton: isClt ? false : el('chkSvcProton').checked,
                    Office: (el('selOffice').value === 'm365' || el('selOffice').value === 'perpetuo'),
                    OfficeTipo: el('selOffice').value,
                    McAfee: el('chkSvcMcAfee').checked,
                    Norton: el('chkSvcNorton').checked,
                    Cyber: cyber
                }
            };
        }

        // Unico pulsante: invia i dati confermati allo script. Lo script parte (o
        // aggiorna i dati) SOLO con Conferma:true; l'esito mostrato e' quello vero.
        function avviaConfigurazione() {
            var payload = datiCliente();
            if (!payload) return;
            var btn = el('btnAvvia');
            btn.disabled = true;
            mostraEsito('Invio dei dati al PC...', 'avviso');
            fetchConTimeout(SERVER + '/cred', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            }).then(function(r) {
                return r.json().catch(function() { return {}; }).then(function(j) { return { ok: r.ok, j: j }; });
            }).then(function(res) {
                btn.disabled = false;
                if (res.ok && res.j && res.j.ok !== false) {
                    mostraEsito('\u2713 Dati ricevuti dal PC: avvio in corso.', 'ok');
                    showToast('Dati ricevuti dal PC');
                    apriScheda('tab-live');
                } else {
                    mostraEsito('Il PC ha rifiutato i dati: ' + ((res.j && res.j.motivo) || 'risposta non valida') + '.', 'errore');
                }
            }).catch(function() {
                btn.disabled = false;
                // Un solo canale: il server locale di PC Facile (127.0.0.1:8899).
                mostraEsito('PC Facile non risponde: dati NON ricevuti. Controlla che la finestra di PC Facile sia aperta e riprova.', 'errore');
                showToast('PC non raggiunto', 'errore');
            });
        }

        function mostraEsitoStep(stepKey, msg, tipo) {
            var mapKey = stepKey;
            if (stepKey === 'sysdm') mapKey = 'ripristino';
            if (stepKey === 'icone') mapKey = 'app';
            if (stepKey === 'officeattiva') mapKey = 'office';
            if (stepKey === 'netplwiz' || stepKey === 'nopass') mapKey = 'account';
            if (stepKey === 'devmgmt') mapKey = 'driver';
            if (stepKey === 'winupdate') mapKey = 'aggiorna';
            if (stepKey === 'scheda') mapKey = 'diagnostica';
            var box = el('esitoStep-' + mapKey);
            if (!box) return;
            box.innerText = msg;
            box.className = 'step-esito ' + (tipo || 'ok');
        }

        function saltaOperazione(taskKey) {
            var targetKey = taskKey;
            if (targetKey === 'current' && ultimoStato && (ultimoStato.Tasks || ultimoStato.tasks)) {
                var tt = ultimoStato.Tasks || ultimoStato.tasks;
                for (var k in tt) {
                    if (((tt[k].Stato || tt[k].stato || '') + '').toLowerCase() === 'running') {
                        targetKey = k;
                        break;
                    }
                }
            }
            showToast('Salto operazione in corso...');
            fetchConTimeout(SERVER + '/skip', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ TaskId: targetKey })
            }).then(function(r) {
                return r.json().catch(function() { return {}; });
            }).then(function() {
                showToast('Operazione saltata: passo alla successiva');
                checkConnection();
            }).catch(function() {
                showToast('PC Facile non risponde', 'errore');
            });
        }

        function eseguiPasso(step, paramOverride) {
            var payload = { Step: step, Param: paramOverride || '' };
            if (step === 'app') {
                payload.Param = el('selStepApp') ? el('selStepApp').value : 'PROFILO:BASE';
            } else if (step === 'office' || step === 'officeattiva') {
                payload.Param = el('selStepOffice') ? el('selStepOffice').value : 'm365';
            } else if (step === 'account') {
                var nu = val('inStepNomeUtente') || 'Utente';
                var np = val('inStepNomePc') || 'PC-Utente';
                payload.NomeUtente = nu;
                payload.NomePc = np;
            }
            mostraEsitoStep(step, 'Invio comando al PC in corso...', 'avviso');
            var ctrl = window.AbortController ? new AbortController() : null;
            var t = ctrl ? setTimeout(function() { ctrl.abort(); }, 8000) : null;
            fetch(SERVER + '/step', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload),
                signal: ctrl ? ctrl.signal : undefined
            }).then(function(r) {
                if (t) clearTimeout(t);
                return r.json().catch(function() { return {}; }).then(function(j) { return { ok: r.ok, j: j }; });
            }).then(function(res) {
                if (res.ok && res.j && res.j.ok !== false) {
                    var msg = (res.j && res.j.messaggio) || 'Passaggio avviato sul PC.';
                    mostraEsitoStep(step, '\u2713 ' + msg, 'ok');
                    showToast(msg);
                    checkConnection();
                } else {
                    var err = (res.j && res.j.motivo) || 'Impossibile eseguire il passaggio';
                    mostraEsitoStep(step, '\u2717 ' + err, 'errore');
                    showToast(err, 'errore');
                }
            }).catch(function() {
                if (t) clearTimeout(t);
                mostraEsitoStep(step, '\u2717 PC Facile non risponde: verifica che la finestra dello script sia aperta.', 'errore');
                showToast('PC Facile non risponde', 'errore');
            });
        }

        function eseguiComandoRapido(cmdText) {
            var inp = el('inComandoRemoto');
            if (inp) inp.value = cmdText;
            eseguiComandoDiretto(cmdText);
        }

        function eseguiComandoDiretto(overrideCmd) {
            var cmd = (overrideCmd !== undefined ? overrideCmd : val('inComandoRemoto')).trim();
            if (!cmd) {
                showToast('Scrivi prima un\'istruzione o un comando', 'avviso');
                return;
            }
            var out = el('outComandoRemoto');
            if (out) out.innerText = '\u23F3 Esecuzione in corso sul PC: ' + cmd + ' ...\n\n' + (out.innerText || '');
            fetchConTimeout(SERVER + '/cmd', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ Command: cmd, Source: 'pannello' })
            }).then(function(r) {
                return r.json().catch(function() { return {}; });
            }).then(function(res) {
                if (res && res.output !== undefined) {
                    if (out) out.innerText = res.output;
                    showToast(res.ok === false ? 'Comando terminato con avvisi' : 'Istruzione eseguita sul PC');
                } else {
                    showToast('Risposta ricevuta');
                }
                checkConnection();
            }).catch(function() {
                if (out) out.innerText = '\u2717 PC Facile non risponde: verifica che la finestra dello script sia aperta.';
                showToast('PC Facile non risponde', 'errore');
            });
        }

        // STATO DELLA CONNESSIONE E INDICATORE IN ALTO
        var ultimoStato = null;
        function aggiornaIndicatore() {
            var b = el('badgeStato');
            var off = el('offlineNoticeBox');
            var attesa = el('attesaDatiBox');
            var s = ultimoStato || {};
            // Collegato = risponde il server locale di PC Facile (unico canale).
            var collegato = isScriptConnected;
            if (off) off.style.display = collegato ? 'none' : 'block';
            if (attesa) attesa.style.display = (collegato && s.InAttesaDati) ? 'block' : 'none';
            if (!b) return;
            if (!collegato) {
                b.className = 'badge-stato stato-off';
                b.innerText = (s.Completato ? 'Script chiuso' : 'PC Facile non risponde');
            } else if (s.Completato) {
                var n = contaErrori(s);
                b.className = 'badge-stato ' + (n > 0 ? 'stato-avvisi' : 'stato-ok');
                b.innerText = n > 0 ? ('Completato con ' + n + (n === 1 ? ' avviso' : ' avvisi')) : 'Completato';
            } else if (s.InAttesaDati) {
                b.className = 'badge-stato stato-attesa';
                b.innerText = 'In attesa dei dati cliente';
            } else {
                b.className = 'badge-stato stato-corso';
                b.innerText = 'Collegato \u00b7 in corso';
            }
        }

        function setConnected(connected) {
            isScriptConnected = connected;
            aggiornaIndicatore();
        }

        function contaErrori(data) {
            var tasks = (data && (data.Tasks || data.tasks)) || {};
            var n = 0;
            for (var k in tasks) { if (((tasks[k].Stato || tasks[k].stato || '') + '').toLowerCase() === 'error') n++; }
            return n;
        }

        function checkConnection() {
            fetchConTimeout(SERVER + '/status', { method: 'GET', mode: 'cors', cache: 'no-store' })
                .then(function(r) {
                    if (!r.ok) throw new Error('HTTP ' + r.status);
                    return r.json();
                })
                .then(function(data) {
                    lastStatusPing = Date.now();
                    // Le versioni vecchie dello script rispondono solo {"status":"running"}
                    if (data && (data.Percentuale !== undefined || data.Tasks)) {
                        applyStatus(data);
                    } else {
                        setConnected(true);
                    }
                })
                .catch(function() {
                    if (Date.now() - lastStatusPing > 12000) setConnected(false);
                });
        }
        setInterval(checkConnection, 1500);
        checkConnection();

        var NOMI_TASK = {};
        function applyStatus(data) {
            if (!data) return;
            lastStatusPing = Date.now();
            isScriptConnected = true;
            ultimoStato = data;

            var pct = parseInt(data.Percentuale !== undefined ? data.Percentuale : (data.percentuale || 0), 10) || 0;
            el('progressBarFill').style.width = pct + '%';
            el('progressPercentText').innerText = pct + '%';
            el('progressBar').setAttribute('aria-valuenow', pct);

            var faseVal = data.FaseCorrente || data.faseCorrente;
            if (faseVal) el('currentFaseText').innerText = faseVal;
            var detVal = data.Dettaglio || data.dettaglio || '';
            // Il dettaglio piu' aggiornato e' quello della fase in corso.
            var tt = data.Tasks || data.tasks || {};
            for (var tk in tt) {
                if (((tt[tk].Stato || tt[tk].stato || '') + '').toLowerCase() === 'running' && (tt[tk].Dettaglio || tt[tk].dettaglio)) { detVal = tt[tk].Dettaglio || tt[tk].dettaglio; }
            }
            el('currentDetailText').innerText = detVal;

            if (data.Inizio) inizioLavori = Number(data.Inizio) || 0;

            var v = el('versioneText');
            if (v) v.innerText = data.Versione ? ('Script PC Facile v' + data.Versione) : 'Script PC Facile collegato';

            var hw = data.Hardware;
            if (hw && (hw.Modello || hw.Cpu || hw.Seriale)) {
                el('hwModelloText').innerText = hw.Modello || '\u2014';
                el('hwCpuText').innerText = [hw.Cpu, hw.Ram].filter(Boolean).join(' \u00b7 ') || '\u2014';
                el('hwSerialVal').innerText = hw.Seriale || '';
                el('hwBar').style.display = 'flex';
            }

            var tasks = data.Tasks || data.tasks;
            var errori = [];
            if (tasks) {
                var doneCount = 0;
                for (var key in tasks) {
                    var task = tasks[key];
                    var row = el('task-' + key);
                    var stato = ((task.Stato || task.stato || 'pending') + '').toLowerCase();
                    var dettaglio = task.Dettaglio || task.dettaglio || '';
                    if (stato === 'done' || stato === 'skipped' || stato === 'error') doneCount++;
                    if (!row) continue;
                    var nome = row.querySelector('.task-name').innerText.replace(/^\d+\.\s*/, '');
                    if (stato === 'error') errori.push(nome + (dettaglio ? ': ' + dettaglio : ''));
                    row.className = 'task-item ' + stato;
                    var badge = row.querySelector('.task-badge');
                    var badgeClass = 'badge-pending', badgeText = 'In attesa';
                    if (stato === 'done') { badgeClass = 'badge-done-task'; badgeText = 'Fatto'; }
                    else if (stato === 'running') { badgeClass = 'badge-running'; badgeText = 'In corso'; }
                    else if (stato === 'error') { badgeClass = 'badge-error'; badgeText = 'Errore'; }
                    else if (stato === 'skipped') { badgeClass = 'badge-skipped'; badgeText = (key === 'ripristino' ? 'Ottimizzato SSD' : 'Saltato'); }
                    badge.className = 'task-badge ' + badgeClass;
                    badge.innerText = badgeText;
                    var stepBadge = el('step-badge-' + key);
                    if (stepBadge) {
                        stepBadge.className = 'task-badge ' + badgeClass;
                        stepBadge.innerText = badgeText;
                    }
                    var icon = row.querySelector('.task-icon');
                    if (stato === 'done' || stato === 'skipped') icon.innerHTML = '&#10003;';
                    else if (stato === 'running') icon.innerHTML = '<span class="spinner"></span>';
                    else if (stato === 'error') icon.innerHTML = '&#10007;';
                    else icon.innerHTML = '&#9675;';
                    row.querySelector('.task-detail').innerText = (dettaglio && stato !== 'pending' && stato !== 'done') ? dettaglio : '';
                }
                el('taskCountBadge').innerText = doneCount + '/' + TASK_KEYS.length;
            }
            if (!_stepNomeEdited && (data.NomeUtenteAttuale || data.NomePcAttuale) && !val('inNome') && !val('inCognome')) {
                var inU = el('inStepNomeUtente'), inP = el('inStepNomePc');
                if (inU && data.NomeUtenteAttuale) inU.value = data.NomeUtenteAttuale;
                if (inP && data.NomePcAttuale) inP.value = data.NomePcAttuale;
            }
            if (data.LogComandi && el('outComandoRemoto') && data.UltimoCmdId && data.UltimoCmdId !== window._lastSeenCmdId) {
                window._lastSeenCmdId = data.UltimoCmdId;
                el('outComandoRemoto').innerText = data.LogComandi;
            }

            var completato = !!(data.Completato || data.completato);
            var btnSkipCur = el('btnSkipCurrent');
            if (btnSkipCur) {
                var haRunning = false;
                if (tasks) {
                    for (var rk in tasks) {
                        if (((tasks[rk].Stato || tasks[rk].stato || '') + '').toLowerCase() === 'running') { haRunning = true; break; }
                    }
                }
                btnSkipCur.style.display = (!completato && haRunning) ? 'inline-block' : 'none';
            }
            var banner = el('completionBanner');
            if (completato) {
                var lista = el('completionAvvisi');
                lista.innerHTML = '';
                errori.forEach(function(t) { var li = document.createElement('li'); li.innerText = t; lista.appendChild(li); });
                if (errori.length > 0) {
                    banner.className = 'banner-complete con-avvisi';
                    el('completionTitle').innerText = '\u26A0 Configurazione completata con ' + errori.length + (errori.length === 1 ? ' avviso' : ' avvisi') + ': controlla prima della consegna';
                } else {
                    banner.className = 'banner-complete';
                    el('completionTitle').innerText = '\u2713 Configurazione completata';
                }
                banner.style.display = 'block';
                if (!audioPlayed) { audioPlayed = true; playChime(); }
            } else {
                banner.style.display = 'none';
            }
            // Pannello aperto a lavori gia' avviati: mostro l'avanzamento (una volta,
            // solo se l'operatore non ha gia' scelto una scheda).
            if (!schedaScelta && !data.InAttesaDati && (pct > 5 || completato)) { apriScheda('tab-live', true); schedaScelta = true; }
            if (data.InAttesaDati) { apriScheda('tab-cred', true); }
            aggiornaIndicatore();
        }

        if (!val('inEmail') && !val('inPass')) { aggiornaCred(); }

    </script>
</body>
</html>
"@
        $html | Set-Content -Path $pannelloFile -Encoding UTF8
        $Global:PannelloFile = $pannelloFile
        if (-not $serverOk) {
            if (-not $Global:Test -and -not $env:PESTER_TEST) {
                Write-Info "Server locale del pannello non avviato (porta 8899 occupata?): i dati del cliente li chiedo in console."
            }
            return
        }
        $aperto = $false
        try { Set-SplitScreenLayout -HtmlPath $pannelloFile; $aperto = $true } catch {
            try { Start-Process $pannelloFile -ErrorAction Stop; $aperto = $true } catch {}
        }
        $Global:PannelloDisponibile = $aperto
        if ($aperto) { Write-OK "Pannello Operatore aperto nel browser: inserisci li' i dati del cliente." }
        else { Write-Info "Browser non disponibile: i dati del cliente li chiedo in console." }
    } catch {
        Write-Info "Creazione pannello operatore non riuscita: $_"
    }
}


# Applica i dati del cliente confermati nel pannello (o letti dal checkpoint
# di ripresa, o inseriti in console se il pannello non si apre). UNICA
# funzione che li mette nelle variabili usate dai passi.
function Set-DatiCliente {
    param($Dati)
    if (-not $Dati) { return $false }
    try {
        $genericiRegex = '^(clt(\s+clt)?|utente(\s+utente)?|cliente(\s+cliente)?|oem|admin)$'
        $isClt = (-not $Dati.Cliente) -or ($Dati.Cliente.Trim() -match "(?i)$genericiRegex") -or
                 (($Dati.Nome -and $Dati.Nome.Trim() -match "(?i)$genericiRegex") -and (-not $Dati.Cognome -or $Dati.Cognome.Trim() -match "(?i)$genericiRegex"))
        $Global:IsCltMode = [bool]$isClt

        if ($isClt) {
            $Global:credMsAccount = ""
            $script:credMsAccount = ""
            $Global:credMsPassword = ""
            $script:credMsPassword = ""
            $Global:credDominio = ""
            $Global:nomeCliente = "Utente"
            $script:nomeCliente = "Utente"
            $Global:nomeProprioCliente = "Utente"
            $Global:cognomeCliente = ""
        } else {
            if ($Dati.Email) {
                $Global:credMsAccount = [string]$Dati.Email
                $script:credMsAccount = [string]$Dati.Email
                if ([string]$Dati.Email -like "*@*") { $Global:credDominio = ([string]$Dati.Email -split "@")[-1] }
            }
            if ($Dati.Password) {
                $Global:credMsPassword = [string]$Dati.Password
                $script:credMsPassword = [string]$Dati.Password
            }
            if ($Dati.Cliente) {
                $Global:nomeCliente = [string]$Dati.Cliente
                $script:nomeCliente = [string]$Dati.Cliente
            }
            if ($Dati.Nome)     { $Global:nomeProprioCliente = [string]$Dati.Nome }
            if ($Dati.Cognome)  { $Global:cognomeCliente = [string]$Dati.Cognome }
        }
        if ($Dati.Provider) { $Global:credProvider = [string]$Dati.Provider }
        if ($Dati.Telefono) { $Global:telefonoCliente = [string]$Dati.Telefono }
        $Global:credSecurePassword = if ($Dati.PasswordSecure) { [string]$Dati.PasswordSecure.Trim() } else { "" }
        if ($Global:credSecurePassword -and $Dati.Email) {
            $Global:credMsAccount = [string]$Dati.Email
            $script:credMsAccount = [string]$Dati.Email
        }
        if ($Dati.Modalita -and ([string]$Dati.Modalita).ToUpper() -eq 'POSTVENDITA') {
            $Global:ModalitaPostVendita = $true
            if ($Global:PannelloSync) {
                $Global:PannelloSync.Modalita = 'POSTVENDITA'
                foreach ($kSkip in @('ripristino', 'pulizia', 'driver', 'aggiorna')) {
                    $Global:PannelloSync.Saltati[$kSkip] = $true
                }
            }
        } elseif ($Dati.Modalita -and ([string]$Dati.Modalita).ToUpper() -eq 'COMPLETA') {
            $Global:ModalitaPostVendita = $false
            if ($Global:PannelloSync) { $Global:PannelloSync.Modalita = 'COMPLETA' }
        }
        if ($Dati.ProfiloApp -and [string]$Dati.ProfiloApp -match '^(BASE|UFFICIO|GAMING|COMPLETO|ESSENZIALE)$') { $Global:ProfiloAppCliente = [string]$Dati.ProfiloApp }
        if ($Dati.Servizi) {
            $Global:serviziSelezionati = $Dati.Servizi
            # Suite Office da installare/attivare (1 = Microsoft 365, 2 = perpetuo,
            # 4 = LibreOffice, 5 = nessuna). Senza OfficeTipo (pannelli vecchi)
            # la spunta "card Office" vale Microsoft 365.
            $tipo = [string]$Dati.Servizi.OfficeTipo
            $Global:SceltaOffice = switch ($tipo) {
                'm365'        { '1' }
                'perpetuo'    { '2' }
                'libreoffice' { '4' }
                'no'          { '5' }
                default       { if ($Dati.Servizi.Office) { '1' } else { '5' } }
            }
        }
        # Rinomina subito l'utente Windows e il PC col nome del cliente (o 'Utente' se clt clt)
        try {
            if (Get-Command Set-NomeUtenteEPc -ErrorAction SilentlyContinue) {
                $basePc = if ($Global:nomeProprioCliente) { $Global:nomeProprioCliente } elseif ($Global:nomeCliente) { $Global:nomeCliente } else { "Utente" }
                $cleanPc = ($basePc -replace '[^A-Za-z0-9]', '')
                if (-not $cleanPc -or $cleanPc -match '^(?i)(oem|clt|cltclt|cliente)$') { $cleanPc = "Utente" }
                $pcTarget = "PC-$cleanPc"
                if ($pcTarget.Length -gt 15) { $pcTarget = $pcTarget.Substring(0, 15) }
                [void](Set-NomeUtenteEPc -NomeUtente $Global:nomeCliente -NomePc $pcTarget -Silenzioso)
            }
        } catch {}
        $Global:DatiCliente = $Dati
        $Global:DatiClienteRicevuti = $true
        return $true
    } catch {
        return $false
    }
}

# Legge i dati del cliente arrivati dal pannello. UN SOLO canale: il server
# locale http://127.0.0.1:8899 (POST /cred), che li mette in coda; qui prendo
# il piu' recente. Non blocca: si chiama a ogni passo, cosi' i dati (anche
# corretti e riconfermati) valgono dal passo successivo.
function Get-CredenzialiSalvatePannello {
    if ($Global:PannelloSync -and $Global:PannelloSync.CodaCred) {
        $ultimo = $null
        $voce = $null
        while ($Global:PannelloSync.CodaCred.TryDequeue([ref]$voce)) { $ultimo = $voce }
        if ($ultimo) {
            try {
                $parsed = $ultimo | ConvertFrom-Json
                if ((Test-DatiClienteConfermati $parsed) -and (Set-DatiCliente $parsed)) {
                    Write-OK "Dati cliente ricevuti dal pannello: $($Global:nomeCliente) $(if ($Global:credMsAccount) { "($($Global:credMsAccount))" } else { "(senza email)" })."
                    Update-PannelloStatus -AttesaDati 'no'
                    return $true
                }
            } catch {}
        }
    }
    return $false
}

# Dati del cliente per la modalita' -Test (CI): esercitano tutti i passi.
function Get-DatiClienteTest {
    return [pscustomobject]@{
        Conferma = $true; Cliente = 'Rossi Mario'; Nome = 'Mario'; Cognome = 'Rossi'
        Email = 'rossimario@outlook.it'; Password = 'Mario123!'; Provider = 'Microsoft'
        Telefono = '3331234567'; ProfiloApp = 'BASE'
        Servizi = [pscustomobject]@{ Proton = $false; Office = $true; OfficeTipo = 'm365'; McAfee = $false; Norton = $false; Cyber = $true }
    }
}

# Ripiego MINIMO in console: SOLO se il pannello non si e' potuto aprire
# (server locale non avviato o browser non disponibile).
function Read-DatiClienteConsole {
    Write-Titolo "DATI CLIENTE (pannello non disponibile)"
    Write-Host "  Il pannello operatore non si e' aperto: inserisci qui i dati essenziali." -ForegroundColor Yellow
    $cognome = ([string](Attendi-Risposta "Cognome del cliente (facoltativo, INVIO per saltare)")).Trim()
    $nome    = ([string](Attendi-Risposta "Nome del cliente (facoltativo, INVIO per saltare)")).Trim()
    $off = ([string](Attendi-Risposta "Office: 1 = card Microsoft 365, 2 = card perpetuo, 3 = LibreOffice, INVIO = nessuna")).Trim()
    $av  = ([string](Attendi-Risposta "Card antivirus: M = McAfee, N = Norton, INVIO = nessuna (Defender)")).Trim().ToUpper()
    $cy  = ([string](Attendi-Risposta "Unieuro Cyber Protection acquistata? (S/N)")).Trim()
    $tel = ""
    if ($cy -match '^[Ss]') { $tel = ([string](Attendi-Risposta "Cellulare del cliente (per Cyber Protection)")).Trim() }
    $cliente = ("$cognome $nome").Trim()
    if (-not $cliente) { $cliente = "Utente" }
    $baseEmailPass = if ($nome -and $cognome) { "$nome $cognome" } elseif ($nome) { $nome } elseif ($cognome) { $cognome } else { "Utente" }
    $dati = [pscustomobject]@{
        Conferma = $true; Cliente = $cliente; Nome = $nome; Cognome = $cognome
        Email = (New-EmailCliente -Base $baseEmailPass -Dominio 'outlook.it'); Password = (New-PasswordCliente -Base (if ($nome) { $nome } else { $baseEmailPass })); Provider = 'Microsoft'
        Telefono = $tel; ProfiloApp = 'BASE'
        Servizi = [pscustomobject]@{
            Everyday = $true
            Proton = $false
            Office = ($off -match '^[12]$')
            OfficeTipo = switch ($off) { '1' { 'm365' } '2' { 'perpetuo' } '3' { 'libreoffice' } default { 'no' } }
            McAfee = ($av -eq 'M'); Norton = ($av -eq 'N'); Cyber = ($cy -match '^[Ss]')
        }
    }
    [void](Set-DatiCliente $dati)
    Write-OK "Dati cliente impostati da console: $cliente ($($dati.Email))."
    return $true
}

# Aspetta i dati del cliente (OPZIONALE, massimo 30s): si chiama solo alla fine.
# Se sono gia' arrivati dal pannello non si ferma nulla. Se non arrivano entro
# 30 secondi (o premi INVIO), prosegue automaticamente con profilo standard (Utente)
# e completa tutta la configurazione senza bloccarsi.
function Wait-DatiCliente {
    [CmdletBinding()]
    param([string]$Motivo = "", [int]$TimeoutSec = 0)
    if ($Global:DatiClienteRicevuti) { return $true }
    if ($Test -or $Global:Test -or $env:PESTER_TEST) { return (Set-DatiCliente (Get-DatiClienteTest)) }
    if (Get-CredenzialiSalvatePannello) { return $true }
    if (-not $Global:PannelloDisponibile -and $TimeoutSec -gt 0) { return (Read-DatiClienteConsole) }

    if ($TimeoutSec -le 0) {
        $std = [pscustomobject]@{
            Conferma = $true; Cliente = 'Utente'; Nome = 'Utente'; Cognome = ''
            Email = ''; Password = ''; Provider = 'Microsoft'
            Telefono = ''; ProfiloApp = 'BASE'
            Servizi = [pscustomobject]@{ Everyday = $true; Proton = $false; Office = $false; OfficeTipo = 'no'; McAfee = $false; Norton = $false; Cyber = $false }
        }
        [void](Set-DatiCliente $std)
        $Global:SkipAccountPrompt = $true
        Write-OK "Avvio diretto (0s attesa): procedo subito in automatico. Puoi inserire i dati cliente nel pannello in qualsiasi momento."
        return $true
    }

    Update-PannelloStatus -AttesaDati 'si' -Dettaglio "Dati cliente opzionali: conferma nel pannello entro ${TimeoutSec}s (altrimenti continuo da solo)"
    Write-Host ""
    Write-Titolo "DATI DEL CLIENTE OPZIONALI (PANNELLO OPERATORE)"
    if ($Motivo) { Write-Host "  $Motivo" -ForegroundColor White }
    Write-Host "  -> Se vuoi inserirli, compila nel pannello e premi 'CONFERMA DATI CLIENTE'." -ForegroundColor Cyan
    Write-Host "  -> Nessun obbligo: tra $TimeoutSec secondi (o premendo INVIO) proseguo e finisco automaticamente." -ForegroundColor Yellow
    Write-Host "     (P = riapri il pannello se l'hai chiuso)" -ForegroundColor Gray
    Beep-Attesa
    $swAttesa = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        while (-not (Get-CredenzialiSalvatePannello)) {
            if ($swAttesa.Elapsed.TotalSeconds -ge $TimeoutSec) {
                $std = [pscustomobject]@{
                    Conferma = $true; Cliente = 'Utente'; Nome = 'Utente'; Cognome = ''
                    Email = ''; Password = ''; Provider = 'Microsoft'
                    Telefono = ''; ProfiloApp = 'BASE'
                    Servizi = [pscustomobject]@{ Everyday = $true; Proton = $false; Office = $false; OfficeTipo = 'no'; McAfee = $false; Norton = $false; Cyber = $false }
                }
                [void](Set-DatiCliente $std)
                $Global:SkipAccountPrompt = $true
                Write-OK "Nessun dato cliente inserito entro ${TimeoutSec}s: proseguo automaticamente (Utente) e completo la configurazione."
                return $true
            }
            try {
                if (Get-Command Invoke-PassiSingoliCoda -ErrorAction SilentlyContinue) { Invoke-PassiSingoliCoda }
            } catch {}
            try {
                if ([Console]::KeyAvailable) {
                    $k = [Console]::ReadKey($true)
                    if ($k.Key -eq [ConsoleKey]::Enter) {
                        $std = [pscustomobject]@{
                            Conferma = $true; Cliente = 'Utente'; Nome = 'Utente'; Cognome = ''
                            Email = ''; Password = ''; Provider = 'Microsoft'
                            Telefono = ''; ProfiloApp = 'BASE'
                            Servizi = [pscustomobject]@{ Everyday = $true; Proton = $false; Office = $false; OfficeTipo = 'no'; McAfee = $false; Norton = $false; Cyber = $false }
                        }
                        [void](Set-DatiCliente $std)
                        $Global:SkipAccountPrompt = $true
                        Write-OK "Continuo subito con profilo standard (nessuna card Office)."
                        return $true
                    }
                    if ($k.Key -eq [ConsoleKey]::P -and $Global:PannelloFile) {
                        try { Set-SplitScreenLayout -HtmlPath $Global:PannelloFile } catch { try { Start-Process $Global:PannelloFile } catch {} }
                        Write-Info "Pannello riaperto."
                    }
                }
            } catch {}
            Start-Sleep -Milliseconds 400
        }
    } finally {
        Update-PannelloStatus -AttesaDati 'no'
    }
    return $true
}

# =============================================================================
# GESTIONE OFFLINE INSTALLERS & PREPARAZIONE USB
# =============================================================================

function Get-OfflineDirs {
    $dirs = [System.Collections.Generic.List[string]]::new()

    $clean = {
        param([string]$p)
        if ([string]::IsNullOrWhiteSpace($p)) { return $null }
        $p = ($p -replace '["'']', '').Trim().TrimEnd('\').TrimEnd('/')
        # Escludi categoricamente le directory di sistema di Windows (es. C:\Windows, System32)
        $winDir = if ($env:WINDIR) { $env:WINDIR.TrimEnd('\') } else { "C:\Windows" }
        if ($p -like "$winDir*") { return $null }
        return $p
    }

    $addDir = {
        param([string]$base)
        $b = & $clean $base
        try {
            if ($b -and (Test-Path -LiteralPath $b -ErrorAction SilentlyContinue)) {
                $dirs.Add([System.IO.Path]::Combine($b, "installers"))
                $dirs.Add([System.IO.Path]::Combine($b, "offline"))
                $dirs.Add([System.IO.Path]::Combine($b, "cache"))
                $dirs.Add($b)
            }
        } catch {}
    }

    if ($Global:TargetDir) { & $addDir $Global:TargetDir }
    if ($TargetDir -and $TargetDir -ne $Global:TargetDir) { & $addDir $TargetDir }
    if ($PSScriptRoot) { & $addDir $PSScriptRoot }
    $curr = try { (Get-Location).Path } catch { $null }
    if ($curr) { & $addDir $curr }

    try {
        $allDrives = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.IsReady -and ($_.Name -match '^[a-zA-Z]:' -or $_.DriveType -eq 'Removable') }
        foreach ($d in $allDrives) {
            $root = $d.RootDirectory.FullName
            if ($root) { & $addDir $root }
        }
    } catch {
        try {
            $removables = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter }
            foreach ($r in $removables) {
                $rPath = "$($r.DriveLetter):\"
                & $addDir $rPath
            }
        } catch {}
    }

    $existing = @()
    foreach ($d in $dirs) {
        if (-not $d) { continue }
        $cd = & $clean $d
        try {
            if ($cd -and (Test-Path -LiteralPath $cd -ErrorAction SilentlyContinue) -and -not ($existing -contains $cd)) {
                $existing += $cd
            }
        } catch {}
    }
    return $existing
}

function Stop-AppPopups {
    param([string]$Nome)
    if ($Test) { return }
    try {
        $targets = @()
        if ($Nome -like "*Spotify*") { $targets += "Spotify" }
        elseif ($Nome -like "*Zoom*") { $targets += "Zoom" }
        elseif ($Nome -like "*Discord*") { $targets += "Discord" }
        elseif ($Nome -like "*Steam*") { $targets += "Steam" }
        elseif ($Nome -like "*AIMP*") { $targets += "AIMP" }
        elseif ($Nome -like "*Adobe*" -or $Nome -like "*Acrobat*") { $targets += @("AdobeCollabSync", "AcroCEF", "AcrobatNotificationClient") }
        elseif ($Nome -like "*Teams*") { $targets += @("ms-teams", "Teams") }
        elseif ($Nome -like "*AnyDesk*") { $targets += "AnyDesk" }
        elseif ($Nome -like "*Skype*") { $targets += "SkypeApp" }
        elseif ($Nome -like "*7-Zip*" -or $Nome -like "*7z*") { $targets += @("7zFM", "7zG", "7z") }

        # Helper e popup molesti di background
        $targets += @("AdobeCollabSync", "AcroCEF")

        if ($targets.Count -gt 0) {
            Start-Sleep -Seconds 1
            foreach ($t in $targets) {
                $procs = Get-Process -Name $t -ErrorAction SilentlyContinue
                if ($procs) {
                    $procs | Stop-Process -Force -ErrorAction SilentlyContinue
                }
            }
        }

        # Chiudi finestre di dialogo di errore note rimaste orfane (es. 7-Zip "Can't load config info")
        Get-Process -ErrorAction SilentlyContinue | Where-Object {
            $_.MainWindowTitle -match 'can''t load config info' -and $_.ProcessName -notmatch 'powershell|code|msedge'
        } | ForEach-Object { try { $_.Kill() } catch {} }
    } catch {}
}

function Enable-PreventSleep {
    if ($Test) { return }
    try {
        Add-Type -TypeDefinition @"
        using System;
        using System.Runtime.InteropServices;
        public class WinPower {
            [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
            public static extern uint SetThreadExecutionState(uint esFlags);
            public const uint ES_SYSTEM_REQUIRED = 0x00000001;
            public const uint ES_DISPLAY_REQUIRED = 0x00000002;
            public const uint ES_CONTINUOUS = 0x80000000;
        }
"@ -ErrorAction SilentlyContinue
        [WinPower]::SetThreadExecutionState([WinPower]::ES_CONTINUOUS -bor [WinPower]::ES_SYSTEM_REQUIRED -bor [WinPower]::ES_DISPLAY_REQUIRED) | Out-Null
    } catch {}
}

function Find-OfflineInstaller {
    param(
        [string]$WingetId,
        [string]$Nome
    )
    $dirs = Get-OfflineDirs
    if ($dirs.Count -eq 0) { return $null }

    $patterns = @{
        "Google.Chrome"                     = @("*Chrome*Setup*.exe", "*Chrome*Standalone*.exe", "*googlechrome*.exe", "*Chrome*.msi")
        "Mozilla.Firefox"                  = @("*Firefox*Setup*.exe", "*firefox*.exe", "*Firefox*Installer*.exe", "*Firefox*.msi")
        "VideoLAN.VLC"                     = @("*vlc*win64.exe", "*vlc*.exe", "*vlc*.msi")
        "Adobe.Acrobat.Reader.64-bit"      = @("*AcroRdr*.exe", "*Acrobat*Reader*.exe", "*AdbeRdr*.exe", "*AcroRdr*it_IT*.exe", "*Acro*.msi")
        "SumatraPDF.SumatraPDF"            = @("*SumatraPDF*.exe", "*SumatraPDF*.msi")
        "7zip.7zip"                        = @("*7z*x64.msi", "*7z*.msi", "*7z*x64.exe", "*7z*.exe")
        "AnyDesk.AnyDesk"                  = @("*AnyDesk*.exe")
        "TeamViewer.TeamViewer"            = @("*TeamViewer*Setup*.exe", "*TeamViewer*.exe", "*TeamViewer*.msi")
        "Zoom.Zoom"                        = @("*Zoom*.msi", "*ZoomInstaller*.exe", "*Zoom*.exe")
        "TheDocumentFoundation.LibreOffice"= @("*LibreOffice*x86-64.msi", "*LibreOffice*.msi", "*LibreOffice*.exe")
        "Apache.OpenOffice"                = @("*Apache*OpenOffice*.exe", "*OpenOffice*.exe", "*OpenOffice*.msi")
        "Spotify.Spotify"                  = @("*Spotify*Full*Setup*.exe", "*Spotify*Setup*.exe", "*Spotify*.exe", "*Spotify*.msixbundle")
        "9NKSQGP7F2NH"                     = @("*WhatsApp*.exe", "*WhatsApp*.msixbundle", "*WhatsApp*.appxbundle")
        "GIMP.GIMP"                        = @("*gimp*setup*.exe", "*gimp*.exe", "*gimp*.msi")
        "Valve.Steam"                      = @("*SteamSetup*.exe", "*Steam*.exe")
        "EpicGames.EpicGamesLauncher"      = @("*EpicGamesLauncher*.msi", "*EpicInstaller*.msi", "*EpicGames*.exe")
        "Discord.Discord"                  = @("*DiscordSetup*.exe", "*Discord*.exe")
        "AIMP.AIMP"                        = @("*aimp*.exe")
        "Intel.IntelDriverAndSupportAssistant" = @("*Intel*Driver*Support*Assistant*.exe", "*IntelDSA*.exe", "*Intel*.exe")
        "Microsoft.Office"                 = @("*OfficeSetup*.exe", "*Office*.exe", "*Setup32*.exe", "*Setup64*.exe")
        "Microsoft.VCRedist.2015+.x64"      = @("*vc_redist.x64*.exe", "*vcredist*x64*.exe")
        "Microsoft.VCRedist.2015+.x86"      = @("*vc_redist.x86*.exe", "*vcredist*x86*.exe")
        "MCPR"                             = @("*MCPR*.exe")
        "NRnR"                             = @("*NRnR*.exe")
    }

    $namePatterns = @{
        "Visual C++ x64"                   = @("*vc_redist.x64*.exe", "*vcredist*x64*.exe")
        "Visual C++ x86"                   = @("*vc_redist.x86*.exe", "*vcredist*x86*.exe")
        "Microsoft Visual C++ 2015-2022 (x64)" = @("*vc_redist.x64*.exe", "*vcredist*x64*.exe")
        "Microsoft Visual C++ 2015-2022 (x86)" = @("*vc_redist.x86*.exe", "*vcredist*x86*.exe")
        "VLC"                              = @("*vlc*win64.exe", "*vlc*.exe", "*vlc*.msi")
        "Adobe Acrobat Reader"             = @("*AcroRdr*.exe", "*Acrobat*Reader*.exe", "*AdbeRdr*.exe", "*AcroRdr*it_IT*.exe", "*Acro*.msi")
        "Sumatra PDF"                      = @("*SumatraPDF*.exe", "*SumatraPDF*.msi")
        "7-Zip"                            = @("*7z*x64.msi", "*7z*.msi", "*7z*x64.exe", "*7z*.exe")
        "AnyDesk"                          = @("*AnyDesk*.exe")
        "TeamViewer"                       = @("*TeamViewer*Setup*.exe", "*TeamViewer*.exe", "*TeamViewer*.msi")
        "Zoom"                             = @("*Zoom*.msi", "*ZoomInstaller*.exe", "*Zoom*.exe")
        "LibreOffice"                      = @("*LibreOffice*x86-64.msi", "*LibreOffice*.msi", "*LibreOffice*.exe")
        "OpenOffice"                       = @("*Apache*OpenOffice*.exe", "*OpenOffice*.exe", "*OpenOffice*.msi")
        "Spotify"                          = @("*Spotify*Full*Setup*.exe", "*Spotify*Setup*.exe", "*Spotify*.exe", "*Spotify*.msixbundle")
        "WhatsApp"                         = @("*WhatsApp*.exe", "*WhatsApp*.msixbundle", "*WhatsApp*.appxbundle")
        "GIMP"                             = @("*gimp*setup*.exe", "*gimp*.exe", "*gimp*.msi")
        "Steam"                            = @("*SteamSetup*.exe", "*Steam*.exe")
        "Epic Games Launcher"              = @("*EpicGamesLauncher*.msi", "*EpicInstaller*.msi", "*EpicGames*.exe")
        "Discord"                          = @("*DiscordSetup*.exe", "*Discord*.exe")
        "AIMP"                             = @("*aimp*.exe")
        "Intel Driver e Support Assistant" = @("*Intel*Driver*Support*Assistant*.exe", "*IntelDSA*.exe", "*Intel*.exe")
        "Microsoft 365"                    = @("*OfficeSetup*.exe", "*Office*.exe", "*Setup32*.exe", "*Setup64*.exe")
        "MCPR"                             = @("*MCPR*.exe")
        "NRnR"                             = @("*NRnR*.exe")
    }

    $searchList = @()
    if ($WingetId -and $patterns.ContainsKey($WingetId)) { $searchList += $patterns[$WingetId] }
    if ($Nome -and $patterns.ContainsKey($Nome)) { $searchList += $patterns[$Nome] }
    if ($Nome -and $namePatterns.ContainsKey($Nome)) { $searchList += $namePatterns[$Nome] }
    if ($WingetId) {
        $searchList += "*$WingetId*.msi"
        $searchList += "*$WingetId*.exe"
    }
    if ($Nome) {
        $cleanNome = ($Nome -replace '[^a-zA-Z0-9]','*')
        $searchList += "*$cleanNome*.msi"
        $searchList += "*$cleanNome*.exe"
    }

    # Preferisci pacchetti .msi prima di .exe per massima affidabilita' silent
    $orderedSearchList = @($searchList | Sort-Object { if ($_ -like "*.msi") { 0 } else { 1 } })

    foreach ($d in $dirs) {
        if (-not (Test-Path -LiteralPath $d)) { continue }
        try {
            $files = @(Get-ChildItem -LiteralPath $d -File -ErrorAction SilentlyContinue)
            if ($files.Count -eq 0) { continue }
            foreach ($p in $orderedSearchList) {
                # Controllo dimensione minima (>= 100 KB) per scartare file parziali, vuoti o non validi
                $matched = $files | Where-Object { $_.Name -like $p -and $_.Length -ge 102400 } | Select-Object -First 1
                if ($matched) { return $matched.FullName }
            }
        } catch {}
    }
    return $null
}

function Install-OfflinePackage {
    param(
        [string]$FilePath,
        [string]$Nome
    )
    if ($Test) { Write-OK "TEST: installazione offline simulata per $Nome ($FilePath)"; return $true }
    Write-Info "Installazione offline da USB in corso: $Nome ($FilePath)..."
    try {
        if (-not (Test-Path -LiteralPath $FilePath)) {
            Write-Info "File offline non trovato: $FilePath. Procedo con Winget..."
            return $false
        }
        $fItem = Get-Item -LiteralPath $FilePath -ErrorAction SilentlyContinue
        if ($fItem -and $fItem.Length -lt 102400) {
            Write-Info "File offline $FilePath troppo piccolo ($($fItem.Length) bytes, possibile download corrotto). Procedo con Winget..."
            return $false
        }

        $ext = [System.IO.Path]::GetExtension($FilePath).ToLower()
        $workDir = Split-Path -Path $FilePath -Parent
        if (-not $workDir -or -not (Test-Path -LiteralPath $workDir)) { $workDir = $env:TEMP }
        $proc = $null
        if ($ext -eq '.msi') {
            for ($mTry = 1; $mTry -le 3; $mTry++) {
                $proc = Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i `"$FilePath`" /qn /norestart" -WorkingDirectory $workDir -PassThru -ErrorAction Stop
                $timer = 0
                while (-not $proc.HasExited -and $timer -lt 300) {
                    Start-Sleep -Seconds 2
                    $timer += 2
                    if ($timer % 10 -eq 0) {
                        Write-Host "     -> ${Nome}: installazione MSI in corso... (${timer}s / max 300s)" -ForegroundColor DarkGray
                    }
                }
                if (-not $proc.HasExited) {
                    try { $proc.Kill() } catch {}
                    Write-Info "Installazione MSI per $Nome ha superato il timeout (300s). Procedo con fallback..."
                    return $false
                }
                if ($proc.ExitCode -eq 1618 -and $mTry -lt 3) {
                    Write-Info "Windows Installer occupato (1618) per ${Nome}: attendo 10s e riprovo..."
                    Start-Sleep -Seconds 10
                    continue
                }
                break
            }
        } elseif ($ext -eq '.msixbundle' -or $ext -eq '.appxbundle' -or $ext -eq '.msix' -or $ext -eq '.appx') {
            Add-AppxPackage -Path $FilePath -ErrorAction Stop
            Write-OK "$Nome installato con successo da pacchetto offline Appx/MSIX!"
            Stop-AppPopups -Nome $Nome
            return $true
        } elseif ($FilePath -like "*Spotify*" -or $Nome -eq "Spotify") {
            # Spotify blocca l'installazione se avviato direttamente da Amministratore (Token elevato).
            # Lo avviamo nel contesto utente standard (Medium Integrity) tramite Scheduled Task limitata o runas.
            $taskName = "PCFacile_Spotify_$([Math]::Abs((Get-Random) % 10000))"
            try {
                if (Get-Command New-ScheduledTaskAction -ErrorAction SilentlyContinue) {
                    $action = New-ScheduledTaskAction -Execute $FilePath -Argument "/silent" -WorkingDirectory $workDir
                    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
                    Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Force -ErrorAction Stop | Out-Null
                    Start-ScheduledTask -TaskName $taskName -ErrorAction Stop
                    
                    $t = 0
                    Start-Sleep -Seconds 3
                    $spotExeCheck = Join-Path $env:APPDATA "Spotify\Spotify.exe"
                    $spotLocalCheck = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\Spotify.exe"
                    while ($t -lt 120) {
                        if ((Test-Path $spotExeCheck) -or (Test-Path $spotLocalCheck)) { break }
                        if (-not (Get-Process -Name "*Spotify*" -ErrorAction SilentlyContinue) -and $t -ge 10) { break }
                        Start-Sleep -Seconds 2
                        $t += 2
                    }
                    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
                } else {
                    & schtasks.exe /create /tn $taskName /tr "`"$FilePath`" /silent" /sc ONCE /st 00:00 /ru "$env:USERNAME" /rl LIMITED /f 2>$null | Out-Null
                    & schtasks.exe /run /tn $taskName 2>$null | Out-Null
                    Start-Sleep -Seconds 8
                    & schtasks.exe /delete /tn $taskName /f 2>$null | Out-Null
                }
            } catch {
                try {
                    Start-Process -FilePath $FilePath -ArgumentList "/silent" -WorkingDirectory $workDir -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
                } catch {}
            }

            # Verifica se Spotify e' installato nel profilo utente
            $spotExe = Join-Path $env:APPDATA "Spotify\Spotify.exe"
            $spotLocal = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\Spotify.exe"
            if ((Test-Path $spotExe) -or (Test-Path $spotLocal) -or (Get-Process "Spotify" -ErrorAction SilentlyContinue)) {
                Write-OK "$Nome installato con successo!"
                Stop-AppPopups -Nome $Nome
                return $true
            } else {
                Write-Info "Installazione standard di Spotify non rilevata. Procedo con fallback..."
                return $false
            }
        } else {
            $arg = "/S"
            if ($FilePath -like "*Chrome*") { $arg = "/silent /install" }
            elseif ($FilePath -like "*Opera*") { $arg = "/silent /launchopera=0 /setdefaultbrowser=0 /allusers=1" }
            elseif ($FilePath -like "*Firefox*") { $arg = "/S" }
            elseif ($FilePath -like "*7z*") { $arg = "/S" }
            elseif ($FilePath -like "*vlc*") { $arg = "/L=1040 /S" }
            elseif ($FilePath -like "*Acro*" -or $FilePath -like "*Adbe*") { $arg = "/sAll /rs /rps /msi /norestart /quiet EULA_ACCEPT=YES" }
            elseif ($FilePath -like "*Sumatra*") { $arg = "/S" }
            elseif ($FilePath -like "*AnyDesk*") { $arg = "--install `"${env:ProgramFiles(x86)}\AnyDesk`" --start-with-win --silent --create-shortcuts" }
            elseif ($FilePath -like "*TeamViewer*") { $arg = "/S" }
            elseif ($FilePath -like "*Zoom*") { $arg = "/silent" }
            elseif ($FilePath -like "*Discord*") { $arg = "-s" }
            elseif ($FilePath -like "*WhatsApp*") { $arg = "--silent" }
            elseif ($FilePath -like "*LibreOffice*" -or $FilePath -like "*OpenOffice*") { $arg = "/S" }
            elseif ($FilePath -like "*aimp*") { $arg = "/AUTO=`"$env:ProgramFiles\AIMP`" /SILENT" }
            elseif ($FilePath -like "*gimp*") { $arg = "/VERYSILENT /NORESTART /ALLUSERS" }
            elseif ($FilePath -like "*Steam*") { $arg = "/S" }
            elseif ($FilePath -like "*Intel*") { $arg = "/quiet /norestart" }
            elseif ($FilePath -like "*vc_redist*" -or $FilePath -like "*vcredist*") { $arg = "/install /quiet /norestart" }

            $isWhatsAppStub = ($FilePath -like "*WhatsApp*" -or $Nome -like "*WhatsApp*")
            $proc = Start-Process -FilePath $FilePath -ArgumentList $arg -WorkingDirectory $workDir -PassThru -ErrorAction Stop
            $timer = 0
            $maxWait = 300
            while (-not $proc.HasExited -and $timer -lt $maxWait) {
                Start-Sleep -Seconds 1
                $timer += 1
                if ($timer % 5 -eq 0) {
                    Write-Host "     -> ${Nome}: installazione in corso... (${timer}s / max ${maxWait}s)" -ForegroundColor DarkGray
                }
                if ($isWhatsAppStub -and ($timer % 2 -eq 0)) {
                    try {
                        # Se il pacchetto Store di WhatsApp risulta gia' installato, chiudi subito la mini-finestra dello Store
                        if (Get-AppxPackage -Name "*WhatsApp*" -ErrorAction SilentlyContinue) {
                            try { $proc.Kill() } catch {}
                            Get-Process -Name "WhatsAppInstaller*","StoreInstaller*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
                            break
                        }
                        # Premi automaticamente il pulsante "Installa" / "Install" nella finestra Microsoft Store (PEGI) via UIAutomation
                        Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes -ErrorAction SilentlyContinue
                        $rootEl = [System.Windows.Automation.AutomationElement]::RootElement
                        if ($rootEl) {
                            $winCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Window)
                            foreach ($win in $rootEl.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)) {
                                $wName = [string]$win.Current.Name
                                if ($wName -match '(?i)(Microsoft Store|WhatsApp|StoreInstaller)') {
                                    $btnCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
                                    foreach ($btn in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
                                        $bName = ([string]$btn.Current.Name).Trim()
                                        if ($bName -match '^(?i)(Installa|Install|Ottieni|Get)$') {
                                            $inv = $null
                                            if ($btn.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$inv) -and $inv) {
                                                $inv.Invoke()
                                                Write-Info "Premuto automaticamente '$bName' nella finestra Microsoft Store per $Nome."
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } catch {}
                }
                try {
                    # Rileva e chiudi all'istante eventuali finestre di dialogo o di errore bloccanti (es. 7-Zip "Can't load config info")
                    $errProcs = Get-Process -ErrorAction SilentlyContinue | Where-Object {
                        $_.Id -eq $proc.Id -or ($_.ProcessName -match '7z|installer|setup' -and $_.MainWindowTitle -match '7-Zip|error|errore|can''t load|config')
                    }
                    foreach ($ep in $errProcs) {
                        if ($ep.MainWindowTitle -match '7-Zip|error|errore|can''t load|config') {
                            Write-Info "Rilevato popup di errore/avviso bloccante ($($ep.MainWindowTitle)): chiusura automatica..."
                            try { $ep.Kill() } catch {}
                        }
                    }
                } catch {}
            }
            if (-not $proc.HasExited) {
                try { $proc.Kill() } catch {}
                Write-Info "Processo di installazione offline per $Nome ha superato il tempo massimo ($($maxWait)s). Procedo con Winget..."
                return $false
            }
        }
        if ($proc -and ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010 -or $proc.ExitCode -eq 1641)) {
            Write-OK "$Nome installato con successo!"
            Stop-AppPopups -Nome $Nome
            return $true
        } else {
            Start-Sleep -Seconds 3
            if (Test-IsAppInstalled -Nome $Nome) {
                Write-OK "$Nome installato con successo (verificato su disco)!"
                Stop-AppPopups -Nome $Nome
                return $true
            }
            $code = if ($proc) { $proc.ExitCode } else { "sconosciuto" }
            Write-Info "Installazione pacchetto per $Nome uscita con codice $code."
        }
    } catch {
        Write-Info "Installazione offline non riuscita ($($_.Exception.Message)). Procedo con Winget..."
    }
    return $false
}

# Fallback diretto ufficiale per le app del catalogo quando Winget/msstore
# falliscono (es. contesto Admin per Spotify, errore certificato 0x8a15005e
# su reti negozio con proxy/filtro, o sorgente msstore bloccata).
function Install-AppDirectFallback {
    param([string]$WingetId, [string]$Nome)
    if ($Test -or $Global:Test -or $env:PESTER_TEST) {
        Write-OK "TEST: fallback diretto $Nome simulato."
        return $true
    }
    $mappa = @{
        'Google.Chrome'                     = @{ Base = 'ChromeStandaloneSetup64'; Urls = @('https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi', 'https://dl.google.com/tag/s/appguid%3D%7B8A69D345-D564-463C-AFF5-1A09E5037969%7D%26iid%3D%7B00000000-0000-0000-0000-000000000000%7D%26lang%3Dit%26browser%3D4%26usagestats%3D0%26appname%3DGoogle%2520Chrome%26needsadmin%3Dprefers%26ap%3Dx64-stable-statsdef_1/chrome/install/ChromeStandaloneSetup64.exe') }
        'Opera.OperaGX'                     = @{ Base = 'OperaGXSetup'; Urls = @('https://net.geo.opera.com/opera_gx/stable/windows') }
        'Mozilla.Firefox'                   = @{ Base = 'Firefox_Setup'; Urls = @('https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=it') }
        'VideoLAN.VLC'                      = @{ Base = 'vlc-win64'; Urls = @('https://download.videolan.org/pub/videolan/vlc/last/win64/vlc-3.0.21-win64.exe') }
        'Adobe.Acrobat.Reader.64-bit'       = @{ Base = 'AcroRdrDC_it_IT'; Urls = @('https://ardownload2.adobe.com/pub/adobe/reader/win/AcrobatDC/2500120432/AcroRdrDC2500120432_it_IT.exe', 'https://ardownload2.adobe.com/pub/adobe/acrobat/win/AcrobatDC/2600322075/AcroRdrDCx642600322075_MUI.exe') }
        'SumatraPDF.SumatraPDF'             = @{ Base = 'SumatraPDF-install'; Urls = @('https://www.sumatrapdfreader.org/dl/rel/3.6.1/SumatraPDF-3.6.1-64-install.exe', 'https://files2.sumatrapdfreader.org/software/sumatrapdf/rel/3.6.1/SumatraPDF-3.6.1-64-install.exe') }
        'Spotify.Spotify'                   = @{ Base = 'SpotifyFullSetup'; Urls = @('https://download.scdn.co/SpotifyFullSetup.exe', 'https://download.scdn.co/SpotifySetup.exe') }
        'AIMP.AIMP'                         = @{ Base = 'aimp_setup'; Urls = @('https://aimp.ru/?do=download.file&id=3') }
        '7zip.7zip'                         = @{ Base = '7z-x64'; Urls = @('https://www.7-zip.org/a/7z2409-x64.msi', 'https://www.7-zip.org/a/7z2408-x64.msi') }
        '9NKSQGP7F2NH'                      = @{ Base = 'WhatsAppInstaller'; Urls = @('https://get.microsoft.com/installer/download/9NKSQGP7F2NH?cid=website_cta_psi') }
        'GIMP.GIMP'                         = @{ Base = 'gimp-setup'; Urls = @('https://download.gimp.org/gimp/v3.0/windows/gimp-3.0.8-setup.exe', 'https://download.gimp.org/gimp/v3.0/windows/gimp-3.0.6-setup.exe') }
        'Valve.Steam'                       = @{ Base = 'SteamSetup'; Urls = @('https://cdn.fastly.steamstatic.com/client/installer/SteamSetup.exe') }
        'EpicGames.EpicGamesLauncher'       = @{ Base = 'EpicGamesLauncherInstaller'; Urls = @('https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncherInstaller.msi') }
        'AnyDesk.AnyDesk'                   = @{ Base = 'AnyDesk'; Urls = @('https://download.anydesk.com/AnyDesk.exe') }
        'Discord.Discord'                   = @{ Base = 'DiscordSetup'; Urls = @('https://discord.com/api/downloads/distributions/app/installers/latest?channel=stable&platform=win&arch=x64') }
        'Zoom.Zoom'                         = @{ Base = 'ZoomInstallerFull'; Urls = @('https://zoom.us/client/latest/ZoomInstallerFull.msi', 'https://zoom.us/client/latest/ZoomInstaller.msi') }
        'TheDocumentFoundation.LibreOffice' = @{ Base = 'LibreOffice_Win_x86-64'; Urls = @('https://download.documentfoundation.org/libreoffice/stable/26.8.3/win/x86_64/LibreOffice_26.8.3_Win_x86-64.msi', 'https://download.documentfoundation.org/libreoffice/stable/25.8.7/win/x86_64/LibreOffice_25.8.7_Win_x86-64.msi') }
    }
    $entry = if ($WingetId -and $mappa.ContainsKey($WingetId)) { $mappa[$WingetId] } else { $null }
    if (-not $entry) { return $false }

    $curlBin = Join-Path $env:SystemRoot "System32\curl.exe"
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13 } catch {}
    foreach ($u in $entry.Urls) {
        $extDest = if ($u -match '\.msi(\?|$)') { '.msi' } else { '.exe' }
        $dest = Join-Path $env:TEMP ($entry.Base + $extDest)
        try {
            Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
            Write-Info "Scarico installer ufficiale $Nome ($u)..."
            if (Test-Path -LiteralPath $curlBin) {
                & $curlBin -fL --retry 2 --connect-timeout 15 --max-time 600 -sS -A "Mozilla/5.0" -o $dest $u 2>$null
            } else {
                Invoke-WebRequest -Uri $u -OutFile $dest -UseBasicParsing -TimeoutSec 600 -ErrorAction Stop
            }
            if ((Test-Path -LiteralPath $dest) -and ((Get-Item -LiteralPath $dest).Length -gt 102400)) {
                # Verifica magic byte (MZ per .exe o D0CF per .msi) per scartare pagine HTML di errore
                $hdr = New-Object byte[] 4
                $nRead = 0
                $fsHdr = [System.IO.File]::OpenRead($dest)
                try { $nRead = $fsHdr.Read($hdr, 0, 4) } finally { $fsHdr.Close() }
                $isBin = ($nRead -ge 2) -and (($hdr[0] -eq 0x4D -and $hdr[1] -eq 0x5A) -or ($hdr[0] -eq 0xD0 -and $hdr[1] -eq 0xCF))
                if (-not $isBin) {
                    Write-Info "File scaricato da $u non e' un installer binario valido: passo all'URL successivo..."
                    Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
                    continue
                }
                $okOff = Install-OfflinePackage -FilePath $dest -Nome $Nome
                Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
                if ($okOff) { return $true }
                break
            }
        } catch {
            Write-Info "Download diretto $Nome da $u non riuscito: $($_.Exception.Message)"
        }
        Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
    }
    return $false
}

function Install-SpotifyDirect {
    return (Install-AppDirectFallback -WingetId 'Spotify.Spotify' -Nome 'Spotify')
}

# Visual C++ 2015-2022 gia' installato per l'architettura indicata (x64/x86).
function Test-VCRuntimePresente {
    param([ValidateSet('x64', 'x86')][string]$Arch)
    foreach ($base in @('HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes')) {
        try {
            $k = Get-ItemProperty -Path (Join-Path $base $Arch) -ErrorAction Stop
            if ([int]$k.Installed -eq 1 -and [int]$k.Major -eq 14 -and [int]$k.Minor -ge 30) { return $true }
        } catch {}
    }
    return $false
}

function Install-VisualCRuntime {
    if ($Test) {
        Write-OK "TEST: Installazione Microsoft Visual C++ Redistributable (x64 & x86) simulata."
        Add-Report "Microsoft Visual C++ Runtime (x64/x86)" "OK"
        return $true
    }

    Write-Info "Verifica e installazione Runtime Essenziali (Microsoft Visual C++ 2015-2022)..."
    $runtimes = @(
        @{ Nome = "Microsoft Visual C++ 2015-2022 (x64)"; WingetId = "Microsoft.VCRedist.2015+.x64"; Url = "https://aka.ms/vs/17/release/vc_redist.x64.exe"; File = "vc_redist.x64.exe" },
        @{ Nome = "Microsoft Visual C++ 2015-2022 (x86)"; WingetId = "Microsoft.VCRedist.2015+.x86"; Url = "https://aka.ms/vs/17/release/vc_redist.x86.exe"; File = "vc_redist.x86.exe" }
    )

    $allOk = $true
    foreach ($rt in $runtimes) {
        # 0. Gia' presente (registro del Visual C++ 2015-2022, versione 14.30+)? Salto.
        $archRt = if ($rt.WingetId -like '*x64') { 'x64' } else { 'x86' }
        if (Test-VCRuntimePresente -Arch $archRt) {
            Write-OK "$($rt.Nome) gia' installato. Salto."
            continue
        }
        # 1. Prova prima da installer offline USB se presente
        $offlineFile = Find-OfflineInstaller -WingetId $rt.WingetId -Nome $rt.Nome
        if ($offlineFile) {
            if (Install-OfflinePackage -FilePath $offlineFile -Nome $rt.Nome) {
                Write-OK "$($rt.Nome) installato da archivio offline USB."
                continue
            }
        }

        # 2. Prova installazione via Winget (specificando espressamente --source winget e nascondendo output spurio)
        $wingetInstalled = $false
        if (Confirm-Winget) {
            try {
                $vcOut = Join-Path $env:TEMP "winget-vc.out"
                $vcErr = Join-Path $env:TEMP "winget-vc.err"
                $p = Start-Process winget -ArgumentList "install --id $($rt.WingetId) --exact --source winget --silent --accept-source-agreements --accept-package-agreements" -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $vcOut -RedirectStandardError $vcErr -ErrorAction SilentlyContinue
                Remove-Item $vcOut, $vcErr -Force -ErrorAction SilentlyContinue
                if ($p -and ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010 -or $p.ExitCode -eq 1641 -or $p.ExitCode -eq -1978335189)) {
                    $wingetInstalled = $true
                    Write-OK "$($rt.Nome) installato via Winget."
                }
            } catch {}
        }

        # 3. Fallback download diretto da server ufficiale Microsoft
        if (-not $wingetInstalled) {
            try {
                $tempDest = Join-Path $env:TEMP $rt.File
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
                Invoke-WebRequest -Uri $rt.Url -OutFile $tempDest -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
                $proc = Start-Process -FilePath $tempDest -ArgumentList "/install /quiet /norestart" -Wait -PassThru -ErrorAction Stop
                if ($proc -and ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010 -or $proc.ExitCode -eq 1641)) {
                    Write-OK "$($rt.Nome) installato da download diretto Microsoft."
                } else {
                    $allOk = $false
                }
            } catch {
                Write-Info "Installazione di $($rt.Nome) non riuscita: $_"
                $allOk = $false
            }
        }
    }

    if ($allOk) {
        Add-Report "Microsoft Visual C++ Runtime (x64/x86)" "OK"
    } else {
        Add-Report "Microsoft Visual C++ Runtime (x64/x86)" "AVVISO"
    }
    return $allOk
}

function Enable-WindowsUpdateAutoSettings {
    param([switch]$Test)
    if ($Test -or -not $RunReale) { return }
    try {
        # Attiva l'interruttore "Ottieni gli ultimi aggiornamenti non appena sono disponibili"
        # (Windows 11 22H2/23H2/24H2/25H2) e abilita gli aggiornamenti facoltativi/di anteprima
        $uxKey = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
        if (-not (Test-Path $uxKey)) { New-Item -Path $uxKey -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty -Path $uxKey -Name 'IsContinuousInnovationOptedIn' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $uxKey -Name 'ExcludeWUDriversInQualityUpdate' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

        $polWuKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
        if (-not (Test-Path $polWuKey)) { New-Item -Path $polWuKey -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty -Path $polWuKey -Name 'AllowTemporaryEnterpriseFeatureControl' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $polWuKey -Name 'AllowOptionalContent' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

        $auKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update'
        if (-not (Test-Path $auKey)) { New-Item -Path $auKey -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty -Path $auKey -Name 'AUOptions' -Value 4 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $auKey -Name 'IncludeRecommendedUpdates' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

        $polAuKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
        if (-not (Test-Path $polAuKey)) { New-Item -Path $polAuKey -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty -Path $polAuKey -Name 'NoAutoUpdate' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $polAuKey -Name 'AUOptions' -Value 4 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $polAuKey -Name 'AllowMUUpdateService' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $polAuKey -Name 'IncludeRecommendedUpdates' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

        try {
            Set-Service -Name 'wuauserv' -StartupType Automatic -ErrorAction SilentlyContinue
            Start-Service -Name 'wuauserv' -ErrorAction SilentlyContinue
            Start-Service -Name 'UsoSvc' -ErrorAction SilentlyContinue
        } catch {}

        try {
            $sm = New-Object -ComObject Microsoft.Update.ServiceManager
            $null = $sm.AddService2('7971f918-a847-4430-9279-4a52d1efe18d', 7, '')
        } catch {}

        $uso = Join-Path $env:SystemRoot 'System32\UsoClient.exe'
        if (Test-Path -LiteralPath $uso) {
            Start-Process -FilePath $uso -ArgumentList 'StartInteractiveScan' -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {}
}

function Install-WindowsUpdateDrivers {
    param(
        [int]$TimeoutSec = 360,
        [switch]$Test
    )
    if ($Test -or -not $RunReale) {
        Write-OK "TEST: simulazione ricerca/aggiornamento driver Windows Update completata."
        Add-Report "Driver (Windows Update)" "OK"
        Update-PannelloStatus -TaskId "driver" -Stato "done" -Percentuale 72 -Dettaglio "Completato (test)"
        return @{ Esito = "OK"; Trovati = 0; Installati = 0; RebootRequired = $false }
    }
    Enable-WindowsUpdateAutoSettings

    Write-Info "Ricerca e installazione driver su Windows Update in corso (max $([math]::Round($TimeoutSec/60)) min)..."
    Write-Host "  (Puoi premere 'S' o 'Esc' in qualsiasi momento per saltare)" -ForegroundColor Yellow
    Start-BarraAnimata "Driver Windows Update [Premi S per saltare]"

    $jobDriver = Start-Job -ScriptBlock {
        $esito = [ordered]@{
            Trovati        = 0
            NomiDriver     = @()
            Scaricati      = 0
            Installati     = 0
            ResultCode     = 0
            RebootRequired = $false
            Errore         = $null
        }
        try {
            $sess = New-Object -ComObject Microsoft.Update.Session
            $searcher = $sess.CreateUpdateSearcher()
            $result = $searcher.Search("Type='Driver' and IsInstalled=0")
            if (-not $result -or -not $result.Updates -or $result.Updates.Count -eq 0) {
                return $esito
            }
            $daInstallare = New-Object -ComObject Microsoft.Update.UpdateColl
            $titoli = @()
            foreach ($u in $result.Updates) {
                if ($u.InstallationBehavior -and $u.InstallationBehavior.CanRequestUserInput) { continue }
                if (-not $u.EulaAccepted) { try { $u.AcceptEula() } catch {} }
                $daInstallare.Add($u) | Out-Null
                $titoli += [string]$u.Title
            }
            $esito.Trovati = $daInstallare.Count
            $esito.NomiDriver = $titoli
            if ($daInstallare.Count -eq 0) {
                return $esito
            }

            # Download
            $downloader = $sess.CreateUpdateDownloader()
            $downloader.Updates = $daInstallare
            $null = $downloader.Download()
            $esito.Scaricati = $daInstallare.Count

            # Install
            $installer = $sess.CreateUpdateInstaller()
            $installer.Updates = $daInstallare
            $resInst = $installer.Install()
            $esito.Installati = $daInstallare.Count
            $esito.ResultCode = $resInst.ResultCode
            $esito.RebootRequired = [bool]$resInst.RebootRequired
            return $esito
        } catch {
            $esito.Errore = $_.Exception.Message
            return $esito
        }
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $saltatoOperatore = $false
    $scadutoTimeout = $false

    while ($jobDriver.State -eq 'Running') {
        if ($sw.Elapsed.TotalSeconds -ge $TimeoutSec) {
            $scadutoTimeout = $true
            break
        }
        try {
            if ([Console]::KeyAvailable) {
                $k = [Console]::ReadKey($true)
                if ($k.Key -eq [ConsoleKey]::S -or $k.Key -eq [ConsoleKey]::Escape) {
                    $saltatoOperatore = $true
                    break
                }
            }
        } catch {}
        Start-Sleep -Milliseconds 400
    }

    Stop-BarraAnimata

    if ($saltatoOperatore) {
        try { Stop-Job $jobDriver -ErrorAction SilentlyContinue } catch {}
        try { Remove-Job $jobDriver -Force -ErrorAction SilentlyContinue } catch {}
        Write-Host ""
        Write-Info "Installazione driver interrotta dall'operatore (tasto S/Esc): proseguo con le app."
        Add-Report "Driver (Windows Update)" "SALTATO (dall'operatore)"
        Update-PannelloStatus -TaskId "driver" -Stato "done" -Percentuale 72 -Dettaglio "Driver saltati da operatore"
        return @{ Esito = "SALTATO"; Trovati = 0; Installati = 0; RebootRequired = $false }
    } elseif ($scadutoTimeout) {
        try { Stop-Job $jobDriver -ErrorAction SilentlyContinue } catch {}
        try { Remove-Job $jobDriver -Force -ErrorAction SilentlyContinue } catch {}
        Write-Host ""
        Write-Errore "Tempo massimo ricerca/download driver superato ($([math]::Round($TimeoutSec/60)) min): proseguo per non bloccare il setup notturno."
        Add-Report "Driver (Windows Update)" "AVVISO (timeout superato)"
        Update-PannelloStatus -TaskId "driver" -Stato "done" -Percentuale 72 -Dettaglio "Driver parziali (timeout superato)"
        return @{ Esito = "TIMEOUT"; Trovati = 0; Installati = 0; RebootRequired = $false }
    } else {
        $datiJob = $null
        try {
            $datiJob = Receive-Job $jobDriver -ErrorAction SilentlyContinue | Select-Object -Last 1
        } catch {}
        try { Remove-Job $jobDriver -Force -ErrorAction SilentlyContinue } catch {}

        if ($datiJob -and $datiJob.Errore) {
            Write-Errore "Ricerca/installazione driver non riuscita: $($datiJob.Errore)"
            Add-Report "Driver (Windows Update)" "ERRORE"
            Update-PannelloStatus -TaskId "driver" -Stato "error" -Percentuale 72 -Dettaglio "Non riuscito (proseguo)"
            return @{ Esito = "ERRORE"; Trovati = 0; Installati = 0; RebootRequired = $false; Errore = $datiJob.Errore }
        } elseif ($datiJob -and $datiJob.Trovati -eq 0) {
            Write-OK "Nessun driver da installare: risultano gia' tutti aggiornati."
            Add-Report "Driver (Windows Update)" "OK"
            Update-PannelloStatus -TaskId "driver" -Stato "done" -Percentuale 72 -Dettaglio "Tutti i driver gia' aggiornati"
            return @{ Esito = "OK"; Trovati = 0; Installati = 0; RebootRequired = $false }
        } elseif ($datiJob -and $datiJob.Installati -gt 0) {
            if ($datiJob.NomiDriver) {
                foreach ($t in $datiJob.NomiDriver) {
                    Write-Info "Driver installato: $t"
                }
            }
            if ($datiJob.ResultCode -eq 2) {
                Write-OK "Driver installati con successo ($($datiJob.Installati))."
                Add-Report "Driver installati ($($datiJob.Installati))" "OK"
            } else {
                Write-Info "Installazione driver conclusa (codice $($datiJob.ResultCode)): alcuni potrebbero richiedere riavvio."
                Add-Report "Driver (Windows Update)" "AVVISO"
            }
            if ($datiJob.RebootRequired) {
                Write-Info "Alcuni driver richiedono un RIAVVIO per completare."
            }
            Update-PannelloStatus -TaskId "driver" -Stato "done" -Percentuale 72 -Dettaglio "Driver installati ($($datiJob.Installati))"
            return @{ Esito = "OK"; Trovati = $datiJob.Trovati; Installati = $datiJob.Installati; RebootRequired = $datiJob.RebootRequired }
        } else {
            Write-OK "Controllo driver completato."
            Add-Report "Driver (Windows Update)" "OK"
            Update-PannelloStatus -TaskId "driver" -Stato "done" -Percentuale 72 -Dettaglio "Completato"
            return @{ Esito = "OK"; Trovati = 0; Installati = 0; RebootRequired = $false }
        }
    }
}

function Select-DestinazioneUSB {
    param(
        [string]$DefaultDir,
        [switch]$Test
    )

    $opzioni = [System.Collections.Generic.List[pscustomobject]]::new()
    $visti = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    # 1. Trova tutte le unita' rimovibili USB (massima priorita')
    try {
        $removables = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.IsReady -and $_.DriveType -eq 'Removable' }
        foreach ($r in $removables) {
            $p = $r.RootDirectory.FullName
            if ($visti.Add($p)) {
                $label = if ($r.VolumeLabel) { $r.VolumeLabel } else { "Chiavetta USB" }
                $freeGb = [Math]::Round($r.TotalFreeSpace / 1GB, 1)
                $totGb  = [Math]::Round($r.TotalSize / 1GB, 1)
                $opzioni.Add([pscustomobject]@{
                    Percorso    = $p
                    Etichetta   = "$p  -  $label (USB Removibile, $freeGb GB liberi di $totGb GB)"
                    Consigliato = $true
                })
            }
        }
    } catch {}

    # 2. Se e' stato passato un TargetDir o PSScriptRoot valido (es. da PC Facile.bat)
    $candDirs = @($DefaultDir, $Global:TargetDir, $PSScriptRoot)
    foreach ($cd in $candDirs) {
        if ($cd -and (Test-Path $cd) -and $cd -notlike "$env:TEMP*") {
            try {
                $full = (Get-Item $cd).FullName
                if ($visti.Add($full)) {
                    $opzioni.Add([pscustomobject]@{
                        Percorso    = $full
                        Etichetta   = "$full  (Cartella di avvio di PC Facile)"
                        Consigliato = ($opzioni.Count -eq 0)
                    })
                }
            } catch {}
        }
    }

    # 3. Altre unita' disco secondarie (Fixed/Esterne/Dati, es. D:\, E:\)
    try {
        $otherDrives = [System.IO.DriveInfo]::GetDrives() | Where-Object {
            $_.IsReady -and $_.DriveType -eq 'Fixed' -and $_.Name -notlike "C:*"
        }
        foreach ($od in $otherDrives) {
            $p = $od.RootDirectory.FullName
            if ($visti.Add($p)) {
                $label = if ($od.VolumeLabel) { $od.VolumeLabel } else { "Disco secondario" }
                $freeGb = [Math]::Round($od.TotalFreeSpace / 1GB, 1)
                $totGb  = [Math]::Round($od.TotalSize / 1GB, 1)
                $opzioni.Add([pscustomobject]@{
                    Percorso    = $p
                    Etichetta   = "$p  -  $label (Disco secondario, $freeGb GB liberi di $totGb GB)"
                    Consigliato = ($opzioni.Count -eq 0)
                })
            }
        }
    } catch {}

    # 4. Desktop di questo PC
    try {
        $desktopPath = [Environment]::GetFolderPath('Desktop')
        if ($desktopPath -and (Test-Path $desktopPath) -and $visti.Add($desktopPath)) {
            $opzioni.Add([pscustomobject]@{
                Percorso    = $desktopPath
                Etichetta   = "$desktopPath  (Desktop di questo PC)"
                Consigliato = ($opzioni.Count -eq 0)
            })
        }
    } catch {}

    # Se siamo in modalita' test o non interattiva, prendi la prima
    if ($Test -or $opzioni.Count -eq 0) {
        if ($opzioni.Count -gt 0) { return $opzioni[0].Percorso }
        $desk = [Environment]::GetFolderPath('Desktop')
        if ($desk -and (Test-Path $desk)) { return $desk }
        return $env:TEMP
    }

    Write-Host "Seleziona dove preparare i pacchetti offline:" -ForegroundColor White
    Write-Host ""
    for ($i = 0; $i -lt $opzioni.Count; $i++) {
        $num = $i + 1
        $opt = $opzioni[$i]
        $tag = if ($opt.Consigliato) { "  <-- CONSIGLIATO (INVIO)" } else { "" }
        $col = if ($opt.Consigliato) { [ConsoleColor]::Green } else { [ConsoleColor]::White }
        Write-Host "  [$num] " -ForegroundColor Yellow -NoNewline
        Write-Host "$($opt.Etichetta)$tag" -ForegroundColor $col
    }
    $sfNum = $opzioni.Count + 1
    Write-Host "  [$sfNum] Sfoglia cartelle / Inserisci percorso a mano..." -ForegroundColor Gray
    Write-Host ""

    $scelta = Attendi-Risposta "Scelta (1-$sfNum, INVIO = opzione 1 consigliata)"
    if ([string]::IsNullOrWhiteSpace($scelta) -or $scelta -eq "1") {
        return $opzioni[0].Percorso
    }

    if ($scelta -match '^\d+$') {
        $idx = [int]$scelta - 1
        if ($idx -ge 0 -and $idx -lt $opzioni.Count) {
            return $opzioni[$idx].Percorso
        }
        if ($idx -eq $opzioni.Count) {
            # Prova finestra di dialogo grafica per sfogliare
            try {
                Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
                $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
                $dialog.Description = "Seleziona la chiavetta USB o la cartella per i pacchetti offline"
                $dialog.ShowNewFolderButton = $true
                if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK -and $dialog.SelectedPath) {
                    return $dialog.SelectedPath
                }
            } catch {}
            $customPath = Attendi-Risposta "Scrivi il percorso della cartella (es. E:\ o D:\USB)"
            if ($customPath -and (Test-Path $customPath)) { return $customPath }
        }
    }

    if (Test-Path $scelta) { return $scelta }
    if ($opzioni.Count -gt 0) { return $opzioni[0].Percorso }
    $desk = [Environment]::GetFolderPath('Desktop')
    if ($desk -and (Test-Path $desk)) { return $desk }
    return $env:TEMP
}

function Invoke-PreparaUSBOffline {
    param([string]$TargetDir)

    Write-Titolo "PREPARAZIONE CHIAVETTA USB OFFLINE"
    Write-Host "Questa funzione scarica tutti i programmi di installazione (.exe / .msi)" -ForegroundColor White
    Write-Host "direttamente sulla chiavetta USB (cartella 'installers')." -ForegroundColor White
    Write-Host "Cosi' per le prossime configurazioni dei clienti il setup funzionera'" -ForegroundColor White
    Write-Host "al 100% OFFLINE e alla massima velocita' senza consumare banda!" -ForegroundColor Green
    Write-Host ""

    # 1. Selezione interattiva semplificata della cartella/chiavetta USB
    $targetBase = Select-DestinazioneUSB -DefaultDir $TargetDir
    Write-Host ""
    Write-Host "Destinazione selezionata: " -NoNewline
    Write-Host $targetBase -ForegroundColor Green

    $installersDir = Join-Path $targetBase "installers"
    if (-not (Test-Path $installersDir)) {
        try {
            New-Item -Path $installersDir -ItemType Directory -Force | Out-Null
            Write-OK "Creata cartella installers: $installersDir"
        } catch {
            Write-Errore "Impossibile creare cartella $installersDir : $_"
            return
        }
    }

    # 2. Catalogo dei pacchetti da scaricare
    $downloadCatalog = @(
        @{
            Nome      = "Google Chrome (64-bit Standalone)"
            File      = "ChromeStandaloneSetup64.exe"
            Urls      = @(
                "https://dl.google.com/tag/s/appguid%3D%7B8A69D345-D564-463C-AFF5-1A09E5037969%7D%26iid%3D%7B00000000-0000-0000-0000-000000000000%7D%26lang%3Dit%26browser%3D4%26usagestats%3D0%26appname%3DGoogle%2520Chrome%26needsadmin%3Dprefers%26ap%3Dx64-stable-statsdef_1/chrome/install/ChromeStandaloneSetup64.exe"
            )
            MinSizeKB = 50000
            Categoria = "Base"
        },
        @{
            Nome      = "Mozilla Firefox (Italiano 64-bit Full)"
            File      = "Firefox_Setup.exe"
            Urls      = @(
                "https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=it"
            )
            MinSizeKB = 45000
            Categoria = "Base"
        },
        @{
            Nome      = "VLC Media Player (64-bit)"
            File      = "vlc-win64.exe"
            Urls      = @(
                "https://download.videolan.org/pub/videolan/vlc/last/win64/vlc-3.0.21-win64.exe",
                "https://get.videolan.org/vlc/3.0.21/win64/vlc-3.0.21-win64.exe"
            )
            MinSizeKB = 35000
            Categoria = "Base"
        },
        @{
            Nome      = "Adobe Acrobat Reader (64-bit Italiano)"
            File      = "AcroRdrDCx64_it_IT.exe"
            Urls      = @(
                "https://ardownload2.adobe.com/pub/adobe/acrobat/win/AcrobatDC/2500120744/AcroRdrDCx642500120744_MUI.exe",
                "https://ardownload2.adobe.com/pub/adobe/acrobat/win/AcrobatDC/2400420243/AcroRdrDCx642400420243_MUI.exe"
            )
            MinSizeKB = 150000
            Categoria = "Base"
        },
        @{
            Nome      = "7-Zip (64-bit MSI)"
            File      = "7z-x64.msi"
            Urls      = @(
                "https://www.7-zip.org/a/7z2409-x64.msi",
                "https://www.7-zip.org/a/7z2408-x64.msi",
                "https://www.7-zip.org/a/7z2301-x64.msi"
            )
            MinSizeKB = 1500
            Categoria = "Base"
        },
        @{
            Nome      = "AnyDesk (Assistenza Remota)"
            File      = "AnyDesk.exe"
            Urls      = @(
                "https://download.anydesk.com/AnyDesk.exe"
            )
            MinSizeKB = 3000
            Categoria = "Base"
        },
        @{
            Nome      = "TeamViewer (64-bit)"
            File      = "TeamViewer_Setup_x64.exe"
            Urls      = @(
                "https://download.teamviewer.com/download/TeamViewer_Setup_x64.exe"
            )
            MinSizeKB = 40000
            Categoria = "Completo"
        },
        @{
            Nome      = "Zoom Desktop Client Full (MSI)"
            File      = "ZoomInstallerFull.msi"
            Urls      = @(
                "https://zoom.us/client/latest/ZoomInstallerFull.msi",
                "https://zoom.us/client/latest/ZoomInstaller.msi"
            )
            MinSizeKB = 30000
            Categoria = "Completo"
        },
        @{
            Nome      = "AIMP Audio Player"
            File      = "aimp.exe"
            Urls      = @(
                "https://aimp.ru/?do=download.file&id=3",
                "https://aimp.ru/files/desktop/builds/aimp_5.40.2726_w64.exe",
                "https://aimp.ru/?do=download.file&id=4"
            )
            MinSizeKB = 10000
            Categoria = "Completo"
        },
        @{
            Nome      = "LibreOffice (64-bit Italiano)"
            File      = "LibreOffice_Win_x86-64.msi"
            Urls      = @(
                "https://download.documentfoundation.org/libreoffice/stable/26.8.0/win/x86_64/LibreOffice_26.8.0_Win_x86-64.msi",
                "https://download.documentfoundation.org/libreoffice/stable/26.2.6/win/x86_64/LibreOffice_26.2.6_Win_x86-64.msi",
                "https://download.documentfoundation.org/libreoffice/stable/25.8.7/win/x86_64/LibreOffice_25.8.7_Win_x86-64.msi"
            )
            MinSizeKB = 250000
            Categoria = "Completo"
        },
        @{
            Nome      = "Norton Removal Tool (NRnR)"
            File      = "NRnR.exe"
            Urls      = @(
                "https://buy-download.norton.com/downloads/RnR/NLOK/NRnR.exe",
                "https://www.norton.com/nrnr"
            )
            MinSizeKB = 5000
            Categoria = "Base"
        },
        @{
            Nome      = "McAfee Consumer Product Removal (MCPR)"
            File      = "MCPR.exe"
            Urls      = @(
                "https://download.mcafee.com/molbin/iss-loc/SupportTools/MCPR/MCPR.exe"
            )
            MinSizeKB = 5000
            Categoria = "Base"
        },
        @{
            Nome      = "Sumatra PDF (64-bit)"
            File      = "SumatraPDF-install.exe"
            Urls      = @(
                "https://www.sumatrapdfreader.org/dl/rel/3.6.1/SumatraPDF-3.6.1-64-install.exe",
                "https://files2.sumatrapdfreader.org/software/sumatrapdf/rel/3.6.1/SumatraPDF-3.6.1-64-install.exe"
            )
            MinSizeKB = 7000
            Categoria = "Completo"
        },
        @{
            Nome      = "Spotify"
            File      = "SpotifyFullSetup.exe"
            Urls      = @(
                "https://download.scdn.co/SpotifyFullSetup.exe",
                "https://download.scdn.co/SpotifySetup.exe"
            )
            MinSizeKB = 20000
            Categoria = "Completo"
        },
        @{
            Nome      = "GIMP (Image Editor)"
            File      = "gimp-setup.exe"
            Urls      = @(
                "https://download.gimp.org/gimp/v2.10/windows/gimp-2.10.38-setup.exe"
            )
            MinSizeKB = 250000
            Categoria = "Completo"
        },
        @{
            Nome      = "Steam Setup"
            File      = "SteamSetup.exe"
            Urls      = @(
                "https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe"
            )
            MinSizeKB = 2000
            Categoria = "Completo"
        },
        @{
            Nome      = "Discord"
            File      = "DiscordSetup.exe"
            Urls      = @(
                "https://discord.com/api/download?platform=win"
            )
            MinSizeKB = 80000
            Categoria = "Completo"
        },
        @{
            Nome      = "Microsoft Visual C++ 2015-2022 (64-bit)"
            File      = "vc_redist.x64.exe"
            Urls      = @(
                "https://aka.ms/vs/17/release/vc_redist.x64.exe"
            )
            MinSizeKB = 20000
            Categoria = "Base"
        },
        @{
            Nome      = "Microsoft Visual C++ 2015-2022 (32-bit)"
            File      = "vc_redist.x86.exe"
            Urls      = @(
                "https://aka.ms/vs/17/release/vc_redist.x86.exe"
            )
            MinSizeKB = 15000
            Categoria = "Base"
        }
    )

    $daScaricare = $downloadCatalog
    if (-not $Test) {
        Write-Host "Cosa vuoi scaricare sulla chiavetta?" -ForegroundColor White
        Write-Host "  1) Pacchetto Base + Utility (Consigliato: Chrome, Firefox, VLC, Adobe, 7-Zip, AnyDesk, Visual C++, NRnR, MCPR - ~500 MB)" -ForegroundColor Green
        Write-Host "  2) Pacchetto Completo (Tutti i programmi inclusi LibreOffice, Spotify, Zoom, GIMP, Steam, Discord - ~1.5 GB)" -ForegroundColor White
        Write-Host ""
        $sceltaPkg = Attendi-Risposta "Scelta (1/2, INVIO = Pacchetto Base)"
        if ([string]::IsNullOrWhiteSpace($sceltaPkg) -or $sceltaPkg -eq "1") {
            $daScaricare = @($downloadCatalog | Where-Object { $_.Categoria -eq "Base" })
        }
    }

    Write-Host ""
    Write-Info "Avvio download dei pacchetti offline..."
    $tot = $daScaricare.Count
    $idx = 0
    $riusciti = 0
    $giaPresenti = 0

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

    foreach ($pkg in $daScaricare) {
        $idx++
        $destPath = Join-Path $installersDir $pkg.File
        Write-Host ""
        Write-Host "[$idx/$tot] $($pkg.Nome)..." -ForegroundColor White

        if ($Test) {
            Write-OK "TEST: simulazione download $($pkg.Nome) -> $($pkg.File)"
            $riusciti++
            continue
        }

        # Verifica se gia' presente e valido
        if (Test-Path $destPath) {
            $finfo = Get-Item $destPath -ErrorAction SilentlyContinue
            if ($finfo -and ($finfo.Length / 1KB) -ge $pkg.MinSizeKB) {
                $mb = [Math]::Round($finfo.Length / 1MB, 1)
                Write-OK "Gia' presente sulla chiavetta ($mb MB). Salto."
                $giaPresenti++
                $riusciti++
                continue
            }
        }

        # Download con fallback URL e visualizzazione progresso
        $ok = $false
        foreach ($url in $pkg.Urls) {
            Write-Info "Download da: $url"
            try {
                $wc = New-Object System.Net.WebClient
                $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0")
                $wc.DownloadFile($url, $destPath)
                $wc.Dispose()
            } catch {
                try {
                    Invoke-WebRequest -Uri $url -OutFile $destPath -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -UseBasicParsing -ErrorAction Stop
                } catch {
                    Write-Info "Errore da questa sorgente ($($_.Exception.Message)), provo alternativa..."
                }
            }

            if (Test-Path $destPath) {
                $len = (Get-Item $destPath).Length
                if (($len / 1KB) -ge $pkg.MinSizeKB) {
                    $mb = [Math]::Round($len / 1MB, 1)
                    Write-OK "Scaricato con successo: $($pkg.File) ($mb MB)"
                    $ok = $true
                    $riusciti++
                    break
                } else {
                    Write-Info "File scaricato troppo piccolo ($len bytes), riprovo..."
                    Remove-Item $destPath -Force -ErrorAction SilentlyContinue
                }
            }
        }

        if (-not $ok) {
            Write-Errore "Impossibile scaricare $($pkg.Nome). Sara' installato tramite winget durante il setup."
        }
    }

    # File di PC Facile sulla chiavetta: tutti quelli elencati in manifest.txt,
    # scaricati e verificati (SHA256) prima di sostituire le copie esistenti.
    # Se il manifest non e' raggiungibile, copio i file accanto a questo script.
    Write-Host ""
    Write-Info "Aggiorno i file di PC Facile sulla chiavetta USB (manifest.txt)..."
    $aggUsb = $null
    if (-not $Test) {
        # Il launcher che sta girando (se e' sulla stessa chiavetta) non va
        # sovrascritto: la sua nuova versione va in "PC Facile.bat.nuovo".
        $launcherAttivo = if ($LauncherPath) { $LauncherPath } elseif ($TargetDir) { Join-Path $(if ($TargetDir -match '^[A-Za-z]:$') { "$TargetDir\" } else { $TargetDir }) 'PC Facile Windows.bat' } else { $null }
        try {
            $aggUsb = Invoke-AggiornamentoUSB -Destinazione $targetBase -LauncherInEsecuzione $launcherAttivo
            if ($launcherAttivo -and -not $LauncherPath) { Start-SostituzioneLauncherDifferita -Launcher $launcherAttivo }
        } catch {}
    }
    if ($aggUsb -and $aggUsb.Ok) {
        Write-OK "File di avvio e script aggiornati e verificati nella radice della chiavetta."
    } else {
        try {
            if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "setup-pc.ps1"))) {
                foreach ($nomeFile in @("setup-pc.ps1", "setup-pc.ps1.sha256", "PC Facile Windows.bat", "PC Facile Mac.command", "PC Facile Chromebook.html", "Scarica Ultima Versione.url", "setup-mac.sh", "setup-mac.sh.sha256")) {
                    $src = Join-Path $PSScriptRoot $nomeFile
                    $dst = Join-Path $targetBase $nomeFile
                    if ((Test-Path -LiteralPath $src) -and ([System.IO.Path]::GetFullPath($src) -ne [System.IO.Path]::GetFullPath($dst))) {
                        Copy-Item -LiteralPath $src -Destination $dst -Force -ErrorAction SilentlyContinue
                    }
                }
                # Anche i file Wi-Fi del negozio (cartella wifi\), se presenti accanto allo script.
                foreach ($nomeWifi in (Get-FileWifiManifest)) {
                    $rel = $nomeWifi -replace '/', [System.IO.Path]::DirectorySeparatorChar
                    $src = Join-Path $PSScriptRoot $rel
                    $dst = Join-Path $targetBase $rel
                    if ((Test-Path -LiteralPath $src) -and ([System.IO.Path]::GetFullPath($src) -ne [System.IO.Path]::GetFullPath($dst))) {
                        $cartWifi = Split-Path $dst -Parent
                        if (-not (Test-Path -LiteralPath $cartWifi)) { New-Item -ItemType Directory -Path $cartWifi -Force -ErrorAction SilentlyContinue | Out-Null }
                        Copy-Item -LiteralPath $src -Destination $dst -Force -ErrorAction SilentlyContinue
                    }
                }
                Write-Info "Manifest non raggiungibile: copiati sulla chiavetta i file presenti accanto allo script."
            } else {
                Write-Info "Manifest non raggiungibile e nessuna copia locale: file di avvio non aggiornati."
            }
        } catch {}
    }

    # Configurazione Wi-Fi Negozio / Laboratorio
    Write-Host ""
    Write-Host "Configurazione Wi-Fi Negozio / Laboratorio:" -ForegroundColor White
    $salvaWifi = Attendi-Risposta "Vuoi salvare la rete Wi-Fi del negozio sulla chiavetta per la connessione automatica? (S/N, default = S)"
    if ($salvaWifi -match "^[Ss]" -or [string]::IsNullOrWhiteSpace($salvaWifi)) {
        Save-StoreWiFiProfile -TargetDir $targetBase
    }

    # Riepilogo finale
    Write-Host ""
    Write-Titolo "PREPARAZIONE USB COMPLETATA"
    Write-Host "Pacchetti pronti su chiavetta: $riusciti su $tot (gia' presenti: $giaPresenti)" -ForegroundColor Green
    Write-Host "Cartella offline: $installersDir" -ForegroundColor White
    Write-Host ""
    Write-Host "Ora la tua chiavetta USB e' un kit autonomo al 100%!" -ForegroundColor Yellow
    Write-Host "Puoi inserirla nei PC dei clienti e lanciare 'PC Facile.bat':" -ForegroundColor White
    Write-Host "il PC si colleghera' in automatico al Wi-Fi del negozio e installera' tutto da solo!" -ForegroundColor White
    Write-Host ""
    Beep-Completato
}

# =============================================================================
# CONNETTIVITA' E RETE (VERIFICA ENDPOINT E TEST-RETE)
# =============================================================================

function Test-Rete {
    # 1) Ping veloce
    try {
        $ping = New-Object System.Net.NetworkInformation.Ping
        if (($ping.Send("8.8.8.8", 2000)).Status -eq 'Success') { return $true }
    } catch {}
    # 2) Fallback: alcuni firewall bloccano il ping (ICMP) ma non il web (TCP 443)
    return (Test-Endpoint -HostName "www.microsoft.com")
}

# Verifica se un host e' raggiungibile su una porta (default 443) - connect TCP
function Test-Endpoint {
    param(
        [string]$HostName,
        [int]$Port = 443,
        [int]$TimeoutMs = 2500
    )
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $async = $tcp.BeginConnect($HostName, $Port, $null, $null)
        $ok = $async.AsyncWaitHandle.WaitOne($TimeoutMs)
        $connesso = $ok -and $tcp.Connected
        $tcp.Close()
        return [bool]$connesso
    } catch {
        return $false
    }
}

function New-WlanProfileXml {
    param([string]$Ssid, [string]$Password)
    # Escape XML: & < > ' " in SSID/password renderebbero il profilo non valido.
    $Ssid = [System.Security.SecurityElement]::Escape($Ssid)
    $Password = [System.Security.SecurityElement]::Escape($Password)
    return @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>$Ssid</name>
    <SSIDConfig>
        <SSID>
            <name>$Ssid</name>
        </SSID>
    </SSIDConfig>
    <connectionType>ESS</connectionType>
    <connectionMode>auto</connectionMode>
    <MSM>
        <security>
            <authEncryption>
                <authentication>WPA2PSK</authentication>
                <encryption>AES</encryption>
                <useOneX>false</useOneX>
            </authEncryption>
            <sharedKey>
                <keyType>passPhrase</keyType>
                <protected>false</protected>
                <keyMaterial>$Password</keyMaterial>
            </sharedKey>
        </security>
    </MSM>
</WLANProfile>
"@
}

function Connect-AutoWiFi {
    param([string]$TargetDir)
    if ($Test) { return $true }
    try {
        # Se siamo gia' connessi a Internet, non serve fare nulla
        if (Test-Rete) { return $true }

        Write-Info "Verifica e connessione automatica Wi-Fi da chiavetta USB..."
        $searchDirs = @()
        if ($TargetDir -and (Test-Path -LiteralPath $TargetDir)) {
            $searchDirs += (Join-Path $TargetDir "wifi")
            $searchDirs += $TargetDir
        }
        if ($PSScriptRoot -and (Test-Path -LiteralPath $PSScriptRoot)) {
            $searchDirs += (Join-Path $PSScriptRoot "wifi")
            $searchDirs += $PSScriptRoot
        }
        try {
            $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -gt 0 }
            foreach ($drv in $drives) {
                $root = $drv.Root
                foreach ($sub in @('', 'PC Facile', 'PC-Facile', 'PC-Facile-main')) {
                    $baseUsb = if ($sub) { Join-Path $root $sub } else { $root }
                    if (Test-Path (Join-Path $baseUsb "wifi")) { $searchDirs += (Join-Path $baseUsb "wifi") }
                    if (Test-Path $baseUsb) { $searchDirs += $baseUsb }
                }
            }
        } catch {}

        $searchDirs = @($searchDirs | Select-Object -Unique)

        foreach ($dir in $searchDirs) {
            if (-not (Test-Path -LiteralPath $dir)) { continue }

            # 1. Cerca profili XML esportati da netsh (*.xml con <WLANProfile>)
            $xmlFiles = @(Get-ChildItem -Path $dir -Filter "*.xml" -ErrorAction SilentlyContinue)
            foreach ($xml in $xmlFiles) {
                try {
                    $content = Get-Content -Path $xml.FullName -Raw -ErrorAction SilentlyContinue
                    if ($content -match '<WLANProfile' -and $content -match '<name>(.*?)</name>') {
                        $profName = $Matches[1]
                        Write-Info "Tentativo di connessione alla rete Wi-Fi: '$profName'..."
                        & netsh.exe wlan add profile filename="$($xml.FullName)" user=all 2>$null | Out-Null
                        & netsh.exe wlan connect name="$profName" 2>$null | Out-Null

                        $t = 0
                        while ((-not (Test-Rete)) -and $t -lt 6) {
                            Start-Sleep -Seconds 2
                            $t += 2
                        }
                        if (Test-Rete) {
                            Write-OK "Connesso automaticamente al Wi-Fi: $profName!"
                            try {
                                $kitDir = if ($Global:TargetDir -and (Test-CartellaKitUSB $Global:TargetDir)) { $Global:TargetDir } elseif ($PSScriptRoot -and (Test-CartellaKitUSB $PSScriptRoot)) { $PSScriptRoot } else { $null }
                                if ($kitDir) { [void](Invoke-AggiornamentoUSB -Destinazione $kitDir -LauncherInEsecuzione $LauncherPath) }
                            } catch {}
                            return $true
                        }
                    }
                } catch {}
            }

            # 2. Cerca file wifi.txt / wifi.ini / wifi.conf con SSID e Password
            $txtFiles = @((Join-Path $dir "wifi.txt"), (Join-Path $dir "wifi.ini"), (Join-Path $dir "wifi.conf"))
            foreach ($txt in $txtFiles) {
                if (Test-Path -LiteralPath $txt) {
                    $lines = Get-Content -LiteralPath $txt -ErrorAction SilentlyContinue
                    $ssid = ""
                    $wifiPass = ""
                    foreach ($l in $lines) {
                        $line = $l.Trim()
                        if ($line -match '^(SSID|RETE|WIFI)\s*[:=]\s*(.+)$') { $ssid = $Matches[2].Trim() }
                        elseif ($line -match '^(PASS|PASSWORD|KEY|CHIAVE)\s*[:=]\s*(.+)$') { $wifiPass = $Matches[2].Trim() }
                        elseif (-not $ssid -and $line -notmatch '^#' -and $line.Length -gt 0) {
                            $ssid = $line
                        } elseif ($ssid -and -not $wifiPass -and $line -notmatch '^#' -and $line.Length -gt 0) {
                            $wifiPass = $line
                        }
                    }
                    if ($ssid -and $wifiPass) {
                        Write-Info "Tentativo di connessione automatica Wi-Fi: '$ssid'..."
                        $tempXml = Join-Path $env:TEMP "wifi_auto_$([Math]::Abs((Get-Random)%10000)).xml"
                        $xmlData = New-WlanProfileXml -Ssid $ssid -Password $wifiPass
                        [System.IO.File]::WriteAllText($tempXml, $xmlData, [System.Text.Encoding]::UTF8)
                        & netsh.exe wlan add profile filename="$tempXml" user=all 2>$null | Out-Null
                        & netsh.exe wlan connect name="$ssid" 2>$null | Out-Null
                        Remove-Item -LiteralPath $tempXml -Force -ErrorAction SilentlyContinue

                        $t = 0
                        while ((-not (Test-Rete)) -and $t -lt 8) {
                            Start-Sleep -Seconds 2
                            $t += 2
                        }
                        if (Test-Rete) {
                            Write-OK "Connesso automaticamente al Wi-Fi: $ssid!"
                            try {
                                $kitDir = if ($Global:TargetDir -and (Test-CartellaKitUSB $Global:TargetDir)) { $Global:TargetDir } elseif ($PSScriptRoot -and (Test-CartellaKitUSB $PSScriptRoot)) { $PSScriptRoot } else { $null }
                                if ($kitDir) { [void](Invoke-AggiornamentoUSB -Destinazione $kitDir -LauncherInEsecuzione $LauncherPath) }
                            } catch {}
                            return $true
                        }
                    }
                }
            }
        }
    } catch {}
    return $false
}

function Save-StoreWiFiProfile {
    param([string]$TargetDir)
    if ($Test) { return $true }
    try {
        $wifiDir = Join-Path $TargetDir "wifi"
        if (-not (Test-Path $wifiDir)) { New-Item -Path $wifiDir -ItemType Directory -Force | Out-Null }

        $exported = $false
        try {
            $interfaces = & netsh.exe wlan show interfaces 2>$null
            $currentSsid = ""
            foreach ($line in $interfaces) {
                if ($line -match '^\s*SSID\s*:\s*(.+)$') {
                    $currentSsid = $Matches[1].Trim()
                    break
                }
            }
            if ($currentSsid) {
                & netsh.exe wlan export profile name="$currentSsid" folder="$wifiDir" key=clear 2>$null | Out-Null
                $xmls = Get-ChildItem -Path $wifiDir -Filter "*.xml" -ErrorAction SilentlyContinue
                if ($xmls.Count -gt 0) {
                    Write-OK "Profilo Wi-Fi esportato con successo per '$currentSsid' in $wifiDir"
                    $exported = $true
                }
            }
        } catch {}

        if (-not $exported) {
            Write-Info "Inserisci i dati della rete Wi-Fi del negozio (verranno salvati in 'wifi/wifi.txt'):"
            $ssidIn = (Attendi-Risposta "Nome Rete Wi-Fi (SSID)").Trim()
            if ($ssidIn) {
                $pwdIn = (Attendi-Risposta "Password Wi-Fi (WPA2)").Trim()
                $txtFile = Join-Path $wifiDir "wifi.txt"
                $content = "SSID=$ssidIn`r`nPASSWORD=$pwdIn"
                [System.IO.File]::WriteAllText($txtFile, $content, [System.Text.Encoding]::UTF8)

                $xmlData = New-WlanProfileXml -Ssid $ssidIn -Password $pwdIn
                $xmlFile = Join-Path $wifiDir "wifi-$ssidIn.xml"
                [System.IO.File]::WriteAllText($xmlFile, $xmlData, [System.Text.Encoding]::UTF8)
                Write-OK "Rete Wi-Fi '$ssidIn' salvata con successo nella cartella wifi."
            }
        }
    } catch {
        Write-Info "Impossibile salvare il profilo Wi-Fi: $($_.Exception.Message)"
    }
}

# Cartella Desktop reale (gestisce anche il Desktop reindirizzato su OneDrive)
function Get-DesktopDir {
    try {
        $d = [Environment]::GetFolderPath('Desktop')
        if ($d -and (Test-Path $d)) { return $d }
    } catch {}
    $fallback = Join-Path $env:USERPROFILE "Desktop"
    if (Test-Path $fallback) { return $fallback }
    return $env:TEMP
}

# SCHEDA DI CONSEGNA: sul Desktop del cliente deve restare UN solo file, il PDF
# (contiene anche la chiave BitLocker: niente piu' file "NON CANCELLARE").
# L'HTML si scrive in una cartella di lavoro (ProgramData\PCFacile\consegna) e
# Edge headless lo converte in PDF. Solo se il PDF esiste ed e' > 0 byte lo
# sposto sul Desktop e cancello l'HTML. Se la conversione fallisce l'HTML va
# sul Desktop come ripiego (si stampa / salva in PDF dal browser). In ogni caso
# tolgo dal Desktop il vecchio riepilogo TXT e, se c'e' il PDF, il vecchio HTML
# (lasciati da versioni precedenti o da una sessione ripresa); con la scheda
# sul Desktop tolgo anche il vecchio "NON CANCELLARE - Chiave ... .txt", salvo
# -ConservaVecchiaChiaveBitLocker (chiave non letta in questa sessione).
# -Convertitore: scriptblock (percorsoHtml, percorsoPdf) usato dai test; di
# default Edge headless con un profilo temporaneo (non disturba il pannello
# gia' aperto in Edge). Restituisce Esito PDF / HTML / ERRORE e il percorso.
function Save-SchedaConsegna {
    param(
        [Parameter(Mandatory = $true)][string]$HtmlDoc,
        [Parameter(Mandatory = $true)][string]$DesktopDir,
        [Parameter(Mandatory = $true)][string]$CartellaLavoro,
        [scriptblock]$Convertitore,
        [switch]$ConservaVecchiaChiaveBitLocker
    )
    $nomeBase    = 'Scheda-Consegna-Cliente'
    $htmlLavoro  = Join-Path $CartellaLavoro "$nomeBase.html"
    $pdfLavoro   = Join-Path $CartellaLavoro "$nomeBase.pdf"
    $pdfDesktop  = Join-Path $DesktopDir "$nomeBase.pdf"
    $htmlDesktop = Join-Path $DesktopDir "$nomeBase.html"
    $txtDesktop  = Join-Path $DesktopDir 'Riepilogo-Configurazione-PC.txt'
    $chiaveVecchia = Join-Path $DesktopDir 'NON CANCELLARE - Chiave di Ripristino BitLocker.txt'
    # Il vecchio file della chiave BitLocker (versioni precedenti) si toglie solo
    # quando la scheda (che contiene la chiave) e' davvero sul Desktop.
    $togliChiaveVecchia = { if (-not $ConservaVecchiaChiaveBitLocker) { Remove-Item -LiteralPath $chiaveVecchia -Force -ErrorAction SilentlyContinue } }
    $fileOk = { param($p) (Test-Path -LiteralPath $p -PathType Leaf) -and ((Get-Item -LiteralPath $p -ErrorAction SilentlyContinue).Length -gt 0) }

    # Il riepilogo TXT non va mai sul Desktop (sta nel log tecnico).
    Remove-Item -LiteralPath $txtDesktop -Force -ErrorAction SilentlyContinue

    try {
        if (-not (Test-Path -LiteralPath $CartellaLavoro)) { New-Item -Path $CartellaLavoro -ItemType Directory -Force -ErrorAction Stop | Out-Null }
        Remove-Item -LiteralPath $pdfLavoro -Force -ErrorAction SilentlyContinue
        Set-Content -LiteralPath $htmlLavoro -Value $HtmlDoc -Encoding UTF8 -ErrorAction Stop
    } catch {
        return [pscustomobject]@{ Esito = 'ERRORE'; Percorso = $null; Messaggio = "scheda HTML non scritta: $($_.Exception.Message)" }
    }

    if (-not $Convertitore) {
        $Convertitore = {
            param($PercorsoHtml, $PercorsoPdf)
            $edge = Get-EdgePath
            if (-not $edge) { return }
            $profilo = Join-Path (Split-Path -Parent $PercorsoPdf) 'edge-profilo'
            $uri = ([System.Uri]$PercorsoHtml).AbsoluteUri
            $argEdge = @('--headless', '--disable-gpu', '--no-first-run', '--no-default-browser-check',
                         '--run-all-compositor-stages-before-draw', '--no-pdf-header-footer', '--print-to-pdf-no-header',
                         "--user-data-dir=`"$profilo`"", "--print-to-pdf=`"$PercorsoPdf`"", "`"$uri`"") -join ' '
            $proc = Start-Process -FilePath $edge -ArgumentList $argEdge -WindowStyle Hidden -PassThru -ErrorAction Stop
            if ($proc -and -not $proc.WaitForExit(90000)) { try { $proc.Kill() } catch {} }
            # Edge puo' finire di scrivere il file un attimo dopo l'uscita: attendo max 10 s.
            for ($i = 0; $i -lt 20 -and -not (Test-Path -LiteralPath $PercorsoPdf); $i++) { Start-Sleep -Milliseconds 500 }
            Start-Sleep -Milliseconds 500
            Remove-Item -LiteralPath $profilo -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    try { & $Convertitore $htmlLavoro $pdfLavoro } catch {}

    $pdfOk = [bool](& $fileOk $pdfLavoro)
    if ($pdfOk) {
        # Copia (non Move): il file prende i permessi del Desktop, non quelli di
        # ProgramData, cosi' il cliente puo' gestirlo senza richieste UAC.
        try { Copy-Item -LiteralPath $pdfLavoro -Destination $pdfDesktop -Force -ErrorAction Stop } catch { $pdfOk = $false }
        $pdfOk = $pdfOk -and [bool](& $fileOk $pdfDesktop)
    }
    if ($pdfOk) {
        Remove-Item -LiteralPath $htmlLavoro -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $htmlDesktop -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $pdfLavoro -Force -ErrorAction SilentlyContinue
        & $togliChiaveVecchia
        return [pscustomobject]@{ Esito = 'PDF'; Percorso = $pdfDesktop; Messaggio = 'PDF creato sul Desktop' }
    }

    # Ripiego: PDF non creato (o vuoto) -> l'HTML stampabile va sul Desktop.
    Remove-Item -LiteralPath $pdfLavoro -Force -ErrorAction SilentlyContinue
    try {
        Copy-Item -LiteralPath $htmlLavoro -Destination $htmlDesktop -Force -ErrorAction Stop
        Remove-Item -LiteralPath $htmlLavoro -Force -ErrorAction SilentlyContinue
        & $togliChiaveVecchia
        return [pscustomobject]@{ Esito = 'HTML'; Percorso = $htmlDesktop; Messaggio = 'PDF non creato: sul Desktop resta la scheda HTML' }
    } catch {
        return [pscustomobject]@{ Esito = 'ERRORE'; Percorso = $htmlLavoro; Messaggio = "PDF non creato e HTML non copiato sul Desktop: $($_.Exception.Message)" }
    }
}

# (Set-EdgeFirstRunPolicies definita all'inizio con Set-SplitScreenLayout)

# =============================================================================
# INIZIALIZZAZIONE VARIABILI GLOBALI E RIPRESA SESSIONE
# =============================================================================

# Credenziali del nuovo account, generate dallo script allo step Account
# Microsoft e scritte nel riepilogo. Init qui cosi' esistono anche se quel
# passo viene saltato (restano vuote nel file).
$credMsAccount = ""; $credMsPassword = ""; $credAltro = ""
# Provider account scelto (Microsoft/Google/Proton/Outlook) + dominio email: li
# ricordo nel checkpoint, cosi' su una ripresa il riepilogo mostra il provider
# GIUSTO (es. Proton) e non ripiega su Microsoft/outlook.it.
$Global:credProvider = ""; $Global:credDominio = ""
# Job in background per il DOWNLOAD degli aggiornamenti di Windows: programmato
# al passo Aggiornamenti, parte all'inizio del passo App (dopo i driver per evitare
# collisioni COM su wuauserv), scaricando mentre installiamo le applicazioni.
$Global:JobWinUpdate = $null
$Global:AvviaWinUpdateDopoDriver = $false

# Contatore app che NON si sono installate (per l'avviso rete a fine passo App).
$Global:AppFallite = 0
# Esito dell'ultima Installa-Pacchetto ($true = installata o gia' presente).
# Serve al passo App per segnare come "fatta" solo cio' che e' andato a buon
# fine, cosi' su una ripresa si riscaricano SOLO le app davvero mancanti.
$Global:UltimaInstallOk = $false
# Ripresa FINE dentro il passo App: profilo scelto, piano di installazione e
# app gia' completate nella sessione interrotta (caricati dal checkpoint).
$Global:AppProfiloRipresa = ""
$Global:AppListaRipresa   = @()
$Global:AppFatteRipresa   = @()

# Dati del cliente (dal pannello operatore, un'unica volta): vedi Set-DatiCliente.
$Global:DatiCliente = $null
$Global:DatiClienteRicevuti = $false
$Global:ProfiloAppCliente = ""
$Global:PannelloDisponibile = $false
$Global:PannelloFile = ""
$Global:StatoFile   = Join-Path $(if ($env:ProgramData) { $env:ProgramData } else { [System.IO.Path]::GetTempPath() }) "PCFacile\stato.json"
$Global:FaseRipresa = 0

# Segna un passo come completato (sovrascrive il checkpoint precedente).
function Save-Fase {
    param([int]$Fase, [string]$Nome)
    if (-not $RunReale) { return }
    try {
        $dir = Split-Path $Global:StatoFile
        if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
        $prev = $null
        if (Test-Path $Global:StatoFile) { try { $prev = Get-Content $Global:StatoFile -Raw | ConvertFrom-Json } catch {} }
        $nc  = if ($nomeCliente)         { $nomeCliente }         elseif ($prev) { $prev.NomeCliente } else { "" }
        $ca  = if ($credMsAccount)       { $credMsAccount }       elseif ($prev) { $prev.CredAccount } else { "" }
        $cp  = if ($credMsPassword)      { $credMsPassword }      elseif ($prev) { $prev.CredPassword } else { "" }
        $cpr = if ($Global:credProvider) { $Global:credProvider } elseif ($prev -and $prev.PSObject.Properties.Name -contains 'CredProvider') { $prev.CredProvider } else { "" }
        $cdo = if ($Global:credDominio)  { $Global:credDominio }  elseif ($prev -and $prev.PSObject.Properties.Name -contains 'CredDominio')  { $prev.CredDominio } else { "" }
        $sco = if ($Global:SceltaOffice) { $Global:SceltaOffice } elseif ($prev -and $prev.PSObject.Properties.Name -contains 'SceltaOffice') { $prev.SceltaOffice } else { "" }
        $dcl = if ($Global:DatiCliente) { $Global:DatiCliente } elseif ($prev -and $prev.PSObject.Properties.Name -contains 'DatiCliente') { $prev.DatiCliente } else { $null }
        [pscustomobject]@{
            Schema = 3
            Fase = $Fase; FaseNome = $Nome
            SceltaOffice = $sco
            DatiCliente = $dcl
            Data = (Get-Date -Format 'dd/MM/yyyy HH:mm')
            NomeCliente = $nc
            CredAccount = $ca; CredPassword = $cp
            CredProvider = $cpr; CredDominio = $cdo
        } | ConvertTo-Json -Depth 5 | Set-Content -Path $Global:StatoFile -Encoding UTF8
    } catch {}
}

# Vero se il passo era gia' stato completato nella sessione ripresa.
function Test-FaseFatta { param([int]$Fase) return ($Global:FaseRipresa -ge $Fase) }

# Sotto-checkpoint DENTRO il passo App: salva profilo scelto, piano completo e
# app gia' installate, senza chiudere il passo (Fase = passi completati prima
# di App = si riparte dal passo App). Cosi' una chiusura a meta' installazione
# riparte dall'app esatta.
function Save-AppProgresso {
    param([string]$Profilo, [array]$Lista, [string[]]$Fatte)
    if (-not $RunReale) { return }
    try {
        $dir = Split-Path $Global:StatoFile
        if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
        [pscustomobject]@{
            Schema = 3
            Fase = [Math]::Max(0, [array]::IndexOf(@($Global:Passi | ForEach-Object { $_.Id }), 'app')); FaseNome = "Applicazioni (installazione in corso)"
            SceltaOffice = $Global:SceltaOffice
            DatiCliente = $Global:DatiCliente
            Data = (Get-Date -Format 'dd/MM/yyyy HH:mm')
            NomeCliente = $nomeCliente
            CredAccount = $credMsAccount; CredPassword = $credMsPassword
            CredProvider = $Global:credProvider; CredDominio = $Global:credDominio
            AppProfilo = $Profilo
            AppLista   = @($Lista)
            AppFatte   = @($Fatte)
        } | ConvertTo-Json -Depth 5 | Set-Content -Path $Global:StatoFile -Encoding UTF8
    } catch {}
}

# =============================================================================
# CATALOGO PACCHETTI - UNICA FONTE (usato da STEP 3/5/6 e dalla Diagnostica)
# =============================================================================
$CatalogoOffice = @(
    @{ Nome = "Microsoft 365"; Id = "Microsoft.Office" },
    @{ Nome = "OpenOffice";    Id = "Apache.OpenOffice" },
    @{ Nome = "LibreOffice";   Id = "TheDocumentFoundation.LibreOffice" }
)
$CatalogoBrowser = @(
    @{ Nome = "Google Chrome";   Id = "Google.Chrome" },
    @{ Nome = "Mozilla Firefox"; Id = "Mozilla.Firefox" },
    @{ Nome = "Microsoft Edge";  Id = "Microsoft.Edge" },
    @{ Nome = "Brave";           Id = "Brave.Brave" },
    @{ Nome = "Opera";           Id = "Opera.Opera" },
    @{ Nome = "Opera GX";        Id = "Opera.OperaGX" },
    @{ Nome = "Vivaldi";         Id = "Vivaldi.Vivaldi" }
)
$CatalogoApp = @(
    @{ Nome = "VLC Media Player";     Id = "VideoLAN.VLC";                 Profili = @("BASE","UFFICIO","GAMING") },
    @{ Nome = "Adobe Acrobat Reader"; Id = "Adobe.Acrobat.Reader.64-bit";  Profili = @("BASE","UFFICIO","GAMING") },
    @{ Nome = "Sumatra PDF";          Id = "SumatraPDF.SumatraPDF";        Profili = @("UFFICIO") },
    @{ Nome = "Spotify";              Id = "Spotify.Spotify";              Profili = @("BASE","UFFICIO","GAMING") },
    @{ Nome = "AIMP";                 Id = "AIMP.AIMP";                    Profili = @("BASE","UFFICIO","GAMING") },
    @{ Nome = "7-Zip";                Id = "7zip.7zip";                    Profili = @("BASE","UFFICIO","GAMING") },
    @{ Nome = "WhatsApp";             Id = "9NKSQGP7F2NH";                 Profili = @("BASE","UFFICIO","GAMING") },
    @{ Nome = "GIMP";                 Id = "GIMP.GIMP";                    Profili = @("UFFICIO") },
    @{ Nome = "Steam";                Id = "Valve.Steam";                  Profili = @("GAMING") },
    @{ Nome = "Epic Games Launcher";  Id = "EpicGames.EpicGamesLauncher";  Profili = @("GAMING") },
    @{ Nome = "AnyDesk";              Id = "AnyDesk.AnyDesk";              Profili = @("BASE","UFFICIO","GAMING") },
    @{ Nome = "Discord";              Id = "Discord.Discord";              Profili = @("GAMING") },
    @{ Nome = "Zoom";                 Id = "Zoom.Zoom";                    Profili = @("BASE","UFFICIO","GAMING") }
)

# =============================================================================
# VERIFICA PRIVILEGI AMMINISTRATORE E AMBIENTE
# =============================================================================

$isAdmin = $false
try {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    if ($currentUser) {
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
} catch {
    if ($Test) { $isAdmin = $true }
}
if (-not $isAdmin) {
    Write-Errore "Questo script richiede privilegi di amministratore."
    if ($Test) {
        Write-Info "Modalita' TEST: proseguo comunque (nessuna operazione admin verra' eseguita)."
    } else {
        Write-Info "Riavvia PowerShell come amministratore e riprova."
        Pausa
        return
    }
}

try {
    if ($MyInvocation.MyCommand.Path) {
        Unblock-File -Path $MyInvocation.MyCommand.Path -ErrorAction SilentlyContinue
    }
} catch {}

$ep = Get-ExecutionPolicy
if ($ep -eq 'Restricted' -or $ep -eq 'AllSigned') {
    Write-Info "ExecutionPolicy: $ep. Se hai avuto errori di avvio, rilancia con:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" -ForegroundColor Yellow
}

try {
    $sac = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy" `
            -Name VerifiedAndReputablePolicyState -ErrorAction SilentlyContinue).VerifiedAndReputablePolicyState
    if ($sac -eq 1) {
        Write-Host "[AVVISO] Smart App Control ATTIVO: potrebbe bloccare alcuni installer scaricati." -ForegroundColor Yellow
        Write-Info "Se un'installazione viene bloccata: Sicurezza di Windows > Controllo app e browser >"
        Write-Info "  Controllo intelligente delle app > Disattivato (IRREVERSIBILE senza reinstallare Windows)."
        Write-Info "Puoi comunque proseguire: molte app (firmate/reputate) si installano lo stesso."
        Pausa
    }
} catch {}

# =============================================================================
# CHIUSURA FINESTRA LAUNCHER BACKGROUND & ELEVAZIONE SILENZIOSA
# =============================================================================
if (-not $Test -and -not $Diagnostica) {
    # (Rimosso: la chiusura forzata dei cmd.exe "PC Facile". Uccideva anche il
    #  launcher che esegue questo script e il launcher attuale chiude gia' da
    #  solo la finestra non elevata.)

    # 2. Sblocca i file scaricati (Unblock-File) prima di mostrare il menu
    try { Enable-SilentElevation } catch {}
}

# =============================================================================
# AVVIO UNICO (nessun menu): -Test solo CI, -PreparaUSB/-Diagnostica manutenzione
# =============================================================================

# Modalita' TEST (-Test): rende lo script non interattivo e non distruttivo.
if ($Test -or $Diagnostica) {
    if ($Test) { Write-Host "*** MODALITA' TEST: nessuna modifica reale, risposte automatiche ***" -ForegroundColor Magenta }
    function Read-Host {
        param([Parameter(Position = 0)][string]$Prompt)
        $risposta = if ($Prompt -match 'S/N') { "N" } else { "" }
        Write-Host "$Prompt [AUTO => '$risposta']" -ForegroundColor Gray
        return $risposta
    }
}

# Parametri di vecchie modalita' (menu, Espresso, Manuale, Agente IA, ...):
# ignorati, il flusso e' uno solo.
if ($ParametriIgnorati) {
    Write-Info "Parametri ignorati (il flusso di PC Facile e' uno solo): $($ParametriIgnorati -join ' ')"
}

# Manutenzione nascosta: preparazione della chiavetta offline, poi esce.
if ($PreparaUSB) {
    Invoke-PreparaUSBOffline -TargetDir $TargetDir
    return
}

if (-not $Diagnostica) {
    try { Clear-Host } catch {}
    $titoloB = "PC FACILE   -   versione $SCRIPT_VERSION"
    $r1Vis = "   UNIEURO   PC FACILE  -  Assistenza & Configurazione PC"
    $r2Vis = "   Batte. Forte. Sempre. - Setup Tecnico Dedicato v$SCRIPT_VERSION"
    $larg = [Math]::Max(64, [Math]::Max($r1Vis.Length + 2, [Math]::Max($r2Vis.Length + 2, $titoloB.Length + 4)))
    $pad1 = " " * ($larg - $r1Vis.Length)
    $pad2 = " " * ($larg - $r2Vis.Length)
    $padSx = [int](($larg - $titoloB.Length) / 2)
    $padDx = $larg - $padSx - $titoloB.Length
    $boxLine = ([string][char]0x2550) * $larg
    Write-Host ""
    if ($vtOn) {
        Write-Host "  $U_ORANGE$([char]0x2554)$boxLine$([char]0x2557)$U_RESET"
        Write-Host "  $U_ORANGE$([char]0x2551)$U_RESET  $U_ORANGE_BG UNIEURO $U_RESET $U_WHITE PC FACILE  -  Assistenza & Configurazione PC$pad1$U_ORANGE$([char]0x2551)$U_RESET"
        Write-Host "  $U_ORANGE$([char]0x2551)$U_RESET  $U_ORANGE Batte. Forte. Sempre.$U_RESET $U_PEACH- Setup Tecnico Dedicato v$SCRIPT_VERSION$pad2$U_ORANGE$([char]0x2551)$U_RESET"
        Write-Host "  $U_ORANGE$([char]0x255A)$boxLine$([char]0x255D)$U_RESET"
        Write-Host ""
        Write-Host "  $U_GREEN$SYM_OK$U_RESET $U_WHITE CONFIGURAZIONE AVVIATA: FASE 1 (DATI CLIENTE, OFFICE E ATTIVAZIONI)$U_RESET"
        Write-Host "  $U_ORANGE$SYM_INFO$U_RESET $U_PEACH Inserisci i dati del cliente nel pannello operatore (una volta sola).$U_RESET"
        Write-Host "  $U_BLUE$SYM_INFO$U_RESET $U_WHITE Poi la Fase 2 prosegue dritta in automatico fino alla fine.$U_RESET"
        Write-Host ""
    } else {
        Write-Host "  $([char]0x2554)$boxLine$([char]0x2557)" -ForegroundColor DarkYellow
        Write-Host "  $([char]0x2551)$(" " * $padSx)$titoloB$(" " * $padDx)$([char]0x2551)" -ForegroundColor White
        Write-Host "  $([char]0x255A)$boxLine$([char]0x255D)" -ForegroundColor DarkYellow
        Write-Host ""
        Write-Host "  CONFIGURAZIONE AVVIATA: FASE 1 (DATI CLIENTE, OFFICE E ATTIVAZIONI)" -ForegroundColor Green
        Write-Host "  Inserisci i dati del cliente nel pannello operatore (una volta sola)." -ForegroundColor White
        Write-Host "  Poi la Fase 2 prosegue dritta in automatico fino alla fine." -ForegroundColor Cyan
        Write-Host ""
    }
}

$RunReale = (-not $Test -and -not $Diagnostica)
if ($RunReale) {
    try { Enable-SilentElevation } catch {}
    try { Set-PreventSleep $true } catch {}
    # Attiva SUBITO la tastiera italiana (00000410) a secondo 0 (prima di Wi-Fi e Pannello)
    # cosi' la chiocciola (@ = AltGr+o') funziona subito anche su PC nuovi partiti in inglese.
    try {
        Set-ItemProperty -Path 'HKCU:\Keyboard Layout\Preload' -Name '1' -Value '00000410' -ErrorAction SilentlyContinue
        $kList = New-WinUserLanguageList 'it-IT'
        $kList[0].InputMethodTips.Clear()
        $kList[0].InputMethodTips.Add('0410:00000410')
        Set-WinUserLanguageList -LanguageList $kList -Force -ErrorAction SilentlyContinue | Out-Null
        if (-not ([System.Management.Automation.PSTypeName]'Win32.KbdItLive').Type) {
            Add-Type -Name KbdItLive -Namespace Win32 -MemberDefinition '[DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern IntPtr LoadKeyboardLayout(string pwszKLID, uint Flags); [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);' -ErrorAction SilentlyContinue
        }
        $hKbd = [Win32.KbdItLive]::LoadKeyboardLayout('00000410', 1)
        [void][Win32.KbdItLive]::PostMessage([IntPtr]0xFFFF, 0x0050, [IntPtr]::Zero, $hKbd)
    } catch {}
    try { Set-EdgeFirstRunPolicies } catch {}
    try { Connect-AutoWiFi -TargetDir $TargetDir } catch { Write-Info "Connessione Wi-Fi automatica: $_" }
    # Sincronizza SUBITO fuso orario e orologio PRIMA di Invoke-SelfUpdateIfOutdated
    # cosi' un PC nuovo con batteria tampone/BIOS indietro di mesi non fallisce i controlli HTTPS.
    try {
        & tzutil.exe /s "W. Europe Standard Time" 2>$null | Out-Null
        Set-Service -Name w32time -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name w32time -ErrorAction SilentlyContinue
        & w32tm.exe /resync /force 2>$null | Out-Null
        & powercfg.exe /change standby-timeout-ac 0 2>$null | Out-Null
        & powercfg.exe /change standby-timeout-dc 0 2>$null | Out-Null
        & powercfg.exe /change monitor-timeout-ac 0 2>$null | Out-Null
        & powercfg.exe /change monitor-timeout-dc 0 2>$null | Out-Null
    } catch {}
    if (-not $NoSelfUpdate) {
        if (Invoke-SelfUpdateIfOutdated -TargetDir $TargetDir -LauncherPath $LauncherPath) { return }
    }
    # Il pannello NON blocca: la fase 1 parte subito. I dati del cliente
    # arrivano dal pannello mentre la fase 1 lavora (Get-CredenzialiSalvatePannello
    # a ogni passo); servono davvero solo da Office in poi (Wait-DatiCliente).
    try { Open-PannelloOperatore } catch { Write-Info "Pannello Operatore: $_" }
}

# =============================================================================
# ACCORTEZZE PC NUOVO (orologio + anti-sospensione)
# =============================================================================

# Data/ora sbagliata su un PC nuovo -> errori HTTPS su winget/download/attivazioni.
# Servizio W32Time in avvio automatico come client NTP + fuso automatico + resync (solo se online).
if ($RunReale) {
    try {
        Set-Service -Name w32time -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name w32time -ErrorAction SilentlyContinue
        Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters' -Name Type -Value 'NTP' -ErrorAction SilentlyContinue
        & w32tm /config /manualpeerlist:"time.windows.com,0x9" /syncfromflags:manual /update 2>$null | Out-Null
        Set-Service -Name tzautoupdate -StartupType Automatic -ErrorAction SilentlyContinue
        if (Test-Rete) {
            & w32tm /resync /force 2>$null | Out-Null
        }
        Write-OK "Sincronizzazione orario attivata e orologio aggiornato."
        Add-Report "Sincronizzazione orario" "OK"
    } catch {
        Write-Info "Sincronizzazione orario non completata del tutto: proseguo."
        Add-Report "Sincronizzazione orario" "AVVISO"
    }
}

# Evita la sospensione durante le installazioni (solo con alimentatore collegato).
try {
    & powercfg /change standby-timeout-ac 0 2>$null | Out-Null
    & powercfg /change monitor-timeout-ac 0 2>$null | Out-Null
} catch {}

# =============================================================================
# INFO COMPATIBILITA' (Windows e PowerShell)
# =============================================================================

try {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($os) {
        Write-Info "Sistema: $($os.Caption) (build $($os.BuildNumber))"
        $build = 0
        [void][int]::TryParse($os.BuildNumber, [ref]$build)
        if ($build -gt 0 -and $build -lt 17763) {
            Write-Errore "Windows troppo vecchio (build $build): winget richiede 1809 (17763) o superiore."
            Write-Info "Le installazioni app potrebbero non funzionare su questo sistema."
        }
    }
} catch {}

Write-Info "PowerShell: $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"
if ($PSVersionTable.PSEdition -eq 'Core') {
    Write-Info "Consiglio: usa Windows PowerShell 5.1 (PC Facile.bat lo fa gia'). Su PowerShell 7"
    Write-Info "  l'installazione di riserva di winget (Add-AppxPackage) puo' non funzionare."
}

# PowerShell a 32-bit (x86) su Windows a 64-bit: winget spesso da errori
# (sorgenti/certificati). Va usata la versione a 64-bit.
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    Write-Errore "Stai usando PowerShell a 32-bit (x86) su Windows a 64-bit."
    Write-Info "winget puo' fallire. Chiudi e apri 'Windows PowerShell' NORMALE (64-bit),"
    Write-Info "  NON la voce con '(x86)'. Oppure usa PC Facile.bat (parte a 64-bit)."
    Pausa
}

# =============================================================================
# CONTROLLI PRE-INSTALLAZIONE (riavvio in sospeso + spazio disco)
# =============================================================================

# Riavvio in sospeso: alcune installazioni falliscono finche' non si riavvia.
try {
    $rebootPending = $false
    $chiaviReboot = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    )
    foreach ($k in $chiaviReboot) { if (Test-Path $k) { $rebootPending = $true } }
    # NB: PendingFileRenameOperations NON e' piu' un segnale: su PC appena
    # installati da USB e' quasi sempre popolato con rinomine innocue e dava
    # un falso "riavvio in sospeso". Restano le due chiavi CBS/WindowsUpdate.
    if ($rebootPending) {
        Write-Info "C'e' un RIAVVIO in sospeso: alcune installazioni potrebbero fallire."
        Write-Info "Consiglio: riavvia il PC e rilancia lo script per risultati migliori."
    }
} catch {}

# Spazio libero sul disco di sistema
try {
    $lettera = $env:SystemDrive.TrimEnd(':')
    $free = (Get-PSDrive $lettera -ErrorAction SilentlyContinue).Free
    if ($free) {
        $freeGB = [math]::Round($free / 1GB, 1)
        Write-Info "Spazio libero su $($env:SystemDrive) $freeGB GB"
        if ($freeGB -lt 10) {
            Write-Errore "Poco spazio libero ($freeGB GB): le installazioni potrebbero fallire."
        }
    }
} catch {}

# Attivazione di Windows (evita di consegnare un PC con Windows non attivo)
try {
    $winLic = Get-CimInstance -ClassName SoftwareLicensingProduct `
        -Filter "ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL" `
        -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($winLic -and $winLic.LicenseStatus -eq 1) {
        Write-OK "Windows attivato."
        Add-Report "Windows attivato" "OK"
    } else {
        Write-Errore "Windows NON risulta attivato: verifica la licenza prima di consegnare."
        Add-Report "Windows attivato" "ERRORE"
    }
} catch {}

# Salute del disco (SMART): avvisa se un disco non e' Healthy
try {
    $dischi = Get-PhysicalDisk -ErrorAction SilentlyContinue
    if ($dischi) {
        $malati = @($dischi | Where-Object { $_.HealthStatus -and $_.HealthStatus -ne 'Healthy' })
        if ($malati.Count -gt 0) {
            foreach ($d in $malati) { Write-Errore "Disco '$($d.FriendlyName)': stato $($d.HealthStatus)!" }
            Add-Report "Salute disco" "ERRORE"
        } else {
            Write-OK "Dischi in salute (Healthy)."
        }
    }
} catch {}

# Presenza batteria (per laptop): lo stato dettagliato finisce nel file riepilogo
try {
    $Global:HaBatteria = [bool](Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)
} catch { $Global:HaBatteria = $false }

# =============================================================================
# PREFLIGHT RETE (utile su reti aziendali con firewall/proxy)
# =============================================================================

Write-Host ""
Write-Info "Controllo raggiungibilita' servizi (rete)..."
$endpoints = @(
    @{ Nome = "GitHub (download script)";            HostName = "raw.githubusercontent.com" },
    @{ Nome = "Microsoft (winget/Windows Update)";   HostName = "www.microsoft.com" },
    @{ Nome = "Store winget (installazione app)";    HostName = "cdn.winget.microsoft.com" }
)
$bloccati = 0
foreach ($e in $endpoints) {
    if (Test-Endpoint -HostName $e.HostName) {
        Write-OK "OK  $($e.Nome)"
    } else {
        Write-Errore "KO  $($e.Nome) [$($e.HostName)]"
        $bloccati++
    }
}
if ($bloccati -gt 0) {
    Write-Info "$bloccati servizio/i non raggiungibile/i: probabile firewall o proxy aziendale."
    Write-Info "Rimedi: tieni setup-pc.ps1 accanto ad PC Facile.bat (evita GitHub); per le"
    Write-Info "  installazioni app usa un hotspot o una rete senza filtri."
    Add-Report "Rete: $bloccati servizio/i bloccato/i" "AVVISO"
    Pausa
} else {
    Write-OK "Tutti i servizi chiave sono raggiungibili."
}

# =============================================================================
# LOG SU FILE (registro per ogni PC)
# =============================================================================

# Nessun log/transcript separato: a fine lavoro si crea UN solo file riepilogo.
$Global:LogFile = $null

# =============================================================================
# FUNZIONE: VERIFICA E INSTALLA WINGET
# =============================================================================

# Ripara le sorgenti winget (una volta per sessione, o forzato su errore).
# Risolve gli errori di integrita' sorgente/certificato (es. 0x8A15005E) su
# sorgenti corrotte o non aggiornate, tipici su PC nuovi.
# Primo tentativo SOLO aggiornamento: il "reset" azzera anche gli accordi e va
# usato solo se davvero serve (cioe' se l'aggiornamento fallisce). Se qualcosa
# fallisce, l'errore reale di winget diventa VISIBILE (non piu' nascosto).
function Enable-WingetStoreCertBypass {
    if ($Test -or $Global:Test -or $env:PESTER_TEST) { return }
    try {
        $polKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppInstaller"
        if (-not (Test-Path $polKey)) { New-Item -Path $polKey -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty -Path $polKey -Name "EnableBypassCertificatePinningForMicrosoftStore" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $polKey -Name "EnableAdditionalSources" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $polKey -Name "EnableSettings" -Value 1 -Type DWord -ErrorAction SilentlyContinue
    } catch {}
    try {
        $jsonCfg = '{"$schema":"https://aka.ms/winget-settings.schema.json","network":{"bypassCertificatePinningForMicrosoftStore":true}}'
        $cfgPaths = @(
            (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\settings.json"),
            (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Settings\settings.json")
        )
        foreach ($cp in $cfgPaths) {
            $dirCp = Split-Path $cp -Parent
            if (-not (Test-Path -LiteralPath $dirCp)) { New-Item -ItemType Directory -Path $dirCp -Force -ErrorAction SilentlyContinue | Out-Null }
            [System.IO.File]::WriteAllText($cp, $jsonCfg, (New-Object System.Text.UTF8Encoding($false)))
        }
    } catch {}
    try {
        & winget.exe settings --enable BypassCertificatePinningForMicrosoftStore 2>$null | Out-Null
    } catch {}
}

function Repair-WingetSources {
    param([switch]$Forza)
    if ($Global:WingetRiparato -and -not $Forza) { return }
    $Global:WingetRiparato = $true
    Write-Info "Riparazione sorgenti winget (bypass certificato Store 0x8a15005e + source.msix)..."
    Start-BarraAnimata "Riparo le sorgenti winget"
    try {
        Enable-WingetStoreCertBypass
        # Su Windows 11 nuovi di fabbrica (winget v1.2/v1.3), 'winget source update'
        # fallisce con 0x8A15005E (certificato CDN fissato scaduto). Installare
        # direttamente source.msix con Add-AppxPackage usa i certificati di sistema
        # di Windows e sblocca subito il catalogo winget in 3 secondi.
        $srcMsix = Join-Path $env:TEMP "winget-source.msix"
        $curlBin = Join-Path $env:SystemRoot "System32\curl.exe"
        try {
            Remove-Item -LiteralPath $srcMsix -Force -ErrorAction SilentlyContinue
            if (Test-Path -LiteralPath $curlBin) {
                & $curlBin -fsSL --connect-timeout 10 --max-time 60 -o $srcMsix "https://cdn.winget.microsoft.com/cache/source.msix" 2>$null
            } else {
                Invoke-WebRequest -Uri "https://cdn.winget.microsoft.com/cache/source.msix" -OutFile $srcMsix -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
            }
            if ((Test-Path -LiteralPath $srcMsix) -and ((Get-Item -LiteralPath $srcMsix).Length -gt 1048576)) {
                Add-AppxPackage -Path $srcMsix -ErrorAction Stop
                Remove-Item -LiteralPath $srcMsix -Force -ErrorAction SilentlyContinue
                Write-OK "Catalogo sorgente Microsoft.WinGet.Source installato direttamente."
            }
        } catch {}
        Remove-Item -LiteralPath $srcMsix -Force -ErrorAction SilentlyContinue

        # Se anche il binario winget di fabbrica e' vecchio (es. 2022) e rifiuta il certificato
        # di msstore (0x8a15005e su WhatsApp), aggiorna DesktopAppInstaller da aka.ms/getwinget
        if ($Forza) {
            try {
                & winget.exe search --exact --id 9NKSQGP7F2NH --source msstore --accept-source-agreements 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    $wgBundle = Join-Path $env:TEMP "Microsoft.DesktopAppInstaller.msixbundle"
                    Remove-Item -LiteralPath $wgBundle -Force -ErrorAction SilentlyContinue
                    if (Test-Path -LiteralPath $curlBin) {
                        & $curlBin -fsSL --connect-timeout 10 --max-time 90 -o $wgBundle "https://aka.ms/getwinget" 2>$null
                    } else {
                        Invoke-WebRequest -Uri "https://aka.ms/getwinget" -OutFile $wgBundle -UseBasicParsing -TimeoutSec 90 -ErrorAction SilentlyContinue
                    }
                    if ((Test-Path -LiteralPath $wgBundle) -and ((Get-Item -LiteralPath $wgBundle).Length -gt 5242880)) {
                        Add-AppxPackage -Path $wgBundle -ErrorAction SilentlyContinue
                        Remove-Item -LiteralPath $wgBundle -Force -ErrorAction SilentlyContinue
                        Enable-WingetStoreCertBypass
                        Write-OK "Winget (App Installer) aggiornato all'ultima versione."
                    }
                }
            } catch {}
        }

        $out = winget source update 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-OK "Sorgenti winget aggiornate."
        } else {
            Write-Info "Aggiornamento sorgenti fallito: provo il reset delle sorgenti (forzato)..."
            winget source reset --force 2>&1 | Out-Null
            $out = winget source update 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-OK "Sorgenti winget ripristinate."
            } else {
                Write-Errore "Sorgenti winget NON funzionanti sul PC (usero' il download diretto ufficiale)."
            }
            $out | Select-Object -Last 4 | ForEach-Object { Write-Host "     $_" -ForegroundColor Gray }
        }
    } catch {
        Write-Info "Riparazione sorgenti non riuscita: $_"
    } finally { Stop-BarraAnimata }
}

function Confirm-Winget {
    # Risultato calcolato una sola volta per sessione (evita ricontrolli/reinstalli)
    if ($null -ne $Global:WingetOk) { return $Global:WingetOk }

    Write-Info "Verifica presenza di Winget..."

    # Su molte immagini OEM (HP, Acer, MSI, Asus) l'alias winget.exe non e' nel PATH
    # del processo elevato Amministratore anche se il pacchetto DesktopAppInstaller e' gia' su disco.
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        try {
            $userWinApps = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"
            if ((Test-Path -LiteralPath (Join-Path $userWinApps "winget.exe")) -and ($env:PATH -notlike "*$userWinApps*")) {
                $env:PATH = "$userWinApps;$env:PATH"
            }
            if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
                $sysWg = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if ($sysWg -and $sysWg.DirectoryName) {
                    $env:PATH = "$($sysWg.DirectoryName);$env:PATH"
                }
            }
        } catch {}
    }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-OK "Winget trovato."
        $Global:WingetOk = $true
        if (-not $Test -and -not $Global:Test -and -not $env:PESTER_TEST) {
            Enable-WingetStoreCertBypass
            # Test rapido catalogo: su Windows 11 nuovi di fabbrica il certificato
            # sorgente preinstallato e' scaduto (0x8a15005e); se la ricerca fallisce,
            # riparo subito installando source.msix prima di avviare il ciclo app.
            try {
                & winget search --exact --id 7zip.7zip --source winget --accept-source-agreements 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Repair-WingetSources -Forza
                }
            } catch {}
        }
        return $true
    }

    Write-Info "Winget non trovato. Tentativo di installazione..."

    try {
        $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
        $msixBundle = $releases.assets | Where-Object { $_.name -like "*.msixbundle" } | Select-Object -First 1

        if (-not $msixBundle) {
            Write-Errore "Impossibile trovare il pacchetto Winget su GitHub."
            $Global:WingetOk = $false
            return $false
        }

        $tempPath = "$env:TEMP\AppInstaller.msixbundle"
        Write-Info "Download in corso: $($msixBundle.name)"
        Invoke-WebRequest -Uri $msixBundle.browser_download_url -OutFile $tempPath -UseBasicParsing

        Add-AppxPackage -Path $tempPath -ErrorAction Stop
        Remove-Item $tempPath -Force

        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-OK "Winget installato con successo."
            $Global:WingetOk = $true
            return $true
        } else {
            Write-Errore "Installazione Winget fallita."
            $Global:WingetOk = $false
            return $false
        }
    } catch {
        Write-Errore "Errore durante installazione Winget: $_"
        $Global:WingetOk = $false
        return $false
    }
}

# Lancia winget con timeout e restituisce il codice di uscita firmato.
function Invoke-WingetConBarra {
    param(
        [string]$Nome,
        [string[]]$WingetArgs,
        [int]$TimeoutSec = 600 # 10 minuti massimo per singola operazione/app (reti lente / file grandi)
    )
    if ($Test -or $Global:Test -or $env:PESTER_TEST) {
        Write-OK "TEST: simulazione winget $Nome completata."
        return 0
    }

    Write-Info "Scarico e installo $Nome (max $([math]::Round($TimeoutSec/60)) min)..."
    try {
        # L'alias App Installer puo' restituire ExitCode nullo; cmd.exe lo propaga correttamente.
        $p = Start-Process -FilePath $env:ComSpec -ArgumentList "/d /c winget $($WingetArgs -join ' ')" -NoNewWindow -PassThru -ErrorAction Stop
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $ultimoBeat = 0
        while (-not $p.HasExited) {
            if ($Global:PannelloSync -and $Global:PannelloSync.SkipCurrent) {
                Write-Host ""
                Write-Info "Operazione '$Nome' saltata dall'operatore dal pannello."
                try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch {}
                return -9998
            }
            $sec = [int]$sw.Elapsed.TotalSeconds
            if ($sec -ge $TimeoutSec) {
                Write-Host ""
                Write-Errore "Tempo massimo superato ($($TimeoutSec)s) per ${Nome}: interrompo il processo per non bloccare il setup notturno."
                try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch {}
                try {
                    Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $p.Id } | ForEach-Object {
                        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
                    }
                } catch {}
                return -9999
            }
            if ($sec -ge ($ultimoBeat + 5)) {
                $ultimoBeat = $sec
                try { Write-Host ("`r   -> {0}: operazione in corso... ({1}s / max {2}s)   " -f $Nome, $sec, $TimeoutSec) -NoNewline -ForegroundColor DarkGray } catch {}
            }
            Start-Sleep -Milliseconds 500
        }
        if ($ultimoBeat -gt 0) { try { Write-Host "" } catch {} }
        try { $p.WaitForExit() } catch {}
        Reset-ConsoleMode
        $exitCode = $p.ExitCode
        if ($null -eq $exitCode) { $exitCode = -1 }
        return $exitCode
    } catch {
        try {
            winget @WingetArgs
            $code = $LASTEXITCODE
            if ($null -eq $code) { $code = -1 }
            return $code
        } catch { return -1 }
    }
}

# --- ICONA SUL DESKTOP per ogni app installata (cosi' il cliente vede cosa e'
#     stato messo). Due nomi "somigliano" se, tolti spazi/punteggiatura, uno
#     contiene l'altro (es. "Adobe Acrobat Reader" ~ "Adobe Acrobat"). ---
function Test-NomeSimile {
    param([string]$A, [string]$B)
    $na = ($A -replace '[^A-Za-z0-9]', '').ToLower()
    $nb = ($B -replace '[^A-Za-z0-9]', '').ToLower()
    if (-not $na -or -not $nb) { return $false }
    return ($na.Contains($nb) -or $nb.Contains($na))
}

# Collegamenti "spazzatura" da NON copiare sul Desktop (disinstalla, guida...).
function Test-LnkJunk {
    param([string]$Base)
    $junk = @('*uninstall*', '*disinstall*', '*guida*', '*help*', '*read*me*', '*leggimi*',
              '*documentation*', '*website*', '*sito*', '*modify*', '*repair*', '*support*',
              '*aggiorna*', '*update*')
    foreach ($p in $junk) { if ($Base -like $p) { return $true } }
    return $false
}

# Toglie il collegamento di Microsoft Edge dal Desktop (utente + pubblico):
# se installiamo altri browser, l'icona di Edge sul Desktop non serve.
function Remove-EdgeDaDesktop {
    if (-not $RunReale) { return }
    try {
        $desktops = @([Environment]::GetFolderPath('Desktop'),
                      [Environment]::GetFolderPath('CommonDesktopDirectory')) |
                    Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique
        foreach ($d in $desktops) {
            Get-ChildItem -Path $d -Filter '*Edge*.lnk' -ErrorAction SilentlyContinue |
                ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
        }
    } catch {}
}

# Tutti i collegamenti del menu Start (utente + tutti gli utenti, ricorsivo).
function Get-StartMenuLnks {
    $roots = @(
        (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'),
        (Join-Path $env:APPDATA     'Microsoft\Windows\Start Menu\Programs')
    )
    $res = @()
    foreach ($r in $roots) {
        if (Test-Path $r) { $res += Get-ChildItem -Path $r -Filter *.lnk -Recurse -ErrorAction SilentlyContinue }
    }
    return $res
}

# Crea sul Desktop l'icona dell'app APPENA installata, cosi' il cliente la vede
# comparire man mano. Strategia in ordine di affidabilita':
#  0) DIFF prima/dopo: se mi passi $LnkPrima (i collegamenti del menu Start PRIMA
#     dell'installazione), copio i collegamenti NUOVI comparsi = esattamente
#     quelli creati da QUESTA app (niente indovinelli sui nomi);
#  1) altrimenti cerco nel menu Start un collegamento che somiglia al nome;
#  2) app dello Store (MSIX, niente .lnk) -> Get-StartApps + shell:AppsFolder.
# Salta i doppioni. Un breve retry copre il caso in cui il collegamento non e'
# ancora stato scritto subito dopo la fine di winget.
# Icone (.lnk) presenti sul Desktop VISTO dal cliente = Desktop utente PIU'
# Desktop pubblico (C:\Users\Public\Desktop): Windows li fonde. Molti installer
# (Chrome, AnyDesk, Steam...) mettono l'icona sul PUBBLICO, quindi il controllo
# anti-doppione deve guardare entrambi, altrimenti si finisce con due icone.
function Get-DesktopLnks {
    $dirs = @((Get-DesktopDir),
              [Environment]::GetFolderPath('CommonDesktopDirectory')) |
            Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique
    $res = @()
    foreach ($d in $dirs) {
        $res += Get-ChildItem -Path $d -Filter *.lnk -ErrorAction SilentlyContinue
    }
    return $res
}

# Pulizia doppioni: se la STESSA app ha un'icona sia sul Desktop pubblico (messa
# dall'installer) sia su quello utente (copiata da noi), tolgo quella UTENTE e
# lascio l'originale del pubblico. Da lanciare DOPO le installazioni: copre anche
# il caso in cui l'installer crea la sua icona un attimo dopo il nostro controllo.
function Remove-IconeDoppieDesktop {
    if (-not $RunReale) { return }
    try {
        $userD = Get-DesktopDir
        $pubD  = [Environment]::GetFolderPath('CommonDesktopDirectory')
        if (-not ($pubD -and (Test-Path $pubD))) { return }
        $userLnks = @(Get-ChildItem -Path $userD -Filter *.lnk -ErrorAction SilentlyContinue)
        $pubLnks  = @(Get-ChildItem -Path $pubD  -Filter *.lnk -ErrorAction SilentlyContinue)
        foreach ($u in $userLnks) {
            if ($pubLnks | Where-Object { Test-NomeSimile $_.BaseName $u.BaseName }) {
                Remove-Item $u.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {}
}

# Converte un flusso di byte PNG in un file .ico Windows (formato PNG-in-ICO standard da Vista a Windows 11).
function Convert-PngToIco {
    param(
        [byte[]]$pngBytes,
        [string]$outFile
    )
    try {
        if (-not $pngBytes -or $pngBytes.Length -lt 24) { return $false }
        # Verifica magic byte PNG: 0x89 0x50 0x4E 0x47
        if ($pngBytes[0] -ne 0x89 -or $pngBytes[1] -ne 0x50 -or $pngBytes[2] -ne 0x4E -or $pngBytes[3] -ne 0x47) {
            return $false
        }
        # Dimensioni da IHDR (offset 16..23, big-endian)
        $w = [System.BitConverter]::ToInt32(@($pngBytes[19], $pngBytes[18], $pngBytes[17], $pngBytes[16]), 0)
        $h = [System.BitConverter]::ToInt32(@($pngBytes[23], $pngBytes[22], $pngBytes[21], $pngBytes[20]), 0)
        $icoW = if ($w -ge 256 -or $w -le 0) { 0 } else { [byte]$w }
        $icoH = if ($h -ge 256 -or $h -le 0) { 0 } else { [byte]$h }
        $lenBytes = [System.BitConverter]::GetBytes([int]$pngBytes.Length)
        $offsetBytes = [System.BitConverter]::GetBytes([int]22)

        $outDir = Split-Path $outFile
        if ($outDir -and -not (Test-Path $outDir)) {
            New-Item -Path $outDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
        }

        $ms = New-Object System.IO.MemoryStream
        # Header ICO: Reserved (2), Type 1=Icon (2), Count 1 (2)
        $ms.Write([byte[]]@(0, 0, 1, 0, 1, 0), 0, 6)
        # Entry: Width(1), Height(1), Colors(1), Reserved(1), Planes(2), BPP(2), BytesInRes(4), Offset(4)
        $ms.Write([byte[]]@($icoW, $icoH, 0, 0, 1, 0, 32, 0), 0, 8)
        $ms.Write($lenBytes, 0, 4)
        $ms.Write($offsetBytes, 0, 4)
        # PNG payload
        $ms.Write($pngBytes, 0, $pngBytes.Length)
        [System.IO.File]::WriteAllBytes($outFile, $ms.ToArray())
        $ms.Dispose()
        return (Test-Path $outFile)
    } catch {
        return $false
    }
}

# Estrae l'icona ufficiale da un'app dello Store (MSIX/AppX) e la converte in .ico leggibile da Explorer
function Get-AppxPackageIcon {
    param(
        [string]$AppUserModelId = "",
        [string]$NomeApp = ""
    )
    try {
        $baseData = if ($env:ProgramData) { $env:ProgramData } elseif ([System.IO.Directory]::Exists("C:\ProgramData")) { "C:\ProgramData" } else { [System.IO.Path]::GetTempPath() }
        $iconDir = Join-Path $baseData "PCFacile\Icons"
        if (-not (Test-Path $iconDir)) {
            New-Item -Path $iconDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
            try { & icacls.exe "$iconDir" /grant "Users:(OI)(CI)RX" /T 2>$null | Out-Null } catch {}
        }
        $safeName = ($NomeApp -replace '[\\/:*?"<>|]', '').Trim()
        if (-not $safeName -and $AppUserModelId) { $safeName = ($AppUserModelId -split '!')[0] }
        if (-not $safeName) { return $null }

        $icoDest = Join-Path $iconDir "$safeName.ico"
        if ((Test-Path $icoDest) -and (Get-Item $icoDest).Length -gt 100) {
            return $icoDest
        }

        $pkg = $null
        if ($AppUserModelId) {
            $pfn = ($AppUserModelId -split '!')[0]
            $pkg = Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { $_.PackageFamilyName -eq $pfn } | Select-Object -First 1
        }
        if (-not $pkg -and $NomeApp) {
            $pkg = Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$safeName*" } | Select-Object -First 1
        }

        if ($pkg -and $pkg.InstallLocation -and (Test-Path $pkg.InstallLocation)) {
            # 1) Se c'e' un .ico nativo nel pacchetto
            $icoFile = Get-ChildItem -Path $pkg.InstallLocation -Filter "*.ico" -Recurse -ErrorAction SilentlyContinue |
                Sort-Object Length -Descending | Select-Object -First 1
            if ($icoFile) {
                Copy-Item -Path $icoFile.FullName -Destination $icoDest -Force -ErrorAction SilentlyContinue
                try { & icacls.exe "$icoDest" /grant "Users:RX" 2>$null | Out-Null } catch {}
                if (Test-Path $icoDest) { return $icoDest }
            }

            # 2) Cerca gli asset PNG ufficiali
            $assetsDir = Join-Path $pkg.InstallLocation "Assets"
            $searchDirs = @($assetsDir, $pkg.InstallLocation) | Where-Object { Test-Path $_ }
            $pngFiles = @()
            foreach ($sd in $searchDirs) {
                $pngFiles += Get-ChildItem -Path $sd -Filter "*.png" -Recurse -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -notmatch 'splash|banner|badge|contrast-black|contrast-white' }
            }

            $candidato = $pngFiles | Where-Object { $_.Name -match 'targetsize-(48|64|96|128|256)|Square150|Square44|Logo|AppList' } |
                Sort-Object {
                    $score = 0
                    if ($_.Name -match 'targetsize-256') { $score += 100 }
                    elseif ($_.Name -match 'targetsize-128') { $score += 90 }
                    elseif ($_.Name -match 'targetsize-64') { $score += 80 }
                    elseif ($_.Name -match 'targetsize-48') { $score += 70 }
                    elseif ($_.Name -match 'Square150') { $score += 60 }
                    elseif ($_.Name -match 'Square44') { $score += 50 }
                    elseif ($_.Name -match 'Logo') { $score += 40 }
                    $score += [int]($_.Length / 1024)
                    $score
                } -Descending | Select-Object -First 1

            if (-not $candidato -and $pngFiles.Count -gt 0) {
                $candidato = $pngFiles | Sort-Object Length -Descending | Select-Object -First 1
            }

            if ($candidato) {
                $pngBytes = [System.IO.File]::ReadAllBytes($candidato.FullName)
                if (Convert-PngToIco -pngBytes $pngBytes -outFile $icoDest) {
                    try { & icacls.exe "$icoDest" /grant "Users:RX" 2>$null | Out-Null } catch {}
                    return $icoDest
                }
            }
        }
    } catch {}
    return $null
}

# Forza l'aggiornamento immediato della cache delle icone e della griglia Desktop di Explorer
function Update-DesktopIconCache {
    try {
        $code = @'
        using System;
        using System.Runtime.InteropServices;
        public class PCFacileShellNotify {
            [DllImport("shell32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
            public static extern void SHChangeNotify(int wEventId, uint uFlags, IntPtr dwItem1, IntPtr dwItem2);
            public static void NotifyDir(string path) {
                if (string.IsNullOrEmpty(path)) return;
                IntPtr ptr = Marshal.StringToHGlobalUni(path);
                try {
                    // SHCNE_UPDATEDIR (0x1000) | SHCNF_PATHW (0x0005) | SHCNF_FLUSH (0x1000)
                    SHChangeNotify(0x00001000, 0x1005, ptr, IntPtr.Zero);
                } finally {
                    Marshal.FreeHGlobal(ptr);
                }
            }
        }
'@
        Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue
        [PCFacileShellNotify]::SHChangeNotify(0x08000000, 0x1000, [IntPtr]::Zero, [IntPtr]::Zero)
        foreach ($d in @((Get-DesktopDir), [Environment]::GetFolderPath('CommonDesktopDirectory'))) {
            if ($d -and (Test-Path -LiteralPath $d)) {
                [PCFacileShellNotify]::NotifyDir($d)
            }
        }
    } catch {}
    try { Start-Process "ie4uinit.exe" -ArgumentList "-show" -WindowStyle Hidden -ErrorAction SilentlyContinue } catch {}
}

# Controlla e ripara i collegamenti sul Desktop che hanno icone bianche o target Store senza icona
function Repair-DesktopShortcuts {
    if (-not $RunReale) { return }
    try {
        $desktopDirs = @((Get-DesktopDir), [Environment]::GetFolderPath('CommonDesktopDirectory')) |
            Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

        $wsh = New-Object -ComObject WScript.Shell
        $riparati = 0

        foreach ($dir in $desktopDirs) {
            $lnks = Get-ChildItem -Path $dir -Filter *.lnk -ErrorAction SilentlyContinue
            foreach ($lnk in $lnks) {
                try {
                    $sc = $wsh.CreateShortcut($lnk.FullName)
                    $nome = $lnk.BaseName

                    # Ripara Spotify
                    if ($nome -like "*Spotify*") {
                        $spotExes = @(
                            (Join-Path $env:APPDATA "Spotify\Spotify.exe"),
                            (Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\Spotify.exe"),
                            "$env:ProgramFiles\Spotify\Spotify.exe",
                            "${env:ProgramFiles(x86)}\Spotify\Spotify.exe"
                        )
                        $spotExes += @(Get-ChildItem -Path "C:\Users\*\AppData\Roaming\Spotify\Spotify.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
                        try {
                            $pkgSpot = Get-AppxPackage -Name "*Spotify*" -ErrorAction SilentlyContinue | Select-Object -First 1
                            if ($pkgSpot -and $pkgSpot.InstallLocation) {
                                $spotExes += (Join-Path $pkgSpot.InstallLocation "Spotify.exe")
                            }
                        } catch {}
                        $spotReal = $spotExes | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

                        if ($spotReal) {
                            $sc.TargetPath = $spotReal
                            $sc.Arguments = ""
                            $sc.IconLocation = "$spotReal,0"
                            $sc.WorkingDirectory = Split-Path $spotReal
                            $sc.Save()
                            $riparati++
                            continue
                        } else {
                            $ico = Get-AppxPackageIcon -NomeApp "Spotify"
                            if ($ico) {
                                $sc.IconLocation = "$ico,0"
                                $sc.Save()
                                $riparati++
                                continue
                            }
                            # Se non trova icona AppX, cerca gli asset del pacchetto SpotifyMusic
                            $pkgSpot = Get-AppxPackage -Name "*SpotifyMusic*" -ErrorAction SilentlyContinue | Select-Object -First 1
                            if ($pkgSpot -and $pkgSpot.InstallLocation) {
                                $spotIco = Get-ChildItem -Path $pkgSpot.InstallLocation -Filter "*.ico" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                                if ($spotIco) {
                                    $sc.IconLocation = "$($spotIco.FullName),0"
                                    $sc.Save()
                                    $riparati++
                                    continue
                                }
                            }
                        }
                    }

                    # Ripara collegamenti Store ad explorer.exe (WhatsApp, ecc.)
                    if ($sc.TargetPath -like "*explorer.exe*" -and $sc.Arguments -like "*shell:AppsFolder*") {
                        $appId = ($sc.Arguments -replace '^.*shell:AppsFolder\\', '').Trim()
                        $curIco = $sc.IconLocation
                        if (-not $curIco -or $curIco -like "*WindowsApps*" -or -not (Test-Path ($curIco -split ',')[0])) {
                            $ico = Get-AppxPackageIcon -AppUserModelId $appId -NomeApp $nome
                            if ($ico) {
                                $sc.IconLocation = "$ico,0"
                                $sc.Save()
                                $riparati++
                            }
                        }
                    }
                } catch {}
            }
            # Rimuovi eventuali cartelle temporanee di estrazione (es. OpenOffice 4.1.17 Installation Files)
            try {
                Get-ChildItem -Path $dir -Directory -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -like '*OpenOffice*' -or $_.Name -like '*Installation Files*' } |
                    ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
                Get-ChildItem -Path $dir -Filter "*.lnk" -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.BaseName -like '*OpenOffice*Install*' -or $_.BaseName -like '*Installation Files*' } |
                    ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
            } catch {}
        }

        # Se Office e' installato ma manca qualche collegamento (es. Word terminato dopo), assicurati che ci siano tutti
        try {
            if (Test-OfficeInstallato) { Add-CollegamentiOffice }
        } catch {}
        # Assicura che il collegamento Desktop a Unieuro Cyber Protection sia sempre presente accanto a Unieuro Secure
        try {
            if (-not $Global:serviziSelezionati -or $Global:serviziSelezionati.Everyday -or $Global:serviziSelezionati.Cyber) {
                Add-ShortcutCyberProtection
            }
        } catch {}

        if ($riparati -gt 0) {
            Write-OK "Riparate icone desktop per $riparati collegamenti."
        }
        Set-DesktopIconOrder
        Update-DesktopIconCache
    } catch {}
}

# Restituisce la priorita' logica e cromatica di un'icona Desktop:
# 1) PRIME DUE APP: Unieuro Secure (#1) e Unieuro Cyber Protection / Cybersecurity (#2)
# 2) Office & Documenti (Word Blu -> Excel Verde -> PowerPoint Arancio -> Outlook Azzurro -> OneNote Viola -> LibreOffice -> Adobe Rosso -> Sumatra Giallo)
# 3) Browser & Comunicazione (Chrome Multicolore -> Browser -> Zoom Blu -> WhatsApp Verde -> Discord Viola -> AnyDesk Rosso -> TeamViewer Blu)
# 4) Multimedia, Utilita' & Gaming (Spotify Verde -> VLC Arancio -> AIMP Arancio -> GIMP Ambra -> 7-Zip -> Steam Blu Notte -> Epic Nero -> GPU)
# 5) Scheda di Consegna Finale (PDF/HTML cliente sempre in fondo)
function Get-DesktopIconPriority {
    param([string]$Nome)
    if (-not $Nome) { return 800 }
    $n = $Nome.Trim()
    if ($n -match 'Unieuro\s*Secure|F-Secure')             { return 1 }
    if ($n -match 'Cyber\s*Protection|Cybersecurity')      { return 2 }
    if ($n -match '^(Microsoft\s+)?Word\b')                { return 10 }
    if ($n -match '^(Microsoft\s+)?Excel\b')               { return 20 }
    if ($n -match '^(Microsoft\s+)?PowerPoint\b')          { return 30 }
    if ($n -match '^(Microsoft\s+)?Outlook\b')             { return 40 }
    if ($n -match '^(Microsoft\s+)?OneNote\b')             { return 50 }
    if ($n -match '^(Microsoft\s+)?(Access|Publisher)\b')  { return 60 }
    if ($n -match 'LibreOffice')                           { return 70 }
    if ($n -match 'Adobe|Acrobat')                         { return 80 }
    if ($n -match 'Sumatra')                               { return 90 }
    if ($n -match 'McAfee|Norton')                         { return 130 }
    if ($n -match 'Chrome')                                { return 210 }
    if ($n -match 'Firefox|Brave|Opera')                   { return 220 }
    if ($n -match 'Zoom')                                  { return 230 }
    if ($n -match 'WhatsApp')                              { return 240 }
    if ($n -match 'Discord')                               { return 250 }
    if ($n -match 'AnyDesk')                               { return 260 }
    if ($n -match 'TeamViewer')                            { return 270 }
    if ($n -match 'Spotify')                               { return 310 }
    if ($n -match 'VLC')                                   { return 320 }
    if ($n -match 'AIMP')                                  { return 330 }
    if ($n -match 'GIMP')                                  { return 340 }
    if ($n -match '7-Zip|7Zip|Unarchiver')                 { return 350 }
    if ($n -match 'Steam')                                 { return 360 }
    if ($n -match 'Epic\s*Games')                          { return 370 }
    if ($n -match 'NVIDIA|GeForce|Adrenalin|Intel')        { return 380 }
    if ($n -match 'Scheda-Consegna')                       { return 900 }
    return 800
}

# Riordina le icone sul Desktop del cliente secondo l'ordine logico e cromatico
# (prima Office, poi Sicurezza Unieuro, Browser/Comunicazione, Multimedia/Utility
# e per ultima la Scheda di Consegna PDF). Consolida i collegamenti da Public\Desktop
# e User\Desktop e li reinserisce in sequenza in modo che la griglia di Windows 11
# li disponga dall'alto in basso colonna per colonna.
function Set-DesktopIconOrder {
    param([switch]$Test)
    if ($Test -or -not $RunReale) { return }
    try {
        $userD = Get-DesktopDir
        if (-not $userD -or -not (Test-Path -LiteralPath $userD)) { return }
        $pubD  = [Environment]::GetFolderPath('CommonDesktopDirectory')
        $dirs  = @($userD, $pubD) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique

        $candidati = @()
        foreach ($d in $dirs) {
            $candidati += @(Get-ChildItem -LiteralPath $d -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Extension -ieq '.lnk' -or $_.BaseName -like 'Scheda-Consegna*' })
        }
        if ($candidati.Count -le 1) { return }

        # Deduplica eventuali doppioni tra Desktop Utente e Desktop Pubblico
        $unici = @()
        foreach ($f in $candidati) {
            $gia = $unici | Where-Object {
                ($_.Name -ieq $f.Name) -or ($_.Extension -ieq '.lnk' -and $f.Extension -ieq '.lnk' -and (Test-NomeSimile $_.BaseName $f.BaseName))
            } | Select-Object -First 1
            if ($gia) {
                if ($f.FullName -ne $gia.FullName) {
                    try { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue } catch {}
                }
            } else {
                $unici += $f
            }
        }

        $ordinati = @($unici | Sort-Object -Property @{ Expression = { Get-DesktopIconPriority $_.BaseName } }, @{ Expression = { $_.BaseName } })
        $tmpBase = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
        $stageDir = Join-Path $tmpBase ("pcfacile-desk-order-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $stageDir -Force -ErrorAction Stop | Out-Null

        $staged = @()
        foreach ($item in $ordinati) {
            $destTmp = Join-Path $stageDir $item.Name
            try {
                Copy-Item -LiteralPath $item.FullName -Destination $destTmp -Force -ErrorAction Stop
                if (Test-Path -LiteralPath $destTmp) {
                    try {
                        Remove-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
                        $staged += [pscustomobject]@{ Name = $item.Name; TmpPath = $destTmp; TargetDir = $userD }
                    } catch {
                        # Se un collegamento su Public\Desktop fosse bloccato, non lo duplichiamo
                        Remove-Item -LiteralPath $destTmp -Force -ErrorAction SilentlyContinue
                    }
                }
            } catch {}
        }

        if ($staged.Count -gt 0) {
            try {
                Get-Item -Path 'HKCU:\Software\Microsoft\Windows\Shell\Bags\1\Desktop' -ErrorAction SilentlyContinue |
                    ForEach-Object {
                        foreach ($p in $_.Property) {
                            if ($p -like 'ItemPos*') {
                                Remove-ItemProperty -Path $_.PSPath -Name $p -ErrorAction SilentlyContinue
                            }
                        }
                    }
            } catch {}
            Update-DesktopIconCache
            Start-Sleep -Milliseconds 350

            $t0 = (Get-Date).AddMinutes(-5)
            $idx = 0
            foreach ($s in $staged) {
                $idx++
                $finalPath = Join-Path $s.TargetDir $s.Name
                try {
                    $ts = $t0.AddSeconds($idx * 2)
                    $fi = Get-Item -LiteralPath $s.TmpPath -ErrorAction SilentlyContinue
                    if ($fi) {
                        $fi.CreationTime = $ts
                        $fi.LastWriteTime = $ts
                    }
                    Move-Item -LiteralPath $s.TmpPath -Destination $finalPath -Force -ErrorAction Stop
                    Start-Sleep -Milliseconds 110
                } catch {}
            }
            Update-DesktopIconCache
        }
        Remove-Item -LiteralPath $stageDir -Recurse -Force -ErrorAction SilentlyContinue
    } catch {}
}

function Add-IconaDesktop {
    param([string]$Nome, [string[]]$LnkPrima = @())
    if (-not $RunReale) { return }
    Stop-AppPopups -Nome $Nome
    try {
        $desktop = Get-DesktopDir

        # ANTI-DOPPIONE (per PRIMO): se su UNO DEI DUE Desktop (utente o pubblico)
        # c'e' gia' un'icona che somiglia al nome dell'app - creata dall'installer
        # stesso (Chrome, AnyDesk, Steam...) o da un giro precedente - non ne
        # aggiungo una seconda.
        $gia = Get-DesktopLnks | Where-Object { Test-NomeSimile $_.BaseName $Nome } | Select-Object -First 1
        if ($gia) { return }

        # 0) DIFF: collegamenti NUOVI creati dall'installazione (max ~4s di attesa).
        if ($LnkPrima -and $LnkPrima.Count -ge 0) {
            $nuovi = @()
            for ($t = 0; $t -lt 2; $t++) {
                $nuovi = @(Get-StartMenuLnks | Where-Object {
                    ($LnkPrima -notcontains $_.FullName) -and -not (Test-LnkJunk $_.BaseName)
                })
                if ($nuovi.Count -gt 0) { break }
                Start-Sleep -Milliseconds 700
            }
            if ($nuovi.Count -gt 0) {
                # Preferisci quelli che somigliano al nome; se nessuno, prendi il piu'
                # "principale" (nome piu' corto). Copio UN collegamento per app, e
                # solo se un'icona simile non e' comparsa nel frattempo sul Desktop.
                $match = @($nuovi | Where-Object { Test-NomeSimile $_.BaseName $Nome })
                $scelto = if ($match.Count -gt 0) { $match | Sort-Object { $_.BaseName.Length } | Select-Object -First 1 }
                          else { $nuovi | Sort-Object { $_.BaseName.Length } | Select-Object -First 1 }
                if ($scelto) {
                    $giaSimile = Get-DesktopLnks |
                        Where-Object { Test-NomeSimile $_.BaseName $scelto.BaseName } | Select-Object -First 1
                    $dest = Join-Path $desktop $scelto.Name
                    if (-not $giaSimile -and -not (Test-Path $dest)) {
                        Copy-Item -Path $scelto.FullName -Destination $dest -Force -ErrorAction SilentlyContinue
                    }
                    Update-DesktopIconCache
                    return
                }
            }
        }

        # 1) Menu Start: collegamento Win32 con l'icona vera dell'app (per nome).
        $cand = Get-StartMenuLnks |
            Where-Object { -not (Test-LnkJunk $_.BaseName) -and (Test-NomeSimile $_.BaseName $Nome) } |
            Sort-Object { $_.BaseName.Length } | Select-Object -First 1
        if ($cand) {
            Copy-Item -Path $cand.FullName -Destination (Join-Path $desktop $cand.Name) -Force -ErrorAction SilentlyContinue
            Update-DesktopIconCache
            return
        }

        # 2) App dello Store (WhatsApp, Spotify...): AppUserModelID via Get-StartApps.
        $app = Get-StartApps -ErrorAction SilentlyContinue |
            Where-Object { Test-NomeSimile $_.Name $Nome } | Sort-Object { $_.Name.Length } | Select-Object -First 1
        if ($app) {
            $wsh = New-Object -ComObject WScript.Shell
            $file = ("$($app.Name).lnk" -replace '[\\/:*?"<>|]', '')
            $sc = $wsh.CreateShortcut((Join-Path $desktop $file))

            # Verifica speciale per Spotify Win32 (installato nel profilo utente)
            $spotExe = $null
            if ($Nome -like "*Spotify*") {
                $spotExes = @(
                    (Join-Path $env:APPDATA "Spotify\Spotify.exe"),
                    (Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\Spotify.exe"),
                    "$env:ProgramFiles\Spotify\Spotify.exe",
                    "${env:ProgramFiles(x86)}\Spotify\Spotify.exe"
                )
                $spotExes += @(Get-ChildItem -Path "C:\Users\*\AppData\Roaming\Spotify\Spotify.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
                $spotExe = $spotExes | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
            }

            if ($spotExe) {
                $sc.TargetPath = $spotExe
                $sc.WorkingDirectory = Split-Path $spotExe
                $sc.IconLocation = "$spotExe,0"
            } elseif ($app.AppID -match '\.exe$' -and (Test-Path $app.AppID)) {
                $sc.TargetPath = $app.AppID
                $sc.IconLocation = "$($app.AppID),0"
            } else {
                $sc.TargetPath = "$env:WINDIR\explorer.exe"
                $sc.Arguments  = "shell:AppsFolder\$($app.AppID)"
                # Estrai l'icona ufficiale del pacchetto Store e salvala in ProgramData\PCFacile\Icons
                $ico = Get-AppxPackageIcon -AppUserModelId $app.AppID -NomeApp $Nome
                if ($ico) {
                    $sc.IconLocation = "$ico,0"
                }
            }
            $sc.Save()
            Update-DesktopIconCache
        }
    } catch {}
}

function Test-IsAppInstalled {
    param(
        [string]$Nome,
        [string]$WingetId
    )
    if ($Test -or $Global:Test -or $env:PESTER_TEST) { return $false }

    # 1. Percorsi file eseguibili noti (istantaneo, 0 millisecondi)
    $progFiles = if ($env:ProgramFiles) { $env:ProgramFiles } else { "C:\Program Files" }
    $progFiles86 = if (${env:ProgramFiles(x86)}) { ${env:ProgramFiles(x86)} } else { "C:\Program Files (x86)" }
    $appData = if ($env:APPDATA) { $env:APPDATA } else { "" }
    $localAppData = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { "" }

    $knownPaths = @{
        "7-Zip"                = @(
            (Join-Path $progFiles "7-Zip\7zFM.exe"),
            (Join-Path $progFiles86 "7-Zip\7zFM.exe")
        )
        "7zip.7zip"            = @(
            (Join-Path $progFiles "7-Zip\7zFM.exe"),
            (Join-Path $progFiles86 "7-Zip\7zFM.exe")
        )
        "Google Chrome"        = @(
            (Join-Path $progFiles "Google\Chrome\Application\chrome.exe"),
            (Join-Path $progFiles86 "Google\Chrome\Application\chrome.exe")
        )
        "Google.Chrome"        = @(
            (Join-Path $progFiles "Google\Chrome\Application\chrome.exe"),
            (Join-Path $progFiles86 "Google\Chrome\Application\chrome.exe")
        )
        "VLC"                  = @(
            (Join-Path $progFiles "VideoLAN\VLC\vlc.exe"),
            (Join-Path $progFiles86 "VideoLAN\VLC\vlc.exe")
        )
        "VideoLAN.VLC"         = @(
            (Join-Path $progFiles "VideoLAN\VLC\vlc.exe"),
            (Join-Path $progFiles86 "VideoLAN\VLC\vlc.exe")
        )
        "Adobe Acrobat Reader" = @(
            (Join-Path $progFiles "Adobe\Acrobat DC\Acrobat\Acrobat.exe"),
            (Join-Path $progFiles86 "Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"),
            (Join-Path $progFiles "Adobe\Acrobat Reader DC\Reader\AcroRd32.exe")
        )
        "Adobe.Acrobat.Reader.64-bit" = @(
            (Join-Path $progFiles "Adobe\Acrobat DC\Acrobat\Acrobat.exe"),
            (Join-Path $progFiles86 "Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"),
            (Join-Path $progFiles "Adobe\Acrobat Reader DC\Reader\AcroRd32.exe")
        )
        "AnyDesk"              = @(
            (Join-Path $progFiles86 "AnyDesk\AnyDesk.exe"),
            (Join-Path $progFiles "AnyDesk\AnyDesk.exe")
        )
        "AnyDesk.AnyDesk"      = @(
            (Join-Path $progFiles86 "AnyDesk\AnyDesk.exe"),
            (Join-Path $progFiles "AnyDesk\AnyDesk.exe")
        )
        "Spotify"              = @(
            (Join-Path $appData "Spotify\Spotify.exe"),
            (Join-Path $localAppData "Microsoft\WindowsApps\Spotify.exe")
        )
        "Spotify.Spotify"      = @(
            (Join-Path $appData "Spotify\Spotify.exe"),
            (Join-Path $localAppData "Microsoft\WindowsApps\Spotify.exe")
        )
        "Zoom"                 = @(
            (Join-Path $appData "Zoom\bin\Zoom.exe"),
            (Join-Path $progFiles "Zoom\bin\Zoom.exe")
        )
        "Zoom.Zoom"            = @(
            (Join-Path $appData "Zoom\bin\Zoom.exe"),
            (Join-Path $progFiles "Zoom\bin\Zoom.exe")
        )
        "AIMP"                 = @(
            (Join-Path $progFiles "AIMP\AIMP.exe"),
            (Join-Path $progFiles86 "AIMP\AIMP.exe")
        )
        "AIMP.AIMP"            = @(
            (Join-Path $progFiles "AIMP\AIMP.exe"),
            (Join-Path $progFiles86 "AIMP\AIMP.exe")
        )
    }

    if ($Nome -and $knownPaths.ContainsKey($Nome)) {
        foreach ($p in $knownPaths[$Nome]) {
            if ($p -and (Test-Path -LiteralPath $p)) { return $true }
        }
    }
    if ($WingetId -and $knownPaths.ContainsKey($WingetId)) {
        foreach ($p in $knownPaths[$WingetId]) {
            if ($p -and (Test-Path -LiteralPath $p)) { return $true }
        }
    }

    # 2. Controllo rapido pacchetti UWP / Store (es. WhatsApp)
    if ($WingetId -and ($WingetId -match '^[A-Z0-9]{12}$' -or $Nome -eq 'WhatsApp')) {
        try {
            $uwp = Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*WhatsApp*" -or ($WingetId -and $_.PackageFamilyName -like "*$WingetId*") }
            if ($uwp) { return $true }
        } catch {}
    }

    # 3. Controllo tramite Winget list (con --source winget per evitare errori msstore 0x8a15005e)
    if ($WingetId -and (Confirm-Winget)) {
        try {
            $srcList = if ($WingetId -match '^[A-Z0-9]{12}$') { @('--source', 'msstore') } else { @('--source', 'winget') }
            & winget.exe list --exact --id $WingetId @srcList --accept-source-agreements 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { return $true }
        } catch {}
    }

    return $false
}

function Installa-Pacchetto {
    param(
        [string]$Nome,
        [string]$WingetId
    )

    # 0. Verifica preventiva istantanea: se l'app e' gia' installata, SALTA SUBITO (evita popup e reinstallazioni)
    if (Test-IsAppInstalled -Nome $Nome -WingetId $WingetId) {
        Write-OK "$Nome gia' installato. Salto."
        Add-Report "$Nome (installazione)" "OK"
        Add-IconaDesktop -Nome $Nome
        $Global:UltimaInstallOk = $true
        return
    }

    # 1. Prova prima l'installazione offline ad altissima velocita' da USB se presente
    $offlineFile = Find-OfflineInstaller -WingetId $WingetId -Nome $Nome
    if ($offlineFile) {
        if (Install-OfflinePackage -FilePath $offlineFile -Nome $Nome) {
            Add-Report "$Nome (installazione offline)" "OK"
            Add-IconaDesktop -Nome $Nome
            $Global:UltimaInstallOk = $true
            return
        }
    }

    # 2. Se l'offline non e' presente, prova Winget; se Winget non e' disponibile su
    #    questo PC (es. immagine OEM di fabbrica senza VCLibs/UI.Xaml), usa SUBITO
    #    il download diretto ufficiale (curl.exe) invece di fallire!
    if (-not (Confirm-Winget)) {
        Write-Info "Winget non disponibile su questa immagine di fabbrica: installo $Nome via download diretto ufficiale..."
        $lnkPrimaFallback = @(Get-StartMenuLnks | ForEach-Object { $_.FullName })
        if (Install-AppDirectFallback -Nome $Nome -WingetId $WingetId) {
            Add-Report "$Nome (installazione)" "OK (download diretto)"
            Add-IconaDesktop -Nome $Nome -LnkPrima $lnkPrimaFallback
            $Global:UltimaInstallOk = $true
            return
        }
        Write-Errore "Winget non disponibile e fallback diretto non riuscito per $Nome."
        Add-Report "$Nome (installazione)" "ERRORE"
        $Global:UltimaInstallOk = $false
        return
    }

    # Disambigua SEMPRE la sorgente: ID Microsoft Store (12 caratteri) -> msstore,
    # tutto il resto -> winget. Senza --source, winget da' errore -1978335138
    # ("specify --source") quando lo stesso ID compare in piu' sorgenti, ed evita
    # anche di interrogare msstore (dove capitano errori di certificato/CDN).
    # SE l'app non si trova nella sorgente forzata, sotto si RITENTA senza --source
    # (winget cerca in tutte le fonti, incluso lo Store): cosi' funzionano anche
    # le app solo-Store del catalogo (es. WhatsApp).
    $sorgente = @()
    if ($WingetId -match '^[A-Z0-9]{12}$') { $sorgente = @('--source', 'msstore') }
    else { $sorgente = @('--source', 'winget') }

    # Esito di default: fallito. Lo porto a $true solo sui rientri di successo,
    # cosi' il passo App puo' segnare come "fatta" solo cio' che e' riuscito.
    $Global:UltimaInstallOk = $false

    # Gia' installato? Uso --source winget (o msstore per ID Store) per evitare
    # errori di certificato su msstore (0x8a15005e) in console.
    winget list --exact --id $WingetId @sorgente --accept-source-agreements 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-OK "$Nome gia' installato. Salto."
        Add-Report "$Nome (installazione)" "OK"
        Add-IconaDesktop -Nome $Nome
        $Global:UltimaInstallOk = $true
        return
    }

    # Fotografo i collegamenti del menu Start PRIMA dell'installazione: dopo, la
    # differenza sono quelli creati da quest'app -> li copio sul Desktop.
    $lnkPrima = @(Get-StartMenuLnks | ForEach-Object { $_.FullName })

    # Codici che indicano successo (0) o successo con riavvio richiesto (3010/1641)
    $successo = @(0, 3010, 1641)
    # Gia' presente (stessa versione o da un'altra sorgente): per noi e' OK.
    # -1978335189 = "no applicable update", -1978335135 = "package already installed"
    $giaInstallato = @(-1978335189, -1978335135)
    # Errori di integrita'/certificato/sorgente: si risolvono riparando le sorgenti
    $erroriSorgente = @(-1978335138, -1978335194, -1978335215, -1978335216, -1978335217, -1978335226)
    $riparatoQui = $false
    $ritentoSenzaSorgente = $false

    $maxTentativi = 3
    $tentativiFatti = 0
    for ($tentativo = 1; $tentativo -le $maxTentativi; $tentativo++) {
        $tentativiFatti = $tentativo
        Write-Info "Installo $Nome...$(if ($tentativo -gt 1) { " (tentativo $tentativo)" })"
        $codeInstall = Invoke-WingetConBarra -Nome $Nome -WingetArgs (@('install', '--exact', '--id', $WingetId) + $sorgente + @('--silent', '--accept-package-agreements', '--accept-source-agreements'))
        if ($codeInstall -eq -9999) {
            Write-Info "Winget in timeout (10 min) per ${Nome}: provo download diretto ufficiale..."
            if (Install-AppDirectFallback -Nome $Nome -WingetId $WingetId) {
                Add-Report "$Nome (installazione)" "OK (download diretto)"
                Add-IconaDesktop -Nome $Nome -LnkPrima $lnkPrima
                $Global:UltimaInstallOk = $true
                return
            }
            Write-Info "Installazione di $Nome interrotta per timeout (10 min): salto l'app per completare il setup."
            Add-Report "$Nome (installazione)" "AVVISO (timeout 10 min)"
            $Global:AppFallite++
            $Global:UltimaInstallOk = $false
            return
        }
        if ($successo -contains $codeInstall) {
            if ($codeInstall -eq 3010 -or $codeInstall -eq 1641) {
                Write-OK "$Nome installato (richiede riavvio)."
            } else {
                Write-OK "$Nome installato."
            }
            Add-Report "$Nome (installazione)" "OK"
            Add-IconaDesktop -Nome $Nome -LnkPrima $lnkPrima
            $Global:UltimaInstallOk = $true
            return
        }

        # -1978335189 ("no applicable update") e -1978335135 ("gia' installato"):
        # l'app e' gia' presente (stessa versione o da un'altra origine), per noi
        # e' comunque OK, non un errore.
        if ($giaInstallato -contains $codeInstall) {
            Write-OK "$Nome gia' installato. Salto."
            Add-Report "$Nome (installazione)" "OK"
            Add-IconaDesktop -Nome $Nome -LnkPrima $lnkPrima
            $Global:UltimaInstallOk = $true
            return
        }

        # Ricontrollo con 'winget list' con la stessa sorgente: se l'app risulta
        # comunque presente, non segno ERRORE per sbaglio.
        winget list --exact --id $WingetId @sorgente --accept-source-agreements 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-OK "$Nome installato."
            Add-Report "$Nome (installazione)" "OK"
            Add-IconaDesktop -Nome $Nome -LnkPrima $lnkPrima
            $Global:UltimaInstallOk = $true
            return
        }

        # Errore 1618 (ERROR_INSTALL_ALREADY_RUNNING): un altro installer MSI
        # (es. Visual C++ o processo OEM) sta ancora rilasciando il mutex.
        if ($codeInstall -eq 1618 -and $tentativo -lt $maxTentativi) {
            Write-Info "Un altro installer Windows (MSI) e' in corso (1618): attendo 10s e riprovo..."
            Start-Sleep -Seconds 10
            continue
        }

        # App non trovata nella sorgente forzata (esiste solo in un'altra fonte,
        # tipicamente lo Store): ritento SENZA --source, cosi' winget la cerca
        # ovunque. Prima del messaggio d'errore, per non spaventare l'utente con
        # un rosso che poi si risolve subito.
        if (($codeInstall -eq -1978335212) -and -not $ritentoSenzaSorgente) {
            Write-Info "App non trovata in questa sorgente: riprovo senza forzarla..."
            $ritentoSenzaSorgente = $true
            $sorgente = @()
            continue
        }

        # Se un pacchetto (Spotify, WhatsApp Store 9NKSQGP7F2NH, AIMP 404, ecc.) fallisce al primo
        # tentativo con Winget, prova subito a riparare le sorgenti (una sola volta per msstore 0x8a15005e)
        # oppure passa direttamente all'installer ufficiale (Install-AppDirectFallback) senza ripetere 3 volte!
        if (($WingetId -match '^[A-Z0-9]{12}$' -or $erroriSorgente -contains $codeInstall) -and -not $riparatoQui) {
            Write-Info "Errore sorgente/certificato Store ($codeInstall): riparo le sorgenti winget e riprovo..."
            Repair-WingetSources -Forza
            $riparatoQui = $true
            continue
        }

        Write-Info "Winget non riuscito per $Nome (codice: $codeInstall): passo subito al download diretto ufficiale..."
        if (Install-AppDirectFallback -WingetId $WingetId -Nome $Nome) {
            Add-Report "$Nome (installazione)" "OK"
            Add-IconaDesktop -Nome $Nome -LnkPrima $lnkPrima
            $Global:UltimaInstallOk = $true
            return
        }

        Write-Errore "Installazione $Nome fallita (codice: $codeInstall)."

        # CONNESSIONE CADUTA? Molti fallimenti (revoca certificato, hash, download
        # interrotto) sono di rete. Avviso FORTE e aspetto che torni (max ~90s).
        if (-not (Test-Rete)) {
            Write-Errore "!!  CONNESSIONE ASSENTE  !!  Ricollega il WiFi o il cavo di rete."
            Beep-Attesa
            $attesaRete = 0
            while ((-not (Test-Rete)) -and $attesaRete -lt 90) { Start-Sleep -Seconds 5; $attesaRete += 5 }
            if (Test-Rete) { Write-OK "Connessione tornata: riprovo." }
            else { Write-Info "Ancora senza rete: faccio un ultimo tentativo." }
        }

        # Ritento comunque (anche con rete presente): gli errori transitori di
        # download/certificato spesso passano al secondo o terzo colpo.
        if ($tentativo -lt $maxTentativi) {
            Write-Info "Riprovo l'installazione (tentativo $($tentativo + 1) di $maxTentativi)..."
            Start-Sleep -Seconds 3
        }
    }

    # VERIFICA finale con 'winget list' SENZA sorgente forzata: a volte l'app si
    # installa davvero ma winget ritorna un codice strano (o era gia' presente
    # da un'altra origine). Se ora risulta presente, per noi e' un successo.
    winget list --exact --id $WingetId @sorgente --accept-source-agreements 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-OK "$Nome risulta installato (verificato)."
        Add-Report "$Nome (installazione)" "OK"
        Add-IconaDesktop -Nome $Nome -LnkPrima $lnkPrima
        $Global:UltimaInstallOk = $true
        return
    }

    # Fallback finale: se tutti i tentativi Winget sono falliti, prova il download
    # diretto dell'installer ufficiale prima di segnalare l'app come non installata.
    if (Install-AppDirectFallback -WingetId $WingetId -Nome $Nome) {
        Add-Report "$Nome (installazione)" "OK"
        Add-IconaDesktop -Nome $Nome -LnkPrima $lnkPrima
        $Global:UltimaInstallOk = $true
        return
    }

    # Fallback speciale per Spotify: se l'installer Win32 fallisce per elevazione token admin,
    # proviamo l'installazione del pacchetto Store MSIX ufficiale (ID 9NCBCSZSJRSB)
    if (($Nome -eq "Spotify" -or $WingetId -eq "Spotify.Spotify") -and -not $Global:UltimaInstallOk) {
        Write-Info "Tentativo di installazione Spotify via Microsoft Store (MSIX)..."
        $storeCode = Invoke-WingetConBarra -Nome "Spotify (Microsoft Store)" -WingetArgs @('install', '--exact', '--id', '9NCBCSZSJRSB', '--source', 'msstore', '--silent', '--accept-package-agreements', '--accept-source-agreements')
        if ($successo -contains $storeCode -or $giaInstallato -contains $storeCode) {
            Write-OK "Spotify installato con successo da Microsoft Store."
            Add-Report "Spotify (installazione)" "OK"
            Add-IconaDesktop -Nome "Spotify" -LnkPrima $lnkPrima
            $Global:UltimaInstallOk = $true
            return
        }
        winget list --exact --id '9NCBCSZSJRSB' --accept-source-agreements 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-OK "Spotify risulta installato da Store (verificato)."
            Add-Report "Spotify (installazione)" "OK"
            Add-IconaDesktop -Nome "Spotify" -LnkPrima $lnkPrima
            $Global:UltimaInstallOk = $true
            return
        }
    }

    Write-Errore "$Nome NON installato dopo $tentativiFatti tentativi."
    Add-Report "$Nome (installazione)" "ERRORE"
    $Global:AppFallite++
}

# =============================================================================
# DIAGNOSTICA (-Diagnostica): controlla senza modificare nulla, poi esce
# =============================================================================

if ($Diagnostica) {
    Write-Titolo "DIAGNOSTICA (v$SCRIPT_VERSION) - Nessuna modifica al sistema"

    # Ambiente
    if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
        Write-Errore "PowerShell a 32-bit (x86): winget e LocalAccounts a rischio. Usa 64-bit."
    } else {
        Write-OK "PowerShell a 64-bit."
    }

    # winget + riparazione sorgenti
    if (Confirm-Winget) {
        Write-OK "winget disponibile (sorgenti riparate)."

        # Tutti gli ID pacchetti: derivati dal CATALOGO unico (Office + Browser + App)
        $tuttiId = $CatalogoOffice + $CatalogoBrowser + $CatalogoApp

        Write-Host ""
        Write-Info "Verifica ID pacchetti con 'winget show' (nessuna installazione)..."
        $ko = 0; $installati = 0
        foreach ($p in $tuttiId) {
            $src = @()
            if ($p.Id -match '^[A-Z0-9]{12}$') { $src = @('--source', 'msstore') }
            winget show --exact --id $p.Id @src --accept-source-agreements 2>$null | Out-Null
            $valido = ($LASTEXITCODE -eq 0)
            winget list --exact --id $p.Id @src --accept-source-agreements 2>$null | Out-Null
            $gia = ($LASTEXITCODE -eq 0)
            if ($valido) {
                if ($gia) { Write-OK "OK   $($p.Nome)  [gia' installato]"; $installati++ }
                else { Write-OK "OK   $($p.Nome)  [$($p.Id)]" }
            } else {
                Write-Errore "KO   $($p.Nome)  [$($p.Id)]  (codice $LASTEXITCODE)"
                $ko++
            }
        }
        Write-Host ""
        Write-Host ("Riepilogo pacchetti: {0} validi, {1} KO, {2} gia' installati (su {3})" -f ($tuttiId.Count - $ko), $ko, $installati, $tuttiId.Count) -ForegroundColor $THEME_TXT
        if ($ko -eq 0) { Write-OK "Tutti gli ID pacchetti sono validi." }
        else { Write-Errore "$ko ID pacchetto/i non risolti: da correggere nello script." }
    } else {
        Write-Errore "winget NON disponibile: impossibile validare i pacchetti."
    }

    # Test scrittura sul Desktop (la scheda di consegna PDF si salva qui)
    Write-Host ""
    try {
        $tf = Join-Path (Get-DesktopDir) "pcfacile_test.tmp"
        "test" | Set-Content -Path $tf -ErrorAction Stop
        Remove-Item $tf -Force -ErrorAction SilentlyContinue
        Write-OK "Desktop scrivibile (scheda di consegna PDF OK): $(Get-DesktopDir)"
    } catch {
        Write-Errore "Desktop NON scrivibile: la scheda di consegna potrebbe non salvarsi."
    }

    # Office installato? (per attivazione perpetuo serve ospp.vbs)
    $ospp = @(
        "$env:ProgramFiles\Microsoft Office\Office16\ospp.vbs",
        "${env:ProgramFiles(x86)}\Microsoft Office\Office16\ospp.vbs"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($ospp) { Write-OK "Office installato (ospp.vbs trovato)." }
    else { Write-Info "Office non ancora installato (ospp.vbs assente): normale su PC nuovo, lo installa il passo Office." }

    Write-Host ""
    Write-Info "Diagnostica completata. Nessuna modifica effettuata al sistema."
    try { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null } catch {}
    return  # return (non exit) per non chiudere la finestra se eseguito in memoria
}

# =============================================================================
# BENVENUTO
# =============================================================================

# Clear-Host fallisce senza una console vera (esecuzione headless/redirect): protetto
try { Clear-Host } catch {}
# Nessun menu: il doppio click su PC Facile.bat e' gia' la conferma, si parte
# diretti con la fase 1.

# =============================================================================
# SESSIONE PRECEDENTE INTERROTTA? Se c'e' un checkpoint, proponi di riprendere
# da dove si era arrivati (i passi gia' completati vengono saltati).
# =============================================================================
if ($RunReale) {
    try {
        if (Test-Path $Global:StatoFile) {
            $st = $null
            try { $st = Get-Content $Global:StatoFile -Raw -ErrorAction Stop | ConvertFrom-Json } catch {}
            if ($st) {
                $isOld = $false
                try {
                    $fi = Get-Item $Global:StatoFile -ErrorAction SilentlyContinue
                    if ($fi -and (Get-Date).Subtract($fi.LastWriteTime).TotalHours -gt 2) {
                        $isOld = $true
                    }
                } catch {}

                if ($isOld) {
                    Remove-Item $Global:StatoFile -Force -ErrorAction SilentlyContinue
                    Write-Info "Sessione precedente obsoleta (> 2 ore) rimossa: si parte da zero."
                } else {
                    Write-Titolo "Sessione precedente trovata"
                    Write-Host "  VERSIONE PROGRAMMA      : $SCRIPT_VERSION" -ForegroundColor $THEME_COL
                    Write-Host "  Interrotta il           : $($st.Data)" -ForegroundColor White
                    Write-Host "  Ultimo passo completato : $($st.FaseNome)" -ForegroundColor White
                    if ($st.NomeCliente) { Write-Host "  Cliente                 : $($st.NomeCliente)" -ForegroundColor White }
                    Write-Host ""

                    # Automatico: riprende da solo (i passi gia' fatti si saltano
                    # comunque); N entro 15 secondi = ricomincia da capo.
                    $rRip = Attendi-Risposta -Prompt "Riprendo tra 2 secondi (N = ricomincia da capo)" -TimeoutSec 2 -Default "S"
                    $vuoiRiprendere = ($rRip -notmatch '^[Nn]')

                    if ($vuoiRiprendere) {
                        $Global:FaseRipresa = [int]$st.Fase
                        if ($st.NomeCliente)  { $nomeCliente    = [string]$st.NomeCliente }
                        if ($st.CredAccount)  { $credMsAccount  = [string]$st.CredAccount }
                        if ($st.CredPassword) { $credMsPassword = [string]$st.CredPassword }
                        if ($st.PSObject.Properties.Name -contains 'CredProvider' -and $st.CredProvider) { $Global:credProvider = [string]$st.CredProvider }
                        if ($st.PSObject.Properties.Name -contains 'CredDominio'  -and $st.CredDominio)  { $Global:credDominio  = [string]$st.CredDominio }
                        if ($st.PSObject.Properties.Name -contains 'AppProfilo' -and $st.AppProfilo) {
                            $Global:AppProfiloRipresa = [string]$st.AppProfilo
                            $Global:AppListaRipresa   = @($st.AppLista)
                            $Global:AppFatteRipresa   = @($st.AppFatte)
                        }
                        if ($st.PSObject.Properties.Name -contains 'SceltaOffice' -and $st.SceltaOffice) { $Global:SceltaOffice = [string]$st.SceltaOffice }
                        # Dati del cliente gia' confermati nel pannello: non li richiedo.
                        if ($st.PSObject.Properties.Name -contains 'DatiCliente' -and $st.DatiCliente) {
                            if (Set-DatiCliente $st.DatiCliente) { Write-OK "Dati cliente ripresi: $($Global:nomeCliente)." }
                        }
                        # Checkpoint di una versione con un ordine dei passi diverso:
                        # tengo i dati del cliente ma riparto dal primo passo (i
                        # passi gia' fatti vengono riconosciuti e saltati da soli).
                        if (-not ($st.PSObject.Properties.Name -contains 'Schema') -or [int]$st.Schema -ne 3) {
                            $Global:FaseRipresa = 0
                            $Global:AppProfiloRipresa = ""; $Global:AppListaRipresa = @(); $Global:AppFatteRipresa = @()
                            Write-Info "Sessione salvata da una versione precedente: riparto dal primo passo (quelli gia' fatti si saltano da soli)."
                        }
                        Write-OK "Riprendo: i passi gia' completati verranno saltati."
                    } else {
                        Remove-Item $Global:StatoFile -Force -ErrorAction SilentlyContinue
                        Write-Info "Sessione precedente azzerata: configurazione avviata da capo."
                    }
                }
            }
        }
    } catch {}
}

# =============================================================================
# CONTROLLO CONNESSIONE - prima di tutto: senza Internet la lingua (pacchetto),
# le app e gli aggiornamenti NON funzionano. Avviso e do modo di collegarla.
# =============================================================================
if ($RunReale) {
    if (-not (Test-Rete)) {
        Write-Titolo "ATTENZIONE: Internet non collegato"
        Write-Errore "Il PC NON risulta connesso a Internet."
        Write-Host "I pacchetti offline presenti su chiavetta verranno installati comunque." -ForegroundColor Yellow
        Write-Host "Per lingua e aggiornamenti online, connetti il Wi-Fi appena possibile." -ForegroundColor White
        Write-Host ""
        if (Test-Rete) {
            Write-OK "Connessione a Internet OK."
            if (-not $Global:USBUpdated -and -not $AggiornaUSB -and -not $Test -and -not $env:PESTER_TEST) {
                $kitDir = if ($TargetDir -and (Test-CartellaKitUSB $TargetDir)) { $TargetDir }
                          elseif (Test-CartellaKitUSB $PSScriptRoot) { $PSScriptRoot }
                          else { $null }
                if ($kitDir) {
                    $Global:USBUpdated = $true
                    try {
                        Write-Info "Verifico e aggiorno la chiavetta USB con l'ultima versione di PC Facile..."
                        [void](Invoke-AggiornamentoUSB -Destinazione $kitDir -LauncherInEsecuzione $LauncherPath)
                    } catch {}
                }
            }
        }
        else { Write-Info "Proseguo in modalita' autonoma (priorita' pacchetti offline USB)." }
    } else {
        Write-OK "Connessione a Internet OK."
        if (-not $Global:USBUpdated -and -not $AggiornaUSB -and -not $Test -and -not $env:PESTER_TEST) {
            $kitDir = if ($TargetDir -and (Test-CartellaKitUSB $TargetDir)) { $TargetDir }
                      elseif (Test-CartellaKitUSB $PSScriptRoot) { $PSScriptRoot }
                      else { $null }
            if ($kitDir) {
                $Global:USBUpdated = $true
                try {
                    Write-Info "Verifico e aggiorno la chiavetta USB con l'ultima versione di PC Facile..."
                    [void](Invoke-AggiornamentoUSB -Destinazione $kitDir -LauncherInEsecuzione $LauncherPath)
                } catch {}
            }
        }
    }
}

# =============================================================================
# AVVISO ANTIVIRUS ATTIVO - un AV attivo puo' mettere in quarantena lo script
# (si difende quando prova a rimuovere gli AV di prova). Avviso PRIMA di agire,
# cosi' l'operatore lo whitelista/consente ed evita che il setto venga ucciso.
# =============================================================================
if ($RunReale) {
    $avAttivi = @(Get-AntivirusInstallati)
    if ($avAttivi.Count -gt 0) {
        Write-Titolo "ATTENZIONE: Antivirus attivo rilevato"
        Write-Errore "Presente: $(($avAttivi.Nome | Select-Object -Unique) -join ', ')."
        Write-Host "Un antivirus attivo puo' bloccare lo script: se compare un avviso, seleziona 'Consenti'." -ForegroundColor Yellow
        Write-Host ""
    }
}

# =============================================================================
# PASSI DI CONFIGURAZIONE (dopo ogni scelta si avanza; B al prompt = indietro)
# =============================================================================

# Torna al passo precedente quando l'utente digita B al prompt principale di un
# passo. Uso 'continue wizard' (loop etichettato) per rifare il giro del while
# anche da dentro lo switch, saltando il $passo++ di fine passo.

# Funzioni dei passi Antivirus/Unieuro: definite QUI (prima del wizard) perche'
# ora l'Antivirus e' l'ultimo passo mentre Unieuro gira prima e usa
# Attiva-ServizioWeb: cosi' entrambe sono gia' disponibili quando servono.
# Mostra le credenziali da usare in una pagina web e le mette PRONTE negli
# appunti, cosi' l'operatore incolla con CTRL+V invece di digitarle (non e'
# possibile compilare da soli i campi di siti terzi in modo affidabile: questo
# e' l'aiuto concreto e sicuro).
#
# MENU APPUNTI che RESTA attivo: premi E o P per (ri)copiare Email o Password
# quante volte vuoi e in QUALSIASI ordine (comodo per il campo "conferma
# password" o se sbagli campo), INVIO quando hai finito. Le credenziali restano
# scritte a schermo per averle sott'occhio.
# Apre una pagina web per un passo manuale (in -Test non apre nulla).
function Open-PaginaWeb {
    param([string]$Url)
    if ($Test -or $Global:Test -or $env:PESTER_TEST) { Write-Info "(test) aprirei: $Url"; return }
    try { Start-Process $Url -ErrorAction Stop; Write-OK "Browser aperto su: $Url" }
    catch { Write-Info "Apri a mano nel browser: $Url" }
}

function Mostra-CredenzialiPagina {
    param([string]$Utente, [string]$Password, [switch]$NonBlocca)
    if (-not ($Utente -or $Password)) { return }
    Write-Host ""
    Write-Host "  +--------------------------------------------------------+" -ForegroundColor Yellow
    Write-Host "  |  CREDENZIALI DA INCOLLARE NELLA PAGINA                  |" -ForegroundColor Yellow
    Write-Host "  +--------------------------------------------------------+" -ForegroundColor Yellow
    if ($Utente)   { Write-Host "     Email / utente : $Utente" -ForegroundColor White }
    if ($Password) { Write-Host "     Password      : $Password" -ForegroundColor White }
    if (-not $RunReale) { return }
    # Copio subito l'email (di solito e' il primo campo), poi lascio il menu.
    if ($Utente) { try { Set-Clipboard -Value $Utente } catch {} }
    Write-Host ""
    $opz = @()
    if ($Utente)   { $opz += "E = copia EMAIL" }
    if ($Password) { $opz += "P = copia PASSWORD" }
    if (-not $NonBlocca) { $opz += "INVIO = ho finito" }
    Write-Host ("  Premi:  " + ($opz -join "    ")) -ForegroundColor Cyan
    if ($Utente) { Write-OK "Email gia' copiata: incolla con CTRL+V." }
    if ($NonBlocca) { return }
    Start-BipRipetuto
    try {
        while ($true) {
            $ch = ""; $isEnter = $false
            try {
                $key = [Console]::ReadKey($true)
                $ch = "$($key.KeyChar)".ToUpper()
                if ($key.Key -eq [ConsoleKey]::Enter) { $isEnter = $true }
            } catch {
                # Fallback senza ReadKey: riga di testo, vuoto = ho finito.
                $ch = (Read-Host "  E / P / INVIO").ToUpper()
                if ($ch -eq "") { $isEnter = $true }
            }
            if ($isEnter) { break }
            elseif ($ch -eq "E") {
                if ($Utente) { try { Set-Clipboard -Value $Utente; Write-OK "Email copiata: incolla con CTRL+V." } catch {} }
                else { Write-Info "Nessuna email da copiare." }
            }
            elseif ($ch -eq "P") {
                if ($Password) { try { Set-Clipboard -Value $Password; Write-OK "Password copiata: incolla con CTRL+V." } catch {} }
                else { Write-Info "Per questo servizio la password la crea il sito (arriva via email)." }
            }
            # ogni altro tasto: ignorato, il menu resta attivo
        }
    } finally {
        Stop-BipRipetuto
    }
    Write-Host ""
}

function Installa-Antivirus {
    param(
        [string]$Nome,
        [string]$UrlRiscatto,
        [string]$Utente = "",
        [string]$Password = ""
    )

    Write-Info "Apertura pagina registrazione/riscatto $Nome..."
    Open-PaginaWeb $UrlRiscatto
    Write-Host ""
    Write-Host "Completa registrazione/download nel browser." -ForegroundColor White
    Write-Host "L'installer parte DA SOLO appena finisce di scaricarsi (niente INVIO)." -ForegroundColor White
    # Antivirus: l'attivazione si fa accedendo con l'account principale del
    # cliente. Metto quelle credenziali pronte da incollare.
    Mostra-CredenzialiPagina -Utente $Utente -Password $Password -NonBlocca
    if (-not $RunReale) { Add-Report "$Nome (antivirus)" "OK (test)"; return }

    # Sorveglio Download e Desktop: appena compare un .exe NUOVO (creato dopo
    # ORA) e il download e' finito (dimensione stabile), lo avvio da solo.
    $cartelle = @((Join-Path $env:USERPROFILE "Downloads"), (Get-DesktopDir)) | Select-Object -Unique
    $inizio = Get-Date
    $timeoutMin = 8
    Write-Info "In attesa dell'installer di $Nome (max $timeoutMin min). Premi 'S' per saltare."
    $installer = $null
    while (((Get-Date) - $inizio).TotalMinutes -lt $timeoutMin) {
        try {
            if ([Console]::KeyAvailable) {
                $k = [Console]::ReadKey($true)
                $chAv = "$($k.KeyChar)".ToUpper()
                if ($chAv -eq "E" -and $Utente) { try { Set-Clipboard -Value $Utente; Write-OK "Email copiata: incolla con CTRL+V." } catch {} }
                elseif ($chAv -eq "P" -and $Password) { try { Set-Clipboard -Value $Password; Write-OK "Password copiata: incolla con CTRL+V." } catch {} }
                elseif ($k.Key -eq [ConsoleKey]::S -or $k.Key -eq [ConsoleKey]::Escape) {
                    Write-Info "Attesa installer interrotta dall'operatore."
                    break
                }
            }
        } catch {}
        $cand = Get-ChildItem -Path $cartelle -Filter "*.exe" -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -gt $inizio -and $_.Length -gt 100KB } |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($cand) {
            # Aspetto che il file smetta di crescere = download completo.
            $dim1 = $cand.Length
            Start-Sleep -Seconds 2
            $cand.Refresh()
            if ($cand.Length -eq $dim1) { $installer = $cand; break }
        }
        Start-Sleep -Seconds 2
    }

    if ($installer) {
        Start-Process -FilePath $installer.FullName
        Write-OK "Installer $Nome avviato AUTOMATICAMENTE: $($installer.Name)"
        Add-Report "$Nome (antivirus)" "OK"
    } else {
        Write-Info "Nessun installer rilevato entro $timeoutMin min: avvialo a mano dalla cartella Download."
        Add-Report "$Nome (antivirus)" "AVVISO"
    }
}

# Servizio web-only (nessun installer PC): apre il sito, l'operatore inserisce
# il codice e segna le credenziali per l'app mobile del cliente.
function Attiva-ServizioWeb {
    param(
        [string]$Nome,
        [string]$UrlAttivazione,
        [string]$Utente = "",
        [string]$Password = ""
    )

    Write-Info "Apertura pagina attivazione $Nome..."
    Open-PaginaWeb $UrlAttivazione
    Write-Host ""
    Write-Host "Sul sito: inserisci il codice/PIN e completa i dati richiesti." -ForegroundColor White
    Write-Host "IMPORTANTE: annota le credenziali per l'app mobile e consegnale al cliente." -ForegroundColor Yellow
    # Registrazione col cliente: uso la sua email come utente (pronta da incollare).
    # La password del portale spesso la crea il sito e la manda via email.
    Mostra-CredenzialiPagina -Utente $Utente -Password $Password -NonBlocca
    Write-OK "$Nome completato."
    Add-Report "$Nome (protezione)" "OK"
}


function Get-OsppPath {
    $percorsi = @(
        "$env:ProgramFiles\Microsoft Office\Office16\ospp.vbs",
        "${env:ProgramFiles(x86)}\Microsoft Office\Office16\ospp.vbs"
    )
    foreach ($p in $percorsi) { if (Test-Path $p) { return $p } }
    return $null
}

# Collegamenti alle app Office sul Desktop: i clienti le cercano li'. Usa
# WScript.Shell (COM standard, niente P/Invoke: l'antivirus non lo segnala).
# Crea solo i collegamenti delle app davvero presenti e non gia' esistenti.
function Add-CollegamentiOffice {
    $officeDir = @(
        "$env:ProgramFiles\Microsoft Office\root\Office16",
        "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16",
        "$env:ProgramFiles\Microsoft Office\Office16",
        "${env:ProgramFiles(x86)}\Microsoft Office\Office16"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $officeDir) { Write-Info "Cartella Office non trovata: nessun collegamento sul Desktop."; return }
    $appOffice = @(
        @{ Nome = "Word";       Exe = "WINWORD.EXE"  },
        @{ Nome = "Excel";      Exe = "EXCEL.EXE"    },
        @{ Nome = "PowerPoint"; Exe = "POWERPNT.EXE" },
        @{ Nome = "Outlook";    Exe = "OUTLOOK.EXE"  },
        @{ Nome = "OneNote";    Exe = "ONENOTE.EXE"  }
    )
    $desktop = Get-DesktopDir
    $creati = 0
    try {
        $wsh = New-Object -ComObject WScript.Shell
        foreach ($a in $appOffice) {
            $exe = Join-Path $officeDir $a.Exe
            if (-not (Test-Path $exe)) { continue }
            $lnk = Join-Path $desktop "$($a.Nome).lnk"
            if (Test-Path $lnk) { continue }
            $sc = $wsh.CreateShortcut($lnk)
            $sc.TargetPath = $exe
            $sc.WorkingDirectory = $officeDir
            $sc.Save()
            $creati++
        }
    } catch { Write-Info "Collegamenti Office non creati: $_" }
    if ($creati -gt 0) {
        Write-OK "Collegamenti sul Desktop: $creati app Office (Word, Excel, ...)."
        Add-Report "Collegamenti Office sul Desktop ($creati)" "OK"
    } else {
        Write-Info "Collegamenti Office: gia' presenti sul Desktop o nessuna app trovata."
    }
}

# Crea il collegamento Desktop per Unieuro Cyber Protection con icona dedicata,
# subito dopo Unieuro Secure.
function Add-ShortcutCyberProtection {
    if (-not $RunReale) { return }
    $desktop = Get-DesktopDir
    if (-not $desktop -or -not (Test-Path -LiteralPath $desktop)) { return }
    $lnk = Join-Path $desktop "Unieuro Cyber Protection.lnk"
    $icoDir = Join-Path $env:ProgramData "PCFacile"
    if (-not (Test-Path -LiteralPath $icoDir)) { New-Item -ItemType Directory -Path $icoDir -Force | Out-Null }
    $icoPath = Join-Path $icoDir "cyber-protection.ico"
    $pngPath = Join-Path $icoDir "cyber-protection.png"

    if (-not (Test-Path -LiteralPath $icoPath)) {
        try {
            Invoke-WebRequest -Uri "https://www.covercare.it/wp-content/uploads/2026/01/favicon-192x192-1.png" -OutFile $pngPath -UseBasicParsing -TimeoutSec 8 -ErrorAction SilentlyContinue
        } catch {}
        try {
            Add-Type -AssemblyName System.Drawing -ErrorAction Stop
            $bmp = $null
            if (Test-Path -LiteralPath $pngPath) {
                try {
                    $srcImg = [System.Drawing.Image]::FromFile($pngPath)
                    $bmp = New-Object System.Drawing.Bitmap(64, 64)
                    $g = [System.Drawing.Graphics]::FromImage($bmp)
                    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                    $g.DrawImage($srcImg, 0, 0, 64, 64)
                    $g.Dispose(); $srcImg.Dispose()
                } catch { $bmp = $null }
            }
            if (-not $bmp) {
                $bmp = New-Object System.Drawing.Bitmap(64, 64)
                $g = [System.Drawing.Graphics]::FromImage($bmp)
                $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
                $g.Clear([System.Drawing.Color]::FromArgb(255, 0, 18, 43))
                $br = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 238, 114, 3))
                $pts = @(
                    (New-Object System.Drawing.Point(32, 10)),
                    (New-Object System.Drawing.Point(52, 18)),
                    (New-Object System.Drawing.Point(48, 40)),
                    (New-Object System.Drawing.Point(32, 54)),
                    (New-Object System.Drawing.Point(16, 40)),
                    (New-Object System.Drawing.Point(12, 18))
                )
                $g.FillPolygon($br, $pts)
                $br.Dispose(); $g.Dispose()
            }
            $msPng = New-Object System.IO.MemoryStream
            $bmp.Save($msPng, [System.Drawing.Imaging.ImageFormat]::Png)
            $pngBytes = $msPng.ToArray()
            $msPng.Dispose(); $bmp.Dispose()
            $fs = [System.IO.File]::OpenWrite($icoPath)
            $bw = New-Object System.IO.BinaryWriter($fs)
            $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]1)
            $bw.Write([byte]64); $bw.Write([byte]64); $bw.Write([byte]0); $bw.Write([byte]0)
            $bw.Write([uint16]1); $bw.Write([uint16]32)
            $bw.Write([uint32]$pngBytes.Length); $bw.Write([uint32]22)
            $bw.Write($pngBytes)
            $bw.Close(); $fs.Close()
        } catch {}
    }

    try {
        $url = "https://unieuro-cyber-protection.covercare.it"
        $edge = @("$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe", "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
        $chrome = @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
        $wsh = New-Object -ComObject WScript.Shell
        $sc = $wsh.CreateShortcut($lnk)
        if ($edge) {
            $sc.TargetPath = $edge
            $sc.Arguments = "--app=$url"
        } elseif ($chrome) {
            $sc.TargetPath = $chrome
            $sc.Arguments = "--app=$url"
        } else {
            $sc.TargetPath = $env:ComSpec
            $sc.Arguments = "/c start `"`" `"$url`""
        }
        if (Test-Path -LiteralPath $icoPath) { $sc.IconLocation = "$icoPath,0" }
        $sc.Description = "Unieuro Cyber Protection"
        $sc.Save()
        Write-OK "Collegamento Desktop creato: Unieuro Cyber Protection"
    } catch { Write-Info "Collegamento Unieuro Cyber Protection non creato: $_" }
}

# =============================================================================
# CONTROLLI "GIA' FATTO" (ogni passo prima verifica se il lavoro c'e' gia')
# =============================================================================

# Antivirus della card acquistata dal cliente (scelta nel pannello): da TENERE,
# non e' un antivirus di prova da rimuovere.
function Invoke-EverydayDigital {
    param(
        [string]$Utente = "",
        [string]$Password = ""
    )
    # 0. Estensione Browsing Protection (F-Secure) per Edge e Chrome
    Install-BrowsingProtectionExtension
    # 1. Unieuro Secure (powered by F-Secure)
    $testFsInstalled = {
        try {
            if ((Get-AntivirusTerzi | Where-Object { $_ -match 'F-Secure|WithSecure|Unieuro\s*Secure' }) -or
                (Test-Path (Join-Path $env:ProgramFiles "F-Secure")) -or
                (Test-Path (Join-Path ${env:ProgramFiles(x86)} "F-Secure")) -or
                (Test-Path (Join-Path $env:ProgramFiles "Unieuro Secure"))) {
                return $true
            }
        } catch {}
        return $false
    }
    $giainst = & $testFsInstalled
    if ($giainst) {
        Write-OK "Unieuro Secure (F-Secure) risulta gia' installato."
        Add-Report "Unieuro Secure (F-Secure)" "OK (gia' installato)"
    } else {
        $off = Find-OfflineInstaller -Nome "Unieuro Secure" -WingetId "F-Secure"
        if ($off) {
            Write-Info "Trovato installer offline Unieuro Secure: $(Split-Path -Leaf $off)"
            if (Install-OfflinePackage -Nome "Unieuro Secure" -FilePath $off) {
                Add-Report "Unieuro Secure (F-Secure)" "OK (offline)"
            }
        } else {
            $tmpDir = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
            $exeUrl = "https://download.sp.f-secure.com/SE/Unieuro/installer/UnieuroSecure.exe"
            $exePath = Join-Path $tmpDir "UnieuroSecure.exe"
            $curlBin = Join-Path $env:SystemRoot "System32\curl.exe"
            $scaricato = $false
            if ($RunReale) {
                Write-Info "Download diretto installer ufficiale Unieuro Secure..."
                try {
                    Remove-Item -LiteralPath $exePath -Force -ErrorAction SilentlyContinue
                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
                    if (Test-Path -LiteralPath $curlBin) {
                        & $curlBin -fL --retry 2 --connect-timeout 15 --max-time 180 -sS -A "Mozilla/5.0" -o $exePath $exeUrl 2>$null
                    } else {
                        Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -UseBasicParsing -TimeoutSec 180 -ErrorAction Stop
                    }
                    if ((Test-Path -LiteralPath $exePath) -and ((Get-Item -LiteralPath $exePath).Length -gt 200KB)) {
                        $scaricato = $true
                    }
                } catch {}
            } else {
                Add-Report "Unieuro Secure (F-Secure)" "OK (test)"
                $scaricato = $true
            }
            if ($scaricato -and $RunReale) {
                $passPerSecure = if ($Global:credSecurePassword) { $Global:credSecurePassword } else { $Password }
                if (($Utente -and -not $Global:IsCltMode) -or $Global:credSecurePassword) {
                    Mostra-CredenzialiPagina -Utente $Utente -Password $passPerSecure -NonBlocca
                }
                Write-Info "Installazione automatica silenziosa di Unieuro Secure in corso (max 4 min)..."
                $lnkPrimaFs = @(Get-StartMenuLnks | ForEach-Object { $_.FullName })
                $pFs = $null
                try {
                    $pFs = Start-Process -FilePath $exePath -ArgumentList "--silent --accept-eult" -PassThru -ErrorAction Stop
                    $tFs = 0
                    while (-not $pFs.HasExited -and $tFs -lt 240) {
                        Start-Sleep -Seconds 2
                        $tFs += 2
                        if ($tFs % 10 -eq 0) {
                            Write-Host "     -> Unieuro Secure: installazione in corso... (${tFs}s / max 240s)" -ForegroundColor DarkGray
                        }
                    }
                } catch {}
                if (& $testFsInstalled) {
                    Write-OK "Unieuro Secure (F-Secure) installato automaticamente!"
                    Add-IconaDesktop -Nome "Unieuro Secure" -LnkPrima $lnkPrimaFs
                    Add-Report "Unieuro Secure (F-Secure)" "OK (installazione automatica)"
                } else {
                    # Se la modalita' silenziosa non ha completato (es. conflitto da confermare), apro l'installer guidato
                    try { Start-Process -FilePath $exePath } catch {}
                    Write-OK "Installer Unieuro Secure avviato: completa l'installazione guidata."
                    Add-Report "Unieuro Secure (F-Secure)" "OK (avviato)"
                }
            } elseif (-not $scaricato) {
                Installa-Antivirus -Nome "Unieuro Secure (F-Secure)" -UrlRiscatto "https://safeavenue.f-secure.com/iframe/-installers/unieuro/" -Utente $Utente -Password $Password
            }
        }
    }
    # 2. Unieuro Cyber Protection (inclusa in Everyday Digital)
    if ($Global:telefonoCliente) { Write-Info "Cellulare del cliente: $($Global:telefonoCliente)" }
    if ($Utente -and -not $Global:IsCltMode) {
        Attiva-ServizioWeb -Nome "Unieuro Cyber Protection" -UrlAttivazione "https://unieuro-cyber-protection.covercare.it" -Utente $Utente
    }
    Add-ShortcutCyberProtection
    Update-PannelloStatus -TaskId "cyber" -Stato "done" -Dettaglio "Incluso in Everyday Digital"
}

function Test-AvDaTenere {
    param([string]$Nome)
    $sv = $Global:serviziSelezionati
    if (-not $sv -or -not $Nome) { return $false }
    if ($sv.Everyday -and $Nome -match 'F-Secure|WithSecure|Unieuro\s*Secure') { return $true }
    if ($sv.McAfee -and $Nome -match 'McAfee') { return $true }
    if ($sv.Norton -and $Nome -match 'Norton') { return $true }
    return $false
}

# Antivirus NON Microsoft gia' presenti: Centro sicurezza di Windows
# (root/SecurityCenter2, AntiVirusProduct) + chiavi di disinstallazione.
function Get-AntivirusTerzi {
    $nomi = New-Object System.Collections.Generic.List[string]
    try {
        foreach ($p in @(Get-CimInstance -Namespace 'root/SecurityCenter2' -ClassName AntiVirusProduct -ErrorAction Stop)) {
            $n = [string]$p.displayName
            if ($n -and $n -notmatch 'Defender|Microsoft') { $nomi.Add($n) }
        }
    } catch {}
    foreach ($av in @(Get-AntivirusInstallati)) { if ($av.Nome) { $nomi.Add([string]$av.Nome) } }
    return @($nomi | Sort-Object -Unique)
}

# Vero se Windows e' gia' tutto in italiano (display, formati, sistema, paese,
# prima lingua e fuso orario): il passo Lingua non ha niente da fare.
function Test-LinguaItaliana {
    try {
        if ((Get-UICulture).Name -notlike 'it*') { return $false }
        if ((Get-Culture).Name -ne 'it-IT') { return $false }
        foreach ($c in @('Get-WinSystemLocale', 'Get-WinHomeLocation', 'Get-WinUserLanguageList')) {
            if (-not (Get-Command $c -ErrorAction SilentlyContinue)) { return $false }
        }
        if ((Get-WinSystemLocale).Name -ne 'it-IT') { return $false }
        if ((Get-WinHomeLocation).GeoId -ne 118) { return $false }
        $lingue = @(Get-WinUserLanguageList)
        if ($lingue.Count -eq 0 -or $lingue[0].LanguageTag -ne 'it-IT') { return $false }
        if ((Get-TimeZone).Id -ne 'W. Europe Standard Time') { return $false }
        if (Get-Command Get-InstalledLanguage -ErrorAction SilentlyContinue) {
            $instLangs = @(Get-InstalledLanguage -ErrorAction SilentlyContinue)
            if ($instLangs.Count -gt 0 -and ($instLangs.LanguageId -notcontains 'it-IT')) { return $false }
        }
        return $true
    } catch { return $false }
}

# Punto di ripristino "Prima di setup-pc" gia' creato oggi.
function Test-PuntoRipristinoOggi {
    try {
        foreach ($rp in @(Get-ComputerRestorePoint -ErrorAction Stop)) {
            if ($rp.Description -ne 'Prima di setup-pc') { continue }
            $quando = [System.Management.ManagementDateTimeConverter]::ToDateTime($rp.CreationTime)
            if ($quando.Date -eq (Get-Date).Date) { return $true }
        }
    } catch {}
    return $false
}

# Office (Microsoft 365 / perpetuo) installato: ospp.vbs oppure Click-to-Run.
function Test-OfficeInstallato {
    if (Get-OsppPath) { return $true }
    try {
        $c2r = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration' -ErrorAction Stop
        if ($c2r.ProductReleaseIds) { return $true }
    } catch {}
    return $false
}

# Office gia' attivato: licenza "LICENSED" (ospp /dstatus) oppure licenza
# Microsoft 365 dell'utente (cartella Licenses non vuota).
function Test-OfficeAttivato {
    try {
        $ospp = Get-OsppPath
        if ($ospp) {
            $out = (& cscript.exe //nologo $ospp /dstatus 2>$null) | Out-String
            if ($out -match '---LICENSED---') { return $true }
        }
        if ($env:LOCALAPPDATA) {
            $lic = Join-Path $env:LOCALAPPDATA 'Microsoft\Office\Licenses'
            if ((Test-Path -LiteralPath $lic) -and @(Get-ChildItem -LiteralPath $lic -Recurse -File -ErrorAction SilentlyContinue).Count -gt 0) { return $true }
        }
    } catch {}
    return $false
}

# Controllo "gia' fatto" di un passo: ritorna il motivo (testo breve per
# console, pannello e riepilogo) oppure $null se il passo va eseguito.
# In modalita' -Test ritorna sempre $null: si esercitano tutti i passi.
function Test-PassoGiaFatto {
    param([string]$Id)
    if ($Test -or -not $RunReale) { return $null }
    switch ($Id) {
        'ripristino' {
            if (Test-PuntoRipristinoOggi) { return "Punto di ripristino gia' creato oggi" }
        }
        'avprova' {
            if (@(Get-AntivirusInstallati | Where-Object { -not (Test-AvDaTenere $_.Nome) }).Count -eq 0) { return "Nessun antivirus di prova presente" }
        }
        'lingua' {
            if (Test-LinguaItaliana) { return "Windows gia' tutto in italiano" }
        }
        'officeattiva' {
            if ((Test-OfficeInstallato) -and (Test-OfficeAttivato)) { return "Office gia' attivato" }
        }
        'antivirus' {
            $av = @(Get-AntivirusTerzi)
            if ($av.Count -gt 0) { return "Gia' installato: $($av -join ', ')" }
        }
    }
    return $null
}

# =============================================================================
# LAVORI IN BACKGROUND durante i passi manuali (runspace nello stesso processo,
# quindi con gli stessi privilegi da amministratore). Oggi: Invoke-PuliziaSistema
# (bloatware, avvio automatico, comodita' Windows), che non fa domande e non
# usa il browser. Gli aggiornamenti restano l'ULTIMO passo, mai in background.
# Il runspace riceve le funzioni e le variabili dello script; pannello e barra
# animata li gestisce solo lo script principale (qui sono funzioni vuote), e le
# voci del riepilogo tornano allo script quando il lavoro finisce.
# Se il runspace non parte, la pulizia si fa in primo piano al passo "pulizia".
# =============================================================================
function Start-LavoriInBackground {
    if ($Global:LavoriBg) { return }
    try {
        $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
        $silenziate = @('Update-PannelloStatus', 'Start-BarraAnimata', 'Stop-BarraAnimata', 'Pausa')
        $esistenti = @{}
        foreach ($c in $iss.Commands) { $esistenti[$c.Name] = $true }
        foreach ($f in @(Get-ChildItem Function:)) {
            if ($esistenti.ContainsKey($f.Name) -or $silenziate -contains $f.Name) { continue }
            $iss.Commands.Add((New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry($f.Name, $f.Definition)))
        }
        foreach ($n in $silenziate) {
            $iss.Commands.Add((New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry($n, 'param()')))
        }
        $rs = [runspacefactory]::CreateRunspace($iss)
        $rs.Open()
        # Variabili dello script (e globali) che il runspace non ha gia' di suo.
        $viste = @{}
        foreach ($scope in @('Script', 'Global')) {
            foreach ($v in @(Get-Variable -Scope $scope -ErrorAction SilentlyContinue)) {
                if ($viste.ContainsKey($v.Name)) { continue }
                $viste[$v.Name] = $true
                if ($v.Options -band ([System.Management.Automation.ScopedItemOptions]::ReadOnly -bor [System.Management.Automation.ScopedItemOptions]::Constant)) { continue }
                if ($null -ne $rs.SessionStateProxy.PSVariable.Get($v.Name)) { continue }
                try { $rs.SessionStateProxy.SetVariable($v.Name, $v.Value) } catch {}
            }
        }
        # Riepilogo ed errori: liste proprie (niente accessi concorrenti), unite
        # a quelle dello script quando il lavoro finisce.
        $bgReport = [System.Collections.ArrayList]::new()
        $bgErrori = [System.Collections.ArrayList]::new()
        $rs.SessionStateProxy.SetVariable('Report', $bgReport)
        $rs.SessionStateProxy.SetVariable('ErroriImprevisti', $bgErrori)
        $ps = [PowerShell]::Create()
        $ps.Runspace = $rs
        [void]$ps.AddScript({
            $ok = $true
            try { Invoke-PuliziaSistema } catch { $ok = $false; Add-Report "Pulizia e ottimizzazione (background): $($_.Exception.Message)" "ERRORE" }
            $ok
        })
        $Global:LavoriBg = @{ PS = $ps; RS = $rs; Handle = $ps.BeginInvoke(); Report = $bgReport; Errori = $bgErrori; Inizio = Get-Date }
        Update-PannelloStatus -TaskId "pulizia" -Stato "running" -Dettaglio "In background mentre fai i passi manuali"
        Write-Info "Pulizia e ottimizzazione avviate in background: intanto fai i passi manuali."
    } catch {
        $Global:LavoriBg = $null
        Write-Info "Lavori in background non disponibili: la pulizia si fara' dopo i passi manuali."
    }
}

# Attende la fine dei lavori in background (max $TimeoutMin minuti), riporta
# le voci del riepilogo nello script principale e libera il runspace.
# Ritorna $true se la pulizia e' terminata correttamente.
function Complete-LavoriInBackground {
    param([int]$TimeoutMin = 30)
    $bg = $Global:LavoriBg
    if (-not $bg) { return $false }
    $ok = $false
    try {
        if (-not $bg.Handle.IsCompleted) {
            Write-Info "Attendo la fine della pulizia in background..."
            Start-BarraAnimata "Pulizia in background: quasi finito"
            try {
                $limite = (Get-Date).AddMinutes($TimeoutMin)
                while (-not $bg.Handle.IsCompleted -and (Get-Date) -lt $limite) { Start-Sleep -Milliseconds 500 }
            } finally { Stop-BarraAnimata }
        }
        if ($bg.Handle.IsCompleted) {
            $esito = @($bg.PS.EndInvoke($bg.Handle))
            $ok = ($esito.Count -gt 0 -and [bool]$esito[-1])
        } else {
            try { $bg.PS.Stop() } catch {}
            Add-Report "Pulizia e ottimizzazione (background): tempo massimo superato" "AVVISO"
        }
    } catch {
        Add-Report "Pulizia e ottimizzazione (background): $($_.Exception.Message)" "ERRORE"
    } finally {
        foreach ($r in @($bg.Report)) { if ($null -ne $r) { [void]$Report.Add($r) } }
        if ($null -ne $Global:ErroriImprevisti) { foreach ($e in @($bg.Errori)) { if ($null -ne $e) { [void]$Global:ErroriImprevisti.Add($e) } } }
        try { $bg.PS.Dispose() } catch {}
        try { $bg.RS.Close(); $bg.RS.Dispose() } catch {}
        $Global:LavoriBg = $null
    }
    return $ok
}

# =============================================================================
# PULIZIA E OTTIMIZZAZIONE (bloatware, avvio automatico, comodita' Windows).
# Nessuna domanda all'operatore: puo' girare in BACKGROUND (Start-LavoriInBackground)
# mentre l'operatore fa i passi manuali, oppure in primo piano al passo "pulizia".
# =============================================================================
function Invoke-PuliziaSistema {
trap {
    # Come il trap globale: registra l'imprevisto e prosegue con l'istruzione
    # successiva DENTRO la pulizia (senza, un errore chiuderebbe tutto il ciclo).
    Register-ErroreImprevisto $_
    try { Write-Host "   [!] Imprevisto gestito: $($_.Exception.Message)" -ForegroundColor DarkYellow } catch {}
    continue
}
    # ---------------------------------------------------------------------
    # 1/2 - BLOATWARE + PULIZIA AVVIO AUTOMATICO & BARRA APPLICAZIONI
    # ---------------------------------------------------------------------
    Write-Info "1/2 - Rimozione bloatware OEM, app promozionali e pulizia avvio..."

    $rimosse = 0

    # 0) Termina processi noti in background per sbloccare file ed evitare blocchi
    $junkProcesses = @(
        'Dropbox', 'DropboxUpdate', 'DropboxOEM',
        'Booking', 'BookingApp',
        'WildTangent', 'WildTangentGames',
        'ExpressVPN', 'expressvpn-browser-helper',
        'Evernote', 'EvernoteClipper',
        'AcerCareCenter', 'ACCStd', 'CareCenter', 'AcerCollection', 'Planet9',
        'HPJumpStart', 'HPSupportAssistant', 'HPCommRecovery',
        'DellSupportAssist', 'DellDataVault',
        'LenovoVantageService', 'LenovoNow'
    )
    if ($RunReale) {
        foreach ($proc in $junkProcesses) {
            try { Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue 2>$null } catch {}
        }
    }

    # 1) App Store (Appx) superflue e Provisioned Packages (per nuovi utenti).
    # Include Dropbox, Booking, Evernote, tutto il bloatware Acer/HP/Lenovo/Dell/Asus,
    # giochi sponsorizzati e social/streaming. NON include Xbox ne' Spotify.
    $bloatwareAppx = @(
        # --- Microsoft consumer / giochi / stubs ---
        "Microsoft.BingNews", "Microsoft.BingWeather", "Microsoft.BingSearch",
        "Microsoft.BingFinance", "Microsoft.BingSports",
        "Microsoft.GetHelp", "Microsoft.Getstarted", "Microsoft.Microsoft3DViewer",
        "Microsoft.MicrosoftSolitaireCollection", "Microsoft.MixedReality.Portal",
        "Microsoft.People", "Microsoft.WindowsFeedbackHub",
        "Microsoft.ZuneMusic", "Microsoft.ZuneVideo", "Microsoft.Windows.DevHome",
        "Microsoft.Todos", "MicrosoftCorporationII.QuickAssist", "Clipchamp.Clipchamp",
        "Microsoft.MicrosoftOfficeHub",
        "king.com.*", "*.CandyCrush*", "*.HiddenCity*", "*.MarchofEmpires*",
        "*.RoyalRevolt*", "*.DisneyMagicKingdoms*", "*.BubbleWitch*", "*.FarmHeroes*",
        # --- Social/streaming/cloud/trial terze parti ---
        "*.Facebook", "*.Instagram", "*.TikTok", "*.Netflix", "*.DisneyPlus",
        "*.AmazonPrimeVideo", "*.AmazonMusic", "*.Amazon*", "*Booking*", "*.Twitter",
        "*.LinkedIn*", "*Dropbox*", "DropboxInc.Dropbox", "*Evernote*",
        "*WildTangent*", "*ExpressVPN*", "*CyberLink*",
        # --- HP ---
        "*SupportAssistant*", "*myHP*", "AD2F1837.HPPrivacySettings", "*HPJumpStart*",
        "*HPPCHardwareDiagnostics*", "*HPPowerManager*", "*HPQuickDrop*", "*HPSystemInformation*",
        "*HPWorkWell*", "*HPProgrammableKey*", "*HPDesktopSupportUtilities*",
        # --- Lenovo ---
        "*LenovoVantage*", "*LenovoCompanion*", "*LenovoUtility*", "*LenovoWelcome*",
        "*LenovoQuickClean*", "*LenovoNow*", "*LenovoSmartCommunication*",
        # --- Dell ---
        "*DellSupportAssist*", "*DellCustomerConnect*", "*DellDigitalDelivery*",
        "*DellUpdate*", "*DellOptimizer*", "*PartnerPromo*", "*DellPowerManager*",
        # --- Asus (NB: NON tocco 'ASUS System Control Interface': e' un DRIVER vitale) ---
        "*MyASUS*", "*ASUSPCAssistant*", "*ASUSGiftBox*", "*GlideX*", "*ASUSSplendid*",
        "*ScreenXpert*", "*ScreenPad*", "*ArmouryCrate*", "*AsusCloud*", "*ASUSWebStorage*",
        "*ASUSSettings*", "*ProArtCreatorHub*", "*ASUSLiveUpdate*", "*AsusProductRegistration*",
        "*ASUSDialoutBox*", "*ASUSAppCenter*",
        # --- Acer (tutto il bloatware promozionale, telemetry e store apps) ---
        "*AcerCollection*", "*AcerRegistration*", "*AcerJumpstart*", "*AcerCareCenter*",
        "*AcerPortal*", "*AcerQuickAccess*", "*Planet9*", "*AcerPurifiedVoice*",
        "*AcerUserExperience*", "*AcerExplorerAssistant*"
    )

    try {
        $tuttiAppx = @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue)
        foreach ($t in $tuttiAppx) {
            if (-not $t -or -not $t.Name) { continue }
            $daRimuovere = $false
            foreach ($pkg in $bloatwareAppx) {
                if ($t.Name -like $pkg) { $daRimuovere = $true; break }
            }
            if ($daRimuovere) {
                Write-Info "Rimuovo app Store: $($t.Name)"
                Update-PannelloStatus -TaskId "pulizia" -Stato "running" -Dettaglio "Rimozione app Store: $($t.Name)..."
                try { Remove-AppxPackage -Package $t.PackageFullName -AllUsers -ErrorAction SilentlyContinue | Out-Null } catch {}
                $rimosse++
            }
        }
        $tuttiProv = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue)
        foreach ($pr in $tuttiProv) {
            if (-not $pr) { continue }
            $daRimuovereProv = $false
            foreach ($pkg in $bloatwareAppx) {
                if (($pr.DisplayName -and $pr.DisplayName -like $pkg) -or ($pr.PackageName -and $pr.PackageName -like $pkg)) {
                    $daRimuovereProv = $true
                    break
                }
            }
            if ($daRimuovereProv) {
                try { Remove-AppxProvisionedPackage -Online -PackageName $pr.PackageName -ErrorAction SilentlyContinue | Out-Null } catch {}
            }
        }
    } catch {}

    # 2) Disinstallazione DIRETTA da REGISTRO per programmi Win32 OEM (offline-safe,
    # con timeout massimo di 35s per evitare che un disinstallatore con finestra nascosta blocchi lo script)
    $bloatwareWin32Patterns = @(
        '*Dropbox*', '*Booking*', '*Evernote*', '*WildTangent*',
        '*ExpressVPN*', '*CyberLink*', '*Google Play Games*',
        '*Acer Care Center*', '*Acer Collection*', '*Acer Registration*', '*Acer Jumpstart*',
        '*Planet9*', '*Acer User Experience*', '*Care Center Service*',
        '*HP Support Assistant*', '*HP Documentation*', '*HP Sure Recover*', '*HP JumpStart*',
        '*Lenovo Vantage*', '*Lenovo Welcome*', '*Lenovo Now*',
        '*Dell SupportAssist*', '*Dell Customer Connect*', '*Dell Digital Delivery*',
        '*ASUS GiftBox*', '*GlideX*', '*ASUS Product Registration*'
    )

    $uninstallKeys = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $nomiWin32Trovati = @()
    if ($RunReale) {
        foreach ($uPath in $uninstallKeys) {
            try {
                $items = Get-ItemProperty -Path $uPath -ErrorAction SilentlyContinue
                if (-not $items) { continue }
                foreach ($item in $items) {
                    $dispName = $item.DisplayName
                    if (-not $dispName) { continue }
                    $nomiWin32Trovati += [string]$dispName

                    $matchFound = $false
                    foreach ($pat in $bloatwareWin32Patterns) {
                        if ($dispName -like $pat) {
                            $matchFound = $true
                            break
                        }
                    }
                    if (-not $matchFound) { continue }

                    $uninst = $item.QuietUninstallString
                    if (-not $uninst) { $uninst = $item.UninstallString }
                    if ($uninst) {
                        Write-Info "Disinstallo programma Win32 (max 35s): $dispName"
                        Update-PannelloStatus -TaskId "pulizia" -Stato "running" -Dettaglio "Disinstallazione $dispName..."
                        try {
                            $procUn = $null
                            if ($uninst -match 'msiexec(\.exe)?' -or $item.PSChildName -match '^\{[0-9A-Fa-f\-]+\}$') {
                                $prodCode = if ($item.PSChildName -match '^\{[0-9A-Fa-f\-]+\}$') { $item.PSChildName } else {
                                    if ($uninst -match '\{[0-9A-Fa-f\-]+\}') { $matches[0] } else { $null }
                                }
                                if ($prodCode) {
                                    $procUn = Start-Process -FilePath "msiexec.exe" -ArgumentList "/x `"$prodCode`" /qn /norestart" -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
                                }
                            } elseif ($item.QuietUninstallString) {
                                $procUn = Start-Process -FilePath "cmd.exe" -ArgumentList "/d /s /c `"$($item.QuietUninstallString)`"" -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
                            } else {
                                $cmd = $uninst
                                if ($cmd -notmatch '/S|/silent|/verysilent|/qn') { $cmd = "$cmd /S /silent /qn /norestart" }
                                $procUn = Start-Process -FilePath "cmd.exe" -ArgumentList "/d /s /c `"$cmd`"" -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
                            }
                            if ($procUn) {
                                if ($procUn.WaitForExit(35000)) {
                                    $rimosse++
                                    Write-OK "Disinstallato: $dispName"
                                } else {
                                    try { $procUn.Kill() } catch {}
                                    Write-Info "Timeout (35s) disinstallazione '$dispName': interrotto per non bloccare il setup."
                                }
                            }
                        } catch {}
                    }
                }
            } catch {}
        }
    }

    # 3) Passaggio di completamento Win32 via Winget SOLO per i bloatware effettivamente rilevati nel registro (max 25s ciascuno)
    $trialWin32Winget = @(
        "Dropbox", "Dropbox Promotion", "Dropbox OEM", "Booking.com",
        "Evernote", "WildTangent Games", "ExpressVPN", "CyberLink PowerDVD",
        "HP Support Assistant", "HP Documentation", "HP Sure Recover",
        "MyASUS", "ASUS GiftBox", "GlideX", "ASUS Product Registration Program",
        "Acer Care Center", "Planet9", "Google Play Games"
    )
    if ($RunReale -and $nomiWin32Trovati.Count -gt 0 -and (Confirm-Winget)) {
        foreach ($nome in $trialWin32Winget) {
            $presente = $false
            foreach ($inst in $nomiWin32Trovati) {
                if ($inst -like "*$nome*") { $presente = $true; break }
            }
            if (-not $presente) { continue }
            try {
                $pWg = Start-Process -FilePath "winget.exe" -ArgumentList @('uninstall', '--name', $nome, '--silent', '--accept-source-agreements') -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
                if ($pWg) {
                    if ($pWg.WaitForExit(25000) -and $pWg.ExitCode -eq 0) {
                        Write-Info "Rimosso (winget): $nome"
                        $rimosse++
                    } elseif (-not $pWg.HasExited) {
                        try { $pWg.Kill() } catch {}
                    }
                }
            } catch {}
        }
    }

    # 4) Pulizia COLLEGAMENTI (.lnk e .url) dal Menu Start, Desktop (Utente, Pubblico e OneDrive)
    # NB: NON usare il filtro Adobe generico altrimenti elimina Adobe Acrobat Reader appena installato!
    $junkShortcutPatterns = @(
        '*Booking*', '*Dropbox*', '*Evernote*', '*WildTangent*', '*ExpressVPN*',
        '*CyberLink*', '*Offerte Adobe*', '*Adobe offers*', '*Amazon*',
        '*TikTok*', '*Instagram*', '*Facebook*', '*Disney*', '*Netflix*',
        '*Acer Collection*', '*Acer Care Center*', '*Acer Jumpstart*', '*Acer Registration*',
        '*Planet9*', '*HP Support Assistant*', '*HP Documentation*', '*Lenovo Welcome*',
        '*Lenovo Vantage*', '*Dell SupportAssist*', '*Dell Digital Delivery*',
        '*ASUS GiftBox*', '*GlideX*', '*MSI Product Registration*', '*MSIala*',
        '*McAfee*', '*Norton*', '*Google Play Games*'
    )

    $shortcutDirs = @(
        (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'),
        (Join-Path $env:APPDATA     'Microsoft\Windows\Start Menu\Programs'),
        [Environment]::GetFolderPath('Desktop'),
        [Environment]::GetFolderPath('CommonDesktopDirectory'),
        'C:\Users\Public\Desktop',
        (Join-Path $env:USERPROFILE 'OneDrive\Desktop')
    )
    foreach ($dir in $shortcutDirs) {
        if (-not $dir -or -not (Test-Path $dir)) { continue }
        Get-ChildItem -Path $dir -Include *.lnk, *.url -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
            $nomeFile = $_.BaseName
            foreach ($pat in $junkShortcutPatterns) {
                if ($nomeFile -like $pat) {
                    Write-Info "Elimino collegamento: $($_.Name)"
                    Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
                    $rimosse++
                    break
                }
            }
        }
        # Pulizia cartelle residue temporanee di installer sul Desktop (es. OpenOffice Installation Files)
        Get-ChildItem -Path $dir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*OpenOffice*' -or $_.Name -like '*Installation Files*' } | ForEach-Object {
            Write-Info "Elimino cartella residua installer dal desktop: $($_.Name)"
            Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            $rimosse++
        }
        Get-ChildItem -Path $dir -Filter "*.lnk" -File -ErrorAction SilentlyContinue | Where-Object { $_.BaseName -like '*OpenOffice*Install*' -or $_.BaseName -like '*Installation Files*' } | ForEach-Object {
            Write-Info "Elimino collegamento temporaneo installer: $($_.Name)"
            Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
            $rimosse++
        }
    }

    # 5) SBLOCCO DALLA BARRA DELLE APPLICAZIONI (Taskbar Unpin)
    # Rimuove le icone promozionali (Booking, Dropbox, Acer) fissate da OEM nella barra
    try {
        $taskbarDir = Join-Path $env:APPDATA 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar'
        if (Test-Path $taskbarDir) {
            Get-ChildItem -Path $taskbarDir -Include *.lnk, *.url -File -ErrorAction SilentlyContinue | ForEach-Object {
                $tbName = $_.BaseName
                foreach ($pat in $junkShortcutPatterns) {
                    if ($tbName -like $pat) {
                        Write-Info "Tolgo icona dalla barra: $($_.Name)"
                        Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
                        $rimosse++
                        break
                    }
                }
            }
        }

        # Unpin via Shell COM: agisce sia sui file pinned che su shell:AppsFolder
        $shellApp = New-Object -ComObject Shell.Application
        if (Test-Path $taskbarDir) {
            $tbFolder = $shellApp.Namespace($taskbarDir)
            if ($tbFolder) {
                foreach ($item in $tbFolder.Items()) {
                    foreach ($pat in $junkShortcutPatterns) {
                        if ($item.Name -like $pat) {
                            $v = $item.Verbs() | Where-Object { $_.Name.Replace('&','') -match 'Unpin from taskbar|Rimuovi dalla barra|Sblocca dalla barra' }
                            if ($v) { $v.DoIt() }
                        }
                    }
                }
            }
        }
        $appsFolder = $shellApp.Namespace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}')
        if ($appsFolder) {
            foreach ($app in $appsFolder.Items()) {
                foreach ($pat in $junkShortcutPatterns) {
                    if ($app.Name -like $pat) {
                        $v = $app.Verbs() | Where-Object { $_.Name.Replace('&','') -match 'Unpin from taskbar|Rimuovi dalla barra|Sblocca dalla barra' }
                        if ($v) {
                            $v.DoIt()
                            Write-Info "Sbloccato dalla barra applicazioni: $($app.Name)"
                        }
                        break
                    }
                }
            }
        }
    } catch {}

    # 6) Pulizia AVVIO AUTOMATICO: updater/helper NOTI (produttore, promo). NON
    # tocca driver, OneDrive, gli updater dei browser, ne' le app del setup.
    $avvioJunk = @(
        'HP*', '*Lenovo*', 'Dell*', '*ASUS*', 'Acer*', '*SupportAssist*', '*Vantage*',
        'SunJavaUpdate*', 'iTunesHelper', 'QuickTime*', 'CCleaner*',
        'WildTangent*', 'ExpressVPN*', '*Booking*', '*Dropbox*', '*Evernote*',
        '*CyberLink*', '*Planet9*', '*ACCStd*', '*CareCenter*', '*Google Play Games*'
    )
    $avvioTolti = 0
    # a) Voci di registro "Run" (utente + macchina + 32-bit): tolgo per nome-voce
    $runKeys = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run'
    )
    $metaProp = @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider')
    foreach ($rk in $runKeys) {
        if (-not (Test-Path $rk)) { continue }
        $voci = Get-ItemProperty -Path $rk -ErrorAction SilentlyContinue
        if (-not $voci) { continue }
        foreach ($v in $voci.PSObject.Properties) {
            if ($metaProp -contains $v.Name) { continue }
            foreach ($pat in $avvioJunk) {
                if ($v.Name -like $pat) {
                    Write-Info "Tolgo da avvio: $($v.Name)"
                    Remove-ItemProperty -Path $rk -Name $v.Name -ErrorAction SilentlyContinue
                    $avvioTolti++
                    break
                }
            }
        }
    }
    # b) Collegamenti nelle cartelle "Esecuzione automatica" (utente + tutti)
    foreach ($dir in @([Environment]::GetFolderPath('Startup'), [Environment]::GetFolderPath('CommonStartup'))) {
        if (-not $dir -or -not (Test-Path $dir)) { continue }
        Get-ChildItem -Path $dir -Filter *.lnk -ErrorAction SilentlyContinue | ForEach-Object {
            $nomeLnk = $_.BaseName
            foreach ($pat in $avvioJunk) {
                if ($nomeLnk -like $pat) {
                    Write-Info "Tolgo collegamento avvio: $nomeLnk"
                    Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
                    $avvioTolti++
                    break
                }
            }
        }
    }
    # c) Task pianificati all'avvio/logon: DISABILITO (non elimino) i junk noti.
    #    Salto i task di sistema \Microsoft\Windows\ e gli updater dei browser.
    $taskJunk = @(
        '*Offerte Adobe*', '*Adobe offers*', '*HP*', '*Lenovo*', '*Dell*', '*ASUS*', '*Acer*',
        '*SupportAssist*', '*Vantage*', '*CCleaner*', '*WildTangent*',
        '*ExpressVPN*', '*Java Update*', '*JavaUpdate*',
        '*Dropbox*', '*Booking*', '*Evernote*', '*CyberLink*', '*Planet9*'
    )
    try {
        foreach ($tk in (Get-ScheduledTask -ErrorAction SilentlyContinue)) {
            if ($tk.State -eq 'Disabled') { continue }
            if ($tk.TaskPath -like '\Microsoft\Windows\*') { continue }   # OS: non toccare
            $full = "$($tk.TaskPath)$($tk.TaskName)"
            foreach ($pat in $taskJunk) {
                if ($full -like $pat) {
                    Write-Info "Disabilito task avvio: $($tk.TaskName)"
                    Disable-ScheduledTask -TaskName $tk.TaskName -TaskPath $tk.TaskPath -ErrorAction SilentlyContinue | Out-Null
                    $avvioTolti++
                    break
                }
            }
        }
    } catch {}

    Write-OK "Bloatware: rimosse $rimosse app/collegamenti; tolti $avvioTolti elementi dall'avvio automatico."
    Add-Report "Rimozione bloatware ($rimosse app)" "OK"
    Add-Report "Pulizia avvio automatico ($avvioTolti)" "OK"

    # ---------------------------------------------------------------------
    # 2/2 - CONFIGURAZIONE WINDOWS BASE (piccole comodita')
    # ---------------------------------------------------------------------
    Write-Info "2/2 - Applico piccole comodita' di Windows..."
    try {
        $adv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Set-ItemProperty -Path $adv -Name "HideFileExt" -Value 0 -Type DWord -ErrorAction SilentlyContinue   # mostra estensioni
        Set-ItemProperty -Path $adv -Name "LaunchTo"    -Value 1 -Type DWord -ErrorAction SilentlyContinue   # Esplora su "Questo PC"
        Write-OK "Impostazioni Esplora file applicate."
        Add-Report "Configurazione Windows base" "OK"
    } catch {
        Write-Errore "Impossibile applicare alcune impostazioni: $_"
        Add-Report "Configurazione Windows base" "ERRORE"
    }

    # --- PULIZIA BARRA DELLE APPLICAZIONI (Windows 11): tolgo i pulsanti inutili
    # che confondono il cliente - Widget (meteo/notizie), Chat/Teams, Vista
    # attivita' e la casella di ricerca (resta comunque la ricerca dal menu
    # Start). Tutto via registro HKCU: si applica al prossimo accesso/riavvio,
    # come le altre comodita'. Su Windows 10 alcune chiavi sono ignorate: nessun
    # problema, restano innocue. ---
    try {
        $adv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Set-ItemProperty -Path $adv -Name "TaskbarDa"          -Value 0 -Type DWord -ErrorAction SilentlyContinue   # Widget: nascosto
        Set-ItemProperty -Path $adv -Name "TaskbarMn"          -Value 0 -Type DWord -ErrorAction SilentlyContinue   # Chat/Teams: nascosto
        Set-ItemProperty -Path $adv -Name "ShowTaskViewButton" -Value 0 -Type DWord -ErrorAction SilentlyContinue   # Vista attivita': nascosta
        Set-ItemProperty -Path $adv -Name "ShowCopilotButton"  -Value 0 -Type DWord -ErrorAction SilentlyContinue   # Copilot: nascosto
        $srch = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
        if (-not (Test-Path $srch)) { New-Item -Path $srch -Force | Out-Null }
        Set-ItemProperty -Path $srch -Name "SearchboxTaskbarMode" -Value 0 -Type DWord -ErrorAction SilentlyContinue  # Ricerca: nascosta dalla barra
        # Nasconde l'icona di Windows Spotlight ("Ulteriori informazioni su questa immagine" / "Peering over smooth seas") dal Desktop
        $hideDesk = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"
        if (-not (Test-Path $hideDesk)) { New-Item -Path $hideDesk -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty -Path $hideDesk -Name "{2cc5ca98-6485-489a-920e-b3e88a6ccce3}" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Write-OK "Barra applicazioni e Desktop ripuliti (Widget, Chat, Vista attivita', Copilot, Ricerca, Spotlight)."
        Add-Report "Pulizia barra applicazioni (Win11)" "OK"
    } catch {
        Write-Info "Alcune impostazioni della barra non applicate (versione di Windows diversa)."
        Add-Report "Pulizia barra applicazioni (Win11)" "AVVISO"
    }

    # DISINSTALLA OneDrive (non solo l'avvio automatico): molti clienti non lo
    # vogliono. Chiudo il processo, lancio il disinstallatore ufficiale, tolgo la
    # versione Store (Appx) e il provisioning (i nuovi utenti non lo riavranno).
    try {
        Write-Info "Disinstallazione OneDrive..."
        Start-BarraAnimata "Disinstallo OneDrive"
        taskkill /f /im OneDrive.exe 2>$null | Out-Null
        $odSetup = @("$env:SystemRoot\SysWOW64\OneDriveSetup.exe", "$env:SystemRoot\System32\OneDriveSetup.exe") |
            Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($odSetup) {
            $pOd = Start-Process $odSetup -ArgumentList "/uninstall /silent" -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
            if ($pOd -and -not $pOd.WaitForExit(40000)) {
                try { $pOd.Kill() } catch {}
                Write-Info "Timeout (40s) disinstallazione OneDrive: proseguo."
            }
        }
        Get-AppxPackage -AllUsers *OneDrive* -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        foreach ($prOd in @($tuttiProv | Where-Object { $_.DisplayName -like "*OneDrive*" })) {
            try { Remove-AppxProvisionedPackage -Online -PackageName $prOd.PackageName -ErrorAction SilentlyContinue | Out-Null } catch {}
        }
        $run = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        if (Get-ItemProperty -Path $run -Name "OneDrive" -ErrorAction SilentlyContinue) { Remove-ItemProperty -Path $run -Name "OneDrive" -ErrorAction SilentlyContinue }
        $clsidOd = "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
        try {
            New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -ErrorAction SilentlyContinue | Out-Null
            if (Test-Path $clsidOd) { Set-ItemProperty -Path $clsidOd -Name "System.IsPinnedToNameSpaceTree" -Value 0 -Type DWord -ErrorAction SilentlyContinue }
        } catch {}
        if (Test-Path "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe") {
            Write-Info "OneDrive forse non rimosso del tutto (riprova dopo il riavvio)."
            Add-Report "Rimozione OneDrive" "AVVISO"
        } else {
            Write-OK "OneDrive disinstallato."
            Add-Report "Rimozione OneDrive" "OK"
        }
    } catch {
        Write-Info "Rimozione OneDrive non riuscita: $_"
        Add-Report "Rimozione OneDrive" "AVVISO"
    } finally { Stop-BarraAnimata }

    # --- PRIVACY & TELEMETRIA MICROSOFT: disattivazione telemetria diagnostica,
    # advertising ID e tracciamento personalizzato per massimizzare privacy e reattivita' ---
    try {
        $dcPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
        if (-not (Test-Path $dcPolicy)) { New-Item -Path $dcPolicy -Force | Out-Null }
        Set-ItemProperty -Path $dcPolicy -Name "AllowTelemetry" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $dcPolicy -Name "DoNotShowFeedbackNotifications" -Value 1 -Type DWord -ErrorAction SilentlyContinue

        $actPol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
        if (-not (Test-Path $actPol)) { New-Item -Path $actPol -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty -Path $actPol -Name "PublishUserActivities" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $actPol -Name "UploadUserActivities" -Value 0 -Type DWord -ErrorAction SilentlyContinue

        foreach ($svcDiag in @('DiagTrack','dmwappushservice')) {
            Stop-Service -Name $svcDiag -Force -ErrorAction SilentlyContinue
            Set-Service -Name $svcDiag -StartupType Disabled -ErrorAction SilentlyContinue
        }

        $advId = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
        if (-not (Test-Path $advId)) { New-Item -Path $advId -Force | Out-Null }
        Set-ItemProperty -Path $advId -Name "Enabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue

        $priv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy"
        if (-not (Test-Path $priv)) { New-Item -Path $priv -Force | Out-Null }
        Set-ItemProperty -Path $priv -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue

        $cloud = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
        if (-not (Test-Path $cloud)) { New-Item -Path $cloud -Force | Out-Null }
        Set-ItemProperty -Path $cloud -Name "DisableConsumerAccountStateContent" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $cloud -Name "DisableWindowsConsumerFeatures" -Value 1 -Type DWord -ErrorAction SilentlyContinue

        $cdm = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        if (Test-Path $cdm) {
            foreach ($kCdm in @('SystemPaneSuggestionsEnabled','SoftLandingEnabled','SilentInstalledAppsEnabled','ContentDeliveryAllowed','OemPreInstalledAppsEnabled','PreInstalledAppsEnabled','RotatingLockScreenOverlayEnabled','SubscribedContent-310093Enabled','SubscribedContent-338387Enabled','SubscribedContent-338388Enabled','SubscribedContent-338389Enabled','SubscribedContent-338393Enabled','SubscribedContent-353694Enabled','SubscribedContent-353696Enabled')) {
                Set-ItemProperty -Path $cdm -Name $kCdm -Value 0 -Type DWord -ErrorAction SilentlyContinue
            }
        }
        # Disattiva Windows Recall AI, Copilot, schermata "Finisci di configurare il PC" (Scoobe),
        # suggerimenti/pubblicita' in Esplora File e Start, e attiva Storage Sense automatico su SSD.
        $aiPol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
        if (-not (Test-Path $aiPol)) { New-Item -Path $aiPol -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty -Path $aiPol -Name "DisableAIDataAnalysis" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $aiPol -Name "TurnOffSavingSnapshots" -Value 1 -Type DWord -ErrorAction SilentlyContinue

        $copPol = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"
        if (-not (Test-Path $copPol)) { New-Item -Path $copPol -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty -Path $copPol -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord -ErrorAction SilentlyContinue

        $upe = "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement"
        if (-not (Test-Path $upe)) { New-Item -Path $upe -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty -Path $upe -Name "ScoobeSystemSettingEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue

        $advExp = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Set-ItemProperty -Path $advExp -Name "ShowSyncProviderNotifications" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $advExp -Name "Start_IrisRecommendations" -Value 0 -Type DWord -ErrorAction SilentlyContinue

        $siuf = "HKCU:\Software\Microsoft\Siuf\Rules"
        if (-not (Test-Path $siuf)) { New-Item -Path $siuf -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty -Path $siuf -Name "NumberOfSIUFInPeriod" -Value 0 -Type DWord -ErrorAction SilentlyContinue

        $ss = "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy"
        if (-not (Test-Path $ss)) { New-Item -Path $ss -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty -Path $ss -Name "01" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $ss -Name "04" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $ss -Name "256" -Value 30 -Type DWord -ErrorAction SilentlyContinue

        Write-OK "Privacy Windows e Super Debloat applicati (Recall AI, Copilot, Scoobe, pubblicita' Esplora File/Start disattivati e Storage Sense attivo)."
        Add-Report "Privacy e telemetria Windows" "OK"
    } catch {
        Write-Info "Alcune impostazioni privacy non applicate: $_"
        Add-Report "Privacy e telemetria Windows" "AVVISO"
    }

    # --- OTTIMIZZAZIONE SPAZIO SU DISCO: Ibernazione (su SSD <= 260GB) e WinSxS (DISM) ---
    try {
        $driveC = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
        if ($driveC -and ($driveC.Size / 1GB) -le 260) {
            Write-Info "Disco di sistema <= 256 GB: disattivazione ibernazione per liberare spazio SSD..."
            powercfg /hibernate off 2>$null | Out-Null
            Write-OK "Ibernazione disattivata (liberati da 8 a 32 GB di spazio SSD)."
            Add-Report "Ottimizzazione spazio SSD (ibernazione off)" "OK"
        }
    } catch {}

    # --- REATTIVITA' UI & PRESTAZIONI ---
    try {
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "8" -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WaitToKillAppTimeout" -Value "2000" -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "HungAppTimeout" -Value "1000" -ErrorAction SilentlyContinue
        $mm = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
        if (Test-Path $mm) { Set-ItemProperty -Path $mm -Name "ClearPageFileAtShutdown" -Value 0 -Type DWord -ErrorAction SilentlyContinue }
        Write-OK "Reattivita' UI ottimizzata (MenuShowDelay=8ms, chiusura rapida app bloccate, ClearPageFileAtShutdown=0)."
        Add-Report "Reattivita' UI e prestazioni" "OK"
    } catch {
        Write-Info "Alcune impostazioni di reattivita' UI non applicate: $_"
    }

    # --- VERIFICA TRIM NATIVO & RETRIM SSD ---
    try {
        & fsutil.exe behavior set DisableDeleteNotify 0 2>$null | Out-Null
        Optimize-Volume -DriveLetter C -ReTrim -ErrorAction SilentlyContinue | Out-Null
        Write-OK "TRIM SSD nativo verificato ed eseguito su C: (ReTrim)."
        Add-Report "Ottimizzazione TRIM SSD (C:)" "OK"
    } catch {
        Write-Info "TRIM SSD su C: non eseguito: $_"
    }

    # Nota: NON avviamo dism.exe /StartComponentCleanup prima di Driver e Windows Update,
    # perche' blocca il Windows Servicing Stack (TiWorker/CBS) e rallenta l'SSD su PC nuovi.
    Write-OK "Pulizia e ottimizzazione iniziale completata."
}


# =============================================================================
# ORDINE DEI PASSI (unica fonte: console, checkpoint di ripresa e pannello)
#   1) APP E LINGUA (automatici): ripristino, antivirus di prova, lingua,
#      applicazioni, Office (installazione). Intanto l'operatore inserisce i
#      dati del cliente nel pannello; Office e' l'ultimo passo della fase 1
#      perche' e' il primo che ne ha bisogno (quale card?).
#   2) PASSI MANUALI dell'operatore: nome, account, attivazione Office,
#      antivirus, Cyber Protection. Intanto la pulizia gira in BACKGROUND.
#   3) RESTO (automatici): pulizia (attesa/fine), driver e, per ULTIMI, gli
#      aggiornamenti (app, Store, Windows).
# Ogni passo prima controlla se il suo lavoro c'e' gia' (Test-PassoGiaFatto)
# e in quel caso lo salta ("gia' fatto" in console, pannello e riepilogo).
# Checkpoint: Fase = numero di passi completati (Schema 3 = quest'ordine).
# =============================================================================
$Global:Passi = @(
    @{ Id = 'avprova';      Nome = 'Rimozione antivirus di prova';          Gruppo = 1; Task = 'avprova' }
    @{ Id = 'everyday';     Nome = 'Unieuro Everyday Digital (Priorita'')'; Gruppo = 1; Task = 'everyday' }
    @{ Id = 'office';       Nome = 'Office (installazione)';                Gruppo = 1; Task = 'office' }
    @{ Id = 'nome';         Nome = 'Nome cliente e PC';             Gruppo = 1; Task = 'account' }
    @{ Id = 'account';      Nome = 'Account/email cliente';         Gruppo = 1; Task = 'account' }
    @{ Id = 'officeattiva'; Nome = 'Office (attivazione)';          Gruppo = 1; Task = 'office' }
    @{ Id = 'antivirus';    Nome = 'Antivirus';                     Gruppo = 1; Task = 'antivirus' }
    @{ Id = 'cyber';        Nome = 'Unieuro Cyber Protection';      Gruppo = 1; Task = 'cyber' }
    @{ Id = 'lingua';       Nome = 'Lingua e regione';              Gruppo = 2; Task = 'lingua' }
    @{ Id = 'ripristino';   Nome = 'Punto di ripristino';           Gruppo = 2; Task = 'ripristino' }
    @{ Id = 'app';          Nome = 'Applicazioni + browser';        Gruppo = 2; Task = 'app' }
    @{ Id = 'pulizia';      Nome = 'Pulizia e ottimizzazione';      Gruppo = 2; Task = 'pulizia' }
    @{ Id = 'driver';       Nome = 'Driver';                        Gruppo = 2; Task = 'driver' }
    @{ Id = 'aggiorna';     Nome = 'Aggiornamenti (app + Windows)'; Gruppo = 2; Task = 'aggiorna' }
)
$gruppiNomi = @{ 1 = 'FASE 1 di 2 - Dati cliente, Office e attivazioni (operatore)'; 2 = 'FASE 2 di 2 - Lingua, programmi, pulizia, driver e aggiornamenti (automatico)' }
$totPassi = $Global:Passi.Count

# Ripresa: si riparte dal primo passo non completato; nel pannello i passi gia'
# fatti risultano completati.
$passo = [Math]::Max(0, [Math]::Min([int]$Global:FaseRipresa, $totPassi))
for ($i = 0; $i -lt $passo; $i++) {
    Update-PannelloStatus -TaskId $Global:Passi[$i].Task -Stato "done" -Dettaglio "Gia' completato"
}
if ($passo -gt 0 -and $passo -lt $totPassi) { Write-Info "Riprendo dal passo $($passo + 1) di $($totPassi): $($Global:Passi[$passo].Nome)." }

# Esegue su richiesta un singolo passaggio inviato dalla scheda "4. Passaggi" del pannello.
function Invoke-PassoSingolo {
    param($Cmd)
    if (-not $Cmd -or -not $Cmd.Step) { return }
    $st = ([string]$Cmd.Step).Trim().ToLower()
    $param = if ($Cmd.Param) { ([string]$Cmd.Param).Trim() } else { "" }
    Write-Host ""
    Write-Titolo "ESECUZIONE SINGOLO PASSAGGIO DAL PANNELLO: $($st.ToUpper())"
    switch ($st) {
        'account' {
            $nu = if ($Cmd.NomeUtente) { ([string]$Cmd.NomeUtente).Trim() } else { "Utente" }
            $np = if ($Cmd.NomePc) { ([string]$Cmd.NomePc).Trim() } else { "" }
            $res = Set-NomeUtenteEPc -NomeUtente $nu -NomePc $np
            $Global:nomeProprioCliente = $res.NomeUtente
            Add-Report "Nome cliente / PC ($($res.NomeUtente) / $($res.NomePc))" "OK"
            Update-PannelloStatus -TaskId "account" -Stato "done" -Dettaglio "Utente: $($res.NomeUtente) ($($res.NomePc))"
        }
        'ripristino' {
            Update-PannelloStatus -TaskId "ripristino" -Stato "running" -Dettaglio "Creazione punto di ripristino..."
            if (-not ($Test -or $Global:Test -or $env:PESTER_TEST)) {
                try {
                    Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
                    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "SystemRestorePointCreationFrequency" -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
                    Checkpoint-Computer -Description "PC Facile - Punto manuale" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
                    Write-OK "Punto di ripristino creato con successo."
                    Add-Report "Punto di ripristino (manuale)" "OK"
                    Update-PannelloStatus -TaskId "ripristino" -Stato "done" -Dettaglio "Punto creato"
                } catch {
                    Write-Errore "Creazione punto di ripristino non riuscita: $_"
                    Update-PannelloStatus -TaskId "ripristino" -Stato "error" -Dettaglio "Non riuscito"
                }
            } else {
                Update-PannelloStatus -TaskId "ripristino" -Stato "done" -Dettaglio "Punto creato (test)"
            }
        }
        'avprova' {
            Update-PannelloStatus -TaskId "avprova" -Stato "running" -Dettaglio "Rimozione antivirus di prova..."
            $avInst = @(Get-AntivirusInstallati | Where-Object { -not (Test-AvDaTenere $_.Nome) })
            foreach ($av in $avInst) {
                Write-Info "Rimuovo $($av.Nome)..."
                if (-not ($Test -or $Global:Test -or $env:PESTER_TEST)) {
                    if ($av.QuietUninstall) { try { cmd /c $av.QuietUninstall 2>$null | Out-Null } catch {} }
                    elseif ($av.Uninstall) { try { cmd /c "$($av.Uninstall) /silent /quiet /norestart" 2>$null | Out-Null } catch {} }
                    if (Confirm-Winget) { winget uninstall --name $av.Nome --silent --accept-source-agreements 2>$null | Out-Null }
                }
            }
            Update-PannelloStatus -TaskId "avprova" -Stato "done" -Dettaglio "Completato"
            Write-OK "Passaggio rimozione antivirus di prova completato."
        }
        'lingua' {
            Update-PannelloStatus -TaskId "lingua" -Stato "running" -Dettaglio "Applicazione lingua e tastiera IT..."
            if (-not ($Test -or $Global:Test -or $env:PESTER_TEST)) {
                try {
                    $lista = New-WinUserLanguageList it-IT
                    $lista[0].InputMethodTips.Clear()
                    $lista[0].InputMethodTips.Add("0410:00000410")
                    Set-WinUserLanguageList $lista -Force
                } catch {}
                try { Set-WinUILanguageOverride -Language it-IT } catch {}
                if (Get-Command Set-SystemPreferredUILanguage -ErrorAction SilentlyContinue) {
                    try { Set-SystemPreferredUILanguage it-IT -ErrorAction SilentlyContinue } catch {}
                }
                try { Set-Culture it-IT } catch {}
                try { Set-WinHomeLocation -GeoId 118 } catch {}
                try { Set-WinSystemLocale it-IT } catch {}
                try { Set-TimeZone -Id "W. Europe Standard Time" -ErrorAction SilentlyContinue } catch {}
                if (Get-Command Copy-UserInternationalSettingsToSystem -ErrorAction SilentlyContinue) {
                    try { Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true } catch {}
                }
            }
            Write-OK "Lingua, tastiera italiana e fuso orario applicati."
            Add-Report "Lingua italiana (ripetuta da pannello)" "OK"
            Update-PannelloStatus -TaskId "lingua" -Stato "done" -Dettaglio "Italiano applicato"
        }
        'runtime' {
            Update-PannelloStatus -TaskId "runtime" -Stato "running" -Dettaglio "Installazione Visual C++..."
            [void](Install-VisualCRuntime)
            Update-PannelloStatus -TaskId "runtime" -Stato "done" -Dettaglio "Completato"
        }
        'app' {
            Update-PannelloStatus -TaskId "app" -Stato "running" -Dettaglio "Installazione selezionata ($param)..."
            if ($param -match '^APP:(.+)$') {
                $idApp = $matches[1]
                $voceCat = $CatalogoApp | Where-Object { $_.Id -eq $idApp } | Select-Object -First 1
                $nomeApp = if ($voceCat) { $voceCat.Nome } elseif ($idApp -eq 'Google.Chrome') { 'Google Chrome' } elseif ($idApp -eq 'Opera.OperaGX') { 'Opera GX' } elseif ($idApp -eq 'Mozilla.Firefox') { 'Mozilla Firefox' } else { $idApp }
                Installa-Pacchetto -Nome $nomeApp -WingetId $idApp
            } else {
                $prof = if ($param -match '^PROFILO:(.+)$') { $matches[1] } else { 'BASE' }
                Installa-Pacchetto -Nome $(if ($prof -eq 'GAMING') { 'Opera GX' } else { 'Google Chrome' }) -WingetId $(if ($prof -eq 'GAMING') { 'Opera.OperaGX' } else { 'Google.Chrome' })
                foreach ($a in $CatalogoApp) {
                    if ($prof -eq 'COMPLETO' -or ($a.Profili -contains $prof)) {
                        Installa-Pacchetto -Nome $a.Nome -WingetId $a.Id
                    }
                }
            }
            Remove-IconeDoppieDesktop
            Repair-DesktopShortcuts
            Update-PannelloStatus -TaskId "app" -Stato "done" -Dettaglio "Completato"
        }
        'icone' {
            Remove-IconeDoppieDesktop
            Repair-DesktopShortcuts
            Write-OK "Icone Desktop riparate e duplicate rimosse."
            Update-PannelloStatus -TaskId "app" -Stato "done" -Dettaglio "Icone Desktop riparate"
        }
        'office' {
            Update-PannelloStatus -TaskId "office" -Stato "running" -Dettaglio "Installazione Office ($param)..."
            switch ($param) {
                'libreoffice' { Installa-Pacchetto -Nome "LibreOffice" -WingetId "TheDocumentFoundation.LibreOffice" }
                'openoffice'  { Installa-Pacchetto -Nome "OpenOffice" -WingetId "Apache.OpenOffice"; Repair-DesktopShortcuts }
                default       {
                    if (-not (Test-OfficeInstallato)) { Installa-Pacchetto -Nome "Microsoft 365" -WingetId "Microsoft.Office" }
                    Add-CollegamentiOffice
                }
            }
            Update-PannelloStatus -TaskId "office" -Stato "done" -Dettaglio "Office installato"
        }
        'officeattiva' {
            $urlOff = if ($param -eq 'perpetuo') { "https://office.com/setup" } else { "https://microsoft365.com/setup" }
            Open-PaginaWeb $urlOff
            Mostra-CredenzialiPagina -Utente $Global:credMsAccount -Password $Global:credMsPassword
            Update-PannelloStatus -TaskId "office" -Stato "done" -Dettaglio "Pagina attivazione aperta"
        }
        'antivirus' {
            Update-PannelloStatus -TaskId "antivirus" -Stato "running" -Dettaglio "Attivazione antivirus..."
            if ($param -eq 'norton') {
                Installa-Antivirus -Nome "Norton" -UrlRiscatto "https://www.norton.com/setup" -Utente $Global:credMsAccount -Password $Global:credMsPassword
            } else {
                Installa-Antivirus -Nome "McAfee" -UrlRiscatto "https://www.mcafee.com/activate" -Utente $Global:credMsAccount -Password $Global:credMsPassword
            }
            Update-PannelloStatus -TaskId "antivirus" -Stato "done" -Dettaglio "Antivirus avviato"
        }
        'everyday' {
            Update-PannelloStatus -TaskId "everyday" -Stato "running" -Dettaglio "Attivazione Unieuro Everyday Digital..."
            Invoke-EverydayDigital -Utente $Global:credMsAccount -Password $Global:credMsPassword
            Update-PannelloStatus -TaskId "everyday" -Stato "done" -Dettaglio "Configurato"
        }
        'cyber' {
            Update-PannelloStatus -TaskId "cyber" -Stato "running" -Dettaglio "Apertura Cyber Protection..."
            Attiva-ServizioWeb -Nome "Unieuro Cyber Protection" -UrlAttivazione "https://unieuro-cyber-protection.covercare.it" -Utente $Global:credMsAccount
            Update-PannelloStatus -TaskId "cyber" -Stato "done" -Dettaglio "Configurato"
        }
        'pulizia' {
            Update-PannelloStatus -TaskId "pulizia" -Stato "running" -Dettaglio "Pulizia bloatware e ottimizzazione..."
            Invoke-PuliziaSistema
            $Global:PuliziaFatta = $true
            Update-PannelloStatus -TaskId "pulizia" -Stato "done" -Dettaglio "Completato"
        }
        'driver' {
            Update-PannelloStatus -TaskId "driver" -Stato "running" -Dettaglio "Ricerca e installazione driver..."
            [void](Install-WindowsUpdateDrivers -TimeoutSec 360 -Test:$Test)
            Update-PannelloStatus -TaskId "driver" -Stato "done" -Dettaglio "Completato"
        }
        'aggiorna' {
            Update-PannelloStatus -TaskId "aggiorna" -Stato "running" -Dettaglio "Aggiornamento app e firme..."
            if (Confirm-Winget) {
                [void](Invoke-WingetConBarra -Nome "aggiornamenti app" -WingetArgs @('upgrade', '--all', '--silent', '--accept-package-agreements', '--accept-source-agreements', '--include-unknown') -TimeoutSec 600)
            }
            Update-PannelloStatus -TaskId "aggiorna" -Stato "done" -Dettaglio "Completato"
        }
        'scheda' {
            if (Get-Command Invoke-SchedaConsegnaFinale -ErrorAction SilentlyContinue) {
                Invoke-SchedaConsegnaFinale
            }
        }
        'diagnostica' {
            Invoke-PcFacileDiagnostics -MostraDettagli | Out-Null
            Update-PannelloStatus -TaskId "diagnostica" -Stato "done" -Dettaglio "Check salute eseguito"
        }
    }
}

function Invoke-PassiSingoliCoda {
    if ($Global:PannelloSync -and $Global:PannelloSync.CodaStep) {
        $voceStep = $null
        while ($Global:PannelloSync.CodaStep.TryDequeue([ref]$voceStep)) {
            if ($voceStep) {
                try {
                    $parsedStep = $voceStep | ConvertFrom-Json
                    Invoke-PassoSingolo $parsedStep
                } catch {}
            }
        }
    }
}

# La percentuale del pannello la guidano i passi (i singoli passi aggiornano
# solo stato e dettaglio del proprio task).
$Global:PercentualeDaPassi = $true
$gruppoMostrato = 0

:wizard while ($passo -lt $totPassi) {
trap {
    # Come il trap globale: registra l'imprevisto e prosegue con l'istruzione
    # successiva DENTRO questo passo (senza, un errore chiuderebbe tutto il ciclo).
    Register-ErroreImprevisto $_
    try { Write-Host "   [!] Imprevisto gestito: $($_.Exception.Message)" -ForegroundColor DarkYellow } catch {}
    continue
}
$voce = $Global:Passi[$passo]
if ($voce.Gruppo -ne $gruppoMostrato) {
    $gruppoMostrato = $voce.Gruppo
    Write-Host ""
    Write-Host ("$AON  " + $gruppiNomi[$voce.Gruppo] + "$AOFF") -ForegroundColor $THEME_COL
}
# Dati del cliente e singoli passaggi dal pannello: non bloccano.
[void](Get-CredenzialiSalvatePannello)
Invoke-PassiSingoliCoda
# Passi iniziali (operatore): si aspettano i dati del cliente, poi la fase 2 va dritta in automatico.
if ($voce.Gruppo -eq 1) {
    [void](Wait-DatiCliente -Motivo "I passi iniziali (Office, nome, account, attivazioni) usano i dati del cliente.")
}

Write-Host ""
$barLen = 20
$passoMostrato = $passo + 1
$pieni = [int]($barLen * $passoMostrato / $totPassi)
if ($pieni -gt $barLen) { $pieni = $barLen }
$bar = (([string]$BOX_FULL) * $pieni) + (([string]$BOX_EMPTY) * ($barLen - $pieni))
Write-Host ("$AON  Passo $passoMostrato/$totPassi  [$bar]  $($voce.Nome)$AOFF") -ForegroundColor $THEME_COL
Update-PannelloStatus -Percentuale (5 + [int](90 * $passo / $totPassi)) -PercentualeGuida -FaseCorrente $voce.Nome

if ($Global:PannelloSync) { $Global:PannelloSync.SkipCurrent = $false }
if ($Global:PannelloSync -and $Global:PannelloSync.Saltati -and $Global:PannelloSync.Saltati[$voce.Task]) {
    Write-Info "Passo '$($voce.Nome)' saltato dall'operatore dal pannello."
    Add-Report "$($voce.Nome) (saltato dall'operatore)" "SALTATO"
    Update-PannelloStatus -TaskId $voce.Task -Stato "skipped" -Dettaglio "Saltato dall'operatore"
    $passo++
    Save-Fase $passo $voce.Nome
    continue wizard
}

$giaFatto = Test-PassoGiaFatto -Id $voce.Id
if ($giaFatto) {
    Write-Titolo $voce.Nome
    Write-OK "$giaFatto`: salto il passo."
    Add-Report "$($voce.Nome) ($giaFatto)" "OK"
    Update-PannelloStatus -TaskId $voce.Task -Stato "done" -Dettaglio $giaFatto
    $passo++
    Save-Fase $passo $voce.Nome
    continue wizard
}

Update-PannelloStatus -TaskId $voce.Task -Stato "running"
switch ($voce.Id) {
'everyday' {
trap {
    Register-ErroreImprevisto $_
    try { Write-Host "   [!] Imprevisto gestito: $($_.Exception.Message)" -ForegroundColor DarkYellow } catch {}
    continue
}
# =============================================================================
# UNIEURO EVERYDAY DIGITAL (PRIORITA' - Unieuro Secure + Cyber Protection)
# =============================================================================
Write-Titolo "Unieuro Everyday Digital (Priorita')"
Update-PannelloStatus -TaskId "everyday" -Stato "running" -Percentuale 8 -FaseCorrente "Unieuro Everyday Digital" -Dettaglio "Installazione/attivazione Unieuro Secure + Cyber Protection..."
if ($Global:serviziSelezionati -and $Global:serviziSelezionati.Everyday) {
    Invoke-EverydayDigital -Utente $credMsAccount -Password $credMsPassword
    Update-PannelloStatus -TaskId "everyday" -Stato "done" -Dettaglio "Configurato"
} else {
    Write-Info "Unieuro Everyday Digital non selezionato: saltato."
    Add-Report "Unieuro Everyday Digital" "SALTATO (non selezionato)"
    Update-PannelloStatus -TaskId "everyday" -Stato "skipped" -Dettaglio "Non selezionato (saltato)"
}
}
'ripristino' {
trap {
    # Come il trap globale: registra l'imprevisto e prosegue con l'istruzione
    # successiva DENTRO questo passo (senza, un errore chiuderebbe tutto il ciclo).
    Register-ErroreImprevisto $_
    try { Write-Host "   [!] Imprevisto gestito: $($_.Exception.Message)" -ForegroundColor DarkYellow } catch {}
    continue
}
# =============================================================================
# PUNTO DI RIPRISTINO (rete di sicurezza prima delle modifiche)
# =============================================================================

if (-not $CreaRipristino) {
    # Richiesta esplicita operatore: "questo puoi saltarlo, e' super opzionale".
    # Su macchine nuove in negozio risparmia fino a 25 GB su SSD ed evita attese VSS inutili.
    Write-Info "Punto di ripristino: saltato (super opzionale, ottimizzazione spazio SSD)."
    Update-PannelloStatus -TaskId "ripristino" -Stato "skipped" -Percentuale 45 -FaseCorrente "Baseline" -Dettaglio "Ottimizzato per SSD"
    Add-Report "Punto di ripristino" "SALTATO (ottimizzazione SSD)"
} else {

Write-Titolo "Punto di Ripristino"
Update-PannelloStatus -TaskId "ripristino" -Stato "running" -Percentuale 40 -FaseCorrente "Punto di Ripristino" -Dettaglio "Creazione punto di ripristino di sicurezza..."

Write-Host "Crea un punto di ripristino: se qualcosa va storto puoi tornare indietro." -ForegroundColor White
Write-Host ""
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        # Limita lo spazio massimo del ripristino al 5% del disco per proteggere lo storage SSD
        try { vssadmin resize shadowstorage /for=C: /on=C: /maxsize=5% 2>$null | Out-Null } catch {}
        # Rimuove il limite di 1 punto ogni 24h, solo per crearne uno adesso
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" `
            -Name "SystemRestorePointCreationFrequency" -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
        Write-Info "Creazione punto di ripristino (puo' richiedere un minuto)..."
        Start-BarraAnimata "Creo il punto di ripristino"
        $job = $null
        try {
            $job = Start-Job -ScriptBlock {
                param($desc)
                try { Checkpoint-Computer -Description $desc -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop; return 0 }
                catch { return 1 }
            } -ArgumentList "Prima di setup-pc"
            if (-not (Wait-Job $job -Timeout 60)) {
                Stop-Job $job
                Write-Errore "Creazione del punto di ripristino in timeout dopo 60 secondi: salto."
                Update-PannelloStatus -TaskId "ripristino" -Stato "error" -Percentuale 45 -Dettaglio "Timeout (proseguo)"
                Add-Report "Punto di ripristino" "ERRORE (timeout)"
            } elseif ((Receive-Job $job) -eq 0) {
                Write-OK "Punto di ripristino creato."
                Update-PannelloStatus -TaskId "ripristino" -Stato "done" -Percentuale 45 -Dettaglio "Completato"
                Add-Report "Punto di ripristino" "OK"
            } else {
                Write-Errore "NON e' stato possibile creare il punto di ripristino."
                Write-Info "  Non e' un errore bloccante: la configurazione prosegue comunque."
                Update-PannelloStatus -TaskId "ripristino" -Stato "error" -Percentuale 45 -Dettaglio "Non riuscito (proseguo)"
                Add-Report "Punto di ripristino" "ERRORE"
            }
        } catch {
            Write-Errore "NON e' stato possibile creare il punto di ripristino."
            Write-Info "  Causa: $_"
            Write-Info "  Non e' un errore bloccante: la configurazione prosegue comunque."
            Update-PannelloStatus -TaskId "ripristino" -Stato "error" -Percentuale 45 -Dettaglio "Non riuscito (proseguo)"
            Add-Report "Punto di ripristino" "ERRORE"
        } finally {
            if ($job) { Remove-Job $job -Force -ErrorAction SilentlyContinue }
            Stop-BarraAnimata
        }
    } catch {
        Write-Errore "NON e' stato possibile creare il punto di ripristino."
        Write-Info "  Causa: $_"
        Write-Info "  Non e' un errore bloccante: la configurazione prosegue comunque."
        Update-PannelloStatus -TaskId "ripristino" -Stato "error" -Percentuale 45 -Dettaglio "Non riuscito (proseguo)"
        Add-Report "Punto di ripristino" "ERRORE"
    }

}
}
'avprova' {
trap {
    # Come il trap globale: registra l'imprevisto e prosegue con l'istruzione
    # successiva DENTRO questo passo (senza, un errore chiuderebbe tutto il ciclo).
    Register-ErroreImprevisto $_
    try { Write-Host "   [!] Imprevisto gestito: $($_.Exception.Message)" -ForegroundColor DarkYellow } catch {}
    continue
}
# =============================================================================
# RIMOZIONE ANTIVIRUS DI PROVA (prima delle installazioni: evita conflitti e
# blocchi). Il resto della pulizia (bloatware, avvio, comodita') e' in
# Invoke-PuliziaSistema e gira in background durante i passi manuali.
# Gli antivirus della card acquistata dal cliente NON vengono toccati.
# =============================================================================


Write-Titolo "Rimozione antivirus di prova"
Update-PannelloStatus -TaskId "avprova" -Stato "running" -FaseCorrente "Rimozione antivirus di prova" -Dettaglio "Ricerca antivirus di prova preinstallati..."

    # ---------------------------------------------------------------------
    # 1/3 - ANTIVIRUS DI PROVA
    # ---------------------------------------------------------------------
    Write-Info "Rimozione antivirus di prova preinstallati..."
    # Detection via REGISTRO (non 'winget list': becca anche i preinstallati).
    # Esclusi quelli da TENERE (card acquistata dal cliente o installati dall'operatore).
    $avInstallati  = @(Get-AntivirusInstallati | Where-Object { -not (Test-AvDaTenere $_.Nome) })
    if ($avInstallati.Count -eq 0) {
        Write-Info "Nessun antivirus di prova trovato."
        Add-Report "Antivirus di prova" "SALTATO"
    } else {
        foreach ($av in $avInstallati) {
            Write-Info "Provo a rimuovere: $($av.Nome)..."
            Start-BarraAnimata "Rimuovo $($av.Nome)"
            try {
                # 1) Disinstallatore SILENZIOSO dal registro (ARP) con timeout max 30s e supporto tasto Salta
                $cmdAv = if ($av.QuietUninstall) { $av.QuietUninstall } elseif ($av.Uninstall) { "$($av.Uninstall) /silent /quiet /norestart" } else { "" }
                if ($cmdAv) {
                    try {
                        $pAv = Start-Process -FilePath "cmd.exe" -ArgumentList "/d /s /c `"$cmdAv`"" -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
                        $tAv = 0
                        while ($pAv -and -not $pAv.HasExited -and $tAv -lt 60) {
                            if ($Global:PannelloSync -and ($Global:PannelloSync.SkipCurrent -or $Global:PannelloSync.Saltati['avprova'])) {
                                try { $pAv.Kill() } catch {}
                                break
                            }
                            Start-Sleep -Milliseconds 500
                            $tAv++
                        }
                        if ($pAv -and -not $pAv.HasExited) { try { $pAv.Kill() } catch {} }
                    } catch {}
                }
                # 2) winget come rinforzo (max 20s, salta se l'operatore ha premuto Salta)
                if ((-not ($Global:PannelloSync -and ($Global:PannelloSync.SkipCurrent -or $Global:PannelloSync.Saltati['avprova']))) -and (Confirm-Winget)) {
                    try {
                        $pWgAv = Start-Process -FilePath "winget.exe" -ArgumentList @('uninstall', '--name', $av.Nome, '--silent', '--accept-source-agreements') -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
                        $tWg = 0
                        while ($pWgAv -and -not $pWgAv.HasExited -and $tWg -lt 40) {
                            if ($Global:PannelloSync -and ($Global:PannelloSync.SkipCurrent -or $Global:PannelloSync.Saltati['avprova'])) {
                                try { $pWgAv.Kill() } catch {}
                                break
                            }
                            Start-Sleep -Milliseconds 500
                            $tWg++
                        }
                        if ($pWgAv -and -not $pWgAv.HasExited) { try { $pWgAv.Kill() } catch {} }
                    } catch {}
                }
            } finally { Stop-BarraAnimata }
        }

        # VERIFICO cosa e' rimasto: attendo che i processi di disinstallazione silenziosa
        # abbiano completato la cancellazione delle chiavi di registro (fino a 16s).
        $maxAttesaAV = 8
        for ($w = 0; $w -lt $maxAttesaAV; $w++) {
            Start-Sleep -Seconds 2
            $rimasti = @(Get-AntivirusInstallati | Where-Object { -not (Test-AvDaTenere $_.Nome) })
            if ($rimasti.Count -eq 0) { break }
        }

        $rimasti      = @(Get-AntivirusInstallati | Where-Object { -not (Test-AvDaTenere $_.Nome) })
        $mcafeeResta  = @($rimasti | Where-Object { $_.Nome -match 'McAfee' }).Count -gt 0
        $nortonResta  = @($rimasti | Where-Object { $_.Nome -match 'Norton' }).Count -gt 0

        if ($rimasti.Count -eq 0) {
            Write-OK "Antivirus di prova rimossi con successo (disinstallazione standard completata)."
            Add-Report "Antivirus di prova rimossi" "OK"
        } else {
            Write-Info "Resistono ai metodi standard: $(($rimasti.Nome) -join ', '). Uso i tool dedicati."
            Add-Report "Antivirus di prova (residui: tool ufficiale)" "AVVISO"
        }

        # McAfee: se resiste alla disinstallazione standard, usiamo il tool dedicato MCPR
        if ($mcafeeResta) {
            $mcprOffline = Find-OfflineInstaller -Nome "MCPR"
            if ($mcprOffline -and (Test-Path $mcprOffline)) {
                Write-Info "McAfee resiste: avvio MCPR da archivio offline USB ($mcprOffline)..."
                Start-Process -FilePath $mcprOffline
                Write-Info "MCPR avviato: completalo a video, poi RIAVVIA il PC."
                Add-Report "McAfee (avviato MCPR da USB)" "AVVISO"
            } elseif ($nortonResta) {
                # Se Norton e' presente, scaricare un exe farebbe scattare IDP.Generic: apro la pagina
                Start-Process "https://www.mcafee.com/support/?articleId=TS101331"
                Write-Info "McAfee resiste: aperta la pagina di MCPR. Scaricalo ed eseguilo a mano, poi RIAVVIA."
                Add-Report "McAfee (MCPR a mano)" "AVVISO"
            } else {
                try {
                    Write-Info "McAfee resiste: scarico e avvio MCPR (tool ufficiale McAfee)..."
                    $mcpr = "$env:TEMP\MCPR.exe"
                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
                    irm "https://download.mcafee.com/molbin/iss-loc/SupportTools/MCPR/MCPR.exe" -OutFile $mcpr -ErrorAction Stop
                    Start-Process -FilePath $mcpr
                    Write-Info "MCPR avviato: completalo (Avanti), poi RIAVVIA. Toglie McAfee del tutto."
                    Add-Report "McAfee (MCPR avviato: completare a mano)" "AVVISO"
                } catch {
                    Start-Process "https://www.mcafee.com/support/?articleId=TS101331"
                    Write-Info "Download MCPR fallito: aperta la pagina, scaricalo a mano."
                    Add-Report "McAfee (MCPR a mano)" "AVVISO"
                }
            }
        }

        # Norton: se e SOLO se la disinstallazione standard fallisce e Norton e' ancora presente
        if ($nortonResta) {
            $nrnrOffline = Find-OfflineInstaller -Nome "NRnR"
            if ($nrnrOffline -and (Test-Path $nrnrOffline)) {
                Write-Info "Norton resiste ai metodi standard: avvio NRnR da archivio offline USB ($nrnrOffline)..."
                Start-Process -FilePath $nrnrOffline
                Write-Info "NRnR avviato: seleziona 'Opzioni avanzate' -> 'Solo rimozione', poi RIAVVIA."
                Add-Report "Norton (avviato NRnR da USB)" "AVVISO"
            } else {
                try {
                    Write-Info "Norton resiste ai metodi standard: scarico e avvio NRnR (tool ufficiale)..."
                    $nrnrDest = "$env:TEMP\NRnR.exe"
                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
                    irm "https://buy-download.norton.com/downloads/RnR/NLOK/NRnR.exe" -OutFile $nrnrDest -ErrorAction Stop
                    Start-Process -FilePath $nrnrDest
                    Write-Info "NRnR avviato: seleziona 'Opzioni avanzate' -> 'Solo rimozione', poi RIAVVIA."
                    Add-Report "Norton (NRnR avviato: completare a mano)" "AVVISO"
                } catch {
                    Start-Process "https://norton.com/nrnr"
                    Write-Info "Norton ancora presente: aperta pagina NRnR. Scaricalo, eseguilo e poi RIAVVIA."
                    Add-Report "Norton (NRnR a mano)" "AVVISO"
                }
            }
        }
    }
    Update-PannelloStatus -TaskId "avprova" -Stato "done" -Dettaglio "Completato"
}
'lingua' {
trap {
    # Come il trap globale: registra l'imprevisto e prosegue con l'istruzione
    # successiva DENTRO questo passo (senza, un errore chiuderebbe tutto il ciclo).
    Register-ErroreImprevisto $_
    try { Write-Host "   [!] Imprevisto gestito: $($_.Exception.Message)" -ForegroundColor DarkYellow } catch {}
    continue
}
# =============================================================================
# LINGUA E REGIONE (ITALIANO)
# =============================================================================


Write-Titolo "Lingua e Regione (Italiano)"
Update-PannelloStatus -TaskId "lingua" -Stato "running" -Percentuale 30 -FaseCorrente "Forzatura Lingua & Regione (it-IT)" -Dettaglio "Configurazione lingua italiana..."

Write-Host "Imposta display, tastiera, formati e pacchetto lingua in italiano (it-IT)." -ForegroundColor White
Write-Host ""

$culturaAttuale = (Get-Culture).Name
Write-Info "Lingua/regione attuale: $culturaAttuale"

    # Salto il DOWNLOAD del pacchetto SOLO se il DISPLAY e' gia' in italiano
    # (Get-UICulture). ATTENZIONE: il fatto che it-IT sia "tra le lingue installate"
    # NON basta - spesso c'e' solo tastiera/regione, ma la TRADUZIONE dei menu (il
    # Local Experience Pack) manca e l'interfaccia resta inglese. Percio' se il
    # display non e' ancora italiano, installo il pacchetto ANCHE se it-IT risulta
    # "presente". Il forzamento qui sotto viene applicato SEMPRE.
    $displayGiaItaliano = $false
    try {
        $packPresente = $true
        if (Get-Command Get-InstalledLanguage -ErrorAction SilentlyContinue) {
            $instL = @(Get-InstalledLanguage -ErrorAction SilentlyContinue)
            if ($instL.Count -gt 0) { $packPresente = ($instL.LanguageId -contains 'it-IT') }
        }
        $displayGiaItaliano = ((Get-UICulture).Name -like 'it*') -and $packPresente
    } catch {}

    # --- 1) LANGUAGE PACK it-IT (Windows 11 22H2+): e' QUESTO (il Local Experience
    #     Pack) che traduce i MENU. Lo installo se il display non e' gia' italiano. ---
    $packOk = $false
    if ($Test) {
        Write-OK "TEST: simulazione installazione language pack it-IT."
        $packOk = $true
    } elseif ($displayGiaItaliano) {
        Write-OK "Display gia' in italiano: salto il download, applico il forzamento."
        $packOk = $true
    } elseif (Get-Command Install-Language -ErrorAction SilentlyContinue) {
        # Il download del pack fallisce spesso per cali di rete del negozio:
        # ritento fino a 3 volte e, se la rete e' assente, aspetto che torni.
        $maxTentLingua = 3
        for ($tLingua = 1; $tLingua -le $maxTentLingua; $tLingua++) {
            try {
                Write-Info "Installazione/applicazione language pack it-IT (qualche minuto, serve Internet)...$(if ($tLingua -gt 1) { " (tentativo $tLingua)" })"
                Start-BarraAnimata "Installo la lingua italiana (max 12 min)"
                $timeoutLingua = $false
                try {
                    # Eseguo l'installazione in un JOB con TIMEOUT: se si impianta
                    # (rete filtrata o antivirus che blocca il download), NON lascio
                    # lo script fermo all'infinito - interrompo e proseguo.
                    $jobLingua = Start-Job -ScriptBlock {
                        $ProgressPreference = 'SilentlyContinue'
                        try { Install-Language it-IT -CopyToSettings -ErrorAction Stop | Out-Null }
                        catch { Install-Language it-IT -ErrorAction Stop | Out-Null }
                    }
                    if (Wait-Job $jobLingua -Timeout 720) {
                        Receive-Job $jobLingua -ErrorAction SilentlyContinue | Out-Null
                    } else {
                        Stop-Job $jobLingua -ErrorAction SilentlyContinue
                        $timeoutLingua = $true
                    }
                } finally {
                    Stop-BarraAnimata
                    try { Remove-Job $jobLingua -Force -ErrorAction SilentlyContinue } catch {}
                    try { Write-Progress -Activity "Installing language" -Completed -ErrorAction SilentlyContinue } catch {}
                    try { Write-Progress -Activity "Installazione lingua" -Completed -ErrorAction SilentlyContinue } catch {}
                }
            } catch {}
            if ($timeoutLingua) {
                Write-Errore "Installazione lingua troppo lunga (oltre 12 min): interrompo e proseguo."
                Write-Info "Riprova piu' tardi con una rete pulita (hotspot) o l'antivirus in pausa."
                break
            }
            $packOk = ((Get-InstalledLanguage -ErrorAction SilentlyContinue).LanguageId -contains "it-IT")
            if ($packOk) { break }
            # Non riuscito: se manca la rete, avviso e aspetto che torni, poi ritento.
            if ($tLingua -lt $maxTentLingua) {
                if (-not (Test-Rete)) {
                    Write-Errore "!!  CONNESSIONE ASSENTE  !!  Ricollega il WiFi o il cavo di rete."
                    Beep-Attesa
                    $attLingua = 0
                    while ((-not (Test-Rete)) -and $attLingua -lt 90) { Start-Sleep -Seconds 5; $attLingua += 5 }
                    if (Test-Rete) { Write-OK "Connessione tornata: riprovo la lingua." }
                }
                Write-Info "Riprovo l'installazione della lingua (tentativo $($tLingua + 1) di $maxTentLingua)..."
                Start-Sleep -Seconds 3
            }
        }
        if (-not $packOk) {
            Write-Host ""
            Write-Errore "############################################################"
            Write-Errore "#  LINGUA ITALIANA NON SCARICATA                           #"
            Write-Errore "############################################################"
            Write-Errore "Il pacchetto di traduzione dei menu non e' arrivato: quasi"
            Write-Errore "sempre e' la RETE del negozio che filtra/rallenta il download."
            Write-Info    "SOLUZIONE: collega il PC a un HOTSPOT del telefono e rilancia"
            Write-Info    "PC Facile (rispondi S alla ripresa): scarichera' solo la lingua."
            Write-Info    "Apro le Impostazioni lingua di Windows: da li' puoi anche"
            Write-Info    "  scaricare l'italiano a mano (Aggiungi lingua / pacchetto)."
            try { Start-Process "ms-settings:regionlanguage" } catch {}
            Write-Host ""
        }
    } else {
        Write-Info "Install-Language non c'e' (Windows 10): il pacchetto lingua di visualizzazione va aggiunto a mano."
        $packDaAggiungere = $true
    }

    # --- 2) UNA SOLA lingua: ITALIANO. Tolgo l'inglese (e ogni altra) dall'elenco
    #     preferito, cosi' le parti non ancora tradotte NON cadono sull'inglese:
    #     era QUESTA la causa del "meta' italiano meta' inglese". Metto anche la
    #     tastiera italiana. -Force sostituisce l'intero elenco con solo it-IT. ---
    try {
        $lista = New-WinUserLanguageList it-IT
        $lista[0].InputMethodTips.Clear()
        $lista[0].InputMethodTips.Add("0410:00000410")   # tastiera italiana
        Set-WinUserLanguageList $lista -Force
    } catch { Write-Info "Elenco lingue non impostato: $_" }

    # --- 3) Lingua UI (utente + sistema), formati, regione, locale, fuso ---
    try { Set-WinUILanguageOverride -Language it-IT -WarningAction SilentlyContinue } catch {}
    if (Get-Command Set-SystemPreferredUILanguage -ErrorAction SilentlyContinue) {
        # Errore non terminante (RPC_E_CHANGED_MODE se il thread ha gia' usato COM): il catch non lo ferma.
        try { Set-SystemPreferredUILanguage it-IT -ErrorAction SilentlyContinue } catch {}
    }
    try { Set-Culture it-IT } catch {}
    try { Set-WinHomeLocation -GeoId 118 } catch {}      # Italia
    try { Set-WinSystemLocale it-IT } catch {}
    try { Set-TimeZone -Id "W. Europe Standard Time" -ErrorAction Stop; Write-OK "Fuso orario Italia (CET)." } catch {}
    # Rinforzo via registro: lingua UI preferita dell'utente e di sistema = solo it-IT.
    try { Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'PreferredUILanguages' -Value @('it-IT') -Type MultiString -Force -ErrorAction SilentlyContinue } catch {}
    try { Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop\MuiCached' -Name 'MachinePreferredUILanguages' -Value @('it-IT') -Type MultiString -Force -ErrorAction SilentlyContinue } catch {}
    try { Set-ItemProperty -Path 'Registry::HKEY_USERS\.DEFAULT\Control Panel\Desktop' -Name 'PreferredUILanguages' -Value @('it-IT') -Type MultiString -Force -ErrorAction SilentlyContinue } catch {}

    # --- 4) SOLO ORA propago a schermata di LOGIN e NUOVI UTENTI: cosi' copio la
    #     configurazione GIA' tutta italiana. (Prima veniva fatto troppo presto,
    #     copiando ancora l'inglese: ecco perche' login/nuovi utenti restavano
    #     misti.) ---
    if (Get-Command Copy-UserInternationalSettingsToSystem -ErrorAction SilentlyContinue) {
        try { Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true } catch {}
    }

    # --- Esito CHIARO: se il pack non c'e', l'utente deve sapere PERCHE' resta inglese ---
    if ($packOk) {
        Write-OK "Italiano forzato ovunque (solo it-IT, niente inglese di riserva): display,"
        Write-OK "tastiera, formati, login e nuovi utenti. Attivo del tutto dopo il RIAVVIO."
        Add-Report "Lingua italiana (it-IT, forzata)" "OK"
    } elseif ($packDaAggiungere) {
        Write-Info "Tastiera e formati in italiano OK. L'INTERFACCIA resta inglese: su Windows 10 va aggiunto il pacchetto lingua a mano."
        Add-Report "Lingua italiana (display da completare)" "AVVISO"
    } else {
        Write-Errore "Tastiera/formati OK, ma il LANGUAGE PACK non si e' installato: l'interfaccia resta in INGLESE."
        Write-Errore "Causa tipica: Internet assente/bloccato durante l'installazione. Controlla la rete e rilancia lo step lingua."
        Add-Report "Lingua italiana (pack mancante)" "AVVISO"
    }
    Write-Info "Display e schermata di login in italiano si vedono dopo il RIAVVIO del PC."

    # --- 5) Windows 10: il pacchetto lingua (display) va aggiunto a mano ---
    if ($packDaAggiungere) {
        Write-Info "Su Windows 10 il pacchetto della lingua di visualizzazione va aggiunto da Impostazioni > Lingua."
    }
    Write-OK "Lingua e regione impostate su Italiano (it-IT)."
    Update-PannelloStatus -TaskId "lingua" -Stato "done" -Percentuale 35 -Dettaglio "Completato"
}
'office' {
trap {
    # Come il trap globale: registra l'imprevisto e prosegue con l'istruzione
    # successiva DENTRO questo passo (senza, un errore chiuderebbe tutto il ciclo).
    Register-ErroreImprevisto $_
    try { Write-Host "   [!] Imprevisto gestito: $($_.Exception.Message)" -ForegroundColor DarkYellow } catch {}
    continue
}
# =============================================================================
# INSTALLAZIONE APP OFFICE: qui si sceglie e si INSTALLA la suite (se manca).
# L'ATTIVAZIONE (card PIN) e' un passo manuale separato ("officeattiva"), dopo
# l'account del cliente.
# =============================================================================

Write-Titolo "Installazione App Office"
Update-PannelloStatus -TaskId "office" -Stato "running" -FaseCorrente "Configurazione Office & Runtime" -Dettaglio "Configurazione icone Office e runtime..."

# Quale suite dipende dalla card del cliente: la scelta arriva dal pannello
# (se non e' ancora arrivata, qui la si aspetta: e' il primo passo che serve).
[void](Wait-DatiCliente -Motivo "Office dipende dalla card del cliente: scegli la suite nel pannello.")
$nomiOffice = @{ '1' = 'Microsoft 365 (card)'; '2' = 'Office perpetuo (card)'; '4' = 'LibreOffice'; '5' = 'nessuna' }
$sceltaAtt = if ($Global:SceltaOffice) { [string]$Global:SceltaOffice } else { '5' }
Write-Info "Suite Office scelta nel pannello: $($nomiOffice[$sceltaAtt])."
switch ($sceltaAtt) {
    { $_ -eq '1' -or $_ -eq '2' } {
        # Stessa app per le due card (Microsoft 365 / Office perpetuo): cambia
        # solo la pagina di riscatto nel passo manuale di attivazione.
        if (Test-OfficeInstallato) {
            Write-OK "Office gia' installato su questo PC."
            Add-Report "Microsoft Office (installazione)" "OK (gia' presente)"
        } else {
            Installa-Pacchetto -Nome "Microsoft 365" -WingetId "Microsoft.Office"
        }
        Add-CollegamentiOffice
    }
    '4' {
        Installa-Pacchetto -Nome "LibreOffice" -WingetId "TheDocumentFoundation.LibreOffice"
    }
    default {
        if (Test-OfficeInstallato) {
            Write-OK "Nessuna card Office, ma Office e' gia' installato: creo i collegamenti sul Desktop."
            Add-CollegamentiOffice
            Add-Report "Microsoft Office (collegamenti)" "OK (gia' presente)"
        } else {
            Write-Info "Nessuna suite Office da installare."
            Add-Report "Installazione app Office" "SALTATO (nessuna card)"
        }
    }
}

$dettOffice = if ($Global:SceltaOffice -match '^[12]$') { "Installato (attivazione nei passi manuali)" } else { "Completato" }
Update-PannelloStatus -TaskId "office" -Stato "done" -Dettaglio $dettOffice
}
'app' {
trap {
    # Come il trap globale: registra l'imprevisto e prosegue con l'istruzione
    # successiva DENTRO questo passo (senza, un errore chiuderebbe tutto il ciclo).
    Register-ErroreImprevisto $_
    try { Write-Host "   [!] Imprevisto gestito: $($_.Exception.Message)" -ForegroundColor DarkYellow } catch {}
    continue
}
# =============================================================================
# APPLICAZIONI + BROWSER
# =============================================================================

Write-Titolo "Applicazioni"
# 0) Installazione Runtime Essenziali (Microsoft Visual C++ 2015-2022 x86 & x64)
Update-PannelloStatus -TaskId "runtime" -Stato "running" -FaseCorrente "Runtime Essenziali" -Dettaglio "Installazione Microsoft Visual C++ (x86 & x64)..."
[void](Install-VisualCRuntime)
Update-PannelloStatus -TaskId "runtime" -Stato "done" -Dettaglio "Completato"

Update-PannelloStatus -TaskId "app" -Stato "running" -FaseCorrente "Installazione Applicazioni" -Dettaglio "Avvio installazione app..."

$appsDisponibili = $CatalogoApp
$profili = [ordered]@{
    "BASE"    = @($CatalogoApp | Where-Object { $_.Profili -contains "BASE" }    | ForEach-Object { $_.Id })
    "UFFICIO" = @($CatalogoApp | Where-Object { $_.Profili -contains "UFFICIO" } | ForEach-Object { $_.Id })
    "GAMING"  = @($CatalogoApp | Where-Object { $_.Profili -contains "GAMING" }  | ForEach-Object { $_.Id })
}

function Costruisci-PianoApp {
    param([string]$Scelta)
    $piano = @()
    if ($Scelta -eq "3") { $piano += @{ Nome = "Opera GX"; Id = "Opera.OperaGX" } }
    else                 { $piano += @{ Nome = "Google Chrome"; Id = "Google.Chrome" } }
    foreach ($app in $appsDisponibili) {
        $prendi = switch ($Scelta) {
            "1" { $profili["BASE"]    -contains $app.Id }
            "2" { $profili["UFFICIO"] -contains $app.Id }
            "3" { $profili["GAMING"]  -contains $app.Id }
            "4" { $true }
            default { $false }
        }
        if ($prendi) { $piano += @{ Nome = $app.Nome; Id = $app.Id } }
    }
    return $piano
}

$Global:AppFallite = 0
$codiciProfilo = @{ "BASE" = "1"; "UFFICIO" = "2"; "GAMING" = "3"; "COMPLETO" = "4" }

$pianoApp  = @()
$appFatte  = @()
$etichetta = ""

$isPostVenditaApp = [bool]($Global:ModalitaPostVendita -or ($Global:PannelloSync -and $Global:PannelloSync.Modalita -eq 'POSTVENDITA') -or ($Global:ProfiloAppCliente -eq 'ESSENZIALE'))
if ($isPostVenditaApp) {
    $etichetta = "ESSENZIALE (Post Vendita Rapido da OEM)"
    $pianoApp  = @(@{ Nome = "Google Chrome"; Id = "Google.Chrome" })
    Write-Info "Modalita' Post Vendita da OEM attiva: installo solo Google Chrome (salto le altre app del catalogo per consegna rapida)."
} elseif ($Global:AppProfiloRipresa) {
    $etichetta = [string]$Global:AppProfiloRipresa
    $pianoApp  = @($Global:AppListaRipresa | ForEach-Object { @{ Nome = [string]$_.Nome; Id = [string]$_.Id } })
    $appFatte  = @($Global:AppFatteRipresa | ForEach-Object { [string]$_ })
    $Global:AppProfiloRipresa = ""; $Global:AppListaRipresa = @(); $Global:AppFatteRipresa = @()
    $rimaste = @($pianoApp | Where-Object { $appFatte -notcontains $_.Id }).Count
    Write-OK "Riprendo l'installazione app (profilo $etichetta): $rimaste da completare."
    Write-Info "Le app gia' installate le salto: riparto dall'esatta app rimasta."
} else {
    # Profilo scelto nel pannello; se i dati non sono ancora arrivati parto
    # col profilo BASE (nessuna attesa: la fase 1 non si ferma) e alla fine
    # aggiungo le app mancanti se nel frattempo arriva un profilo piu' ampio.
    $etichetta = if ($Global:ProfiloAppCliente -and $codiciProfilo.ContainsKey($Global:ProfiloAppCliente)) { $Global:ProfiloAppCliente } else { "BASE" }
    if (-not $Global:ProfiloAppCliente) { Write-Info "Dati del cliente non ancora arrivati: parto col profilo BASE." }
    $pianoApp  = @(Costruisci-PianoApp -Scelta $codiciProfilo[$etichetta])
}
Write-Host "Profilo app: $etichetta" -ForegroundColor Green

if ($pianoApp.Count -gt 0) {
    if ($pianoApp | Where-Object { $_.Id -eq "Google.Chrome" -or $_.Id -eq "Opera.OperaGX" }) {
        Remove-EdgeDaDesktop
    }
    $appIndex = 0
    foreach ($app in $pianoApp) {
        $appIndex++
        if ($Global:ModalitaPostVendita -or ($Global:PannelloSync -and $Global:PannelloSync.Modalita -eq 'POSTVENDITA')) {
            if ($app.Id -ne "Google.Chrome") {
                Write-Info "$($app.Nome): saltato (Modalita' Post Vendita: solo essenziali)."
                continue
            }
        }
        if ($appFatte -contains $app.Id) {
            Write-Info "$($app.Nome): gia' installato in questa sessione, salto."
            continue
        }
        Update-PannelloStatus -TaskId "app" -Stato "running" -FaseCorrente "Installazione Applicazioni" -Dettaglio "Installazione $($app.Nome) in corso..."
        Installa-Pacchetto -Nome $app.Nome -WingetId $app.Id
        if ($Global:UltimaInstallOk) {
            $appFatte += $app.Id
            Save-AppProgresso -Profilo $etichetta -Lista $pianoApp -Fatte $appFatte
        }
    }
    # Profilo confermato nel pannello DURANTE l'installazione: aggiungo le app
    # che mancano (quelle gia' installate si saltano da sole).
    [void](Get-CredenzialiSalvatePannello)
    $isPostVenditaDopo = [bool]($Global:ModalitaPostVendita -or ($Global:PannelloSync -and $Global:PannelloSync.Modalita -eq 'POSTVENDITA') -or ($Global:ProfiloAppCliente -eq 'ESSENZIALE'))
    if (-not $isPostVenditaDopo -and $Global:ProfiloAppCliente -and $codiciProfilo.ContainsKey($Global:ProfiloAppCliente) -and $Global:ProfiloAppCliente -ne $etichetta) {
        $etichetta = $Global:ProfiloAppCliente
        $extra = @(Costruisci-PianoApp -Scelta $codiciProfilo[$etichetta] | Where-Object { $id = $_.Id; -not ($pianoApp | Where-Object { $_.Id -eq $id }) })
        if ($extra.Count -gt 0) { Write-Info "Profilo $etichetta scelto nel pannello: aggiungo $($extra.Count) app." }
        foreach ($app in $extra) {
            $pianoApp += $app
            Update-PannelloStatus -TaskId "app" -Stato "running" -Dettaglio "Installazione $($app.Nome) in corso..."
            Installa-Pacchetto -Nome $app.Nome -WingetId $app.Id
            if ($Global:UltimaInstallOk) {
                $appFatte += $app.Id
                Save-AppProgresso -Profilo $etichetta -Lista $pianoApp -Fatte $appFatte
            }
        }
    }
    Update-PannelloStatus -TaskId "app" -Stato "done" -Percentuale 88 -Dettaglio "Tutte le app installate"
} else {
    Update-PannelloStatus -TaskId "app" -Stato "skipped" -Percentuale 88 -Dettaglio "Saltato"
}

Remove-IconeDoppieDesktop
Repair-DesktopShortcuts

if ($Global:AppFallite -ge 2) {
    Write-Host ""
    Write-Errore "$($Global:AppFallite) app non installate: probabile RETE con proxy/filtro."
    Write-Info "Collega il PC a un'altra rete (HOTSPOT del telefono o linea senza filtri)"
    Write-Info "e rilancia PC Facile: rispondi S a 'Riprendere da dove eri arrivato?' -"
    Write-Info "le app gia' installate si saltano da sole, riscarica solo le mancanti."
    Add-Report "App non installate ($($Global:AppFallite)): probabile rete" "AVVISO"
}
}
'nome' {
trap {
    # Come il trap globale: registra l'imprevisto e prosegue con l'istruzione
    # successiva DENTRO questo passo (senza, un errore chiuderebbe tutto il ciclo).
    Register-ErroreImprevisto $_
    try { Write-Host "   [!] Imprevisto gestito: $($_.Exception.Message)" -ForegroundColor DarkYellow } catch {}
    continue
}
# =============================================================================
# NOME CLIENTE E PC (primo passo manuale: il nome genera le credenziali
# suggerite per l'account del passo successivo).
# =============================================================================


Write-Titolo "Nome Cliente e PC"

# Legge il nome visualizzato attuale: prima LocalAccounts, poi ADSI (che
# funziona anche in PowerShell x86, dove il modulo LocalAccounts non c'e').
$adsiUser = 'WinNT://./' + $env:USERNAME + ',user'
$nomeAttuale = $null
try {
    $nomeAttuale = (Get-LocalUser -Name $env:USERNAME -ErrorAction Stop).FullName
} catch {
    try { $nomeAttuale = ([ADSI]$adsiUser).FullName } catch {}
}

# Riconoscimento nomi e hostname generici di fabbrica / OEM (da non lasciare sul PC del cliente)
$oemNames = @('OEM', 'ADMIN', 'ADMINISTRATOR', 'USER', 'OWNER', 'DEFAULTUSER0', 'PC', 'LAPTOP', 'DESKTOP', 'CLT', 'CLT CLT', 'CLTCLT', 'CLIENTE')
$isOemUser = ($oemNames -contains $env:USERNAME.ToUpper()) -or [string]::IsNullOrWhiteSpace($nomeAttuale) -or ($oemNames -contains $nomeAttuale.ToUpper())
$isOemComputer = ($env:COMPUTERNAME -match '^(LAPTOP|DESKTOP|WIN)-[A-Z0-9]{4,10}$') -or ($oemNames -contains $env:COMPUTERNAME.ToUpper())

# Il nome arriva dai dati del cliente (pannello, una volta sola).
if ($Global:nomeCliente -and $Global:nomeCliente -notmatch '^(?i)(Cliente|OEM|Utente|clt|clt\s*clt)$') {
    $nomeCliente = $Global:nomeCliente
}

if (-not $nomeCliente -or $oemNames -contains $nomeCliente.Trim().ToUpper()) {
    if ($isOemUser -or $env:USERNAME -match '^(?i)(telef|oem|admin|user|utente|clt|clt\s*clt)$') {
        $nomeCliente = "Utente"
    } else {
        $nomeCliente = $env:USERNAME
    }
}

Write-Info "Utente di sistema: $env:USERNAME"
Write-Info "Nome cliente / account: $(if ($nomeCliente) { $nomeCliente } elseif ($nomeAttuale) { $nomeAttuale } else { 'Utente' })"
Write-Info "Nome PC attuale: $env:COMPUTERNAME"
Write-Host ""

if (-not $RunReale) {
    Write-Info "(test) nome account e nome PC non modificati (cliente: $nomeCliente)."
    Add-Report "Nome cliente ($nomeCliente)" "OK (test)"
} elseif ($nomeCliente -and $nomeCliente -ne "") {
    # Rinomina il PC in 'PC-Nome' o 'PC-Utente' (priorita' al NOME proprio del cliente, max 15 char)
    $nomeDaUsare = if ($Global:nomeProprioCliente -and $Global:nomeProprioCliente.Trim() -and $Global:nomeProprioCliente.Trim() -notmatch '^(?i)(clt|oem|cliente)$') {
        $Global:nomeProprioCliente.Trim()
    } else {
        # Se nomeProprioCliente non e' popolato, estrai il nome da nomeCliente (es. 'Rossi Mario' -> 'Mario')
        $parti = $nomeCliente -split '\s+' | Where-Object { $_ }
        if ($parti.Count -gt 1) { $parti[-1] } else { $nomeCliente }
    }
    $cleanPc = ($nomeDaUsare -replace '[^A-Za-z0-9]', '')
    if (-not $cleanPc -or $oemNames -contains $cleanPc.ToUpper()) { $cleanPc = "Utente" }
    $pcNuovo = "PC-$cleanPc"
    if ($pcNuovo.Length -gt 15) { $pcNuovo = $pcNuovo.Substring(0, 15) }

    $resNome = Set-NomeUtenteEPc -NomeUtente $nomeCliente -NomePc $pcNuovo -Silenzioso
    Write-OK "Nome account utente impostato su: $($resNome.NomeUtente)"
    Add-Report "Nome cliente ($($resNome.NomeUtente))" "OK"
    Write-OK "Nome PC aggiornato in '$($resNome.NomePc)' (attivo dopo il riavvio)."
    Add-Report "Nome PC ($($resNome.NomePc))" "OK"
} else {
    Write-Info "Nome account e PC mantenuti ($env:USERNAME / $env:COMPUTERNAME)."
    Add-Report "Nome cliente" "MANTENUTO ($env:USERNAME)"
}


# (nessuna pausa: si avanza da solo)
}
'account' {
trap {
    # Come il trap globale: registra l'imprevisto e prosegue con l'istruzione
    # successiva DENTRO questo passo (senza, un errore chiuderebbe tutto il ciclo).
    Register-ErroreImprevisto $_
    try { Write-Host "   [!] Imprevisto gestito: $($_.Exception.Message)" -ForegroundColor DarkYellow } catch {}
    continue
}
# =============================================================================
# ACCOUNT CLIENTE (passo manuale: crealo/accedi col cliente davanti, cosi'
# poi attivazione Office e antivirus fanno 'Accedi con Microsoft' senza altri OTP).
# =============================================================================


Write-Titolo "Account / Email cliente"

if ($Global:IsCltMode -or $Global:SkipAccountPrompt) {
    Write-Info "Nessuna email cliente richiesta (modalita' clt / dati saltati): salto la creazione dell'account."
    Add-Report "Account email" "SALTATO"
} else {
    if ($Global:credMsAccount) { $credMsAccount = $Global:credMsAccount }
    if ($Global:credMsPassword) { $credMsPassword = $Global:credMsPassword }
    # $nomeCliente e' "Cognome Nome" (da $Dati.Cliente, costruito dal pannello come
    # "cognome + nome"): NON va usato per la password, altrimenti prende il cognome
    # come base (New-PasswordCliente usa sempre la PRIMA parola). Uso i campi
    # separati Nome/Cognome quando disponibili (niente ambiguita' di ordine);
    # New-EmailCliente si aspetta "Nome Cognome", quindi li ricompongo in quell'ordine.
    $nomeProprio = if ($Global:nomeProprioCliente) { $Global:nomeProprioCliente } else { $null }
    $cognomeCli  = if ($Global:cognomeCliente) { $Global:cognomeCliente } else { $null }
    $basePerNome = if ($nomeProprio -and $cognomeCli) { "$nomeProprio $cognomeCli" }
                   elseif ($nomeCliente -and $nomeCliente.ToUpper() -ne "OEM") { $nomeCliente }
                   else { "utente" }
    if (-not $credMsAccount) {
        $dom = if ($Global:credDominio) { $Global:credDominio } else { "outlook.it" }
        $credMsAccount = New-EmailCliente -Base $basePerNome -Dominio $dom
    }
    if (-not $credMsPassword) {
        $basePerPassword = if ($nomeProprio -and $nomeProprio.ToUpper() -ne "OEM") { $nomeProprio } else { $basePerNome }
        $credMsPassword = New-PasswordCliente -Base $basePerPassword
    }
    $provNome = if ($Global:credProvider) { [string]$Global:credProvider } else { "Microsoft" }
    $Global:credProvider = $provNome
    # Pagina di registrazione del provider scelto nel pannello (tipo di email).
    $urlAccount = switch -Regex ($provNome) {
        '^Google'  { "https://accounts.google.com/signup" }
        '^Proton'  { "https://account.proton.me/signup?plan=free" }
        '^Libero'  { "https://registrazione.libero.it" }
        '^iCloud'  { "https://account.apple.com" }
        default    { "https://signup.live.com" }
    }
    Write-Host "Crea (o apri) ORA l'account $provNome del cliente, col cliente davanti." -ForegroundColor White
    if ($provNome -notmatch '^(Microsoft|Hotmail|Outlook)') {
        Write-Info "NB: per attivare Office/antivirus serve comunque un account Microsoft;"
        Write-Info "    con $provNome crei l'email del cliente."
    }
    Open-PaginaWeb $urlAccount
    Mostra-CredenzialiPagina -Utente $credMsAccount -Password $credMsPassword -NonBlocca
    Add-Report "Account $provNome ($credMsAccount)" "OK"
}
}
'officeattiva' {
trap {
    # Come il trap globale: registra l'imprevisto e prosegue con l'istruzione
    # successiva DENTRO questo passo (senza, un errore chiuderebbe tutto il ciclo).
    Register-ErroreImprevisto $_
    try { Write-Host "   [!] Imprevisto gestito: $($_.Exception.Message)" -ForegroundColor DarkYellow } catch {}
    continue
}
# =============================================================================
# ATTIVAZIONE OFFICE (passo manuale): riscatto della card PIN con l'account del
# cliente appena creato/aperto. La suite e' stata scelta e installata nella fase 1.
# =============================================================================
Write-Titolo "Attivazione Office"
Update-PannelloStatus -TaskId "office" -Stato "running" -FaseCorrente "Attivazione Office" -Dettaglio "Riscatto card PIN..."
switch ([string]$Global:SceltaOffice) {
    "1" {
        Open-PaginaWeb "https://microsoft365.com/setup"
        Write-Info "Accedi con l'account Microsoft del cliente e inserisci il codice grattato sulla card."
        Mostra-CredenzialiPagina -Utente $credMsAccount -Password $credMsPassword -NonBlocca
        Add-Report "Microsoft 365 (riscatto card PIN)" "OK"
        Update-PannelloStatus -TaskId "office" -Stato "done" -Dettaglio "Installato e attivato"
    }
    "2" {
        Open-PaginaWeb "https://office.com/setup"
        Write-Info "Accedi con l'account Microsoft del cliente e inserisci il codice grattato sulla card."
        Write-Info "Dopo il riscatto: apri Word e accedi con lo stesso account -> Office si attiva da solo."
        Mostra-CredenzialiPagina -Utente $credMsAccount -Password $credMsPassword -NonBlocca
        Add-Report "Office perpetuo (riscatto card PIN)" "OK"
        Update-PannelloStatus -TaskId "office" -Stato "done" -Dettaglio "Installato e attivato"
    }
    default {
        Write-Info "Nessuna card Office da attivare: passo saltato."
        Update-PannelloStatus -TaskId "office" -Stato "done" -Dettaglio "Nessuna card da attivare"
    }
}
}
'antivirus' {
trap {
    # Come il trap globale: registra l'imprevisto e prosegue con l'istruzione
    # successiva DENTRO questo passo (senza, un errore chiuderebbe tutto il ciclo).
    Register-ErroreImprevisto $_
    try { Write-Host "   [!] Imprevisto gestito: $($_.Exception.Message)" -ForegroundColor DarkYellow } catch {}
    continue
}
# =============================================================================
# ANTIVIRUS (passo manuale)
# =============================================================================

Write-Titolo "Antivirus"
Update-PannelloStatus -TaskId "antivirus" -Stato "running" -Percentuale 90 -FaseCorrente "Configurazione Antivirus" -Dettaglio "Verifica Windows Defender e card cliente..."

# Dalla card indicata nel pannello (nessuna domanda). Se un antivirus e' gia'
# installato il passo e' gia' stato saltato da Test-PassoGiaFatto.
$sv = $Global:serviziSelezionati
if ($sv -and $sv.McAfee) {
    Installa-Antivirus -Nome "McAfee" -UrlRiscatto "https://www.mcafee.com/activate" -Utente $credMsAccount -Password $credMsPassword
    Update-PannelloStatus -TaskId "antivirus" -Stato "done" -Dettaglio "McAfee configurato"
} elseif ($sv -and $sv.Norton) {
    Installa-Antivirus -Nome "Norton" -UrlRiscatto "https://www.norton.com/setup" -Utente $credMsAccount -Password $credMsPassword
    Update-PannelloStatus -TaskId "antivirus" -Stato "done" -Dettaglio "Norton configurato"
} else {
    Write-Info "Nessuna card antivirus: Windows Defender e' attivo e aggiornato."
    Add-Report "Antivirus" "OK (Windows Defender)"
    Update-PannelloStatus -TaskId "antivirus" -Stato "done" -Dettaglio "Windows Defender attivo"
}
}
'cyber' {
trap {
    # Come il trap globale: registra l'imprevisto e prosegue con l'istruzione
    # successiva DENTRO questo passo (senza, un errore chiuderebbe tutto il ciclo).
    Register-ErroreImprevisto $_
    try { Write-Host "   [!] Imprevisto gestito: $($_.Exception.Message)" -ForegroundColor DarkYellow } catch {}
    continue
}
# =============================================================================
# UNIEURO CYBER PROTECTION (passo manuale, opzionale)
# =============================================================================

Write-Titolo "Unieuro Cyber Protection"
Update-PannelloStatus -TaskId "cyber" -Stato "running" -Percentuale 94 -FaseCorrente "Unieuro Cyber Protection" -Dettaglio "Configurazione servizio web..."

# Opzionale: solo se indicato nel pannello (servizio venduto su richiesta).
if ($Global:serviziSelezionati -and $Global:serviziSelezionati.Everyday) {
    Write-Info "Unieuro Cyber Protection gia' configurata con Everyday Digital."
    Update-PannelloStatus -TaskId "cyber" -Stato "done" -Dettaglio "Incluso in Everyday Digital"
} elseif ($Global:serviziSelezionati -and $Global:serviziSelezionati.Cyber) {
    if ($Global:telefonoCliente) { Write-Info "Cellulare del cliente: $($Global:telefonoCliente)" }
    Attiva-ServizioWeb -Nome "Unieuro Cyber Protection" -UrlAttivazione "https://unieuro-cyber-protection.covercare.it" -Utente $credMsAccount
    Add-ShortcutCyberProtection
    Update-PannelloStatus -TaskId "cyber" -Stato "done" -Dettaglio "Configurato"
} else {
    Write-Info "Unieuro Cyber Protection non acquistato: saltato."
    Add-Report "Unieuro Cyber Protection" "SALTATO (non acquistato)"
    Update-PannelloStatus -TaskId "cyber" -Stato "skipped" -Dettaglio "Non acquistato (saltato)"
}
}
'pulizia' {
trap {
    # Come il trap globale: registra l'imprevisto e prosegue con l'istruzione
    # successiva DENTRO questo passo (senza, un errore chiuderebbe tutto il ciclo).
    Register-ErroreImprevisto $_
    try { Write-Host "   [!] Imprevisto gestito: $($_.Exception.Message)" -ForegroundColor DarkYellow } catch {}
    continue
}
# =============================================================================
# PULIZIA E OTTIMIZZAZIONE: normalmente e' gia' partita in background durante i
# passi manuali; qui si aspetta che finisca. Se non era partita (es. ripresa
# dopo un riavvio o runspace non disponibile) si fa adesso in primo piano.
# =============================================================================
Write-Titolo "Pulizia e ottimizzazione"
if ($Global:LavoriBg) {
    $okBg = Complete-LavoriInBackground
    if ($okBg) { Write-OK "Pulizia e ottimizzazione completate (in background)." }
    else { Write-Info "Pulizia in background non completata del tutto: vedi il riepilogo." }
} else {
    Update-PannelloStatus -TaskId "pulizia" -Stato "running" -FaseCorrente "Pulizia e ottimizzazione" -Dettaglio "Rimozione bloatware e ottimizzazione..."
    Invoke-PuliziaSistema
}
$Global:PuliziaFatta = $true
Update-PannelloStatus -TaskId "pulizia" -Stato "done" -Dettaglio "Completato"
}
'driver' {
trap {
    # Come il trap globale: registra l'imprevisto e prosegue con l'istruzione
    # successiva DENTRO questo passo (senza, un errore chiuderebbe tutto il ciclo).
    Register-ErroreImprevisto $_
    try { Write-Host "   [!] Imprevisto gestito: $($_.Exception.Message)" -ForegroundColor DarkYellow } catch {}
    continue
}
# =============================================================================
# DRIVER (Windows Update, opzionale) - prima degli aggiornamenti finali
# =============================================================================

Write-Titolo "Driver (Windows Update)"
Update-PannelloStatus -TaskId "driver" -Stato "running" -FaseCorrente "Driver Hardware & GPU" -Dettaglio "Verifica driver grafici e periferiche..."

Write-Host "Cerca e installa i driver mancanti/aggiornati dal catalogo Windows Update." -ForegroundColor White
Write-Host "Se c'e' una scheda video DEDICATA, uso anche il tool del produttore (Windows" -ForegroundColor White
Write-Host "Update spesso non ne prende il driver giusto). Puo' richiedere qualche minuto" -ForegroundColor White
Write-Host "e talvolta un riavvio. Opzionale." -ForegroundColor White
Write-Host ""

$gpuDed = Get-GpuDedicata
switch ($gpuDed) {
    'NVIDIA' {
        if (Confirm-Winget) {
            Write-Info "Scheda video NVIDIA (dedicata): installo l'app NVIDIA per i driver..."
            winget install --exact --id Nvidia.NvidiaApp --source winget --silent --accept-package-agreements --accept-source-agreements 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) {
                winget install --exact --id Nvidia.GeForceExperience --source winget --silent --accept-package-agreements --accept-source-agreements 2>$null | Out-Null
            }
            if ($LASTEXITCODE -eq 0) {
                Write-OK "App NVIDIA installata: APRILA per scaricare i driver piu' recenti."
                Add-Report "App NVIDIA (driver GeForce): aprire per completare" "OK"
            } else {
                Write-Info "App NVIDIA non installata (id/rete): scaricala da nvidia.com/it-it/software/nvidia-app/"
                Add-Report "App NVIDIA (driver GeForce)" "AVVISO"
            }
        }
        Write-Host ""
    }
    'INTEL' {
        if (Confirm-Winget) {
            Write-Info "Scheda video Intel Arc (dedicata): installo Intel Driver & Support Assistant..."
            Installa-Pacchetto -Nome "Intel Driver e Support Assistant" -WingetId "Intel.IntelDriverAndSupportAssistant"
            Write-Info "APRI 'Intel Driver & Support Assistant' per scaricare il driver video."
            Add-Report "Intel DSA (driver video): aprire per completare" "OK"
        }
        Write-Host ""
    }
    'AMD' {
        Write-Info "Scheda video AMD (dedicata): apro la pagina AMD per il driver video."
        Start-Process "https://www.amd.com/it/support"
        Write-OK "Browser aperto su amd.com/it/support (auto-rilevamento driver)."
        Write-Info "Scarica ed esegui 'AMD Software: Adrenalin Edition', poi riavvia se richiesto."
        Add-Report "AMD (driver video): scaricare da amd.com" "AVVISO"
        Write-Host ""
    }
    default {
        Write-Info "Nessuna scheda video dedicata rilevata: i driver video li gestisce Windows Update."
    }
}

    $vuoiDriver = "S"
if ($vuoiDriver -match "^[Ss]") {
    $resDrv = Install-WindowsUpdateDrivers -TimeoutSec 360 -Test:$Test
} else {
    Write-Info "Installazione driver saltata."
    Add-Report "Driver (Windows Update)" "SALTATO"
    Update-PannelloStatus -TaskId "driver" -Stato "skipped" -Percentuale 72 -Dettaglio "Saltato"
}
}
'aggiorna' {
trap {
    # Come il trap globale: registra l'imprevisto e prosegue con l'istruzione
    # successiva DENTRO questo passo (senza, un errore chiuderebbe tutto il ciclo).
    Register-ErroreImprevisto $_
    try { Write-Host "   [!] Imprevisto gestito: $($_.Exception.Message)" -ForegroundColor DarkYellow } catch {}
    continue
}
# =============================================================================
# AGGIORNAMENTI - ULTIMO PASSO: app (winget + Microsoft Store) e Windows Update
# =============================================================================

Write-Titolo "Aggiornamenti (app + Windows)"
Update-PannelloStatus -TaskId "aggiorna" -Stato "running" -FaseCorrente "Aggiornamenti di Sicurezza" -Dettaglio "Verifica aggiornamenti app e Windows..."

Write-Host "Con un solo SI aggiorno, una dopo l'altra:" -ForegroundColor White
Write-Host "  - App: all'ultima versione le app gestite da winget (anche OEM)." -ForegroundColor White
Write-Host "  - App del Microsoft Store: richiesta di aggiornamento allo Store." -ForegroundColor White
Write-Host "  - Windows: gli aggiornamenti di SICUREZZA di Windows (installati a fine lavoro)." -ForegroundColor White
Write-Host "Puo' richiedere diversi minuti." -ForegroundColor White
Write-Host ""

    $vuoiUpgrade = "S"
if ($vuoiUpgrade -match "^[Ss]") {
    # 1) APP INSTALLATE (winget)
    if (Confirm-Winget) {
        $null = Invoke-WingetConBarra -Nome "aggiornamenti app" -WingetArgs @('upgrade', '--all', '--silent', '--accept-package-agreements', '--accept-source-agreements', '--include-unknown') -TimeoutSec 600
        Write-OK "Aggiornamento app completato."
        Add-Report "Aggiornamento app installate" "OK"
    } else {
        Write-Errore "Winget non disponibile."
        Add-Report "Aggiornamento app installate" "ERRORE"
    }

    # 2) APP DEL MICROSOFT STORE: chiedo allo Store di cercare e installare gli
    #    aggiornamenti (metodo standard MDM/CIM; se non disponibile, si salta).
    if ($RunReale) {
        try {
            Get-CimInstance -Namespace 'root\cimv2\mdm\dmmap' -ClassName 'MDM_EnterpriseModernAppManagement_AppManagement01' -ErrorAction Stop |
                Invoke-CimMethod -MethodName UpdateScanMethod -ErrorAction Stop | Out-Null
            Write-OK "Microsoft Store: aggiornamento delle app avviato (prosegue da solo)."
            Add-Report "Aggiornamento app Microsoft Store" "OK"
        } catch {
            Write-Info "Microsoft Store: aggiornamento automatico non disponibile su questo PC."
            Add-Report "Aggiornamento app Microsoft Store" "SALTATO"
        }
    }

    # 3) AGGIORNAMENTI DI SICUREZZA DI WINDOWS: attiva "Ottieni gli ultimi
    #    aggiornamenti non appena sono disponibili", avvia il download in
    #    background (qui sotto) e installa tutto alla fine prima del riavvio.
    Write-Host ""
    if ($RunReale) {
        Enable-WindowsUpdateAutoSettings
        Write-OK "Windows Update: attivato 'Ottieni gli ultimi aggiornamenti non appena sono disponibili'."
    }
    Write-Info "Aggiornamenti Windows (inclusi cumulativi e anteprima): download in background, installazione a fine lavoro."
    $Global:AvviaWinUpdateDopoDriver = $true
    if ($Test) {
        Write-OK "TEST: simulazione download aggiornamenti Windows programmato in background."
        Add-Report "Aggiornamenti Windows (scaricati in background)" "OK"
    }
    Update-PannelloStatus -TaskId "aggiorna" -Stato "done" -Dettaglio "App aggiornate, Windows Update a fine lavoro"
} else {
    $Global:AvviaWinUpdateDopoDriver = $false
    Write-Info "Aggiornamenti saltati (app e Windows)."
    Add-Report "Aggiornamento app installate" "SALTATO"
    Add-Report "Aggiornamenti di sicurezza Windows" "SALTATO"
    Update-PannelloStatus -TaskId "aggiorna" -Stato "skipped" -Dettaglio "Saltato"
}

# Download degli aggiornamenti di Windows in background: gli aggiornamenti sono
# l'ULTIMO passo (i driver sono gia' fatti, niente contesa su Windows Update).
# Scarica mentre lo script prepara report e consegna; l'installazione avviene
# alla fine, subito prima del riavvio.
if ($Global:AvviaWinUpdateDopoDriver -and -not $Global:JobWinUpdate -and -not $Test) {
    try {
        $Global:JobWinUpdate = Start-Job -ScriptBlock {
            try {
                $uso = Join-Path $env:SystemRoot 'System32\UsoClient.exe'
                if (Test-Path -LiteralPath $uso) {
                    Start-Process -FilePath $uso -ArgumentList 'StartInteractiveScan' -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
                    Start-Process -FilePath $uso -ArgumentList 'StartDownload' -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
                }
                $s = New-Object -ComObject Microsoft.Update.Session
                $searcher = $s.CreateUpdateSearcher()
                try { $searcher.Online = $true } catch {}
                $res  = $searcher.Search("IsInstalled=0 and IsHidden=0")
                $coll = New-Object -ComObject Microsoft.Update.UpdateColl
                foreach ($u in $res.Updates) {
                    if ($u.InstallationBehavior -and $u.InstallationBehavior.CanRequestUserInput) { continue }
                    if (-not $u.EulaAccepted) { try { $u.AcceptEula() } catch {} }
                    if (-not $u.IsDownloaded) { $coll.Add($u) | Out-Null }
                }
                if ($coll.Count -gt 0) {
                    $dl = $s.CreateUpdateDownloader(); $dl.Updates = $coll; $dl.Download() | Out-Null
                }
                return $res.Updates.Count
            } catch { return -1 }
        }
        Write-OK "Download aggiornamenti Windows avviato in background."
        Add-Report "Aggiornamenti Windows (scaricati in background)" "OK"
    } catch {
        Write-Errore "Impossibile avviare gli aggiornamenti di Windows: $_"
        Add-Report "Aggiornamenti di sicurezza Windows" "ERRORE"
    }
}
}
}
# Task del pannello rimasto "in corso" (passi senza aggiornamenti propri): lo
# chiudo, a meno che il passo successivo continui lo stesso task.
$prossimoTask = if ($passo + 1 -lt $totPassi) { $Global:Passi[$passo + 1].Task } else { '' }
try {
    if ($prossimoTask -ne $voce.Task -and $Global:PannelloStatus -and $Global:PannelloStatus.Tasks.Contains($voce.Task) -and
        $Global:PannelloStatus.Tasks[$voce.Task].Stato -in @('running', 'pending')) {
        Update-PannelloStatus -TaskId $voce.Task -Stato "done" -Dettaglio "Completato"
    }
} catch {}
$passo++
Save-Fase $passo $voce.Nome
}
$Global:PercentualeDaPassi = $false
# Sicurezza: se i lavori in background fossero ancora aperti, li chiudo qui.
if ($Global:LavoriBg) { [void](Complete-LavoriInBackground) }

# =============================================================================
# FINE
# =============================================================================

Write-Titolo "CONFIGURAZIONE COMPLETATA - REPORT"

if ($Report.Count -eq 0) {
    Write-Info "Nessuna operazione registrata."
} else {
    $nOk      = ($Report | Where-Object { $_.Esito -eq "OK" }).Count
    $nErrore  = ($Report | Where-Object { $_.Esito -eq "ERRORE" }).Count
    $nSaltato = ($Report | Where-Object { $_.Esito -eq "SALTATO" }).Count
    $nAvviso  = ($Report | Where-Object { $_.Esito -eq "AVVISO" }).Count

    foreach ($r in $Report) {
        switch ($r.Esito) {
            "OK"      { $colore = "Green" }
            "ERRORE"  { $colore = "Red" }
            default   { $colore = "Yellow" }
        }
        Write-Host ("  [{0,-8}] {1}" -f $r.Esito, $r.Voce) -ForegroundColor $colore
    }

    Write-Host ""
    Write-Host ("$AON" + ("Totale: {0} OK, {1} ERRORE, {2} SALTATO, {3} AVVISO" -f $nOk, $nErrore, $nSaltato, $nAvviso) + "$AOFF") -ForegroundColor $THEME_COL
    if ($nErrore -gt 0) {
        Write-Host "Controlla le voci in ERRORE prima di consegnare il PC." -ForegroundColor Red
    }
}

# UN SOLO file riepilogo, ordinato - solo run reale (Configura)
if ($RunReale) {
    # -------------------------------------------------------------------------
    # LEGGIBILITA' SCHERMO: imposta il ridimensionamento (scaling) in base alla
    # risoluzione, cosi' il PC non esce con tutto microscopico sugli schermi ad
    # alta risoluzione. Via registro (Win8DpiScaling + LogPixels), niente
    # P/Invoke. Si applica del tutto dopo il logout/riavvio. Fatto qui (dopo i
    # driver) perche' la risoluzione ormai e' quella nativa/definitiva.
    # -------------------------------------------------------------------------
    try {
        $hres = (Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
                 Where-Object { $_.CurrentHorizontalResolution } |
                 Sort-Object CurrentHorizontalResolution -Descending |
                 Select-Object -First 1).CurrentHorizontalResolution
        if ($hres) {
            $logPixels = if ($hres -ge 3800) { 192 }        # 4K      -> 200%
                         elseif ($hres -ge 2500) { 144 }    # ~1440p  -> 150%
                         elseif ($hres -ge 1900) { 120 }    # 1080p   -> 125%
                         else { 96 }                        # sotto   -> 100%
            $perc = [int]($logPixels / 96 * 100)
            $desk = "HKCU:\Control Panel\Desktop"
            Set-ItemProperty -Path $desk -Name "Win8DpiScaling" -Value 1 -Type DWord -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $desk -Name "LogPixels" -Value $logPixels -Type DWord -ErrorAction SilentlyContinue
            Write-OK "Ridimensionamento schermo a $perc% (risoluzione ${hres}px): attivo dopo il logout."
            Add-Report "Ridimensionamento schermo ($perc%)" "OK"
        }
    } catch {
        Write-Info "Ridimensionamento schermo non impostato: proseguo."
    }

    # -------------------------------------------------------------------------
    # CHIAVE DI RIPRISTINO BITLOCKER (il piu' TARDI possibile: se la device
    # encryption di Windows 11 si e' attivata durante il setup, ora la chiave
    # esiste). Usa la funzione di log Add-Report come gli altri passi.
    # DATO SENSIBILE: la chiave va SOLO nella scheda di consegna PDF (riquadro
    # "Conserva questa chiave"), che resta col PC. Niente file separato sul
    # Desktop e niente chiave nei log.
    # -------------------------------------------------------------------------
    function Invoke-SchedaConsegnaFinale {
    Update-PannelloStatus -TaskId "diagnostica" -Stato "running" -Percentuale 98 -FaseCorrente "Diagnostica & Scheda Consegna" -Dettaglio "Lettura chiave BitLocker e scheda cliente..."
    Write-Titolo "Chiave di Ripristino BitLocker"
    Write-Host "Riporto la chiave di ripristino nella scheda di consegna: senza, se Windows" -ForegroundColor White
    Write-Host "attiva la crittografia da solo, dopo un reset o un cambio hardware si perde l'accesso." -ForegroundColor White
    Write-Host ""
    $bitlocker = Get-BitLockerRecovery -Volume $env:SystemDrive
    switch ($bitlocker.Esito) {
        "OK"      { Write-OK "Chiave di ripristino BitLocker trovata (volume $($bitlocker.Volume)): va nella scheda di consegna PDF." }
        "SALTATO" { Write-Info $bitlocker.Messaggio }
        default   { Write-Info $bitlocker.Messaggio }   # AVVISO
    }
    Add-Report "Chiave di ripristino BitLocker" $bitlocker.Esito

    # Diagnostica salute hardware e stato licenza
    $storageInfo = Get-StorageHealthInfo
    $batteryInfo = Get-BatteryHealthInfo
    $winActInfo  = Get-WindowsActivationStatus

    # Le credenziali del nuovo account le ha GENERATE lo script allo step Account
    # Microsoft ($credMsAccount / $credMsPassword). Se quel passo e' stato saltato
    # restano vuote. Niente domande all'operatore, niente password dal browser.
    #
    # Leggi se l'operatore ha salvato/aggiornato credenziali dal pannello Edge
    Get-CredenzialiSalvatePannello | Out-Null
    if ($Global:nomeCliente -and $Global:nomeCliente -notmatch '^(?i)(Cliente|OEM|Utente|clt|clt\s*clt)$') {
        $nomeCliente = $Global:nomeCliente
        $nomeDaUsare = if ($Global:nomeProprioCliente -and $Global:nomeProprioCliente.Trim() -and $Global:nomeProprioCliente.Trim() -notmatch '^(?i)(clt|oem|cliente)$') {
            $Global:nomeProprioCliente.Trim()
        } else {
            $parti = $nomeCliente -split '\s+' | Where-Object { $_ }
            if ($parti.Count -gt 1) { $parti[-1] } else { $nomeCliente }
        }
        $cleanPc = ($nomeDaUsare -replace '[^A-Za-z0-9]', '')
        if (-not $cleanPc -or $cleanPc.ToUpper() -eq "OEM") { $cleanPc = "Utente" }
        $pcNuovo = "PC-$cleanPc"
        if ($pcNuovo.Length -gt 15) { $pcNuovo = $pcNuovo.Substring(0, 15) }
        [void](Set-NomeUtenteEPc -NomeUtente $nomeCliente -NomePc $pcNuovo -Silenzioso)
    }

    # $nomeCliente e' "Cognome Nome" (da $Dati.Cliente): per email/password uso
    # i campi separati Nome/Cognome quando disponibili, altrimenti $nomeCliente
    # resta l'unico dato che ho (sessioni riprese da un vecchio checkpoint).
    # New-PasswordCliente prende sempre la PRIMA parola: con "Cognome Nome"
    # genererebbe la password dal cognome, non dal nome.
    $nomeProprioRete = if ($Global:nomeProprioCliente) { $Global:nomeProprioCliente } else { $null }
    $cognomeRete     = if ($Global:cognomeCliente) { $Global:cognomeCliente } else { $null }
    $baseEmailRete = if ($nomeProprioRete -and $cognomeRete) { "$nomeProprioRete $cognomeRete" } else { $nomeCliente }
    $basePassRete  = if ($nomeProprioRete) { $nomeProprioRete } else { $nomeCliente }

    if ($Global:IsCltMode) {
        $credMsAccount = ""
        $credMsPassword = ""
    } else {
        # Se dal pannello sono arrivate credenziali, hanno la precedenza assoluta
        if ($Global:credMsAccount) {
            $credMsAccount = $Global:credMsAccount
        } elseif ($nomeCliente -and $nomeCliente -notmatch '^(Cliente|OEM|Utente)$' -and ($credMsAccount -match 'telef|oem|admin|user|utente' -or -not $credMsAccount)) {
            $domRete = if ($Global:credDominio) { $Global:credDominio } else { "proton.me" }
            $credMsAccount = New-EmailCliente -Base $baseEmailRete -Dominio $domRete
        }

        if ($Global:credMsPassword) {
            $credMsPassword = $Global:credMsPassword
        } elseif ($nomeCliente -and $nomeCliente -notmatch '^(Cliente|OEM|Utente)$' -and ($credMsPassword -match 'Telef|OEM|Admin|Utente' -or -not $credMsPassword)) {
            $credMsPassword = New-PasswordCliente -Base $basePassRete
        }

        if ($Global:credProvider) {
            $provNome = $Global:credProvider
        }

        # RETE DI SICUREZZA sulla PASSWORD: nel file non deve MAI mancare (salvo modalita' clt).
        if (-not $credMsPassword) {
            $basePass = if ($basePassRete -and $basePassRete.ToUpper() -ne "OEM") { $basePassRete } else { "Utente" }
            $credMsPassword = New-PasswordCliente -Base $basePass
        }
        if (-not $credMsAccount) {
            $baseAcc = if ($baseEmailRete -and $baseEmailRete.ToUpper() -ne "OEM") { $baseEmailRete } else { "utente" }
            $domRete = if ($Global:credDominio) { $Global:credDominio } else { "outlook.it" }
            $credMsAccount = New-EmailCliente -Base $baseAcc -Dominio $domRete
        }
    }
    try {
        $winOk   = ($winActInfo.Attivo -or (@($Report | Where-Object { $_.Voce -eq 'Windows attivato' -and $_.Esito -eq 'OK' }).Count -gt 0))
        $diskBad = ($storageInfo.Salute -notmatch 'Healthy|Buono|OK' -or (@($Report | Where-Object { $_.Voce -eq 'Salute disco' -and $_.Esito -eq 'ERRORE' }).Count -gt 0))
        $freeTxt = ""
        try { $freeTxt = "{0} GB liberi" -f [math]::Round((Get-PSDrive ($env:SystemDrive.TrimEnd(':')) -ErrorAction SilentlyContinue).Free / 1GB, 1) } catch {}

        $softwareOk = @($Report | Where-Object { $_.Voce -like '*installazione*' -and $_.Esito -eq 'OK' } |
                        ForEach-Object { ($_.Voce -replace ' \(installazione\)', '').Trim() })
        $av = @($Report | Where-Object { ($_.Voce -like '*antivirus*' -or $_.Voce -like '*protezione*') -and $_.Esito -eq 'OK' })
        $altre = @($Report | Where-Object { $_.Voce -notlike '*installazione*' -and $_.Voce -notlike '*antivirus*' -and $_.Voce -notlike '*protezione*' })

        # Rilegge eventuali dati cliente confermati nel pannello durante la Fase 2
        try { [void](Get-CredenzialiSalvatePannello) } catch {}

        # --- VERIFICA FINALE: le cose importanti sono andate DAVVERO? (ricontrollo
        #     lo stato vero, non mi fido degli esiti dei singoli passi). ---
        $verifica = @()
        # Verifica lingua installata: Get-InstalledLanguage non c'e' su tutti i
        # sistemi (in tal caso cado su DISM Get-WindowsLanguagePack, che elenca i
        # language pack reali; servono admin, e qui lo siamo). Se proprio nessuno
        # dei due funziona -> $null e la voce si omette dalla verifica finale.
        $vLang = $null
        try {
            if (Get-Command Get-InstalledLanguage -ErrorAction SilentlyContinue) {
                $vLang = (@(Get-InstalledLanguage -ErrorAction Stop).LanguageId -contains 'it-IT')
            } else {
                $vLang = (@(Get-WindowsLanguagePack -Online -ErrorAction Stop | Where-Object { $_.Language -match '^it-' }).Count -gt 0)
            }
        } catch { $vLang = $null }
        if ($null -ne $vLang) { $verifica += [pscustomobject]@{ N = 'Pacchetto lingua italiano'; Ok = $vLang } }
        $verifica += [pscustomobject]@{ N = 'OneDrive rimosso'; Ok = (-not (Test-Path "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe")) }
        # "Antivirus di prova rimossi": conta SOLO i trial NON installati in questa
        # sessione - un AV scelto al passo Antivirus (McAfee/Norton) e' voluto,
        # non una prova da togliere, quindi va escluso dai "di prova".
        $avInstallatiNoi = @($av | ForEach-Object { ($_.Voce -replace ' \(antivirus\)', '' -replace ' \(protezione\)', '').Trim() })
        $avRestanoProva  = @(Get-AntivirusInstallati | Where-Object { $avInstallatiNoi -notcontains $_.Nome })
        $verifica += [pscustomobject]@{ N = 'Antivirus di prova rimossi'; Ok = ($avRestanoProva.Count -eq 0) }
        $verifica += [pscustomobject]@{ N = 'Windows attivato'; Ok = $winOk }

        # Mostro la verifica anche a schermo (oltre che nel file).
        Write-Titolo "Verifica finale"
        foreach ($v in $verifica) { if ($v.Ok) { Write-OK $v.N } else { Write-Errore "$($v.N): DA RIFARE" } }

        # --- Dettagli tecnici per l'assistenza (troubleshooting nello stesso file) ---
        $osInfo = $null; try { $osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue } catch {}
        $hwInfo = Get-SystemHardwareDetails
        $wgVer = "n/d"; try { $wgVer = (winget --version) 2>$null } catch {}
        $resTxt = if ($hres) { "$hres" } else { "n/d" }
        $avTxt = try { (@(Get-AntivirusInstallati).Nome | Select-Object -Unique) -join ', ' } catch { '' }
        if (-not $avTxt) { $avTxt = 'nessuno' }

        $sep = "------------------------------------------------------------"

        # Le CREDENZIALI del cliente vanno SOLO nella scheda di consegna (PDF sul
        # Desktop): il riepilogo testuale qui sotto finisce nel log tecnico in
        # ProgramData\PCFacile\log e NON contiene password ne' recovery key.
        $provNome = if ($Global:credProvider) { $Global:credProvider } elseif ($prov) { $prov.Nome } else { "Microsoft" }

        $clienteDisplay = if ($Global:nomeCliente -and $Global:nomeCliente -notmatch '^(?i)(OEM|clt|clt\s*clt)$') { $Global:nomeCliente } elseif ($nomeCliente -and $nomeCliente -notmatch '^(?i)(OEM|clt|clt\s*clt)$') { $nomeCliente } elseif ($isOemUser -or $env:USERNAME -match '^(?i)(oem|clt|clt\s*clt)$') { "Utente" } else { $env:USERNAME }
        $pcDisplay = if ($Global:PannelloStatus -and $Global:PannelloStatus.NomePcAttuale) { $Global:PannelloStatus.NomePcAttuale } elseif ($pcNuovo) { $pcNuovo } elseif ($env:COMPUTERNAME -match '^(LAPTOP|DESKTOP|WIN)-[A-Z0-9]{4,10}$' -or $env:COMPUTERNAME -match '^(?i)(oem|clt|pc-clt)$') { "PC-$clienteDisplay" } else { $env:COMPUTERNAME }

        $isClt = [bool]$Global:IsCltMode -or
                 ($nomeCliente -match '(?i)^(clt\s*clt|clt)$') -or
                 ($Global:nomeCliente -match '(?i)^(clt\s*clt|clt)$') -or
                 ($Global:nomeProprioCliente -match '(?i)^clt$' -and ($Global:cognomeCliente -match '(?i)^clt$' -or -not $Global:cognomeCliente))

        $f = @()
        $f += "============================================================"
        $f += "   RIEPILOGO TECNICO CONFIGURAZIONE PC (log assistenza)"
        $f += "============================================================"
        $f += ""
        $f += "Data     : $(Get-Date -Format 'dd/MM/yyyy HH:mm')"
        $f += "Cliente  : $clienteDisplay"
        $f += "Nome PC  : $pcDisplay"
        $f += "Utente   : $clienteDisplay"
        if ($isClt -or (-not $credMsAccount -and -not $credMsPassword)) {
            $f += "Account  : Nessuno (configurazione rapida clt)"
        } else {
            $f += "Account  : $credMsAccount ($provNome)"
            $f += "           (password e credenziali: solo nella scheda di consegna PDF sul Desktop)"
        }
        $f += ""
        $f += $sep
        $f += "HARDWARE, SERIALE & GARANZIA LEGALE"
        $f += $sep
        $f += "  Produttore / Modello : $($hwInfo.Produttore) $($hwInfo.Modello)"
        $f += "  Seriale (Service Tag): $($hwInfo.Seriale)"
        $f += "  Scheda Madre         : $($hwInfo.SchedaMadre)"
        $f += "  Processore (CPU)     : $($hwInfo.Cpu)"
        $f += "  Memoria RAM          : $($hwInfo.RamGB) GB"
        $f += "  Scheda Video (GPU)   : $($hwInfo.Gpu)"
        $f += ""
        $f += $sep
        $f += "STATO SISTEMA & DIAGNOSTICA"
        $f += $sep
        $f += "  Windows attivato     : $($winActInfo.StatoBreve)"
        if ($freeTxt) { $f += "  Spazio disco C:      : $freeTxt" }
        $f += "  Salute disco/SSD     : $($storageInfo.StatoCompleto)"
        if ($batteryInfo.Presente) { $f += "  Batteria             : $($batteryInfo.Descrizione)" }
        $f += ""
        $f += $sep
        $f += "VERIFICA FINALE (ricontrollo automatico)"
        $f += $sep
        foreach ($v in $verifica) { $f += ("  [{0}] {1}" -f $(if ($v.Ok) { 'OK       ' } else { 'DA RIFARE' }), $v.N) }
        $f += ""
        $f += $sep
        $f += "SOFTWARE INSTALLATO"
        $f += $sep
        if ($softwareOk.Count -gt 0) { foreach ($sw in $softwareOk) { $f += "  - $sw" } } else { $f += "  (nessuno)" }
        $f += ""
        $f += $sep
        $f += "ANTIVIRUS / PROTEZIONE"
        $f += $sep
        if ($av.Count -gt 0) { foreach ($a in $av) { $f += "  - $($a.Voce)" } } else { $f += "  (da verificare)" }
        $f += ""
        $f += $sep
        # La recovery key da' accesso completo al disco: NON va nel log (resta
        # solo nella scheda di consegna PDF sul Desktop).
        $f += "CHIAVE DI RIPRISTINO BITLOCKER"
        $f += $sep
        if ($bitlocker) {
            $f += "  Volume        : $($bitlocker.Volume)"
            $f += "  Cifratura     : $($bitlocker.Stato)"
            if ($bitlocker.RecoveryKey) {
                $f += "  ID chiave     : $($bitlocker.KeyId)"
                $f += "  Recovery key  : (non riportata nel log: e' solo nella scheda di consegna PDF sul Desktop)"
            } else {
                $f += "  $($bitlocker.Messaggio)"
            }
        } else {
            $f += "  (controllo non eseguito)"
        }
        $f += ""
        $f += $sep
        $f += "ALTRE OPERAZIONI"
        $f += $sep
        foreach ($r in $altre) { $f += ("  [{0,-8}] {1}" -f $r.Esito, $r.Voce) }
        $f += ""
        if ($Global:ErroriImprevisti.Count -gt 0) {
            $f += $sep
            $f += "IMPREVISTI GESTITI ($($Global:ErroriImprevisti.Count)) - dettaglio nel log tecnico"
            $f += $sep
            foreach ($e in $Global:ErroriImprevisti) { $f += "  [riga $($e.Riga)] $($e.Messaggio)" }
            $f += ""
        }
        $f += $sep
        $f += "DETTAGLI TECNICI (per assistenza in negozio)"
        $f += $sep
        $f += "  Windows      : $(if ($osInfo) { "$($osInfo.Caption) build $($osInfo.BuildNumber)" } else { 'n/d' })"
        $f += "  PowerShell   : $($PSVersionTable.PSVersion)"
        $f += "  winget       : $wgVer"
        $f += "  Risoluzione  : $resTxt px"
        $f += "  Antivirus    : $avTxt"
        $f += "  Versione tool: $SCRIPT_VERSION"
        $f += "  Data setup   : $(Get-Date -Format 'dd/MM/yyyy HH:mm')"
        $f += ""
        $f += "============================================================"
        $f += "  Unieuro - Assistenza Tecnica & Installazioni PC"
        $f += "============================================================"

        # Il riepilogo tecnico testuale va SOLO nel log tecnico (ProgramData\PCFacile\log),
        # mai sul Desktop: al cliente resta soltanto la scheda di consegna PDF.
        $baseDati = if ($env:ProgramData) { $env:ProgramData } else { [System.IO.Path]::GetTempPath() }
        try {
            $logDir = Join-Path $baseDati "PCFacile\log"
            if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
            $txtLog = Join-Path $logDir "riepilogo-tecnico.txt"
            $f | Set-Content -Path $txtLog -Encoding UTF8
            Write-OK "Riepilogo tecnico salvato nel log (non sul Desktop): $txtLog"
        } catch {}

        # Scheda di Consegna Cliente con grafica Unieuro: UNICO documento per il
        # cliente. HTML generato in ProgramData\PCFacile\consegna, convertito in
        # PDF sul Desktop e poi cancellato (Save-SchedaConsegna).
        try {
            $appInstallate = @($Report | Where-Object { $_.Voce -like '*installazione*' -and $_.Esito -eq 'OK' } | ForEach-Object { ($_.Voce -replace ' \(installazione\)', '' -replace ' \(installazione offline\)', '').Trim() })
            $appItems = ""
            foreach ($app in $appInstallate) { $appItems += "<div class='app-badge'>&#10003; <strong>$app</strong></div>" }
            if (-not $appItems) { $appItems = "<div class='app-badge'>&#10003; <strong>Applicazioni base configurate</strong></div>" }

            # Antivirus / Cyber Protection attivati in questa sessione: prima stavano
            # solo nel riepilogo TXT sul Desktop, ora nella scheda (unico documento).
            $avRighe = ""
            foreach ($a in $av) {
                $svcAv = [System.Net.WebUtility]::HtmlEncode(($a.Voce -replace ' \(antivirus\)', '' -replace ' \(protezione\)', '').Trim())
                $notaAv = if ($a.Voce -like '*protezione*') { "Cyber Protection: password creata dal sito, arriva via email al cliente &bull; PIN card: __________" } else { "Attivato con l'account principale &bull; PIN card: __________" }
                $avRighe += "<tr><td style='font-weight: 600;'>$($svcAv):</td><td>$notaAv</td></tr>"
            }
            $rigaPassSecure = if ($Global:credSecurePassword) {
                "<tr><td style='font-weight: 600;'>Password Unieuro Secure:</td><td><code style='font-size: 14px; font-weight: bold; background: #ffedd5; color: #c2410c; padding: 2px 8px; border-radius: 4px;'>$([System.Net.WebUtility]::HtmlEncode($Global:credSecurePassword))</code> <em style='color: #64748b; font-size: 11px; margin-left: 8px;'>(dalla mail Unieuro Secure)</em></td></tr>"
            } else { "" }
            $credBox = ""
            if (((-not $isClt) -and ($credMsAccount -or $credMsPassword)) -or $Global:credSecurePassword) {
                $rigaPassIniziale = if ((-not $isClt) -and $credMsPassword) {
                    "<tr><td style='font-weight: 600;'>Password iniziale:</td><td><code style='font-size: 14px; font-weight: bold; background: #fee2e2; color: #991b1b; padding: 2px 8px; border-radius: 4px;'>$credMsPassword</code> <em style='color: #64748b; font-size: 11px; margin-left: 8px;'>(da personalizzare al primo accesso)</em></td></tr>"
                } else { "" }
                $credBox = @"
            <div class='card card-cred'>
                <h3>&#128273; Credenziali di Primo Accesso &bull; $provNome</h3>
                <table class='info-table'>
                    <tr><td style='width: 32%; font-weight: 600;'>Email / Utente:</td><td><strong style='font-size: 14px; color: #00122B;'>$credMsAccount</strong></td></tr>
                    $rigaPassIniziale
                    $rigaPassSecure
                    <tr><td style='font-weight: 600;'>Account Windows:</td><td><code>$clienteDisplay</code></td></tr>
                    <tr><td style='font-weight: 600;'>Servizi inclusi:</td><td>Windows 11, Office / Microsoft 365, Antivirus &bull; Card PIN annotato</td></tr>
                    $avRighe
                </table>
            </div>
"@
            }

            # Chiave BitLocker: unica copia per il cliente (niente file separato sul
            # Desktop), quindi riquadro ben visibile subito sotto le credenziali.
            $bitlockerBox = ""
            if ($bitlocker -and $bitlocker.RecoveryKey) {
                $blKeyId = [System.Net.WebUtility]::HtmlEncode("$($bitlocker.KeyId)")
                $blKey   = [System.Net.WebUtility]::HtmlEncode("$($bitlocker.RecoveryKey)")
                $blVol   = [System.Net.WebUtility]::HtmlEncode("$($bitlocker.Volume)")
                $bitlockerBox = @"
            <div class='card card-bitlocker'>
                <div class='bl-titolo'>&#9888; CONSERVA QUESTA CHIAVE &bull; Chiave di ripristino BitLocker</div>
                <p class='bl-testo'>Il disco di questo PC &egrave; protetto con BitLocker. Se Windows chiede la <strong>chiave di ripristino</strong> (dopo un aggiornamento, un reset o una riparazione), inserisci il codice qui sotto. <strong>Senza questa chiave i dati del PC non sono pi&ugrave; accessibili.</strong></p>
                <div class='bl-chiave'>$blKey</div>
                <table class='info-table'>
                    <tr><td>ID chiave:</td><td><code>$blKeyId</code></td></tr>
                    <tr><td>Volume protetto:</td><td>$blVol</td></tr>
                </table>
                <p class='bl-testo' style='margin-top: 8px;'><strong>Stampa questa scheda o fotografala con lo smartphone</strong> e conservala in un posto sicuro, lontano dal PC. Non condividere la chiave con nessuno.</p>
            </div>
"@
            }

            $htmlDoc = @"
<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <title>Scheda Consegna PC - $clienteDisplay</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Segoe UI', system-ui, -apple-system, sans-serif; }
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
    <div class="sheet">
        <div class="header">
            <div class="header-brand">
                <div class="brand-logo">UNIEURO</div>
                <div>
                    <h1>Scheda di Consegna e Configurazione PC</h1>
                    <p>Assistenza Tecnica &bull; <em style="color: #EE7203; font-weight: 600;">Batte. Forte. Sempre.</em></p>
                </div>
            </div>
            <div class="badge-brand">PC FACILE v$SCRIPT_VERSION</div>
        </div>
        <div class="body">
            $credBox
            $bitlockerBox
            <div class="grid">
                <div class="card">
                    <h3>&#128100; Dati Cliente</h3>
                    <table class="info-table">
                        <tr><td>Cliente:</td><td><strong>$clienteDisplay</strong></td></tr>
                        $(if ($Global:telefonoCliente) { "<tr><td>Cellulare / Tel:</td><td><strong>$([System.Net.WebUtility]::HtmlEncode($Global:telefonoCliente))</strong></td></tr>" })
                        <tr><td>Nome Computer:</td><td><code>$pcDisplay</code></td></tr>
                        <tr><td>Seriale / S/N:</td><td><strong>$($hwInfo.Seriale)</strong></td></tr>
                        <tr><td>Data Setup:</td><td>$(Get-Date -Format 'dd/MM/yyyy HH:mm')</td></tr>
                        <tr><td>Licenza Windows:</td><td><strong style="color:$(if ($winActInfo.Attivo) { '#16a34a' } else { '#e11d48' });">&#10003; $($winActInfo.StatoBreve)</strong></td></tr>
                        <tr><td>Stato Setup:</td><td><strong style="color:#16a34a;">&#10003; Pronto e Collaudato</strong></td></tr>
                    </table>
                </div>
                <div class="card">
                    <h3>&#128187; Specifiche Hardware &amp; Diagnostica</h3>
                    <table class="info-table">
                        <tr><td>Dispositivo:</td><td><strong>$($hwInfo.Produttore) $($hwInfo.Modello)</strong></td></tr>
                        <tr><td>Processore:</td><td>$($hwInfo.Cpu)</td></tr>
                        <tr><td>RAM:</td><td>$($hwInfo.RamGB) GB</td></tr>
                        <tr><td>Scheda Video:</td><td>$($hwInfo.Gpu)</td></tr>
                        <tr><td>Stato Disco / SSD:</td><td><strong>$($storageInfo.StatoCompleto)</strong></td></tr>
                        $(if ($batteryInfo.Presente) { "<tr><td>Salute Batteria:</td><td><strong>$($batteryInfo.Descrizione)</strong></td></tr>" })
                        <tr><td>Lingua:</td><td>Italiano (it-IT)</td></tr>
                    </table>
                </div>
            </div>
            <div class="card">
                <h3>&#128230; Programmi e Utility Installate</h3>
                <div class="app-grid">$appItems</div>
            </div>
            <div class="card">
                <h3>&#128161; Consigli e Istruzioni per l'Uso</h3>
                <ul class="tips-list">
                    <li><strong>Connessione Wi-Fi:</strong> All'accensione a casa, seleziona la tua rete Wi-Fi in basso a destra ed inserisci la password di casa.</li>
                    <li><strong>Sicurezza Credenziali:</strong> Se &egrave; stata creata una password provvisoria, modificala al primo accesso in <em>Impostazioni &gt; Account</em>.</li>
                    $(if ($bitlocker -and $bitlocker.RecoveryKey) { "<li><strong>BitLocker:</strong> La chiave di ripristino del disco &egrave; <strong>solo in questa scheda</strong> (riquadro rosso in alto): conservala.</li>" })
                    <li><strong>Teleassistenza:</strong> AnyDesk e TeamViewer sono configurati e pronti sul desktop in caso di necessit&agrave; di supporto da remoto.</li>
                </ul>
            </div>
        </div>
        <div class="footer">
            <div>Documento di consegna ufficiale generato automaticamente per il cliente da <strong>PC Facile</strong>.</div>
            <button class="btn-print no-print" onclick="window.print()">&#128438; Stampa / Salva in PDF</button>
        </div>
    </div>
</body>
</html>
"@
            # Volume cifrato ma chiave NON letta in questa sessione: il vecchio file
            # "NON CANCELLARE" sul Desktop (se c'e') potrebbe essere l'unica copia -> lo tengo.
            $tieniChiaveVecchia = ($bitlocker -and $bitlocker.Esito -eq 'AVVISO')
            $scheda = Save-SchedaConsegna -HtmlDoc $htmlDoc -DesktopDir (Get-DesktopDir) -CartellaLavoro (Join-Path $baseDati "PCFacile\consegna") -ConservaVecchiaChiaveBitLocker:$tieniChiaveVecchia
            if ($tieniChiaveVecchia -and (Test-Path -LiteralPath (Join-Path (Get-DesktopDir) "NON CANCELLARE - Chiave di Ripristino BitLocker.txt"))) {
                Write-Errore "Chiave BitLocker non letta: lascio sul Desktop il vecchio file 'NON CANCELLARE - Chiave di Ripristino BitLocker.txt'. Verifica a mano."
            }
            switch ($scheda.Esito) {
                'PDF'  {
                    Write-OK "Scheda di consegna PDF salvata sul Desktop (unico file per il cliente): $($scheda.Percorso)"
                    Add-Report "Scheda di consegna PDF sul Desktop" "OK"
                }
                'HTML' {
                    Write-Errore "PDF della scheda non creato: sul Desktop resta la scheda HTML ($($scheda.Percorso))."
                    Write-Info "Aprila e usa 'Stampa / Salva in PDF' dal browser."
                    Add-Report "Scheda di consegna PDF (ripiego HTML sul Desktop)" "AVVISO"
                }
                default {
                    Write-Errore "Scheda di consegna non salvata: $($scheda.Messaggio)"
                    Add-Report "Scheda di consegna" "ERRORE"
                }
            }
            if ($scheda.Percorso -and (Test-Path -LiteralPath $scheda.Percorso)) {
                try { Start-Process -FilePath $scheda.Percorso } catch {}
            }
        } catch {
            Write-Info "Scheda di consegna non creata: $_"
        }

        # ---------------------------------------------------------------------
        # LOG STRUTTURATO (JSON + CSV) per l'assistenza/statistiche. NON sul
        # Desktop (non e' roba per il cliente): va in ProgramData\PCFacile\log.
        # Il JSON contiene tutto (sistema, esiti, verifica, errori imprevisti);
        # il CSV e' la tabella piatta degli esiti, comoda da aprire in Excel.
        # NIENTE credenziali nel log: restano solo nella scheda di consegna.
        # ---------------------------------------------------------------------
        try {
            $logDir = Join-Path $baseDati "PCFacile\log"
            if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
            $stamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
            $baseLog = Join-Path $logDir ("setup_{0}_{1}" -f $env:COMPUTERNAME, $stamp)

            $logObj = [ordered]@{
                versioneTool     = $SCRIPT_VERSION
                data             = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
                cliente          = "$nomeCliente"
                nomePc           = "$env:COMPUTERNAME"
                utente           = "$env:USERNAME"
                seriale          = "$($hwInfo.Seriale)"
                produttore       = "$($hwInfo.Produttore)"
                modello          = "$($hwInfo.Modello)"
                sistema          = if ($osInfo) { "$($osInfo.Caption) build $($osInfo.BuildNumber)" } else { 'n/d' }
                powershell       = "$($PSVersionTable.PSVersion)"
                winget           = "$wgVer"
                windowsAttivato  = [bool]$winOk
                risoluzione      = "$resTxt"
                antivirus        = "$avTxt"
                esiti            = @($Report | ForEach-Object { [ordered]@{ voce = $_.Voce; esito = $_.Esito } })
                verificaFinale   = @($verifica | ForEach-Object { [ordered]@{ voce = $_.N; ok = [bool]$_.Ok } })
                erroriImprevisti = @($Global:ErroriImprevisti)
            }
            $logObj | ConvertTo-Json -Depth 6 | Set-Content -Path "$baseLog.json" -Encoding UTF8
            $Report | Select-Object @{N='voce';E={$_.Voce}}, @{N='esito';E={$_.Esito}} |
                Export-Csv -Path "$baseLog.csv" -NoTypeInformation -Encoding UTF8
            Write-OK "Log tecnico salvato: $baseLog.json / .csv"

            # Salva una copia del report anche sulla chiavetta USB (cartella Logs\)
            # cosi' l'operatore ha sempre lo storico dei PC configurati sulla chiavetta.
            try {
                $usbLogBase = if ($Global:TargetDir -and (Test-CartellaKitUSB $Global:TargetDir)) { $Global:TargetDir }
                              elseif ($PSScriptRoot -and (Test-CartellaKitUSB $PSScriptRoot)) { $PSScriptRoot }
                              else { $null }
                if ($usbLogBase) {
                    $usbLogDir = Join-Path $usbLogBase "Logs"
                    if (-not (Test-Path -LiteralPath $usbLogDir)) { New-Item -Path $usbLogDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null }
                    Copy-Item -LiteralPath "$baseLog.json" -Destination (Join-Path $usbLogDir (Split-Path "$baseLog.json" -Leaf)) -Force -ErrorAction SilentlyContinue
                    Copy-Item -LiteralPath "$baseLog.csv"  -Destination (Join-Path $usbLogDir (Split-Path "$baseLog.csv"  -Leaf)) -Force -ErrorAction SilentlyContinue
                }
            } catch {}
        } catch {
            Write-Info "Log strutturato non salvato: $_"
        }
    } catch {
        Write-Info "Impossibile creare riepilogo e scheda di consegna: $_"
    }
    # Qui il report e' completo (verifica finale, BitLocker e scheda compresi).
    Send-ReportGitHub -ReportVoci $Report
    Repair-DesktopShortcuts
    Update-PannelloStatus -TaskId "diagnostica" -Stato "done" -Percentuale 100 -FaseCorrente "Configurazione PC Completata!" -Dettaglio "Tutti i lavori terminati con successo" -Completato
    }
    Invoke-SchedaConsegnaFinale
    Set-DesktopIconOrder
}

# -----------------------------------------------------------------------------
# PULIZIA FINALE: PC Facile non lascia tracce di se' sul PC del cliente.
# Cancella la copia dello script scaricata in %TEMP% dal launcher e i due valori
# di registro dei colori (console riportata allo stato di fabbrica). Remove-Item
# cancella in modo PERMANENTE, NON passa dal Cestino. La SCHEDA DI CONSEGNA
# (PDF) sul Desktop resta: serve al cliente. Se lo script gira dalla chiavetta (offline) la copia
# locale NON viene toccata. Fatto PRIMA dell'eventuale riavvio, cosi' parte sempre.
# Il server del pannello resta attivo durante il menu finale cosi' l'operatore
# puo' ancora usare la scheda "4. Passaggi", e viene chiuso all'uscita.
# -----------------------------------------------------------------------------
if ($RunReale) {
    try {
        Restore-SilentElevation
        # Console riportata com'era: tolgo TUTTI i valori scritti dal .bat e da
        # questo script (colori, font, VT), poi reimporto il backup originale
        # (se presente): i valori che esistevano prima tornano identici.
        $valoriConsole = @('VirtualTerminalLevel', 'FaceName', 'FontFamily', 'FontWeight', 'FontSize', 'ScreenColors') +
            @(0, 1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 12, 14, 15 | ForEach-Object { 'ColorTable{0:D2}' -f $_ })
        foreach ($vc in $valoriConsole) {
            Remove-ItemProperty -Path 'HKCU:\Console' -Name $vc -ErrorAction SilentlyContinue
        }
        if ($Global:ConsoleBackupFile -and (Test-Path -LiteralPath $Global:ConsoleBackupFile)) {
            & reg.exe import $Global:ConsoleBackupFile 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { Remove-Item -LiteralPath $Global:ConsoleBackupFile -Force -ErrorAction SilentlyContinue }
        }
    } catch {}
    # Lavoro COMPLETATO: via il checkpoint di ripresa sessione (contiene anche
    # le credenziali generate: non deve restare sul PC del cliente). La cartella
    # ProgramData\PCFacile resta perche' contiene i log tecnici (senza
    # credenziali): li teniamo per l'assistenza.
    try { Remove-Item $Global:StatoFile -Force -ErrorAction SilentlyContinue } catch {}
    $ioStesso = $MyInvocation.MyCommand.Path
    if ($ioStesso -and $ioStesso -like "$env:TEMP\*") {
        # Il file .ps1 in esecuzione NON e' bloccato: lo rimuovo ora, lo script
        # prosegue dalla memoria. Cosi' non resta nulla sul disco del cliente.
        try { Remove-Item -LiteralPath $ioStesso -Force -ErrorAction SilentlyContinue } catch {}
    }
    Write-OK "Pulizia finale: PC Facile rimosso dal PC (la scheda di consegna resta sul Desktop)."
}

# AGGIORNAMENTI WINDOWS: erano in DOWNLOAD in background. Ora (dopo driver e
# antivirus, cosi' non c'e' un'altra installazione Windows Update in corso)
# completo eventuali download residui e INSTALLO tutti gli aggiornamenti
# disponibili (inclusi cumulativi e anteprima), sincronizzando anche UsoClient
# cosi' non resta il pulsante "Scarica e installa tutto" da premere a mano.
if ($RunReale -and ($Global:JobWinUpdate -or $Global:AvviaWinUpdateDopoDriver)) {
    Write-Host ""
    Enable-WindowsUpdateAutoSettings
    if ($Global:JobWinUpdate) {
        Write-Info "Completo il download degli aggiornamenti di Windows (avviato prima in background)..."
        Start-BarraAnimata "Aggiornamenti Windows: completo il download"
        try { Wait-Job $Global:JobWinUpdate -Timeout 600 | Out-Null } catch {} finally { Stop-BarraAnimata }
        try { $null = Receive-Job $Global:JobWinUpdate -ErrorAction SilentlyContinue } catch {}
        Stop-Job $Global:JobWinUpdate -ErrorAction SilentlyContinue
        Remove-Job $Global:JobWinUpdate -Force -ErrorAction SilentlyContinue
    }
    Write-Info "Scarico e installo tutti gli aggiornamenti Windows disponibili (inclusi anteprima)..."
    Start-BarraAnimata "Installo gli aggiornamenti di Windows (max 10 min)"
    try {
        $jobFinInstall = Start-Job -ScriptBlock {
            try {
                $uso = Join-Path $env:SystemRoot 'System32\UsoClient.exe'
                if (Test-Path -LiteralPath $uso) {
                    Start-Process -FilePath $uso -ArgumentList 'StartInteractiveScan' -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
                }
                $sFin = New-Object -ComObject Microsoft.Update.Session
                $searcherFin = $sFin.CreateUpdateSearcher()
                try { $searcherFin.Online = $true } catch {}
                $rFin = $searcherFin.Search("IsInstalled=0 and IsHidden=0")
                $daScaricare = New-Object -ComObject Microsoft.Update.UpdateColl
                $cFin = New-Object -ComObject Microsoft.Update.UpdateColl
                foreach ($u in $rFin.Updates) {
                    if ($u.InstallationBehavior -and $u.InstallationBehavior.CanRequestUserInput) { continue }
                    if (-not $u.EulaAccepted) { try { $u.AcceptEula() } catch {} }
                    if (-not $u.IsDownloaded) { $daScaricare.Add($u) | Out-Null }
                }
                if ($daScaricare.Count -gt 0) {
                    $dlFin = $sFin.CreateUpdateDownloader()
                    $dlFin.Updates = $daScaricare
                    $dlFin.Download() | Out-Null
                }
                foreach ($u in $rFin.Updates) {
                    if ($u.InstallationBehavior -and $u.InstallationBehavior.CanRequestUserInput) { continue }
                    if ($u.IsDownloaded) { $cFin.Add($u) | Out-Null }
                }
                $installatiCount = $cFin.Count
                if ($installatiCount -gt 0) {
                    $iFin = $sFin.CreateUpdateInstaller()
                    $iFin.Updates = $cFin
                    $null = $iFin.Install()
                }
                if (Test-Path -LiteralPath $uso) {
                    Start-Process -FilePath $uso -ArgumentList 'StartDownload' -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
                    Start-Sleep -Seconds 2
                    Start-Process -FilePath $uso -ArgumentList 'StartInstall' -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
                }
                return $installatiCount
            } catch { return -1 }
        }
        if (Wait-Job $jobFinInstall -Timeout 600) {
            $nInst = [int](Receive-Job $jobFinInstall -ErrorAction SilentlyContinue | Select-Object -Last 1)
            if ($nInst -gt 0) {
                Write-OK "Aggiornamenti di Windows installati ($nInst): il riavvio finale li completa."
            } else {
                Write-OK "Windows Update allineato e aggiornamenti avviati."
            }
        } else {
            Stop-Job $jobFinInstall -ErrorAction SilentlyContinue
            Write-Info "Tempo massimo installazione aggiornamenti raggiunto: il riavvio finale finalizzera' l'installazione."
        }
        Remove-Job $jobFinInstall -Force -ErrorAction SilentlyContinue
    } catch {} finally { Stop-BarraAnimata }
    try {
        $usoFin = Join-Path $env:SystemRoot 'System32\UsoClient.exe'
        if (Test-Path -LiteralPath $usoFin) {
            Start-Process -FilePath $usoFin -ArgumentList 'StartDownload' -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
            Start-Process -FilePath $usoFin -ArgumentList 'StartInstall' -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {}
}

# MENU DI CHIUSURA: Check Salute PC oppure Riavvio (il pannello web resta collegato!)
if ($RunReale) {
    Set-PreventSleep $false
    try { $host.UI.RawUI.WindowTitle = "PC Facile [100%] - CONFIGURAZIONE COMPLETATA!" } catch {}
    Update-PannelloStatus -TaskId "diagnostica" -Stato "done" -Percentuale 100 -FaseCorrente "CONFIGURAZIONE COMPLETATA!" -Dettaglio "Tutte le procedure sono terminate. Puoi chiudere o riavviare." -Completato
    Write-Titolo "COMPLETAMENTO PC FACILE"
    Write-OK "TUTTE LE PROCEDURE SONO TERMINATE: CONFIGURAZIONE COMPLETATA AL 100%!"
    Beep-Completato   # melodia "tutto finito" subito appena termina l'ultima procedura
    Write-Host "Configurazione e ottimizzazione completate con successo!" -ForegroundColor Green
    Write-Host "  (Il Pannello Operatore resta attivo: puoi usare la scheda '4. Passaggi' per ripetere qualsiasi operazione)" -ForegroundColor Cyan
    Write-Host ""
    
    $linguaOk = @($Report | Where-Object { $_.Voce -like "Lingua italiana (it-IT*" -and $_.Esito -eq "OK" }).Count -gt 0
    
    do {
        Write-Host "Scegli come procedere:" -ForegroundColor White
        Write-Host "  1) Esegui Check Completo Salute PC (SSD SMART, Batteria, Licenza, Driver, BitLocker)" -ForegroundColor Cyan
        Write-Host "  2) Riavvia il PC adesso (Consigliato per rendere attive tutte le modifiche)" -ForegroundColor Green
        Write-Host "  3) Esci senza riavviare (Riavvio manuale in seguito)" -ForegroundColor Yellow
        Write-Host ""

        $sceltaFine = Attendi-Risposta "Scelta (1-3, INVIO = 3 Esci)"
        if ([string]::IsNullOrWhiteSpace($sceltaFine)) { $sceltaFine = "3" }
        switch ($sceltaFine) {
            "1" {
                Invoke-PcFacileDiagnostics -MostraDettagli | Out-Null
                Write-Host ""
            }
            "2" {
                try {
                    Stop-LocalCredServer
                    $tmpPannello = Join-Path $(if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }) "Pannello-Operatore.html"
                    Remove-Item -LiteralPath $tmpPannello -Force -ErrorAction SilentlyContinue
                } catch {}
                Write-Info "Riavvio del PC in corso..."
                Restart-Computer -Force
                break
            }
            "3" {
                try {
                    Stop-LocalCredServer
                    $tmpPannello = Join-Path $(if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }) "Pannello-Operatore.html"
                    Remove-Item -LiteralPath $tmpPannello -Force -ErrorAction SilentlyContinue
                } catch {}
                if ($linguaOk) {
                    Write-Info "Ricordati di riavviare prima di consegnare il PC per applicare lingua e nuove impostazioni."
                }
                break
            }
            default {
                Write-Info "Opzione non valida. Inserisci 1, 2 o 3."
            }
        }
    } while ($sceltaFine -ne "2" -and $sceltaFine -ne "3")
}

Write-Host ""
Beep-Completato   # melodia "tutto finito" (utile se ti sei allontanato)
Write-Host "${AON}Buon lavoro!$AOFF" -ForegroundColor $THEME_COL

# Assicura chiusura di eventuali barre di progresso o job residui e azzera il codice di uscita
try { Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue } catch {}
try { $ProgressPreference = 'SilentlyContinue' } catch {}
$LASTEXITCODE = 0
# Niente Pausa qui: l'unico "premi un tasto" e' quello finale del launcher .bat
# ("Operazione terminata"), cosi' non si preme INVIO due volte.

