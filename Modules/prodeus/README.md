# Prodeus – Einzelspieler-Trainer

Eigenständiges TrainerDock-Modul für Steam 1.0.2, Build 9679369, auf Apple Silicon
mit macOS 27 oder neuer. Ausschließlich für den Einzelspieler; Koop, Versus und
Editor werden nicht freigegeben.

| Funktionen | Tasten |
|---|---|
| Unbegrenzte Gesundheit, Rüstung und Sprünge | F1–F3 |
| Roten, grünen, blauen und gelben Schlüssel geben | F4–F7 |
| Automatische Karte, Doppelsprung und Sprintstoß geben | F8–F10 |
| Unbegrenzte Munition und kein Nachladen | F11–F12 |
| Spielgeschwindigkeit | ⇧F1 |

Schlüssel, Karte und Fähigkeiten sind ausdrückliche Einmalaktionen. Sie werden
weder beim Start noch durch gespeicherte Auswahlen wiederholt. „Alles aus“ löst
eigene Dauereffekte; ausdrücklich vergebene Fähigkeiten bleiben erhalten.

Das vollständige Overlay mit Mausfreigabe und gespeichertem Glasregler gehört zum
Modul. Die IL2CPP-Anbindung arbeitet ausschließlich im beobachteten originalen
Unity-Rückruf mit typisierten Metadaten und geschützten Besitzerreferenzen.
Profilgrenzen und native Besonderheiten stehen in [AGENTS.md](AGENTS.md).

```sh
python3 -B script/build.py --module prodeus --configuration Release
```

Buildprodukte liegen außerhalb des Codes unter `~/Library/Developer/TrainerDock`.
Private Entwicklungshelfer unter `Tests/Prodeus` gehören nicht ins Produkt.
Spieltests und Veröffentlichung benötigen einen entsprechenden Nutzerauftrag.
Weitere Originalbuilds oder Stores benötigen eigene geprüfte Profile.
