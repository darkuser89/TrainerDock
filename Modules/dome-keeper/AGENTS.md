# Dome Keeper – echtes TrainerDock-Trainermodul

Die übergeordnete AGENTS.md und docs/MODULES.md gelten. Dieses Modul enthält die
vollständige native Godot-Anbindung und das eigene Ingame-Overlay. Keine Demo-
Adapter oder Test-Fixtures ins Produkt aufnehmen.

- Unterstützt ist ausschließlich die in Module.json erfasste Steam-Installation
  5.0.8.14 / Build 25038893 mit der geprüften arm64-UUID und PCK-Verzeichnisidentität.
  Weitere UUIDs oder PCK-Builds benötigen eigene Belege.
- GodotABI.mm bindet die originale Godot-C-Schnittstelle. GodotBindings.h enthält
  ausschließlich an dieser Installation bestätigte Registrierungsadressen und
  Byteprüfungen. Kein Game-Code, keine Vtable und keine Schutzprüfung wird gepatcht.
- Gameplay läuft über Callable.call_deferred in Godots echter MessageQueue.
  Niemals eine Haupt-/Hintergrundqueue als Ersatz-GameThread ausgeben.
- DomeScript.hpp ist eigener, nur im Prozess erzeugter Trainercode. Originalskripte,
  Packs, Saves und ausführbare Dateien bleiben unverändert. Keine Save-Werkzeuge
  oder Freischaltungen hinzufügen.
- Tatsächliche lokale Besitzer prüfen; Netzwerkmodus ist keine Aktivierungssperre.
  Eigentümer enthalten Szene, Karte,
  Keeper, Kuppel und Ladezähler. Alte Werte nie in einen neuen Lauf zurückschreiben.
- Dauereffekte bei Pause, Szenen- und Besitzerwechsel lösen. Nur eigene, noch
  zuordenbare Werte zurücknehmen; fremde Änderungen schützen. Rücklesen entscheidet
  über „Aktiv“. Eisen/Wasser/Kobalt bleiben explizite Einmalaktionen.
- Builds unter ~/Library/Developer/TrainerDock. Synthetische Tests starten keine Spiele.
  Weitere Ingame-Tests brauchen einen entsprechenden aktuellen Nutzerauftrag.
