# Vampire Crawlers – nativer TrainerDock-Trainer

Eigenständiger vollständiger Trainer für Steam, Bundle 1.6.1 (11), Build-ID 25304267,
arm64 auf Apple Silicon. Andere Builds und Stores sind nicht freigegeben.
Das erfasste Steam-Profil ist nach den unten beschriebenen nativen Prüfungen freigegeben.

## Funktionen

Godmode, No Mana Cost, One Hit Kill und EXP Multiplier sowie 23 explizite Editoren:
Town Coins, Dungeon Coins, EXP, Health, Armor, Might, Amount, Area, Growth, Greed,
Luck, Recovery, Mana, Hand, Magnet, Duration, Revival Charge, Revival Stacks,
Card Skips, Rerolls, Banishes, Curse und Charm.

Hand bezeichnet den nativen Wert `DealCount` für Karten pro neuer Hand. Der Editor
passt bei Bedarf dessen native Grenzen für den laufenden Dungeon einmalig an.
Gesundheit bleibt auf das native Maximum begrenzt. EXP ist
`TotalXp` des laufenden Dungeons; das Spiel verarbeitet Levelaufstiege. Änderungen
können vom Spiel regulär gespeichert werden. Einmalaktionen werden ausschließlich
nach expliziter Betätigung ausgeführt. Der Editorbereich für Revival Charge ist auf 0 bis 99 begrenzt.

## Native Umsetzung

`IL2CPP.mm` bindet ausschließlich Exporte der bereits geladenen originalen
GameAssembly. `UnityLoop.mm` ergänzt über originale PlayerLoop-APIs einen nativen
Rückruf; nur dieser führt Gameplay-Aufträge aus. Klassen und Felder werden aus den
originalen Metadaten aufgelöst, ohne feste Spieladressen oder Binärpatches.
`VampireBackend.mm` besitzt die vollständige Spiellogik mit nativen Weak-Handles,
Profil-/Laufkennung, eigenen Effektbaselines und Rücklesebestätigung.

Godmode verwendet `PlayerModel.SetInvulnerable`. Manafreiheit betrifft ausschließlich
Karten des aktuellen Spielers; entfernte Karten verlieren unsere temporäre Wirkung.
One Hit Kill setzt aktive Gegner im lokalen Kampf auf 1 Gesundheit und 0 Rüstung;
der nächste Treffer besiegt sie. Besiegte Gegner werden beim Ausschalten nicht
wiederbelebt. Der EXP-Multiplikator ergänzt nur tatsächlich neu beobachtete Gewinne.
Das Overlay gibt Cursor und zuvor aktive InputActionMaps beim Schließen zurück.

## Ausdrücklich genehmigte Originalprüfung

Dieser Steam-Build enthält trotz erfolgreicher Steam-Dateiprüfung eine ungültige
Originalsignatur des Hauptprogramms (Info.plist, −67030). Der Nutzer hat ausschließlich
für diesen erfassten Build `sha256-original` genehmigt. Vor jedem TrainerDock-Start werden
Info.plist, vollständiges Universal-Hauptprogramm, GameAssembly, UnityPlayer und
IL2CPP-Metadaten mit 39 SHA-256-Abschnitten lückenlos geprüft. UUID und Version bleiben
Pflicht. Keine Signaturen, Spieldateien oder macOS-Schutzmechanismen werden verändert.

## Prüfen

Synthetische Tests liegen in `Tests/VampireCrawlers/NativeContractTests.m` sowie in den
gemeinsamen Bridge-, Identitäts- und HiDPI-Prüfungen. `Probe.mm`, `CandidateChecks.mm`,
`Launch.swift`, `Query.swift` und der Metadatenleser sind reine Entwicklungswerkzeuge;
sie werden niemals ins Produkt gelinkt. Der native PlayerLoop-Rückruf ist im Spiel bestätigt. Alle 23 Werteditoren
bestanden einen gebündelten nativen Setz-/Rücklese-/Wiederherstellungstest.
Gesundheit: 120 → 119 → 120; Handgröße: 4 → 5 → 4 einschließlich ursprünglicher
Handgrenzen. Alle übrigen Editorproben: +1 und Wiederherstellung des Ausgangswerts.
Zusätzlich blieb die interaktiv gesetzte Handgröße 5 über mehrere Frames erhalten;
die originale Spieloberfläche zeigte den geänderten Wert und 4/5 Handkarten an.

Godmode, Manafreiheit und One-Hit-Gegnerwerte wurden mit Rücknahme geprüft.
Mana blieb beim echten Kartenausspielen erhalten; Gegner wurden nach Treffern
besiegt. Ein kontrollierter echter EXP-Gewinn ergab 0 → 2 → 0 bei gleichem Level;
auch beim Kartenausspielen war der Multiplikator aktiv. Die strengere Zuordnung
über genau einen aktiven EnemyEncounter und dessen eigene Liste bestand danach
die drei Schalter-/Rücknahmeprüfungen. Overlay-Mausbedienung und Eingaberückgabe
wurden geprüft. Insgesamt drei Spielstarts; keine parallelen Spielinstanzen.

Guardian-/Bossbegegnungen, alle denkbaren Wertebereiche, Langzeitsitzungen und
weitere Spielbuilds wurden nicht geprüft. Build und synthetische Tests ersetzen
diese fehlenden Ingame-Prüfungen nicht.
