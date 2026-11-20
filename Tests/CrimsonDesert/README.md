# Crimson Desert: native Updateprüfung

Die getrennten Produktprofile binden Steam arm64 1.0.35 (450), Steam-Build
26480954 (Spielversion 2.04.08), 1.0.35 (466), Steam-Build 26636972, und
1.0.35 (476), Steam-Build 26776744.
Build 450 verwendet unverändert `CrimsonBuild.h`; Build 466 und 476 verwenden
jeweils eigene 75 Bindungen und sechs globale Adressen in `CrimsonBuild466.h`
beziehungsweise `CrimsonBuild476.h`.
Unbekannte UUIDs und fehlende Bindungen haben keinen Rückfall auf Build 450.

Build 466 und 476 prüfen nach jeweils ausdrücklicher Nutzerfreigabe vier Originaldateien mit
30 lückenlosen SHA-256-Abschnitten. Die gemeinsame Originalprüfung aus
`Core/GameIdentity.m` wird auch in der Runtime verwendet. Keine Signaturänderung.
Die Statusmanager-Felder und der Geldschlüssel haben eigene 466-Offsets;
insbesondere Stamina liegt bei `0xbe`, Leben bei `0xd6` und Geist bei `0xd8`.
Die Inventartransaktion verwendet weiterhin die originalen Konstruktoren und
Destruktoren, einschließlich des geänderten Drop-Konstruktors.

Der ursprüngliche Offlineauftrag untersagte einen Spielstart. Am 18.11.2026
hat der Nutzer die anschließende Ingame-Prüfung ausdrücklich beauftragt.
Originaldatei- und synthetische Prüfungen ersetzen die dabei einzeln zu
bestätigenden Effekte, Rücknahme und Mausbedienung nicht.
Der optionale Diagnoseexport `CDSetPlayerStatRatio` lehnt Build 466 und 476 ausdrücklich
ab, weil dessen separate Test-RPC noch nicht gebunden wurde. Die 13
Katalogfunktionen verwenden diesen Export nicht. Geld-/Stapeltests nutzen die
regulären sitzungsgebundenen Traineraktionen.

Vor einem genehmigten Spielstart die Originaldatei ausschließlich lesend prüfen:

```sh
python3 -B Tests/CrimsonDesert/BuildContract.py '/Pfad/CrimsonDesert_Steam.app'
python3 -B script/build.py --module crimson-desert
```

`BuildContract.py` prüft zusätzlich die ursprünglichen Singleton-Accessor,
Task-Adresse, Timer- und Inventar-RTTI sowie den Typmarker der Inventarauswahl.
Mehrdeutige Funktionsprologe allein reichen für ein weiteres Update nicht aus.
Die GameThread- und ServerThread-Anbindung und tatsächliche Effekte anschließend
im selben freigegebenen Lauf prüfen.

`NativeBindingsTests.mm` führt den tatsächlichen Runtime-Buildschutz gegen
synthetische Images aus: alle drei Builds, sämtliche je 75 einzeln beschädigten
Instruktionsprüfungen der beiden späteren Builds, falsche UUID/Architektur/Header
und keine Rückfalladresse.
Dieser Test läuft als isolierter Bestandteil des Modulbuilds. Das Spiel wird
dabei weder geladen noch gestartet.

`IngameProbe.m` ist ein optionaler Testhelfer und gehört in kein Produkt-Target.
Er benötigt genau die C-Exports aus `CrimsonNative.h`, die geprüfte Runtime und
`MT_CRIMSON_PROBE_OUTPUT` als absoluten temporären Ausgabepfad. Die übrige
Startumgebung einschließlich Profil, Zielpfad, Sitzung und deaktivierter
Startauswahl aus dem Modulvertrag beibehalten. Keine laufende Runtime ersetzen
und niemals eine zweite Spielinstanz als vermeintlichen Ersatz öffnen.

Der Helfer überschreibt eine einzige JSON-Zustandsdatei. Aufträge liegen unter
`<Ausgabepfad>.command.json`, benötigen eine steigende `sequence`, die exakte
`pid` und bei Spieleraktionen den aktuellen `actorKey`. Unterstützte Befehle:

- `feature`, `wanted`, `value`: bestehende native Trainerfunktion anfordern.
- `stat`, `ratio`: ursprünglichen nativen Statusauftrag prüfen.
- `overlay`: Engine-Mausfreigabe anfordern; dies öffnet kein Overlayfenster.

