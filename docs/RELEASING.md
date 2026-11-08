# GitHub-Build und Veröffentlichung

`.github/workflows/build-release.yml` verwendet GitHubs Apple-Silicon-Runner
`xcode-27` mit macOS 27 und macOS-27-SDK. Die native Mindestversion bleibt 27.0.
Der Workflow startet keine Spiele und benötigt keine privaten Signierschlüssel.
Balatros synthetische Lua-/Scoring-/Besitzertests laufen im Cloud-Build mit
separatem Homebrew-LuaJIT. Die Prüfung mit Balatros ursprünglicher Lua-Bibliothek
wird dabei ausdrücklich als nicht durchgeführt gemeldet. Der Ersatz befindet sich
ausschließlich im Testprozess und wird nicht ins Produkt oder ZIP eingebunden.
Lokale Tests verwenden ohne `TRAINERDOCK_TEST_LUA_LIBRARY` weiterhin das Original.

Turoks synthetischer Nebel-Pixeltest benötigt einen beschleunigten OpenGL-Kontext.
Fehlt dieser auf dem GitHub-Runner, meldet der Prüfer ausdrücklich „NOT RUN“
statt einer bestandenen Grafikprüfung. Nur der Cloud-Build erlaubt dafür den
Rückgabecode 77 mit `TRAINERDOCK_ALLOW_MISSING_TEST_GPU=1`; lokale Builds bleiben
streng. Shader-, Pixel-, Rücklese- und Rücknahmefehler brechen weiterhin ab.
Native Grenz-, Bridge- und HiDPI-Prüfungen laufen auch ohne Test-GPU vollständig.

Zusätzlich führt CI die Performance-Grenzprüfer unter `Tests/Managed`,
`Tests/UnrealPerformance` und `Tests/NativePerformance` aus. Sie zählen tatsächliche
Produktpfade mit synthetischen Besitzern: Leerlauf, Metadatenauflösung, unveränderte
Aufträge, fremde Änderungen und Rücknahme. Der native Runner verwendet nach dem
Release-Build dessen Xcode-Objekte mit `--configuration Release`. Der Unreal-Runner
verlangt einen expliziten isolierten Lua-Host aus `TRAINERDOCK_TEST_LUA_LIBRARY`.
Keine dieser Prüfungen startet ein Spiel oder liefert einen FPS-Nachweis.

## Getrennte Produkte und gezielte Builds

Die App enthält nur den Launcher, den eigenen Epic-Starthelfer und
`Contents/Resources/TrainerCatalog.json`. Trainermodule werden einzeln über die
App heruntergeladen und außerhalb des App-Bundles verwaltet. Der Ordner
`Contents/Resources/Modules` enthält ausschließlich einen README-Hinweis für
ältere App-Updater. Keine Trainerbibliothek wird in den Launcherprozess geladen.

`script/trainer_distribution.py plan` vergleicht die tatsächlichen Eingaben mit
dem **zuletzt erfolgreich veröffentlichten Katalog**, nicht mit dem vorherigen
Git-Commit. Pro Trainer werden dessen Builddefinition, Profilmetadaten, Quellen,
rekursive lokale Header, verwendete SDK-Quellen und Buildflags gehasht. Geteilte
Resident-Evil-/Kex-Quellen treffen ihre abhängigen Trainer. Ein Managed-Lockeintrag
betrifft ausschließlich seinen Trainer. Reine App-/UI-Änderungen bauen keine
Trainer neu. Gemeinsame Buildinfrastruktur darf beide Produktarten invalidieren.
Testdateien sind keine Produkt-Eingaben; die passenden synthetischen Grenzprüfungen
laufen weiterhin bei betroffenen Produktänderungen.

- Push auf `main` oder manueller Workflow auf `main`: nur geänderte Produkte
  bauen, prüfen und veröffentlichen. Unveränderte Produkte behalten ihren Download.
