# Architektur: vollständige Trainermodule, schlanker Launcher

## Aufgabenverteilung

Die App enthält ausschließlich die gemeinsame Oberfläche, Modulverwaltung,
Installationserkennung und den allgemeinen Start-/Nachrichtenvertrag. Keine
Trainerbibliothek, Spieladresse, Engineklasse, Cheatwirkung oder spielabhängige
Übersetzung von Auswahlformaten wird in den Launcher kompiliert.

Ein `.mhtmodule` ist der **vollständige Trainer** für ein Spiel:

```text
Modules/<spiel>.mhtmodule/
  Module.json          # Name, Storeprofile, Funktionen und Wertebereiche
  TrainerConfig.json   # ausschließlich die Profile dieses Moduls
  Trainer.dylib        # Adapter, Spiellogik, GameThread-Bridge und Ingame-Overlay
  LICENSE
```

Die mitgelieferten Module liegen in `TrainerDock.app/Contents/Resources/Modules`.
Ältere Pakete mit dem benachbarten Ordner `Modules` werden weiterhin gelesen. Zusätzliche bzw. ersetzende
Module können unter `~/Library/Application Support/TrainerDock/Modules` liegen. Ein
Benutzermodul mit derselben ID hat Vorrang. „Trainer & Spiele neu laden“ lädt die
Definitionen neu. Dafür muss die App nicht neu kompiliert werden.

Der Launcher liest die Modulmetadaten. Erst ein ausdrücklicher Spielstart lädt die
**im gewählten Modul enthaltene** Trainerbibliothek in den passenden Spielprozess.
Dadurch befinden sich gleichnamige Objective-C-Klassen verschiedener Trainer nicht
im gemeinsamen Launcherprozess. Auch mehrere Resident-Evil-Spiele haben jeweils
ein vollständiges eigenes Modul, keine zentral benötigte Familienruntime.

## Entwicklungsquellen

`Modules/<id>/Sources` enthält den Trainercode. Die Resident-Evil-Module nutzen beim
Bauen gemeinsame Entwicklungsquellen unter `Modules/_Shared/ResidentEvil`; jede
ausgelieferte Moduldatei enthält trotzdem ihre vollständige, eigenständig ladbare
Bibliothek. Es besteht keine Laufzeitabhängigkeit zu `_Shared` oder einem anderen
Modul. Die alten Launcher und Produktdemos wurden nicht übernommen.

`Build.json` gehört nur zum Quellmodul. Es listet Sources, Compileroptionen, nativen
Katalogexport und Tests. `Module.json` ist die Spieldefinition. Der Build erzeugt
den Funktionskatalog aus den echten nativen FeatureInfo-Tabellen; dieselben Tabellen
versorgen das Ingame-Overlay. Der Launcher besitzt keine fest codierte Spieleliste.

## Start und Einstellungen

Die Installationserkennung liest LaunchServices, Applications-Ordner und Steam-
Bibliotheken. Explizit gespeicherte Pfade haben Vorrang. Jeder Profilpfad wird vor
Übernahme und Start auf Bundle-ID, Executable, arm64-Mach-O bzw. exakt geprüfte arm64-Slice, UUID,
Bundleversion und Originalsignatur/Team-ID geprüft. Storeangaben gelten nur für die
hinterlegten Profile, nicht automatisch für andere Stores oder Spielupdates.

Der Launcher zeigt das Fenster vor der Verzeichnissuche. Fehlende Installationen
werden auf einer abbrechbaren Hintergrundwarteschlange gesucht; vorhandene Pfade
werden nicht erneut gesucht. Ergebnisse werden auf dem Hauptthread übernommen,
wobei inzwischen gewählte Pfade Vorrang behalten. Die Build-Prüfung zur Anzeige
läuft ebenfalls im Hintergrund. Abgebrochene Ergebnisse und Ergebnisse einer
anderen Auswahl dürfen weder Status noch Startknopf verändern. Der explizite
Spielstart prüft das Original erneut vollständig; Anzeigeergebnisse ersetzen
keine Startprüfung. Suche mit unveränderter Spielauswahl erhält die vorhandene
Ansicht. Ohne aktive Sitzung gibt es keine periodischen Zeilenaktualisierungen.

