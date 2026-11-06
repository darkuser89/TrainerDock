# Wiederverwendbare Vorlage für echte native Trainer

Diese Vorlage enthält die technische Grundlage für ein vollständiges TrainerDock-Modul:
Ingame-Overlay mit Liquid Glass und Ersatzdarstellung, Shortcuts, Auswahlverwaltung,
serialisierte Bridge, Profilprüfung, Speicherhilfen und Runtime-Anbindung an den
universellen Launcher. Die spielabhängige native Anbindung muss entwickelt werden.

**Die Vorlage ist kein fertiger Trainer.** Es gibt keine simulierten Wirkungen,
Spieladressen, erfundenen UUIDs oder vorgetäuschten Erfolge. Der einzige
Katalogeintrag ist als nicht implementiert markiert. Der Standardadapter meldet
„nicht unterstützt“ und führt keine Aufträge auf einem Ersatzthread aus.

## Für einen anderen Chat

Den Arbeitsauftrag aus [CHAT_START.md](CHAT_START.md) verwenden oder den globalen
Skill `$trainer-template` aufrufen. Der kanonische Vorlagenordner ist
`/Users/jbw/Documents/MHT/Templates/Trainer`.

Ein neues Quellmodul anlegen:

```sh
cd /Users/jbw/Documents/MHT
python3 -B script/new_module.py --id mein-spiel --name "Mein Spiel" --store Steam
```

Die neutrale Vorlage `trainer` ist Standard. Mit `--profile /pfad/profil.json`
können bereits tatsächlich ermittelte Identitätsdaten eingelesen werden. Ohne
Profildatei bleiben sie leer. Beide Wege erzeugen deaktivierte Entwicklungsprofile.
Es wird nichts gebaut, installiert oder gestartet. Vorhandene Module werden nicht
überschrieben. Die Ausgabe enthält eigene Sources und eine eigene AGENTS.md.

Vor der nativen Eingabeanbindung und dem ersten Spielstart die Anleitung
[Overlay-Maus und gebündelte Tests](../../docs/OVERLAY_INPUT.md) lesen. Sie enthält
die bestätigten Ursachen für unsichtbare, gebundene oder blinkende Mauszeiger sowie
Prüfungen für Laufzeit-Ivars, echte Cursorpixel, Koordinaten und die Rückgabe der
Steuerung. Diagnose und synthetische Tests vorab vorbereiten; Menü, Gameplay und
mehrere reversible Funktionen in einem freigegebenen Lauf prüfen. Die NMS-Quellen
dienen als Muster; ihre Spieladressen und nativen Signaturen bleiben spielgebunden.

## Spielabhängige Arbeit

Der Glasregler unten rechts ist Teil der Vorlage und gehört in jeden neuen
Trainer. `glassIntensity` wird auf 0…1 begrenzt und über den bestehenden
Optionskanal pro Modul gespeichert. 0 ist transparent, 0,5 natives Glas und 1
vollständig deckend; Texte und Bedienelemente bleiben unverändert sichtbar.
`MHTGlassIntensity.m` in `sdkSources` und die Optionsweitergabe beibehalten.
Die synthetischen HiDPI-Prüfungen kontrollieren auch Slider, Mauszustellung,
Endpunkte und Wiederherstellung. Ein Spielstart ist dafür nicht erforderlich.

1. `Module.json`: Store, Bundle-ID, Executable, Team-ID, Version und arm64-UUID
   anhand der tatsächlichen Originalinstallation ermitteln. Keine Fantasiewerte.
2. `Sources/NativeAdapter.m`: bestätigte Engine-Zustellung an den tatsächlichen
   GameThread implementieren; lokale Besitzer, Weak-Handles und Spielmodus prüfen.
3. `Sources/TrainerFeatures.*`: nur wirklich implementierte Funktionen definieren.
   Zahlenwerte begrenzen; Einmalaktionen explizit kennzeichnen. „Aktiv“ ausschließlich
   nach nativer Rücklesebestätigung. Eigene Effekte bei Besitzerwechsel lösen.
   Anschließend `groups` in `Module.json` pflegen: jede native Feature-ID genau
   einmal einer passenden Gruppe zuordnen. Der Launcher stellt diese Bereiche
   aufklappbar dar; Details und Beispiel unter `docs/MODULES.md` im TrainerDock-Projekt.
4. Die generische Bridge, Lade-/Kontextprüfung, Cursorfreigabe und
   Auswahlverwaltung erhalten. Keine automatischen Einmalaktionen beim Start.
5. `Build.json`: benötigte Sources und eigene Tests ergänzen. Für einen kompatiblen
   MT-Adapter kann `testSuite: "mt"` genutzt werden, sobald echte Funktionstypen
   existieren. Native `.mm`-Dateien werden mit C++17 kompiliert.
6. `developmentOnly` erst nach tatsächlicher Implementierung entfernen bzw. auf
   `false` setzen. Vorlagen werden bei Gesamtbuilds übersprungen; ihr expliziter
   Produktbuild wird abgelehnt. Das schützt vor versehentlicher Auslieferung.
7. Profile erst mit belegter nativer Anbindung freigeben. Tests im Spiel ausschließlich
   im Umfang des Nutzerauftrags durchführen und getrennt von synthetischen Tests benennen.

Danach das vollständige Modul unabhängig vom Launcher bauen:

```sh
python3 -B script/build.py --module mein-spiel
```

Der Befehl aktualisiert `TrainerDock.xcodeproj` und baut das native Scheme
`Trainer-mein-spiel`. Für direkte Xcode-Arbeit nach Änderungen an `Build.json`
`python3 -B script/xcode_project.py` ausführen. Mindestziel für App und Trainer
ist macOS 27.0.

Ausgabe: `~/Library/Developer/TrainerDock/Modules/mein-spiel.mhtmodule`. Anschließend im
Launcher „Trainer & Spiele neu laden“. Das Modul enthält die ganze Trainerbibliothek,
Profile, Katalog und Lizenz; der Launcher benötigt keine spielabhängige Änderung.

Details zum Vertrag: [Modulanleitung](../../docs/MODULES.md) und
[Architektur](../../docs/ARCHITECTURE.md). Die gemeinsamen SDK-Quellen befinden sich
unter `ModuleSDK/`; sie werden in jedes vollständige Modul kompiliert.

Das native Overlay wird mit `MHTOverlayHost` in einem separaten, nicht fokussierenden
Child-Panel desselben Spielprozesses gehostet. Damit gelangen keine Glas-Constraints
in ein Enginefenster, das etwa Unreal von seinem GameThread abfragt. `sdkSources`
im Build behalten; Mausereignisse über `MHTOverlayMouseEvent` in die Panelkoordinaten
umrechnen. Das Spielfenster erhält keine zusätzlichen Trainer-Subviews.
`host.mouseHandler` an `root.handleMouseEvent:` anbinden und
`host.mouseInteractionEnabled` zusammen mit `root.wantsMouseInteraction` und dem
aktiven Spielfenster aktualisieren. Das Panel empfängt nur bei geöffneter Bedienung
eigene Klicks; Tastaturfokus und geschlossene Mausbedienung bleiben beim Spiel.
