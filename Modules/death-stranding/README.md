# Death Stranding Director’s Cut

Eigenständiges natives TrainerDock-Modul für die Mac-App-Store-Version 1.1.4,
Build 0.5376581.0 (Anzeige im Spiel: 1.004). Entwicklung noch nicht abgeschlossen:
Der Katalog enthält die 26 gewünschten IDs; 15 besitzen noch keine freigegebene
native Implementierung und bleiben ausdrücklich deaktiviert.

## Native Funktionen

Implementiert sind Blut/Leben, Bewusstsein, Ausdauer, langfristige Erschöpfung,
Schuhhaltbarkeit, Ausrüstungsakku, Standreserve im Wasser, Tragfähigkeit,
Spielgeschwindigkeit, BB-Stress und das explizite Setzen chiraler Kristalle.
Die Haltbarkeitsfunktion gilt für getragene Schuhe, nicht für sämtliche Ausrüstung.
Die Nachfüllschalter beenden beim Ausschalten das Nachfüllen; sie erzeugen keine
zusätzliche Verletzung und stellen keinen früheren Verbrauch wieder her.
Kristalle werden ausschließlich durch eine ausdrückliche Einmalaktion verändert.

Die Wasserfunktion (F11) hält die separate Stand-/Atemreserve voll, deren nativer
Verbrauch vom normalen Ausdauerwert getrennt ist. Das Auffüllen, die laufende
Erhaltung und das Abschalten wurden im Originalprozess geprüft; der Nutzer hat
stabilen Stand an derselben flachen Wasserstelle bestätigt. Tiefes Wasser, starke
Strömung und allgemeiner Sturzschutz wurden nicht geprüft.

Tragfähigkeit (F6) bearbeitet die beiden nativen Traglast-Basisgrenzen des aktuellen
Spielers. Der originale Rechner berücksichtigt weiterhin Ausdauer und Spielboni.
150 und 180 wurden einschließlich der berechneten Grenze und Rücknahme auf die
ursprünglichen Werte geprüft; der Nutzer bestätigte die Anzeige im Frachtmenü.
Spielgeschwindigkeit (⌥F12, 0,25–3) steuert Welt, Spieler und Kamera gemeinsam über
einen eigenen Controller-Auftrag. 0,5 und 1,5 sowie Rücknahme auf eins wurden nativ
geprüft; der Nutzer bestätigte die höhere Bewegungsgeschwindigkeit. Beim Ausschalten
wird nur der eigene Auftrag zurückgenommen. Keine anderen Zeitanforderungen löschen.

Kein BB-Stress (F5) verwendet die originale Stressroutine. 500 → 0, laufende
Unterdrückung, korrekte Aktiv-Anzeige und erneuter Stress nach Ausschalten wurden
im selben Originalprozess geprüft. Der Prüfer stellte den Ausgangswert wieder her.
Steuerauftrag und Serialisierungsabbild dürfen nicht mit aktuellem Stress verwechselt
werden; nur aktuelle Spielerwerte bestätigen die Wirkung.

## Originalidentität und Zustellung

Bundle `com.505games.deathstranding`, arm64-UUID
`6823C89C-242D-37B0-ABC4-4D45A67E7C4C`, Team-ID `96RLY8D2JE`.
Die reguläre Originalsignaturprüfung im Host bleibt erhalten. Keine Spieldateien ändern.
Der Runtime trägt die exakte native Identität selbst; das sandboxed Original muss
keine externe Launcher-Konfiguration lesen. Tatsächlichen Executable-Pfad,
Bundle-Metadaten und UUID vor der Anbindung prüfen. Die Initialisierung erfolgt
auf dem AppKit-Runloop, nicht innerhalb der frühen dyld-Identitätsprüfung.

`DecimaEngine` bindet ausschließlich die geprüften originalen
`waitForNextFrame`-Implementierungen der beiden Frame-Pacing-Klassen an.
Die Queue läuft nur auf dem beobachteten `AppMainThread`, nicht auf AppKits
Hauptthread oder einem Ersatzworker. Der lokale Actor muss eindeutig sein.
Pool, Actor, Entity und drei Komponenten bilden den Besitzervertrag.
Native Aufrufe und Datenzugriffe prüfen diesen Vertrag erneut.

Der native Schuhwert besteht aus normaler und zusätzlicher Haltbarkeit;
ein anderer nahegelegener Wert ist nur ein Cache. Bei Ausdauer zählt ein Wert
oberhalb der durch Erschöpfung gesunkenen Obergrenze weiterhin als voll.

## Overlay und Entwicklungstests

Overlay, Glasregler und Cursor bleiben im Modul. `OverlayCursor` zeichnet einen
klickdurchlässigen Vektorpfeil im isolierten Trainerfenster. Sichtbarkeit folgt
Bedienwunsch und App-Fokus. Die native Mausfreigabe verwendet die zwei verifizierten
Cursor-Methoden dieses Builds; keine NMS-Spieladressen oder globalen Hide-Zähler.
Bei Fokusverlust keine physische Maus für das Spiel erneut binden.

`Tests/DeathStranding` enthält ausschließlich eigene Entwicklerprüfer. Diese niemals
in Produktquellen aufnehmen. `NativeContractTests` prüft Fremdprozessablehnung,
fehlende GameThread-Zustellung und echte Cursorpixel bei 1×/2×.
`StartupTests.py` prüft die Executable-/Bundle-Identität mit zuerst eingefügter
Bibliothek und fehlender externer Konfigurationsdatei. Synthetische Prüfungen
ersetzen keine Ingame-Wirkungsprüfung.
`WaterReserveCheck.py` prüft im ausdrücklich gestarteten Kandidaten auf sicherem
Boden den nativen Reservenverbrauch, Rücklesen, Nachfüllen und Abschalten; der
Prüfer startet oder beendet kein Spiel und ersetzt keinen Wasservergleich.
`ExpandedCheck.py` bündelt native Traglast-/Zeitprüfungen und Rücknahme im gleichen
freigegebenen Lauf. Asynchrone Protokolländerungen einzeln zurücklesen, bevor die
nächste folgt; die Zustellung eines Nachrichtenbündels ist keine Wirkungsbestätigung.
`BBStressCheck.py` prüft die originale Routine, aktuellen Stress, Darstellung und
Abschalten im freigegebenen Lauf. Die absichtlichen Stresswerte bleiben unter 75 %;
Ausgangswert und Schalterauswahl werden danach wiederhergestellt.
