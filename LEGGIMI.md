# PC Facile — `setup-pc.ps1`

Script PowerShell per configurare i PC Windows dei clienti (negozio informatica):
lingua italiana, nome cliente, Office, antivirus/protezione, browser, app base,
con **report finale** degli esiti.

---

## 0. Prima di iniziare — Lingua in Italiano

I PC installati da chiavetta USB spesso saltano la scelta lingua e partono in
**inglese**. La **fase 1** dello script imposta tutto in `it-IT` (display, formati,
tastiera, language pack). La lingua di **sistema** si applica del tutto **dopo il
riavvio**.

> Se preferisci farlo a mano prima: Impostazioni → Ora e lingua → Lingua e area
> geografica → aggiungi **Italiano (Italia)** e impostalo come predefinito.

---

## 1. Un solo modo di avvio: doppio click su `PC Facile.bat`

C'è **un solo flusso**, sempre uguale, il più automatico possibile:

1. **Doppio click su `PC Facile.bat`** dalla chiavetta (UAC → *Sì*).
2. Se c'è **McAfee** il launcher lo fa rimuovere con i suoi strumenti ufficiali
   (altrimenti blocca lo script) e propone il riavvio.
3. **Auto-aggiornamento**: scarica l'ultima versione da GitHub (verificata SHA256)
   e aggiorna la chiavetta; senza Internet usa la copia sulla chiavetta.
4. Lo script **parte subito con la fase 1** (programmi e lingua), senza menu né domande.
5. Nello stesso momento **apre da solo il pannello operatore** (una pagina locale
   nel browser, a sinistra; la console resta a destra). Lì inserisci **una volta
   sola** i dati del cliente e i servizi sullo scontrino mentre la fase 1 lavora.
6. Poi la **fase 2** (passi manuali col cliente) e la **fase 3** (pulizia, driver,
   aggiornamenti per ultimi) proseguono con quei dati.

Niente altro da scegliere: non ci sono più menu, modalità alternative, pagine web
da aprire a mano o comandi da incollare.

### Il pannello operatore

- **Scheda Cliente**: cognome, nome, cellulare, tipo di email (email e password
  si propongono da sole, puoi modificarle), **Office** (nessuna card, card
  Microsoft 365, card Office 2024/2021, LibreOffice), **programmi** (Base, Ufficio,
  Gaming, Completo) e servizi (email Proton, card McAfee/Norton, Unieuro Cyber
  Protection). Premi **CONFERMA DATI CLIENTE**: il pannello dice se il PC li ha
  davvero ricevuti. Puoi correggerli e confermare di nuovo: valgono dal passo
  successivo.
- **Scheda Avanzamento**: fasi e passi in tempo reale, tempo dall'avvio,
  hardware e seriale, avvisi da controllare prima della consegna.
- **Scheda Portali**: link diretti a Microsoft, Office, McAfee, Norton, Covercare.

Se i dati non sono ancora arrivati quando servono (Office, ultimo passo della
fase 1, e poi i passi manuali), lo script si ferma, lo segnala nel pannello
("il PC aspetta i dati del cliente") e fa un bip di richiamo dopo 2 minuti.
Se hai chiuso il pannello, premi **P** nella console per riaprirlo.

> Il pannello parla con lo script **solo** tramite un piccolo server locale
> (`127.0.0.1:8899`, raggiungibile solo dal PC stesso), che accetta dati **solo**
> dalla pagina aperta dallo script: nessun sito web può inviarli. Se il browser
> chiede il permesso di accedere ai dispositivi della rete locale, rispondi
> **Consenti**. Solo se il pannello non si può aprire (porta occupata, browser
> assente) lo script chiede in console i dati essenziali (cognome, nome, Office,
> antivirus, Cyber Protection).

### La chiavetta

Ti basta **UN file**: `PC Facile.bat`.

```
https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main/PC%20Facile.bat
```

Tasto destro → **Salva con nome** → `PC Facile.bat` sulla chiavetta.
⚠️ Verifica che finisca in `.bat` e **non** `.bat.txt`.

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
  cartella che contiene già `setup-pc.ps1`.
- Il manifest arriva dallo stesso repository dei file: protegge da download
  corrotti o troncati, **non** da una manomissione del repository.

**Uso OFFLINE:** per preparare una chiavetta nuova basta copiarci
`PC Facile.bat` e avviarlo una volta con Internet: da lì in poi i file restano
aggiornati da soli. Senza Internet il launcher usa la copia di `setup-pc.ps1`
già presente sulla chiavetta.

---

## 2. Manutenzione (non per il flusso cliente)

Da usare solo per preparare/controllare la chiavetta, **non** sul PC del cliente.
Da un Prompt dei comandi aperto nella cartella della chiavetta:

```bat
REM Scarica gli installer offline nella cartella "installers" della chiavetta
"PC Facile.bat" -PreparaUSB

REM Controlla ambiente e ID dei pacchetti (NON installa nulla)
"PC Facile.bat" -Diagnostica
```

`-Test` (simulazione non interattiva e non distruttiva) esiste solo per la CI.
I parametri delle vecchie modalità (`-Menu`, `-Espresso`, `-Manuale`,
`-AgenteIA`, `-Migrazione`, `-Veloce`) vengono ignorati: il flusso è uno solo.

