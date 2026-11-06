# Herkunft

Die sechs bereitgestellten GPL-3.0-only-Trainer wurden als bearbeiteter Projektcode in vollständige Trainermodule übernommen. Alte Launcher, Demos, Diagnose-Starthelfer und Buildbestände gehören nicht zur neuen Anwendung.

- DeadIsland2: dead-island-2-trainer
- ResidentEvil: ResidentEvil2Trainer
- LiesOfP: LiesOfPTrainer
- Cyberpunk2077: Cyberpunk2077Trainer
- RoboCop: RoboCopTrainer
- CrimsonDesert: CrimsonDesertTrainer


## Dome Keeper

Neu implementiertes eigenständiges Modul aus der neutralen Trainervorlage, ohne
WeMod-Code oder Windows-Adressen. Das Nutzerbild diente nur als Funktionswunsch.
Identität und Bindung wurden an der bereitgestellten Steam-Installation 5.0.8.14
(Build 25038893) bestimmt: originale arm64-UUID, Signatur-Identifier/CDHash und
PCK-Verzeichnisfingerprint stehen im Profil. Die C-Schnittstellenregistrierungen
wurden im unveränderten arm64-Executable abgeglichen und ihre Prologe im Modul
hinterlegt. Propertynamen und native Berechnungen wurden in den unverschlüsselten
Spielressourcen überprüft; Originalskripte oder Ressourcen werden nicht ausgeliefert.
Die ABI-Definitionen richten sich nach der offiziellen Godot-4.3-C-Schnittstelle.

## Escape from Duckov

Eigenständiger Trainer aus der neutralen Vorlage für die bereitgestellte native
Steam-Installation 2.3.30, Build 24013657. Das Nutzerbild liefert Funktionswünsche;
kein FLiNG-/Windows-Trainercode und keine fremden Adressen werden übernommen.
Originale arm64-UUID und SHA-256 der angebundenen Managed-Assemblies stehen im Profil.
MonoRuntime.mm nutzt die öffentliche Einbettungs-API der bereits geladenen originalen
Mono-Laufzeit. Managed/Trainer.cs und Safety.cs sind eigener Trainercode; originale
Assemblies, Spielskripte und Save-Inhalte werden nicht kopiert oder ausgeliefert.

## No Man’s Sky

Die vom Nutzer bereitgestellten GPL-3.0-only-Quellen aus `NoMansSkyTrainer` wurden
als unabhängiges Modul übernommen. Alte Launcher-, Demo- und Builddateien werden
nicht ausgeliefert. Die Referenz bleibt unverändert.

Native Funktionen, Update-Rückruf und relevante Datenzugriffe wurden am aktuellen
Original-Executable abgeglichen: Steam-Build 26386568, arm64-UUID
`1FABCC98-D6B6-3905-BF1B-823BD5033DA9`. Die vom Nutzer nach Steam-Dateiprüfung
genehmigten vollständigen Originalhashes stehen im Profil. Die Integration ergänzt
TrainerDock-Protokoll, separate Overlay-Paneldarstellung und aktuelle HiDPI-Unterstützung.
