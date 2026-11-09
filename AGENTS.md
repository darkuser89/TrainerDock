# TrainerDock – Anleitung für weitere Chats

## Auftrag und Grenzen

TrainerDock ist ein universeller macOS-Launcher mit unabhängigen Spielmodulen. Links stehen
installierte Spiele, rechts deren Trainerfunktionen und Startaktion. Die Option
„Alle Trainer“ zeigt auch noch nicht eingerichtete Spiele. Store, Spielbuild
und individuelle Installationspfade gehören zum Profil des jeweiligen Moduls.

Produktname, App und Xcode-Schemes heißen **TrainerDock**. Der bestehende
Codeordner `/Users/jbw/Documents/MHT` bleibt der kanonische Quellpfad.
`MHT*`-SDK-Symbole, Protokoll-/Einstellungsschlüssel und `.mhtmodule` sind stabile
Kompatibilitätskennungen. Neue Module verwenden diesen bestehenden Vertrag.
Die App übernimmt bisherige Einstellungen einmalig aus `local.mht.launcher`
nach `local.trainerdock.launcher`, ohne neuere Werte zu überschreiben. Zusätzliche
Module liegen unter `~/Library/Application Support/TrainerDock/Modules`;
der bisherige MHT-Ordner wird weiterhin gelesen.

- Vor Änderungen `git status --short` und `git diff` prüfen. Fremde Änderungen schützen.
- Den globalen Skill `/Users/jbw/.codex/skills/graphify-offline/SKILL.md` verwenden:
  `graphify status`, gegebenenfalls `extract`/`update`, konkrete Abfragen und danach
  Quellcodeprüfung. Den Index nach relevanten Änderungen aktualisieren.
- Die sechs ursprünglichen Trainerprojekte sind Referenzen und bleiben unverändert.
  Ihre Dokumente beschreiben die Herkunft; sie ersetzen keinen aktuellen Nutzerauftrag.
- Keine Spiele automatisch für Entwicklungstests starten oder beenden. Builds und
  synthetische Tests sind erlaubt. Ein normaler Klick auf „Spiel mit Trainer starten“
  startet ausschließlich das ausgewählte Profil. Kein stiller Ersatzstart ohne Trainer.
- Keine Signaturen, Entitlements, Schutzmechanismen oder ausführbaren Spieldateien
  verändern. Keine unbekannten UUIDs als unterstützt ausgeben. Saves nicht bearbeiten.
- Ausschließlich echte Trainer ausliefern: Jede angebotene Funktion muss über eine
  tatsächlich implementierte native Spielanbindung verfügen. Keine Demo-Trainer,
  simulierten Cheatwirkungen, Attrappen oder vorgetäuschten Erfolgsanzeigen im Produkt.
  Nicht implementierte oder nicht belegte Funktionen deaktiviert lassen und klar
  kennzeichnen. Synthetische Fixtures sind ausschließlich unter `Tests/` erlaubt und
  dürfen nicht in Launcher oder Trainermodule eingebunden werden.
- Alle sichtbaren Trainertexte auf Deutsch halten: Funktionsnamen, Beschreibungen,
  Gruppen, Schaltflächen, Bedienhilfen sowie Status- und Fehlermeldungen. Spielnamen
  und Marken beibehalten; interne Feature-IDs, Protokollschlüssel, native Typ-/Methodennamen
  und Tastenzuordnungen bei Übersetzungen nicht verändern. Der native Katalog ist
  die gemeinsame Textquelle für Launcher und Ingame-Trainer.
- Code, Builds, App und Audit getrennt halten. Der stabile Buildordner ist
  `~/Library/Developer/TrainerDock`, außerhalb dieses Repositories. Genau eine aktuelle
  geprüfte `TrainerDock.app`; kurzlebige Austauschdaten werden automatisch entfernt.
  Keine Apps, Binaries, Logs, Caches oder Auditberichte im Code ablegen.
- Ein Audit wird nur bei konkretem Bedarf separat erstellt und bleibt unter
  1.000.000.000 Byte. Ungeprüfte Behauptungen sind keine Ergebnisse.

## Architektur

- `TrainerDock.xcodeproj`: echtes natives Xcode-Projekt. Scheme `TrainerDock` baut und prüft alle
  Produkte; `TrainerDock-Launcher` nur den Launcher, `Trainer-<id>` ein Trainermodul.
  Mindestversion für App und Trainer: macOS 27.0. Der Launcher bleibt arm64;
  Trainerarchitekturen werden ausdrücklich durch ihre Profile und `Build.json` gebunden.
  `Config/TrainerDock.xcconfig` ist die gemeinsame Buildkonfiguration.
