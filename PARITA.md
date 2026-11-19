# Parità Windows / Mac — PC Facile

Regola: **una modifica a una versione va replicata sull'altra.** Questa tabella
è la mappa. `setup-pc.ps1` (Windows) e `setup-mac.sh` (Mac) devono restare
allineati come flusso e funzioni.

| Passo / funzione            | Windows (`setup-pc.ps1`)                  | Mac (`setup-mac.sh`)                          | Note |
|-----------------------------|-------------------------------------------|-----------------------------------------------|------|
| Avvio unico (no menu)       | doppio click `PC Facile.bat` = configura; `-Test` solo CI, `-PreparaUSB`/`-Diagnostica` manutenzione | doppio click `PC Facile.command` = configura; `--test` solo CI, `--diagnostica` manutenzione | pari |
| Dati cliente (una volta)    | pannello locale → server `127.0.0.1:8899` (unico canale); console solo se il pannello non si apre | pannello locale → file `pcfacile-cred.json` in Download (zsh non ha un server HTTP) ; INVIO = nome in console | canale diverso per limite tecnico |
| Ordine                      | fase 1 dati cliente, Office e attivazioni · fase 2 lingua, app, pulizia, driver e aggiornamenti (automatico fino alla fine) | fase 1 dati cliente, nome e servizi · fase 2 lingua, app e aggiornamenti (automatico fino alla fine) | pari |
| Lingua italiana             | `Install-Language it-IT -CopyToSettings`  | `defaults write AppleLanguages/AppleLocale`   | pari |
| Sincronizzazione orario     | `w32tm` + W32Time auto + tzautoupdate     | `systemsetup -setusingnetworktime on` + sntp  | pari |
| Nome cliente + host         | `Set-NomeUtenteEPc` (`Set-LocalUser` + `ADSI` + pulizia cache `LogonUI` + `Rename-Computer`, sanitizza `clt clt` → `Utente`/`PC-Utente`) | `imposta_nome_mac` (`scutil --set ComputerName/HostName`, sanitizza `clt clt` → `Mac`) | pari |
| Scheda Passaggi singoli     | Scheda `4. Passaggi` nel pannello operatore (`POST /step`): ripete qualsiasi passo `1..13` nell'ordine o cambia subito Nome Utente/PC | Scheda `3. Passaggi` nel pannello operatore (`pcfacile-step.json`): ripete i passi `1..8` nell'ordine o cambia subito Nome Mac | pari |
| Punto di ripristino         | `Checkpoint-Computer`                     | `tmutil localsnapshot` (Time Machine)         | pari |
| Account + credenziali       | Apre account.microsoft.com, genera cred   | Apre appleid.apple.com, genera cred           | pari |
| Office                      | installa (winget) + riscatto card PIN sul web | — (su Mac Office si scarica da web, opzionale)| solo Win |
| Pulizia / ottimizzazione    | AV prova + debloat OEM + config Windows   | config `defaults` (no debloat OEM: non esiste)| Mac = solo config |
| Antivirus                   | McAfee/Norton                             | — (raramente su Mac; skip)                    | solo Win |
| Unieuro Cyber Protection    | apre portale                              | apre portale (uguale)                         | pari |
| Browser                     | catalogo winget                           | cask brew                                     | pari |
| App (BASE/UFFICIO/GAMING)   | winget + tool GPU se dedicata (NVIDIA/Intel Arc/AMD) | brew cask (Mac: GPU integrata) | pari |
| Errori gestore app          | codice winget propagato via `cmd.exe`, riparazione sorgenti su errore certificato | codice uscita nativo di Homebrew | specifico per gestore |
| Aggiornamenti               | `winget upgrade` + aggiornamenti sicurezza Windows (COM Microsoft.Update) + driver Windows Update | `brew upgrade` + `softwareupdate` | pari |
| Chiave di ripristino disco  | **BitLocker** (`manage-bde`/cmdlet)       | **FileVault** (`fdesetup`)                    | pari |
| Barra attesa download/install| `Start-BarraAnimata` / `Stop-BarraAnimata` (winget in Start-Process) | — (brew mostra gia' il progresso)             | solo Win |
| Avviso sonoro fine passo    | `[console]::Beep`                         | `printf '\a'`                                 | pari |
| Bip di richiamo se non rispondi| runspace: dopo 2 min bip corto ogni ~4s | —                                             | solo Win |
| Credenziali (esist./gen.)   | `Nome123!` + `Set-Clipboard`              | `Nome123!` + `pbcopy`                         | pari |
| Report finale / Scheda      | Desktop solo `Scheda-Consegna-Cliente.pdf` (ripiego `.html` se il PDF fallisce); riepilogo tecnico in `C:\ProgramData\PCFacile\log` | Desktop solo `Scheda-Consegna-Mac.html` | pari (un solo file sul Desktop; su Mac niente PDF automatico) |
| Assist credenziali pagine   | copia email/password negli appunti quando apre Cyber Protection/antivirus | — | solo Win |
| Pulizia finale (auto-elimina)| rimuove `%TEMP%\setup-pc.ps1` + reg colori + checkpoint | `rm` dello script scaricato in `/tmp` | pari |
| Ripresa sessione interrotta | checkpoint JSON in `ProgramData\PCFacile` (anche fine dentro il passo App: profilo + app gia' fatte) | —          | solo Win |
| Collegamenti Office Desktop | WScript.Shell dopo installazione Office   | —                                             | solo Win |
| Icona Desktop per ogni app  | copia lnk da Start / shell:AppsFolder     | —                                             | solo Win |
| Errori: rete di sicurezza   | `trap` a livello script + lista imprevisti | (`set -e` / trap shell)                       | solo Win (per ora) |
| Log strutturato             | JSON + CSV in `ProgramData\PCFacile\log`  | — (TODO)                                       | solo Win (per ora) |

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
- **Soppressione Schermata Benvenuto Edge (FRE) e popup widget**: disabilitazione policy HKLM/HKCU, file sentinella First Run, modalita' app `--app` e disattivazione widget Windows 11 / Bing (su Mac Safari/Chrome non hanno questo blocco).
- **Auto-aggiornamento USB affidabile con attesa Wi-Fi**: loop di attesa connessione Internet fino a 15s in `PC Facile.bat`, chiusura automatica dopo 5s del prompt UAC non concesso e aggiornamento automatico dei file della chiavetta USB appena la rete e' attiva.
- **Leggibilità console e zero riavvio AV**: `Reset-ConsoleMode` (rimuove `DISABLE_NEWLINE_AUTO_RETURN` lasciato da `winget`), barre titolo adattive a metà schermo, soppressione barra blu `Install-Language` e nessun prompt di riavvio dopo rimozione McAfee in `PC Facile.bat`.
- **Campi cliente tutti opzionali (Win & Mac)**: `Nome`, `Cognome` e `Cellulare` sono sempre facoltativi (anche con Cyber Protection); se lasciati vuoti, la configurazione prosegue e termina come `Utente`.
- **Avviso immediato fine ultima procedura (Win & Mac — v13.5.5)**: al termine dell'ultima procedura (dopo l'ultimo Windows Update su Windows e dopo l'ultimo passo su Mac), entrambi gli script mostrano subito il messaggio esplicito `TUTTE LE PROCEDURE SONO TERMINATE: CONFIGURAZIONE COMPLETATA AL 100%!` e riproducono il segnale acustico (`Beep-Completato` + titolo finestra + Pannello Operatore al 100% su Windows, `\a` su Mac) prima di attendere al menu `Scelta (1-3)`.
- **Ordine passi: Lingua per prima e Dati cliente per ultimi (Win & Mac — v13.5.6)**: in entrambi gli script il cambio lingua (`Lingua e regione` / `Lingua e Regione`) e' il **primo** passo in assoluto; seguono nello stesso ordine tutti i passi automatici (ripristino, rimozione AV prova, app, pulizia, driver, aggiornamenti) e solo **per ultimi** vengono chiesti i dati del cliente (`Wait-DatiCliente` / `attendi_credenziali_mac`) con Office, nome PC/Mac, account, antivirus e Cyber Protection.
- **Avvio 100% automatico senza pause/McAfee e zero errori spuri Winget (Solo Windows — v13.5.7)**: `PC Facile.bat` rimuove McAfee in modalita' silenziosa automatica senza mai fermarsi su `pause` o chiedere di premere Invio; `setup-pc.ps1` imposta `$ProgressPreference = 'SilentlyContinue'` dall'inizio, evita interrogazioni `msstore` non necessarie (`0x8a15005e`), propaga sempre l'ExitCode in `Invoke-WingetConBarra` e gestisce `1618` con attesa di 10s prima del retry.
- **Chiavetta USB rimossa durante l'esecuzione (Solo Windows — v13.5.8)**: `Get-OfflineDirs` verifica l'esistenza del percorso prima di comporlo con `[System.IO.Path]::Combine` evitando l'errore `Join-Path : Cannot find drive 'D'` se la chiavetta viene scollegata a script avviato.
- **Dati cliente mai obbligatori nemmeno a fine script (Win & Mac — v13.5.9)**: `Wait-DatiCliente` (Windows) e `attendi_credenziali_mac` (Mac) attendono al massimo 30 secondi (o INVIO) e poi proseguono e completano automaticamente la configurazione come `Utente` se non sono stati inseriti dati nel pannello.
- **Fallback diretto Spotify non elevato (Solo Windows — v13.5.10)**: se `winget`/`msstore` falliscono per contesto Admin o errore certificato (`0x8a15005e`), `Installa-Pacchetto` scarica `SpotifyFullSetup.exe` da `download.scdn.co` e lo installa tramite Task Scheduler non elevato (`Install-SpotifyDirect`).
- **Fallback diretto universale per tutte le app (Solo Windows — v13.5.11)**: `Install-AppDirectFallback` copre Chrome, Firefox, VLC, Adobe Reader, SumatraPDF, Spotify, AIMP, 7-Zip, WhatsApp, AnyDesk, Zoom e LibreOffice scaricando gli installer ufficiali quando `winget`/`msstore` falliscono su reti con proxy/filtri SSL.
- **Riduzione al minimo dei tasti INVIO (Solo Windows — v13.5.12)**: `Installa-Antivirus` non blocca piu' prima del watcher download, `Attiva-ServizioWeb` rimuove la doppia conferma S/N, `Passo account` si salta automaticamente se i dati cliente non sono stati inseriti, la ripresa sessione scende a 5s e `INVIO` al menu finale esce subito.
- **Inversione Fase 1 e Fase 2 (Win & Mac — v13.6.0)**: in entrambi gli script e nel pannello operatore, la **Fase 1** esegue subito i passi con i dati del cliente (Office, nome PC/Mac, account, antivirus e Cyber Protection) e poi la **Fase 2** prosegue dritta in automatico (lingua, ripristino, rimozione AV prova, app, pulizia, driver e aggiornamenti) fino alla fine senza ulteriori interruzioni.
- **Unieuro Everyday Digital come Priorita' #1 (Win & Mac — v13.7.0)**: aggiunto **Unieuro Everyday Digital** (`Unieuro Secure / F-Secure` su `https://my.f-secure.com` + `Unieuro Cyber Protection` su `https://unieuro-cyber-protection.covercare.it`) come prima voce preselezionata nel pannello operatore e primo passo assoluto della Fase 1 su Windows e Mac (con avvio automatico dell'installer `.exe`/`.pkg`/`.dmg` appena scaricato o da USB offline, e protezione di `F-Secure` / `Unieuro Secure` in `Test-AvDaTenere`).
- **Connessione Wi-Fi immediata e rimozione silenziosa antivirus all'apertura (Solo Windows — v13.7.1)**: corretto `PC Facile.bat` (rimozione `>nul 2>&1` dentro PowerShell per `netsh wlan`) e estesa la disinstallazione silenziosa automatica iniziale senza conferme a tutti gli antivirus di prova preinstallati (`McAfee`, `Norton`, `Avast`, `AVG`).
- **Barra fissa in alto nel Pannello Operatore (Win & Mac — v13.8.0)**: l'intestazione con **Avanzamento configurazione** e le schede **1. Cliente / 2. Avanzamento / 3. Portali / 4. Passaggi** resta fissa (`position: sticky; top: 0`) scorrendo insieme all'operatore nelle varie sezioni.
- **Auto-allineamento post-connessione (Win & Mac — v13.9.0)**: dopo che il dispositivo si collega alla rete (`Connect-AutoWiFi`), `Invoke-SelfUpdateIfOutdated` (Windows) e il controllo SHA256 in `setup-mac.sh` (Mac) verificano se lo script in esecuzione è più vecchio di `main` su GitHub; in caso affermativo aggiornano automaticamente la chiavetta e si riavviano subito con l'ultima versione verificata.
- **Autoinstallazione diretta Unieuro Secure (Win & Mac — v13.10.0)**: `Invoke-EverydayDigital` (Windows) e `setup-mac.sh` (Mac) scaricano direttamente gli installer ufficiali F-Secure/Unieuro (`https://download.sp.f-secure.com/SE/Unieuro/installer/UnieuroSecure.exe` e `UnieuroSecure.mpkg`) e li avviano automaticamente senza passare manualmente dal portale (con fallback su `https://safeavenue.f-secure.com/iframe/-installers/unieuro/`).
- **Rilevamento completo `clt clt` / `clt` nel Pannello (Win & Mac — v13.10.1)**: `isCltNome` riconosce `clt` / `clt clt` anche se digitato in un solo campo (es. solo Cognome), azzerando sempre email e password e proseguendo senza conferme.

## Solo Mac (Non Esiste su Windows)
- **Rosetta 2** su Apple Silicon (arm64): serve a far girare le app solo-Intel.
