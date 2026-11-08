# Overlay-Maus: Erkenntnisse und Prüfablauf

Diese Anleitung vor der ersten Ingame-Prüfung eines neuen Trainers lesen.
Grundlage sind die bestätigten Korrekturen in No Man’s Sky und die isolierte
Overlay-Anbindung von Dead Island 2. Die Muster sind übertragbar; Spieladressen,
Vtables, Objektpfade und Funktionssignaturen benötigen eigene Buildnachweise.

## Fehler unterscheiden

| Beobachtung | Gezielt prüfen |
|---|---|
| Klicks funktionieren, Zeiger unsichtbar | Tatsächlich gezeichnete Cursorpixel, Bildgröße, Hotspot und Sichtbarkeit des eigenen Panels |
| Maus im Menü frei, im laufenden Spiel gebunden | Engine-Eingabemanager, Fenster-Capture und rohe Eingabeansicht; erneute Bindung während des Updates |
| Zeiger/Overlay blinkt beim Überfahren | Verzögerte Statusmeldungen als Sichtbarkeitsschalter, Fokuswechsel und implizite Layeranimationen |
| Klick trifft eine andere Zeile | Bildschirm-, Fenster-, View- und Zoomkoordinaten einschließlich Flipped-Views getrennt nachvollziehen |

Ein sichtbarer Zeiger beweist keine freie Maus. Eine erfolgreiche Capture-Flag-
Änderung beweist weder freie Bewegung noch richtige Klickzuordnung. Diese drei
Eigenschaften getrennt prüfen; Erfolg nur für die tatsächlich belegte Eigenschaft
melden.

## Native Anbindung und Darstellung

- Objective-C-Ivars über `class_getInstanceVariable` und `ivar_getOffset` zur
  Laufzeit auflösen. Typ, Klassengröße und ursprüngliche Methode prüfen. Ein
  statischer Offline-Offset kann sich durch AppKit-Superklassen verschieben.
  Bei No Man’s Sky war der feste Wert 44 für `isMouseCaptured` falsch.
- Den nativen Eingabepfad vollständig untersuchen. No Man’s Sky benötigt den
  ShowMouse-/UnlockMouse-Zustand des Engine-Eingabemanagers sowie die Freigabe
  von InputSystem, Fenster-Capture und roher Eingabeansicht. Nur das untere
  Capture-Flag zu ändern führte zur erneuten Bindung in folgenden Bildrunden.
- Wenn die Engine ihre Eingabeabsicht pro Frame erneuert, die eigene UI-Übernahme
  am belegten Engine-Rückruf erhalten. Bei No Man’s Sky erfolgt dies vor und nach
  dem ursprünglichen Update. Für andere Engines die passende Stelle erst belegen.
  Engine-Aufrufe gehören auf den echten GameThread, AppKit-Arbeit auf den Hauptthread.
- Baselines einmal bei der Übernahme erfassen und an den tatsächlichen Besitzer
  binden. Neu geöffnete Spielmenüs respektieren. Beim Schließen eigene Zustände
  zurückgeben; beim Fokusverlust keine physische Mausbindung im Hintergrund
  erzwingen. Keine globalen Hide-/Unhide-Zähler durch wiederholte Aufrufe ausgleichen.
- Glas und Auto Layout im isolierten `MHTOverlayHost` halten. Keine Trainer-Views
  oder Constraints ins Enginefenster einbauen. `MHTOverlayMouseEvent` für die
  Fensterumrechnung nutzen; Tastaturfokus beim Spiel belassen.
- Die angeforderte Overlay-/Cursor-Sichtbarkeit an Bedienwunsch und App-Fokus
  binden. Einzelne verspätete Capture-Rückmeldungen dürfen sie nicht fortlaufend
  ein-/ausschalten. Den tatsächlichen Freigabestatus separat und ehrlich anzeigen.
- `NSCursor.arrowCursor.image` kann leer sein. Größe, Zeichenergebnis und Alpha
  prüfen; gleiche Repräsentationszahlen können auch zweimal null bedeuten.
  Bei Bedarf einen kontrastreichen Vektorpfeil im eigenen Panel zeichnen. Er darf
  keine Klicks abfangen und muss bei Schließen/Fokusverlust verschwinden.
- In Punkten layouten, Hotspot und View-Flipping berücksichtigen. AppKit verwaltet
  die Backing-Auflösung. Cursorbewegungen ohne implizite Layeranimationen darstellen
  und unveränderte Frames nicht fortlaufend neu setzen.

## Vorbereitung und gebündelter Test

1. Vor dem ersten Spielstart Buildidentität, native APIs, Zustellthread und
   Eingabebesitzer prüfen. Bereits vorhandene Engine-Anbindungen und Tests gezielt
   wiederverwenden. Keine ungeprüften Signaturen oder Offsets übertragen.
