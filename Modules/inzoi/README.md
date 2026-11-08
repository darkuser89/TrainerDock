# inZOI für TrainerDock

Eigenständiger nativer Trainer für Steam-Build **26264076**, Version
**5.4.95 (0.0.46)**, arm64. Andere Builds benötigen eine eigene Prüfung.
Die vom Nutzer genehmigte Originalprüfung bindet vier vollständige Dateien
über 78 SHA-256-Abschnitte; das Spielbundle bleibt unverändert.

Der Katalog enthält 20 deutsche Funktionen in fünf Gruppen: Bedürfnisse,
Karma und Ambitionen, Geld und Meow-Münzen, Fähigkeiten und Geschwindigkeit.
Geld, Meow-Münzen und Ambitionsabschluss sind ausdrückliche Einmalaktionen.
Der Glasregler unten rechts bleibt über den normalen Optionskanal gespeichert.

## Native Anbindung

`LuaEngine.mm` beobachtet originale geschützte Lua-Aufrufe des exakt gebundenen
Builds. B2-Aufträge laufen ausschließlich im beobachteten Simulationsthread.
B1-Aufträge verwenden die originale GameThread-Warteschlange und die zugehörige
VM-/Threadkennung. Keine Ersatzthreads oder Aufrufe einer fremden Lua-VM.

`RuntimeMod.mm` legt ausschließlich eigene Lua-Skripte in einem kurzlebigen,
sitzungsgebundenen Modverzeichnis außerhalb des Spielbundles ab und lädt sie
über die originale Modding-API. Das Modul enthält sämtliche Skripte selbst.
Beim regulären Ende entfernt es nur unveränderte eigene Dateien.

Die ursprünglichen Komponenten liefern Statistiken, Haushaltswährungen,
Fähigkeiten und Missionszustände. `MissionData.mm` lädt die originalen
Missionsdefinitionen einmal auf B1 und stellt ausschließlich validierte Zeilen
für B2 bereit. Der Ambitionsabschluss führt echte Missionsereignisse aus und
bestätigt anschließend den originalen Abschlusszustand.

Bedürfnisverlust sowie Karma- und Währungszuwachs werden anhand der beobachteten
Nettoänderung je Simulationsschritt skaliert. Gleichzeitig verrechnete Gewinne
und Ausgaben werden deshalb als Nettobetrag behandelt. Fähigkeiten-EP laufen
dagegen über den originalen `AddSkillExp`-Rückruf. Bewegungs- und Spieltempo
werden nativ gelesen, gesetzt und bestätigt; Ausschalten nimmt eigene
Tempoänderungen zurück, sofern das Spiel den Wert nicht inzwischen geändert hat.

## Entwicklung und Prüfung

Projektweite `AGENTS.md` und [modulspezifische Regeln](AGENTS.md) beachten.
Die Tests unter `Tests/InZOI` enthalten ausschließlich Entwicklungswerkzeuge;
sie werden nicht in das Produkt eingebunden. Private Diagnoseexporte sind im
Produktbuild nicht vorhanden.

```sh
python3 -B script/build.py --module inzoi
```

Synthetische Bridge-, HiDPI-, Cursor-, Warteschlangen- und Missionsparserprüfungen
ersetzen keine Ingame-Prüfung eines aktualisierten Spielbuilds.
