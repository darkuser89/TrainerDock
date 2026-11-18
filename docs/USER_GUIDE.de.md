# TrainerDock – Bedienungsanleitung

**Deutsch** · [English](USER_GUIDE.en.md) · [Română](USER_GUIDE.ro.md)

[Zur README und Spieleliste](../README.md)

## 1. Was TrainerDock macht

TrainerDock verwaltet Spiele, deren Installationspfade und separat herunterladbare
Trainer. Die App enthält den Launcher und Katalogmetadaten. Die eigentliche
Trainerbibliothek wird erst beim angeforderten Start in das gewählte Spiel geladen.
Ein heruntergeladener Trainer ist deshalb noch keine laufende Spielinstanz.

Appversion, Trainerversion und Spielbuild sind unabhängig. Ein neuer Trainer kann
in einer kompatiblen bestehenden App erscheinen. Ein neuer Spielbuild benötigt
trotzdem ein ausdrücklich unterstütztes Profil; dieselbe Versionsanzeige oder
derselbe Spielname allein belegt keine Kompatibilität.

## 2. Installieren und einrichten

1. Prüfe die Voraussetzungen: Apple Silicon, macOS 27 oder neuer und ein in der
   [Spieleliste](../README.md) unterstützter Originalbuild. Für gekennzeichnete
   Intel-Spielprofile wird Rosetta benötigt.