Der gemeinsame Startvertrag umfasst `MHT_MODULE`, `MHT_SESSION`, `MHT_TARGET`,
`MHT_CONFIG`, `MHT_PROFILE`, `MHT_OPTIONS` und `MHT_SELECTION`. Das Modul übersetzt
seine privaten Auswahlformate selbst. Zusätzliche Storevariablen stehen im Profil
unter `launchEnvironment`; sie dürfen den gemeinsamen Vertrag nicht überschreiben.
Keine Spielsignaturen, Entitlements oder ausführbaren Dateien werden verändert.
Eine fehlende Trainerverbindung wird sichtbar gemeldet; kein stiller Ersatzstart.

## Livebedienung

`MHTProtocol` überträgt JSON über lokale Distributed Notifications. Nachrichten sind
an Protokollversion, Modul-ID, Sitzungstoken und PID gebunden. Befehle enthalten eine
Request-ID, kurze Frist und die zuletzt bestätigte Kontextgeneration. Wiederholte
oder abgelaufene Nachrichten werden verworfen. Dies ist lokale Sitzungszuordnung,
keine kryptografische Authentifizierung gegen andere Prozesse desselben Benutzers.

Die Modul-Bridge prüft Werte und Besitzerwechsel erneut und liefert Aufträge an den
tatsächlichen GameThread. Setter sind idempotent; Einmalaktionen werden nie erneut
versendet. „Alles aus“ und Overlaybedienung bleiben in Ladepausen möglich. Nur native
Rücklesebestätigung darf „Aktiv“ anzeigen. Netzwerkstatus blockiert keine Funktionen
und löscht keine Aktivierungswünsche. Eigentümer- und Ladeprüfungen bleiben maßgeblich.

Alle 0,5 Sekunden meldet das Modul seinen Zustand. Nach 2,5 Sekunden ohne Rückmeldung
entfernt der Launcher die aktive Kennzeichnung und deaktiviert Livebefehle. Jede
Spielsitzung bleibt unabhängig von der aktuellen Auswahl in der Seitenleiste.

Liquid Glass ist dauerhaft aktiviert und wird vom Modul im eigenen Overlay
umgesetzt: NSGlassEffectView auf dem Mindestziel macOS 27, alternativ Vibrancy und
bei entsprechenden Barrierefreiheitseinstellungen eine deckende Fläche. Der Host
normalisiert auch ältere gespeicherte `liquidGlass: false`-Werte auf `true`.
Sichtbarkeit und Platzierung bleiben unabhängig davon gespeichert.

### Glasdeckkraft im Trainer

Jeder Trainer enthält unten rechts im ausgeklappten Panel einen `MHTGlassSlider`
aus `ModuleSDK/MHTGlassIntensity.*`. `glassIntensity` ist eine endliche Zahl von
0 bis 1: 0 bedeutet vollständig klaren Hintergrund, 0,5 die bisherige native
Glasdarstellung (Standard für alte Einstellungen), 1 einen deckenden Hintergrund.
Die erste Hälfte blendet das native Material ein, die zweite eine deckende Fläche
darüber. Material und Deckfläche sind Geschwister unter dem Vordergrund; dessen
Alpha bleibt 1. Glas wird nicht zusammen mit Texten oder Bedienelementen ausgeblendet.
Reduzierte Transparenz und erhöhter Kontrast erzwingen weiterhin einen deckenden
Hintergrund, ohne den gespeicherten Wunschwert zu überschreiben.

Der Regler nutzt die vorhandene Down-/Drag-/Up-Zustellung, auch außerhalb seines
Rahmens, statt einer blockierenden nativen Tracking-Schleife im Enginefenster.
Wertänderungen fließen durch `optionsChanged` in die normalen Laufzeitoptionen.
Beim Loslassen und bei Accessibility-Schritten publiziert die Bridge den aktuellen
Zustand zusätzlich sofort; der Launcher speichert den Wert mit den übrigen Optionen
pro Modul. Beim nächsten Start wird er über `MHT_OPTIONS` wiederhergestellt.
Programmatische Rückmeldungen lösen keine neuen Wertänderungsbefehle aus.

`Tests/HiDPITests.m` prüft alle Trainer und die Vorlage auf Bereichsgrenzen,
ungültige Werte, Vordergrund-Alpha, Hintergrund-Endpunkte, Fußzeilenposition,
vollständige Mausfolgen, Accessibility, Ein-/Ausklappen und HiDPI. `MHTTests.m`
prüft die dauerhafte Speicherung im Host. Diese Tests sind keine Ingame-Nachweise.

