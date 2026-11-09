# Prodeus – nativer Einzelspieler-Trainer

Projektweite `../../AGENTS.md`, `../../docs/MODULES.md` und
`../../docs/OVERLAY_INPUT.md` gelten weiterhin.

- Auf ausdrücklichen Nutzerauftrag ausschließlich Einzelspieler. Den tatsächlichen
  originalen Spielmodus und lokalen Spieler prüfen; Koop, Versus, Netzwerkraum
  und Editor nicht als Einzelspieler behandeln. Internetzugang allein ist keine
  Mehrspieler-Sitzung. Bei Modus-/Besitzerwechsel Aufträge verwerfen und nur eigene
  Dauereffekte lösen. Das ist eine spielbezogene Nutzervorgabe.
- Freigegebene Originalidentität: Steam-App 964800, Build 9679369,
  Bundle 1.0.2 (0), arm64-Haupt-UUID DEF4DD2F-8142-39D2-8BD8-BEB64BACC720.
  Steam meldete die Installation als korrekt; macOS beanstandet steam_api.bundle.
  Der Nutzer hat die vollständige SHA-256-Prüfung der sechs im Profil genannten
  Originaldateien ausdrücklich genehmigt. Alle 20 Abschnitte lückenlos prüfen;
  keine stillen Hashupdates oder Freigaben weiterer Builds.
- GameAssembly und UnityPlayer zusätzlich an ihre tatsächlich ermittelten UUIDs
  binden. Keine Spielsignaturen, Originaldateien oder Saves verändern.
- IL2CPP-Felder und Methoden typisiert auflösen, Referenzen mit GC-Handles schützen.
  Effekte ausschließlich auf dem beobachteten originalen Unity-PlayerLoop-Rückruf.
  Kontextabfragen begrenzen; ohne Effekt/Auftrag keine Spielsuche im Framepfad.
- Schlüssel, Karte und Fähigkeiten sind ausdrückliche Einmalaktionen und dürfen
  weder bei Start noch bei Poll oder Wiederherstellung wiederholt werden.
- `GameInfo.inRoom` ist kein Mehrspielerbeleg: Das originale `SetGameType`
  setzt es auch im Einzelspieler. Tatsächliche Netzwerk-/Offline-Raumzustände,
  Koop-/Versus-/Editorflags und lokale Besitzer gemeinsam prüfen. Der geladene
  Einzelspieler zeigte `inRoom=true`, `IsMultiplayer=false`, `OfflineMode=true`.
- Das aktive Magazin liegt in `fpwInstances[currentWeapon].ammoClip`, mit
  geprüften Spieler-Rückverweisen und Waffenindex. `controller.ammoClip[]` ist
  lediglich der Ausrüstungszwischenspeicher und belegt keine Nachladewirkung.
  Ein ausdrücklich vergebener Doppelsprung muss beim Lösen einer temporären
  Sprung-Lease erhalten bleiben.
- Das vollständige Overlay samt Mausfreigabe und gespeichertem Glasregler bleibt
  in diesem Modul. Keine Spiellogik im Launcher ergänzen.
- Tests unter `../../Tests/Prodeus` sind synthetische Vertrags-/ABI-Prüfungen und
  gezielte lokale Prüfhilfen; niemals im Produkt ausliefern oder als Ingame-Beleg
  ausgeben. Nur dieses geänderte Modul bauen; keine anderen Trainer versionieren.
