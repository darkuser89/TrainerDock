# TrainerDock · Mac Game Trainers

Ein gemeinsamer macOS-Launcher für die bereitgestellten Trainer. Installierte Spiele
stehen links, die jeweiligen Trainerfunktionen und der Startknopf rechts. Unter
„Trainer & Spielpfade“ lässt sich jede Spiele-App einzeln auswählen.

Enthalten sind siebzehn Trainer:

| Spiel | Unterstützter Store | Profilversion |
|---|---|---|
| Balatro | Steam | 1.0.1o-FULL (Build 17459173) |
| Dome Keeper | Steam | 5.0.8.14 (Build 25038893) |
| Escape from Duckov | Steam | 2.3.30 (Build 24013657) |
| Dead Island 2 | Steam / Mac App Store | 0.6.4 |
| Resident Evil 2 | Mac App Store | 1.0.2 |
| Resident Evil 3 | Mac App Store | 1.0.0 |
| Resident Evil 4 | Mac App Store | 1.0.7 |
| Resident Evil 7 | Mac App Store | 1.0.4 |
| Resident Evil Village | Mac App Store | 1.1.8 |
| Lies of P | Steam | 1.14.0 |
| Cyberpunk 2077 | Steam | 2.5.0 |
| RoboCop: Rogue City | Steam | 0.0.1 |
| Crimson Desert | Steam | Bundle 1.0.35 (450) / Anzeige 2.04.08 |
| Vampire Crawlers | Steam | 1.6.1 (11), Build 25304267 |
| No Man’s Sky | Steam | Bundle 4.70, Build 26386568 |
| Vampire Survivors | Steam | 1.16.111 (Build 25984009) |
| Control Ultimate Edition | Steam / Mac App Store | Steam 1.34 (Build 3), MAS 1.33.1 (Build 27) / 1.371 (Build 28) |

Control enthält alle zwölf angeforderten Funktionen. Native Grenzen und
Prüfumfang: [Control-Modul](Modules/control/README.md).

Die Trainer übernehmen die konkreten arm64-Buildidentitäten der gelieferten Projekte.
Weitere Stores und Spielupdates werden dadurch nicht automatisch unterstützt.

## Benutzen

1. TrainerDock öffnen. Fehlende Spiele unter „Trainer & Spielpfade“ einrichten.
2. Links das Spiel und gegebenenfalls rechts die Storeversion auswählen.
3. Steam für Steamprofile regulär öffnen. Eine bereits laufende Spielinstanz vorher
   regulär beenden. „Spiel mit Trainer starten“ anklicken.
4. Funktionen rechts bedienen oder das Ingame-Overlay mit **⌘ ^** öffnen.
   Die spielbezogenen Kürzel stehen bei den Funktionen. „Alles aus“ löst eigene
   Dauereffekte; Einmaländerungen werden dadurch nicht rückgängig gemacht.

Die native Seitenleiste zeigt die Original-Icons installierter Spiele. Mit der
Suche und den Filtern „Installiert“ / „Alle Trainer“ lässt sich die Bibliothek
eingrenzen. Fensterbreite und -höhe bleiben beim Spielwechsel erhalten.

**⌘ ,** öffnet „Trainer & Spielpfade“ mit Suche, Spielkarten und separaten Pfaden
pro Store. **⌘ R** lädt Trainer und Spiele neu, **⌘ 1** zeigt die Bibliothek.

Liquid Glass ist dauerhaft aktiviert, auch im Ingame-Overlay. TrainerDock benötigt
macOS 27 oder neuer und verwendet natives AppKit-Glas.
Reduzierte Transparenz bzw. erhöhter Kontrast behalten Vorrang.
Im Ingame-Trainer regelt unten rechts „Glas“ die Hintergrunddeckkraft von
transparent bis undurchsichtig. Der Wert bleibt pro Trainer gespeichert.
Installationspfade stehen in „Trainer & Spielpfade“ und im Tooltip von „Spielpfad …“;
die Hauptansicht zeigt keine lange Pfadzeile.

„Mit letzter Cheat-Auswahl starten“ ist standardmäßig ausgeschaltet. Vorgemerkte
Dauerschalter werden nur bei eingeschalteter Option und gültigem Spielkontext
wiederhergestellt. Einmalaktionen werden nie automatisch ausgeführt. Die gespeicherte
Auswahl und Pfade liegen in den Benutzereinstellungen der Anwendung.