- Pull Request: gezielte Builds und Prüfungen; keine Veröffentlichung.
- Expliziter `vMAJOR.MINOR.PATCH`-Tag: setzt die Version eines geänderten Launchers.
- Die Launcher-Version wird mit `script/ci_version.py` oberhalb vorhandener Tags
  gewählt. Trainer verwenden eigene streng numerische Versionen. Ist ihre
  Quellversion nicht höher als vorhandene bzw. reservierte Tags, steigt die
  Patchnummer automatisch. Vorhandene Pakete und Tags werden niemals ersetzt.

Alle Veröffentlichungen laufen serialisiert. Ein Trainer erhält ein eigenes
**Prerelease** `trainer-<id>-v<version>` mit `<id>-<version>.zip`. Das ZIP enthält
exakt vier Dateien unter `<id>.mhtmodule/`: `Module.json`, `TrainerConfig.json`,
`Trainer.dylib`, `LICENSE`. Paketversion und Metadaten stimmen überein; native
Profile und Spielidentitäten werden unverändert übernommen. Alte Versionen bleiben
im Katalog und auf GitHub erhalten.

Erst nach bestätigtem Upload mit passender GitHub-SHA-256-Prüfsumme und Größe wird
der Katalog `trainer-catalog/catalog.json` aktualisiert. Auch dieses Release bleibt
Prerelease. Der Katalogtausch verwendet einen vorbereiteten Assetnamen und einen
kurzlebigen letzten bestätigten Katalog; bei Fehlern wird zurückgenommen. Ein
abgebrochener Lauf verwendet beim Wiederanlauf bestätigte Bytes und überspringt
bereits reservierte Tags. Ein nicht bestätigtes Paket erscheint niemals als
verfügbarer Download. Ein bereits veröffentlichtes stabiles App-Release trägt
seinen Quellfingerprint, sodass ein später fehlgeschlagenes Katalogupdate keinen
unnötigen App-Neubau erzwingt.

Nur Launcher-Releases `vX.Y.Z` sind stabil. Dadurch findet der bestehende
GitHub-App-Updater weiterhin ausschließlich App-Updates. Neue Trainerpakete
benötigen keine neue App-Veröffentlichung.

## Lokale Vorbereitung und erste Umstellung

Builddaten bleiben unter `~/Library/Developer/TrainerDock`. Normale Entwicklung:

```sh
python3 -B script/build.py --module stray
python3 -B script/build.py --launcher-only
```

Ein vollständiger Entwicklungsbuild kann weiterhin alle freigegebenen echten
Trainer extern bauen und prüfen. Das Launcher-Scheme benötigt keine vorhandenen
Trainerpakete mehr. Vor dem ersten schlanken App-Ersatz bestehende eingebettete
Trainer über `MHTTrainerStore` übernehmen; der Updatehelfer tut dies vor seinem
atomaren App-Tausch. Bestehende versionierte Benutzertrainer bleiben unangetastet.

Für echte vorhandene, geprüfte Runtimepakete, ohne einen App-Build auszulösen:

```sh
python3 -B script/trainer_distribution.py plan
python3 -B script/trainer_distribution.py package
```

`plan` schreibt den bestätigten Ausgangskatalog und Bauplan unter `Distribution/`;
`package` prüft und verpackt die tatsächlich geänderten externen Runtimepakete.
Ein erst nach vollständig beendetem Xcode-Build, finaler CodeSign-Phase und
Signaturprüfung vom Buildwrapper erzeugter Beleg unter `BuildFingerprints/`
bindet Quellfingerprint und tatsächliche Bibliotheksbytes. Fehlende oder abweichende
Belege verlangen einen neuen Trainerbuild; alte externe Binaries werden nicht
blind aktuellen Quellen zugeordnet. Direkte Xcode-Scheme-Builds erzeugen keinen
Veröffentlichungsbeleg; dafür anschließend `script/build.py --module <id>`
verwenden. Quelländerungen während des Builds verhindern die Belegerstellung.
Für die allererste Offline-Vorbereitung kann `--catalog <datei>` einen expliziten
bestätigten oder leeren Bootstrapkatalog verwenden. Keine erfundenen Paket-URLs
oder Prüfsummen ergänzen. `publish-trainers` veröffentlicht anschließend die
geprüften Pakete und den Katalog; erst danach den Launcher bauen, damit dessen
Offlinekatalog die tatsächlich verfügbaren Downloads enthält. Veröffentlichung
benötigt einen entsprechenden Auftrag und den vorhandenen GitHub-Repositoryzugang.

