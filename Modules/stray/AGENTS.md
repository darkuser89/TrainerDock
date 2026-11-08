# Stray: Regeln für weitere Chats

Die projektweite `AGENTS.md` gilt vollständig. Identität: Steam 12863654,
Stray 1.5 (100), arm64, UUID `C72D3F73-25F4-333B-9108-83432E09E687`,
Team-ID `TE4JMK2LRA`. Normale Originalsignaturprüfung verwenden; keine neue
Hash-Ausnahme, fremde UUID oder unverifizierte Adresse übernehmen.

- Der Nutzer hat den aktuellen Trainer ausdrücklich als WIP freigegeben und
  weitere Ingame-Tests beendet. Das identifizierte Steam-Profil darf ausgeliefert
  werden; WIP in Modulname, Profilhinweis und Overlay erhalten. Nur IDs 0, 1, 5
  und 7 sind freigegeben. IDs 2, 3, 4 und 6 bleiben als WIP deaktiviert, bis
  ihre Wirkung tatsächlich belegt ist. Diese Freigabe ist kein neuer Testauftrag.
  Synthetische Tests niemals als ausgeführte Spieltests beschreiben.
- Die Zustell-ABI lautet `GameThreadCall(block, NSArray *, bool)`. Exakte UUID
  und Originalprologues prüfen. Bindung nur auf dem AppKit-Hauptthread versuchen;
  jede Spieloperation zusätzlich auf den echten GameThread begrenzen. Fehlende
  Initialisierung darf weder stilles Warten ohne Bindungsversuch noch eine
  Ersatz-Ausführung auf Main-/Hintergrundthreads erzeugen.
- Strays statisch hergeleitete Reflexionsanordnung unterscheidet sich von anderen
  Unreal-Modulen: UObject Index/Klasse/Name/Outer bei `0x0c/0x10/0x18/0x20`,
  UStruct Super/Children/ChildProperties bei `0x40/0x48/0x50`, FField Next/Name
  bei `0x20/0x28`, FProperty ArrayDim/ElementSize/Flags/Offset bei
  `0x34/0x38/0x40/0x4c`; Bool-Zusatzdaten beginnen bei `0x78`.
  Ein FUObjectItem ist `0x18` Byte groß. Geladene Typen, Größen und Besitzer
  zusätzlich prüfen; niemals Frostpunk-Offsets ungeprüft übertragen.
- Klassen-Kindlisten enthalten auch `DelegateFunction` und andere UField-Typen.
  Die Funktionssuche muss originale `UField`-/`UFunction`-Vererbung prüfen,
  statt ausschließlich den Klassennamen `Function` zu erlauben. Besitzer und
  zyklische Verknüpfungen weiterhin ablehnen; Delegate-Signaturen dürfen eine
  spätere geerbte Funktion wie `ActorComponent.GetOwner` nicht verdecken.
- `GetPlayerPawn`, lokaler Controller, dessen Pawn und die LifeComponent müssen
  denselben lokalen Besitzer beschreiben. Bei Streaming ist `Level.OwningWorld`
  maßgeblich. CDOs, zerstörte Objekte, fremde Welten und alte Aufträge verwerfen;
  Weak-Referenzen einschließlich Serienkennung erhalten.
- Godmode besitzt höchstens einen eigenen originalen Push/Pop-Stapeleintrag.
  Fremde Stapel und eine unabhängig deaktivierte Schadensfreigabe erhalten.
  Gesundheit und Godmode dürfen sich beim Ausschalten nicht gegenseitig
  deaktivieren. Gesundheitsmaximum und Wirkung nativ rücklesen.
