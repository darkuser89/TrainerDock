# Vollständige Trainermodule entwickeln und hinzufügen

## Vertrag

Jedes Spielmodul enthält den ganzen Trainer: native Spielanbindung, Cheatwirkungen,
GameThread-Zustellung, Besitzerprüfung, Auswahlverwaltung und Ingame-Overlay. Die App
lädt Module, zeigt deren Funktionen und übermittelt allgemeine Start-/Bedienbefehle.
Keine neue Spiellogik oder Fallunterscheidung nach Spielnamen im Launcher ergänzen.

Ein Modul besteht im Code aus `Module.json`, `Build.json` und den Trainer-Sources.
Im Build entsteht eine eigenständige `.mhtmodule` mit `Trainer.dylib`, Manifest,
Profildatei und Lizenz. Sie benötigt kein anderes Modul und keine zentral abgelegte
Trainerbibliothek. Die generische SDK-Anbindung wird in das Modul kompiliert.

Profile können mit `gameVersion` die sichtbare Spielversion getrennt von der
geprüften Bundle-`version` angeben. Standardmäßig werden die vollständige
Bundlesignatur und die Team-ID geprüft. Für Originalinstallationen mit ausschließlich
signierter arm64-Slice ist `signatureScope: "arm64-executable"` möglich; dafür sind
die tatsächlich ermittelten `signatureIdentifier`, `signatureCDHash` und zusätzliche
`fileChecks` erforderlich. Jeder Dateicheck enthält einen relativen `path`,
`fileSize`, `offset`, `length` und `sha256` für den geprüften Bereich. Keine
Signaturen erzeugen oder Schutzmechanismen verändern, um ein Profil passend zu machen.

Epic-Profile können `epicAppName` und optional `epicNamespace` zur lesenden
Installationserkennung aus Epics `.item`-Manifesten angeben. Sie sind Storekennungen,
keine Anmeldedaten und keine Buildfreigabe. Die ursprüngliche Spielidentität wird
weiterhin vollständig geprüft. Kandidaten werden pro Modul und Profil gespeichert;
eine gemeinsame Bundle-ID darf Steam und Epic nicht denselben Pfad zuordnen.
Explizit gewählte Pfade bleiben erhalten. Mehrdeutige Epic-Installationen benötigen
eine manuelle Pfadwahl. Die Erkennung führt weder Launcher noch Spiele aus.
Ein funktionierender authentifizierter Start muss vor der Freigabe separat belegt
werden; allein die Erkennung macht ein Epic-Profil noch nicht startfähig.

`launchMode: "epic"` verwendet den generischen Epic-Startdienst. Der Epic-Client
muss zuvor regulär beendet sein; TrainerDock beendet ihn nicht selbst. Ein eigener
kurzlebiger Helfer neben der Spiele-App reicht die vom Originalclient gelieferten
Argumente unverändert an das geprüfte Originalprogramm weiter. Nur die Trainer-
Umgebung wird ergänzt. Epics temporäre Startzuordnung wird durch ein privates
Transaktionsjournal gesichert und anschließend exakt zurückgenommen; fremde
Änderungen bleiben erhalten. Keine Authargumente lesen, speichern oder loggen.
Fehler und Timeouts lösen weder Direktstarts noch automatische Wiederholungen aus.

`launchMode: "executable"` startet das validierte Originalprogramm direkt, wenn
dessen ursprünglicher Installationsordner nicht als `.app` registriert ist.
Ohne dieses Feld verwendet TrainerDock den normalen macOS-Appstart. Beide Wege übergeben
denselben Trainervertrag; ein Startfehler darf keinen Ersatzstart ohne Trainer auslösen.

Bei einem originalen Shellwrapper kann ein ausdrücklich freigegebenes
`sha256-original`-Profil zusätzlich `bundleExecutable` nennen. Dieses muss dem
originalen CFBundleExecutable entsprechen und vollständig mitgehasht sein;
`executable` bezeichnet weiterhin das tatsächlich geprüfte native Programm.
Optionale `workingDirectory` und `libraryDirectory` sind relative, existierende
Verzeichnisse innerhalb des Bundles, auch nach Symlinkauflösung. Letzteres liefert
den originalen Bibliothekssuchpfad. Der Host prüft vor beiden Startwegen zusätzlich
den tatsächlichen Executable-Pfad laufender Prozesse, auch ohne App-Registrierung.

