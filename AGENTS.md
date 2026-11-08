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
- Code, Builds, App und Audit getrennt halten. Der stabile Buildordner ist
  `~/Library/Developer/TrainerDock`, außerhalb dieses Repositories. Genau eine aktuelle
  geprüfte `TrainerDock.app`; kurzlebige Austauschdaten werden automatisch entfernt.
  Keine Apps, Binaries, Logs, Caches oder Auditberichte im Code ablegen.
- Ein Audit wird nur bei konkretem Bedarf separat erstellt und bleibt unter
  1.000.000.000 Byte. Ungeprüfte Behauptungen sind keine Ergebnisse.

## Architektur

- `TrainerDock.xcodeproj`: echtes natives Xcode-Projekt. Scheme `TrainerDock` baut und prüft alle
  Produkte; `TrainerDock-Launcher` nur den Launcher, `Trainer-<id>` ein Trainermodul.
  Mindestversion für App und Trainer: macOS 27.0, Architektur arm64.
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

Das Hostprogramm lädt ausschließlich geprüfte Modulmetadaten. Vollständige Trainermodule liegen in der App unter `Contents/Resources/Modules`;
für ältere Pakete wird daneben `Modules` weiterhin gelesen. Zusätzliche liegen unter
`~/Library/Application Support/TrainerDock/Modules`. Der Launcher enthält keine Spiellogik.
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
ohne den Launcher neu zu kompilieren. Danach „Trainer & Spiele neu laden“.

GitHub Actions baut über `.github/workflows/build-release.yml` auf `xcode-27` alle
freigegebenen Trainer und den Launcher. Push/PR liefern geprüfte Artefakte; `vX.Y.Z`-
Tags veröffentlichen Releases erst nach erfolgreichem Build. `script/release.py`
verpackt ausschließlich die App, alle echten Module und Lizenz-/Versionsangaben.
Kein Spielstart und keine Veröffentlichung von Spieldateien gehören zum CI-Build.
Duckov und Vampire Survivors beziehen nur eigene kompilierte C#-Bausteine aus dem
vom Nutzer ausdrücklich genehmigten Entwickler-Release `managed-inputs-v1`.
`Config/ManagedImages.json` bindet deren Bytes, Quellen und Originalprofile;
bei Änderungen lokal neu kompilieren und die Bausteine bewusst aktualisieren.
Kein stiller Hashwechsel und keine Ersatz- oder Testassembly. Details:
`docs/RELEASING.md`. Ad-hoc-Signierung ist keine Notarisierung.

## Bei neuen Modulen

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
umrechnen und den Fokus beim Spiel belassen. DI2 besitzt dafür einen Regressionstest.

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
vor dem Entpacken und ersetzen App samt eingebetteten Trainermodulen gemeinsam.
Keine Downgrades, fremden Downloadquellen oder unvollständigen Pakete akzeptieren.
Das native ZIP-Entpacken erlaubt keine Pfadausbrüche, Links oder Spezialdateien.
Vor Installation laufende Spiele abwarten und im Helfer erneut prüfen; Spiele
niemals für Updates schließen. Bei fehlgeschlagenem App-Start den atomaren Tausch
zurücknehmen. Benutzermodule und Einstellungen bleiben außerhalb der App.
Die vorhandene technische Ad-hoc-Codeversiegelung der arm64-Produkte bleibt bestehen;
macOS-Schutzmechanismen nicht verändern. Keine privaten Schlüssel verwenden.

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
