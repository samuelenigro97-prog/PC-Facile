# PC Facile — `setup-pc.ps1`

Script PowerShell per configurare i PC Windows dei clienti (negozio informatica):
lingua italiana, nome cliente, Office, antivirus/protezione, browser, app base,
con **report finale** degli esiti.

---

## 0. Prima di Iniziare — Lingua in Italiano

I PC installati da chiavetta USB spesso saltano la scelta lingua e partono in
**inglese**. Lo **STEP 0** dello script imposta tutto in `it-IT` (display, formati,
tastiera, language pack). La lingua di **sistema** si applica del tutto **dopo il
riavvio**.

> Se preferisci farlo a mano prima: Impostazioni → Ora e lingua → Lingua e area
> geografica → aggiungi **Italiano (Italia)** e impostalo come predefinito.

---

## 1. Web App Online & Download Launcher

Puoi accedere alla **Web App Unificata** da qualsiasi computer o browser di negozio:
👉 **[https://samuelenigro97-prog.github.io/pc-facile/](https://samuelenigro97-prog.github.io/pc-facile/)**

Dalla Web App puoi:
- Inserire i dati del cliente (cognome, nome, cellulare, servizi sullo scontrino): email e password si propongono da sole.
- Premere **AVVIA CONFIGURAZIONE**: è l'unico pulsante che manda i dati al PC. Lo script parte (o aggiorna i dati) solo dopo questo clic, e il pannello dice se il PC li ha davvero ricevuti.
- Seguire l'avanzamento reale (fasi, percentuale, tempo dall'avvio, hardware e seriale del PC) anche dalla pagina su GitHub, aperta **sul PC da configurare**.
- Vedere a fine lavoro se ci sono avvisi da controllare prima della consegna.
- Accedere ai portali di attivazione (Microsoft, Office 365, McAfee, Norton, Covercare).
- Scaricare al volo **`PC Facile.bat`** se lo script non è ancora avviato.

> Il pannello parla con lo script tramite un piccolo server locale (`127.0.0.1:8899`, raggiungibile solo dal PC stesso) che accetta dati solo dal pannello ufficiale su GitHub Pages o dalla pagina aperta dallo script. Se il browser chiede il permesso di accedere ai dispositivi della rete locale, rispondi **Consenti**.

Ti basta **UN file**: `PC Facile.bat`.

```
https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main/PC%20Facile.bat
```

Tasto destro → **Salva con nome** → `PC Facile.bat`.
⚠️ Verifica che finisca in `.bat` e **non** `.bat.txt`.

