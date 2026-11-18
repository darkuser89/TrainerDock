# Frostpunk

Eigenständiges, freigegebenes TrainerDock-Modul für **Frostpunk** mit 15 nativen
Funktionen, getrennt von Frostpunk 2. Die Spielanbindung und die unten beschriebenen
Wirkungen wurden im vorhandenen Spielstand „Ein neues Zuhause“, Tag 37, geprüft.

## Unterstützter Originalbuild

Das freigegebene Steam-Profil bindet ausschließlich diese Originalidentität:

- Steam-App 323190, Build 15262773.
- Bundle `com.11bitstudios.frostpunk`, Version 1.1.1 (20201216.0).
- Sichtbare Spielversion 1.6.1; Originalprogramm `Frostpunk`, Architektur x86_64.
- Image-UUID `381A9DB7-5849-39B1-85BC-208861544E41`.

Die zwölf erfassten Originaldateipfade sind über 19 vollständige SHA-256-Abschnitte
gebunden, einschließlich der verschachtelten `hidapi`-Bibliothek.
Der Originalvergleich erreicht Titelmenü und den vorhandenen Stadtstand ohne
Trainer. Die gesondert bestätigten Trainerprüfungen stehen weiter unten.
Spieldateien und Signaturen bleiben unverändert.

## Implementierte Funktionen und stabile IDs

| ID | Funktion | Bedienung |
|---|---|---|
| 0 | Kohle hinzufügen | Einmalaktion mit Mengenwert |
| 1 | Holz hinzufügen | Einmalaktion mit Mengenwert |
| 2 | Stahl hinzufügen | Einmalaktion mit Mengenwert |
| 3 | Dampfkerne hinzufügen | Einmalaktion mit Mengenwert |
| 4 | Rohkost hinzufügen | Einmalaktion mit Mengenwert |
| 5 | Prothesen hinzufügen | Einmalaktion mit Mengenwert |
| 6 | Unbegrenztes Lager | Dauerschalter |
| 7 | Strukturprofile hinzufügen | Einmalaktion; Anzeige und Nutzung szenarioabhängig |
| 8 | Stahlverbundstoffe hinzufügen | Einmalaktion; Anzeige und Nutzung szenarioabhängig |
| 9 | Dampftauscher hinzufügen | Einmalaktion; Anzeige und Nutzung szenarioabhängig |
| 10 | Sofort bauen | Dauerschalter |
| 11 | Sofort forschen | Dauerschalter |
| 12 | Gesetze ohne Wartezeit | Dauerschalter |
| 13 | Kein Generatorstress | Dauerschalter |
| 14 | Spielgeschwindigkeit | Dauerschalter mit Faktor |

Ressourcenaktionen dürfen beim Wiederherstellen einer gespeicherten Auswahl niemals
erneut ausgeführt werden. Die Standardwerte sind 1.000 Einheiten beziehungsweise
10 Dampfkerne; der Tempofaktor ist 2,5. Die Auswahl enthält ausschließlich Mengen
und Aktivierungswünsche, keine gespeicherten Spielobjektadressen.

Die neun Ressourcenaktionen verändern einmalig den vorhandenen nativen Bestand
über den originalen Ressourcensetzer und prüfen die tatsächliche Bestandsdifferenz.
Originale Lagergrenzen bleiben wirksam; eine nur teilweise übernommene Menge wird
als solche gemeldet. Verborgene Prothesen- oder DLC-Bestände werden dadurch weder
sichtbar noch als Szenario freigeschaltet.

„Unbegrenztes Lager“ hebt die Lagergrenzen der neun identifizierten Ressourcen
und der Essensrationen auf mindestens 1.000.000 an. Unbekannte Rohstoffe und Leichen
bleiben ausgeschlossen. Beim Ausschalten werden nur eigene, unverändert
vorgefundene Erweiterungen zurückgenommen; fremde Lageränderungen bleiben erhalten.

„Sofort bauen“ verwendet den originalen Schalter für Bau- und Abrissarbeiten.
„Sofort forschen“ verwendet den originalen Forschungsschalter; laufende Forschung
wird bei ihrer nächsten Spielaktualisierung abgeschlossen. Beides ersetzt weder
Kosten noch Freischaltungen. Bereits fertiggestellte Arbeiten und Forschung
werden beim Ausschalten nicht rückgängig gemacht.

„Gesetze ohne Wartezeit“ setzt die verbleibende Wartezeit über den originalen
Setzer auf null. Gesetzesvoraussetzungen gelten weiterhin. Ausschalten beendet
weitere Rücksetzungen, stellt aber bereits abgelaufene Wartezeit nicht wieder her.
„Kein Generatorstress“ hält einen vorhandenen Generator über dessen Originalfunktion
bei null Stress; Ausschalten beendet die weitere Stresssenkung. Der Tempofaktor
verwendet den originalen Spieltimer und nimmt beim Ausschalten die eigene
Timeränderung unter Erhalt fremder Änderungen zurück.

Das Ingame-Overlay aus der neutralen Vorlage zeigt oben links **Frostpunk** und
enthält unten rechts den gespeicherten Glasregler.

## Bestätigte Prüfungen im Originalspiel

