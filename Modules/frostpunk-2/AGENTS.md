# Frostpunk 2 – native Entwicklung

Die übergeordnete AGENTS.md gilt. Nur echte Originalfunktionen; keine Fixtures im Produkt.
Nur Steam-Build 24037022 mit der in Module.json erfassten UUID, Version und vollständigen
Dateiprüfung ist Gegenstand der Nutzerfreigabe. Keine stillen Hashupdates.

- `Unreal.*` besitzt begrenzte Reflexion und tatsächliche GameThread-Zustellung.
  `NSThread.getGameThread` kann vor Registrierung den MainThread liefern; den echten
  Registrierungsslot prüfen. MH_EXECUTE ermitteln statt Imageindex 0 anzunehmen.
- Für Stadt-, Nation-, Actor- und Komponentenbesitz den gemeinsamen `fp::worldOf`
  verwenden. Bei gestreamten Levels ist der Level-Outer ein eigenes Paket-Worldobjekt;
  maßgeblich ist die originale `Level.OwningWorld` samt Mitgliedschaft in World.Levels.
- ArrayProperty.Inner liegt in diesem Build bei +0x78, nicht beim ArrayFlags-Byte +0x70.
  Typsicherheit, Inner-Besitzer und echte lokale Gemeinschaftsmitgliedschaft erhalten.
- Native Parameter nach tatsächlich geladenen UFunction-Namen, Größen und Flags prüfen.
  Ein UHT-C++-sizeof kann wegen Tailpadding von ParmsSize abweichen.
- Shipping-EnableCheats ist ein No-op. Nur einen realen controllergebundenen Manager
  über Originalallocator und reflektierten Objektsetter verwenden; nie CDO als Receiver.
- Bevölkerung benutzt originale 72-Byte-Parameter inklusive FText-Konstruktor/-Destruktor.
  Signiertes Delta, maximal ±100.000 pro Aufruf, keine automatische Teilfehlerwiederholung.
- Ratspause ist manuell; native Funktion schaltet Sitzungen weiter. Kein periodischer Aufruf.
- Reversible Leases nur bei weiterhin eigenem Schreibwert lösen; fehlgeschlagene Rücknahmen
  retrybar halten, auch während Loading. Fremde Zustände erhalten.
- Diagnosen sind sitzungsgebunden und einzeln zuzustellen. Verbrauchte Request-IDs bis zum
  Sitzungsende sperren; verspätete Aufträge verwerfen. Keine Doppelstarts.
- MHTOverlayHost und gemeinsamen Glasregler erhalten. Mausfreigabe auf tatsächlichem
  GameThread, visuelle AppKit-Bedienung auf MainThread. Nutzer bestätigte Maus und Regler.

Nicht durchgeführte Effekttests ausdrücklich benennen. Entwicklungskennzeichnung und
Profilsperre erst nach belegter Anbindung entfernen. Builds außerhalb des Quellordners.