`command.queued` ist nur die Zustellung. Erfolg erfordert spätere Client- und
Serverwerte bzw. `quantityResult.success`, identischen Besitzer und Zielstapel.
Bei Besitzerwechsel abbrechen. Reversible Funktionen gemeinsam prüfen und eigene
Änderungen zurücknehmen. Geld und Stapelmengen können gespeichert werden; für
Stapeltests keine Questgegenstände verwenden und die Ausgangsmenge wiederherstellen.
Der Stundensprung ist eine separate Einmalaktion. Kampfwerte allein belegen keinen
realen Treffer. Native Mausfreigabe, sichtbaren Zeiger und echte Klicks getrennt
prüfen; synthetische Fernsteuerung kann die physischen Spieltasten nicht ersetzen.

Temporäre Helfer und Zustandsdateien außerhalb von Code/Audit halten und nach
regulärem Ende des freigegebenen Testprozesses entfernen.

`Launch.m` startet nur nach frischer Originalprüfung und Ausschluss einer
laufenden Instanz. Der private Prüfer und alle Sitzungsdateien liegen in einem
externen temporären Ordner. `Requests.json` übermittelt nur sitzungs- und
kontextgebundene Befehle über das echte Runtimeprotokoll. Kein Ersatzstart ohne
Trainer und kein automatisches Beenden des Spiels.

`InventoryTests.mm` prüft die echte Inventarsuche gegen synthetische Daten:
Geldschlüssel aller drei Builds, mehrere Treffer auch in verschiedenen Inventaren,
geänderte Gegenstandsnummern und beschädigte Größen. Der alte Geld-Inventarhelfer
wird unter Build 466 nicht verwendet: Sein zunächst zugeordneter Einstieg erwartet
einen `ItemEss`-Zeiger statt des bisherigen Bytearguments.

Der parameterlose Metadatenzugriff (Build 466: Manager-Typ 68, Feld
`0x78`) liefert die Inventarart 3, keinen Index. Der ebenfalls gebundene originale
Dispatcher ordnet diese Art dem Hauptinventar 1 zu; Bankinventar 9 bleibt getrennt.
Build 450 behält seinen ursprünglichen geprüften Resolver und dessen ABI.
Der leere Drop-Konstruktor von Build 466 besteht aus vier Blattinstruktionen:
Nullzeiger bei `+0x30`, Variantentag 18 als 16-Bit-Wert bei `+0`, Rückkehr.
Ein Kopierkonstruktor mit zweitem Argument ist dafür ungeeignet. Die Offline-
und CI-Grenztests prüfen diese ABI ausdrücklich, nicht nur ähnliche Prologe.

Für die gebündelte Ingame-Prüfung Client-/Serverwerte vor Aktivierung, nach
Aktivierung und nach Rücknahme vergleichen. Das Spielinventar zusätzlich zur
nativen Rücklesung prüfen. Beim Geldtest höchstens eine Hundertste hinzufügen,
den exakten Ausgangswert wiederherstellen und Bankinventar 9 unverändert prüfen.
Nur kurzlebige sitzungsgebundene Zustandsdaten außerhalb des Repositories verwenden;
keine Spielstände bearbeiten und Prüfer erst nach regulärem Prozessende entfernen.

## Prüfung von Build 476

Am 20.11.2026 im ausdrücklich genehmigten vorhandenen Spielstand geprüft:
GameThread-Zustellung und ServerWalkThread-Rücklesen mit identischem Besitzer;
Maximalwerte 400/150/40, Verteidigung 49, Angriff 10.000, Tempo 1,25 und
Tageszeitstopp. Unbegrenztes Leben, Ausdauer und Geist setzen die nativen
Minimalwerte auf ihre jeweiligen Maximalwerte. Alle zehn Dauerschalter melden
erst nach Client-/Serverrücklesen aktiv. Ausschalten stellte die Ausgangswerte
300/120/30, Verteidigung 39, Angriff 11, Tempo 1 und Tageszeitfaktor 12 wieder her.
Ein Stundensprung änderte die angehaltene Feldzeit genau einmal um 3.600 Sekunden.
Geld wurde um 0,01 erhöht und exakt zurückgesetzt; Bankinventar 9 blieb unverändert.
Der ausgewählte Süßkartoffelstapel wurde nativ und sichtbar von drei auf vier und
zurück auf drei gesetzt. Der Nutzer bestätigte Schalter und Glasregler mit seiner
Maus. Sämtliche Testschalter wurden abschließend ausgeschaltet.

Diese Updateprüfung bestätigt die nativen Werte und Inventarwirkungen; ein neuer
Kampftreffer-/Verbrauchstest und eine FPS-Messung wurden nicht durchgeführt.
Die separat gebundenen alten Originalbuilds wurden synthetisch geprüft, aber
in diesem Lauf nicht erneut gestartet.
