# Lies of P – TrainerDock-Trainer

Steam 1.14.0 arm64, ausschließlich der bereits gebundene Originalbuild.
Der vollständige Trainer einschließlich nativer Spielanbindung und Overlay
liegt in diesem Modul; der Launcher enthält keine Spieladressen.

Ab Modulversion 2.0.0 gibt es **36 Funktionen ohne Hauptschalter**. Jede Option
funktioniert direkt im bestätigten Spielkontext. Einmalaktionen benötigen
keinen zuvor eingeschalteten Cheat. „Alles aus“ löst weiterhin alle eigenen
Wirkungen; Prozessidentität, GameThread, lokale Besitzer und Rücklesen bleiben Pflicht.
Die vorhandenen Kürzel der echten Funktionen bleiben unverändert;
Strg+Umschalt+1 ist nicht mehr mit einer Aktivierungsaktion belegt.

Der Katalog ist `liesofp-36-v2`. Alte private Auswahlformate werden unter
Entfernen des früheren Eintrags 0 umgeordnet. Die allgemeine Launcher-Auswahl
verwendet `selectionVersion: "2"`, damit alte numerische IDs nicht auf andere
Funktionen zeigen. Die alte Auswahl bleibt separat gespeichert; neue Auswahl
und Werte werden unabhängig davon gespeichert. Kein automatischer Einmalaufruf.

Regressionstests prüfen direkte Schalter, Einmalaktionen bei ausgeschalteter
erster Funktion, Altkatalog-Zuordnung und weiterhin abgewiesene fremde Prozesse.
Die Änderung wurde gebaut und synthetisch geprüft; dafür wurde kein Spiel gestartet.

```sh
python3 -B script/build.py --module lies-of-p
```

Ausgabe: `~/Library/Developer/TrainerDock/Modules/lies-of-p.mhtmodule`.
