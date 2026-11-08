# Vampire Survivors

Die projektweite AGENTS.md und `$trainer-template` gelten. Dieses Modul enthält
den vollständigen eigenen Unity/Mono-Trainer; keine Spielklassen in App oder Core.

- Das erfasste Steamprofil 1.16.111 (Build 25984009) erhalten. UUID, originale
  arm64-Signatur/CDHash, vollständige Dateichecks und Managed-MVIDs erhalten.
  Neue Builds benötigen eigene Analyse und Wirkungstests. Spieldateien unverändert lassen.
- Das erfasste Epic-Profil 1.16.111 (64959298) verwendet `launchMode: "epic"`.
  Es hat dieselbe Hauptdatei-UUID wie Steam,
  aber einen eigenen CDHash und eigene Managed-MVIDs. Nur vollständige Store-Tupel
  akzeptieren, niemals einzeln gemischte Assemblies. Epic-Pfade über das passende
  Launcher-Manifest ermitteln; die gemeinsame Bundle-ID trennt die Stores nicht.
  Keine Steam-Umgebungsvariablen an Epic weitergeben. Online benötigt das Original
  den offiziellen Epic-Launcher-Login; Direktstart ohne dessen Argumente scheitert.
  Keine Anmeldung oder Netzwerkprüfung umgehen und keine Authargumente protokollieren.
  Der Epic-Launcher muss vor dem Trainerstart regulär beendet sein: sein laufender
  Cache überschreibt die temporäre Startzuordnung. Nicht automatisch beenden oder
  nach einem Fehler ohne Trainer starten. Den allgemeinen Startdienst verwenden;
  die eigene Spielanbindung bleibt vollständig in diesem Modul.
- Mono ausschließlich aus der bereits geladenen originalen Laufzeit binden.
  Bootstrap stellt nur einen Auftrag an UniTask; Gameplay läuft ausschließlich
  innerhalb des beobachteten eigenen Unity-Update-Rückrufs.
- Die 19 IDs und die gemeinsame Bridge erhalten. IDs 9–18 sind ausdrückliche
  Einmalaktionen. Hotkey-Modifier verwenden das kompakte Overlayformat (Shift = 1).
- Faktoren benutzen eigene EggFloat-Anteile. Natürliche Val-Zuwächse erhalten und
  fremd veränderte Anteile nicht blind zurückschreiben. Nur native Rücklesungen
  dürfen aktiv melden. Native Waffenbegrenzungen gelten weiterhin.
- Coins Collected bedeutet RunCoins, nicht RunPickups_Coins. Editorwerte für EXP,
  Guthaben und Statistik sind native Fließkommazahlen und dürfen nicht auf Integer
  gerundet werden. Revivals berücksichtigt UsedRevivals; Rerolls ist ein eigener Stat.
- Lokalen Besitzer und Kontextgeneration prüfen; keine Netzwerksperre ergänzen.
  Cursorfreigabe und isolierten MHTOverlayHost einschließlich Mauszustellung erhalten.
  Den gespeicherten Glasregler und HiDPI-Vertrag nicht entfernen.
- Tests und reale Beobachter bleiben unter Tests/VampireSurvivors. Prüfbibliotheken
  mit exakten C-Exports linken. Niemals geladene Kandidaten ersetzen oder ein bereits
  laufendes Spiel ein zweites Mal starten. Freigaben aus dem konkreten Auftrag beachten.
