# Terraria – eigenständiger TrainerDock-Trainer

Steam **1.4.5.8**, Build **24893155**, arm64, macOS 27+. Der vollständige Trainer
mit nativer Mono-Anbindung, Overlay, zwölf Funktionen und Glasregler liegt hier.
Der Launcher enthält keine Terraria-Spiellogik.

## Originalbindung

Der Nutzer hat die vollständige SHA-256-Prüfung dieses unsignierten Originalbuilds
explizit genehmigt. 28 erfasste Dateien sind in 33 lückenlosen Abschnitten gebunden,
einschließlich Startskript, nativem Programm, Terraria.exe, FNA, BCL und Bibliotheken.
Keine Signaturen, Spieldateien oder Savebytes werden verändert.

- Native arm64-UUID: `EC32A5AF-44E5-37D6-8BB7-60B58BCD68FD`.
- Terraria-MVID: `6D97EEC3-CF49-43D4-BABA-712C3E4443CF`.
- FNA-MVID: `E53843E6-4CD4-419F-8A19-1B6B97E2011E`.
- mscorlib-MVID: `9B98D4B5-790E-4339-B39F-4E5620F6B824`.

Das Originalbundle nennt ein Shellskript als CFBundleExecutable. Die deklarative
`bundleExecutable`-Angabe bindet dieses zusätzlich; gestartet wird ausschließlich
das geprüfte native `Terraria.bin.osx`. Arbeits- und Bibliotheksverzeichnis bleiben
innerhalb des vollständig geprüften Bundles. Neue Builds bleiben gesperrt.

## Native Anbindung

Nur öffentliche Exporte der originalen eingebetteten Mono-Laufzeit werden verwendet.
`Marshal.GetDelegateForFunctionPointer` erzeugt den nativen Action-Rückruf für das
originale Ereignis `Main.OnTickForThirdPartySoftwareOnly`. Erst dessen tatsächlich
beobachtete Ausführung erlaubt Spielzugriffe. Das Ereignis kann zweimal pro Update
laufen; Aufträge bleiben serialisiert und an den beobachteten Thread gebunden.
Keine JIT-Patches und keine zusätzliche Managed-Assembly im Produkt.

Felder und Methoden kommen aus Originalmetadaten. Primitive und Enum-Untertypen
werden typisiert geprüft; FNA verwendet einen acht Byte großen `System.TimeSpan`.
Schwache Mono-GC-Handles, Weltkennung, lokale Figur und Inventar binden den Besitzer.
Gegenstandsleases prüfen zusätzlich die originale Typ-ID, damit ein wiederverwendeter
Inventarslot keine fremden Ausgangswerte erhält. Eigene Wirkungen werden nur bei
passender Rücklesung gelöst. Netzwerkstatus erzeugt keine Funktionssperre.

## Umfang

F1–F12 entsprechen der Reihenfolge im Trainer:

1. God Mode: Immunität, kein Blinken, kein Rückstoß, kein Fallschaden.
2. Gesundheit bis zum aktuellen Maximum auffüllen.
3. Mana bis zum aktuellen Maximum auffüllen.
4. Atemreserve erhalten.
5. Flugreserven vorhandener Flügel/Raketenstiefel erhalten; gewährt keine Ausrüstung.
6. Originaler Geisterflug. Vor dem Ausschalten eine freie Stelle wählen.
7. Vorhandene Inventarstapel auf die originale Stapelgrenze auffüllen.
8. Originale Lichtkarten aufhellen; beim Ausschalten neu berechnen.
9. Alle geladenen Handwerksrezepte anzeigen. Material- und Ortsanforderungen bleiben.
10. Schaden nicht verbrauchbarer Waffen erhöhen. Munition, Münzen und Wurfstapel
    bleiben unverändert; ein Treffer ist weiterhin erforderlich. Ausgangsschaden
    bleibt bei GC-Verschiebung und eigenen Waffenkopien nach Typ/Präfix erhalten.
11. Uhrzeit und Tag-/Nachtphase einfrieren.
12. FNA-Updatefrequenz skalieren. Dafür vorübergehend den originalen Frame-Skip-Modus
    „Ein“ verwenden; beim Ausschalten, im Menü und beim Besitzerwechsel zurücknehmen.

Liquid Glass ist dauerhaft aktiv. Der Regler unten rechts verändert nur den
Hintergrund, speichert 0…1 pro Trainer und erhält die Texte sichtbar. Das isolierte
`MHTOverlayHost`-Panel erhält Mausereignisse ausschließlich bei geöffneter Bedienung.

## Entwicklung und Prüfungen

Alle zwölf Funktionen besitzen eine implementierte native Anbindung. Im lokalen
Einzelspieler-Lauf wurden die ursprünglichen Zustände, Rücklesungen und Rücknahme
geprüft: Gesundheit, Mana, Atem, Geisterflag, Stapel samt originalem Verbrauch,
3603 Rezeptindizes, Zeitstopp, Waffenschaden und Lichtkarten. God Mode blockierte
einen originalen 10-Punkte-Schadenseingang; ohne ihn sank die Gesundheit um zehn.
Der originale Waffenschadenspfad besiegte einen tatsächlich erzeugten blauen Schleim
mit einem Treffer. Dies war ein nativer Trefferaufruf, kein manuell gezielter Schuss.

Mit original ausgerüsteten Flügeln blieb die Flugreserve auf 100. Bei Tempo 2
betrug der FNA-Takt 83334 statt 166667 TimeSpan-Ticks; zwischen zwei durchgehend
aktiven Messpunkten vergingen 90 Welt-Ticks in 0,72 Sekunden (etwa 125/s).
Die aufgehellte Unterwelt und ausgerüsteten Flügel waren zusätzlich sichtbar.
Ein längerer manueller Flug und ein eigener Unterwassertauchgang wurden nicht
separat durchgeführt. Der Nutzer bestätigte anschließend sichtbaren Mauszeiger, bedienbare Schalter
und den verstellbaren Glasregler im geöffneten Trainer.

Bridge-, ABI-, Enum-, Profil-, Wrapper-, Doppelstart- und HiDPI-Prüfungen bestehen
außerhalb des Spiels. Der direkte Native-Prozessschutz wies einen zweiten Start
während derselben laufenden Terraria-Instanz zurück.

Die abschließende Schadenskorrektur ist im neu gestarteten lokalen Lauf bestätigt:
Eine originale Waffenkopie behielt eingeschaltet 1.000.000 Schaden und erhielt
beim Ausschalten wieder 5. Die anderen Startwaffen kehrten zu 4 und 3 zurück;
Silber-/Kupfermünzen und Wurfmesser blieben durchgehend bei 50/25/5 Schaden.
Der originale Trefferpfad besiegte einen echten Gegner mit einem Treffer.
Danach waren alle Schalter aus, keine Feldleases mehr vorhanden, Tempo wieder
166667 TimeSpan-Ticks und die ursprüngliche Waffe im Inventar zurückgegeben.
Temporäre Testflügel und Waffenkopie sind entfernt. Die native Profildatei bindet
weiterhin ausschließlich den ausdrücklich genehmigten Build.

Tests und ihre eigenen Werkzeuge bleiben ausschließlich unter `Tests/Terraria`.
Die Metadatenleser führen Originalassemblies nicht aus. Tests erstellen keine
Quellkopien von Spielen, verändern keine Saves von außen und bleiben außerhalb
des Produktbuilds. Bibliotheken geladener Testprozesse niemals überschreiben.

Produktbuild: `python3 -B script/build.py --module terraria`.
Build und aktuelle App liegen unter `~/Library/Developer/TrainerDock`.
