# Vampire Survivors – eigenständiger TrainerDock-Trainer

Native arm64-Steamversion **1.16.111**, Steam-Build **25984009**. Mindestziel des
Trainers: macOS 27. Der Launcher enthält keine Spielbindung; native Mono-Anbindung,
eigener C#-Trainer, Katalog, Bridge, Eingabe und Liquid-Glass-Overlay liegen im Modul.

Das zusätzliche Epic-Profil **1.16.111 (64959298)** besitzt eine eigene Storebindung.
Seine originale arm64-Signatur und 16 vollständige Dateichecks sind separat gebunden.
Der eigene Trainer akzeptiert ausschließlich das vollständige Steam- oder Epic-MVID-
Tupel. Die automatische Installationserkennung trennt beide Stores trotz gleicher
Bundle-ID. Ein direkter Online-Start ohne die Anmeldung des Epic-Launchers scheitert.
Der authentifizierte Start über den originalen Epic-Client wurde mit der echten
Trainerverbindung und einem geladenen lokalen Lauf bestätigt. Alle neun
Dauereffekte wurden im Epic-Lauf nativ als aktiv zurückgelesen; der Nutzer bediente
den Trainer selbst. Die zehn Editoren wurden in dieser Storevariante nicht
zusätzlich einzeln verändert; ihre originalen Verbraucher und die gemeinsame
Managed-ABI wurden gegen beide Storeversionen abgeglichen.

Vor einem Epic-Trainerstart den **Epic Games Launcher regulär beenden**. TrainerDock
öffnet ihn für die echte Anmeldung und startet genau das ausgewählte Originalspiel.
Ein laufender Epic-Client wird nicht automatisch beendet, weil sein Cache die
temporäre Startzuordnung überschreibt. Der allgemeine Startdienst legt dafür
kurz einen eigenen Helfer neben der Spiele-App ab und nimmt die Startzuordnung
anschließend bytegenau zurück. Die Spiel-App und ihre Signaturen bleiben unverändert.

## Funktionen

19 Funktionen in vier aufklappbaren Launchergruppen:

- Spieler: Godmode/No Hit, Super Movement Speed, Movement Speed Multiplier,
  Edit: Revivals und Edit: Rerolls.
- Waffen: Super Damage, Super Attack Radius, Super Attack Speed und Damage Multiplier.
- Erfahrung: Mega EXP, EXP Multiplier, Edit: EXP, Edit: Growth und Edit: Luck.
- Münzen/Statistik: Edit: Coins, Coins Collected, Enemies Killed, Lifetime Coins,
  Total Coins.

Dauereffekte sind F1–F9, Editoren F10–F12 und Umschalt+F1–F7. Die Editoren
werden nur ausdrücklich ausgeführt und niemals beim Start wiederholt.
„Coins Collected“ ist auf Nutzerwunsch **RunCoins**, der Münzwert der laufenden
Runde. Coins ist das Guthaben; Enemies Killed ist RunEnemies. LifetimeCoins und
TotalCoins bleiben die getrennten Originalzähler. Revivals bearbeitet verbleibende
Wiederbelebungen unter Berücksichtigung bereits verbrauchter Revivals.

Super Movement skaliert um 3, Super Damage um 10, Area um 4, Cooldown auf 10 %
und Mega EXP den Wachstumswert um 100. Normale Faktoren wirken zusätzlich.
Die originalen Waffen-, Schadens-, Flächen- und Cooldown-Grenzen bleiben gültig;
ein hoher Stat-Wert hebt diese Engine-Grenzen nicht auf. EXP-Funktionen verändern
die native lokale Growth-Komponente; neue Erfahrung muss weiterhin gesammelt werden.

## Identität und eigene Effekte

Das Profil prüft die originale arm64-Slice einschließlich UUID und exaktem
CDHash. Die gültige Hauptdateisignatur wird nicht verändert. Die mitgelieferte
unitypurchasing-Unterkomponente besteht die vollständige Bundle-Prüfung nicht;
daher wird der bereits unterstützte Profilvertrag `arm64-executable` verwendet.
16 vollständige SHA-256-Abschnitte binden UnityPlayer, Mono und die fünf relevanten
Managed-Assemblies. Die Managed-Anbindung prüft zusätzlich die MVIDs von Runtime,
PhaserPort, UniTask und UnityEngine.CoreModule. Keine pauschale Buildfreigabe.

Bootstrap erfolgt über die originale UniTask-ContinuationQueue; erst der tatsächlich
ausgeführte eigene Unity-Update-Rückruf verarbeitet native Gameplayaufträge.
Lokaler Spieler, Statbesitzer, Konfigurationsobjekt und Szene bilden den Kontext.
Bei Besitzerwechsel werden alte Befehle und Dauereffekte verworfen. Netzwerkstatus
ist keine Sperre; bei einer Netzwerksitzung wird weiterhin nur der lokale Spieler gewählt.

Faktoren verwenden einen getrennten, zurücknehmbaren Anteil der originalen
EggFloat-Stats. Natürliche Val-Zuwächse durch Levelaufstiege bleiben erhalten.
Nur unverändert eigene Anteile werden zurückgesetzt. Die Originalassemblies und
Saves werden niemals direkt bearbeitet. Explizite Münz-/Statistikaktionen können
vom Spiel normal gespeichert werden. Der Glasregler verändert ausschließlich
den Hintergrund und nutzt den gemeinsamen gespeicherten Optionskanal.

## Prüfung und Build

Im Spiel wurden alle neun Dauereffekte nativ zurückgelesen und die Rücknahme
geprüft. Alle zehn Editoren wurden über das echte Runtime-Protokoll gesetzt und
zurückgelesen; Geld-, EXP- und Statwerte lassen sich ohne Rundungsverlust zurücknehmen.
Bei bereits negativem verbleibendem Revival-Zähler wurde auf null verbleibende
Revivals zurückgesetzt. Die ursprünglichen Münz- und Rundenzähler wurden
wiederhergestellt. Umschalt+F2 führte den Reroll-Editor über den echten Tastenpfad aus.
Mausbedienung und Glasregler wurden im Spiel geprüft. Ein quantitativer Vergleich
realer Waffenabstände und Trefferzahlen wurde nicht durchgeführt; die Original-Stat-
Verbraucher und deren Begrenzungen wurden anhand des Originalcodes geprüft.

Synthetisch geprüft: ungültige Identität, finite Werte, Integergrenzen, Einmalaktionen,
Besitzerwechsel, Netzwerk-Kontinuität, Stop-Priorität, Glasregler und echte
1×/2×-Darstellung bei vier Zoomstufen. Tests liegen ausschließlich unter
`Tests/VampireSurvivors` und gehören nicht zum Produkt. Der temporäre Testbuilder
startet kein Spiel; für echte AppKit-Mausprüfungen ist die normale Fensterzuordnung nötig.

```sh
TRAINERDOCK_REFERENCE_BUNDLE="/Pfad/zur/Vampire_Survivors.app" python3 -B script/build.py --module vampire-survivors
```

Alternativ den Spielpfad zuvor in TrainerDock speichern. Ausgabe:
`~/Library/Developer/TrainerDock/Modules/vampire-survivors.mhtmodule`.
Anschließend im Launcher „Trainer & Spiele neu laden“.
