# Terraria – Modulregeln

Projektweite AGENTS.md und README.md gelten. Nur der explizit genehmigte Steam-Build
24893155 / 1.4.5.8 mit unveränderten vollständigen Hashes und drei Runtime-MVIDs.
Entwicklungsprofil und developmentOnly erst nach bestätigter Anbindung freigeben.
Keine Attrappen, JIT-/Spieldateipatches, fremde Assemblies oder Savebearbeitung.

- Gameplay ausschließlich im beobachteten originalen Terraria-Updateereignis.
- Mono-Referenzen über GC-Handles, Besitzerwechsel und Item-Typwechsel prüfen.
- Nicht alle Werttypen sind primitive Zahlen. Enum-Basistyp und TimeSpan-ABI prüfen.
- `LightMode.Color` ist in diesem Original **3**, nicht 0. Originale Shader-/Lichtmodi
  niemals aus Bezeichnungen anderer Engines oder anderer Builds ableiten.
- Flugdauer benötigt echte ausgerüstete Flügel/Raketenstiefel. Der Basiswert von
  rocketTimeMax allein beweist keine vorhandene Ausrüstung.
- Tempo benötigt originale feste FNA-Updates; FrameSkipMode.On ist **1**.
- MHTOverlayHost.mouseInteractionEnabled mit Bedienwunsch und Fokus aktualisieren.
- Teststart: PID und nativen Rückruf abwarten, bevor CUA die App auswählt. getApp
  kann eine noch nicht registrierte App erneut starten. Bei fehlender Zuordnung
  keinen stillen Ersatzstart auslösen; die vorhandene Instanz behalten.
- Gefälschte Treffer-/Flugnachweise sind verboten. Native Wertprüfung, originales
  Ereignis und tatsächlich beobachtetes Gameplay in README klar unterscheiden.
- Tests/temporäre Ausrüstung nur unter Tests; keine solchen Aktionen im Produkt.
- Geladene Bibliotheken erhalten. Einen Kandidaten extern vorbereiten und erst
  nach freigegebenem regulärem Ende ersetzen; keine doppelten Spielstarts.
