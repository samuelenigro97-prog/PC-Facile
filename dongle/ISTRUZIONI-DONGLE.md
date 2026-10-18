# Dongle Hardware "Zero Clic" per PC Facile

Questo dongle permette di avviare l'intera configurazione di **PC Facile** su qualsiasi computer inserendolo semplicemente in una porta USB, senza dover aprire manualmente finestre, esplora risorse o terminali.

---

## 1. Hardware Consigliato (Costo ~4 €)

Puoi utilizzare qualsiasi scheda basata sul microcontroller **Raspberry Pi RP2040**:
- **Raspberry Pi Pico** (~4 €) - Standard, porta Micro-USB.
- **Waveshare RP2040-Zero** (~3-5 €) - Ultra compatto, porta USB-C nativa, ideale come pendrive minuscola.
- **Adafruit KB2040** o **Trinkey RP2040** - Con presa USB diretta senza cavo.

---

## 2. Preparazione del Dongle (Solo la prima volta)

1. **Installa CircuitPython**:
   - Collega la scheda tenendo premuto il tasto **BOOTSEL** (apparira' come un disco USB chiamato `RPI-RP2`).
   - Scarica il file CircuitPython per la tua scheda da [circuitpython.org](https://circuitpython.org/downloads).
   - Trascina il file `.uf2` dentro `RPI-RP2`. Il dispositivo si riavviera' e verra' riconosciuto come un'unita' disco denominata `CIRCUITPY`.

2. **Copia la libreria HID**:
   - Scarica il pacchetto librerie di CircuitPython da [circuitpython.org/libraries](https://circuitpython.org/libraries).
   - Copia la cartella `adafruit_hid` dentro la cartella `lib/` dell'unita' `CIRCUITPY`.

3. **Copia lo script**:
   - Copia il file `dongle/code.py` nella radice di `CIRCUITPY` (sostituendo l'eventuale `code.py` vuoto esistente).

---

## 3. Utilizzo al Banco di Lavoro

1. Inserisci la chiavetta USB con **PC Facile** nella macchina del cliente.
2. Inserisci il **Dongle RP2040** in una porta USB libera:
   - Il LED di bordo si illumina.
   - Dopo 2 secondi, il dongle simula la digitazione da tastiera della sequenza di avvio.
   - Si apre automaticamente il terminale di PC Facile con elevazione privilegi e parte la configurazione!
3. Quando il LED lampeggia velocemente (5 volte), la sequenza e' completata e puoi rimuovere il dongle.
