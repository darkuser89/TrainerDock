# Control Ultimate Edition – natives TrainerDock-Modul

Eigenständiger Trainer für die nativen arm64-Versionen Steam 1.34 (Build 3)
und Mac App Store 1.33.1 (Build 27) / 1.371 (Build 28).
Der Launcher lädt Metadaten; Spielanbindung, GameThread-Zustellung,
Bedienung, Overlay und Glasregler liegen vollständig in diesem Modul.

Das Profil ist ausschließlich an die erfassten UUIDs von Game, coregame,
app, bonsai und rl gebunden. Originalsignatur, Team-ID und Version werden
geprüft. Andere Stores und Spielupdates benötigen ein eigenes geprüftes Profil.

## Mac App Store

### Update auf 1.371 (Build 28)

Das aktuelle MAS-Profil verwendet den neuen Originalprogramm-Namen `Game` und
fünf neue UUIDs. Die gültige Apple-Originalsignatur bleibt unverändert. Für diesen
Build gibt es eine eigene Adresstabelle; die bisherigen Steam- und MAS-Bindungen
bleiben erhalten. Das bisherige MAS-Profil ist separat auswählbar.

`Tests/Control/UpdateCompatibility.py` prüfte an den Originalen 288 unveränderte
Komponentenmethoden sowie RTTI, Update-Slot, Wert-Pins mit Handle bei +8,
Gesundheitssetter, Datenbankzugriff und Core-APIs. Die Relokationsnormalisierung
wurde dabei auf unmittelbar belegte ADRP-Paare begrenzt.

In genau einem lokalen Lauf wurden native Unverwundbarkeits-, Energie- und
Munitionszustände, Materialien 3/1 → 999 samt Nachfüllen und Rücknahme,
Bewegungsgrenzen ×2, Simulationsfaktor 0,5, Rezeptkosten 25000/3 → 0/0 und
Quellenenergiegewinn 10 → 20 bestätigt. Geld und Fähigkeitspunkte wurden gesetzt
und anschließend auf 1650/0 zurückgestellt. Alle eigenen Dauereffekte wurden
vor dem regulären Testende zurückgenommen.

Overlay-Anzeige, sichtbarer Zeiger, native Mausfreigabe und F1 funktionierten.
Fernsteuerungsklicks auf Schalter und Glasregler lieferten keinen belastbaren
Nachweis; die physische Mausbedienung ist mit diesem Build noch nicht neu bestätigt.
Ein echter Schildtreffer, Waffentreffervergleich und kompletter Herstellungsvorgang
wurden nicht wiederholt. Der alte native Rezept-Abfrageaufruf wird im Testprüfer
für 1.371 ausdrücklich nicht aufgerufen; hier wurden echte Rezeptwerte zurückgelesen.

### Bisheriger MAS-Build 1.33.1

Die MAS-Version hat ein eigenes Profil und eine eigene, über alle fünf UUIDs
gebundene Adresstabelle. Steam- und MAS-Adressen werden niemals gemischt.
Originalsignatur, Team-ID, Version und Hauptdatei-UUID werden weiterhin geprüft;
keine Signaturausnahme und keine Änderungen an Spieldateien sind erforderlich.

Im geladenen MAS-Spiel wurden Unverwundbarkeit, Energie- und Munitionsflag,
Geld/Fähigkeitspunkte setzen, private Bewegungsgrenzen, Simulationszeitfaktor
und ihre Rücknahme geprüft. Der native Rezepttest wechselte von nicht erlaubt
zu erlaubt und nach Rücknahme wieder zurück. Zwei echte eigene Materialstapel
wechselten von 3/1 auf 999, ein Testverbrauch von 999 auf 998 wurde aufgefüllt,
beim Ausschalten kamen 3/1 zurück. Ein Quellenenergiegewinn von 10 wurde mit
Faktor 2 zu 20. Nach nativer Schadensannahme an einem echten feindlichen
Health-Modell setzte One-Hit-Kill dessen Restgesundheit auf null.
Ein aktiver gegnerischer Schild stand für den MAS-Wirkungsvergleich bisher
nicht zur Verfügung; ein kompletter Herstellungsablauf wurde nicht ausgeführt.
Diese Grenzen ersetzen keine bestätigten Wirkungen durch Erfolgsanzeigen.

Overlay-Bedienung per Maus und der gemeinsame Glasregler wurden in MAS geprüft.
Der ursprüngliche Spielstand wurde regulär im Spiel geladen; Saves wurden
nicht direkt bearbeitet. Der normale Spielfortschritt des Nutzers bleibt erhalten.

