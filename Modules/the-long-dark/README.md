# The Long Dark – natives TrainerDock-Modul

Eigenständiger Trainer für Steam **2.60 (0), Build 26450964**, arm64, macOS 27+.
Der Launcher lädt nur Metadaten; IL2CPP-Anbindung, GameThread-Zustellung,
Auswahlverwaltung, vollständiges Ingame-Overlay und Glasregler gehören ins Modul.

Alle 44 angefragten Funktionen sind nativ angebunden und freigegeben. Version 0.2.0
ergänzt Schadensmultiplikator, Gegenstandsnutzungen, sofortiges Herstellen,
Schnellspeichern, Todesschutz für den Spielstand, Waffen, Munition und Schusswaffenschaden.
Die unten genannten Prüfgrenzen bleiben maßgeblich.

## Native Bindung

Das Profil prüft die sieben erfassten Originaldateien lückenlos per SHA-256.
Der Nutzer hat diese Ausnahme ausschließlich für Build 26450964 nach fehlerfreier
Steam-Dateiprüfung genehmigt. Keine Spieldateien oder Signaturen werden verändert;
neue Builds bleiben gesperrt. Zusätzlich sind die arm64-UUIDs von Hauptdatei,
GameAssembly und UnityPlayer gebunden.

`UnityLoop.mm` ergänzt den originalen Unity-PlayerLoop um einen einzelnen Rückruf.
Gameplayzugriffe laufen ausschließlich darin. IL2CPP löst Typen, Methoden und
Felder im gebundenen Original auf. Besitzer werden über schwache GC-Roots,
aktive Szene, Ladezustand und lebende lokale Spielfigur geprüft. Die Bridge
verwirft alte Aufträge bei Kontextwechsel. Eigene Feldüberschreibungen besitzen
Ausgangswert und Rücklesewert; Rücknahme erfolgt nur, solange der Wert noch uns gehört.
Heilung, Freischaltung, Tageszeit und Wetter sind beabsichtigte Spieländerungen,
die beim Ausschalten nicht rückgängig gemacht werden.

Referenzfelder benötigen `il2cpp_field_set_value_object` mit dem Objekt selbst
als drittem Argument. Primitive Felder verwenden den Rohwertpfad. Die Inventarliste
enthält inline gespeicherte `GearItemObject`-Strukturen. `IL2CPP.mm` lehnt sie als
Referenzliste ab; eigene Gegenstände werden stattdessen über originale Ressourcen
und `m_InPlayerInventory` ermittelt. Die Grenztests sichern diese ABI-Verträge ab.

## Funktionsgrenzen

- Haltbarkeit erhält den beim Einschalten vorhandenen Zustand. Sie repariert keine
  Gegenstände; Haltbarkeitsschutz hat Vorrang vor erhöhtem Verschleiß.
- Einfaches Handwerk entfernt vorübergehend Anforderungen geladener Baupläne.
  Sofortiges Herstellen verkürzt die reale Dauer; verstrichene Spielstunden bleiben
  die Originalregel. Ein improvisiertes Kopfstück wurde tatsächlich fertiggestellt.
- Waffen hinzufügen erzeugt neun Basiswaffen/-werkzeuge und fünf passende
  Munitionsstapel über `PlayerManager.AddItemCONSOLE`. DLC-Varianten gehören nicht
  zum Umfang. Die Aktion fügt bei jedem bewussten Aufruf erneut Gegenstände hinzu.
- Munition füllt eigene Schusswaffenmagazine. Pfeile und andere Stapel gehören zum
  Nutzungsschutz. Dieser erhält auch Lebensmittel, Flüssigkeitsreserven und
  Werkzeugnutzung; nicht jeder Gegenstandstyp wurde in jeder Verwendung geprüft.
- Der Schadensfaktor verwendet den originalen BrokenBody-Modifikator einschließlich
  dessen Aktiv-Flag. Eigene Änderungen werden beim Ausschalten zurückgenommen;
  solange er aktiv ist, kann die originale Leidenanzeige erscheinen.
- Schnellspeichern verwendet `SaveGameAndDisplayHUDMessage`, nur wenn das Spiel
  Speichern erlaubt. Die Meldung bestätigt die Anforderung, nicht den asynchronen
  Abschluss. Speichersymbol abwarten.
