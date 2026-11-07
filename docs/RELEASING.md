# GitHub-Build und Veröffentlichung

`.github/workflows/build-release.yml` verwendet GitHubs Apple-Silicon-Runner
`xcode-27` mit macOS 27 und macOS-27-SDK. Die native Mindestversion bleibt 27.0.
Der Workflow startet keine Spiele und benötigt keine privaten Signierschlüssel.
Balatros synthetische Lua-/Scoring-/Besitzertests laufen im Cloud-Build mit
separatem Homebrew-LuaJIT. Die Prüfung mit Balatros ursprünglicher Lua-Bibliothek
wird dabei ausdrücklich als nicht durchgeführt gemeldet. Der Ersatz befindet sich
ausschließlich im Testprozess und wird nicht ins Produkt oder ZIP eingebunden.
Lokale Tests verwenden ohne `TRAINERDOCK_TEST_LUA_LIBRARY` weiterhin das Original.

- Push auf `main`, Pull Request oder **Actions → Build and release TrainerDock →
  Run workflow**: Release-Konfiguration bauen, synthetisch prüfen, ZIP als Artefakt
  für sieben Tage bereitstellen.
- Tag `vMAJOR.MINOR.PATCH`: denselben vollständigen Build ausführen und erst danach
  ein GitHub Release mit ZIP und SHA-256-Prüfsumme veröffentlichen.
- Bestehende Releases nicht überschreiben. Für einen korrigierten Download einen
  neuen Versions-Tag verwenden.

Ein Release aus einem bereits geprüften `main` veröffentlichen:

```sh
git tag -a v1.0.0 -m 'TrainerDock 1.0.0'
git push origin v1.0.0
```

`v1.0.0` ist nur das erste Versionsbeispiel; bereits vorhandene Tags nicht ersetzen.
Der Tag setzt die App-Version, die Workflow-Laufnummer die App-Buildnummer.
Der Build darf die generierte Xcode-Projektdatei nicht verändern; neue Modulquellen
deshalb vor dem Commit mit `python3 -B script/xcode_project.py` eintragen.

## Eigene C#-Build-Abhängigkeiten

Escape from Duckov und Vampire Survivors benötigen beim C#-Kompilieren Referenzen
aus den originalen Spielinstallationen. Diese Spieldateien gehören weder ins
Repository noch auf einen GitHub-Runner oder in einen Download.

Deshalb stellt das Entwickler-Prerelease `managed-inputs-v1` ausschließlich unsere
beiden eigenen kompilierten Trainer-Assemblies bereit. Der Nutzer hat deren
öffentliche Veröffentlichung ausdrücklich genehmigt. Die übrigen nativen Quellen
einschließlich Loader, Bridges und Overlays werden in jedem Cloud-Build mit Xcode
kompiliert. Auch die C#-Policy-Tests werden jedes Mal aus ihren Quellen kompiliert
und ausgeführt. Der Cloud-Build kompiliert diese beiden Trainer-C#-Payloads selbst
nicht erneut gegen Spiele-Assemblies.

`Config/ManagedImages.json` enthält die Dateihashes und einen Hash der C#-Quellen,
Builddefinition und ursprünglichen Profilidentität. Jede Abweichung stoppt den
Build. Keine veralteten Payloads automatisch weiterverwenden oder Hashes nur zur
Umgehung einer fehlgeschlagenen Prüfung ändern.

Nach einer bewussten C#- oder Originalbindungsänderung:

1. Die richtigen Originalinstallationen in TrainerDock einrichten; weiterhin alle
   Buildidentitäten und Datei-Hashes prüfen lassen.
2. `TRAINERDOCK_MANAGED_IMAGES` entfernen. Mit
   `python3 -B script/managed_inputs.py --release managed-inputs-v2` die eigenen
   Bausteine lokal neu kompilieren. Sie liegen extern unter
   `~/Library/Developer/TrainerDock/ManagedInputs`; nur die JSON-Builddefinition
   gehört ins Git-Repository.
3. Den vollständigen Build und erforderliche genehmigte Ingame-Prüfungen durchführen.
   Nur die eigenen zwei `*.Managed.dll` als neue Entwickler-Release-Assets publizieren,
   keine Originalreferenzen. Die ursprüngliche Freigabe gilt konkret für die zwei
   eigenen Bausteine des ersten Entwickler-Releases; zusätzliche Veröffentlichungen
   benötigen einen passenden Nutzerauftrag.
4. Quellen und Lockdatei zusammen committen. Der Cloud-Build muss die neuen
   veröffentlichten Bytes erfolgreich prüfen.

Ein eigener Baustein wird niemals als alternative Spielassembly geladen. Nur unser
Trainercode wird wie bisher vom Modul eingebettet und in der originalen, weiterhin
identifizierten Mono-Laufzeit ausgeführt. Synthetische Fixtures bleiben in `Tests/`.

## Paket und Signierung

`python3 -B script/release.py` prüft die aktuelle App und alle freigegebenen Module
im externen stabilen Buildbaum. Ein kurzlebiger Paketordner wird anschließend
entfernt. Unter `~/Library/Developer/TrainerDock/Distribution` bleiben nur das
aktuelle ZIP und `SHA256SUMS`. Das Paket enthält genau `TrainerDock.app` mit eingebetteten eigenständigen Modulen,
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