## Voraussetzungen

Apple Silicon, **macOS 27 oder neuer**, Xcode mit macOS-27-SDK oder neuer.

## GitHub-Builds und Downloads

[GitHub Actions](https://github.com/darkuser89/TrainerDock/actions/workflows/build-release.yml)
baut bei Pushes auf `main`, Pull Requests und manuellem Start den Launcher und alle
17 nativen Trainer mit Xcode 27. Synthetische Tests und Signaturprüfungen müssen
bestehen. Das geprüfte ZIP steht sieben Tage als Workflow-Artefakt bereit.

Ein Versions-Tag wie `v1.0.0` baut zusätzlich einen öffentlichen
[GitHub Release](https://github.com/darkuser89/TrainerDock/releases/latest)
mit `TrainerDock-macOS-arm64.zip` und `SHA256SUMS`. Den entpackten
TrainerDock-Ordner mit **TrainerDock.app und Modules zusammen** behalten.
Die Downloads sind ad-hoc signiert, nicht Developer-ID-signiert oder notarisiert.

Zwei C#-Trainer verwenden im Cloud-Build ausschließlich unsere eigenen kompilierten
Bausteine. Deren Quellen, Originalbindung und Binärdateien sind über SHA-256 gebunden;
geänderte Quellen sperren einen veralteten Baustein. Spiel-Assemblies werden weder
hochgeladen noch veröffentlicht. Lokales Kompilieren gegen geprüfte Originale bleibt
weiterhin möglich. Ablauf und Aktualisierung: [Release-Anleitung](docs/RELEASING.md).

## Lokal bauen

`TrainerDock.xcodeproj` in Xcode öffnen, Scheme **TrainerDock** wählen und mit **⌘ R** bauen
und den Launcher starten. Das Projekt enthält ein natives App-Target und für jeden
Trainer ein eigenes natives Dylib-Target. **TrainerDock-Launcher** baut nur die Oberfläche;
**Trainer-<spiel-id>** baut ausschließlich den jeweiligen vollständigen Trainer.
Synthetische Prüfungen gehören zum Build; Spiele werden dabei nicht gestartet.

Alternativ denselben Xcode-Build über das vorhandene Skript ausführen:

```sh
./script/build_and_run.sh --build-only   # bauen und synthetisch prüfen
./script/build_and_run.sh --verify       # zusätzlich den Launcher öffnen
```

Die aktuelle App liegt unter `~/Library/Developer/TrainerDock/TrainerDock.app`. Daneben enthält
`Modules` siebzehn eigenständige Trainerpakete. Die App selbst enthält
keine Trainerbibliothek. Weitere Module können ohne Neukompilieren der App geladen
werden; siehe die Modulanleitung. `TRAINERDOCK_BUILD_DIR`
kann einen anderen separaten Buildordner bestimmen. Code und Audit sind als
Buildziel ausgeschlossen. Die App ist ad-hoc signiert, nicht notarisiert.

TrainerDock übernimmt beim ersten Öffnen die bisherigen MHT-Spielpfade,
Trainerauswahl und Glaswerte. Eigene Trainer können unter
`~/Library/Application Support/TrainerDock/Modules` ergänzt werden; die bisherige
Modulablage bleibt lesbar. Das SDK und das Paketformat `.mhtmodule` behalten
ihre kompatiblen technischen Kennungen. Der Quellordner bleibt
`/Users/jbw/Documents/MHT`.

Wiederverwendbare [Trainervorlage](Templates/Trainer/README.md) für andere Chats:
`$trainer-template`. Sie erzeugt ein deaktiviertes Entwicklungsmodul ohne fremde
Spieladressen oder simulierte Cheatwirkungen.

Entwicklung und neue Module: [AGENTS.md](AGENTS.md),
[Modulanleitung](docs/MODULES.md), [Architektur](docs/ARCHITECTURE.md).

Build- und synthetische Tests sind keine Ingame-Nachweise. Konkrete native
Prüfungen und offene Grenzen stehen in den README-Dateien der jeweiligen Module.
Historische Aussagen der Ursprungstrainer sind keine erneute Bestätigung dieser Version.

GPL-3.0-only; siehe `LICENSE` und `docs/PROVENANCE.md`.
