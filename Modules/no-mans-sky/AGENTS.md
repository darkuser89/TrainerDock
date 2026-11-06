# No Man’s Sky

Root-AGENTS.md und docs/MODULES.md beachten. Der vollständige Trainer bleibt in
diesem Modul. Nur echte native Funktionen; keine Demoquellen im Produkt.
Die alte Referenz unter Documents/Codex bleibt unverändert.

Native Adressen gehören ausschließlich zur dokumentierten arm64-UUID des Steam-
Builds 26386568. Vor weiteren Updates Originalfunktionen und Layouts erneut prüfen;
keine automatische UUID- oder Hashfreigabe. Der Nutzer genehmigte für genau diesen
Build sha256-original. Keine Netzwerksperre einbauen.

Build: python3 -B script/build.py --module no-mans-sky. macOS 27+ und arm64.
Native Wirkungsprüfungen und offene Grenzen in README.md dokumentieren.

## Maus und macOS-Laufzeitlayout

- AppKit-Ivars ausschließlich mit `ivar_getOffset` zur Laufzeit bestimmen. Der
  Offline-Wert 44 für `GainputMacInputView.isMouseCaptured` ist auf diesem macOS
  falsch; nicht erneut fest verdrahten. Native Methode, Typ und Klassengröße prüfen.
- Eingabemanager-ShowMouse/UnlockMouse und die tatsächlichen Capture-Ebenen
  gemeinsam freigeben; die reine InputSystem-Flag wird von der Engine zurückgesetzt.
- Den gezeichneten Vektorpfeil erhalten. `NSCursor.arrowCursor.image` kann leer
  sein; sichtbare Cursorpixel bei 1×/2× prüfen, nicht nur Bildrepräsentationszahlen.
- Overlay/Cursor-Sichtbarkeit folgt dem Bedienwunsch und dem App-Fokus, nicht
  einzelnen verzögerten Capture-Rückmeldungen. Keine globalen Hide-Zähler ändern.
- Geladene Testbibliotheken nicht während des Laufs überschreiben. Bei notwendigem
  Ersatz nur einen kurzlebigen Austauschbestand vorbereiten und erst nach dem
  freigegebenen regulären Ende einsetzen. Spielstarts für Prüfungen bündeln.