Die App übernimmt den bestätigten Katalog aus `TRAINERDOCK_CATALOG_FILE` oder
`~/Library/Developer/TrainerDock/Catalog/catalog.json`. Ohne solche Metadaten wird
ein gültiger leerer Katalog eingebaut. Die vollständigen Featuremetadaten stammen
aus den echten nativen Katalogexportern beim separaten Trainerbuild.

Nach Quell-/Targetänderungen `python3 -B script/xcode_project.py` ausführen und das
deterministisch erzeugte Xcode-Projekt mit committen. CI prüft, dass der Build es
nicht verändert. Keine Spiele starten, Originaldateien verändern oder Spiele-
Assemblies auf GitHub veröffentlichen.

## Eigene C#-Build-Abhängigkeiten

Escape from Duckov und Vampire Survivors benötigen beim C#-Kompilieren Referenzen
aus den originalen Spielinstallationen. Diese Spieldateien gehören weder ins
Repository noch auf einen GitHub-Runner oder in einen Download.

Deshalb stellt das Entwickler-Prerelease `managed-inputs-v4` ausschließlich unsere
beiden eigenen kompilierten Trainer-Assemblies bereit. Der Nutzer hat dieses
Paket ausdrücklich öffentlich freigegeben: Beide Trainer vermeiden wiederholte
Besitzer-Stringallokationen und unnötige Pflege bzw. Neuerzeugung eigener Stat-Werte.
Die getrennten Steam-/Epic-Buildtupel bleiben erhalten. Die Pakete
`managed-inputs-v1`, `managed-inputs-v2` und `managed-inputs-v3` bleiben unverändert.
`v4` enthält zusätzlich die abschließend geprüfte Duckov-Rezeptlisten-/Delegaten-
und Inventarverbesserung; beide eigenen DLLs sind im aktuellen Auftrag ausdrücklich
zur öffentlichen Bereitstellung freigegeben. Die übrigen nativen Quellen
einschließlich Loader, Bridges und Overlays werden bei geändertem Trainer mit Xcode
kompiliert. Auch die C#-Policy-Tests werden für betroffene Managed-Trainer aus ihren
Quellen kompiliert und ausgeführt. Der Cloud-Build kompiliert diese beiden Trainer-C#-Payloads selbst
nicht erneut gegen Spiele-Assemblies.

`Config/ManagedImages.json` enthält die Dateihashes und einen Hash der C#-Quellen,
Builddefinition und ursprünglichen Profilidentität. Jede Abweichung stoppt den
Build. Keine veralteten Payloads automatisch weiterverwenden oder Hashes nur zur
Umgehung einer fehlgeschlagenen Prüfung ändern.

Nach einer bewussten C#- oder Originalbindungsänderung:

1. Die richtigen Originalinstallationen in TrainerDock einrichten; weiterhin alle
   Buildidentitäten und Datei-Hashes prüfen lassen.
2. `TRAINERDOCK_MANAGED_IMAGES` entfernen. Mit
   `python3 -B script/managed_inputs.py --release managed-inputs-v5` die eigenen
   Bausteine lokal neu kompilieren. Sie liegen extern unter
   `~/Library/Developer/TrainerDock/ManagedInputs`; nur die JSON-Builddefinition
   gehört ins Git-Repository.
