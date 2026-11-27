# =============================================================================
# tools/telecomando.ps1 - Telecomando Live per eseguire comandi o istruzioni
# sugli altri PC (Windows e Mac) dove e' in esecuzione PC Facile.
# -----------------------------------------------------------------------------
# Uso da questa chat o da terminale sul Mac:
#   1) Vedere tutti i PC attivi in negozio e gli ultimi risultati:
#      pwsh ./tools/telecomando.ps1 -Stato
#   2) Inviare un'istruzione in italiano o un comando PowerShell/Zsh a un PC
#      (Target = "*" per tutti i PC attivi, oppure Seriale / Modello / Hostname):
#      pwsh ./tools/telecomando.ps1 -Comando "togli password windows" -Titolo "Sblocco login"
#      pwsh ./tools/telecomando.ps1 -Target "MSI" -Comando "Get-Process | Select -First 10"
# =============================================================================
param(
    [switch]$Stato,
    [string]$Target = "*",
    [ValidateSet("any", "windows", "mac")][string]$Os = "any",
    [string]$Titolo = "Istruzione remota da Assistente IA",
    [string]$Comando = "",
    [int]$AttesaRispostaSec = 15,
    [switch]$SenzaPush
)

$ErrorActionPreference = 'Stop'
$radice = Split-Path $PSScriptRoot -Parent
$cmdFile = Join-Path $radice "remote/commands.json"
$telemetriaUrl = "https://ntfy.sh/pcfacile-sn97-telemetria-7f9a2c/json?poll=1&since=30m"

function Get-TelemetriaRemota {
    try {
        $raw = Invoke-WebRequest -Uri $telemetriaUrl -UseBasicParsing -TimeoutSec 8 -ErrorAction Stop
        $lines = @($raw.Content -split "`r?`n" | Where-Object { $_.Trim() })
        $eventi = @()
        foreach ($l in $lines) {
            try {
                $outer = $l | ConvertFrom-Json -ErrorAction Stop
                if ($outer.event -eq 'message' -and $outer.message) {
                    $inner = $outer.message | ConvertFrom-Json -ErrorAction Stop
                    $eventi += $inner
                }
            } catch {}
        }
        return $eventi
    } catch {
        return @()
    }
}

if ($Stato -or (-not $Comando)) {
    Write-Host "=== STATO TELECOMANDO PC FACILE (ULTIMI 30 MINUTI) ===" -ForegroundColor Cyan
    $ev = @(Get-TelemetriaRemota)
    if ($ev.Count -eq 0) {
        Write-Host "Nessun evento ricevuto negli ultimi 30 minuti." -ForegroundColor Yellow
    } else {
        foreach ($e in ($ev | Select-Object -Last 15)) {
            $ts = if ($e.ts) { $e.ts } else { "" }
            $pc = "$($e.pc) ($($e.modello) - S/N: $($e.seriale))"
            if ($e.type -eq 'cmd_result') {
                Write-Host "[$ts] [RISULTATO COMANDO] $pc -> $($e.title) (ID: $($e.id), OK: $($e.ok))" -ForegroundColor Green
                if ($e.output) { Write-Host $e.output -ForegroundColor White }
            } else {
                Write-Host "[$ts] [ONLINE] $pc -> $($e.pct)% - $($e.fase)" -ForegroundColor Gray
            }
        }
    }
    if (-not $Comando) { return }
}

$cmdId = "cmd-" + (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss") + "-" + ([guid]::NewGuid().ToString("N").Substring(0, 6))
$data = @{
    updatedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    commands  = @(
        @{
            id      = $cmdId
            target  = $Target
            os      = $Os
            title   = $Titolo
            command = $Comando
        }
    )
}
$json = ($data | ConvertTo-Json -Depth 5) + "`n"
$dirRemote = Split-Path $cmdFile -Parent
if (-not (Test-Path -LiteralPath $dirRemote)) { New-Item -ItemType Directory -Path $dirRemote -Force | Out-Null }
[System.IO.File]::WriteAllText($cmdFile, ($json -replace "`r`n", "`n"), (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Comando preparato in remote/commands.json: $cmdId ($Titolo -> Target: $Target)" -ForegroundColor Cyan

if (-not $SenzaPush) {
    Push-Location $radice
    try {
        & git add remote/commands.json
        & git commit -m "chore(remote): invia comando remoto $cmdId ($Titolo)"
        & git push
    } finally {
        Pop-Location
    }
    Write-Host "Comando pubblicato su GitHub. In attesa della risposta dal PC remoto (max ${AttesaRispostaSec}s)..." -ForegroundColor Yellow
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $AttesaRispostaSec) {
        Start-Sleep -Seconds 3
        $ev = @(Get-TelemetriaRemota | Where-Object { $_.type -eq 'cmd_result' -and $_.id -eq $cmdId })
        if ($ev.Count -gt 0) {
            foreach ($r in $ev) {
                Write-Host ""
                Write-Host "=== RISPOSTA RICEVUTA DA $($r.pc) ($($r.modello) · S/N $($r.seriale)) ===" -ForegroundColor Green
                Write-Host $r.output -ForegroundColor White
            }
            return
        }
    }
    Write-Host "Comando inviato e pronto in coda: verra' eseguito appena il PC target e' online." -ForegroundColor Yellow
}