Dead Island 2 und die neutrale Trainervorlage verwenden `MHTOverlayHost`: Ein
transparentes, nicht fokussierendes Child-Panel isoliert die native Glasfläche vom
eigentlichen Enginefenster. Unreal kann dadurch seine framebasierte Fensterabfrage
auf dem GameThread durchführen, ohne den vom Overlay auf dem Hauptthread genutzten
Auto-Layout-Kontext anzufassen. Bei geöffneter Mausbedienung empfängt das Panel eigene
Klicks, ohne den Tastaturfokus vom Spiel zu übernehmen. Ein beim Öffnen registrierter
Monitor und die Panelzustellung leiten sie an die Overlayzeilen weiter. Bei geschlossener
Bedienung wird das Panel wieder mausdurchlässig. Aus dem Spielfenster kommende
Ereignisse werden zusätzlich in Overlaykoordinaten umgerechnet. Das komplette Hosting
bleibt Teil des Moduls.

## Buildablage

Ein stabiler externer Buildordner: `~/Library/Developer/TrainerDock`. Darin genau eine aktuelle
`TrainerDock.app` und ein aktueller `Modules`-Bestand. Das native `TrainerDock.xcodeproj` kompiliert,
linkt und signiert App und Trainer mit macOS 27.0 als Deploymentziel.
`Config/TrainerDock.xcconfig` hält die gemeinsamen Einstellungen; `script/xcode_project.py`
aktualisiert die versionierten Targets und gemeinsamen Schemes aus `Build.json`.
Xcode behält inkrementelle Objekte unter `Xcode/Build/Intermediates.noindex`;
Testprogramme werden nur in kurzlebigen externen Prüfverzeichnissen erzeugt und
nach der Prüfung entfernt. Keine datierten Serien und kein Audit.

Das Scheme `TrainerDock` baut die nativen Produkte und danach die Launcherprüfung. Sein
Run-Schritt startet ausschließlich `TrainerDock.app`. Pro Trainer gibt es ein eigenes
`Trainer-<id>`-Scheme. Katalogexport und synthetische Tests verwenden die tatsächlich
von Xcode erzeugten Objekte, keine zweite Produktkompilierung. Die nativen Trainer
bleiben eigenständige Pakete im externen Buildbaum und werden vollständig in die
App-Ressourcen übernommen; keine Dylib wird in den Launcherprozess geladen.
Bei einem Buildfehler den Build korrigieren, bevor die App benutzt wird.

## Native Oberfläche

Die sichtbare Bezeichnung lautet „Trainer“. Technische Modulpfade, Paketformate
und Protokollschlüssel bleiben stabil. `MHTTrainerSettings` verwaltet das separate
Einstellungsfenster mit fester Kopfzeile, Trainersuche und scrollbaren Spielkarten.
Jeder Store behält seine eigene Pfadaktion; die vorhandene Identitätsprüfung erfolgt
vor dem Speichern. Fenstergröße und Suchtext bleiben beim erneuten Öffnen erhalten.
`MHTMenu` bindet die nativen Menüs und die Kürzel ⌘ , / ⌘ R / ⌘ 1 an den Launcher.

Der Launcher verwendet eine native Split-View mit Toolbar, Spielsuche und einer
Seitenleiste mit Original-App-Icons. `MHTGameIcons` liest diese über NSWorkspace
ausschließlich aus passenden installierten Spiele-Apps; fehlende Installationen
erhalten ein neutrales Systemsymbol. Der Iconcache bleibt im Arbeitsspeicher.

`MHTAppearance` bündelt adaptive AppKit-Farben, Karten und Layouthelfer. Lange Labels
haben eine niedrige horizontale Kompressionspriorität und werden gekürzt, damit
Modultexte niemals die Fenstergröße bestimmen. Die Trainerliste scrollt. Die
Größenregression prüft sämtliche Modulwechsel bei zwei Fensterbreiten und eine
leere Suche mit der echten Oberfläche, ohne Spiele zu starten.

Für reine UI-Arbeit `./script/build_and_run.sh --launcher-only` verwenden. Dieser
Weg baut nur den Launcher und dessen Prüfungen; bestehende vollständige
Trainermodule bleiben unverändert.

## HiDPI

Layout und Mauskoordinaten bleiben in AppKit-Punkten. AppKit verwaltet die
Backing-Layer-Auflösung; `contentsScale` wird nicht auf einen festen Wert gesetzt.
Die Spielicons behalten alle Originalrepräsentationen und erhalten pro Ansicht
ihre Zielgröße in Punkten. Kartenränder sind ein Gerätepixel breit.

