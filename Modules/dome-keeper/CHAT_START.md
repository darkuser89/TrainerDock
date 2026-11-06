Arbeite am bestehenden echten TrainerDock-Trainer unter Modules/dome-keeper. Lies zuerst
AGENTS.md in diesem Ordner und im Projekt sowie README.md und docs/MODULES.md.
Verwende graphify-offline. Prüfe Status und vorhandene Änderungen.

Native Anbindung: GodotABI.mm, GodotBindings.h, DomeScript.hpp. Kein fremdes Spiel,
keine Test-Fixtures oder simulierten Effekte ins Produkt einbauen. Unbekannte
Spielbuilds bleiben gesperrt. Launcher und Spielinstallation nicht mit Spiellogik
oder Trainerdateien verändern. Nur den eigenständigen Trainer bauen; Änderungen am
gemeinsamen Host nur für tatsächliche allgemeine Anforderungen.

Synthetische Tests sind erlaubt. Originalspielstarts und weitere Ingame-Tests
benötigen einen entsprechenden aktuellen Nutzerauftrag. Im Ergebnis klar zwischen
Bau, synthetischer Prüfung, nativer Rückleseprüfung und beobachteten Kampfeffekten
unterscheiden. Builds außerhalb des Quellordners halten.
