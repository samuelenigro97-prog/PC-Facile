@echo off
title PC Facile
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_PATH=%~f0"
cd /d "%SCRIPT_DIR%" >nul 2>&1
REM ============================================================
REM  PC Facile.bat - launcher ottimizzato 1-Click per setup-pc.ps1
REM  - Elevazione amministratore immediata (UN SOLO prompt UAC)
REM  - Sblocco automatico file (elimina gli avvisi SmartScreen/Apri file)
REM  - Parte SEMPRE con ExecutionPolicy Bypass (niente errori di blocco)
REM  - Scarica l'ultima versione da GitHub con fallback offline su USB
REM ============================================================

REM --- 0. Completa un auto-aggiornamento del launcher rimasto in sospeso ---
REM La nuova versione (gia' verificata SHA256 dal manifest) viene salvata come
REM "PC Facile.bat.nuovo" perche' cmd.exe legge il .bat mentre lo esegue: non si
REM puo' sovrascrivere mentre gira. Qui (e alla fine) la metto al suo posto.
REM Tutto dentro UN blocco tra parentesi: cmd lo legge per intero prima di
REM eseguirlo, quindi dopo il MOVE non rilegge il vecchio file e passa al nuovo.
if exist "%SCRIPT_PATH%.nuovo" (
    move /y "%SCRIPT_PATH%.nuovo" "%SCRIPT_PATH%" >nul 2>&1 && "%SCRIPT_PATH%" %*
)

REM --- 1. Elevazione immediata ad amministratore (UN SOLO prompt UAC) ---
REM "elevated"/"run" come primo argomento e' un marcatore interno del launcher:
REM lo tolgo con SHIFT /1 (cosi' %0 non viene mai sovrascritto da "elevated").
if /i "%~1"=="elevated" (
    shift /1
    goto :elevato
)
if /i "%~1"=="run" (
    shift /1
    goto :elevato
)

net session >nul 2>&1
if %errorlevel% equ 0 goto :elevato
fltmc >nul 2>&1
if %errorlevel% equ 0 goto :elevato

powershell -NoProfile -ExecutionPolicy Bypass -Command "$p='%SCRIPT_PATH%'; $q=[char]34; try { Start-Process -FilePath 'cmd.exe' -ArgumentList ('/c ' + $q + $q + $p + $q + ' elevated' + $q) -Verb RunAs -ErrorAction Stop } catch { try { Start-Process -FilePath $p -ArgumentList 'elevated' -Verb RunAs -ErrorAction Stop } catch { exit 1 } }"
if %errorlevel% neq 0 (
    echo.
    echo   [!] Richiesta privilegi amministratore annullata o non concessa.
    echo   Per avviare: fai click destro su "PC Facile.bat" e scegli "Esegui come amministratore".
    echo.
    powershell -NoProfile -Command "Start-Sleep -Seconds 5" >nul 2>&1
)
exit

:elevato
cd /d "%SCRIPT_DIR%" >nul 2>&1
set "USER_ARGS="
:raccogli_argomenti
if "%~1"=="" goto :argomenti_pronti
set "USER_ARGS=%USER_ARGS% %1"
shift /1
goto :raccogli_argomenti
:argomenti_pronti

REM --- 2. Impostazioni console a tema Unieuro (Navy #00122B & Arancio #EE7203) ---
set "SEE_MASK_NOZONECHECKS=1"
REM Backup delle impostazioni console ORIGINALI (una sola volta): setup-pc.ps1
REM le ripristina nella pulizia finale. Un backup gia' presente NON viene
REM sovrascritto (es. ripresa dopo riavvio: le chiavi sarebbero gia' modificate).
if not exist "%ProgramData%\PCFacile" mkdir "%ProgramData%\PCFacile" >nul 2>&1
if not exist "%ProgramData%\PCFacile\console-backup.reg" reg export "HKCU\Console" "%ProgramData%\PCFacile\console-backup.reg" /y >nul 2>&1
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

REM Disabilita schermata di benvenuto Edge, sync e popup widget Windows 11
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v HideFirstRunExperience /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v SyncDisabled /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v AutoImportAtFirstRun /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v EdgeWidgetAllowed /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v HubsSidebarEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v StandaloneHubsSidebarEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist" /v "1" /t REG_SZ /d "cpikpibllpjmpnchjajlibnmmomnnhnm;https://edge.microsoft.com/extensionwebstorebase/v1/crx" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist" /v "1" /t REG_SZ /d "jmjjnhpacphpjmnnlnccpfmhkcloaade;https://clients2.google.com/service/update2/crx" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /v AllowNewsAndInterests /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v BingSearchEnabled /t REG_DWORD /d 0 /f >nul 2>&1

REM Disattiva per sempre la scadenza password Windows (42 giorni), rimuove la richiesta
REM di password al risveglio dallo standby e riabilita l'accesso diretto senza password.
net accounts /maxpwage:unlimited >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device" /v DevicePasswordLessBuildVersion /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Power\PowerSettings\0e796bdb-100d-47d6-a2d5-f7d2daa51f51" /v ACSettingIndex /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Power\PowerSettings\0e796bdb-100d-47d6-a2d5-f7d2daa51f51" /v DCSettingIndex /t REG_DWORD /d 0 /f >nul 2>&1
powercfg /setacvalueindex SCHEME_CURRENT SUB_NONE CONSOLELOCK 0 >nul 2>&1
powercfg /setdcvalueindex SCHEME_CURRENT SUB_NONE CONSOLELOCK 0 >nul 2>&1
powercfg /setactive SCHEME_CURRENT >nul 2>&1

REM Sblocca automaticamente tutti i file della chiavetta ed elimina gli avvisi SmartScreen / Apri file
powershell -NoProfile -ExecutionPolicy Bypass -Command "$env:SEE_MASK_NOZONECHECKS=1; Get-ChildItem -Path '%SCRIPT_DIR%' -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '^\.(ps1|bat|cmd|command)$' } | Unblock-File -ErrorAction SilentlyContinue" >nul 2>&1

REM Imposta SUBITO il layout tastiera ITALIANO (00000410) in tempo reale cosi' la chiocciola (@ = AltGr+o')
REM funziona all'istante sia per la password Wi-Fi sia nel Pannello Operatore, anche su PC nuovi in inglese.
reg add "HKCU\Keyboard Layout\Preload" /v "1" /t REG_SZ /d "00000410" /f >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue'; try { $l=New-WinUserLanguageList 'it-IT'; $l[0].InputMethodTips.Clear(); $l[0].InputMethodTips.Add('0410:00000410'); Set-WinUserLanguageList -LanguageList $l -Force | Out-Null } catch {}; try { Add-Type -Name KbdIt -Namespace Win32 -MemberDefinition '[DllImport(\"user32.dll\", CharSet=CharSet.Auto)] public static extern IntPtr LoadKeyboardLayout(string pwszKLID, uint Flags); [DllImport(\"user32.dll\")] public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);'; $h=[Win32.KbdIt]::LoadKeyboardLayout('00000410', 1); [void][Win32.KbdIt]::PostMessage([IntPtr]0xFFFF, 0x0050, [IntPtr]::Zero, $h) } catch {}" >nul 2>&1

REM --- 2b. Antivirus di prova preinstallato (McAfee, Norton, Avast, AVG) ---
REM Rimozione 100%% automatica PRIMA dell'avvio di tutte le altre funzionalita'.
call :mcafee
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue'; $paths=@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'); $avs=Get-ItemProperty $paths | Where-Object { $_.DisplayName -match 'Norton|Avast|AVG' -and ($_.QuietUninstallString -or $_.UninstallString) }; foreach($av in $avs){ Write-Host ('[AUTO] Rimozione antivirus di prova preinstallato: ' + $av.DisplayName) -ForegroundColor Cyan; $cmd = if($av.QuietUninstallString){ $av.QuietUninstallString } else { $av.UninstallString + ' /silent /quiet /norestart' }; $p = Start-Process -FilePath 'cmd.exe' -ArgumentList ('/d /s /c \"' + $cmd + '\"') -PassThru -ErrorAction SilentlyContinue; if($p){ [void]$p.WaitForExit(45000) } }"

REM --- Auto-connessione Wi-Fi Negozio da chiavetta USB (se non ancora connesso a Internet) ---
REM Controllo Internet via HTTP con piu' fallback: il solo ping ICMP a 8.8.8.8 e'
REM spesso bloccato dalle reti dei negozi anche quando Internet funziona.
set "NET_OK="
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; try { if ((Invoke-WebRequest 'http://www.msftconnecttest.com/connecttest.txt' -UseBasicParsing -TimeoutSec 3).StatusCode -eq 200) { exit 0 } } catch {}; foreach ($u in @('https://raw.githubusercontent.com/','https://www.google.com/generate_204')) { try { Invoke-WebRequest $u -Method Head -UseBasicParsing -TimeoutSec 3 | Out-Null; exit 0 } catch { if ($_.Exception.Response) { exit 0 } } }; if (@(Test-Connection -ComputerName 1.1.1.1,8.8.8.8 -Count 1 -Quiet -ErrorAction SilentlyContinue) -contains $true) { exit 0 }; exit 1" >nul 2>&1
if %errorlevel% equ 0 (
    set "NET_OK=1"
    goto :wifi_ok
)
echo [AUTO] Connessione Wi-Fi da chiavetta USB in corso...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue'; $q=[char]34; $giaConnesso=((& netsh wlan show interfaces) -match '^\s*(State|Stato)\s*:\s*(connected|connesso)'); $retiVisibili=(& netsh wlan show networks) -join ' '; $dirs=@('%SCRIPT_DIR%wifi','%SCRIPT_DIR%'); foreach($drv in (Get-PSDrive -PSProvider FileSystem)){ if($drv.Root -and $drv.Root -notlike 'C:*'){ $dirs += (Join-Path $drv.Root 'wifi'); $dirs += $drv.Root } }; $dirs = $dirs | Select-Object -Unique; foreach($d in $dirs){ if(Test-Path $d){ Get-ChildItem -Path $d -Filter '*.xml' | ForEach-Object { $c=Get-Content $_.FullName -Raw; if($c -match '<name>(.*?)</name>'){ $ssid=$Matches[1]; & netsh wlan add profile ('filename=' + $_.FullName) 'user=all' | Out-Null; if(-not $giaConnesso -and $retiVisibili -match [regex]::Escape($ssid)){ & netsh wlan connect ('name=' + $ssid) | Out-Null } } }; if(Test-Path (Join-Path $d 'wifi.txt')){ $lines=Get-Content (Join-Path $d 'wifi.txt'); $s=''; $p=''; foreach($l in $lines){ if($l -match '^(SSID|WIFI|RETE)\s*[:=]\s*(.+)$'){$s=$Matches[2].Trim()} elseif($l -match '^(PASS|PASSWORD|KEY|CHIAVE)\s*[:=]\s*(.+)$'){$p=$Matches[2].Trim()} }; if($p){ try { Set-Clipboard -Value $p } catch {} }; if($s -and $p){ $se=[Security.SecurityElement]::Escape($s); $pe=[Security.SecurityElement]::Escape($p); $xml = '<?xml version='+$q+'1.0'+$q+'?><WLANProfile xmlns='+$q+'http://www.microsoft.com/networking/WLAN/profile/v1'+$q+'><name>'+$se+'</name><SSIDConfig><SSID><name>'+$se+'</name></SSID></SSIDConfig><connectionType>ESS</connectionType><connectionMode>auto</connectionMode><MSM><security><authEncryption><authentication>WPA2PSK</authentication><encryption>AES</encryption><useOneX>false</useOneX></authEncryption><sharedKey><keyType>passPhrase</keyType><protected>false</protected><keyMaterial>'+$pe+'</keyMaterial></sharedKey></security></MSM></WLANProfile>'; $t=$env:TEMP+'\w.xml'; [IO.File]::WriteAllText($t,$xml); & netsh wlan add profile ('filename=' + $t) 'user=all' | Out-Null; if(-not $giaConnesso -and $retiVisibili -match [regex]::Escape($s)){ & netsh wlan connect ('name=' + $s) | Out-Null }; Remove-Item $t -Force } } } }; $ok=$false; for($w=0;$w -lt 6;$w++){ Start-Sleep -Seconds 1; try { if ((Invoke-WebRequest 'http://www.msftconnecttest.com/connecttest.txt' -UseBasicParsing -TimeoutSec 2).StatusCode -eq 200) { $ok=$true; break } } catch { try { Invoke-WebRequest 'https://www.google.com/generate_204' -Method Head -UseBasicParsing -TimeoutSec 2 | Out-Null; $ok=$true; break } catch {} } }; if($ok){ Write-Host '[OK] Internet connesso con successo!' -ForegroundColor Green; exit 0 } else { Write-Host '[!] Connessione non ancora attiva: proseguo comunque (tastiera ITA attiva e password Wi-Fi copiata negli appunti).' -ForegroundColor Yellow; exit 1 }"
if %errorlevel% equ 0 set "NET_OK=1"
:wifi_ok
REM Sincronizza subito fuso orario italiano e orologio Windows prima dei download HTTPS
REM (molti PC fermi in magazzino hanno l'ora BIOS sballata che fa fallire i certificati SSL/TLS).
tzutil /s "W. Europe Standard Time" >nul 2>&1
sc config w32time start= auto >nul 2>&1
net start w32time >nul 2>&1
w32tm /resync /force >nul 2>&1
powercfg /change standby-timeout-ac 0 >nul 2>&1
powercfg /change standby-timeout-dc 0 >nul 2>&1
powercfg /change monitor-timeout-ac 0 >nul 2>&1
powercfg /change monitor-timeout-dc 0 >nul 2>&1

REM --- 3. Scarica l'ultima versione da GitHub (con fallback offline) ---
REM Il file scaricato viene tenuto SOLO se il suo SHA256 combacia con
REM setup-pc.ps1.sha256. Se l'impronta non si scarica o non combacia il download
REM viene scartato e si usa la copia sulla chiavetta (nessuna esecuzione "al buio").
set "HAS_LOCAL="
if exist "%SCRIPT_DIR%setup-pc.ps1" set "HAS_LOCAL=1"

del "%TEMP%\setup-pc*.ps1" /f /q >nul 2>&1
set "PS1=%TEMP%\setup-pc-%RANDOM%%RANDOM%.ps1"

if not defined NET_OK if defined HAS_LOCAL goto :avvia_esecuzione

echo Scarico l'ultima versione da GitHub...
powershell -NoProfile -ExecutionPolicy Bypass -Command "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12; $bases=@('https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main','https://cdn.jsdelivr.net/gh/samuelenigro97-prog/pc-facile@main'); $done=$false; foreach($base in $bases){ if($done){break}; try { $t=(Get-Date).Ticks; Invoke-WebRequest -Uri ($base+'/setup-pc.ps1?t='+$t) -UseBasicParsing -TimeoutSec 12 -Headers @{ 'Cache-Control'='no-cache' } -OutFile '%PS1%' -ErrorAction Stop; $rawSha=[string](Invoke-WebRequest -Uri ($base+'/setup-pc.ps1.sha256?t='+$t) -UseBasicParsing -TimeoutSec 6 -Headers @{ 'Cache-Control'='no-cache' } -ErrorAction Stop).Content; $atteso=(($rawSha.Trim()) -split '\s+')[0].ToLower(); $reale=(Get-FileHash '%PS1%' -Algorithm SHA256).Hash.ToLower(); if ($atteso -match '^[0-9a-f]{64}$' -and $reale -eq $atteso) { Write-Host ('Scaricato e verificato da: '+$base) -ForegroundColor Green; $done=$true } else { Remove-Item '%PS1%' -Force -ErrorAction SilentlyContinue } } catch { Remove-Item '%PS1%' -Force -ErrorAction SilentlyContinue } }; if(-not $done){ Remove-Item '%PS1%' -Force -ErrorAction SilentlyContinue; if ('%HAS_LOCAL%' -eq '1') { Write-Host 'Uso la copia su chiavetta USB...' -ForegroundColor Yellow } else { Write-Host 'Impossibile scaricare lo script: connessione assente o bloccata.' -ForegroundColor Yellow } }"

:avvia_esecuzione
REM --- 4. Esecuzione script ---
set "TARGET_DIR=%SCRIPT_DIR%"
if "%TARGET_DIR:~-1%"=="\" set "TARGET_DIR=%TARGET_DIR:~0,-1%"

REM %PS1% esiste solo se il download e' stato VERIFICATO (SHA256): solo allora
REM aggiorno la chiavetta con TUTTI i file elencati in manifest.txt (ognuno
REM verificato SHA256 prima di sostituire la copia; i file Wi-Fi non si toccano).
REM Se qualcosa non va, restano i file attuali e si prosegue comunque.
if exist "%PS1%" (
    echo Aggiorno i file della chiavetta ^(manifest.txt^)...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -AggiornaUSB -TargetDir "%TARGET_DIR%" -LauncherPath "%SCRIPT_PATH%"
    if defined USER_ARGS (
        powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -NoSelfUpdate -TargetDir "%TARGET_DIR%" -LauncherPath "%SCRIPT_PATH%" %USER_ARGS%
    ) else (
        powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -NoSelfUpdate -TargetDir "%TARGET_DIR%" -LauncherPath "%SCRIPT_PATH%"
    )
    goto :fine
)

if exist "%SCRIPT_DIR%setup-pc.ps1" (
    echo Offline: uso la copia sulla chiavetta ^(funziona al 100%% senza Internet^).
    if defined USER_ARGS (
        powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%setup-pc.ps1" -TargetDir "%TARGET_DIR%" -LauncherPath "%SCRIPT_PATH%" %USER_ARGS%
    ) else (
        powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%setup-pc.ps1" -TargetDir "%TARGET_DIR%" -LauncherPath "%SCRIPT_PATH%"
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
    echo.
    echo Premi un tasto per chiudere...
    pause >nul
)

:fine
REM Auto-aggiornamento del launcher: sostituisco questo file con la nuova
REM versione verificata ed esco nello STESSO blocco (cmd non rilegge il file).
if exist "%SCRIPT_PATH%.nuovo" (
    move /y "%SCRIPT_PATH%.nuovo" "%SCRIPT_PATH%" >nul 2>&1
)
exit /b

REM ============================================================
REM  McAfee: rilevamento e rimozione automatica silenziosa
REM ============================================================
:mcafee
setlocal EnableDelayedExpansion
call :mcafee_rileva
if "!MC_N!"=="0" if not defined MC_SVC (
    endlocal
    exit /b 0
)
echo.
echo [AUTO] Rilevato McAfee preinstallato: rimozione automatica silenziosa in corso...
for /l %%I in (1,1,!MC_N!) do echo     - !MC_NOME_%%I!
if "!MC_N!"=="0" goto :mcafee_mcpr
for /l %%I in (1,1,!MC_N!) do call :mcafee_uno %%I
call :mcafee_rileva
if "!MC_N!"=="0" if not defined MC_SVC goto :mcafee_riavvio
:mcafee_mcpr
set "MCPR="
if exist "%~dp0installers\MCPR.exe" set "MCPR=%~dp0installers\MCPR.exe"
if not defined MCPR goto :mcafee_riavvio
set "MC_OK="
powershell -NoProfile -Command "$s=Get-AuthenticodeSignature -LiteralPath '%MCPR%'; if ($s.Status -eq 'Valid' -and $s.SignerCertificate.Subject -match 'McAfee') { exit 0 } else { exit 1 }" >nul 2>&1 && set "MC_OK=1"
if defined MC_OK (
    echo [AUTO] Avvio rimozione McAfee ^(MCPR^)...
    start "" /wait "%MCPR%" /quiet >nul 2>&1
)
:mcafee_riavvio
echo [OK] Procedura McAfee completata: proseguo automaticamente senza riavviare.
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

REM Avvia il disinstallatore McAfee in modalita' silenziosa senza attendere tasti.
:mcafee_uno
echo     Rimozione silenziosa di: !MC_NOME_%1!
cmd /c "!MC_UNS_%1! /quiet /silent /norestart" >nul 2>&1
winget uninstall --name "!MC_NOME_%1!" --silent --accept-source-agreements >nul 2>&1
exit /b 0