3. Den vollständigen Build und erforderliche genehmigte Ingame-Prüfungen durchführen.
   Nur die eigenen zwei `*.Managed.dll` als neue Entwickler-Release-Assets publizieren,
   keine Originalreferenzen. Die bisherigen Freigaben gelten konkret für die
   eigenen Bausteine der Entwickler-Releases v1 bis v4; zusätzliche Veröffentlichungen
   benötigen einen passenden Nutzerauftrag.
4. Quellen und Lockdatei zusammen committen. Der Cloud-Build muss die neuen
   veröffentlichten Bytes erfolgreich prüfen.

Ein eigener Baustein wird niemals als alternative Spielassembly geladen. Nur unser
Trainercode wird wie bisher vom Modul eingebettet und in der originalen, weiterhin
identifizierten Mono-Laufzeit ausgeführt. Synthetische Fixtures bleiben in `Tests/`.

## Paket und Signierung

`python3 -B script/release.py` prüft die aktuelle schlanke App
im externen stabilen Buildbaum; Trainer werden separat geprüft und paketiert. Ein kurzlebiger Paketordner wird anschließend
entfernt. Unter `~/Library/Developer/TrainerDock/Distribution` liegen das
aktuelle App-ZIP, `SHA256SUMS`, der Bauplan und die einzelnen Trainerpakete. Das App-Paket enthält genau `TrainerDock.app` mit Offlinekatalog,
GPL-Lizenz und Build-/Quellcommitangaben unter `Contents/Resources/BUILD.json`.
Keine Tests, Spiele, Referenzassemblies, Logs oder Xcode-Caches werden verpackt.

Die vorhandene Ad-hoc-Signierung bleibt erhalten. Die App ist damit nicht
Developer-ID-signiert und nicht notarisiert; GitHub Releases ändern diesen Status
nicht. Eine spätere notarisierte Distribution benötigt eigene Apple-Developer-
Zertifikate und eine ausdrücklich eingerichtete Notarisierung.

## GitHub-Updater

`App/MHTUpdater.*` fragt ausschließlich stabile Releases des festen Repositorys
`darkuser89/TrainerDock` ab. Versionsvergleich erfolgt numerisch; keine Downgrades.
Genau das Asset `TrainerDock-macOS-arm64.zip` mit GitHubs SHA-256-`digest` und
passender Größe wird akzeptiert. Keine zusätzlichen Signierschlüssel, Sparkle-Secrets
oder Schlüsselbundzugriffe verwenden. Die Prüfsumme schützt gegen beschädigte bzw.
abweichende Bytes; sie ist kein unabhängiger Herausgebernachweis.

`MHTUpdatePackage` prüft Größe und Hash vor dem Entpacken. Das ZIP darf ausschließlich
`TrainerDock.app` enthalten (AppleDouble-Metadaten werden übersprungen); Traversal,
Links und Spezialdateien werden abgelehnt. Größen-/Eintragsgrenzen verhindern
unbegrenztes Entpacken. Die vorhandene Ad-hoc-Codeversiegelung wird auf Integrität
geprüft, ohne Zertifikat oder eigene Signierschlüssel zu verlangen.

Der kopierte eigene Updatehelfer wartet auf das reguläre Ende genau des alten
Launcherprozesses, prüft laufende Spiele erneut und tauscht das vollständige App-Bundle
auf demselben Volume atomar aus. Scheitert der Start über LaunchServices, wird der
Tausch zurückgenommen. Es wird kein Spiel beendet und kein Systemschutz verändert.
Der kurzlebige Austauschordner liegt neben der App und wird nach Abschluss entfernt.
Benutzermodule und Einstellungen liegen außerhalb der App und bleiben erhalten.

CI installiert `libarchive` ausschließlich für die Header und LuaJIT ausschließlich
für synthetische Tests. Die App linkt `/usr/lib/libarchive.2.dylib`; weder Homebrew-
Bibliotheken noch Tests gelangen ins Paket. Der Archive-Headerpfad ist über
`TRAINERDOCK_ARCHIVE_INCLUDE` in der Xcode-Konfiguration anpassbar.