> ⚠️ **Perché l'errore "esecuzione disabilitata"?** Windows blocca i file `.ps1`
> di default: per questo si parte sempre da `PC Facile.bat`, che avvia lo script
> con `-ExecutionPolicy Bypass`. Lo script non può risolverlo da dentro: il
> blocco avviene PRIMA che parta.

---

## 3. Se lo script NON parte proprio (Smart App Control)

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

## 4. Cosa fa lo script (in ordine)

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
| **Fase 1** | **Programmi e lingua (automatico)** — intanto inserisci i dati del cliente nel pannello |
| 1  | **Punto di ripristino** (opzionale, di default saltato per risparmiare SSD). *Salta se già creato oggi* |
| 2  | **Rimozione antivirus di prova** (prima delle installazioni, così non le bloccano). Non tocca l'antivirus della card indicata nel pannello. *Salta se non ce ne sono* |
| 3  | Lingua/regione **Italiano (it-IT)** + tastiera + language pack + propagazione a login/nuovi utenti. *Salta se Windows è già tutto in italiano* |
| 4  | Visual C++ (*saltato se già presente*) + **App + browser** del profilo scelto nel pannello (**Base** se i dati non sono ancora arrivati; se poi arriva un profilo più ampio si aggiungono le app mancanti). **Chrome** per tutti, **Opera GX** con GAMING. *Le app già installate si saltano* |
| 5  | **Office: installazione** della suite indicata nel pannello (Microsoft 365 / perpetuo → app Microsoft 365; LibreOffice; nessuna) + collegamenti sul Desktop. È il primo passo che usa i dati del cliente: se non sono ancora arrivati, qui li aspetta |
| **Fase 2** | **Passi manuali dell'operatore** (con i dati del pannello) — intanto la **pulizia gira in background** |
| 6  | **Nome cliente** (nome visualizzato dell'account **e** nome del PC) |
| 7  | **Account cliente** (col cliente davanti): si apre la registrazione del tipo di email scelto, con email e password pronte da incollare (E/P, INVIO a fine) |
| 8  | **Office: attivazione** con la card PIN (`microsoft365.com/setup` o `office.com/setup`). *Salta se Office è già attivato o se non c'è una card* |
| 9  | **Antivirus** della card indicata (McAfee/Norton), altrimenti Windows Defender. *Se un antivirus è già installato (Centro sicurezza di Windows o programmi installati) il passo si salta: "già installato"* |
| 10 | **Unieuro Cyber Protection** (opzionale, solo se indicato nel pannello) — sito + credenziali app |
| **Fase 3** | **Pulizia, driver e aggiornamenti (automatico)** |
| 11 | **Pulizia e ottimizzazione** (partita in background nella fase 2, qui si attende la fine): bloatware OEM, promo dal menu Start, avvio automatico, OneDrive, **privacy**, piccole comodità Windows |
| 12 | **Driver**: scheda video dedicata (tool del produttore) + driver generici da Windows Update |
| 13 | **Aggiornamenti — sempre per ultimi**: app (`winget upgrade --all`), app del **Microsoft Store**, e **Windows Update** (scaricati in background, installati a fine lavoro prima del riavvio) |
| —  | **Report finale & Consegna**: verifica finale + diagnostica **Salute SSD (SMART)**, **Salute Batteria** (notebook) e **Licenza Windows** + **Scheda Consegna Cliente PDF** sul Desktop (unico file per il cliente; se il disco è cifrato contiene la **chiave di ripristino BitLocker** in un riquadro "Conserva questa chiave") + riavvio |

**Profili app** (browser incluso: Chrome, o Opera GX per GAMING):
- **BASE** — VLC, Adobe Reader, 7-Zip, WhatsApp, Spotify, Zoom, AnyDesk
- **UFFICIO** — BASE + GIMP, Sumatra PDF
- **GAMING** — BASE + Steam, Epic, Discord
- **COMPLETO** — tutte

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
antivirus), al lancio successivo **riprende da solo** da dove era arrivato (entro
15 secondi puoi premere N per ricominciare da capo), con i dati del cliente già
confermati: i passi già completati vengono saltati. Il checkpoint si cancella da solo a
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

## 4-bis. Rete aziendale / con firewall o proxy

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

## 5. File generati (log e report)

Al termine, sul **Desktop** del cliente resta **un solo file**:

- `Scheda-Consegna-Cliente.pdf` — scheda di consegna (credenziali, hardware,
  garanzia, programmi installati e, se il disco è cifrato, la chiave di
  ripristino BitLocker in evidenza nel riquadro "Conserva questa chiave"). L'HTML da cui
  nasce viene generato in `C:\ProgramData\PCFacile\consegna` e cancellato dopo
  la conversione. Se il PDF non si riesce a creare (Edge assente o errore), sul
  Desktop resta `Scheda-Consegna-Cliente.html` da stampare o salvare in PDF dal
  browser.

Non viene più creato il file `NON CANCELLARE - Chiave di Ripristino BitLocker.txt`
(quello lasciato da versioni precedenti viene tolto quando la scheda è sul
Desktop; resta solo se in questa sessione la chiave non si è potuta leggere).

Il materiale tecnico resta in `C:\ProgramData\PCFacile\log` (non sul Desktop):
`riepilogo-tecnico.txt` (senza password né recovery key) e
`setup_<PC>_<data>.json` / `.csv` con gli esiti di ogni passo.

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

## 7. Prova a vuoto

La simulazione completa senza modifiche (`-Test`) gira in automatico nella CI a
ogni modifica: per l'operatore non serve.
