# No Man’s Sky · vollständiger TrainerDock-Trainer

Eigenständiges natives Modul aus dem vom Nutzer bereitgestellten NoMansSkyTrainer.
Enthält den ursprünglichen Katalog mit 30 Funktionen, native Spielanbindung,
Frame-Zustellung, TrainerDock-Steuerprotokoll und HiDPI-Overlay im isolierten Panel.

## Buildbindung

| Steam-Build | Bundle | arm64-UUID | Profil |
| --- | --- | --- | --- |
| 26386568 | 4.70 | `1FABCC98-D6B6-3905-BF1B-823BD5033DA9` | `steam-arm64` |
| 26540391 | 4.70 | `90ACDF11-4B80-34A5-B802-4F09782742CF` | `steam-arm64-26540391` |

Der Nutzer hat nach jeweils positiver Steam-Dateiprüfung genau diese Originale
für vollständige SHA-256-Prüfungen von Hauptdatei und Info.plist freigegeben.
Das neue Profil bindet beide Dateien lückenlos in 28 Abschnitten. Die Spielsignaturen
bleiben unverändert. Andere Store- oder Buildvarianten werden nicht freigegeben.
`Sources/NMSBuilds.h` hält die 23 unabhängig aufgelösten Einstiege, Eingabe-Globals
und VTable-Adressen beider Builds getrennt; unbekannte UUIDs oder Bindungen liefern
keine Adresse. Das ursprüngliche Profil und seine Prüfsummen bleiben erhalten.

## Laufzeitvertrag

Nur der tatsächliche MetalKitApplication-Update-Rückruf darf Gameplayzustände
lesen oder ändern. APPVIEW und aktueller Save-UID
begrenzen den Kontext. Netzwerkstatus blockiert keine Funktionen oder Auswahl.
Einmalige Währungsgaben werden nie automatisch wiederholt. Bereits gewährte
Währung, Ladung oder Gegenstandsmengen werden beim Ausschalten nicht zurückgedreht.
Globale Schalter und Faktoren werden nur bei unverändertem Eigenwert restauriert.

`OverlayCursor` zeichnet einen Vektorpfeil direkt im eigenen Panel; er benötigt
kein möglicherweise leeres System-Cursorbild. Die native Mausfreigabe verwendet
die echten ShowMouse-/UnlockMouse-APIs und die zur Laufzeit ermittelten
Capture-Ivars der AppKit-Eingabeansicht. Der Cursor ist an die sichtbare
Overlayanforderung gebunden und flackert nicht mit einzelnen Capture-Rückmeldungen. Er folgt der
Bildschirmposition, fängt keine Klicks ab und verschwindet beim Schließen oder
Fokusverlust. Keine globalen Cursor-hide/unhide-Zähler werden durch den Overlaycursor verändert.

## Prüfung: Steam-Build 26386568

Die native Zustellung über `MetalKitApplication -update` und die Metadatenbindung
wurden damals im freigegebenen Originalprozess bestätigt. In einem gebündelten Test wurden
elf rücknehmbare native Schalter/Faktoren gesetzt und zurückgelesen: Gesundheit,
Ausdauer, Lebenserhaltung, Sprintfaktor, Gefahrenschutz, Sprachdarstellung,
Herstellungsfreigabe, Schaden, Schiffsüberhitzung, Spielgeschwindigkeit und
Atlas-Pass-Anforderungen. Die Rücknahme wurde für diese Schalter nativ bestätigt.
Der TrainerDock-Steuerkanal meldete einen gültigen Kontext mit 30 Funktionen; das Overlay
wurde im laufenden Spiel dargestellt. Naniten +100 wurde zusätzlich mit nativer
Rücklesebestätigung 100 → 200 beobachtet.

Das ist ein Nachweis der nativen Werteanbindung, kein vollständiger Combat-/Quest-
oder Ausrüstungstest. Weitere Währungsgaben, Inventarauffüllung und alle Ausrüstungsfälle
wurden beim kurzen Update-Test nicht erneut ausgelöst; ihre nativen Funktionen
und die verschobenen Einsprungpunkte wurden am neuen Originalbuild abgeglichen.
Die Cursor-/Capture-Korrektur wurde anschließend im geladenen Spiel vom Nutzer
bestätigt: Mausbedienung und Cheats funktionieren. Es wurden keine weiteren
Spielstarts oder Funktionsprüfungen nach dieser Bestätigung durchgeführt.

Synthetische Tests prüfen Speicher-Rücklesen, Baselines, fremde Änderungen,
GameThread-Grenzen, Einmalaktionen und Netzwerk-unabhängige Bedienung.

## Updateprüfung: Steam-Build 26540391

In genau einer freigegebenen Spielinstanz mit vorhandenem Spielstand wurden der
originale Update-Rückruf, gültiger APPVIEW-/Save-UID-Kontext und die Metadatenbindung
bestätigt. Dieselben elf rücknehmbaren Schalter/Faktoren wurden nativ gesetzt und
zurückgelesen. Die eigenen skalaren Baselines wurden bytegenau nach dem Ausschalten
verglichen; Atlas-Kosten wurden über ihren nativen Rücknahmepfad bestätigt.
Der Steuerkanal meldete alle 30 Funktionen. Schalter und Glasregler (50 → 81 → 50 %)
wurden mit echten UI-Eingaben bedient; ein sichtbarer Vektormauszeiger wurde beobachtet.
Alle Testschalter waren vor dem vom Nutzer genehmigten regulären Beenden aus.

Währungen und Inventargegenstände wurden bei diesem Update-Test nicht vergeben.
Sämtliche 23 gebundenen Adressen wurden unabhängig am neuen Original aufgelöst;
Spieler-, Inventar-, Scanner-, Schwierigkeits- und Eingabelayouts wurden anhand
der originalen Aufrufer/Konstruktoren abgeglichen. Das ersetzt keinen erneuten
vollständigen Kampf-, Quest- oder Ausrüstungstest und keinen FPS-Nachweis.
Der alte Build wurde nicht erneut gestartet.

Der private Builder `Tests/NoMansSky/BuildCandidate.py` prüft vor einem Spielstart
Originalidentität, sämtliche Symboladressen, Buildisolation, Speicherleases,
Bridge, 1×/2×-Overlay und 40.000 Leerlauf-/Pollframes. Er startet kein Spiel.
Der Diagnosehelfer verwendet den tatsächlich laufenden Runtime-Adapter statt eine
zweite Instanz anzulegen; Aufträge sind an Sitzung, Prozess, Anfrage und Frist gebunden.
Diese Prüfer sind keine Produktquellen und werden nicht ausgeliefert.