2. Synthetisch prüfen: Laufzeit-Ivar-Auflösung mit einer echten AppKit-Superklasse,
   fehlende/falsch typisierte Felder, Koordinaten und Hotspot, Klickdurchlässigkeit
   sowie sichtbare Cursorpixel auf zuvor geleerten 1×/2×-Zeichenflächen. Ein leerer
   Cursor darf den Test nicht bestehen. Relevante Fokus-/Rückgabezustände abdecken.
3. Vorab eine kurze Diagnose und Testliste vorbereiten: geladene UUID, tatsächlicher
   Rückruf, Kontext/Besitzer, relevante Capture-/Show-/Lock-Felder samt Rücklesen,
   Overlaywunsch und App-Fokus. Entwicklungshilfen ausschließlich unter `Tests/`
   halten, sitzungsgebunden verwenden und aus dem Produkt ausschließen.
4. Im freigegebenen Lauf gemeinsam prüfen: Menü und echtes Gameplay, Öffnen,
   sichtbarer Zeiger, freie Bewegung, richtige Klickzeile, Bewegung über Panelgrenzen,
   Schließen und Rückkehr zur Spielsteuerung. Reversible Trainerfunktionen mit
   Rücklesen/Rücknahme im selben Lauf bündeln; Einmalaktionen gezielt und getrennt
   behandeln. Eine wartende Menüansicht ersetzt keinen Gameplay-Nachweis.
5. Bei einem Fehler zuerst die betroffenen Ebenen anhand der Diagnose eingrenzen
   und zusammengehörige Korrekturen gemeinsam vorbereiten. Einen neuen Kandidaten
   vollständig bauen und synthetisch prüfen, bevor ein weiterer Neustart nötig wird.
   Sobald die erforderliche Wirkung bestätigt ist, die Ingame-Prüfung beenden.

Ziel ist ein gut vorbereiteter Lauf mit mehreren Prüfungen, keine feste Zusage
über eine maximale Startzahl. Vorhandene Freigaben nutzen; der Ablauf erteilt
keine zusätzlichen Start-/Beendenrechte. Eine laufende Instanz anhand Bundle,
Executable-Pfad und PID zuordnen und Doppelstarts verhindern. Bei notwendigem
Ersatz einen kurzlebigen Austausch-Kandidaten außerhalb des Codes vorbereiten;
geladene Testbibliotheken nicht überschreiben. Erst nach dem regulären Ende
einsetzen. Anschließend überholte eigene Testdateien entfernen.

## Bestehende Referenzen

- [NMSAdapter.m](../Modules/no-mans-sky/Sources/NMSAdapter.m): native Eingabeabsicht,
  Capture-Ebenen, Laufzeit-Ivars und Rückgabe der eigenen Übernahme.
- [OverlayCursor.m](../Modules/no-mans-sky/Sources/OverlayCursor.m): Vektorpfeil,
  Hotspot, HiDPI und klickdurchlässige Darstellung im separaten Panel.
- [NativeContractTests.m](../Tests/NoMansSky/NativeContractTests.m): synthetische
  Ivar- und echte Cursorpixel-Prüfungen; kein Ingame-Ersatz.
- [DeadIsland2OverlayHostTests.m](../Tests/DeadIsland2OverlayHostTests.m): isolierter
  Host und Ereigniszustellung.

Die aktuelle NMS-Mauskorrektur wurde vom Nutzer im Spiel bestätigt. Daraus folgt
keine Kompatibilitätszusage für andere Engines, Stores oder Spielupdates.

## SDL-/Mono-Start und Fernsteuerung

Bei Terraria registrierte sich ein direkt gestartetes Originalprogramm verzögert
als macOS-App. Ein zu frühes `getApp` startete deshalb eine zweite Instanz.
Vor der UI-Auswahl den bestehenden Executable-Pfad und PID sowie die native
Rückmeldung prüfen und auf die tatsächliche App-Registrierung warten. Kein
UI-Werkzeug als Ersatzstart einsetzen. Der Host prüft auch unregistrierte native
Prozesse über `MTExecutableIsRunning`.

Terrarias SDL-Softwarecursor blieb bei synthetischen CUA-Klicks an anderer Stelle
als der macOS-Zeiger. Solche Klicks belegen weder einen Produktfehler noch die
Bedienbarkeit mit echter Maus. Die sichtbare Cursorposition und den ausgelösten
Schalter getrennt rücklesen; nötigenfalls eine kurze gebündelte Nutzerprüfung
anfordern. Das isolierte Panel benötigt außerdem explizit
`mouseInteractionEnabled` passend zum Bedienwunsch und Fokus.