`PC Facile.bat` da solo scarica ed esegue l'ultima versione dello script da GitHub
(serve Internet — sui PC da configurare c'è, serve anche per winget).

Il launcher scarica **sempre l'ultima versione** da GitHub, così è aggiornato da
solo (niente copie vecchie sulla chiavetta).

**Chiavetta sempre aggiornata (automatico):** a ogni avvio con Internet,
`PC Facile.bat` (e su Mac `PC Facile.command`) scarica `manifest.txt` da GitHub
e aggiorna sulla chiavetta **tutti** i file di PC Facile (`setup-pc.ps1`,
`PC Facile.bat`, `PC Facile.command`, `setup-mac.sh`, le impronte `.sha256`,
`LEGGIMI.md` e i file Wi-Fi del negozio `wifi/wifi.txt` e
`wifi/UNIEURO_EXPO.xml`). Ogni file viene verificato con lo **SHA256** del manifest prima di
sostituire la copia; se qualcosa non va (offline, download interrotto, hash
diverso) restano i file già presenti e il lavoro prosegue normalmente.
- Nella cartella `wifi` vengono scritti **solo** `wifi.txt` e `UNIEURO_EXPO.xml`
  (presi dal repository): per cambiare la rete del negozio modificali su GitHub,
  altrimenti una modifica fatta solo sulla chiavetta verrà sovrascritta al
  prossimo avvio. Gli altri file di `wifi` non vengono mai toccati.
- Il launcher non può sostituire sé stesso mentre gira: la nuova versione viene
  salvata come `PC Facile.bat.nuovo` e messa al suo posto a fine esecuzione (o
  al prossimo avvio, se chiudi la finestra prima).
- Chiavette con un `PC Facile.bat` **vecchio** (senza auto-aggiornamento): al
  primo avvio lo script aggiorna comunque i file e sostituisce il launcher
  appena si chiude la sua finestra; dal giro successivo parte quello nuovo.
- L'aggiornamento avviene solo su una chiavetta (disco rimovibile) o in una
  cartella che contiene già `setup-pc.ps1`; non quando il .bat è lanciato da
  `%TEMP%` (comando Win+R).
- Il manifest arriva dallo stesso repository dei file: protegge da download
  corrotti o troncati, **non** da una manomissione del repository.

**Uso OFFLINE (fallback):** per preparare una chiavetta nuova basta copiarci
`PC Facile.bat` e avviarlo una volta con Internet (oppure usare l'opzione
*Prepara USB*): da lì in poi i file restano aggiornati da soli. Senza Internet il
launcher usa la copia di `setup-pc.ps1` già presente sulla chiavetta.
```
https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main/setup-pc.ps1
```

---

## 2. Avvio FACILE (Consigliato) — Doppio Click

**Doppio click su `PC Facile.bat`.** Fa tutto da solo:
- chiede i privilegi di amministratore (UAC → *Sì*)
- scarica ed esegue l'ultima versione da GitHub (con fallback offline su chiavetta)
- avvia con ExecutionPolicy Bypass ed esegue la **Configurazione Automatica Parallela**:
  1. **PARTE SUBITO**: senza pause o questionari, la console inizia con antivirus di prova, lingua italiana, Office e app; poi i passi manuali (con la pulizia in background) e per ultimi driver e aggiornamenti.
  2. **NEL FRATTEMPO LAVORI TU**: apre in parallelo nel browser il **Pannello Operatore Tecnico** con:
      - 🔑 Credenziali cliente generate con pulsanti **Copia Email** e **Copia Password** a 1 click.
      - 🌐 Accesso rapido ai portali: Account Microsoft, Riscatto Office 365 (`microsoft365.com/setup`), Attivazione McAfee/Norton e Unieuro Cyber Protection.
      - ⚡ Monitoraggio live delle fasi e un suono a lavoro finito.
  3. **CONSEGNA PRONTA**: genera sul Desktop la **Scheda Consegna Cliente HTML**, il promemoria **`NON CANCELLARE - Chiave di Ripristino BitLocker.txt`** e suona a lavoro ultimato.

> **Consiglio per il banco:** La prima volta che crei la chiavetta USB, avvia con il parametro `-PreparaUSB` (o da menu con `-Menu`): scaricherà tutti i programmi (Chrome, VLC, Adobe Reader, 7-Zip, AnyDesk, Zoom, LibreOffice, tool rimozione AV) direttamente nella cartella `installers` della USB. Così i successivi PC dei clienti si installeranno al **100% OFFLINE** e in pochissimi minuti!

---

## 2-bis. Avvio Manuale da PowerShell o con Parametri

Apri **Windows PowerShell** come Amministratore e usa questi comandi:

```powershell
# CONFIGURAZIONE AUTOMATICA PARALLELA (Standard / Default)
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main/setup-pc.ps1)))

# MENU AVANZATO UTILITY (scelta manuale tra opzioni)
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main/setup-pc.ps1))) -Menu

# TRASFERIMENTO DATI DA VECCHIO PC / DISCO USB
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main/setup-pc.ps1))) -Migrazione

# PREPARA USB OFFLINE (scarica i pacchetti sulla chiavetta)
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main/setup-pc.ps1))) -PreparaUSB

# DIAGNOSTICA (controlla ID pacchetti e ambiente, NON installa)
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main/setup-pc.ps1))) -Diagnostica

# TEST a vuoto (simulazione completa senza modifiche)
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main/setup-pc.ps1))) -Test
```

Se invece hai il file salvato e vuoi lanciarlo da file:
```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\Desktop\setup-pc.ps1"
```

> ⚠️ **Perché l'errore "esecuzione disabilitata"?** Windows blocca i file `.ps1`
> di default. Eseguire come scriptblock in memoria (comandi sopra) o con
> `-ExecutionPolicy Bypass` lo evita. Lo script non puo' risolverlo da dentro:
> il blocco avviene PRIMA che parta.
>
> **Nota percorso:** usa `$env:USERPROFILE` (es. `C:\Users\telef`) — NON un nome
> utente fisso come `oem`. Ogni PC ha un profilo diverso.

---

## 3. Se lo Script NON Parte Proprio (Smart App Control)

Su alcuni PC il **Controllo intelligente delle app** (Smart App Control) blocca il
`.ps1` scaricato da Internet **senza** dare l'opzione "Esegui comunque".

Per disattivarlo:

**Sicurezza di Windows → Controllo app e browser → Controllo intelligente delle app → Disattivato**

> ⚠️ **IRREVERSIBILE:** una volta disattivato, Smart App Control **non si può più
> riattivare** senza reinstallare/resettare Windows. Valuta se il cliente lo vuole
> davvero spento. In alternativa, prepara lo script da una fonte considerata
> attendibile (es. copialo da chiavetta invece di scaricarlo).

Lo script, se riesce a partire, rileva da solo Smart App Control attivo e ti avvisa.

---

## 4. Cosa Fa lo Script (in Ordine)

All'avvio lo script esegue alcuni **controlli**: privilegi admin, blocchi Windows
(Smart App Control/ExecutionPolicy), versione Windows/PowerShell, **riavvio in
sospeso**, **spazio disco**, **preflight di rete** (GitHub/Microsoft/CDN winget),
sincronizza l'**orologio** ed evita che il PC vada in **sospensione**.

Tre fasi, sempre in quest'ordine. **Ogni passo prima controlla se il suo lavoro
c'è già** (es. antivirus installato a mano, Windows già in italiano, Office già
attivato, app già presenti) e in quel caso lo **salta**, segnandolo "già fatto" in
console, nel pannello e nel riepilogo.

