@echo off
title PC Facile
REM ============================================================
REM  PC Facile.bat - launcher ottimizzato 1-Click per setup-pc.ps1
REM  - Elevazione amministratore immediata (UN SOLO prompt UAC)
REM  - Sblocco automatico file (elimina gli avvisi SmartScreen/Apri file)
REM  - Parte SEMPRE con ExecutionPolicy Bypass (niente errori di blocco)
REM  - Scarica l'ultima versione da GitHub con fallback offline su USB
REM ============================================================

REM --- 1. Elevazione immediata ad amministratore (UN SOLO prompt UAC) ---
if /i "%~1"=="elevated" (
    shift
    goto :elevato
)
if /i "%~1"=="run" (
    shift
    goto :elevato
)

net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process -FilePath 'cmd.exe' -ArgumentList '/c \"\"%~f0\" elevated %*\"' -Verb RunAs } catch { exit 1 }"
    if %errorlevel% neq 0 (
        echo.
        echo   [!] Richiesta privilegi amministratore annullata o non concessa.
        echo   Per avviare: fai click destro su "PC Facile.bat" e scegli "Esegui come amministratore".
        echo.
        pause
    )
    exit
)

:elevato
set "USER_ARGS=%*"

REM --- 2. Impostazioni console a tema Unieuro (Navy #00122B & Arancio #EE7203) ---
set "SEE_MASK_NOZONECHECKS=1"
reg add "HKCU\Console" /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Console" /v FaceName /t REG_SZ /d "Consolas" /f >nul 2>&1
reg add "HKCU\Console" /v FontWeight /t REG_DWORD /d 700 /f >nul 2>&1
reg add "HKCU\Console" /v ColorTable00 /t REG_DWORD /d 0x002B1200 /f >nul 2>&1
reg add "HKCU\Console" /v ColorTable01 /t REG_DWORD /d 0x002B1200 /f >nul 2>&1
reg add "HKCU\Console" /v ColorTable02 /t REG_DWORD /d 0x005EC522 /f >nul 2>&1
reg add "HKCU\Console" /v ColorTable03 /t REG_DWORD /d 0x00FDC593 /f >nul 2>&1
reg add "HKCU\Console" /v ColorTable04 /t REG_DWORD /d 0x004444EF /f >nul 2>&1
reg add "HKCU\Console" /v ColorTable06 /t REG_DWORD /d 0x000372EE /f >nul 2>&1
reg add "HKCU\Console" /v ColorTable07 /t REG_DWORD /d 0x00FCFAF8 /f >nul 2>&1
reg add "HKCU\Console" /v ColorTable08 /t REG_DWORD /d 0x00B8A394 /f >nul 2>&1
reg add "HKCU\Console" /v ColorTable09 /t REG_DWORD /d 0x00FDC593 /f >nul 2>&1
reg add "HKCU\Console" /v ColorTable10 /t REG_DWORD /d 0x005EC522 /f >nul 2>&1
reg add "HKCU\Console" /v ColorTable11 /t REG_DWORD /d 0x00AAD7FE /f >nul 2>&1
reg add "HKCU\Console" /v ColorTable12 /t REG_DWORD /d 0x004444EF /f >nul 2>&1
reg add "HKCU\Console" /v ColorTable14 /t REG_DWORD /d 0x000372EE /f >nul 2>&1
reg add "HKCU\Console" /v ColorTable15 /t REG_DWORD /d 0x00FFFFFF /f >nul 2>&1
reg add "HKCU\Console" /v ScreenColors /t REG_DWORD /d 7 /f >nul 2>&1

REM Sblocca automaticamente tutti i file della chiavetta ed elimina gli avvisi SmartScreen / Apri file
powershell -NoProfile -ExecutionPolicy Bypass -Command "$env:SEE_MASK_NOZONECHECKS=1; Get-ChildItem -Path '%~dp0' -Recurse -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue" >nul 2>&1

REM --- Auto-connessione Wi-Fi Negozio da chiavetta USB (se non ancora connesso a Internet) ---
ping -n 1 8.8.8.8 >nul 2>&1
if %errorlevel% neq 0 (
    echo Connessione a Internet assente: verifico configurazione Wi-Fi su chiavetta...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue'; $dirs=@('%~dp0wifi','%~dp0'); foreach($d in $dirs){ if(Test-Path $d){ Get-ChildItem -Path $d -Filter '*.xml' | ForEach-Object { $c=Get-Content $_.FullName -Raw; if($c -match '<name>(.*?)</name>'){ & netsh wlan add profile filename=$_.FullName user=all >nul 2>&1; & netsh wlan connect name=$Matches[1] >nul 2>&1 } }; if(Test-Path (Join-Path $d 'wifi.txt')){ $lines=Get-Content (Join-Path $d 'wifi.txt'); $s=''; $p=''; foreach($l in $lines){ if($l -match '^(SSID|WIFI|RETE)\s*[:=]\s*(.+)$'){$s=$Matches[2].Trim()} elseif($l -match '^(PASS|PASSWORD|KEY|CHIAVE)\s*[:=]\s*(.+)$'){$p=$Matches[2].Trim()} }; if($s -and $p){ $xml = '<?xml version=\"1.0\"?><WLANProfile xmlns=\"http://www.microsoft.com/networking/WLAN/profile/v1\"><name>'+$s+'</name><SSIDConfig><SSID><name>'+$s+'</name></SSID></SSIDConfig><connectionType>ESS</connectionType><connectionMode>auto</connectionMode><MSM><security><authEncryption><authentication>WPA2PSK</authentication><encryption>AES</encryption><useOneX>false</useOneX></authEncryption><sharedKey><keyType>passPhrase</keyType><protected>false</protected><keyMaterial>'+$p+'</keyMaterial></sharedKey></security></MSM></WLANProfile>'; $t=$env:TEMP+'\w.xml'; [IO.File]::WriteAllText($t,$xml); & netsh wlan add profile filename=$t user=all >nul 2>&1; & netsh wlan connect name=$s >nul 2>&1; Remove-Item $t -Force } } } }; Start-Sleep -Seconds 3" >nul 2>&1
)

REM --- 2b. McAfee (antivirus di prova preinstallato) PRIMA di scaricare lo script ---
REM  Il suo modulo AMSI blocca setup-pc.ps1 ("ScriptContainedMaliciousContent").
REM  Si usa solo il disinstallatore ufficiale di McAfee (o il suo strumento MCPR),
REM  con l'operatore che conferma e segue le finestre: nessuna disattivazione silenziosa.
call :mcafee

REM --- 3. Scarica l'ultima versione da GitHub (con fallback offline) ---
set "HAS_LOCAL="
if exist "%~dp0setup-pc.ps1" set "HAS_LOCAL=1"

echo Scarico l'ultima versione da GitHub...
del "%TEMP%\setup-pc*.ps1" /f /q >nul 2>&1
set "PS1=%TEMP%\setup-pc-%RANDOM%%RANDOM%.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -Command "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12; $bases=@('https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main','https://cdn.jsdelivr.net/gh/samuelenigro97-prog/pc-facile@main'); $done=$false; foreach($base in $bases){ if($done){break}; for($i=1;$i -le 2 -and -not $done;$i++){ try { $t=(Get-Date).Ticks; irm ($base+'/setup-pc.ps1?t='+$t) -Headers @{ 'Cache-Control'='no-cache' } -OutFile '%PS1%' -ErrorAction Stop; try { $atteso=(((irm ($base+'/setup-pc.ps1.sha256?t='+$t) -Headers @{ 'Cache-Control'='no-cache' } -ErrorAction Stop).Trim()) -split '\s+')[0].ToLower(); $reale=(Get-FileHash '%PS1%' -Algorithm SHA256).Hash.ToLower(); if ($atteso -and $reale -ne $atteso) { Write-Host 'Impronta SHA256 non combacia: scarto.' -ForegroundColor Yellow; Remove-Item '%PS1%' -Force -ErrorAction SilentlyContinue } else { Write-Host ('Scaricato e verificato da: '+$base) -ForegroundColor Green; $done=$true } } catch { Write-Host 'Verifica SHA256 saltata.' -ForegroundColor Yellow; $done=$true } } catch { Start-Sleep -Milliseconds 500 } } }; if(-not $done){ Remove-Item '%PS1%' -Force -ErrorAction SilentlyContinue; if ('%HAS_LOCAL%' -eq '1') { Write-Host 'Download online non riuscito: avvio diretto dalla copia offline su chiavetta...' -ForegroundColor Yellow } else { Write-Host 'Impossibile scaricare lo script: connessione assente o bloccata.' -ForegroundColor Yellow } }"

REM --- 4. Esecuzione script ---
set "TARGET_DIR=%~dp0"
if "%TARGET_DIR:~-1%"=="\" set "TARGET_DIR=%TARGET_DIR:~0,-1%"

if exist "%PS1%" (
    copy /y "%PS1%" "%~dp0setup-pc.ps1" >nul 2>&1
    if defined USER_ARGS (
        powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -TargetDir "%TARGET_DIR%" %USER_ARGS%
    ) else (
        powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -TargetDir "%TARGET_DIR%"
    )
    goto :fine
)

if exist "%~dp0setup-pc.ps1" (
    echo Offline: uso la copia sulla chiavetta ^(funziona al 100%% senza Internet^).
    if defined USER_ARGS (
        powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-pc.ps1" -TargetDir "%TARGET_DIR%" %USER_ARGS%
    ) else (
        powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-pc.ps1" -TargetDir "%TARGET_DIR%"
    )
) else (
    echo.
    echo ============================================================
    echo   ATTENZIONE: Connessione a Internet assente e nessun file
    echo   'setup-pc.ps1' trovato sulla chiavetta USB!
    echo.
    echo   Soluzioni:
    echo   1. Connetti questo PC al Wi-Fi (in basso a destra) e riprova.
    echo   2. Oppure copia 'setup-pc.ps1' sulla chiavetta USB accanto
    echo      a 'PC Facile.bat' per farlo funzionare sempre al 100%% OFFLINE!
    echo ============================================================
)

:fine
echo.
echo ============================================================
echo   Operazione terminata. Premi un tasto per chiudere.
echo ============================================================
pause >nul
goto :eof

REM ============================================================
REM  McAfee: rilevamento e rimozione con gli strumenti ufficiali
REM ============================================================
:mcafee
setlocal EnableDelayedExpansion
call :mcafee_rileva
if "!MC_N!"=="0" if not defined MC_SVC (
    endlocal
    exit /b 0
)
echo.
echo ============================================================
echo   ATTENZIONE: su questo PC e' installato McAfee.
echo   McAfee blocca PC Facile ^(lo segnala come "contenuto dannoso"^):
echo   va rimosso PRIMA di continuare, con il suo disinstallatore ufficiale.
echo ============================================================
for /l %%I in (1,1,!MC_N!) do echo     - !MC_NOME_%%I!
if defined MC_SVC echo     - servizi McAfee attivi
echo.
choice /c SN /n /m "Rimuovo McAfee adesso? [S] Si' (consigliato)   [N] No, continua comunque: "
if errorlevel 2 goto :mcafee_fine
if "!MC_N!"=="0" goto :mcafee_mcpr
for /l %%I in (1,1,!MC_N!) do call :mcafee_uno %%I
call :mcafee_rileva
if "!MC_N!"=="0" if not defined MC_SVC goto :mcafee_riavvio
echo.
echo McAfee risulta ancora presente ^(a volte serve un riavvio per completare^).
:mcafee_mcpr
echo.
echo Strumento ufficiale di rimozione McAfee ^(MCPR^): toglie McAfee del tutto.
choice /c SRC /n /m "[S] Avvia MCPR   [R] Riavvia prima il PC   [C] Continua comunque: "
if errorlevel 3 goto :mcafee_fine
if errorlevel 2 goto :mcafee_riavvio
set "MCPR="
if exist "%~dp0installers\MCPR.exe" set "MCPR=%~dp0installers\MCPR.exe"
if defined MCPR goto :mcafee_mcpr_firma
set "MCPR=%TEMP%\MCPR.exe"
del "%MCPR%" /f /q >nul 2>&1
echo Scarico MCPR dal sito ufficiale McAfee...
curl.exe -fsSL -o "%MCPR%" "https://download.mcafee.com/molbin/iss-loc/SupportTools/MCPR/MCPR.exe" >nul 2>&1
if not exist "%MCPR%" powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://download.mcafee.com/molbin/iss-loc/SupportTools/MCPR/MCPR.exe' -OutFile '%MCPR%' -UseBasicParsing" >nul 2>&1
:mcafee_mcpr_firma
set "MC_OK="
if exist "%MCPR%" powershell -NoProfile -Command "$s=Get-AuthenticodeSignature -LiteralPath '%MCPR%'; if ($s.Status -eq 'Valid' -and $s.SignerCertificate.Subject -match 'McAfee') { exit 0 } else { exit 1 }" >nul 2>&1 && set "MC_OK=1"
if not defined MC_OK (
    echo [ATTENZIONE] MCPR non scaricato o firma McAfee non valida: non lo avvio.
    echo     Si apre la pagina ufficiale: scaricalo ed eseguilo a mano.
    start "" "https://www.mcafee.com/support/s/article/000002766"
    echo Premi un tasto quando hai finito...
    pause >nul
    goto :mcafee_riavvio
)
echo Avvio MCPR: Avanti, accetta, scrivi il codice di verifica mostrato, poi attendi
echo "CleanUp Successful". Quando MCPR chiede di riavviare, chiudilo e torna qui.
start "" /wait "%MCPR%"
echo Premi un tasto quando MCPR ha finito...
pause >nul
:mcafee_riavvio
echo.
echo ============================================================
echo   Per completare la rimozione di McAfee serve un RIAVVIO.
echo   Dopo il riavvio riapri "PC Facile.bat" dalla chiavetta.
echo ============================================================
choice /c RC /n /m "[R] Riavvia ora (consigliato)   [C] Continua senza riavviare: "
if errorlevel 2 goto :mcafee_fine
shutdown /r /t 10 /c "PC Facile: riavvio per completare la rimozione di McAfee. Poi riapri PC Facile.bat"
exit
:mcafee_fine
endlocal
exit /b 0

REM Elenca i programmi McAfee (chiavi Uninstall del registro) e i suoi servizi.
:mcafee_rileva
set "MC_N=0"
set "MC_SVC="
for %%R in ("HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall") do (
    for /f "delims=" %%K in ('reg query %%R /s /f "McAfee" /d 2^>nul ^| findstr /b /i "HKEY_"') do call :mcafee_voce "%%K"
)
for %%S in (mfemms mfevtp mfefire) do sc query %%S >nul 2>&1 && set "MC_SVC=1"
exit /b 0

:mcafee_voce
set "MC_NOME="
set "MC_UNS="
for /f "tokens=2,*" %%A in ('reg query "%~1" /v DisplayName 2^>nul ^| findstr /i /c:"DisplayName"') do set "MC_NOME=%%B"
for /f "tokens=2,*" %%A in ('reg query "%~1" /v UninstallString 2^>nul ^| findstr /i /c:"UninstallString"') do set "MC_UNS=%%B"
if not defined MC_NOME exit /b 0
if "!MC_NOME:McAfee=!"=="!MC_NOME!" exit /b 0
if not defined MC_UNS exit /b 0
set /a MC_N+=1
set "MC_NOME_!MC_N!=!MC_NOME!"
set "MC_UNS_!MC_N!=!MC_UNS!"
exit /b 0

REM Avvia il disinstallatore ufficiale registrato da McAfee e aspetta l'operatore.
:mcafee_uno
echo.
echo Avvio la disinstallazione di: !MC_NOME_%1!
echo Segui la finestra di McAfee fino alla fine ^(Rimuovi / Avanti^).
cmd /c "!MC_UNS_%1!"
echo Quando la disinstallazione e' finita, premi un tasto per continuare...
pause >nul
exit /b 0