- `Push/Update/PopSpeedModifier` begrenzt Eingaben über MIN; ein Wert 2 bewirkt
  bei ursprünglichem Endwert 2 keine Beschleunigung. Für den echten Bewegungsfaktor
  ausschließlich die lokalen Walking-/Running-Cachewerte des Pawn bei
  `0x1e30/0x1e34` mit ihrer erfassten Basis multiplizieren. Beide originalen Getter
  einschließlich Prologues binden und vor/nach jedem Write gegen den Rohfloat
  prüfen. BeginPlay bezieht diese Werte aus den Animationsreferenzen TROT/RUN;
  die gemeinsamen Animationsdaten selbst bleiben unverändert. Endwerte müssen
  endlich, positiv und begrenzt sein. PawnWeak, lokale Controller-Zuordnung und
  Weltzugehörigkeit prüfen; eigene Werte nur bedingt zurücknehmen. Originale
  Rail-/Zurg-/Dialogmodifier, Inputgrenzen und Boosts niemals verändern.
- Spieltempo an die aktiven WorldSettings binden. Eigene Änderungen nur dann
  zurücknehmen, wenn der aktuelle Wert noch dem zuletzt geschriebenen entspricht.
  Der HK-Controller interpoliert das Weltzeittempo auch ohne aktiven Zeitlupenmodus
  zurück zu 1. Sein ursprünglicher Faktor ist `1-powf(m_timeDilationLerpRatio,dt)`;
  die eigene Tempo-Lease hält deshalb die typisierte Ratio bei 1 und gibt auch
  diese nur bei unverändert eigenem Wert zurück. Controllerwechsel verwirft die
  alte Lease. Ein unmittelbar gesetzter Weltwert allein belegt keine Dauerwirkung.
- Metadaten nicht in jedem 250-ms-Poll komplett neu traversieren. Die typisierten
  Caches müssen Weak-Serienkennung, native Klassenköpfe, Zieldeskriptor und Feldtyp
  weiterhin prüfen. Nur unveränderliche Metadaten und FNames cachen, keine
  Spielwerte. Deaktivierte Funktionen ohne eigene Lease dürfen keine Wirkung
  auflösen oder erfassen. Leistung im laufenden Spiel messen; synthetische
  Guard-/Leasetests ersetzen diese Messung nicht.
- Defluxor: `Battery` ist Wärme, Standard 0, Überhitzungsgrenze 1. Keine Energie
  auffüllen und keine Ausrüstung freischalten. Originale Defluxorfreigabe, lokale
  Controller-Drohnen-Zuordnung, aktive Welt, Feldtypen und Rücklesen prüfen.
- Wächter-Tarnung beruht auf dem originalen `BTS_Sentinel_Vision`-Tick: Das
  ausgeschaltete `GetVisionLightEnabled`-Flag löscht Ziel und Sichtzustand.
  `IsActorInVision` allein prüft das Flag nicht. Die originale UpdateLogic
  schaltet es nicht pro Tick wieder ein. Vier zusätzliche Dateiprüfungen binden
  Header und komprimierte Nutzdaten beider originalen Blueprint-Dateipaare;
  deren Hashes bei Updates nicht ungeprüft übernehmen. Keine Originalassets
  in Quellen, Tests oder Releases kopieren. Den misspelled nativen Setter
  `SetVisonLightEnabled` erhalten; Tarnung und Aggressionsschalter unabhängig
  zurücknehmen und fremde Zielbesitzer respektieren.
- Capture-Freigabe, sichtbaren Zeiger und Klickzuordnung getrennt testen. Den
  eigenen klickdurchlässigen Vektorzeiger erhalten; keine globalen Hide-Zähler
  als Reparatur verwenden. Glas und Slider bleiben im isolierten Overlayhost.
- Mehrere reversible Funktionen und Eingabeprüfungen in einem genehmigten Lauf
  bündeln. Geladene Bibliotheken nicht überschreiben und Doppelstarts verhindern.
  Aus dieser Anleitung ergeben sich keine zusätzlichen Start-/Beendenfreigaben.
- Tests und private Diagnoseexporte bleiben unter `Tests/Stray` beziehungsweise
  in privaten Testkandidaten. Keine Logs, Apps, Binaries, Originalkopien oder
  Auditberichte im Quellmodul ablegen.
