# =============================================================================
# PC FACILE - DONGLE HARDWARE ZERO-CLIC (CircuitPython per RP2040)
# =============================================================================
# Compatibile con: Raspberry Pi Pico, Waveshare RP2040-Zero, Adafruit KB2040.
# Requisiti: CircuitPython 8.x/9.x e libreria 'adafruit_hid' nella cartella /lib.
#
# Funzionamento:
# 1. Inserisci la chiavetta USB di PC Facile nel PC o Mac.
# 2. Inserisci questo dongle in una porta USB adiacente.
# 3. Il dongle invia via tastiera virtuale USB i comandi per avviare il setup
#    in automatico, senza dover toccare mouse o digitare comandi!
# =============================================================================

import time
import board
import digitalio
import usb_hid
from adafruit_hid.keyboard import Keyboard
from adafruit_hid.keyboard_layout_us import KeyboardLayoutUS
from adafruit_hid.keycode import Keycode

# 1. Indicatore LED di stato (GP25 sul Pico standard, varia su board compatte)
led = None
for led_pin in ("LED", "GP25"):
    if hasattr(board, led_pin):
        try:
            led = digitalio.DigitalInOut(getattr(board, led_pin))
            led.direction = digitalio.Direction.OUTPUT
            led.value = False
            break
        except Exception:
            pass

def blink(volte=3, delay=0.1):
    if not led:
        return
    for _ in range(volte):
        led.value = True
        time.sleep(delay)
        led.value = False
        time.sleep(delay)

# 2. Inizializzazione Tastiera HID
time.sleep(2.0)  # Attesa stabilizzazione driver USB del sistema operativo
kbd = Keyboard(usb_hid.devices)
layout = KeyboardLayoutUS(kbd)

if led:
    led.value = True  # LED acceso fisso: sequenza in corso

# -----------------------------------------------------------------------------
# SEQUENZA PER WINDOWS: Win + R -> PowerShell 1-Click Launcher
# Cerca setup-pc.ps1 su tutti i drive USB o esegue con fallback rete
# -----------------------------------------------------------------------------
CMD_WINDOWS = (
    "powershell -WindowStyle Minimized -ExecutionPolicy Bypass -Command \""
    "$u=(Get-ChildItem ([System.IO.DriveInfo]::GetDrives()|Where-Object{$_.IsReady}|Select-Object -ExpandProperty RootDirectory) -Filter 'setup-pc.ps1' -Recurse -Depth 2 -EA 0|Select-Object -First 1).FullName; "
    "if($u){Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \\\"\"$u\\\"\"' -Verb RunAs}else{irm https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main/setup-pc.ps1|iex}\""
)

# -----------------------------------------------------------------------------
# SEQUENZA PER MACOS: Cmd + Spazio -> Terminal -> Launcher setup-mac.sh
# -----------------------------------------------------------------------------
CMD_MAC = (
    "for v in . /Volumes/*; do [[ -f \"$v/setup-mac.sh\" ]] && { zsh \"$v/setup-mac.sh\"; exit; }; done; "
    "curl -fsSL https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main/setup-mac.sh | zsh\n"
)

def esegui_windows():
    # Premi Win + R
    kbd.press(Keycode.GUI, Keycode.R)
    time.sleep(0.1)
    kbd.release_all()
    time.sleep(0.8)

    # Scrivi il comando di avvio Windows
    layout.write(CMD_WINDOWS)
    time.sleep(0.2)
    kbd.send(Keycode.ENTER)

def esegui_mac():
    # Premi Cmd + Spazio per aprire Spotlight
    kbd.press(Keycode.COMMAND, Keycode.SPACE)
    time.sleep(0.1)
    kbd.release_all()
    time.sleep(0.8)

    # Digita Terminal e premi Invio
    layout.write("terminal")
    time.sleep(0.3)
    kbd.send(Keycode.ENTER)
    time.sleep(1.5)

    # Incolla ed esegui il launcher Mac
    layout.write(CMD_MAC)
    kbd.send(Keycode.ENTER)

# Esegui la sequenza (puoi commentare/scommentare in base al target, o lasciarle in sequenza)
try:
    # Se il dongle e' connesso a Windows, Win+R aprira' Esegui;
    # su Mac Win+R e' Cmd+R (innocuo fuori dal boot).
    esegui_windows()
except Exception:
    pass

# Feedback di completamento: 5 lampeggi rapidi
blink(5, 0.08)
if led:
    led.value = False
