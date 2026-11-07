# GitHub-Build und Veröffentlichung

`.github/workflows/build-release.yml` verwendet GitHubs Apple-Silicon-Runner
`xcode-27` mit macOS 27 und macOS-27-SDK. Die native Mindestversion bleibt 27.0.
Der Workflow startet keine Spiele und benötigt keine privaten Signierschlüssel.

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
aktuelle ZIP und `SHA256SUMS`. Das Paket enthält einen TrainerDock-Ordner mit App,
benachbarten Modulen, GPL-Lizenz, Installationshinweis und Build-/Quellcommitangaben.
Keine Tests, Spiele, Referenzassemblies, Logs oder Xcode-Caches werden verpackt.

Die vorhandene Ad-hoc-Signierung bleibt erhalten. Die App ist damit nicht
Developer-ID-signiert und nicht notarisiert; GitHub Releases ändern diesen Status
nicht. Eine spätere notariserte Distribution benötigt eigene Apple-Developer-
Zertifikate und eine ausdrücklich eingerichtete Notarisierung.
