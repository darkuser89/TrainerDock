# Weiterarbeit am The-Long-Dark-Trainer

Zuerst die projektweite AGENTS.md, dieses Moduls README.md und
`docs/OVERLAY_INPUT.md` lesen. `$trainer-template` und `graphify-offline` verwenden.
Keine neue Vorlage erzeugen: `Modules/the-long-dark` enthält den eigenständigen
nativen Trainer. Der Launcher benötigt keine Spielkenntnis.

Nur Steam 2.60 (0), Build 26450964 ist freigegeben. UUIDs, sieben vollständige
Originaldateien und gespeicherte Hashes müssen unverändert passen. Neue Builds
nicht still freigeben. Spielsignaturen, Spieldateien und Saves nicht bearbeiten.

Alle 44 Funktionen sind nativ angebunden. README.md unterscheidet tatsächliche
Spieltests, geprüfte Originalpfade und nicht durchgeführte Ende-zu-Ende-Prüfungen.
Waffen, reale Munitionsabnahme, fertige Herstellung und originaler Speicherabschluss
sind bestätigt. Todesschutz wurde über den originalen Löschpfad mit eigener
Wegwerfdatei geprüft, kein echter Spielertod ausgelöst. Schusswaffenschaden und
Projektilübergabe sind bestätigt, kein gezielter Tierabschuss durchgeführt.
Keine Erfolge aus bloßer Zustellung ableiten. Keine fremden Spieladressen übernehmen.

IL2CPP-Referenzsetter erwartet das Objekt selbst, nicht dessen lokale Adresse.
`Inventory.m_Items` ist eine Werttypenliste. `Tests/TheLongDark/NativeContractTests.mm`
sichert diese Grenzen ab. GameThread-, Besitzer-, Lade- und Rücknahmeverträge erhalten.

Für Survival-Schnellspeichern `GameManager.SaveGameAndDisplayHUDMessage` verwenden;
`InputManager.ExecuteQuickSaveAction` lieferte hier keinen Speicherabschluss.
Plattformspezifische IL2CPP-Typen wie `SteamCloudManagerPC` können im geladenen
macOS-Image fehlen: optionale Adapter nur bei tatsächlich vorhandenem Typ anbinden.
`ItemLiquidVolume` ist ein acht Byte großer Werttyp mit originalen Fabriken und `Max`.

Tests im Spiel bündeln; bestehende Instanz und geladenen Bibliothekspfad zuerst
prüfen. Keine geladenen Bibliotheken überschreiben. Diagnosequellen nur unter Tests,
Builds außerhalb des Codes im stabilen TrainerDock-Buildbaum. Keine automatischen
Spielstarts oder Neustarts aus dieser Anleitung ableiten.
