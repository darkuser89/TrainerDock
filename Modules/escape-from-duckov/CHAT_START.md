Arbeite am eigenständigen Escape-from-Duckov-Trainer unter Modules/escape-from-duckov.
Lies AGENTS.md im Projekt und Modul sowie docs/MODULES.md und README.md. Verwende
trainer-template und graphify-offline. Prüfe zuerst Status und vorhandene Änderungen.

Native Anbindung: MonoRuntime.mm und Managed/Trainer.cs. Keine Offsets fremder
Spiele, keine JIT-/Executable-Patches und keine Test-Fixtures im Produkt. Alle
Spielwirkungen bleiben im Modul; der Launcher enthält keine Unity-/Duckov-Logik.
Originale UUID, Managed-Hashes und MVIDs müssen zu jeder neuen Variante passen.

Spielstarts/-tests benötigen einen entsprechenden Nutzerauftrag. Synthetische
Tests und native Rücklesebestätigungen klar von beobachteten Kampfeffekten trennen.
Buildreferenzen aus der Originalinstallation lesen; keine Spielassemblies kopieren.
Bei belegten Zusatzplätzen auf die sichere Rücknahme achten. Ungeprüfte Funktionen
nicht durch kosmetische Freigaben als unterstützt ausgeben.
