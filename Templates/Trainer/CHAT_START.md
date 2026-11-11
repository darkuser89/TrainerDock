# Arbeitsauftrag für einen neuen Chat

```text
Nutze $trainer-template und die Vorlage
/Users/jbw/Documents/MHT/Templates/Trainer für ein neues echtes natives
TrainerDock-Trainermodul für das von mir genannte Spiel und dessen Storeversion.

Lies die AGENTS.md im Projekt und in der Vorlage. Lege mit
script/new_module.py ein eigenes deaktiviertes Entwicklungsmodul an.
Lies vor der Eingabeanbindung docs/OVERLAY_INPUT.md. Bereite Native-Analyse,
Diagnose und synthetische Mausprüfungen vor dem ersten Spielstart vor.
Prüfe Menü und Gameplay, sichtbaren Zeiger, freie Bewegung, Klickzuordnung,
Rückgabe der Steuerung und mehrere reversible Cheats gemeinsam im freigegebenen
Lauf. Bestehende Freigaben beachten, Doppelstarts verhindern und nach bestätigter
Wirkung aufhören. Weitere Neustarts erst mit eingegrenzter Ursache und geprüftem
Kandidaten vorbereiten. Keine NMS-Spieladressen übernehmen.
Ermittle die tatsächliche Originalidentität und entwickle die echte native
Spielanbindung. Keine fremden Spieladressen, Demo-Cheats, simulierten Wirkungen
oder vorgetäuschten Erfolgsanzeigen verwenden.

Der vollständige Trainer samt Overlay gehört ins Modul. Den universellen
Launcher nur zum Laden und Anzeigen der Moduloptionen verwenden. Builds,
Code und Audit getrennt halten; bestehende Projekte und Saves schützen.
Keine Spiele automatisch für Tests starten oder beenden. Nicht durchgeführte
Ingame-Prüfungen ausdrücklich nennen und unbelegte Profile deaktiviert lassen.

Lies docs/RELEASING.md zum Einzeltrainer-Ablauf. Baue gezielt mit
script/build.py --module <id> --configuration Release. Wenn die Veröffentlichung
beauftragt ist, Quellen, Tests, Profile und das regenerierte Xcode-Projekt gemeinsam
auf main bringen und Paket/Katalog bis zum bestätigten Download prüfen.
Keine Trainerbibliotheken in den Launcher einbauen oder alte Releases ersetzen.
Neue Trainer über Einzelreleases und Onlinekatalog für die vorhandene kompatible
App veröffentlichen. GitHub Actions baut die Veröffentlichungsprodukte. Bei
launcher.changed: false keine App-Version erhöhen, keinen App-Tag setzen und keinen
Launcher bauen/veröffentlichen. Bei unerwartetem true erst die Hoständerungen prüfen;
neue Trainer, Xcode-Ziele oder Katalogeinträge allein sind kein App-Update.
Prüfe vor Builds und Veröffentlichung script/trainer_distribution.py plan gegen
den letzten bestätigten Onlinekatalog. Nur neue oder tatsächlich geänderte Trainer
unter modules bauen und veröffentlichen; bei leerer Liste keine Trainerversionen
erhöhen. Reine Buildskript-, Test-, Doku- oder Appänderungen erzeugen keine
Trainerupdates. Unerwartete Masseneinträge zuerst untersuchen und korrigieren.
```

Im Auftrag Spielname, Store und gewünschte Funktionen konkret nennen. Einen
Spielstart oder Ingame-Test bei Bedarf ausdrücklich zusätzlich beauftragen.

Für ein Update statt der Neuanlage verwenden:

```text
Nutze $trainer-template, um den vorhandenen Trainer für [Spiel/Store] an den
installierten neuen Spielbuild anzupassen. Behalte seine Modul-ID, bisherigen
geprüften Profile, alten Releases und Benutzereinstellungen. Ergänze neue
Originalbuilds als eigene zunächst deaktivierte Profile und prüfe deren native
Anbindung. Kein zweites Modul und keine Quellkopie pro Spielversion anlegen.
Lies AGENTS.md sowie docs/RELEASING.md. Baue nur den betroffenen Trainer und
gegebenenfalls tatsächlich betroffene gemeinsame Abhängigkeiten. Unterscheide
Paketversion, Spielbuild und Store. Bereite eine neue unveränderliche Einzelversion
mit geprüftem Katalogeintrag vor; veröffentliche sie im Umfang meines Auftrags.
Keine Spielstarts oder Ingame-Prüfungen ohne entsprechenden Auftrag ableiten.
Trainerupdates über den Onlinekatalog ohne neue App-Version veröffentlichen.
GitHub Actions baut die Veröffentlichungsprodukte. Bei launcher.changed: false
keinen Launcher bauen oder veröffentlichen und keine App-Version/Tags erhöhen.
Nur tatsächliche Hoständerungen oder eine benötigte neue Schnittstelle rechtfertigen
ein App-Update; den konkreten Grund benennen.
Vorher script/trainer_distribution.py plan prüfen: Nur neue oder inhaltlich
geänderte Trainer unter modules bauen/veröffentlichen, bei leerer Liste keine.
Reine Buildskript-/Test-/Doku-/Appversionsänderungen und Fingerabdruck-Formatwechsel
dürfen nicht zu neuen Versionen aller Trainer führen. Inhalts- und Buildbeleg
getrennt erhalten; Migration nur anhand bestätigter Altbelege durchführen.
```