| Step | Azione |
|------|--------|
| **Fase 1** | **Programmi e lingua (automatico)** |
| 1  | **Punto di ripristino** (opzionale): rete di sicurezza prima delle modifiche. *Salta se già creato oggi* |
| 2  | **Rimozione antivirus di prova** (prima delle installazioni, così non le bloccano). Non tocca l'antivirus della card scelta nel pannello. *Salta se non ce ne sono* |
| 3  | Lingua/regione **Italiano (it-IT)** + tastiera + language pack + propagazione a login/nuovi utenti. *Salta se Windows è già tutto in italiano* |
| 4  | **Office: installazione** della suite scelta se manca (Office 365, perpetuo, OpenOffice, LibreOffice) + Visual C++ (*saltato se già presente*) + collegamenti Office sul Desktop |
| 5  | **App + browser**: scegli il profilo e il **browser si installa da solo** — **Chrome** per tutti, **Opera GX** se scegli GAMING. *Le app già installate si saltano* |
| **Fase 2** | **Passi manuali dell'operatore** — intanto la **pulizia gira in background** |
| 6  | **Nome cliente** (nome visualizzato dell'account **e** nome del PC): genera anche le credenziali suggerite |
| 7  | **Account cliente** (col cliente davanti): login/registrazione; genera o annota email + password `Nome123!` nel riepilogo |
| 8  | **Office: attivazione** con la card PIN (`microsoft365.com/setup` o `office.com/setup`) + accesso in Word. *Salta se Office è già attivato* |
| 9  | **Antivirus**: McAfee, Norton o Salta. *Se un antivirus è già installato (Centro sicurezza di Windows o programmi installati) il passo si salta: "già installato"* |
| 10 | **Unieuro Cyber Protection** (opzionale) — solo sito + credenziali app |
| **Fase 3** | **Pulizia, driver e aggiornamenti (automatico)** |
| 11 | **Pulizia e ottimizzazione** (partita in background nella fase 2, qui si attende la fine): bloatware OEM, promo dal menu Start, avvio automatico, OneDrive, **privacy**, piccole comodità Windows |
| 12 | **Driver**: scheda video dedicata (tool del produttore) + driver generici da Windows Update |
| 13 | **Aggiornamenti — sempre per ultimi**: app (`winget upgrade --all`), app del **Microsoft Store**, e **Windows Update** (scaricati in background, installati a fine lavoro prima del riavvio) |
| —  | **Report finale & Consegna**: verifica finale + diagnostica **Salute SSD (SMART)**, **Salute Batteria** (notebook) e **Licenza Windows** + generazione file **`NON CANCELLARE - Chiave di Ripristino BitLocker.txt`** (se crittografato) + **Scheda Consegna Cliente HTML** stampabile + riavvio |

**Profili app** (browser incluso: Chrome, o Opera GX per GAMING):
- **BASE** — VLC, Adobe Reader, 7-Zip, WhatsApp, Spotify, Zoom, AnyDesk
- **UFFICIO** — BASE + GIMP, Sumatra PDF
- **GAMING** — BASE + Steam, Epic, Discord
- **COMPLETO** — tutte · **MANUALE** — scegli i singoli numeri

**Driver scheda video**: la ricerca di Windows Update spesso non prende il driver
video giusto. Perciò, se lo script rileva una GPU **dedicata**, usa il tool del
produttore: **NVIDIA** → app NVIDIA; **Intel Arc** → Intel Driver & Support
Assistant; **AMD dedicata** (Radeon RX/Pro) → apre `amd.com/it/support`. Con la
**sola grafica integrata** (Intel HD/UHD/Iris, Radeon dei Ryzen) non installa
nulla di extra: ci pensa Windows Update.

Antivirus **Norton/McAfee**: lo script apre il sito, tu registri e scarichi
l'installer (nome variabile) → lo script trova l'`.exe` più recente in **Download o
Desktop** e lo avvia.
**Unieuro Cyber Protection**: solo apertura sito + promemoria di annotare le
credenziali per l'app mobile del cliente (nessun installer PC).

**Ripresa sessione**: se lo script si chiude a metà (crash, riavvio, blocco
antivirus), al lancio successivo propone di **riprendere da dove eri arrivato**:
i passi già completati vengono saltati. Il checkpoint si cancella da solo a
lavoro finito. Un checkpoint salvato da una versione precedente (con un altro
ordine dei passi) riparte dal primo passo: i lavori già fatti si saltano da soli.

**Collegamenti sul Desktop**: dopo l'installazione di Office lo script crea i
collegamenti a **Word, Excel, PowerPoint, Outlook e OneNote**; inoltre mette sul
Desktop l'icona di **ogni app installata** (browser e app dei profili: VLC,
7-Zip, WhatsApp, TeamViewer, ecc.), così il cliente vede a colpo d'occhio cosa è
stato installato.

