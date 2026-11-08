# Native TrainerDock-Trainervorlage

Lies zuerst `README.md` und `CHAT_START.md` in diesem Ordner sowie die `AGENTS.md`
im TrainerDock-Projekt. Für neue Module `script/new_module.py` verwenden; diese Vorlage
selbst nur bei einem Auftrag zur Verbesserung der Vorlage verändern.

- Nur echte Trainer. Keine simulierten Cheatwirkungen, Dummy-Spielobjekte oder
  Demo-Adapter ins Produkt einbauen. Synthetische Fixtures gehören ausschließlich
  in `Tests/` und dürfen nicht als Ingame-Nachweis gelten.
- Dieses Death-Stranding-Modul gibt nur die exakte MAS-Identität und elf
  geprüfte native Funktionen frei; weitere 15 Katalogeinträge bleiben ausdrücklich
  deaktiviert. Die Freigabe des Moduls bedeutet keine Freigabe dieser 15 Funktionen.
  Keine unbekannten Builds oder ungeprüften zusätzlichen Wirkungen freigeben.
- Die Wasserfunktion hält die native Stand-/Atemreserve voll. Stabilität ist vom
  Nutzer im flachen Wasser bestätigt; keinen allgemeinen Schutz gegen Stürze,
  tiefes Wasser oder starke Strömung daraus ableiten. `DSPlayerParamComponent`
  nicht mit einer Bewegungskomponente verwechseln; Parameter und Reserven sind
  getrennte Daten. Nur die geprüfte originale Reservenroutine aufrufen.
- Traglast: Die zwei pro Spieler kopierten Basisgrenzen liegen im bestätigten
  Parameterblock. Den originalen berechneten Grenzwert getrennt zurücklesen;
  Ausdauerfaktor und Ausrüstungsboni nicht durch einen angeblichen Endwert ersetzen.
  Eigene Änderungen beim Ausschalten zurücknehmen, fremde spätere Werte schützen
  und während Ladepausen keine alten Spielerzeiger beschreiben.
- Zeitsteuerung: ausschließlich eigene originale Controller-Aufträge verwalten.
  ID und vollständige eigene Auftragssignatur vor Rücknahme prüfen; keine fremden
  Zeitaufträge löschen oder den globalen Controller pauschal auf eins setzen.
  Welt-, Spieler- und Kamera-Skala real zurücklesen; native Grenze ist dreifach.
- BB-Stress: Den originalen `SetBBStressByRate`-Auftrag verwenden. Der Auftrag
  bei `PlayerSystem+0x203ac` und dessen Serialisierungsabbild bei `+0xfcf8` sind
  keine aktuelle Wirkungsbestätigung. Aktuellen Stress und Darstellung aus dem
  verifizierten Parameterblock bei `+0x42c4/+0x42c8` getrennt zurücklesen.
  Ausschalten beendet die Unterdrückung und entfernt nur einen eigenen noch
  ausstehenden Null-Auftrag; keinen früheren Stress automatisch hinzufügen.
- Erst echte Originalidentität, native Engine-Anbindung und Rücklesebestätigung
  erarbeiten. Keine fremden Adressen, Offsets oder Signaturen übernehmen.
- GameThread, Besitzerwechsel, Ladepausen und Rücknahme eigener
  Wirkungen beachten. Einmalaktionen niemals automatisch ausführen oder wiederholen.
- Vollständiger Trainer einschließlich Overlay bleibt im Modul; keine Spiellogik
  in `App/` oder `Core/` ergänzen. Der Launcher bleibt unverändert.
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
