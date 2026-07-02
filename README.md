# Sgommello 👹

Un mostriciattolo da menu bar per macOS che ti costringe a fare pause: dopo troppo
tempo continuo davanti allo schermo, sbuca rompendo il vetro del monitor, ci
cammina sopra, tira pugni che lo crepano ancora di più e ti insulta — a voce.

Nato per gioco, realmente utile.

## Cosa fa

- Monitora l'attività di mouse e tastiera. Dopo **45 minuti** continui (configurabile
  5–120) compare sul **monitor principale** sopra qualsiasi finestra, mentre gli
  altri monitor vengono "spenti" con un velo scuro.
- Sbuca da una crepa stile vetro rotto, gironzola, **tira pugni che spaccano nuove
  porzioni di schermo** e fa il gesto dell'ombrello.
- **Parla davvero** (TTS di sistema, voce default: Rocko italiano, timbro da orco)
  con frasi minacciose-comiche.
- Se lo **pizzichi** (click), si arrabbia: occhi rossi e storditi, cammina più veloce,
  mena di più. Si calma da solo in ~30 secondi. Pizzicarlo è controproducente. 🙂
- Per scacciarlo: tieni il cursore nella **zona verde per 3 secondi** (anello di
  progresso incluso). Se invece resti idle 60 secondi, il contatore riparte da zero:
  la pausa vera è l'unica vittoria.
- Quando appare **mette in pausa la musica** (Spotify / Apple Music) e la riprende
  quando se ne va — se non stava suonando nulla, non parte nulla.
- **Webcam (opt-in)**: se abiliti l'opzione, mentre è a schermo controlla se ti sei
  alzato davvero — 5 secondi senza faccia in camera e si congeda da solo. La camera
  è attiva **solo** mentre Sgommello è visibile.

## Requisiti

- macOS 13+
- Swift 5.9+ (Xcode o Command Line Tools)

## Build e avvio

```sh
swift build          # compila
swift run            # avvia (icona nella menu bar, nessuna finestra)
```

Dalla menu bar (icona kickboxing 🥋):
- **Metti in pausa / Riattiva** — sospende il monitoraggio
- **Mostra ora (test)** — lo evoca subito, per demo o taratura
- **Impostazioni…** — timer, voce on/off, scelta della voce italiana

## Architettura

```
Sources/Sgommello/
├── main.swift             Entry point (app accessory, solo menu bar)
├── AppDelegate.swift      Menu di stato e wiring dei componenti
├── Config.swift           Costanti, frasi e battute
├── AppSettings.swift      Preferenze persistite (UserDefaults) e palette suoni
├── ActivityMonitor.swift  Rilevamento attività/idle via CGEventSource
├── Crack.swift            Modello e generazione delle crepe ramificate
├── SgommelloView.swift    Rendering del mostro, macchina a stati, crepe, fumetto
├── OverlayController.swift Finestre overlay multi-monitor e safe zone
├── PresenceMonitor.swift  Webcam + Vision: rileva se ti sei alzato
├── SpeechService.swift    Voce via AVSpeechSynthesizer
└── SettingsWindow.swift   Finestra Impostazioni (SwiftUI)
```

Dettagli utili per chi ci mette mano:
- Il mostro è **interamente procedurale** (NSBezierPath/CGContext): niente asset.
- Le crepe già propagate sono **rasterizzate in cache** e blittate; solo quelle in
  crescita vengono ridisegnate frame per frame.
- L'overlay gira a ~33fps con un `Timer`; il mostro vive solo sullo schermo
  principale, i monitor secondari ricevono un semplice velo scuro.

Nota permessi: l'Info.plist con `NSCameraUsageDescription` è embeddato nel
binario dal linker (vedi `Package.swift`), quindi il permesso camera funziona
anche senza bundle `.app`. Al primo uso della webcam macOS mostra il prompt.

## Roadmap

Vedi [CHANGELOG.md](CHANGELOG.md) — in sintesi: bundle `.app` con icona per
distribuirlo e farlo partire al login.