- `App/`: gemeinsames AppKit-Fenster, native Seitenleiste, Suche, Spielicons,
  Pfade und Bedienung. Icons nur aus tatsächlich installierten Spiele-Apps lesen.
  Die vom Nutzer gewählte Fenstergröße beim Spielwechsel erhalten; lange Texte
  kürzen und lange Funktionslisten scrollen, niemals das Fenster daran anpassen.
  Die Bibliothek liegt in einer nativen interaktiven `NSGlassEffectView`. Keine
  deckenden Sidebar-Füllungen oder zusätzlichen Blur-Schichten darüber legen;
  die macOS-Barrierefreiheit steuert den Glasersatz. Die Fensterunterlage der
  nativen Titelleiste erhalten; `clearColor` am Fenster macht sie unsichtbar.
  Liquid Glass ist dauerhaft aktiviert; keinen Benutzerschalter dafür anbieten.
  Die native Ersatzdarstellung bei reduzierter Transparenz bleibt erhalten.
  Lange Installationspfade nur in den Pfadeinstellungen bzw. als Tooltip anzeigen.
- `Core/`: Modulprüfung, Installationserkennung, Profile und Startumgebung.
  Verzeichnissuche und Build-Prüfung der Anzeige laufen im Hintergrund. Veraltete
  Ergebnisse nach Spiel-/Profilwechsel verwerfen; neu gewählte Pfade schützen.
  Vor dem expliziten Spielstart weiterhin vollständig und frisch prüfen.
- `ModuleSDK/`: gemeinsames Nachrichtenprotokoll und die schmale Runtime-Anbindung.
- `Modules/<spiel-id>/Module.json`: eigenständige Spieldefinition; keine Spielpfade.
  `groups` ordnet jede native Feature-ID genau einmal einer aufklappbaren
  Funktionsgruppe zu; Vertrag und Beispiel unter `docs/MODULES.md`. Keine
  spielabhängige Gruppierungslogik im Host. Keine Hintergrundbilder im Launcher.
- `Modules/<spiel-id>/Sources/`: vollständiger Trainer mit nativen Adaptern,
  Katalogen, Bridges und Ingame-Overlay. Resident Evil teilt Entwicklungsquellen
  unter `Modules/_Shared/ResidentEvil`; jedes gebaute Modul ist eigenständig.
- `Tests/`: synthetische Tests, keine Bestandteil der ausgelieferten Anwendung.
- `script/`: Build und Modulerstellung. `docs/`: versionierte Entwickleranleitungen.

Das Hostprogramm liest ausschließlich geprüfte Modulmetadaten aus dem mitgelieferten
`Contents/Resources/TrainerCatalog.json` und dem letzten gültigen Onlinekatalog.
Die App enthält keine nativen Trainerpakete. Downloads liegen versioniert unter
`~/Library/Application Support/TrainerDock/Modules/<id>/<version>/<id>.mhtmodule`.
Übernommene Altbestände liegen kollisionsfrei unter `<id>/legacy-<Inhaltshash>/`;
die ursprüngliche Trainerversion bleibt erhalten. Alte flache TrainerDock-/MHT-
Ordner werden weiterhin gelesen. Laufende Sitzungen behalten ihre genaue
Modulinstanz und ihren Runtimepfad. Versionen niemals überschreiben oder automatisch
löschen; Löschungen schützen aktive Sitzungen, Spielprozesse und gemappte Dateien.
Die ausdrückliche Sammelaktion „Alle installierten Trainer aktualisieren“ prüft zuerst
den Onlinekatalog und lädt nur fehlende neueste Pakete bereits installierter Trainer.
Suchfilter grenzen diese Aktion nicht ein. Downloads erfolgen nacheinander mit
Fortschritt und Fehlerübersicht; ein Teilfehler stoppt die übrigen Updates nicht.
Keine Downgrades, erneuten Downloads vorhandener Releases oder automatischen Löschungen.
Laufende Sitzungen behalten auch während dieser Aktion ihre bisherige Runtime.
Der Launcher enthält keine Spiellogik.
Native Runtime-
Bibliotheken werden erst beim ausdrücklich angeforderten Spielstart im ausgewählten
Spielprozess geladen. Gleichnamige Objective-C-Klassen verschiedener Backends dürfen
niemals gemeinsam in den Launcherprozess geladen werden.

