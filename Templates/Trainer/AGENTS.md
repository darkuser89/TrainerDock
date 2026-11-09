# Native TrainerDock-Trainervorlage

Lies zuerst `README.md` und `CHAT_START.md` in diesem Ordner sowie die `AGENTS.md`
im TrainerDock-Projekt. Für neue Module `script/new_module.py` verwenden; diese Vorlage
selbst nur bei einem Auftrag zur Verbesserung der Vorlage verändern.

- Alle sichtbaren Texte auf Deutsch schreiben, einschließlich Funktionsnamen,
  Erklärungen, Bedienhilfen und Status-/Fehlermeldungen. Spielnamen und Marken
  erhalten. Interne IDs, native Anbindungen und Protokollschlüssel nicht übersetzen.

- Nur echte Trainer. Keine simulierten Cheatwirkungen, Dummy-Spielobjekte oder
  Demo-Adapter ins Produkt einbauen. Synthetische Fixtures gehören ausschließlich
  in `Tests/` und dürfen nicht als Ingame-Nachweis gelten.
- Die Vorlage ist bewusst nicht funktionsfähig: `developmentOnly: true`, inaktive
  Profile, keine geprüften UUIDs und keine implementierten Funktionen. Sie ist kein
  zusätzlicher fertiger Trainer. Diese Kennzeichnung nicht kosmetisch entfernen.
- Erst echte Originalidentität, native Engine-Anbindung und Rücklesebestätigung
  erarbeiten. Keine fremden Adressen, Offsets oder Signaturen übernehmen.
- GameThread, Besitzerwechsel, Ladepausen und Rücknahme eigener
  Wirkungen beachten. Einmalaktionen niemals automatisch ausführen oder wiederholen.
- Vollständiger Trainer einschließlich Overlay bleibt im Modul; keine Spiellogik
  in `App/` oder `Core/` ergänzen. Der Launcher bleibt unverändert.
- Nur für neue Spiele neue Modul-IDs erzeugen. Spielupdates und weitere Stores
  ergänzen das vorhandene Modul um eigene geprüfte Profile; bisherige IDs und
  Originalbindungen erhalten. Paketversion und Spielbuild getrennt halten.
- Trainer einzeln mit `script/build.py --module <id> --configuration Release`
  bauen. Bei beauftragter Veröffentlichung den gezielten CI-/Katalogablauf aus
  [docs/RELEASING.md](../../docs/RELEASING.md#neue-trainer-und-spielupdates-veröffentlichen)
  verwenden. Alte Releases und installierte Versionen erhalten; keine Binaries
  in Git oder die App kopieren, keine veröffentlichten Bytes/Prüfsummen ersetzen.
  Lokale Buildprodukte werden nicht automatisch im Launcher installiert.
- Vor Builds/Veröffentlichungen `python3 -B script/trainer_distribution.py plan`
  gegen den bestätigten Onlinekatalog prüfen. Nur neue oder tatsächlich inhaltlich
  geänderte Trainer aus `modules` bauen und veröffentlichen; bei leerer Liste
  weder Trainerbuilds noch Versionssprünge oder Trainer-Releases erzeugen.
  Reine Buildskript-, Test-, Doku-, Appversions- und Buildpfadänderungen zählen
  nicht als Trainerupdates. Gemeinsame Runtimeänderungen treffen ausschließlich
  tatsächliche Abhängigkeiten. Unerwartete Masseneinträge im Plan vor dem Build
  untersuchen und die Ursache korrigieren; nicht pauschal alle Versionen erhöhen.
  Inhaltsprüfung und strengen Build-/Bytebeleg getrennt erhalten. Fingerabdruck-
  Formatwechsel nur mit bestätigten Altbelegen migrieren; `buildOnlyVersions`
  nicht wieder als Updates anbieten. Maßgeblich ist `docs/RELEASING.md`.
- Spielstarts und Tests im Originalprozess benötigen einen entsprechenden
  Nutzerauftrag. Builds und synthetische Tests starten keine Spiele.
- Vor der ersten Ingame-Prüfung die projektweite Anleitung
  [Overlay-Maus und gebündelte Tests](../../docs/OVERLAY_INPUT.md) lesen. Analyse,
  Diagnose und synthetische Prüfungen vorbereiten; Menü, Gameplay, Zeiger,
  freie Bewegung, Klickzuordnung und Rückgabe zusammen im freigegebenen Lauf prüfen.
- AppKit-Ivars über `ivar_getOffset` zur Laufzeit bestimmen. Engine-Capture,
  Fenster-Capture und rohe Eingabe getrennt untersuchen; ein einzelnes Flag kann
  von der Engine pro Frame überschrieben werden. Keine NMS-Adressen übernehmen.
- Cursorbilder können leer sein. Sichtbare Cursorpixel bei 1×/2× auf geleerter
  Zeichenfläche prüfen; ein eigener Vektorpfeil muss Klicks durchlassen.
  Sichtbarkeit nach Bedienwunsch/Fokus steuern und Capture-Rücklesung getrennt melden.
- Reversible Funktionen im selben Lauf bündeln. Weitere Kandidaten erst nach
  eingegrenzter Ursache und bestandenen synthetischen Prüfungen starten. Geladene
  Testbibliotheken nicht überschreiben; Doppelstarts verhindern und nach bestätigter
  Wirkung aufhören. Vorhandene Start-/Beendenfreigaben bleiben maßgeblich.
- Keine App, Objektdateien, Logs oder Caches in diesem Quellordner speichern.
- HiDPI-Verhalten aus `MHTHiDPI.h` erhalten: Punkte für Layout und Eingaben,
  Pixelraster erst beim Zeichnen; Zoom- und Backing-Wechsel neu zeichnen. Keine
  feste Layerauflösung setzen oder native Glasflächen als Bitmap zwischenspeichern.
- Unten rechts `MHTGlassSlider` samt `MHTGlassIntensity.m` in `sdkSources`
  erhalten. `glassIntensity` durch alle normalisierten Optionen weitergeben und
  über `optionsChanged` pro Trainer speichern: 0 transparent, 0,5 Standardglas,
  1 undurchsichtig. Nur den Hintergrund regeln, Vordergrund unverändert lassen.
  Keine blockierende Maus-Tracking-Schleife in der Engine-Ereigniszustellung.
