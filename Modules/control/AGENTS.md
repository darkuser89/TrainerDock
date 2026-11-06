# Control – Regeln für weitere Änderungen

Die Projekt-AGENTS.md und `$trainer-template` gelten. Nur dieses eigenständige
Modul bearbeiten; keine Control-Logik in den Launcher verschieben.

- Nur echte native Wirkungen. Alle zwölf Katalogfunktionen sind implementiert.
  Materialien nur für vorhandene eigene Stapel und erfasste Rezeptzutaten
  anwenden. Reale Prüfung: 4/1/1 → 999, Nachfüllen 998 → 999, Rücknahme 4/1/1.
  Besitzer, GlobalID, exakte Komponente und unveränderten letzten Wert vor
  Rücknahme prüfen. Fremde/übertragene Stapel und fremde Änderungen schützen.
- Unterstützt sind Steam 1.34 (Build 3), MAS 1.33.1 (Build 27) und MAS 1.371
  (Build 28), jeweils arm64 mit eigener vollständiger Fünf-Image-Bindung in
  `ControlEngine.mm`. Keine weiteren Builds durch bloße UUID-Ergänzung freigeben.
  Der stabile Profilname `control-mas-arm64` bezeichnet den aktuellen MAS-Build;
  das ältere Profil heißt `control-mas-1-33-1-arm64`.
- Vor einem Update-Test `Tests/Control/UpdateCompatibility.py` mit den exakten
  Originalen ausführen. Es prüft unter anderem 288 Komponentenmethoden,
  GameServer-Slot, Setter, Pins und Core-APIs. Relokationsmaskierung nur auf
  echte ADRP-Paare begrenzen; anschließend geladene Objektzeiger dürfen keine
  Feldoffsets verdecken. Statische Gleichheit ist kein Ingame-Wirkungsnachweis.
- Originaldateien, Signaturen, Entitlements, Schutzmechanismen und Saves nicht
  bearbeiten. Der Trainer verändert ausschließlich gültige Laufzeitdaten.
- Aufträge ausschließlich über den nativen GameServer-Rückruf zustellen.
  AppKit-Aufträge nur auf dem Hauptthread. Ein Ersatzthread ist kein GameThread.
- Vor Rücknahme alte GlobalID erneut auflösen, exakte Komponente und Besitzer
  prüfen, fremde Änderungen schützen. Alte Aufträge bei Besitzerwechsel verwerfen.
- Output-Pins über den originalen FlowConnectionManager benachrichtigen.
  Eine bloße gespeicherte Output-Zahl kann ohne Auswirkung bleiben.
- One-Hit-Kill und Schildzerstörung über die tatsächlichen feindlichen
  Health-Modelle anbinden. Das PlayerAssist-Ausgabeflag wird frameweise aus
  Einstellungen überschrieben; eine bloße Flag-Rücklesung belegt keine Wirkung.
  Angenommenen Schaden, Originalsetter, Feindlichkeit und Besitzer getrennt prüfen.
- Bewegung über die private, tatsächlich konsumierte Konfiguration ändern;
  `MovementState`-Ausgabewerte werden von der Engine neu berechnet. Zeitlupe
  über den Simulationsschritt prüfen, nicht allein über ein zurückgelesenes Flag.
- Mausmodus und Sichtbarkeit während Overlaybedienung halten; letzten echten
  Enginewunsch beim Schließen/Fokusverlust wiederherstellen. Gemeinsamen
  `MHTOverlayHost` und den gespeicherten Glasregler unten rechts erhalten.
- Vor Tests `docs/OVERLAY_INPUT.md` lesen, Diagnose und synthetische Prüfungen
  vorbereiten. Reversible Prüfungen im selben freigegebenen Lauf bündeln.
  Controls Maustastenpfad benötigt echten globalen Hardwarezustand; einen
  fehlgeschlagenen Fernsteuerungsklick nicht als belegten Eingabefehler behandeln.
- Keine Doppelstarts, keine Überschreibung geladener Testbibliotheken und kein
  Unload installierter nativer Rückrufe. Diagnosecode bleibt unter `Tests/`.
- Nur konkrete Nutzerfreigaben erlauben Spielstarts/-beenden. Vorhandene
  Freigaben weiterverwenden. Im aktuellen Auftrag ist lokales Testen/Laden erlaubt.
- Code, stabile externe Builds und Audit getrennt halten. Keine Binaries,
  Logs, Cacheverzeichnisse oder historische Testserien im Quellordner.
