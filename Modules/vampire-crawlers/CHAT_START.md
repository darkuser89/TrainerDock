# Weiterentwicklung dieses Trainers

Lies die zentrale und die modulbezogene AGENTS.md, README.md sowie
`docs/MODULES.md` und `docs/ARCHITECTURE.md`. Verwende `$trainer-template` und
`graphify-offline`. Prüfe Status/Diff und schütze bestehende Änderungen.

Dieses Modul enthält den vollständigen nativen IL2CPP-Trainer samt Overlay.
Das erfasste Steam-Profil ist freigegeben; die konkreten bestätigten Prüfungen und
Grenzen stehen in README.md. Neue Profile zunächst deaktiviert entwickeln.
Keine synthetischen Tests als Spielnachweis ausgeben.
Nur der erfasste Steam-Build darf die ausdrücklich genehmigte SHA-256-Originalprüfung
verwenden. Andere Builds/Stores brauchen eigene Identität, Anbindung und Freigabe.

Spielstarts und Beenden nur nach entsprechendem Nutzerauftrag. Mehrere Funktionen
in einer Instanz prüfen und vorhandene Instanzen vor jedem Start ausschließen.
Keine Änderungen an Spieldateien, Signaturen, Entitlements oder Saves.