`script/xcode_project.py` aktualisiert das versionierte Projekt deterministisch aus
`Build.json`. Nach Änderungen an Sources, Defines, Tests oder Freigabestatus eines
Moduls ausführen; der Skript-Build erledigt das automatisch. Generierte Targets nicht
parallel von Hand pflegen. Tests sind keine Produktquellen. Xcode verwaltet
inkrementelle Objekte im externen stabilen Buildbaum, nicht im Repository.

Ein einzelnes Modul wird mit `python3 -B script/build.py --module <id>` gebaut,
ohne den Launcher neu zu kompilieren. Entwicklungsprodukte bleiben im externen
Buildbaum und werden nicht automatisch installiert. Bestätigte Veröffentlichungen
über den Trainerkatalog laden und in der Trainerverwaltung installieren.

GitHub Actions plant über `.github/workflows/build-release.yml` auf `xcode-27`
gegen den zuletzt erfolgreich veröffentlichten Trainerkatalog. Nur geänderte
Quell-Fingerabdrücke werden gebaut; gemeinsame Header, SDK, Buildoptionen und eigene
Managed-Abhängigkeiten zählen mit. App-Änderungen erfordern keinen Trainerbuild.
`script/trainer_distribution.py` plant, paketiert und veröffentlicht getrennt.
Trainer-Releases `trainer-<id>-v<version>` sind unveränderliche Prereleases;
`trainer-catalog/catalog.json` verweist erst nach Paketprüfung darauf. Frühere
Versionen bleiben verfügbar. Geänderte Trainer erhalten eine eigene neue Version,
Spielbuild/Store bleiben getrennte Profile. Neue Spielbuilds niemals automatisch
als unterstützt deklarieren. Der Launcher wird nur bei eigener Änderung als
stabiles `vX.Y.Z` veröffentlicht; `script/release.py` verpackt ausschließlich die
App samt Metadaten, Lizenz und Versionsangaben. PRs veröffentlichen keine Releases.
Kein Spielstart und keine Veröffentlichung von Spieldateien gehören zum CI-Build.
Duckov und Vampire Survivors beziehen nur eigene kompilierte C#-Bausteine aus dem
vom Nutzer ausdrücklich genehmigten Entwickler-Release `managed-inputs-v4`.
`Config/ManagedImages.json` bindet deren Bytes, Quellen und Originalprofile;
bei Änderungen lokal neu kompilieren und die Bausteine bewusst aktualisieren.
Kein stiller Hashwechsel und keine Ersatz- oder Testassembly. Details:
`docs/RELEASING.md`. Ad-hoc-Signierung ist keine Notarisierung.

### Neue Trainer und Spielupdates einzeln ausliefern

- Neues Spiel: mit `script/new_module.py` eine neue stabile Modul-ID anlegen;
  bis zur belegten Anbindung `developmentOnly` und deaktivierte Profile erhalten.
- Spielupdate oder weiterer Store: das vorhandene `Modules/<id>` weiterentwickeln,
  kein zweites Modul, Quellarchiv oder Versionsverzeichnis im Code anlegen.
  Bisherige geprüfte Profile und IDs erhalten; neue Build-/Storeidentitäten als
  eigene Profile ergänzen und deren native Bindungen tatsächlich prüfen.
  Altprofile ohne belegte Bindung in der neuen Runtime deaktivieren; deren
  bisherige Releases bleiben unverändert verfügbar.
- Trainerpaketversion (`MAJOR.MINOR.PATCH`), Spielbuild und Store getrennt halten.
  Ein neues Paket erweitert nicht automatisch die Kompatibilität. Inkompatible
  Feature-ID-Änderungen benötigen zusätzlich eine neue `selectionVersion`.
- Mit `python3 -B script/build.py --module <id> --configuration Release` gezielt
  bauen und prüfen. Der Veröffentlichungsbeleg entsteht erst nach Xcodes finaler
  Codeversiegelung; direkte Scheme-Builds oder alte Binaries ersetzen ihn nicht.
  Lokale Buildprodukte werden nicht automatisch im Launcher installiert.
