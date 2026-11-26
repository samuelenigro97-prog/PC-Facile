# PC Facile — Kit USB Unieuro (Windows · Mac · Chromebook)

> **⬇️ [Scarica Cartella "PC Facile" (Ultima Versione ZIP per Chiavetta USB)](https://github.com/samuelenigro97-prog/PC-Facile/releases/latest/download/PC-Facile.zip)** *(oppure fai doppio clic sul collegamento **`Scarica Ultima Versione.url`** presente nella chiavetta/archivio: estrae direttamente la cartella chiamata **`PC Facile`**)*

Kit automatico da chiavetta USB per configurare in negozio PC **Windows**, **Apple Mac** e **Chromebook (ChromeOS)**:
- **Unieuro Everyday Digital** (**Unieuro Secure / F-Secure** + estensione **Browsing Protection** + **Unieuro Cyber Protection**)
- **Lingua Italiana (`it-IT`)** e sincronizzazione orario
- **Rimozione silenziosa antivirus di prova** (`McAfee`, `Norton`, `Avast`, `AVG`) e collegamento automatico al **Wi-Fi del negozio**
- **Office / Microsoft 365** e **Catalogo App** (`BASE`, `UFFICIO`, `GAMING`) con icone sul Desktop in **ordine logico e cromatico**
- **Aggiornamenti completi** (inclusi gli aggiornamenti di anteprima Windows Update con *"Ottieni gli ultimi aggiornamenti non appena sono disponibili"* attivo)
- **Scheda di Consegna Cliente in PDF** (`Scheda-Consegna-Cliente.pdf`) sul Desktop con diagnostica hardware, chiave BitLocker/FileVault e credenziali Unieuro Secure.

---

## 1. Avvio Immediato a 0 Secondi (Un File per Sistema Operativo)

Sulla chiavetta USB trovi i **3 file di avvio** (lo ZIP scaricato da GitHub contiene già solo i file puliti della chiavetta):

1. 🪟 **Su PC Windows**: doppio clic su **`PC Facile Windows.bat`** (conferma UAC → *Sì*).
2. 🍎 **Su Apple Mac**: doppio clic su **`PC Facile Mac.command`** (inserisci una sola volta all'inizio la password del Mac).
3. 💻 **Su Chromebook (ChromeOS)**: apri l'app *File*, vai sulla chiavetta USB e fai doppio clic su **`PC Facile Chromebook.html`**.

### Come lavora il flusso automatico (0 secondi di attesa)

1. **Rimozione AV di prova e connessione Wi-Fi automatica**: su Windows `PC Facile Windows.bat` rimuove in silenzio eventuali antivirus preinstallati (`McAfee`, `Norton`, `Avast`, `AVG`), collega il PC al Wi-Fi del negozio (`wifi/wifi.txt` o `wifi/UNIEURO_EXPO.xml`) e allinea automaticamente la chiavetta all'ultima versione su GitHub verificata via SHA256.
2. **Partenza istantanea a 0 secondi**: lo script apre a sinistra il **Pannello Operatore** e a destra il **Terminale** e **parte subito a 0 secondi** con **Unieuro Secure** (installato in automatico su ogni PC con l'estensione **Browsing Protection by F-Secure** su Edge e Chrome), la lingua italiana, le app, la pulizia, i driver e gli aggiornamenti.
3. **Inserimento dati cliente e `Incolla mail` per Unieuro Secure**:
   - Puoi inserire i dati del cliente nel Pannello Operatore in qualsiasi momento mentre lo script lavora.
   - Se lasci **Cognome e Nome vuoti** (o scrivi `clt clt` / `Utente`), il PC viene configurato come **`Utente`** senza registrare email e senza stampare il box account nel PDF di consegna.
   - Nel riquadro **Password Unieuro Secure**, clicca **`Incolla mail`** (o incolla l'intero testo della mail `Email: ... Password: ...` ricevuta dal cliente): il pannello estrae da solo Email e Password temporanea di Unieuro Secure, le offre col tasto **`Copia`** a 1 clic e le stampa nella **`Scheda-Consegna-Cliente.pdf`**.
4. **Icone sul Desktop in ordine logico e cromatico**:
   - A fine lavoro tutte le icone sul Desktop vengono riordinate dall'alto in basso mettendo **per prime le due app di sicurezza Unieuro** e poi le altre categorie in armonia cromatica:
     1. **Prime 2 App — Sicurezza Unieuro** (*1. `Unieuro Secure` → 2. `Unieuro Cyber Protection`*)
     2. **Office & Documenti** (*Word → Excel → PowerPoint → Outlook → OneNote → LibreOffice → Adobe Acrobat Reader → SumatraPDF*)
     3. **Browser & Comunicazione** (*Google Chrome → Zoom → WhatsApp → Discord → AnyDesk → TeamViewer*)
     4. **Multimedia, Utilità & Gaming** (*Spotify → VLC → AIMP → GIMP → 7-Zip / The Unarchiver → Steam → Epic Games*)
     5. **Documento finale** (*`Scheda-Consegna-Cliente.pdf`*)

---

## 2. La Chiavetta USB Sempre Aggiornata (`manifest.txt`)

A ogni avvio con Internet, `PC Facile Windows.bat` (Windows) e `PC Facile Mac.command` (Mac) controllano `manifest.txt` su GitHub e aggiornano automaticamente sulla chiavetta tutti i file del kit:
- `PC Facile Windows.bat` *(Windows)*
- `PC Facile Mac.command` *(Mac)*
- `PC Facile Chromebook.html` *(Chromebook / ChromeOS)*
- `Scarica Ultima Versione.url` *(Link diretto al download dello ZIP aggiornato da GitHub)*
- `setup-pc.ps1` + `setup-pc.ps1.sha256`
- `setup-mac.sh` + `setup-mac.sh.sha256`
- `LEGGIMI.md`
- `wifi/wifi.txt` e `wifi/UNIEURO_EXPO.xml`

Ogni file viene verificato con l'impronta **SHA256** prima di sostituire la copia locale, e `Invoke-OrdinaChiavetta` elimina automaticamente eventuali file o cartelle superflue dalla chiavetta.

---

## 2. Manutenzione (Non per il Flusso Cliente)

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

## 7. Prova a Vuoto

La simulazione completa senza modifiche (`-Test`) gira in automatico nella CI a
ogni modifica: per l'operatore non serve.
