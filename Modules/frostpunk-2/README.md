# Frostpunk 2 · Steam

Eigenständiger nativer Trainer für Steam-Build **24037022**, Spielanzeige **1.6.1**,
Bundleversion **0.5.591**, arm64-UUID `10F7F2EA-0D13-337E-BF07-ABA47A4549CF`.
Der vollständige Trainer einschließlich Engineanbindung und Glas-Overlay liegt in diesem Modul.

27 Funktionen in sechs Gruppen: Ressourcen, Stadt & Bevölkerung, Bau & Forschung,
Rat & Gesetze, Bedürfnisse und Spielgeschwindigkeit. Die Bevölkerungsaktionen sind
getrennt: ausgewählte Gemeinschaft/Fraktion oder jede bestehende Gemeinschaft der
aktuellen Stadt auf den eingegebenen Zielwert setzen. Ein Teilfehler wird gemeldet,
niemals automatisch wiederholt. Ein Mindestbestand von einer Person bleibt erhalten.

Die Beziehungsoption begrenzt native Beziehungsabfragen global auf den konfigurierten
Höchstwert. Sie überschreibt keine Beziehungshistorie. Sofortabriss beendet tatsächliche
bereits laufende stadteigene Abrissaufträge. „Ratspause jetzt beenden“ ist eine bewusste
Einmalaktion, weil die native Funktion die Ratsphase und Sitzungsnummer weiterstellt.

Das Profil ist für den exakt gebundenen Build freigegeben. Im Originalprozess
bestätigt: GameThread und lokale Welt-/Stadtbesitzer, neun Ressourcen-Edits mit
sofortiger nativer Bestätigung, acht Dauerschalter mit Rücklesung und Ausschalten,
Bevölkerung aller vier Gemeinschaften jeweils +1/−1 sowie die ausgewählte Karte
über den Produktbefehl (490 → 491 → 490). Maus und Glasregler wurden vom Nutzer
bedient und bestätigt. Die Caches wurden mit abgelaufenen und ersetzten
Metadatenbesitzern synthetisch geprüft; echte Spielwerte werden weiterhin frisch gelesen.

Prüfgrenzen: Zwei Stadtstatistiken wurden gesetzt und zurückgenommen; vier weitere
waren in der abschließenden Messung Nachkommawerte und wurden zum Schutz ihrer
Ausgangswerte nur gelesen. Der originale Edit-Setter akzeptiert Ganzzahlen.
Sofortabriss und Ratspausenwechsel besitzen vollständig gebundene Originalaufrufe;
ihr tatsächlicher Abschluss wurde mangels passendem Auftrag bzw. Ratsphase noch
nicht im Spiel ausgelöst. Bau-/Forschungs-/Expeditions- und Gesetzesprüfungen
bestätigen die nativen Schalter, keine vollständig durchgespielten Abläufe.
Ressourcen-Edits frieren spätere normale Verbrauchs-/Lageränderungen nicht ein.
Ein erfolgreicher Build allein ist kein Ingame-Nachweis.

Die vom Nutzer genehmigte `sha256-original`-Ausnahme gilt ausschließlich für die
vier im Profil erfassten Originaldateien dieses Builds. 31 lückenlose Prüfabschnitte
binden deren gesamten Inhalt. Originaldateien und Signaturen bleiben unverändert.

Private Diagnosequellen liegen unter `Tests/Frostpunk2` und werden nie ausgeliefert.
Deren Kandidatenbuild startet kein Spiel. Produktbau:
`python3 -B script/build.py --module frostpunk-2`.