## Neues Modul anlegen

### Versionierte Auswahl

Bei inkompatibler Neuzuordnung numerischer Funktions-IDs kann ein Modul
`selectionVersion` als kurzen stabilen Bezeichner setzen. Der allgemeine Host
speichert die Auswahl dann in einem eigenen Versionsbereich; alte Einstellungen
bleiben erhalten und werden nicht auf andere Funktionen angewendet. Ohne dieses
Feld bleibt die bisherige Ablage unverändert. Private Auswahlformate und ihre
Migration gehören weiterhin in das Trainermodul.

### Funktionsgruppen im Launcher

Die optionale Eigenschaft `groups` in `Module.json` bestimmt Reihenfolge und
Gruppierung der Anzeige. Sie enthält ausschließlich Verweise auf stabile IDs des
nativen Katalogs, keine zweite Funktionsdefinition:

```json
"groups": [
  { "id": "player", "title": "Spieler", "symbol": "person", "features": [0, 2] },
  { "id": "inventory", "title": "Inventar", "symbol": "shippingbox", "features": [1] }
]
```

Das Beispiel setzt einen nativen Katalog mit genau drei Funktionen voraus.
Jede Funktion muss genau einmal vorkommen; leere Gruppen, doppelte Gruppen-IDs,
fehlende oder unbekannte Feature-IDs werden abgelehnt. `symbol` ist ein SF-Symbol;
bei einem unbekannten Symbol erscheint ein allgemeines Einstellungssymbol.
Gruppen-IDs bleiben stabil, damit der gespeicherte Klappzustand erhalten bleibt.
Ein Modul ohne `groups` erhält einen einzelnen Bereich „Trainer“.

Der Launcher ordnet Bedienbefehle weiterhin anhand der ursprünglichen Feature-ID
zu. Ein-/Ausklappen verändert keine Cheat-Auswahl und sendet keine Spielbefehle.
Die Darstellung enthält keine Hintergrundbilder; installierte Spielicons bleiben
erhalten. Änderungen an `groups` werden beim nächsten Modulbuild übernommen.

### Vorlage verwenden

Für andere Chats gibt es den globalen Skill `$trainer-template` und die neutrale
[Trainervorlage](../Templates/Trainer/README.md) mit einem
[fertigen Chat-Arbeitsauftrag](../Templates/Trainer/CHAT_START.md).

```sh
python3 -B script/new_module.py --id mein-spiel --name "Mein Spiel" --store Steam
```

Standard ist `--template trainer`: ein eigenes vollständiges Quellgerüst ohne
fremde Spieladressen, echte Featurebehauptungen oder simulierte Wirkungen. Die
spielabhängige NativeAdapter-Anbindung muss entwickelt werden. Vorhandene Module
werden niemals überschrieben. Profile sind **enabled: false**, der Build ist mit
**developmentOnly: true** als Entwicklung gesperrt. Unfertige Module werden bei
Gesamtbuilds übersprungen; ein expliziter Produktbuild wird abgelehnt.

Mit `--profile /pfad/profil.json` können bereits tatsächlich ermittelte Daten
übernommen werden: `id`, `name`, `bundleIdentifier`, `executable`, `version`,
`teamIdentifier`, `uuids` und optional `steamAppId`. Ohne diese Datei bleiben die
unbekannten Identitätsdaten leer. Auch übernommene Profile werden deaktiviert.

Nur für gezielte Varianten einer vorhandenen nativen Anbindung ausdrücklich
`--template modul-id` verwenden. Das kopiert deren Sources als Entwicklungsgrundlage;
auch diese Ausgabe bleibt `developmentOnly`. Die Vorlage bedeutet keine automatische
Kompatibilität; fremde Adressen/Signaturen und Enginebindungen müssen ersetzt werden.
Keine lokalen Installationspfade einchecken.

## Native Anbindung entwickeln

1. Originalidentität anhand echter Daten belegen: Bundle-ID, Executable, Architektur,
   UUID, Team-ID, Bundleversion und Store. Keine Profile für unbekannte Builds freigeben.
2. Im neuen Modul Adapter, Katalog und native Engineanbindung implementieren. Den
   tatsächlich bestätigten GameThread verwenden. Native Besitzer mit geeigneten
   Weak-Handles prüfen. Ausschließlich eigene Effekte lösen und nur nach Rücklesen
   „Aktiv“ melden. Keine Netzwerksperre einbauen; Ladepausen und Besitzerwechsel berücksichtigen.