`Tests/Control/BuildStoreTest.py` baut den sitzungsgebundenen `StoreHarness`
und `MASProbe` außerhalb des Codes, startet aber kein Spiel. Der Linker erlaubt
nur die exakt benannten C-Exports des tatsächlichen Produktruntimes. Falsche
C++-Bindungen werden dadurch vor dem Spielstart abgewiesen. Die temporären
Konfigurations-, Befehls- und Zustandsdateien gehören ausschließlich ins
Testverzeichnis unter `/private/tmp` und sind nach dem regulären Testende zu
entfernen. Diese Werkzeuge werden niemals ins Produktmodul gelinkt.

## Funktionen

Gesundheit und Fähigkeitsenergie, unbegrenzte Waffenenergie ohne Nachladen,
Quellenenergie und Fähigkeitspunkte setzen, Bewegungsgeschwindigkeit,
Zeitlupe, One-Hit-Kill nach angenommenem feindlichem Gesundheitsschaden,
Schildzerstörung nach angenommenem feindlichem Schildschaden, vorhandene eigene
Herstellungsmaterialien bei mindestens 999, kostenfreie geladene Herstellungsrezepte
und Multiplikator für neu erhaltene Quellenenergie.

`Infinite Materials` erfasst ausschließlich vorhandene eigene Materialstapel,
deren Inhalt als Rezeptzutat identifiziert ist. Drei reale Stapel mit 4/1/1
wurden auf dem nativen Spielthread auf 999 aufgefüllt, ein testweise auf 998
verringerter Stapel wieder auf 999 gesetzt und beim Ausschalten auf 4/1/1
zurückgesetzt. Die übrigen Inventareinträge blieben unverändert. Ein kompletter
Herstellungs-/Verbrauchsablauf wurde dabei nicht ausgeführt.
Die Schadensanbindungen verwenden die
native Feindlichkeitsmatrix und originale Health-Modelle. Sie reagieren auf
angenommenen Schaden an feindlichen Körpern bzw. Schilden unabhängig von der
Schadensquelle; Freunde und ungetroffene Gegner bleiben unverändert.
Die Anbindung wurde an realen feindlichen Health-Modellen mit nativen
Schadensänderungen geprüft; ein Vergleich mit echten Waffentreffern fehlt noch.
Das Assistenz-Ausgabeflag ist ungeeignet, weil die Engine es neu berechnet.
Storyfreischaltungen werden durch kostenfreie Rezepte nicht aufgehoben.
Quellenenergie und Fähigkeitspunkte sind einmalige Aktionen; der Multiplikator
wartet auf einen neuen Gewinn und vervielfacht keine ausdrücklich gesetzten Werte.

## Native Grenzen

`ControlEngine.mm` identifiziert die fünf Originalimages und stellt Aufträge
über den echten `GameServer::update(float)` auf dem Spielthread zu. Die Zeitlupe
skaliert dessen Simulationsschritt. Nur die Instanz-VTable im beschreibbaren Heap
wird ersetzt; ausführbare Seiten und Spieldateien bleiben unverändert.

`NativeAdapter.mm` prüft lokalen Besitzer, GlobalID und genaue Komponententypen.
Eigene Werte werden nur bei unverändertem Besitzer und passender Rücklesung
zurückgenommen. Alte Befehle werden beim Besitzerwechsel verworfen.
`ControlMovement.mm` bindet eine private Konfiguration an den lokalen Spieler;
gemeinsame NPC-Konfigurationen bleiben unverändert. Wiederholtes Ein-/Ausschalten
verwendet denselben Speicher. Höchstens 32 verschiedene Besitzerzustände werden
bis zum Prozessende gehalten; danach bleibt diese Funktion inaktiv.

`ControlInput.mm` hält Engine-Sichtbarkeit und Mausmodus bei geöffnetem Overlay
und gibt den zuletzt vom Spiel angeforderten Zustand beim Schließen zurück.
Mausprüfung über Hardwarezustand und Ereigniszustellung getrennt behandeln:
Controls AppKit-Maustastenpfad liest `NSEvent.pressedMouseButtons`.
Ein nur zugestelltes Fernsteuerungsereignis kann deshalb im Spiel ohne Wirkung
bleiben, obwohl das Overlay seinen Klick korrekt verarbeitet.

## Bauen und prüfen

```sh
python3 -B script/build.py --module control
```

Ausgabe: `~/Library/Developer/TrainerDock/Modules/control.mhtmodule`.
Im Launcher anschließend „Trainer & Spiele neu laden“.
Mindestziel ist macOS 27.0; der ursprüngliche Spielprozess bleibt arm64.

`Tests/Control/NativeContractTests.mm` prüft falsche Prozessidentitäten,
Speicherschutz, Kontextwechsel, Stop-Priorität und Einmalaktionen.
Die gemeinsamen HiDPI-Tests prüfen Overlay und Glasregler.
Live-Diagnosen unter `Tests/Control/` sind ausschließlich Entwicklungswerkzeuge
und werden niemals in das Produktmodul gelinkt. Ein erfolgreicher Build ist
kein Nachweis für ungeprüfte Spielsituationen.