Alle Overlayfamilien und die neutrale Vorlage verwenden `ModuleSDK/MHTHiDPI.h`:
Textursprünge und Spaltentrenner werden erst im endgültigen Zeichentransform
ausgerichtet, der Bildschirmdichte und Overlayzoom enthält. Die Panelrahmen sind
am Backing-Pixelraster ausgerichtet. Zoomänderungen zeichnen die eigenen Inhalte
neu; Backing-Wechsel lösen zusätzlich Layout und Neuzeichnung aus. Native
Glass-Flächen behalten ihre systemverwaltete Auflösung.

`Tests/HiDPITests.m` rendert jedes Modul synthetisch bei 1×/2× und 70/90/100/130 %
Zoom. Es prüft Textursprünge, echte einpixelige Trennlinien und Panelgrenzen.
Die Launcherprüfung kontrolliert außerdem die Auswahl ausreichend großer
Iconrepräsentationen. Das ersetzt keinen Ingame- oder Mehrmonitor-Praxistest.


## Godot- und Steam-Bundles

Dome Keeper liegt als Universal-Binary in einem APPL-Bundle ohne `.app`-Suffix vor.
Die allgemeine Erkennung berücksichtigt solche Verzeichnisse und liest ihr echtes
Bundle-Icon. Der Dateidialog akzeptiert Installationsordner; die normale strikte
Identitätsprüfung bleibt erforderlich. `gameVersion` dient nur der Anzeige; `version`
ist weiterhin die für die Bundle-Prüfung verwendete Version.

Der Mach-O-Leser wählt aus 32/64-Bit-Fat-Tabellen genau eine arm64-Slice und verwirft
Überlappungen, doppelte Slices und ungültige Grenzen. Standardprofile behalten die
bisherige Signaturprüfung. Das ausdrückliche Profil `signatureScope: arm64-executable`
prüft nur die tatsächlich gestartete Original-Slice; es benötigt zusätzlich deren
exakten Signatur-Identifier, CDHash und `fileChecks` für die Originalressourcen.
Hier wird das PCK-Inhaltsverzeichnis einschließlich aller eingetragenen Dateihashes
geprüft. Die Spielinstallation, Signaturen und Schutzmechanismen werden nie verändert.

`launchMode: executable` startet ausschließlich das vorher validierte Original-
Executable mit der vollständigen Trainerumgebung. Der Host verfolgt dessen PID und
Laufzeit über NSTask. Dieser deklarative Startweg enthält keine spielabhängige Logik
und wird niemals als stiller Ersatz für einen fehlgeschlagenen Trainerstart verwendet.

## Unity/Mono

Escape from Duckov enthält einen eigenen C#-Trainer, der als Byteabbild in dessen
Trainer.dylib eingebettet wird. Der native Loader bindet ausschließlich exportierte
Funktionen der originalen, bereits geladenen Mono-Laufzeit. Die ursprünglichen
Managed-Assemblies bleiben in der Spielinstallation; Build-Hashes und Runtime-MVIDs
verhindern eine Freigabe unbekannter Varianten.

Bootstrap erfolgt über die tatsächliche UniTask-ContinuationQueue. Ein eigenes
MonoBehaviour ruft anschließend in Unity Update die schmale native Warteschlange
auf. Erst innerhalb dieses Rückrufs sind Gameplay-APIs freigegeben; AppKit-
Wiederholungsversuche führen keine Spielwirkungen aus. Das Overlay bleibt im
isolierten nativen MHTOverlayHost. Der Launcher enthält keine Unity- oder Duckov-
Spielklassen und benötigt für das neue Modul keine spielabhängige Änderung.

## Unity/IL2CPP

Vampire Crawlers bindet originale IL2CPP-Exporte aus der bereits geladenen
GameAssembly; die tatsächlichen Spielklassen liegen in Pancake.dll. Originale
Unity-PlayerLoop-APIs registrieren einen nativen Rückruf und erhalten die bestehende
Hierarchie. Erst dessen beobachtete Ausführung erlaubt Gameplay-Zustellung.
Native Layouts kommen aus der Originalreflexion; Arraykopien verwenden die
GC-Schreibbarriere. Hauptprogramm, GameAssembly und UnityPlayer sind buildgebunden.

Die vollständige Anbindung, Featurelogik, Auswahl und das native Ingame-Overlay
liegen im unabhängigen Trainermodul. Der Launcher kennt keine IL2CPP-Klassen.
Die explizite Originalfreigabe dieses Steam-Builds verwendet vollständige SHA-256-
Dateiprüfung; sie ist kein automatischer Ersatzweg bei Signaturfehlern.
