# House Flipper – eigenständiger nativer Trainer

Die projektweite `../../AGENTS.md`, `../../docs/MODULES.md` und
`../../docs/OVERLAY_INPUT.md` gelten weiterhin.

- Ausschließlich die zwei angeforderten echten Funktionen anbieten: unbegrenztes
  Geld und freie Fähigkeitspunkte. Kategorien und Vorteile nicht automatisch
  freischalten oder auswählen; vorhandene Spielerentscheidungen erhalten.
- Der Nutzer hat nach fehlerfreier Steam-Dateiprüfung ausschließlich Steam-App
  613100, Build 25247477, Version `[release] 1.26252 (ab1aa)` (0), x86_64-UUID
  6D82BA8C-38A6-3A10-8CDE-BDD368B8F4CF für `sha256-original` freigegeben.
  Das Original ist unsigniert. Die elf im Profil erfassten Originaldateien in
  ihren 17 lückenlosen Abschnitten vollständig prüfen. Keine stillen Hashupdates,
  weiteren Buildfreigaben oder Änderungen an Spielsignaturen und Spieldateien.
- Der Launcher bleibt arm64/macOS 27+. Nur diese explizite x86_64-Runtime läuft
  mit dem originalen Intelspiel unter Rosetta. Keine automatische Architekturauswahl.
- Die originalen Mono-Assembly-MVIDs, nativen Image-UUIDs und exakten Methodentypen
  gemeinsam prüfen. Obfuskierte Namen nicht durch ähnliche Methoden ersetzen;
  Tokenbindungen nur für den erfassten Originalbuild verwenden.
- Spielzugriffe ausschließlich im tatsächlich beobachteten originalen Unity-
  Rückruf. Besitzer mit GC-Handles schützen, Domain-/Profilwechsel beachten.
  Ohne aktive Wirkung darf der Framepfad keine Spieler-/Inventarsuche auslösen.
- Kein Save-Editing. Werte ausschließlich über Originalfunktionen im laufenden
  Spiel bearbeiten und echte Wirkung zurücklesen. Nur eigene unveränderte Werte
  zurücknehmen; ausgegebene Beträge oder ausgewählte Vorteile nicht rückabwickeln.
- Das vollständige Overlay, gespeicherter Glasregler und Mausfreigabe gehören
  in das Modul. Keine House-Flipper-Spiellogik in Launcher oder gemeinsamem SDK.
- Tests und sitzungsgebundene Entwicklungsprüfer bleiben unter
  `../../Tests/HouseFlipper`, temporäre Artefakte außerhalb des Codes. Keine
  Testprüfer in die Produktbibliothek linken. Build und synthetische Prüfungen
  sind keine Ingame-Bestätigung. Keine Netzwerksperre ergänzen.

## Ursprüngliche Fähigkeitenprüfung dieses Builds

- `SkillCategory.enabled` ist ein gespeicherter Konstruktor-Snapshot; der alte
  `playerProgress`-Backlink ist kein maßgeblicher Besitzerbeleg. Die aktive Kette
  `GameManager.player.progress.skills` und deren typisierte Kategorie-/`SkillInfo`-
  Referenzen samt übereinstimmendem `skillType` verwenden.
- Die echte Verbesserungsansicht filtert ihre Kategorien in `PerksView`
  (`0x060367C3`) über `SkillCategory`-Getter `0x06020398` (Boolean, keine Argumente).
  Genau diesen originalen Getter verwenden, auch wenn Snapshot oder Backlink fehlen.
  Freigaben im Kontextpoll oder nach Besitzer-/Descriptorwechsel prüfen; nicht
  elf reflektierte Getter in jedem Frame erneut aufrufen.
- `numberOfPerksAvailable` ist das echte freie Punktefeld. Der originale Kauf
  `0x0602039B` zieht einen Punkt ab und wendet den gewählten Vorteil an.
  `PerkVisualizer.RefreshPerk` (`0x06036794`) liest das Feld für die Bedienfreigabe.
  Eine native Wertebestätigung belegt keine Aktualisierung eines bereits offenen
  Menüs; diese separat mit Auswahl eines Vorteils prüfen. Keine unbekannten
  Ereignisse oder Vorteilskäufe zur Anzeigeaktualisierung auslösen.
