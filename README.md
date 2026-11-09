# TrainerDock · Mac Game Trainers

Ein gemeinsamer macOS-Launcher für die bereitgestellten Trainer. Installierte Spiele
stehen links, die jeweiligen Trainerfunktionen und der Startknopf rechts. Unter
„Trainer & Spielpfade“ lässt sich jede Spiele-App einzeln auswählen.

Der aktuelle Projektstand enthält **28 eigenständige Trainer**. Die Liste basiert
auf den freigegebenen Profilen unter `Modules/`; die Versionsangaben bezeichnen
das Spiel, nicht die separat versionierten Trainerpakete. Bereits veröffentlichte
Pakete findest du im Trainerkatalog der App.
Neue Trainer erscheinen dort ohne App-Update; „Nach Trainerupdates suchen“ lädt
den aktuellen Katalog. Eine kompatible vorhandene App genügt.

| Spiel | Unterstützter Store | Spiel-/Profilversion | Hinweise |
|---|---|---|---|
| Balatro | Steam | 1.0.1o-FULL (Build 17459173) | |
| Control Ultimate Edition | Steam / Mac App Store | Steam 1.34; MAS 1.33.1 / 1.371 | |
| Crimson Desert | Steam | Bundle 1.0.35 (Build 450) | |
| Cyberpunk 2077 | Steam | 2.5.0 | |
| Dead Island 2 | Steam / Mac App Store | 0.6.4 | **Steam: nur Uncut-Version; MAS: nur German-Cut-Version** |
| Death Stranding Director’s Cut | Mac App Store | 1.004 (Bundle 1.1.4) | |
| Dome Keeper | Steam | 5.0.8.14 | |
| DREDGE | Epic Games Store / GOG | Epic 1.5.5; GOG 1.5.3 | GOG unter Rosetta |
| Escape from Duckov | Steam | 2.3.30 | |
| Frostpunk 2 | Steam | 1.6.1 (Bundle 0.5.591, Build 24037022) | |
| House Flipper | Steam | 1.26252 (Build 25247477) | Rosetta |
| inZOI | Steam | Bundle 5.4.95 (Build 26264076) | |
| Lies of P | Steam | 1.14.0 | |
| No Man’s Sky | Steam | Bundle 4.70 (Build 26386568) | |
| Prodeus | Steam | 1.0.2 (Build 9679369) | **Nur Einzelspieler** |
| Resident Evil 2 | Mac App Store | 1.0.2 | |
| Resident Evil 3 | Mac App Store | 1.0.0 | |
| Resident Evil 4 | Mac App Store | 1.0.7 | |
| Resident Evil 7 | Mac App Store | 1.0.4 | |
| Resident Evil Village | Mac App Store | 1.1.8 | |
| RoboCop: Rogue City | Steam | 0.0.1 | |
| Stray (WIP) | Steam | 1.5 (Build 12863654) | **Unfertig; vier Funktionen deaktiviert** |
| Terraria | Steam | 1.4.5.8 (Build 24893155) | |
| The Long Dark | Steam / Epic Games Store | Steam 2.60 (Build 26450964); Epic 2.55 | |
| Turok | Steam | 2.0 (Build 18198095) | Rosetta |
| Turok 2: Seeds of Evil | Steam | 2.0 (Build 20961743) | Rosetta |
| Vampire Crawlers | Steam | 1.6.1 (Build 25304267) | |
| Vampire Survivors | Steam / Epic Games Store | 1.16.111 | |

Control enthält alle zwölf angeforderten Funktionen. Native Grenzen und
Prüfumfang: [Control-Modul](Modules/control/README.md).

Die Trainer sind an die konkret geprüften Originalbuilds gebunden. Der Launcher
läuft auf Apple Silicon; ausdrücklich ausgewiesene Intelprofile verwenden Rosetta.
Weitere Stores und Spielupdates werden nicht automatisch unterstützt.

## Benutzen

1. TrainerDock öffnen. Gewünschte Trainer unter „Trainer laden & verwalten“ herunterladen
   und fehlende Spielpfade unter „Trainer & Spielpfade“ einrichten.
2. Links das Spiel und gegebenenfalls rechts die Storeversion auswählen.
3. Steam für Steamprofile regulär öffnen. Für Epic-Profile den Epic Games Launcher
   vorher regulär beenden. Eine bereits laufende Spielinstanz regulär beenden und
   in TrainerDock auf „Spielen“ klicken.
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

„Auswahl beim Start laden“ ist standardmäßig ausgeschaltet. Vorgemerkte
Dauerschalter werden nur bei eingeschalteter Option und gültigem Spielkontext
wiederhergestellt. Einmalaktionen werden nie automatisch ausgeführt. Die gespeicherte
Auswahl und Pfade liegen in den Benutzereinstellungen der Anwendung.

