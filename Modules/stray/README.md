# Stray für TrainerDock (WIP)

Eigenständiges natives Trainermodul für **Stray 1.5 (100)**,
**Steam-Build 12863654**, App-ID **1332010**, arm64. Bundle-ID:
`com.annapurnainteractive.Stray`; Team-ID: `TE4JMK2LRA`; Hauptprogramm:
`Stray-Mac-Shipping`; UUID: `C72D3F73-25F4-333B-9108-83432E09E687`.
Die normale Originalsignaturprüfung bleibt verpflichtend. Andere Builds sind
nicht durch diese Identität freigegeben; das Spielbundle bleibt unverändert.
Vier zusätzliche Dateiprüfungen binden die originalen Wächter-Blueprints, auf
deren Sicht- und Update-Logik die Tarnfunktion beruht. Originalassets werden
weder ins Modul kopiert noch mitgeliefert.

Der Nutzer hat die Veröffentlichung des aktuellen Standes ausdrücklich als **WIP**
freigegeben und weitere Ingame-Tests beendet. Launcher, Profil und Overlay tragen
diese Kennzeichnung. Unverwundbarkeit, Gesundheit, Defluxor ohne Überhitzung und
Spielgeschwindigkeit sind verfügbar; native Wirkung und Rücknahme wurden geprüft.
Der Nutzer bestätigte den Gesundheitsschutz gegen Zurks sowie den Defluxor.
Maus, Schalter und Glasregler wurden ebenfalls bestätigt; nach der Cachekorrektur
bestätigte der Nutzer wieder flüssiges Spielen.

Vier Funktionen bleiben sichtbar als WIP deaktiviert: Zurk-Tarnung verhindert
Angriffe noch nicht vollständig; Sentinel-Tarnung und Angriffssperre besitzen
keinen bestätigten Verhaltenstest; der korrigierte Bewegungsfaktor wurde nur
synthetisch geprüft. Native Rücklesewerte allein belegen keine Gegnerwirkung.
Alle acht Funktionen behalten ihre IDs und die Gruppen Katze, Gegner, Ausrüstung
und Spiel. Ein erfolgreicher Build ersetzt keinen Ingame-Nachweis.

## Native Architektur

- `StrayEngine.*` bindet Originalprologues, schwache Objektreferenzen und
  Reflexionsmetadaten. Begrenzte Caches halten ausschließlich Metadaten;
  Weak-Serienkennung, Köpfe und ausgewählte Felddeskriptoren werden weiterhin
  geprüft. Spielzugriffe laufen ausschließlich auf dem bestätigten
  ursprünglichen GameThread. Dessen Zustellfunktion nimmt Block, `NSArray *`
  und anschließend `bool` entgegen. Der Hauptthread darf die Bindung erneut
  versuchen, führt aber keine Spielaufträge als Ersatz aus.
- `PlayerEffects.*` verwaltet eigene Unverwundbarkeits-, Gesundheits-, Bewegungs-
  und Spieltempoänderungen. Die originale Schutzstapelung und die ursprüngliche
  Schadensfreigabe werden gemeinsam berücksichtigt. Der Bewegungsfaktor skaliert
  die zwei lokalen Walking-/Running-Basiswerte des Pawn; beide originalen Getter
  prüfen Layout und Rücklesen. Die ursprünglichen MIN-Modifier, Inputgrenzen und
  Boosts bleiben erhalten. Beim Ausschalten werden nur unverändert eigene Werte
  zurückgegeben; fremde Änderungen und abgelaufene Besitzer bleiben geschützt.
  Spieltempo berücksichtigt zusätzlich die originale Zeitinterpolation des
  lokalen Controllers und stellt deren eigenen Ausgangswert wieder her.
- `EnemyEffects.*` bindet Gegner derselben aktiven Spielwelt. Geladene Vorlagen,
  fremde Welten oder abgelaufene Besitzer dürfen keine Effekte erhalten.
- `Defluxor.mm` behandelt `Battery` als normalisierte **Wärme von 0 bis 1**,
  nicht als Energievorrat. Die Funktion setzt eine im Spiel bereits freigeschaltete
  lokale Defluxor-Drohne voraus und gewährt keine Ausrüstung.
- `StrayInput.mm`, `OverlayCursor.m` und `MHTOverlayHost` trennen ursprüngliche
  Mausfreigabe, sichtbaren eigenen Vektorzeiger und richtige Klickkoordinaten.
  Das Spielfenster erhält keine zusätzlichen Glas-Views oder Constraints.
  Der Glasregler unten rechts wird über den normalen Optionskanal gespeichert.
- Ausgeschaltete Funktionen ohne eigene Wirkung lösen keine zusätzlichen
  Spieler- oder Ausrüstungsabfragen aus. Gegner werden begrenzt neu gesucht;
  ihre Zugehörigkeit wird vor jeder Änderung frisch geprüft. Laufzeitmessungen
  und Wirkungsprüfungen erfolgen getrennt von synthetischen Grenztests.

## Weiterentwicklung

Zuerst [AGENTS.md](AGENTS.md), die projektweiten Regeln und
[Overlay-Eingaben](../../docs/OVERLAY_INPUT.md) lesen. Für einen anderen Chat
[CHAT_START.md](CHAT_START.md) verwenden. `Tests/Stray` enthält ausschließlich
Entwicklungsprüfer und synthetische Fixtures; sie gehören nicht ins Produkt.

WIP-Modul bauen:

```sh
python3 -B script/build.py --module stray
```

Build und App bleiben unter `~/Library/Developer/TrainerDock`. Die ganzen
Trainerquellen liegen in diesem Modul; im Launcher entsteht keine Stray-Spiellogik.
