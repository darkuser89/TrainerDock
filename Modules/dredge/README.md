# DREDGE – Epic Games Store und GOG

Eigenständiger Trainer mit getrennten Profilen für **Epic 1.5.5 (prod-osx-2994.1, arm64)**
und **GOG 1.5.3 (Build 59048070897032907, x86_64 unter Rosetta)**.
Der vollständige native Adapter, Katalog, Nachrichtenkanal und das Ingame-Overlay
liegen in diesem Modul. Der Launcher enthält keine DREDGE-Spiellogik.

## Native Anbindung

`DredgeNative.mm` bindet die drei nativen Images und die MVIDs der Mono-Assemblies.
Spielzugriffe laufen ausschließlich im tatsächlich ausgeführten originalen
`UnityEngine.Application.onBeforeRender`-Rückruf der Spieldomain. Typisierte
Metadaten und GC-Handles sichern Objekte und Aufrufe. Der Framepfad führt ohne
aktivierte Effekte keine Inventar- oder Szenensuche aus.

`DredgeAdapter.mm` enthält alle 15 Funktionen und prüft deren eigene Schreibwerte.
Geld verwendet `System.Decimal` und die originale Geldänderungsmethode.
Der Verkaufspreisfaktor berücksichtigt getrennt die originale Mindestgrenze für
Fische und die Wiederverkaufsbasis für Ausrüstung; Kaufpreise bleiben erhalten.
Großmark zieht weiterhin die originale Kreditrückzahlung vom Erlös ab.
Forschung ergänzt bei Bedarf ein echtes Teil im Lager; freier Platz ist nötig.
Aufwertungskosten sind Geld- und Materialkosten: Vorgänger-, DLC-, Rumpf- und
Platzanforderungen werden nicht umgangen. Kontextgebundene Funktionen warten auf
entsprechende Gegenstände, Fangvorgänge oder Verkaufsansichten.

Eigene Feldänderungen werden nur zurückgenommen, wenn ihr letzter eigener Wert
noch vorliegt. Besitzerwechsel lösen die bisherigen Effekte. Unverbrauchte eigene
Forschungsteile werden beim Ausschalten entfernt; verbrauchte Teile nicht ersetzt.

## Overlay und Start

Das isolierte `MHTOverlayHost`-Panel wird erst nach zwei Originalrückrufen erzeugt.
Das Enginefenster erhält keine zusätzlichen Views oder Constraints. Cursorfreigabe
verwendet Unitys Cursorzustand und die originalen DREDGE-Eingabemethoden.
Der gemeinsame Glasregler, HiDPI und die gespeicherten Overlayoptionen bleiben erhalten.

Das Epic-Profil verwendet den gemeinsamen Broker. Epic muss zuvor regulär beendet
sein. Spieldateien und Signaturen werden nicht gepatcht; Save-Dateien werden nicht direkt bearbeitet. Bei Epic validiert `arm64-executable` den Originalcode; ergänzende vollständige
Dateihashes binden die erfassten Bibliotheken und Assemblies. GOG nutzt ausschließlich
die ausdrücklich genehmigten vollständigen SHA-256-Werte seiner 18 Originaldateien.
GOG startet direkt als App; der Epic-Client wird dafür nicht benötigt.

Das Paket enthält beide ausdrücklich gebundenen Architekturen. Jede Slice bindet
ihre eigenen drei nativen UUIDs und die MVID der jeweiligen Spielassembly. Die
Engine- und mscorlib-Assemblies sind bytegleich; Spielfelder werden weiterhin frisch
über typisierte Mono-Metadaten aufgelöst. Das Universal-Paket benötigt TrainerDock
**1.2.6** oder neuer; die App selbst bleibt arm64 und macOS 27+.

## Nicht unterstützte Storeversion

Mac App Store 1.5.24 (237) wird nicht angeboten: Der gehärtete Originalstart erlaubt
keine DYLD-Umgebungsvariablen und lud die Trainerbibliothek im Test nicht.
Spielsignatur und Schutzmechanismen bleiben unverändert.

## Entwicklung

Projektweite `AGENTS.md`, `docs/MODULES.md` und `docs/OVERLAY_INPUT.md` beachten.
Weitere Spielbuilds bleiben ohne eigene Prüfung und Freigabe gesperrt. `Tests/Dredge/BuildCandidate.py` baut den sitzungsgebundenen Prüfstand unter
`/private/tmp/trainerdock-dredge`; es startet kein Spiel. `--stage` baut einen
kurzlebigen Austauschstand, ohne die geladene Bibliothek zu überschreiben.
Der private Prüfkanal bietet zusätzlich `equipment-setup`, `equipment-check` und
`equipment-reset` für ausdrücklich genehmigte Originalgegenstandstests. Er verweigert
vorhandene Nutzer-Netze/Reusen und bindet jedes eigene Testobjekt an den ursprünglichen
Spielstand; vor dem Entfernen müssen die Produktschalter ausgeschaltet sein.
Die Prüfer sind keine Produktquellen. Veröffentlichungen erfolgen ausschließlich
über den getrennten Einzeltrainer-Ablauf aus `docs/RELEASING.md`.

Für den GOG-Prüfkandidaten `Tests/Dredge/BuildCandidate.py --profile gog-x86_64-1.5.3-59048070897032907 --game-app "/Volumes/Mac Games/DREDGE.app"` verwenden. Der Builder startet kein Spiel.
