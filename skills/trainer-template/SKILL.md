---
name: trainer-template
description: Entwickelt und aktualisiert echte native macOS-Trainer für TrainerDock. Für neue Spiele, zusätzliche Store-/Buildprofile und separat versionierte Trainerveröffentlichungen aus der neutralen Vorlage oder dem vorhandenen Modul; nicht für reine Launcher-UI-Arbeit.
---

# Trainer Template

Die kanonische Codevorlage liegt unter
`/Users/jbw/Documents/MHT/Templates/Trainer`. Lies deren `README.md` und die
`AGENTS.md` des Projekts. Den konkreten Modulvertrag beschreibt
`/Users/jbw/Documents/MHT/docs/MODULES.md`.

## Neues Spiel oder bestehender Trainer

Zuerst vorhandene Module und deren Profile prüfen. Nur für ein neues Spiel eine
neue stabile Modul-ID anlegen. Spielupdates, weitere Stores und Fehlerkorrekturen
gehören in das vorhandene `Modules/<id>`; dafür keinen Generator, keine zweite
Modul-ID und keine Quellkopie pro Spielversion verwenden.

## Neues Spiel anlegen

Im TrainerDock-Codeordner:

```sh
python3 -B script/new_module.py --id spiel-id --name "Spielname" --store Steam
```

Standard ist die neutrale Vorlage `trainer`. Bereits tatsächlich ermittelte
Identität kann mit `--profile /absoluter/pfad/profil.json` eingelesen werden.
Nur bei gezielter Weiterentwicklung einer vorhandenen nativen Anbindung ein
bestehendes Modul ausdrücklich mit `--template modul-id` auswählen.

Der Generator schreibt ein eigenes Quellmodul mit Overlay, Liquid Glass,
Auswahlverwaltung, Bridge, Runtime und bewusst nicht implementiertem Adapter.
Er baut, installiert und startet nichts. Profile bleiben deaktiviert und
`Build.json` enthält `developmentOnly: true`.

Implementiere im neuen Modul die tatsächliche Originalidentität, native Engine-
und GameThread-Anbindung, lokale Besitzerprüfung, echte Funktionen mit
Rücklesebestätigung und das Lösen eigener Wirkungen. Keine Adressen anderer
Spiele, Demo-Cheats, simulierten Wirkungen oder vorgetäuschten Erfolgsanzeigen.
Einmalaktionen nie beim Start wiederholen; Lade-/Besitzerwechsel berücksichtigen.
Netzwerkstatus darf keine Trainerfunktionen blockieren. Fixtures ausschließlich
in `Tests/` halten.

Der ganze Trainer einschließlich Overlay gehört ins Modul. Der Launcher bleibt
allgemein und lädt nur Module, zeigt deren Optionen und übermittelt Befehle.
Entwicklungskennzeichnung und Profilsperren erst nach tatsächlicher Implementierung
und belegter Anbindung entfernen. Ungeprüfte Kompatibilität nicht behaupten.

## Vorhandenen Trainer aktualisieren

Modul-ID, bisherige geprüfte Profile, deren IDs und Benutzereinstellungen erhalten.
Neue Originalbuilds oder Stores als eigene zunächst deaktivierte Profile ergänzen;
Identität, native Bindung und Wirkung frisch belegen. Keine UUIDs oder Spieladressen
allein durch Ähnlichkeit übernehmen. Freigaben für Hashprofile bleiben buildgebunden.
Altprofile ohne belegte Bindung in der neuen Runtime dort deaktivieren; ihre
bisherigen Releases unverändert verfügbar lassen.

Die Paketversion verwendet `MAJOR.MINOR.PATCH` und ist unabhängig von Spielversion
und Storeprofil. CI verwendet eine höhere konfigurierte Version oder vergibt eine
neue Patchversion über veröffentlichte/reservierte Tags. Veröffentlichte Versionen
niemals ersetzen; alte Pakete bleiben nutzbar. Ändert sich die Bedeutung numerischer
Feature-IDs inkompatibel, zusätzlich `selectionVersion` ändern.

## Mausprobleme vor dem ersten Start abfangen

Lies vor der Eingabeanbindung die kanonische Anleitung
[Overlay-Maus und gebündelte Tests](/Users/jbw/Documents/MHT/docs/OVERLAY_INPUT.md).
Sie enthält die bestätigten Ursachen und Referenzen aus No Man’s Sky und DI2:
Laufzeit-Ivars statt fester AppKit-Offsets, vollständige Engine-Capture-Freigabe,
möglicherweise leere Cursorbilder, echte 1×/2×-Pixelprüfungen und stabile Sichtbarkeit.
Spieladressen und Native-Signaturen dieser Referenzen nicht übertragen.

