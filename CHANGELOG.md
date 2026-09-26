# Changelog

Formato ispirato a [Keep a Changelog](https://keepachangelog.com/it/1.1.0/).

## [Unreleased]

### Modificato — solo PDF sul Desktop
- A fine lavoro sul Desktop del cliente resta **solo** `Scheda-Consegna-Cliente.pdf`.
  L'HTML si genera in `C:\ProgramData\PCFacile\consegna`, Edge headless (profilo
  temporaneo, senza intestazioni) lo converte e, solo se il PDF esiste ed è
  > 0 byte, l'HTML viene cancellato. Se il PDF fallisce resta sul Desktop
  l'HTML come ripiego. `Riepilogo-Configurazione-PC.txt` non va più sul Desktop
  (anche quello lasciato da versioni precedenti viene tolto): il riepilogo è in
  `C:\ProgramData\PCFacile\log\riepilogo-tecnico.txt`, ora senza password né
  recovery key BitLocker. Antivirus / Cyber Protection attivati compaiono
  nella scheda.
- Niente più `NON CANCELLARE - Chiave di Ripristino BitLocker.txt` sul Desktop:
  la chiave è solo nella scheda PDF, in un riquadro rosso "Conserva questa
  chiave" subito sotto le credenziali. La copia lasciata da versioni precedenti
  viene tolta (tranne se la chiave non è stata letta in questa sessione). La
  chiave non va mai nei log.

### Modificato — avvio unico
- **Un solo modo di avvio**: doppio click su `PC Facile.bat` → McAfee →
  auto-aggiornamento → fase 1 subito → pannello locale aperto dallo script dove
  si inseriscono una volta i dati del cliente → fase 2 e 3. Office è l'ultimo
  passo della fase 1 (il primo che usa i dati); i passi manuali leggono tutto
  dal pannello (nessuna domanda in console). Ripresa automatica con i dati del
  cliente nel checkpoint (Schema 3).
- Pannello: scelta Office (nessuna / Microsoft 365 / perpetuo / LibreOffice) e
  profilo programmi; pulsante **CONFERMA DATI CLIENTE**.
- Mac: niente menu, stesso ordine (aggiornamenti per ultimi), dati dal pannello.

### Rimosso
- Menu iniziale (1 Zero-Touch, 2 Registrazione guidata/Agente IA, 3 Prepara USB,
  4 Check salute) e i parametri `-Espresso`/`-ZeroTouch`, `-Manuale`, `-Menu`,
  `-AgenteIA`, `-Migrazione`, `-Veloce`, `-skipRestore` (ora ignorati).
- Modulo `Invoke-BrowserAutoSignup` (Agente IA) e `Invoke-MigrazioneDati`.
- Pannello su GitHub Pages (`docs/index.html`, mai pubblicato): la sorgente è
  ora `pannello/pannello-operatore.html`; il server locale non accetta più
  l'origine GitHub Pages. Via anche "Scarica PC Facile.bat" e il comando Win+R.
- Canali dati alternativi: appunti `PCFACILE_CRED:`, file
  `pcfacile-cred*.json` in Download/Desktop/TEMP, file di stato
  `pcfacile-status.js`, prompt console a timeout. Resta solo HTTP locale (più un
  ripiego minimo in console se il pannello non si apre).

### Aggiunto
- Aggiornamento automatico della chiavetta: `manifest.txt` (file + SHA256) e
  modalità `setup-pc.ps1 -AggiornaUSB`, usata da `PC Facile.bat` a ogni avvio;
  equivalente in `PC Facile.command` per Mac. File sostituiti solo dopo la
  verifica SHA256; cartella `wifi` mai toccata; auto-aggiornamento sicuro del
  launcher tramite `PC Facile.bat.nuovo`.
- `tools/aggiorna-manifest.ps1` per rigenerare manifest e impronte; test Pester
  che impediscono al manifest di disallinearsi.
- *Prepara USB* usa il manifest (file verificati) invece dei download non
  verificati.
- Pannello operatore: server locale in background (runspace) che risponde
  sempre; `GET /status` restituisce avanzamento reale, fasi, hardware, seriale,
  versione e ora di avvio, così funziona anche il pannello su GitHub Pages.
  Stato "il PC aspetta i dati del cliente". Preflight con
  `Access-Control-Allow-Private-Network`.
- `tools/sincronizza-pannello.ps1` e test Pester: il pannello dentro
  `setup-pc.ps1` resta identico a `docs/index.html`.

### Modificato
- Pannello operatore (web, locale e Mac): un solo pulsante **AVVIA
  CONFIGURAZIONE**; lo script parte solo con dati confermati (`Conferma`,
  cognome, nome, servizi) e non più al primo tasto digitato. Esito vero
  dell'invio (ricevuto / rifiutato / PC non raggiunto), errori in rosso,
  campi senza dati di esempio, schermata iniziale onesta (0%, "Script non
  avviato"), tempo dall'avvio dello script, esito finale con elenco degli
  avvisi, layout adatto a mezzo schermo e telefono, pulsanti da almeno 44 px,
  etichette accessibili. Tolte le parti inutili (vedi PR).
- Il server locale accetta dati solo dal pannello ufficiale (GitHub Pages) o
  dal pannello aperto dallo script (`file://`).

### Corretto
- `PC Facile.bat`: se `setup-pc.ps1.sha256` non si scarica il download viene
  scartato (prima veniva eseguito senza verifica); la copia sulla chiavetta si
  aggiorna solo dopo una verifica riuscita.
- `PC Facile.bat`: argomenti utente ricostruiti correttamente dopo l'elevazione
  (il marcatore interno `elevated` non arriva più allo script); controllo
  Internet via HTTP con fallback invece del solo ping a 8.8.8.8.
- `PC Facile.bat` salvato con fine riga CRLF anche nel repository
  (`.gitattributes`: `*.bat -text`), così GitHub raw serve un .bat valido.
- Connessione Wi-Fi da `wifi.txt`/`wifi.ini`/`wifi.conf` in `setup-pc.ps1`
  (array di `Join-Path` errato: falliva sempre in silenzio).
- Pannello operatore (web e locale): la sincronizzazione automatica non
  partiva (`telefono` non definito); pulsante "Scarica PC Facile.bat" ora
  scarica davvero il file; comando Win+R corretto e sotto il limite della
  finestra Esegui.
- Escape HTML/XML/sed dei valori inseriti nel pannello, nella scheda di
  consegna Mac e nei profili Wi-Fi.
- Pulizia: file credenziali `pcfacile-cred*.json` e pannelli temporanei con la
  password cancellati; impostazioni della console (colori/font) ripristinate
  dal backup originale a fine lavoro.
- `setup-mac.sh`: rimosso `eval` sui dati letti dal pannello.
- `PC Facile.command`: file temporaneo con `mktemp` e verifica SHA256 tramite
  il nuovo `setup-mac.sh.sha256` (controllato dai test Pester in CI).

### Aggiunto
- Licenza MIT (`LICENSE.md`).
- Template GitHub per bug report, feature request e pull request.
- Runbook release manuale in `docs/RELEASE.md`.

### Da automatizzare quando il permesso `workflow` sarà attivo
- Generazione changelog da commit/PR.
- Release GitHub con artifact `setup-pc.ps1`, `setup-pc.ps1.sha256` e launcher.
