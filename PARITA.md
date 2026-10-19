# Parità Windows / Mac — PC Facile

Regola: **una modifica a una versione va replicata sull'altra.** Questa tabella
è la mappa. `setup-pc.ps1` (Windows) e `setup-mac.sh` (Mac) devono restare
allineati come flusso e funzioni.

| Passo / funzione            | Windows (`setup-pc.ps1`)                  | Mac (`setup-mac.sh`)                          | Note |
|-----------------------------|-------------------------------------------|-----------------------------------------------|------|
| Avvio unico (no menu)       | doppio click `PC Facile.bat` = configura; `-Test` solo CI, `-PreparaUSB`/`-Diagnostica` manutenzione | doppio click `PC Facile.command` = configura; `--test` solo CI, `--diagnostica` manutenzione | pari |
| Dati cliente (una volta)    | pannello locale → server `127.0.0.1:8899` (dati 100% facoltativi, nessun blocco console o attesa); prosegue trasparente con default se non compilati | pannello locale → file `pcfacile-cred.json` in Download (dati 100% facoltativi, nessun blocco console o attesa); prosegue trasparente con default se non compilati | pari |
| Ordine                      | fase 1 app+lingua (+Office) · fase 2 manuali · fase 3 pulizia/driver/aggiornamenti per ultimi | fase 1 lingua/app · fase 2 nome+account/servizi · fase 3 aggiornamenti per ultimi | pari |
| Lingua italiana             | `Install-Language it-IT -CopyToSettings`  | `defaults write AppleLanguages/AppleLocale`   | pari |
| Sincronizzazione orario     | `w32tm` + W32Time auto + tzautoupdate     | `systemsetup -setusingnetworktime on` + sntp  | pari |
| Nome cliente + host         | `Set-LocalUser` + `Rename-Computer`       | `scutil --set ComputerName/HostName`          | pari |
| Punto di ripristino         | `Checkpoint-Computer`                     | `tmutil localsnapshot` (Time Machine)         | pari |
| Account + credenziali       | Apre account.microsoft.com, genera cred   | Apre appleid.apple.com, genera cred           | pari |
| Office                      | installa se indicato nel pannello o crea icone/collegamenti (zero blocchi/attese dati) | — (su Mac Office si scarica da web, opzionale)| solo Win |
| Pulizia / ottimizzazione    | AV prova + debloat OEM + config Windows   | config `defaults` (no debloat OEM: non esiste)| Mac = solo config |
| Antivirus                   | McAfee/Norton                             | — (raramente su Mac; skip)                    | solo Win |
| Unieuro Cyber Protection    | apre portale                              | apre portale (uguale)                         | pari |
| Browser                     | catalogo winget                           | cask brew                                     | pari |
| App (BASE/UFFICIO/GAMING)   | winget + tool GPU se dedicata (NVIDIA/Intel Arc/AMD) | brew cask (Mac: GPU integrata) | pari |
| Aggiornamenti               | `winget upgrade` + aggiornamenti sicurezza Windows (COM Microsoft.Update) + driver Windows Update | `brew upgrade` + `softwareupdate` | pari |
| Chiave di ripristino disco  | **BitLocker** (`manage-bde`/cmdlet)       | **FileVault** (`fdesetup`)                    | pari |
| Barra attesa download/install| `Start-BarraAnimata` / `Stop-BarraAnimata` (runspace con tempo trascorso e titolo finestra) | `start_barra_animata_mac` / `stop_barra_animata_mac` (subshell animata con tempo trascorso e titolo finestra) | pari |
| Avviso sonoro fine passo    | `[console]::Beep`                         | `printf '\a'`                                 | pari |
| Bip di richiamo se non rispondi| runspace: dopo 2 min bip corto ogni ~4s   | `start_bip_ripetuto_mac` / `stop_bip_ripetuto_mac`: dopo 2 min bip ogni 4s | pari |
| Credenziali (esist./gen.)   | `Nome123!` + `Set-Clipboard`              | `Nome123!` + `pbcopy`                         | pari |
| Report finale / Scheda      | Desktop solo `Scheda-Consegna-Cliente.pdf` (ripiego `.html` se il PDF fallisce); riepilogo tecnico in `C:\ProgramData\PCFacile\log` | Desktop solo `Scheda-Consegna-Mac.pdf` (conversione automatica headless con ripiego `.html`); riepilogo tecnico in console e log | pari |
| Assist credenziali pagine   | copia email/password negli appunti + pulsanti copia nel pannello | copia email/password negli appunti + pulsanti copia nel pannello | pari |
| Soppressione First-Run browser | Policy HKLM/HKCU Edge (`HideFirstRunExperience`, `AutoImportAtFirstRun`, `DiagnosticData`, `LocalBrowserDataShareEnabled`) + switch CLI `--no-first-run` `--no-default-browser-check` | `defaults` Safari `AutoOpenSafeDownloads` false + switch CLI `--no-first-run` `--no-default-browser-check` | pari |
| Pannello Operatore Web      | Dashboard dinamica a pagina unica (form cliente collassabile in badge compatto all'avvio, 13 task live sempre a vista, griglia portali integrata) + timer `MM:SS` + chime | Dashboard dinamica a pagina unica (form cliente collassabile in badge compatto all'avvio, 12 task live sempre a vista, griglia portali integrata) + timer `MM:SS` + chime | pari |
| Wi-Fi auto-connessione (negozio) | `netsh wlan` + `wifi/wifi.txt` o `UNIEURO_EXPO.xml` (fallback embedded `UNIEURO_EXPO`) | `networksetup` + `wifi/wifi.txt` (fallback embedded `UNIEURO_EXPO`) | pari |
| Pulizia finale (auto-elimina)| rimuove `%TEMP%\setup-pc.ps1` + reg colori + checkpoint | `rm` dello script scaricato in `/tmp` | pari |
| Ripresa sessione interrotta | checkpoint JSON in `ProgramData\PCFacile` (anche fine dentro il passo App: profilo + app gia' fatte) | —          | solo Win |
| Collegamenti Office Desktop | WScript.Shell dopo installazione Office   | —                                             | solo Win |
| Icona Desktop per ogni app  | copia lnk da Start / shell:AppsFolder     | symlink .app su Desktop                      | pari |
| Scorciatoie portali/servizi | link diretti con auto-selezione checkbox nel pannello | link diretti con auto-selezione checkbox nel pannello | pari |
| Errori: rete di sicurezza   | `trap` a livello script + lista imprevisti | `registra_errore_imprevisto_mac` + `ERRORI_IMPREVISTI` (non bloccante) | pari |
| Log strutturato             | JSON + CSV in `ProgramData\PCFacile\log`  | JSON + CSV + `interventi.csv` in `/Library/Application Support/PCFacile/log` | pari |
| Auto-report GitHub (telemetria)| `Send-ReportGitHub`: Issue automatica su errori/avvisi (zero PII) | `send_report_github_mac`: Issue automatica su errori/avvisi (zero PII) | pari |

## Infrastruttura (a Livello di Repo, Vale per Entrambi)
- **Test Pester** (`tests/`) sulle funzioni pure di `setup-pc.ps1`.
- **CI GitHub Actions**: sintassi + PSScriptAnalyzer + Pester + verifica SHA256.
- **SHA256** (`setup-pc.ps1.sha256`) verificato dal `.bat` allo scaricamento; `setup-mac.sh.sha256` verificato da `PC Facile.command`.

## Solo Windows (Non Esiste su Mac)
- **Debloat barra Win11**: nasconde Widget, Chat, Vista attivita' e Ricerca dalla barra (registro HKCU).
- **Debloat OEM**: macOS non ha crapware del produttore.
- **Rimozione antivirus di prova**: quasi mai preinstallato su Mac.
- **Attivazione Office/driver**: Office da web, driver inclusi in macOS.
- **GeForce se NVIDIA**: i Mac recenti non hanno GPU NVIDIA.


## Versione e Launcher (Parità Completa)
- **Windows**: `setup-pc.ps1` v13.1 (2026-10-18); `1 - AVVIA PER WINDOWS.bat` mostra versione script locale e supporta download da branch oltre a main.
- **Mac**: `setup-mac.sh` v2.2 (2026-10-18); `2 - AVVIA PER MAC.command` mostra versione script locale e supporta download da branch oltre a main.

## Layout Console e Parità Visiva (Windows & Mac)
- **Separatori e Intestazioni**: Stesso formato a 60 caratteri (`============================================================`) in arancione sia su Windows (`setup-pc.ps1`) che su Mac (`setup-mac.sh`), eliminando cornici ASCII a larghezza fissa che sbordavano.
- **Icone e Prefissi di Stato**: Parità completa con `[OK]` (verde), `->` (arancio/giallo), `[X]` (rosso).
- **Pulizia Pipeline**: Eliminati i residui booleani (`True`) su Windows causati da `ShowWindow` e chiamate di sistema.

## Funzionalità Avanzate per Operatività di Negozio / Banco (Parità Completa)
| Funzionalità | Windows (`setup-pc.ps1`) | Mac (`setup-mac.sh`) | Note |
|---|---|---|---|
| **QR Code Ricevuta Consegna** | Generato a fine lavoro nel banner `#qrConsegnaCard` con credenziali, profilo, Wi-Fi negozio e seriale hardware | Generato a fine lavoro nel banner `#qrConsegnaCard` con credenziali, profilo, Wi-Fi negozio e seriale Mac | Pari (libreria `QRCode` integrata) |
| **Annuncio Vocale Fine Lavoro** | `Beep-Completato` con sintesi vocale asincrona SAPI (`SAPI.SpVoice`) in italiano | `beep_completato_mac` con sintesi vocale nativa (`say -v Alice`) in background | Pari |
| **Espulsione Sicura Chiavetta USB** | `Eject-ChiavettaUSB` (rilascio directory e unmount via COM `Shell.Application`) | `eject_chiavetta_mac` (rilascio directory e `diskutil eject`) | Pari |
| **Kit Offline Standalone** | `tools/Scarica-Pacchetti-Offline.bat` (`-PreparaUSB`, salva installer in `installers/`) | `tools/Scarica-Pacchetti-Offline.command` (`--prepara-usb`, salva installer in `installers/mac/`) | Pari |
| **Dongle Hardware Zero-Clic** | `dongle/code.py` (RP2040 HID per avvio istantaneo via `Win+R`) | `dongle/code.py` (RP2040 HID per avvio istantaneo via Spotlight/Terminale) | Pari (supporto universale) |
| **Unieuro Everyday Digital** | Card con Script Vendita (30s) nel pannello, nota QR consegna e box promozionale famiglia (10 smartphone/tablet) nella Scheda Consegna PDF | Card con Script Vendita (30s) nel pannello, nota QR consegna e box promozionale famiglia (10 smartphone/tablet) nella Scheda Consegna PDF | Pari |