- Todesschutz verhindert ausschließlich die native Löschung der zum aktuellen
  Lauf gehörenden Originaldateien nach erkannter Gesundheit null oder originalem
  Tot-Modus. Er erstellt keine Kopien und bearbeitet keine Savebytes. Eine bereits
  erkannte Todesbereinigung bleibt nach Besitzerfreigabe höchstens 120 Sekunden
  geschützt; explizites Ausschalten löst den Schutz. Danach App neu starten und
  den erhaltenen Lauf laden. Keine Wiederbelebung oder sofortige Menü-Neulistung.
- Der Raubtierfaktor verändert Obergrenzen und Nachbesetzungsraten aktiver Regionen,
  erzeugt keine Tiere sofort. Die tatsächliche Population wurde nicht ausgezählt.
- Aurora bestätigt den Originalauftrag für die nächste geeignete Nachtgelegenheit.
  Eine sichtbare Aurora wurde im Test nicht abgewartet.
- Waffenstau verwendet die originale Sperre; ein tatsächlicher Stauvorgang wurde
  nicht provoziert. Reale Revolverschüsse wurden für die Munitionsprüfung abgegeben.
- Flugmodus verwendet die originale freie Kamera. Ausschalten beendet den eigenen
  Flugmodus. Bewegung, Spielzeit und Temperatur verwenden die originalen Werte.
- Nacht setzt Mitternacht; Ausschalten lässt die Zeit dort weiterlaufen. Wetter-
  und Tageszeitaktionen setzen keinen vorherigen Spielzustand zurück.

## Prüfungen und Weiterentwicklung

Im lokalen geladenen Überlebenslauf wurden Originalwerte und Aktions-Rücklesungen
bestätigt. Die letzten acht Funktionen wurden wie folgt geprüft:

- Waffen und Munitionsstapel im echten Inventar, Revolver sichtbar ausgerüstet.
- Reale Revolverschüsse: eingeschaltet sechs Patronen, ausgeschaltet Abnahme auf fünf.
- Negativer Gesundheitsschaden: Faktor 0,5 ergibt fünf statt zehn HP Verlust;
  nach Ausschalten wieder zehn. Testschaden anschließend original geheilt.
- Stapelverbrauch und Essen über originale Aktionen; Stapel und Lebensmittel
  bleiben erhalten, Kalorienreserve steigt. Eigene Feldänderungen danach gelöst.
- Reale Herstellung mit fertigem `GEAR_ImprovisedHat` im Inventar.
- Originales Schnellspeichern mit geändertem Zeitstempel/Dateigröße und beendetem
  Speicherauftrag; dieser Lauf wurde anschließend erneut im Spiel geladen.
- Todesschutz mit einem echten ermittelten Laufpfad aktiv. Zusätzlich eine eigene
  Wegwerfdatei durch den originalen `SaveGameDataPC.DeleteData`-Pfad geprüft:
  bei Test-Tot-Modus erhalten, nach Ausschalten gelöscht. Ein echter Spielertod
  samt erneutem Laden wurde nicht ausgelöst.
- Eigene Schusswaffen zeigen eingeschaltet 1.000.000 Schaden, ausgeschaltet wieder
  100. Der Originalpfad `vp_FPSShooter.Fire` übernimmt `GunItem.m_DamageHP` (+0x48)
  nach `vp_Bullet.Damage` (+0x28), das der originale Trefferpfad verwendet. Ein
  gezielter Tierabschuss wurde nicht durchgeführt; keine solche Ingame-Prüfung behaupten.

Das belegt nicht sämtliche denkbaren Spielsituationen. Mauszeiger, auseinanderliegende
Schalter, Schließen und Glasregler wurden im Overlay bedient. Bridge-, ABI-,
Todesschutz-Grenztests und HiDPI-Prüfungen laufen zusätzlich ohne Spielstart.

```sh
python3 -B script/build.py --module the-long-dark
```

Ausgabe unter `~/Library/Developer/TrainerDock/Modules/the-long-dark.mhtmodule`.
Im Launcher „Trainer & Spiele neu laden“. Bestehende Testinstanzen enthalten
weiterhin ihre bereits geladene Bibliothek; sie nicht überschreiben.
`Tests/TheLongDark` bleibt außerhalb aller Produktquellen. Start, Laden und
reguläres Beenden benötigen einen entsprechenden Auftrag; niemals Doppelstarts.
