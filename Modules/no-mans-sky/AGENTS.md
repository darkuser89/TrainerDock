# No Man’s Sky

Root-AGENTS.md und docs/MODULES.md beachten. Der vollständige Trainer bleibt in
diesem Modul. Nur echte native Funktionen; keine Demoquellen im Produkt.
Die alte Referenz unter Documents/Codex bleibt unverändert.

Native Adressen sind getrennt in `Sources/NMSBuilds.h` gebunden:
Steam-Build 26386568 (`1FABCC98-D6B6-3905-BF1B-823BD5033DA9`) und 26540391
(`90ACDF11-4B80-34A5-B802-4F09782742CF`), jeweils arm64 und Bundle 4.70.
Der Nutzer genehmigte nach positiver Steam-Dateiprüfung beide exakten Builds
für sha256-original. Alte Profile, IDs und Hashes erhalten. Vor weiteren Updates
Originalfunktionen, GameThread, Layouts und Eingabe erneut prüfen; keine
UUID-/Hashfreigabe oder pauschale Adressverschiebung. Keine Netzwerksperre einbauen.

`Tests/NoMansSky/BuildCandidate.py <Spiel.app> --profile <id>` baut nur einen
privaten Entwicklungskandidaten und führt Original-, Native-, Bridge-, HiDPI-
und Leerlaufprüfungen aus. Kein Spielstart. Der Prüfer nutzt den echten Runtime-
Adapter; eine zweite Adapterinstanz würde dessen Frame-Maintenance verdrängen.
Geladene Prüfbibliotheken nicht überschreiben. Veröffentlichungsbuilds übernimmt
GitHub Actions nur für dieses tatsächlich geänderte Modul.

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
