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

## Getrennte Versionen und Veröffentlichung

Ein gemeinsames Git-Repository enthält alle Quellen. `Modules/<id>` bleibt über
Spielupdates stabil; kein kopiertes Quellprojekt pro Spielbuild. Ein neuer
unterstützter Spielbuild bekommt ein vollständig geprüftes eigenes Profil und
anschließend eine neue Trainerversion. Store-/Buildidentitäten niemals still
ersetzen. `selectionVersion` schützt inkompatible Änderungen der Funktions-IDs.

CI vergleicht Quell- und Abhängigkeitsfingerabdrücke mit dem zuletzt bestätigten
Katalog. Es baut nur betroffene Trainer und veröffentlicht unveränderliche
`trainer-<id>-v<version>`-Pakete. Der Katalog nennt den vollständigen nativen
Funktionskatalog, Originalprofile, Download, Größe, SHA-256 und erforderliche
Launcher-/ABI-Version. Veröffentlichtes niemals überschreiben oder neu hashen;
Korrekturen erhalten neue Versionsnummern. Einzelheiten: [RELEASING.md](RELEASING.md).

Profile können mit `compatibilityNote` einen kurzen deutschen Editionshinweis
(höchstens 120 Zeichen) angeben. Der Launcher zeigt ihn in Rot bei der gewählten
Storeversion, im Profilmenü und in den Pfadeinstellungen. Er verändert keine
Storekennung oder technische Buildprüfung.

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

Epic kann die temporäre Zuordnung im Speicher behalten und beim Beenden erneut
auf die Platte schreiben. Deshalb Originalbytes nach dem Start sofort
wiederherstellen, aber Journal, Helfer und Transaktionssperre bis zum regulären
Clientende erhalten. Danach nur die exakt eigene, noncegebundene Rückschreibung
zurücknehmen. Eine dabei von Epic gesetzte Reparaturmarkierung darf ausschließlich
im nachgewiesenen eigenen Replay zurückgesetzt werden; sonstige Änderungen bleiben
geschützt. Endet TrainerDock vorher, übernimmt die nächste Wiederherstellung das
persistente Journal nach dem Clientende. Die nativen Prüfungen unter
`Tests/EpicLaunch/` sichern diese Reihenfolge und fremde Änderungen ab.

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


Das Skript prüft und ersetzt ausschließlich das externe Buildprodukt
`~/Library/Developer/TrainerDock/Modules/mein-spiel.mhtmodule`. Es baut den Launcher
nicht neu, verändert keine eingebetteten Trainerressourcen und installiert das
Produkt nicht automatisch im Benutzerspeicher. Der aktuelle Launcher enthält
ausschließlich Katalogmetadaten.

Für die Weitergabe das vollständige geprüfte Paket über den
[Einzelrelease-Ablauf](RELEASING.md#neue-trainer-und-spielupdates-veröffentlichen)
veröffentlichen. Danach den Katalog in der App aktualisieren und ausdrücklich den
gewünschten Trainer herunterladen. Installierte Pakete liegen versioniert unter
`~/Library/Application Support/TrainerDock/Modules/<id>/<version>/<id>.mhtmodule`;
alte flache Benutzerpakete bleiben lesbar. Frühere Versionen nicht überschreiben
oder zum vermeintlichen Installieren eine einzelne Dylib in die App kopieren.
Native Bibliotheken werden erst beim ausdrücklich angeforderten Spielstart ausgeführt.

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

## Explizite Intelprofile für Rosetta

App und Mindestziel bleiben arm64/macOS 27+. Ein vollständig identifiziertes
Intelspiel kann ein eigenes Profil mit `architecture: "x86_64"` und einen passenden
Modulbuild mit demselben `architecture`-Feld in `Build.json` verwenden. Ohne Feld
bleiben Originalprüfung, Produkt und Tests arm64. Intelprofile benötigen eine
explizite, buildspezifisch vom Nutzer freigegebene `sha256-original`-Prüfung.
Keine fremde Architektur stillschweigend akzeptieren.

Der Xcode-Modultarget und seine synthetischen Prüfprogramme verwenden dieselbe
Architektur. `testSupportSources` darf ausschließlich Dateien unter `Tests/`
enthalten; diese werden nur an Prüfprogramme gelinkt, niemals an Trainer.dylib.
Rosetta ist zum Ausführen von Intelspielen und dieser Intelprüfprogramme nötig.
Der komplette native Trainer und das Ingame-Overlay bleiben im eigenen Modul.

## Gemeinsames ARM-/Intel-Paket

Ein Trainer mit tatsächlich bestätigten Profilen für beide CPUs verwendet
`architectures: ["arm64", "x86_64"]` in `Build.json`. Das einzelne `architecture`
entfällt dabei. Ohne beide Schlüssel gilt weiterhin arm64; pro Profil ist die
jeweilige Architektur einzeln festgelegt. Der Xcode-Generator baut ein gemeinsames
`Trainer.dylib`, und die Paketphase prüft beide CPU-Objektsätze mit den echten
Bridge-, Native- und HiDPI-Tests. Unterschiedliche Kataloge werden abgewiesen.

Die App akzeptiert nur exakt die in den Profilen enthaltenen CPU-Slices mit
macOS-27-Mindestziel und gültigem Code-Siegel aller Architekturen. Unbekannte,
doppelte, überlappende oder fehlende Slices sowie ungültige Fat-Tabellen bleiben
abgewiesen. Bisherige einzelne ARM-/Intel-Pakete bleiben gültig. Downloads solcher
Universal-Pakete nennen mindestens TrainerDock 1.2.6, damit ältere Apps sie nicht
als kompatibel anbieten. App und Broker bleiben arm64.

Eine ausdrücklich genehmigte GOG-Originalfreigabe verwendet
`integrityApproval: "user-confirmed-gog-original"` und Store `GOG`; dieselben
lückenlosen Dateihashes und Identitätsprüfungen gelten. Der Marker allein ersetzt
keine konkrete Nutzerfreigabe oder Originalprüfung. DREDGE bindet ausschließlich
GOG 1.5.3, Build 59048070897032907; Epic bleibt ein eigenes Profil.