3. Bridgebefehle serialisieren. `setWanted:forFeature:` ist ein expliziter idempotenter
   Setter. Einmalaktionen nach Kontextwechsel verwerfen und beim Start nie wiederholen.
   „Alles aus“ muss auch in Ladepausen und bei voller Warteschlange wirksam bleiben.
4. Ingame-Overlay, Cursorfreigabe und Tastenkürzel im Modul halten. `liquidGlass` in
   den normalisierten Optionen erhalten und an `TrainerMaterial.liquidGlassEnabled`
   weitergeben. Barrierefreiheit und ältere Systeme benötigen die native Ersatzdarstellung.
5. `Build.json` pflegen: `sourceRoot`, `sources`, `defines`, `catalogSources`. Native
   `.mm`-Dateien werden separat mit C++17 kompiliert. `family` wählt gegebenenfalls
   vorhandene Build-/Testanpassungen; für einen neuen kompatiblen MT-Vertrag den neuen
   Namen und `testSuite: "mt"` verwenden. Für Kataloge kann `catalog` die Felder
   `prefix`, `setup`, `count`, `function` und `imports` definieren. Alte spezielle
   Defines oder Katalogauswahl der Vorlage nicht ungeprüft behalten.
6. `MHTRuntimeBridge.h` nur in der Modulruntime einbinden. Nach gültiger Prozessprüfung
   und Erstellung der Bridge auf dem Hauptthread anbinden:

   ```objc
   MHTStartControl(gameplay,
       ^NSDictionary *{ return overlayOptions; },
       ^(NSDictionary *options) {
           overlayOptions=MTNormalizeOverlayOptions(options);
           for (MTOverlayRoot *root in roots) [root applyOverlayOptions:overlayOptions];
           updateOverlayInput();
       });
   ```

   Der gemeinsame Vertrag verwendet `MHT_TARGET`, `MHT_CONFIG`, `MHT_PROFILE`,
   `MHT_SESSION`, `MHT_MODULE`, `MHT_OPTIONS` und `MHT_SELECTION`. Spielabhängige
   Auswahlübersetzungen gehören in die Modulruntime. Neue Typzuordnungen gegebenenfalls
   im nur für Module kompilierten SDK ergänzen, niemals im Launcher.
7. `Module.json` enthält `schemaVersion: 1`, stabile eindeutige `id`, `name`, `version`
   und `profiles`. IDs nur aus Buchstaben, Zahlen, Bindestrich und Unterstrich bilden.
   Der Build erzeugt `features` aus dem nativen Katalog. Keine zweite manuelle Liste
   anlegen. Bei inkompatiblen Katalogänderungen gespeicherte Auswahl versionieren.
8. Tests für Wertebereiche, Lade-/Besitzerwechsel, Netzwerk-Kontinuität, Einmalaktionen,
   Auswahlwiederherstellung, Glasersatz und „Alles aus“ ausführen. Fixtures bleiben in
   `Tests`; niemals in die ausgelieferte Trainerbibliothek aufnehmen. Neue Profile
   bleiben ohne belegte Anbindung deaktiviert. Ingame-Prüfungen nur nach Nutzerauftrag.

## Ein Modul bauen, ohne den Launcher neu zu kompilieren

```sh
python3 -B script/build.py --module mein-spiel
```

Der Befehl aktualisiert `TrainerDock.xcodeproj` und baut das native Scheme
`Trainer-mein-spiel`. Für die direkte Arbeit in Xcode nach `Build.json`-Änderungen
`python3 -B script/xcode_project.py` ausführen und das passende Trainer-Scheme wählen.
App und Trainer setzen macOS 27.0 voraus; diese Mindestversion nicht absenken.


Das Skript prüft und ersetzt
`~/Library/Developer/TrainerDock/Modules/mein-spiel.mhtmodule` und aktualisiert die
eingebetteten Modulressourcen der aktuellen App. Der Launcher wird nicht neu kompiliert.
Danach im Launcher „Trainer & Spiele neu laden“ verwenden. Für die Weitergabe genügt
das gesamte Modulverzeichnis, keine einzelne herausgelöste Dylib.

