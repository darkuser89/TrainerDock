# House Flipper

Eigenständiger Trainer für Steam 1.26252, Build 25247477 (Intel unter Rosetta).
Der Launcher bleibt arm64 und benötigt macOS 27 oder neuer.

| Funktion | Wirkung | Taste |
|---|---|---|
| Unbegrenztes Geld | Hält das interne Guthaben bei mindestens einer Milliarde; die sichtbare Währung wird vom Spiel umgerechnet. | F1 |
| Unbegrenzte Fähigkeitspunkte | Hält mindestens neun freie Punkte je tatsächlich freigeschalteter Kategorie bereit. Vorteile werden im Spiel ausgewählt. | F2 |

Ein bereits offenes Verbesserungsmenü gegebenenfalls über einen Tabwechsel
aktualisieren. Gesperrte Kategorien werden nicht freigeschaltet. Ausschalten löst
eigene unveränderte Anhebungen; gekaufte Vorteile werden nicht zurückgenommen.

Der vollständige Trainer einschließlich isoliertem Ingame-Overlay, Mausfreigabe
und gespeichertem Glasregler ist Bestandteil dieses Moduls. Die native Mono-
Anbindung verwendet den beobachteten originalen Unity-Rückruf, typisierte Methoden
und GC-geschützte Besitzer. Profilgrenzen und Besonderheiten stehen in [AGENTS.md](AGENTS.md).

```sh
python3 -B script/build.py --module house-flipper --configuration Release
```

Ausgabe unter `~/Library/Developer/TrainerDock/Modules/house-flipper.mhtmodule`.
Private Entwicklungshelfer liegen ausschließlich unter `Tests/HouseFlipper`;
`BuildCandidate.py` baut und prüft, startet aber kein Spiel. Spieltests und
Veröffentlichungen benötigen einen entsprechenden Auftrag. Weitere Stores und
Spielbuilds benötigen eigene geprüfte Profile; keine stillen Hashupdates.
