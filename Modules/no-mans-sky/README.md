# No Man’s Sky · vollständiger TrainerDock-Trainer

Eigenständiges natives Modul aus dem vom Nutzer bereitgestellten NoMansSkyTrainer.
Enthält den ursprünglichen Katalog mit 30 Funktionen, native Spielanbindung,
Frame-Zustellung, TrainerDock-Steuerprotokoll und HiDPI-Overlay im isolierten Panel.

## Buildbindung

Steam Build-ID 26386568, Bundle 4.70, arm64-UUID
`1FABCC98-D6B6-3905-BF1B-823BD5033DA9`. Die Originalsignatur ist ungültig; der Nutzer
hat nach positiver Steam-Dateiprüfung ausschließlich diesen Build für vollständige
SHA-256-Prüfungen von Hauptdatei und Info.plist freigegeben. Keine Originaldatei wird
verändert. Andere Store- oder Buildvarianten werden nicht freigegeben.

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

## Prüfung

Die native Zustellung über `MetalKitApplication -update` und die Metadatenbindung
wurden im aktuellen Originalprozess bestätigt. In einem gebündelten Test wurden
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
