# Parità Windows / Mac — PC Facile

Regola: **una modifica a una versione va replicata sull'altra.** Questa tabella
è la mappa. `setup-pc.ps1` (Windows) e `setup-mac.sh` (Mac) devono restare
allineati come flusso e funzioni.

| Passo / funzione            | Windows (`setup-pc.ps1`)                  | Mac (`setup-mac.sh`)                          | Note |
|-----------------------------|-------------------------------------------|-----------------------------------------------|------|
| Avvio unico (no menu)       | doppio click `PC Facile.bat` = configura; `-Test` solo CI, `-PreparaUSB`/`-Diagnostica` manutenzione | doppio click `PC Facile.command` = configura; `--test` solo CI, `--diagnostica` manutenzione | pari |
| Dati cliente (una volta)    | pannello locale → server `127.0.0.1:8899` (pulsante `AVVIA INSTALLAZIONE`, dati facoltativi non bloccanti); console solo se il pannello non si apre | pannello locale → file `pcfacile-cred.json` in Download (pulsante `AVVIA INSTALLAZIONE`, dati facoltativi non bloccanti); INVIO = default in console | canale diverso per limite tecnico |
| Ordine                      | fase 1 app+lingua (+Office) · fase 2 manuali · fase 3 pulizia/driver/aggiornamenti per ultimi | fase 1 lingua/app · fase 2 nome+account/servizi · fase 3 aggiornamenti per ultimi | pari |
| Lingua italiana             | `Install-Language it-IT -CopyToSettings`  | `defaults write AppleLanguages/AppleLocale`   | pari |
| Sincronizzazione orario     | `w32tm` + W32Time auto + tzautoupdate     | `systemsetup -setusingnetworktime on` + sntp  | pari |
| Nome cliente + host         | `Set-LocalUser` + `Rename-Computer`       | `scutil --set ComputerName/HostName`          | pari |
| Punto di ripristino         | `Checkpoint-Computer`                     | `tmutil localsnapshot` (Time Machine)         | pari |
| Account + credenziali       | Apre account.microsoft.com, genera cred   | Apre appleid.apple.com, genera cred           | pari |
| Office                      | installa (winget) + riscatto card PIN sul web | — (su Mac Office si scarica da web, opzionale)| solo Win |
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
| Pannello Operatore Web      | 3 schede (Cliente, Avanzamento con 13 task live, Portali) + pulsante `AVVIA INSTALLAZIONE` (dati opzionali con fallback) + timer `MM:SS` + chime | 3 schede (Cliente, Avanzamento con 12 task live, Portali) + pulsante `AVVIA INSTALLAZIONE` (dati opzionali con fallback) + timer `MM:SS` + chime | pari |
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

## Solo Mac (Non Esiste su Windows)
- **Rosetta 2** su Apple Silicon (arm64): serve a far girare le app solo-Intel.
