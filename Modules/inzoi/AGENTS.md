# inZOI: Regeln für weitere Arbeiten

Die projektweite `AGENTS.md` gilt vollständig. Dieses Modul bindet ausschließlich
Steam-Build 26264076 und UUID `B1AA1CC2-C72B-3D8A-AC90-1E8C9155E519`.
Keine stillen Hashupdates, fremden UUIDs oder Änderungen am Spielbundle.

- B1 und B2 sind verschiedene Lua-VMs auf unterschiedlichen Originalthreads.
  `IZOnSimulationThread` und `IZOnPresentationThread` strikt zuordnen. Die
  Darstellungsschlange prüft die beobachtete VM-/Threadkennung erneut.
- `inzoi.cli.execute` nimmt genau eine Befehlszeile entgegen. Datenbankabfragen
  gehören auf B1. Originale Missionsdaten dort einmal laden und validieren;
  keine synchronen B1-Abfragen aus einem blockierten B2-Auftrag.
- Die originale Funktion `LuaPrint` hat bei einer eigenen Diagnoseausgabe einen
  Stackschutz-Abbruch verursacht. Keine `print`-Aufrufe in eigene Runtime-Skripte
  aufnehmen; keine großen Tabellen oder Argumente über diese Ausgabe schicken.
- Komponenten über die tatsächlich gebundenen `EB2ComponentType`-Werte lesen.
  `ComponentsMap:ToTable` ist kein geeigneter Zugriff auf Shared-Pointer-Werte.
  Projektstrukturen liegen unter `INZOI`, nicht unter `UE`.
- `TArray:Get` liefert Strukturkopien. Native Triggerpuffer ausschließlich über
  `GetRef` verändern; Bedingungen vollständig gegen Originaldefinitionen prüfen,
  bevor der erste Trigger geschrieben wird. Ambitionen sind Einmalaktionen.
- Der originale Fähigkeiten-Override heißt
  `B2/Components/B2SkillComponent.lua:Override_AddSkillExp(comp,id,exp)` ohne
  zusätzliches `self`. Nur Aufträge des gesteuerten Zoi verändern. Das native
  Fähigkeitenfeld heißt `Experience`; Währungen heißen `Mew` und `Nyang`.
- Ein TimeManager-Rückruf pro Simulationsschritt genügt. Keine periodische
  Abfrage je Zoi und kein erneutes Mounten bereits geladener eigener Skripte.
- Eigene Moddateien sitzungsgebunden anlegen, fremde Verzeichnisse nicht
  überschreiben und beim Ende nur bytegleich eigene Dateien entfernen.
- `Movement.mm` muss veraltete Besitzeraufträge verwerfen, native Rücklesung vor
  „Aktiv“ verlangen und zwischenzeitliche Spieländerungen beim Ausschalten
  erhalten. Die zugehörigen Grenztests liegen unter `Tests/InZOI`.
- Mauszeiger, Klickzuordnung und Glasregler getrennt prüfen. Menübedienung allein
  bestätigt keine freie Maus im Gameplay. Geladene Bibliotheken nie überschreiben;
  Korrekturen und mehrere Funktionen in einem genehmigten Lauf bündeln.