2. Lade im [neuesten stabilen GitHub Release](https://github.com/darkuser89/TrainerDock/releases/latest)
   die Datei `TrainerDock-macOS-arm64.zip`, entpacke sie und lege **TrainerDock.app**
   im Programme-Ordner ab. Xcode ist zum Benutzen nicht nötig.
3. Öffne **Trainer laden & verwalten** und bei Bedarf **Nach Trainerupdates suchen**.
   Suche das Spiel und lade die gewünschte angebotene Version herunter. Für diesen
   Schritt wird Internet benötigt; er startet kein Spiel.
4. Öffne **Trainer & Spielpfade** mit **⌘ ,**. Falls ein Spiel nicht erkannt wird,
   wähle dessen tatsächliche `.app` aus. Storeprofile haben getrennte Pfade: Eine
   Steam-Installation ersetzt beispielsweise keinen GOG-Pfad.
5. Wähle in der Bibliothek links das Spiel und rechts das passende Store-/Buildprofil.
   **Alle Trainer** zeigt auch Spiele, die noch nicht eingerichtet sind;
   **Installiert** grenzt auf erkannte Installationen ein.

TrainerDock lädt keine Spiele herunter. Du benötigst deren Originalinstallation.
Die Downloads sind ad-hoc signiert, nicht Developer-ID-signiert oder notarisiert.
Bei einer macOS-Meldung den genauen Wortlaut melden; keine Spielsignaturen oder
Schutzmechanismen verändern.

## 3. Das Spiel mit Trainer starten

Eine schon laufende Spielinstanz zunächst regulär im Spiel beenden. Dann:

- **Steam:** Steam regulär öffnen und das Steam-Profil in TrainerDock wählen.
- **Epic:** Epic Games Launcher vorher regulär beenden. Der Startdienst verwendet
  vorübergehend Epics Startzuordnung und nimmt sie anschließend zurück. Ein offener
  Epic-Client kann diese Zuordnung aus seinem Cache überschreiben.
- **GOG / Mac App Store:** Das passende unterstützte Profil und seine Installation wählen.

Klicke auf **Spielen**. Steht dort **Trainer laden**, fehlt zunächst das Paket;
der Download allein startet das Spiel nicht. Vor dem Start werden Spielidentität
und Trainer frisch geprüft. Bei einem nicht unterstützten Build gibt es keinen
stillen Ersatzstart ohne Trainer. Keine zweite Spielinstanz öffnen, um einen
fehlgeschlagenen Trainerstart zu umgehen.

## 4. Funktionen, Overlay und Transparenz

Die Funktionen stehen rechts in aufklappbaren Gruppen. Schalter sind Dauereffekte;
Wertefelder legen den gewünschten Zahlenwert fest. Bei Einmalaktionen muss die
jeweilige Aktion ausdrücklich ausgelöst werden. Die Beschreibungen nennen nötige
Spielzustände, etwa ein geöffnetes Inventar oder einen geladenen Charakter.

**⌘ ^** öffnet oder schließt den Ingame-Trainer: Befehlstaste plus Zirkumflex,
nicht das Steuerungszeichen „Ctrl“. Weitere Kürzel stehen an den Funktionen.
Oben links erscheint der Spielname. Bei Problemen mit dem Kürzel die Tastaturbelegung
und den Spielfokus prüfen; das Overlay lässt sich auch über den Launcher öffnen,
wenn eine passende laufende Sitzung vorhanden ist.

Ein aktivierter Wunsch ist noch kein bestätigter Effekt. **Aktiv** wird erst nach
Rücklesen aus dem Spiel gemeldet. Nicht verfügbare Funktionen können auf den
passenden Kontext warten; deaktivierte oder WIP-Funktionen sind nicht als fertig zu verstehen.
**Alles aus** beendet eigene Dauereffekte. Bereits ausgelöste Einmaländerungen,
zum Beispiel ausgegebenes Geld oder hinzugefügte Gegenstände, werden nicht zurückgedreht.

Liquid Glass bleibt eingeschaltet. Unten rechts im Ingame-Trainer stellt **Glas**
die Hintergrunddeckkraft ein: **0 % transparent, 50 % natives Glas, 100 % deckend**.
Text und Bedienelemente bleiben sichtbar. Der Wert wird pro Trainer gespeichert;
macOS-Einstellungen wie reduzierte Transparenz behalten Vorrang.

**Auswahl beim Start laden** ist zunächst aus. Eingeschaltet stellt sie gespeicherte
Dauerschalter erst im gültigen Spielkontext wieder her. Einmalaktionen werden nie
beim Start wiederholt. Pfade, Auswahlen und Glaswerte bleiben in den Benutzereinstellungen.

## 5. Die App-Sprache ändern

Öffne **Trainer & Spielpfade → App-Sprache**. Wähle **Deutsch**, **Română**,
**English** oder **Systemsprache**, dann beende und öffne TrainerDock regulär neu.
Die Wahl bleibt gespeichert und verändert nicht die globale macOS-Sprache.

**Systemsprache** verwendet die primäre Sprache: Deutsch, Rumänisch und Englisch
werden erkannt, einschließlich regionaler Varianten. Andere primäre Sprachen
verwenden Englisch, auch wenn Deutsch weiter hinten in der Sprachliste steht.
Diese Einstellung betrifft die Launcher-Oberfläche. Trainerkataloge und
Ingame-Trainer behalten derzeit ihre deutschen Funktionstexte.

## 6. Trainer aktualisieren, wechseln und löschen

Öffne **Trainer laden & verwalten** und klicke auf **Nach Trainerupdates suchen**.
Das aktualisiert den Katalog. Für einen einzelnen Trainer die neuere Version
herunterladen; über **Verwenden** lässt sich eine installierte Version auswählen.
Ein Versionswechsel wird erst nach dem regulären Spielende möglich.

**Alle installierten Trainer aktualisieren** prüft zuerst den Onlinekatalog und
lädt fehlende neueste Pakete der bereits installierten Trainer. Der aktuelle
Suchfilter schränkt diese Aktion nicht ein. Downloads laufen nacheinander mit
Fortschritt; ein einzelner Fehler stoppt die übrigen nicht. Nicht installierte
Trainer werden nicht zusätzlich geladen. Vorhandene Releases werden nicht erneut
heruntergeladen und neuere Versionen nicht heruntergestuft.

Neue Pakete ersetzen die alten nicht. Laufende Spiele behalten ihre genaue
Trainerinstanz. Nach Spielende kann eine frühere installierte Version erneut
ausgewählt werden, sofern ihr Profil zum installierten Spiel passt.

Über **Löschen** entfernst du eine nicht mehr benötigte installierte Version.
Aktive Sitzungen, laufende Spiele und noch verwendete Bibliotheken sind geschützt.
TrainerDock löscht alte Versionen nicht automatisch. Die Aktion entfernt das
Trainerpaket, nicht das Spiel oder dessen Spielstände.

## 7. TrainerDock selbst aktualisieren

Im Menü **TrainerDock → Nach Updates suchen …** manuell prüfen. Automatische
Prüfungen lassen sich dort ein- oder ausschalten. Sie erfolgen beim Start und
danach stündlich, mit höchstens einer erfolgreichen automatischen Abfrage pro Tag.

**Laden und installieren** lädt die neue stabile Appversion. Der Updater prüft
Größe und GitHub-SHA-256, wartet auf laufende Spiele und ersetzt nur die App.
Er beendet keine Spiele. Trainerpakete, Pfade und Einstellungen bleiben außerhalb
des App-Bundles erhalten. Scheitert der Appstart, wird der Austausch zurückgenommen.
Appupdates und Trainerupdates sind getrennte Vorgänge.

## 8. Ablage und GitHub-Builds

Heruntergeladene Pakete liegen versioniert unter:

```text
~/Library/Application Support/TrainerDock/Modules/<id>/<version>/<id>.mhtmodule
```

Alte MHT-Ablagen bleiben lesbar. Trainer über die Verwaltung entfernen oder wechseln;
keine Bibliotheken eines laufenden Spiels von Hand austauschen. TrainerDock bearbeitet
keine Spielstände, um Kompatibilität herzustellen. Änderungen durch Trainerfunktionen
können beim normalen Speichern des Spiels Bestandteil des Spielstands werden.

App und Module bleiben im selben Repository, mit getrennten Builds und Releases.
GitHub vergleicht tatsächliche Produktinhalte mit dem zuletzt bestätigten Katalog.
Appänderungen bauen nur die App; Traineränderungen nur die tatsächlich betroffenen
Module. Geänderte gemeinsame Abhängigkeiten können mehrere Trainer betreffen.
Dokumentation, Tests oder bloße Versionsnummern erzeugen keine Funktionsupdates.
Trainer haben einzelne Buildjobs, höchstens drei gleichzeitig, und eigene
unveränderliche Releases. Erst bestätigte Pakete gelangen in den Downloadkatalog.
Details für Entwickler: [Veröffentlichungsanleitung](RELEASING.md).

## 9. Häufige Probleme

| Problem | Vorgehen |
|---|---|
| Spiel fehlt links | **Alle Trainer** wählen, Katalog prüfen und die richtige `.app` in den Pfadeinstellungen auswählen. Mit **⌘ R** neu einlesen. |
| Spielupdate wird abgelehnt | Passendes Trainerupdate suchen. Ohne geprüftes Profil bleibt der neue Build gesperrt; Store oder Dateiname allein reichen nicht. |
| Download fehlt oder schlägt fehl | Internet prüfen und Katalog erneut laden. Bei zu alter App die erforderliche Appversion installieren. Fehlertext und Trainer-/Profilversion melden. |
| Funktion wartet | Benötigten Spielkontext herstellen und Beschreibung beachten. WIP- oder deaktivierte Funktionen bleiben eingeschränkt. Prodeus ist nur für Einzelspieler vorgesehen. |
| Epic-Start scheitert | Epic vorher regulär beenden, korrektes Epic-Profil und Pfad prüfen; keinen zweiten parallelen Spielstart auslösen. |
| Overlay, Maus oder Vollbildwechsel hängen | Wenn möglich speichern und regulär beenden. Spiel, Store, Build, Trainerversion und genaue Auslösung melden; ein bestätigtes kompatibles Paket verwenden. |

Die aktuelle Spieleliste und bekannte Einschränkungen stehen in der
[deutschen README](../README.md). Synthetische Buildtests belegen keine Ingame-FPS
und keine Kompatibilität mit nicht aufgeführten Builds.
