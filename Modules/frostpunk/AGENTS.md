# Frostpunk – Steam / Intel

Die projektweite AGENTS.md und `$trainer-template` gelten. Frostpunk 2 ist ein
anderes Modul und bleibt von Arbeiten an diesem Ordner unberührt.

## Originalidentität und native Grenzen

- Ausschließlich Steam-Build 15262773, Bundle 1.1.1 (20201216.0), Spielanzeige
  1.6.1, x86_64-UUID 381A9DB7-5849-39B1-85BC-208861544E41. Die zwölf
  Originaldateien sind vollständig durch 19 SHA-256-Abschnitte gebunden;
  darunter die echten Versions/A-Frameworks einschließlich SDLs hidapi.
  Die buildspezifische Nutzerfreigabe steht in der Projekt-AGENTS.md.
- Eigene C++-Engine mit SDL2 und Metal. Statische Originalsymbole und deren ABI
  sind Grundlage der Implementierung; keine Unity-/Unreal-Annahmen übernehmen.
- `gFrostpunkGame`, `gGame` und `gFrostpunkEconomyConfig` sind direkte statische
  Objekte. Die Globals der Economy-, Cheat-, Zeit-, Gesetz- und Generatorsysteme
  sind Zeigerslots. Diese beiden ABI-Arten niemals verwechseln.
- Zustellung ausschließlich am leeren SDL_PollEvent-Rücklauf im originalen
  SDLApp::MainLoop, exakte UUID, Rücksprung ImageBase+0xdb2ae8 und Hauptthread.
  Importinterposition verändert keine ausführbaren Originalbytes oder Schutzrechte.
- Der lokale GetEntry-Einstieg ist zusätzlich an seinen originalen Prolog gebunden;
  ein nicht passender Build darf keine Adressfallbacks anderer Spiele verwenden.

## Effekte und Rücknahme

- Stabile IDs 0–14 und Einmalaktionsschutz erhalten. Ressourcenaktionen benutzen
  Originalsetter und echtes Rücklesen; Laden darf keine Hinzufügung wiederholen.
- Ressourcenmap: Economy+0x2240/0x2248, Recordgröße 0x70; EntryPtr ist ein Zeiger,
  EntryLink eine GUID mit 16 Bytes. GetEconomyProperty ist kein Mengengetter.
- Ressourcen nur über den exakt gebundenen Originaleintrag im aktuellen Map ändern.
  Visibility ist eine UI-Eigenschaft, keine Sperre des nativen Setters. Ausgeblendete
  Bestände mit entsprechendem Hinweis zurücklesen; deren Änderung schaltet weder
  Szenarien noch Technologien frei. Prothesen heißen nativ exakt `Augmentation parts`.
  DLC-Ressourcen nicht über angenommene Indizes freigeben.
- Lager ausschließlich für die neun gebundenen Trainerrohstoffe und Essensrationen
  über eigene Kapazitätszugaben verändern, auch wenn die UI sie ausblendet.
  Leichen (`Bodies`) und unbekannte Ressourcen bleiben unverändert. Den eingebauten Lager-Cheat
  0x2 niemals verwenden: Er verändert zusätzlich Bestände und leert sie beim Aus.
- Sofortbau nutzt den originalen Schalter 0x4, Sofortforschung 0x200.
  Keine anderen Cheatbits als gleichwertig behandeln; einige verändern den gesamten
  Forschungsstand. Eigene Bits freigeben, fremde Bits erhalten.
- Bereits fertiggestellte Gebäude/Forschungen und einmal hinzugefügte Ressourcen
  werden beim Ausschalten nicht rückgängig gemacht. Gesetze/Generatorstress
  werden nicht durch Wiedereinsetzen vergangener Cooldowns/Schäden zurückgedreht.
- Spieltempo am originalen FrostpunkTimer ändern; native Pausen- und Tempoauswahl
  des untergeordneten GameplayTimers erhalten. Rücknahme nur am aktuellen Besitzer.
- Ohne Aufträge/aktive Effekte keine Szenen-/Ressourcensuche. Lagerpflege nur im
  Kontextpoll; keine Ressourcenmap je Frame vollständig durchlaufen.

## Prüfung und Auslieferung

Tests/Frostpunk enthält synthetische Grenztests und den privaten, sitzungsgebundenen
Nur-Lese-Prüfer. Keine dieser Testquellen in die Produktbibliothek einbinden.
BuildCandidate.py und BuildIngameProbe.py bauen ausschließlich extern unter
~/Library/Developer/TrainerDock/Tests/Frostpunk und starten keine Spiele.
Originalstarts und reguläres Beenden benötigen den entsprechenden Nutzerauftrag.
Geladene Kandidaten niemals überschreiben. Produktprofil und developmentOnly erst
nach bestätigter Originalanbindung freigeben; fehlende Ingame-Prüfungen benennen.
Ein reines Trainerrelease erfordert keine Appversion und keine anderen Trainerupdates.