- Bei beauftragter Veröffentlichung Quellen, Profile, Tests und das regenerierte
  Xcode-Projekt zusammen auf `main` bringen. CI plant gegen den letzten bestätigten
  Katalog, baut alle tatsächlich betroffenen Trainer und veröffentlicht deren
  neue unveränderliche Pakete. Für einen reinen Trainerwechsel keinen App-Tag und
  keinen Launcher-Gesamtbuild erzwingen. Geteilte Abhängigkeiten können mehrere
  Trainer betreffen; den ermittelten Bauplan nicht künstlich auf eine ID kürzen.
- Einzelreleases sind erst abgeschlossen, wenn Paket und Katalog bestätigt sind
  und die App den Download anbietet. Alte Releases, installierte Versionen,
  Einstellungen und laufende Runtimepfade erhalten. Paketversionen, Prüfsummen
  und Buildbelege niemals nachträglich überschreiben oder zur Fehlerumgehung ändern.

Der konkrete Ablauf einschließlich lokaler Paketierung und Wiederanlauf nach
Fehlern steht in [docs/RELEASING.md](docs/RELEASING.md#neue-trainer-und-spielupdates-veröffentlichen).
Diese Anleitung erweitert weder Veröffentlichungs- noch Spielstartfreigaben.

Epic-Profile verwenden getrennte Storekennungen und Installationspfade, auch bei
gleicher Bundle-ID wie Steam. `launchMode: "epic"` nutzt `Core/MHTEpicLaunch` und
den eigenen `TrainerDockEpicBroker`; keine Spiellogik im Host ergänzen. Der Epic-
Client muss zuvor regulär beendet sein, weil sein Cache Startmetadaten überschreibt.
TrainerDock beendet ihn nicht automatisch. Der kurzlebige Helfer liegt außerhalb
des Spiele-Bundles; ausschließlich Epics Startzuordnung wird journalgesichert
geändert und bytegenau zurückgenommen. Authargumente nur unverändert weiterreichen,
niemals auswerten, speichern oder loggen. Kein Ersatzstart ohne Trainer.

## Bei neuen Modulen

Die Überschrift oben links im Ingame-Trainer zeigt den vollständigen Spielnamen,
niemals „TrainerDock“ oder einen technischen Bundle-Namen. `gameTitle()` im Modul
ist die gemeinsame Quelle für Zeichnung und Bedienhilfe. Der Generator setzt den
angegebenen Spielnamen auch bei Verwendung eines bestehenden Moduls als Vorlage.
Den Titelbereich vor den rechten Fensteraktionen halten; lange Namen dürfen diese
nicht überdecken. Der Launcher behält seinen Produktnamen TrainerDock.

HiDPI: In Punkten layouten, Original-Iconrepräsentationen erhalten und AppKit die
Backing-Layer-Auflösung verwalten lassen. Für eigene Overlayzeichnungen
`ModuleSDK/MHTHiDPI.h` verwenden; bei Zoom- und Backing-Wechseln neu zeichnen.
Keine fest verdrahteten 1×/2×-Bitmaps oder `contentsScale`-Werte. Details und
synthetische 1×/2×-Prüfungen stehen in `docs/ARCHITECTURE.md`.

Jeder Ingame-Trainer besitzt unten rechts den gemeinsamen Regler
`MHTGlassSlider` aus `ModuleSDK/MHTGlassIntensity.*`. Die Option `glassIntensity`
bleibt durch Normalisierung, Laufzeitmeldungen, Speicherung pro Modul und den
nächsten Start erhalten: 0 transparent, 0,5 natives Glas (Standard), 1 deckend.
Nur den Hintergrund verändern, niemals Texte/Bedienelemente mit ausblenden.
Die neutralen Sources und `Build.json` enthalten die vollständige Anbindung;
auch neue Trainer müssen sie erhalten. Details unter `docs/ARCHITECTURE.md`.

Zuerst `Templates/Trainer/README.md`, `docs/MODULES.md` und `docs/ARCHITECTURE.md`
lesen. Andere Chats können dafür den globalen Skill `$trainer-template` verwenden.
`script/new_module.py` verwendet standardmäßig die neutrale Vorlage `trainer`;
unfertige Module bleiben `developmentOnly` und werden nicht als Produkt ausgeliefert. Keine Adressen oder
Signaturen anderer Spiele übernehmen. Neue Profile standardmäßig deaktiviert lassen,
bis Identität, Engine-Anbindung, GameThread-Zustellung und Effekte belegt sind.
Einmalaktionen dürfen nie beim Start wiederholt werden. Dauerschalter erst im
gültigen lokalen Spielkontext anwenden; alte Aufträge nach Besitzerwechsel verwerfen.
Auf ausdrücklichen Nutzerwunsch gibt es keine Netzwerksperre. Netzwerkstatus darf
weder Funktionen blockieren noch Aktivierungswünsche löschen; auch neue Trainer
und die Vorlage müssen diesen Vertrag beibehalten.
Nur bestätigte Rückleseergebnisse dürfen „Aktiv“ melden.

Native Glas-/Auto-Layout-Views nicht direkt in Enginefenster einbauen, deren
Fensterabfragen oder Größenwechsel auf einem GameThread stattfinden. Dafür den
isolierten `ModuleSDK/MHTOverlayHost` verwenden; das Spielfenster selbst bleibt
ohne zusätzliche Trainer-Views oder Constraints. Eingaben in die Overlaykoordinaten
umrechnen und den Fokus beim Spiel belassen. DI2 und Lies of P besitzen dafür
Regressionstests. `Tests/OverlayRuntimeWindowTests.m` prüft außerdem den tatsächlichen
Runtime-Anbindungscode von Cyberpunk 2077, Crimson Desert, RoboCop und allen fünf
Resident-Evil-Trainern: parallele Fensterabfragen, Größen-/Vollbildmeldungen,
erneuerte Content-Views und Klickkoordinaten. Diese synthetischen Prüfungen ersetzen
keinen Ingame-Test. Shortcuts müssen bei einem isolierten Panel dessen Elternfenster
als Spielfenster berücksichtigen. Geometriemeldungen auch vom Engine-Thread nur
asynchron auf den Hauptthread zustellen; nie synchron auf AppKit warten.
Spielspezifische Cursorfreigaben weiterhin auf der originalen Eingabeansicht ausführen,
nicht auf der Content-View des Overlaypanels.

## Mausprobleme früh abfangen, Spielstarts bündeln

Vor der ersten Ingame-Prüfung [docs/OVERLAY_INPUT.md](docs/OVERLAY_INPUT.md) lesen.
Die dort dokumentierten NMS-Erkenntnisse gelten als Diagnosemuster, nicht als
übertragbare Spieladressen:

- Sichtbaren Zeiger, echte Engine-Mausfreigabe und Klickzuordnung getrennt prüfen.
  Ein Menütest belegt keine freie Maus im laufenden Spiel.
- AppKit-Ivars zur Laufzeit über `ivar_getOffset` auflösen; Typ und Grenzen prüfen.
  Alle relevanten Capture-Ebenen und eine mögliche frameweise erneute Bindung beachten.
- Leere System-Cursorbilder erkennen. Sichtbare Pixel bei 1×/2× auf geleerten
  Zeichenflächen prüfen; bei Bedarf einen klickdurchlässigen Vektorpfeil verwenden.
- Sichtbarkeit nach Bedienwunsch/Fokus steuern. Verzögerte Capture-Meldungen dürfen
  Cursor oder Overlay nicht zum Blinken bringen. Rückgabe an Spielmenüs und bei
  Fokusverlust prüfen; keine globalen Hide-Zähler als Reparatur verwenden.
- Native Analyse, Diagnose und synthetische Tests vor dem ersten Start vorbereiten.
  Mausprüfungen und mehrere reversible Trainerfunktionen in einem freigegebenen
  Lauf bündeln. Bei Fehlern Ursachen eingrenzen und Korrekturen zusammen prüfen,
  bevor ein weiterer Start nötig wird. Nach ausreichender Bestätigung aufhören.
- Doppelstarts verhindern. Geladene Testbibliotheken nicht überschreiben; einen
  geprüften kurzlebigen Austauschbestand erst nach regulärem Ende einsetzen.
  Bestehende Freigaben beachten; diese Anleitung erteilt keine zusätzlichen Spielstarts.

## Leistung im laufenden Spiel schützen

- Frame-Rückrufe und Kontextpoll getrennt behandeln. Ohne aktivierte Effekte,
  eigene zurückzunehmende Leases oder explizite Aufträge darf ein Framepfad keine
  Inventar-, Rezept-, Gegner-, Portal- oder Szenensuche auslösen. Verfügbarkeit
  im bestehenden Kontextpoll prüfen; Einmalaktionen ausschließlich auf Auftrag.
- Ein unveränderter Funktionspoll darf nicht erneut die Pflege aller aktiven
  Effekte anstoßen. Aktive Effekte behalten ihren nötigen originalen Framepfad;
  Spielthread-Zustellung und echte Rücklesebestätigung nicht wegoptimieren.
- Nur unveränderliche Metadaten begrenzt cachen. Domain-, Besitzer-, Weak-/GC-,
  Typ- und Deskriptorprüfungen bleiben erhalten; Spielwerte frisch lesen.
  Fehlgeschlagene Auflösungen nicht dauerhaft cachen. Gleichwertige eigene Werte
  nach gültigem Rücklesen nicht erneut schreiben; native Benachrichtigungs- und
  Settersemantik beachten. Fremde Änderungen und Rücknahme weiterhin schützen.
- Ausgeblendete Overlays verarbeiten nur den letzten Zustand; unveränderte
  sichtbare Zustände erzeugen keine neuen Zeichenanforderungen. Beim Öffnen
  sofort den aktuellen Zustand zeigen. Unveränderte Heartbeats dürfen keine
  wiederholten Einstellungs- oder Auswahlschreibvorgänge auslösen.
- Performanceprüfungen müssen Originalpfade mit synthetischen Aufrufzählern
  absichern: Leerlauf, aktive Wirkung, Besitzerwechsel, Ausschalten und erneute
  Aktivierung. Eine Codeprüfung oder weniger Aufrufe ist kein FPS-Nachweis.
  Ingame-Messungen getrennt und nur mit entsprechendem Auftrag durchführen.

## Prüfen und ausführen

Storevarianten benötigen getrennte, vollständig identifizierte native Bindungen.
Bei Control sind Steam 1.34 (Build 3), MAS 1.33.1 (Build 27) und MAS 1.371 (Build 28) über jeweils fünf
Image-UUIDs gebunden. Originale Aufrufer und Feldlayout je Variante prüfen:
Controls MAS-Munitionswert verwendet dieselbe Pin-Benachrichtigung mit Handle
bei +8 wie der Energiewert; ein ähnlich benannter Signalpfad mit Handle bei +4
ist dafür ungeeignet. Keine Adressen nur nach Ähnlichkeit übernehmen.
Separate Objective-C++-Prüfer müssen C-Protokollheader als `extern "C"` einbinden
und nur konkrete Exports des Produktruntimes zulassen. Der Control-Testbuilder
`Tests/Control/BuildStoreTest.py` prüft diese Bindungen vor einem Spielstart.
Bei einem verschwundenen Testprozess zuerst Absturzbericht und tatsächliche
Prozess-ID prüfen; ein neues Öffnen über UI-Werkzeuge kann einen untrainierten
Spielprozess erzeugen und den ursprünglichen Fehler verdecken.

```sh
./script/build_and_run.sh --build-only
./script/build_and_run.sh --verify
./script/build_and_run.sh --launcher-only  # nur UI bauen, prüfen und öffnen
```

Der Xcode-Build kompiliert alle freigegebenen vollständigen Trainermodule und den Launcher mit Warnungen als Fehlern,
führt Protokoll-, Modul-, Bridge- und Darstellungsprüfungen durch und prüft die
Ad-hoc-Signaturen. `--verify` öffnet ausschließlich den Launcher. Ein erfolgreicher
Build oder synthetischer Test ist kein Ingame-Nachweis. In Antworten fehlende
Ingame-Prüfungen ausdrücklich benennen. Kurz und direkt berichten.

## Vampire Crawlers: eng begrenzte Originalfreigabe

Der Nutzer hat für den erfassten Steam-Build 1.6.1 (11), Build-ID 25304267,
ausdrücklich die Profilprüfung `sha256-original` genehmigt. Seine Originalsignatur
bleibt unverändert. Die lückenlosen Hashes der in dessen Profil aufgeführten
Originaldateien, Version und UUID sind Pflicht; keine stillen Hashupdates oder
Freigaben weiterer Builds. Andere Profile behalten die bisherige Signaturprüfung.

## No Man’s Sky: eng begrenzte Originalfreigabe

Der Nutzer hat für Steam-Build-ID 26386568, Bundleversion 4.70, arm64-UUID
`1FABCC98-D6B6-3905-BF1B-823BD5033DA9` die vollständige Profilprüfung
`sha256-original` ausdrücklich genehmigt, nachdem Steam die Installation als
korrekt meldete. Nur die erfassten Originaldateien und Hashes freigeben.
Keine Spielsignaturen oder Schutzmechanismen verändern; weitere Builds bleiben
ohne eigene Prüfung und Freigabe gesperrt.

## App-Updates ohne zusätzliche Signierung

Der Nutzer wünscht Updates direkt über GitHub Releases ohne zusätzliche
Update-Signierung, Zertifikate, Schlüsselbundabfragen oder Signing-Secrets.
`App/MHTUpdater.*` und `MHTUpdatePackage.*` verwenden ausschließlich stabile neuere
Releases von `darkuser89/TrainerDock`, prüfen Assetgröße und GitHubs SHA-256-Digest
vor dem Entpacken und ersetzen ausschließlich die App. Versionierte Benutzertrainer bleiben erhalten;
eingebettete Alttrainer werden vor dem Austausch vollständig geprüft übernommen.
Keine Downgrades, fremden Downloadquellen oder unvollständigen Pakete akzeptieren.
Das native ZIP-Entpacken erlaubt keine Pfadausbrüche, Links oder Spezialdateien.
Vor Installation laufende Spiele abwarten und im Helfer erneut prüfen; Spiele
niemals für Updates schließen. Bei fehlgeschlagenem App-Start den atomaren Tausch
zurücknehmen. Benutzermodule und Einstellungen bleiben außerhalb der App.
Die vorhandene technische Ad-hoc-Codeversiegelung der arm64-Produkte bleibt bestehen;
macOS-Schutzmechanismen nicht verändern. Keine privaten Schlüssel verwenden.

## Frostpunk 2: eng begrenzte Originalfreigabe

Der Nutzer hat nach erfolgreicher Steam-Dateiprüfung ausschließlich Steam-Build
24037022, Bundleversion 0.5.591, arm64-UUID
`10F7F2EA-0D13-337E-BF07-ABA47A4549CF` für `sha256-original` genehmigt.
Die vier Originaldateien aus `Modules/frostpunk-2/Module.json` müssen vollständig
mit ihren 31 lückenlosen SHA-256-Prüfabschnitten übereinstimmen. Keine stillen
Hashupdates, Signaturänderungen oder Freigaben anderer Builds.

Bei Unreal-Levelstreaming ist `Level.OwningWorld` maßgeblich; der Level-Outer
kann ein eigenes Paket-Worldobjekt sein. Die echte aktive Weltzugehörigkeit
prüfen, statt Paket-Outer mit Spielerwelt gleichzusetzen. Native UFunction-
Parameter aus der geladenen Reflexion prüfen, einschließlich Schreibweise und
ParmsSize. Einmalaktionen und Ratsphasenwechsel niemals periodisch wiederholen.

## The Long Dark: eng begrenzte Originalfreigabe

Der Nutzer hat nach Steams fehlerfreier Dateiprüfung ausdrücklich die vollständige
Prüfung `sha256-original` für Steam-Build **26450964**, Version **2.60 (0)**,
arm64-UUID `96B749EC-0FB3-332F-96F9-1859539DE52C` genehmigt. macOS beanstandet
in dieser Installation die mitgelieferte `Contents/PlugIns/libsteam_api.dylib`.
Die Originaldateien und Signaturen bleiben unverändert. Die sieben im Profil
aufgeführten Dateien müssen lückenlos ihren gespeicherten SHA-256-Werten entsprechen;
keine stillen Hashupdates und keine Freigabe weiterer Builds.

Die IL2CPP-Anbindung dieses Spiels muss Referenzfelder mit dem typisierten
`il2cpp_field_set_value_object` schreiben: Das dritte Argument ist das Objekt
selbst, nicht die Adresse einer lokalen Zeigervariablen. Primitive Felder verwenden
ihren eigenen Rohwertpfad. `Inventory.m_Items` enthält inline gespeicherte
`GearItemObject`-Werte; eine solche Liste darf nicht als Referenzarray gelesen werden.
Die Modul-Grenztests sichern beide ABI-Grenzen außerhalb des Spiels ab.

## Terraria: eng begrenzte Originalfreigabe

Der Nutzer hat ausschließlich Steam-Build **24893155**, Spielversion **1.4.5.8**,
arm64-UUID `EC32A5AF-44E5-37D6-8BB7-60B58BCD68FD` ausdrücklich über
`sha256-original` freigegeben. Alle 28 im Profil erfassten Originaldateien müssen
in ihren 33 lückenlosen Abschnitten übereinstimmen. Das originale Shellskript
`Terraria` bleibt unverändert und zusätzlich gebunden; gestartet wird das geprüfte
native `Terraria.bin.osx`. Keine stillen Hashupdates oder Freigaben weiterer Builds.

Mono-Spielzugriffe benötigen den tatsächlich beobachteten originalen Update-Rückruf,
GC-Handles und typisierte Metadaten. Enum-Untertypen und FNA-TimeSpan prüfen.
Terrarias verzögerte App-Registrierung und getrennte SDL-/Systemcursor sind unter
`docs/OVERLAY_INPUT.md` beschrieben; UI-Auswahl darf keinen zweiten Start erzeugen.

## Turok und Turok 2: Intel-Originale unter Rosetta

Der Nutzer hat ausschließlich Turok Steam-Build **18198095** (x86_64-UUID
`73B01170-3775-359F-B17C-867D13F2FB26`) und Turok 2 Steam-Build **20961743**
(x86_64-UUID `AB442E80-6C9C-3FB0-9653-B349C088C250`) ausdrücklich für
`sha256-original` freigegeben. Jeweils alle fünf im Profil genannten Originaldateien
lückenlos prüfen; keine stillen Hashupdates oder Freigaben weiterer Builds.
Die Originalprogramme sind unsigniert und bleiben unverändert.

Der Launcher bleibt arm64 und benötigt weiterhin macOS 27+. Nur ausdrücklich mit
`architecture: "x86_64"` gebundene Intelprofile verwenden eine entsprechend gebaute
Trainerbibliothek unter Rosetta. Ohne Architekturangabe gilt weiterhin arm64;
keine automatische Architekturauswahl oder Übernahme fremder UUIDs. Synthetische
SDL-Hilfen unter `Tests/Kex` dürfen niemals Produktquellen werden.

## inZOI: eng begrenzte Originalfreigabe

Nach fehlerfreier Steam-Dateiprüfung hat der Nutzer ausschließlich Steam-Build
**26264076**, Bundle-Version **5.4.95 (0.0.46)**, arm64-UUID
`B1AA1CC2-C72B-3D8A-AC90-1E8C9155E519` für `sha256-original` freigegeben.
Hauptprogramm, Info.plist, Steam- und Lua-Bibliothek müssen vollständig den
78 Prüfabschnitten des Profils entsprechen. Keine stillen Hashupdates,
Signaturänderungen oder Freigaben weiterer Builds.

inZOI verwendet getrennte B1-/B2-Lua-VMs auf ihren jeweiligen Originalthreads.
Die originale `LuaPrint`-Diagnose hat einen Stackschutz-Abbruch verursacht;
eigene Runtime-Skripte dürfen diesen Ausgabepfad nicht nutzen. Native
Strukturpuffer über `GetRef` statt Strukturkopien verändern und originale
Missionsdefinitionen auf B1 laden. Einzelheiten: `Modules/inzoi/AGENTS.md`.

## DREDGE GOG: eng begrenzte Originalfreigabe

Nach fehlerfreier GOG-Dateiprüfung hat der Nutzer ausschließlich GOG-Build
**59048070897032907**, Version **1.5.3**, Produkt **1744110647**, x86_64-UUID
`E18E02EE-BE72-3DC3-A3AD-C6B11B6CF6A2` für `sha256-original` freigegeben.
Die 18 im GOG-Profil erfassten Originaldateien müssen vollständig ihren
25 lückenlosen SHA-256-Abschnitten entsprechen. Keine stillen Hashupdates,
Signaturänderungen oder Freigaben weiterer Builds. Der GOG-Marker
`user-confirmed-gog-original` gilt ausschließlich für Store `GOG`.

DREDGE liefert ein gemeinsames Universal-Modul für Epic arm64 und GOG x86_64.
`Build.json` darf dafür explizit `architectures: ["arm64", "x86_64"]` statt des
bisherigen einzelnen `architecture` verwenden. Alle Profilarchitekturen müssen
exakt den versiegelten Mach-O-Slices entsprechen; jede Slice bleibt macOS 27+.
Prüfungen pro CPU und übereinstimmende Kataloge sind Pflicht. Solche Pakete benötigen
mindestens TrainerDock 1.2.6; der Launcher selbst bleibt arm64.