## Voraussetzungen

Apple Silicon, **macOS 27 oder neuer**, Xcode mit macOS-27-SDK oder neuer.

## GitHub-Builds und Downloads

[GitHub Actions](https://github.com/darkuser89/TrainerDock/actions/workflows/build-release.yml)
baut mit Xcode 27 ausschließlich neue oder tatsächlich geänderte Produkte.
Grundlage ist der zuletzt erfolgreich veröffentlichte Trainerkatalog. Reine
Launcher-, Dokumentations- oder Buildskriptänderungen erzeugen keine Trainerupdates.
Synthetische Tests und Signaturprüfungen müssen bestehen; Pull Requests veröffentlichen nichts.

Ein geänderter Launcher erhält einen eigenen stabilen
[GitHub Release](https://github.com/darkuser89/TrainerDock/releases/latest)
mit `TrainerDock-macOS-arm64.zip` und `SHA256SUMS`. Das ZIP enthält die
**TrainerDock.app mit Katalogmetadaten**. Trainer werden einzeln als
`trainer-<spiel-id>-v<version>` veröffentlicht und über die App heruntergeladen.
Frühere Trainerversionen bleiben verfügbar. „Alle installierten Trainer aktualisieren“
lädt die fehlenden neuen Pakete bereits installierter Trainer; alte Versionen bleiben erhalten.
Die Downloads sind ad-hoc signiert, nicht Developer-ID-signiert oder notarisiert.

Zwei C#-Trainer verwenden im Cloud-Build ausschließlich unsere eigenen kompilierten
Bausteine. Deren Quellen, Originalbindung und Binärdateien sind über SHA-256 gebunden;
geänderte Quellen sperren einen veralteten Baustein. Spiel-Assemblies werden weder
hochgeladen noch veröffentlicht. Lokales Kompilieren gegen geprüfte Originale bleibt
weiterhin möglich. Ablauf und Aktualisierung: [Release-Anleitung](docs/RELEASING.md).

## App-Updates

TrainerDock prüft GitHub beim Start und danach stündlich, mit höchstens einer
erfolgreichen automatischen Abfrage pro Tag. Im Menü **TrainerDock → Nach Updates
suchen …** jederzeit manuell prüfen; automatische Prüfungen lassen sich dort
abschalten. Eine neue Version wird angezeigt und erst nach „Laden und installieren“
installiert. Die SHA-256-Prüfsumme kommt direkt aus den GitHub-Release-Metadaten.
Nur die App wird ersetzt und TrainerDock neu gestartet. Installierte Trainer
werden separat über die Trainerverwaltung aktualisiert. Laufende Spiele verzögern
die App-Installation; Trainerversionen, Spielstände, Pfade und Einstellungen bleiben erhalten.

Keine zusätzliche Update-Signierung, Apple-Zertifikate oder Schlüsselbundabfragen.
macOS-Schutzmechanismen bleiben unverändert. Die erste Version mit integriertem
Updater muss einmal manuell aus dem GitHub Release installiert werden.

## Lokal bauen

`TrainerDock.xcodeproj` in Xcode öffnen, Scheme **TrainerDock** wählen und mit **⌘ R** bauen
und den Launcher starten. Das Projekt enthält ein natives App-Target und für jeden
Trainer ein eigenes natives Dylib-Target. **TrainerDock-Launcher** baut nur die Oberfläche;
**Trainer-<spiel-id>** baut ausschließlich den jeweiligen vollständigen Trainer.
Synthetische Prüfungen gehören zum Build; Spiele werden dabei nicht gestartet.

Vor dem ersten lokalen Build `brew install libarchive` ausführen. Nur die Header
werden benötigt; die App verwendet die macOS-Systembibliothek, keinen Homebrew-Runtimepfad.
Alternativ denselben Xcode-Build über das vorhandene Skript ausführen:

```sh
./script/build_and_run.sh --build-only   # bauen und synthetisch prüfen
./script/build_and_run.sh --verify       # zusätzlich den Launcher öffnen
```

Die aktuelle App liegt unter `~/Library/Developer/TrainerDock/TrainerDock.app` und
enthält ausschließlich Katalogmetadaten. Vollständige lokale Trainermodule entstehen
unter `~/Library/Developer/TrainerDock/Modules`; sie werden nicht automatisch installiert.
Der Launcher liest nur Metadaten; Trainerbibliotheken werden erst im ausgewählten Spielprozess geladen.
Weitere Module können ohne Neukompilieren der App ergänzt werden; siehe die Modulanleitung. `TRAINERDOCK_BUILD_DIR`
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