Eine zusätzliche vollständige `.mhtmodule` kann auch direkt in
`~/Library/Application Support/TrainerDock/Modules` abgelegt werden. Bei gleicher ID hat das
Benutzermodul Vorrang. Keine fremden Moduldateien ungeprüft übernehmen. Native
Bibliotheken werden erst beim ausdrücklich angeforderten Spielstart ausgeführt.

## Gesamtsystem prüfen

```sh
./script/build_and_run.sh --build-only
./script/build_and_run.sh --smoke
~/Library/Developer/TrainerDock/TrainerDock.app/Contents/MacOS/TrainerDock --validate-installed
graphify update
```

`--smoke` öffnet ausschließlich den Launcher mit allen Modulen. `--validate-installed`
liest nur Identität und Signatur der Installationen; es startet keine Spiele. Beide
sind keine Ingame-Nachweise. Den Unterschied in Antworten ausdrücklich benennen.

## Module mit eigener Managed-Anbindung

`Build.json` kann `managed` mit `referenceProfile`, `referenceDirectory`, `sources`
und dem Namen eines generierten `header` enthalten. `script/managed.py` prüft die
Originalreferenzen anhand der `fileChecks` des Profils, kompiliert ausschließlich
eigene C#-Quellen mit dem lokalen .NET-SDK und erzeugt den Byteheader im externen
Buildstage. Dieser Header ist Teil der jeweiligen nativen Trainerbibliothek.
Keine Originalassemblies ins Modul kopieren und keine Paketdownloads im Build.

Der Referenzpfad kommt aus dem gespeicherten TrainerDock-Spielpfad des angegebenen Profils
oder aus `TRAINERDOCK_REFERENCE_BUNDLE` für einen gezielten Build. Die Originalinstallation
muss dafür erreichbar sein. Neue Build-/Storevarianten benötigen eigene Referenz-
und Runtime-Identitätsprüfungen; Kompilierbarkeit allein bestätigt keine Wirkung.
Optionale `policySources`/`policyTests` führen eigene, von Unity unabhängige
Sicherheitsprüfungen aus. `nativeContractTests` benennt zusätzlich eine echte
Prozess-/Adapterprüfung unter `Tests/`; sie wird nicht ins Produkt eingebunden.

## Native Lua-/SDL-Anbindung

Balatro enthält eigenen Lua-Code als Bestandteil seiner nativen Trainerbibliothek.
Die Original-C-ABI wird nur aus den bereits geladenen, vollständig geprüften
Spielbibliotheken gebunden. LÖVEs Coroutine-Yield erlaubt das Registrieren eines
Update-Rückrufs; ausschließlich dieser Rückruf verarbeitet Gameplayaufträge.
Die schmale LÖVE-Eingabezustellung gehört ebenfalls zum Modul.

`Build.json` kann `undefinedSymbols` mit ausdrücklich benannten Originalsymbolen
angeben. Diese werden ausschließlich beim Linken der jeweiligen Dylib zugelassen,
mit validierten Symbolnamen; Launcher und Tests behalten die strikte Symbolprüfung.
Spielpfade, vollständige Spielbibliotheken und Lua-Spielquellen werden nicht mitgeliefert.

## Ausdrücklich genehmigte vollständige Originalprüfung

`signatureScope: "sha256-original"` ist eine Ausnahme für einen konkret vom Nutzer
freigegebenen Originalbuild mit defekter Originalsignatur. Kein automatischer Ersatz
bei Signaturfehlern. Das Profil benötigt `integrityApproval:
"user-confirmed-steam-original"`, `integrityFiles` und lückenlose `fileChecks` für
alle aufgelisteten Dateien, mindestens das vollständige Hauptprogramm und Info.plist.
Je Abschnitt höchstens 8 MiB, insgesamt höchstens 64 Abschnitte und 32 Dateien.
Lücken, Überlappungen, Größenänderungen, fehlende Dateien und aus dem Bundle führende
Symlinks werden abgewiesen. Version und arm64-UUID bleiben erforderlich.

Die konkrete Freigabe betrifft nur Vampire Crawlers Steam 1.6.1 (11), Build-ID
25304267, mit den erfassten Hashes. Weitere Builds erfordern einen neuen Auftrag.
Andere Profile behalten ihre Originalsignaturprüfung. Diese Prüfung verändert
keine Originaldatei und keine Sicherheitsfunktion des Betriebssystems.