Die laufenden Tests verwenden den bestehenden Tag-37-Spielstand; ein neues Spiel
wurde dafür nicht angelegt. Auch der letzte Abschlusskandidat startete regulär und
lud erneut denselben vorhandenen Spielstand.

- Alle neun Ressourcenaktionen wurden mit jeweils `+1` ausgeführt und anhand
  der nativen Originalbestände bestätigt, einschließlich Prothesen und verborgener
  DLC-Rohstoffe. Nachfolgende Statusabfragen wiederholten die Einmalaktionen nicht.
- Der Lagerschalter setzte zehn identifizierte Lagerkapazitäten auf `1000000`
  und stellte beim Ausschalten deren vorherige Werte exakt wieder her. Die
  Ressourcenmengen änderten sich dabei nicht; der native Leichenbestand
  (`Bodies`) blieb unberührt.
- Eine Baracke stand bei 0 % und wartete auf Arbeiter. Nach Aktivierung von
  „Sofort bauen“ war sie unmittelbar funktionsfähig; dies wurde in der
  Spieloberfläche beobachtet. Der Abriss einer leeren Baracke wurde mit
  eingeschalteter Funktion ebenfalls sofort abgeschlossen.
- Eine laufende Forschung bei 40 % wurde mit dem originalen Sofortforschungs-Bit
  512 nach drei Spielminuten abgeschlossen; der Abschluss wurde in der Spieloberfläche
  beobachtet.
- Beim Ausschalten der eigenen Sofortschalter blieb der bereits vorhandene fremde
  Schalter-Maskenwert `8` erhalten.
- Die originale Gesetzeswartezeit wurde über ihren nativen Setzer von
  `1932735283200` auf `0` gesetzt und zurückgelesen. Dies sind die originalen
  Ganzzahlwerte, keine in Sekunden umgerechneten Angaben.
- Bei in der Spieloberfläche aktivierter Generatorüberlastung wurde natürlich
  angestiegener Stress von `0.0048430194` auf `0` gesenkt. Nach Ausschalten des
  Schutzes stieg der Stress wieder natürlich auf `0.0124119343`. Die Angaben sind
  die nativen Stresswerte, keine Prozentumrechnung.
- Der Spieltimer-Faktor `1.5` wurde nativ gesetzt und zurückgelesen; Ausschalten
  stellte den ursprünglichen Faktor `1` wieder her.
- Ein echter Klick auf den Lagerschalter wirkte. Ein Klick auf den Glasregler
  zeigte 92 % in der Oberfläche. Der Nutzer bestätigte im abschließenden
  Kandidaten ausdrücklich, dass Lagerschalter und Glasregler mit der echten
  Maus funktionieren.

## Prüfgrenzen

- Die Bestandsänderungen verborgener DLC-Rohstoffe sind nativ bestätigt. Ihre
  tatsächliche Nutzung im Szenario „Der letzte Herbst“ wurde nicht geprüft.
- Ingame-FPS-Messungen wurden nicht durchgeführt. Aus den synthetischen
  Leerlaufprüfungen folgt kein gemessener FPS-Nachweis.
- Andere Stores und weitere Spielbuilds wurden nicht geprüft und sind durch
  dieses Profil nicht freigegeben.

Der erste private Trainerstart blieb vor dem Menü im Manifest-Dateizugriff des
zusätzlichen Diagnosehelfers hängen. Der redundante Dateizugriff ist entfernt;
die Initialisierung wartet auf den originalen SDL-Rückruf. Der korrigierte Helfer
wurde im abschließenden Testlauf verwendet. Er ist ausschließlich Testcode und gehört
nicht in das veröffentlichte Trainermodul.

## Synthetische Prüfungen

`Tests/Frostpunk/CatalogTests.m` prüft die produktive Katalog-/Auswahlnormalisierung:
Ressourcen als Einmalaktionen, endliche begrenzte Mengen, ganzzahlige Ressourcen,
Tempo als nicht ganzzahliger Faktor, unbekannte IDs und sitzungsgebundene Nachrichten.
Tests bleiben vom Produkt ausgeschlossen.

Der private vollständige Prüfbuild besteht außerdem native Ressourcen-/Engine-
Grenztests, Bridge-Tests und die tatsächlichen Overlay-/Cursor-Pixelprüfungen bei
1×/2× und verschiedenen Zoomstufen. Geprüft werden unter anderem Zahlenbereiche,
Einmalaktionsschutz, Besitzerwechsel, fremde Werte, eigene Rücknahme und Leerlauf.
Das sind synthetische Prüfungen, keine Ingame- oder FPS-Nachweise.

`Tests/Frostpunk/BuildCandidate.py --game /pfad/Frostpunk.app` und
`BuildIngameProbe.py` bauen nur den privaten Kandidaten und den sitzungsgebundenen
Nur-Lese-Prüfer unter `~/Library/Developer/TrainerDock/Tests/Frostpunk`.
Sie starten oder beenden keine Spiele und schalten das Produktprofil nicht frei.

Das Modul wird separat mit
`python3 -B script/build.py --module frostpunk --configuration Release` gebaut;
dies baut nicht den Launcher und startet kein Spiel. Veröffentlichungsablauf:
[RELEASING.md](../../docs/RELEASING.md).
