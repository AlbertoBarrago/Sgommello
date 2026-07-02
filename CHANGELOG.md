# Changelog

Tutte le modifiche rilevanti a Sgommello sono documentate in questo file.

Il formato segue [Keep a Changelog](https://keepachangelog.com/it/1.1.0/)
e il progetto adotta il [Semantic Versioning](https://semver.org/lang/it/).

## [Unreleased]

### Changed
- Multi-monitor: il mostro compare solo sul monitor principale; i secondari vengono oscurati con un velo scuro (fix del rendering sproporzionato su schermi con geometrie diverse)

### Added
- Ciclo pausa completo (webcam): quando ti alzi, Sgommello si accoccola e dorme per la durata pausa scelta (1–15 min, default 5) mostrando il countdown nel fumetto; a pausa completata sparisce da solo, se torni prima si sveglia arrabbiato e ricomincia
- Pausa automatica della musica: quando Sgommello appare mette in pausa Spotify e Apple Music (solo se stanno suonando, via Apple Events) e riprende la riproduzione quando se ne va
- Integrazione webcam opt-in (AVFoundation + Vision): mentre Sgommello è a schermo, se la camera non vede una faccia per 5 secondi ti sei alzato davvero — lui saluta quasi gentilmente e l'overlay sfuma da solo. La camera gira solo con l'overlay attivo; toggle in Impostazioni, spento di default
- Info.plist embeddato nel binario via linker (`__TEXT,__info_plist`) con `NSCameraUsageDescription`, per il permesso camera senza bundle `.app`

- Script di release (`scripts/release.sh`): assembla `Sgommello.app` (bundle con LSUIElement e icona generata dall'emoji), firma ad-hoc e crea il DMG distribuibile
- Sito di presentazione statico in `docs/`, pronto per GitHub Pages

### Pianificato
- Avvio al login

## [0.1.0] - 2026-07-02

### Added
- Monitoraggio attività: dopo N minuti di uso continuo di mouse/tastiera (default 45, configurabile 5–120), Sgommello appare su tutti i monitor
- Mostro disegnato proceduralmente in Core Graphics: corpo, corna, occhi, bocca animata mentre parla, camminata con bob e squash & stretch, ombra a terra
- Coreografia d'ingresso: crepe ramificate stile vetro rotto che si propagano dal punto d'impatto, con il mostro che sbuca dalla crepa con effetto pop
- Pugni al monitor: il mostro carica, colpisce e crepa nuove porzioni di schermo, con scossa del frame, tonfo + suono vetro e battuta dedicata
- Gesto dell'ombrello con pugno tremante e suono dedicato
- Pizzicotto: cliccando sul mostro sobbalza, gli occhi girano storditi e si arrossano; la rabbia si accumula (cammina più veloce, mena di più) e scala in ~30 secondi
- Voce reale via AVSpeechSynthesizer, default Rocko italiano, timbro da orco (pitch basso); da arrabbiato parla più acuto e veloce
- Safe zone: tieni il cursore nell'area verde per 3 secondi per scacciarlo, con anello di progresso
- Finestra Impostazioni (SwiftUI): slider del timer, toggle voce, selettore fra le voci italiane installate, anteprima voce, test immediato
- Icona menu bar template (SF Symbol) che si adatta a chiaro/scuro, con menu pausa/test/impostazioni
- Supporto multi-monitor: overlay su ogni schermo, audio solo dal principale, safe zone attiva ovunque

### Changed
- Rimossa la personalizzazione di immagine e suoni: palette fissa di suoni di sistema a volumi tarati, mostro solo procedurale (scelta di semplicità)

[Unreleased]: https://example.com/sgommello/compare/v0.1.0...HEAD
[0.1.0]: https://example.com/sgommello/releases/tag/v0.1.0