Bereite Native-Analyse, kurze sitzungsgebundene Diagnose und synthetische Prüfungen
vor dem ersten Spielstart vor. Im freigegebenen Lauf Menü und Gameplay, sichtbaren
Zeiger, freie Bewegung, Klickzuordnung, Schließen/Fokuswechsel und mehrere reversible
Funktionen zusammen prüfen. Bei Fehlern Ursachen anhand der Diagnose eingrenzen und
zusammengehörige Korrekturen gemeinsam bauen/prüfen, bevor ein weiterer Neustart
nötig wird. Vorhandene Start-/Beendenfreigaben nutzen; keine zusätzlichen Rechte
aus diesem Ablauf ableiten. Doppelstarts verhindern, geladene Testbibliotheken
nicht überschreiben und nach ausreichender Bestätigung aufhören. Synthetische
Ergebnisse getrennt von tatsächlich geprüften Ingame-Wirkungen benennen.

## Glasregler in jedem neuen Trainer

Die Vorlage enthält unten rechts `MHTGlassSlider`. `MHTGlassIntensity.m` in
`sdkSources` und die vollständige `glassIntensity`-Weitergabe erhalten: 0 klar,
0,5 natives Glas (Standard), 1 deckend. Der Wert wird über die Laufzeitmeldungen
pro Trainer gespeichert und beim nächsten Start wiederhergestellt. Nur den
Hintergrund regeln; Texte und Eingaben bleiben sichtbar und unverändert. Die
Regelung nicht als abwählbares Liquid-Glass-Feature ersetzen. Vertrag und Tests:
[Glasdeckkraft im Trainer](/Users/jbw/Documents/MHT/docs/ARCHITECTURE.md#glasdeckkraft-im-trainer).

## Prüfen und hinzufügen

- Änderungen an der Vorlage mit `python3 -B script/check_template.py` prüfen.
- Ein fertig implementiertes Modul mit
  `python3 -B script/build.py --module spiel-id --configuration Release` bauen.
  Lokale Buildprodukte sind nicht automatisch im Launcher installiert.
- Builds unter `~/Library/Developer/TrainerDock`, Quellcode und Audit getrennt halten.
  Den lokalen Graphify-Index gemäß Projektanweisung pflegen.
- Keine Spiele für Tests starten oder beenden, sofern der konkrete Nutzerauftrag
  das nicht vorsieht. Synthetische Tests sind keine Ingame-Nachweise.

## Einzelne Trainer veröffentlichen

Lies bei Releasevorbereitung den kanonischen Ablauf
[Neue Trainer und Spielupdates veröffentlichen](/Users/jbw/Documents/MHT/docs/RELEASING.md#neue-trainer-und-spielupdates-veröffentlichen).

Bei beauftragter Veröffentlichung Quellen, Profile, Tests und regeneriertes
Xcode-Projekt gemeinsam auf `main` bringen. CI plant gegen den letzten bestätigten
Katalog, baut nur geänderte Produkte samt tatsächlich betroffenen Abhängigkeiten
und veröffentlicht unveränderliche Prereleases `trainer-<id>-v<version>`.
Keinen App-Tag und keinen Launcher-Gesamtbuild für ein reines Trainerupdate erzwingen.
`script/release.py` erstellt ausschließlich das App-Paket.

Lokal aus dem vollständig committeten Quellstand veröffentlichen. Zuerst
`script/trainer_distribution.py plan`, dann
alle im Bauplan genannten Trainer über den Release-Buildwrapper bauen; anschließend
`package` und `publish-trainers --commit <vollständiger-quellcommit>`. Das Skript hat
keinen `--module`-Filter. Ein direkter Scheme-Build oder altes Binary ersetzt keinen
Beleg nach finalem Xcode-CodeSign. Bei abweichenden Quellen/Bytes neu planen/bauen;
keine Prüfsummen oder Belege zur Fehlerumgehung anpassen.

Abschluss anhand des bestätigten Pakets und Katalogeintrags prüfen. In der App den
Katalog aktualisieren und den gewünschten Trainer ausdrücklich herunterladen;
Download ist kein Spielstart. Versionen liegen unter
`~/Library/Application Support/TrainerDock/Modules/<id>/<version>/<id>.mhtmodule`.
Alte installierte Versionen, Legacy-Pakete und laufende Runtimepfade erhalten.
Keine Binaries ins Git-Repository oder App-Bundle kopieren und nicht automatisch
alle Trainer laden oder alte Versionen löschen. Dieser Ablauf erweitert weder
Veröffentlichungs- noch Spielstartfreigaben.
