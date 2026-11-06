# Balatro Trainer

Eigenständiger vollständiger TrainerDock-Trainer für Steam **1.0.1o-FULL**, Build 17459173,
LÖVE 11.5, native arm64-Slice. Andere Stores, Updates und Mods sind nicht freigegeben.

Der Trainer nutzt ausschließlich die originale LuaJIT-C-ABI. Nach einem echten
LÖVE-Coroutine-Yield wird ein eigener Update-Rückruf registriert. Gameplaybefehle
laufen ausschließlich innerhalb dieses Rückrufs, niemals auf einer Ersatzqueue.
Der Lua-Code gehört zum Trainer und wird im Speicher geladen; Spielarchiv,
ausführbare Dateien, Signaturen und Saves werden nicht bearbeitet.

## Funktionen

- Unlimited Money: Mindestbetrag 9.999.999; eigene Anhebung wird beim Ausschalten
  gelöst, zwischenzeitliche Einnahmen/Ausgaben werden berücksichtigt.
- Unlimited Round Score: mindestens 1 Billion Punkte pro ausgewerteter Hand.
- Unlimited Hands / Discards: Vorrat beim Aktivieren auffüllen, mindestens eins.
- Game Speed: tatsächlichen Update-Zeitschritt mit 0,1–10 multiplizieren.
- Edit Money / Total Score / Hands Left / Discards Left: explizite Einmalaktionen.
- Edit Round Score: Ergebnis der **nächsten ausgewerteten Hand** einmalig setzen.
  Erst die native Schlusswertung übernimmt es; eine Vormerkung vergibt keine Punkte.

Vom Nutzer gewählte Zuordnung: **Total Score = Rundenchips** (`G.GAME.chips`),
**Round Score = Handergebnis**. Der Handeditor hat Vorrang vor Unlimited Round Score.
Die echte `final_scoring_step`-Rückgabe fließt in Animation und Addition ein;
keine reine Anzeigeänderung. Erspielte Punkte werden beim Ausschalten nicht rückgängig gemacht.

Bei Lauf-, Runde-, Blind-, Deck- oder Besitzerwechseln werden native Aufträge und
Einmalvormerkungen verworfen. Die Bridge darf Dauerschalter erst im neuen gültigen
Einzelspielerkontext erneut anwenden. Pausen lösen eigene Wirkungen. Erkannte
Netzwerk- und Modmarker allein sperren den Trainer nicht und löschen keine Auswahl.
Native Besitzer-, API- und Ladeprüfungen bleiben erforderlich; geänderte Spiel-APIs
werden dadurch nicht automatisch als kompatibel bestätigt.
Aktivmeldungen benötigen Rücklesen; die Punktefunktion wartet auf eine echte Wertung.

Das Modul enthält das HiDPI-Overlay mit Liquid Glass und nativer Ersatzdarstellung.
Die LÖVE-Eingaberückrufe werden vor den Spielhandlern an das Overlay geleitet;
das isolierte Panel bleibt für die Maus durchlässig, damit jeder Klick genau einmal
verarbeitet wird. ⌘ + ^ / ⌘ + ` öffnen den Trainer; Escape schließt ihn.
Der Launcher kann die Sichtbarkeit ebenfalls umschalten.

## Entwickeln und bauen

```sh
TRAINERDOCK_REFERENCE_BUNDLE="/Pfad/Balatro.app" python3 -B script/build.py --module balatro
```

`TRAINERDOCK_REFERENCE_BUNDLE` wird nur für die synthetischen Tests mit der originalen
LuaJIT-Laufzeit benötigt, nicht als fest eingebauter Spielpfad. Die Modulidentität
prüft die originale arm64-Signatur/UUID sowie die vollständigen Hashes von Spielarchiv,
LuaJIT-, LÖVE- und SDL-Bibliothek. `undefinedSymbols` bindet nur die zwei angegebenen
Originalsymbole für dyld-Interposition; keine pauschal erlaubten unaufgelösten Symbole.

`Tests/Balatro` enthält ausschließlich Testhilfen und synthetische Fixtures; sie
werden nicht ausgeliefert. Lua-ABI-/Policytests sind keine Ingame-Nachweise.