La pulizia toglie anche i **collegamenti promo dal menu Start** (Booking.com,
"Offerte Adobe", HP Documentation).

**Comodità durante l'uso** (valgono per tutto lo script):
- **Prevenzione Standby**: durante tutto il setup e gli aggiornamenti Windows Update,
  lo script impedisce lo spegnimento dello schermo e la sospensione automatica.
- **Barra di avanzamento**: durante ogni download/installazione una barra animata
  con i secondi mostra che sta lavorando (l'output tecnico resta nascosto).
- **Bip di richiamo**: quando lo script aspetta una tua risposta fa un bip; se non
  rispondi entro 2 minuti inizia a bipare in modo ricorrente (discreto) finché non
  riprendi, così te ne accorgi se ti sei allontanato.
- **Edge senza schermate iniziali** (benvenuto, accesso, import) e senza barra
  laterale/Copilot, Rewards, assistente acquisti.

Alla fine, se hai cambiato la lingua, lo script **propone il riavvio** (serve per
applicare display language e schermata di login).

All'avvio lo script fa un **preflight di rete**: controlla se GitHub, Microsoft e il
CDN winget sono raggiungibili e avvisa subito se la rete (aziendale/proxy) blocca
qualcosa.

---

## 4-bis. Rete Aziendale / con Firewall o Proxy

I PC nuovi **non sono nel dominio** aziendale: usano solo la connessione. Le policy
aziendali (Group Policy, AppLocker) **non** si applicano al PC fresco. Il rischio è
solo che il **firewall/proxy blocchi i download**:

- **GitHub bloccato** → usa la modalità **offline**: tieni `setup-pc.ps1` accanto ad
  `PC Facile.bat` (niente download).
- **Winget/CDN Microsoft bloccati** → le app non si installano (il report lo segnala).
  Rimedio: **hotspot del telefono** per la fase installazioni, o installa dopo su rete
  senza filtri.
- **Proxy con login** → i download automatici possono fallire; usa hotspot.

Il preflight all'avvio ti dice **subito** cosa è raggiungibile, così non scopri il
blocco a metà lavoro.

---

## 5. File Generati (Log e Report)

Al termine, sul **Desktop** trovi due file datati:

- `setup-pc_log_<data>.txt` — log completo di tutta la sessione (prova di cosa è
  stato fatto su quel PC).
- `setup-pc_report_<data>.txt` — riepilogo pulito degli esiti (OK / ERRORE / SALTATO).

Utili da archiviare o allegare alla scheda cliente.

---

## 6. Compatibilità Windows 10 / 11

| | Windows 11 | Windows 10 |
|---|---|---|
| Lingua base (tastiera, formati, regione) | ✅ | ✅ |
| Language pack automatico (`Install-Language`) | ✅ | ❌ solo Win11 — su Win10 lo script apre Impostazioni lingua per aggiungerlo a mano |
| Lingua di sistema/login/nuovi utenti (`Copy-UserInternationalSettingsToSystem`) | ✅ | ❌ solo Win11 |
| Rilevamento Smart App Control | ✅ | non presente (ignorato) |
| Office, antivirus, browser, app (winget) | ✅ | ✅ (serve "App Installer" dallo Store) |

Le parti solo-Win11 sono protette da controllo: su Windows 10 vengono **saltate senza
errori**, il resto funziona.

---

## 7. Prima Prova Sicura (Dry-Run)

Per vedere il flusso senza installare nulla, rispondi:
Punto di ripristino `N` · STEP 0 `N` · STEP 2 `N` · STEP 3 `4` poi attivazione
perpetuo `N` · STEP 4 `3` · STEP 4c `N` · Browser `N`/`N` · STEP 6 `S`.
Arrivi al report finale senza toccare il PC.
