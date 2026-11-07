# Crimson Desert: native Updateprüfung

Das Produktprofil bindet Steam arm64 1.0.35 (450), Spielversion 2.04.08,
Steam-Build 26480954. UUID und sämtliche nativen Einstiegsmuster stehen in
`Modules/crimson-desert/Sources/CrimsonBuild.h`. Unbekannte Builds bleiben gesperrt.

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
