# Escape from Duckov – vollständiger nativer TrainerDock-Trainer

Die übergeordnete AGENTS.md sowie docs/MODULES.md gelten. Kein Demo-Adapter und
keine synthetische Unity-Instanz darf ins Produkt gelangen.

- Profil: Steam 2.3.30, Build 24013657, originale arm64-UUID sowie SHA-256-Prüfungen
  der tatsächlichen Managed-Assemblies. Andere Builds bleiben gesperrt.
- MonoRuntime.mm verwendet ausschließlich die exportierte Mono-Einbettungs-API.
  Eigener C#-Code wird in Trainer.dylib eingebettet und im ursprünglichen Unity-
  AppDomain geladen. Keine Spieldateien kopieren, patchen oder neu signieren.
- Gameplay ausschließlich aus der echten Unity-PlayerLoop: Bootstrap über die
  installierte UniTask-ContinuationQueue, Ausführung aus MonoBehaviour.Update.
  PlayerLoopHelper.IsMainThread prüfen. AppKit dient nur dem Wiederholungsversuch;
  eine Haupt- oder Hintergrundqueue ist kein Ersatz für den GameThread.
- Managed/Trainer.cs prüft ursprüngliche MVIDs, Level, lokale Hauptfigur, Inventar,
  Begleiter und ausgewählte Gegenstände. Bei Szenen-/Besitzerwechsel, Pause und
  Speichern eigene Effekte lösen. Keine pauschale Netzwerk-/Modmarkersperre;
  ursprüngliche MVIDs, native APIs und eindeutige lokale Besitzer weiter prüfen.
- Eigene Stat-Modifikatoren anhand ihres tatsächlichen Besitzers lösen. Niemals
  fremde Modifikatoren löschen. Skalare nur bei passendem Ziel und unverändertem
  eigenem Wert zurücknehmen. Zusatzplätze mit Gegenständen erst nach dem Leeren
  zurücknehmen; niemals Gegenstände zum Wiederherstellen einer Größe abwerfen.
- Geld, EP und Stapelmengen sind ausschließlich explizite Einmalaktionen. Stapel
  müssen der lokalen Figur gehören und ihre native Stapelgrenze einhalten. Gewinne
  nur über native Ereignisse multiplizieren; eigene Transaktionen nicht erneut
  multiplizieren. Keine direkten Save-Zugriffe und keine CheatMode-/Schutzänderung.
- Nicht belegte Wirkungen nicht als aktiv melden. Native Rückleseprüfung entscheidet.
  Nicht bestätigte neue Anbindungen bleiben developmentOnly bzw. deaktiviert.
- Builds unter ~/Library/Developer/TrainerDock. Managed-Referenzen nur aus der originalen
  Installation lesen: gespeicherter TrainerDock-Spielpfad oder TRAINERDOCK_REFERENCE_BUNDLE.
  Keine fremden Assemblies, Binärkopien oder Compilerbestände im Code speichern.
