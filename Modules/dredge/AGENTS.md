# DREDGE

Die projektweite `AGENTS.md` gilt. Vor Änderungen `README.md` und die Originalprofile
lesen; Store, Spielbuild, Modulversion und freigegebene Identitäten getrennt halten.
Keine weiteren Builds oder MVIDs stillschweigend freigeben.

- Nur echte native Effekte; keine Testobjekte oder Prüfer in Produktquellen aufnehmen.
- Mono-Zugriffe ausschließlich im beobachteten originalen Unity-Rückruf der gültigen
  Spieldomain. GC-Handles, typisierte Parameter, Feldgrößen und Decimal-ABI erhalten.
- Leerlauf ohne Inventar-/Szenensuche; aktive Sammlungen begrenzt prüfen. Metadaten
  dürfen gecacht werden, Spielwerte nicht. Besitzerwechsel und eigene Rücknahme sichern.
- Unverwundbarkeit benötigt sowohl GodMode als auch ImmuneMode. Verkaufspreise nur
  am tatsächlichen Verkaufshandler anwenden. Forschungsteile sind echte Lagerobjekte.
- Forschung wird pro Klick mit genau einem Teil bezahlt (`SpendResearchItem`, danach
  `AdjustResearchProgress(..., 1)`). Ein nachgefülltes Originalteil genügt; nicht das
  Lager mit Teilen füllen oder Fortschritt vortäuschen. Nach eigener Rücknahme
  `ResearchHelper.UpdatePartCount` aufrufen, da der Zähler separat gecacht wird.
- Ausrüstungsfreigabe benötigt neben den PlayerStats-Hashsets den echten Fangtyp
  einer tatsächlich eingebauten, intakten Angelrute. Arraytyp, GC-Besitzer,
  Feldidentität und Grenzen prüfen. Nur eigene Arrayelemente zurücknehmen;
  `HasUndamagedEquipment` zurücklesen und die originale Fangansicht nach einer
  Änderung einmalig aktualisieren, niemals ein laufendes Minispiel zurücksetzen.
- Native Glasflächen erst nach beobachteten Originalframes isoliert anlegen. Keine
  Views oder Auto-Layout-Constraints ins Unityfenster einbauen. Maus-, Glasregler-
  und Vollbildprüfungen aus `Tests/Dredge/NativeContractTests.mm` erhalten.
- Alle sichtbaren Texte auf Deutsch; Spielname oben links, gemeinsamer Glasregler unten
  rechts. Netzwerkstatus darf Funktionen nicht blockieren.
- Für Starts und Beenden die konkrete Nutzerfreigabe beachten. Geladene Bibliotheken
  nicht überschreiben; zusammengehörige Prüfungen in einer Instanz bündeln.
- Produktprofil und `developmentOnly` erst nach belegter Anbindung freigeben.
  Ein synthetischer Test ersetzt keine Ingame-Prüfung.
- Neue Stores/Spielupdates im vorhandenen Modul ergänzen; alte Releases unverändert
  erhalten. Builds extern halten, Einzeltrainer-Veröffentlichung gemäß
  `docs/RELEASING.md`; keine Binaries oder Auditberichte im Code ablegen.

## GOG 1.5.3 und zwei Architekturen

GOG-Build 59048070897032907, Produkt 1744110647, ist ausschließlich als x86_64-Profil
gebunden. Der Nutzer hat nach fehlerfreier GOG-Prüfung die 18 Originaldateien mit
25 lückenlosen SHA-256-Abschnitten ausdrücklich genehmigt. Keine stillen Hashupdates.
`DredgeBuild.h` hält die nativen UUIDs und die Spielassembly-MVID getrennt je CPU.
Epic bleibt arm64 mit seiner bisherigen Bindung. Keine GOG-Adressen/MVIDs allein
aufgrund derselben Bundle-ID für Epic übernehmen; GOG ist Version 1.5.3, Epic 1.5.5.

`Build.json` nennt beide `architectures`. Die Paketphase führt native, Bridge- und
HiDPI-Prüfungen gegen jede Architektur aus und verlangt identische Katalogmetadaten.
Die Universal-Paketprüfung setzt TrainerDock 1.2.6 voraus; ältere Pakete erhalten.
GOG verwendet den normalen Appstart. Keine Epic-Startzuordnung dafür ändern.

## Verkaufspreise

Das originale `ItemManager.GetItemValue` begrenzt den Fisch-Verkaufsfaktor auf
mindestens 1; Nichtfische verwenden den Händlerfaktor ohne diese Grenze.
Fischhändler kaufen auch Reusen (`itemSubtypesBought == 257`), daher nicht anhand
des Händlertyps nur einen der Preiszweige annehmen. `DredgeSalePrice.hpp` bildet
beide Originalzweige ab. Der Adapter kompensiert bei tatsächlich vorhandenen,
vom Händler akzeptierten Nichtfischen ausschließlich `hasSellOverride` und
`sellOverrideValue`; Kaufwert und Kaufzweig bleiben unverändert. Eigene Leases,
Original-Decimal-Rechnung, Rücklesen und bedingte Rücknahme erhalten. Bei
widersprüchlichen gleichzeitig aktiven Händlerbasen keine Wirkung behaupten.
Fokuspreis und Sammelverkauf nach echten Änderungen einmalig aktualisieren.
Gleiche Feldwerte nicht periodisch neu schreiben. Gutschrift und angezeigter
Bruttopreis unterscheiden sich bei der originalen Kreditrückzahlung in Großmark.

## Mac App Store 1.5.24 (237): kein freigegebenes Profil

Die unveränderte MAS-Version besitzt eine gültige vollständige Apple-Signatur,
aktiviertes Hardened Runtime und `disable-library-validation`, aber kein
`com.apple.security.cs.allow-dyld-environment-variables`. Der genehmigte einzelne
Teststart lud die Trainerbibliothek nicht; kein nativer Trainerkanal wurde aktiv.
Diese Version wird daher nicht als unterstützt angeboten. Keine Spieldateien,
Signaturen oder Entitlements ändern. Vor einem späteren MAS-Versuch zuerst den
original erlaubten Ladekanal prüfen; gleiche Unity-UUIDs belegen keine Ladbarkeit.
Referenz: https://developer.apple.com/documentation/BundleResources/Entitlements/com.apple.security.cs.allow-dyld-environment-variables
