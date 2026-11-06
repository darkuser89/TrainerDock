# Escape from Duckov · Steam

Vollständiges eigenständiges Trainermodul für **2.3.30**, Steam-Build **24013657**,
native arm64-Ausführung. Profilfreigabe und Entwicklungsstatus sind in Module.json
und Build.json maßgeblich; ein erfolgreicher Build allein bestätigt keine Wirkung.
Andere Spielupdates und Stores sind nicht freigegeben. Geänderte Mod-APIs benötigen
eigene Kompatibilitätsbelege; ein Netzwerkmarker allein blockiert keine Funktion.

| Kürzel | Funktion |
|---|---|
| F1 | Unverwundbar |
| F2 | Unbegrenztes Leben |
| F3 | Unbegrenzte Ausdauer |
| F4 | Unbegrenzte Nahrung |
| F5 | Unbegrenztes Wasser |
| F6 | Kein Nachladen |
| F7 | Sofort nachladen |
| F8 | Kein Tragegewicht |
| F9 | Garantierte kritische Treffer |
| F10 | Superschaden |
| F11 | Schaden × |
| F12 | Rüstung × |
| ⌘F1 | Geld setzen |
| ⌘F2 | Geldgewinn × |
| ⌘F3 | Gewählten Stapel setzen |
| ⌘F4 | Unbegrenzte Haltbarkeit |
| ⌘F5 | Sofort durchsuchen |
| ⌘F6 | Keine Herstellungs-/Forschungskosten |
| ⌘F7 | Sofort forschen |
| ⌘F8 | Nebel aus |
| ⌥F1 | EP setzen |
| ⌥F2 | EP-Gewinn × |
| ⌥F3 | Bewegung × |
| ⌥F4 | Spielgeschwindigkeit × |
| ⌥F5 | Sichtfeld |
| ⌥F6 | Tageszeit anhalten |
| ⌥F7 | Tageszeittempo |
| ⇧F1 | Maximales Leben |
| ⇧F2 | Maximale Ausdauer |
| ⇧F3 | Begleiter-Inventarplätze |
| ⇧F4 | Maximales Tragegewicht |
| ⇧F5 | Spieler-Inventarplätze |
| ⇧F6 | Ausdauerverbrauch × |
| ⇧F7 | Nahrungsverbrauch × |
| ⇧F8 | Wasserverbrauch × |

⌘ ^ öffnet das Ingame-Overlay mit Mausbedienung; ⇧ F9 schaltet alles aus.
Liquid Glass, Ersatzdarstellung und HiDPI-Verhalten liegen vollständig im Modul.

Geld, EP und ausgewählte eigene Stapel sind Einmalaktionen und können vom Spiel
normal gespeichert werden. Stapelgrenzen gelten weiter. Wiederherstellen startet
keine Einmalaktion. Forschungsaktionen müssen weiterhin selbst ausgelöst und
bestätigt werden; vorhandene Rezept-/Perkfreischaltungen bleiben maßgeblich.
Nebel aus entfernt die native Darstellung und aktiviert Rundumsicht bis 50 m;
es verändert keinen Kartenfortschritt. Belegte Zusatzplätze bleiben beim
Ausschalten bis zum Leeren erhalten, damit keine Gegenstände abgeworfen werden.
Netzwerk-/Modmarker allein sperren den Trainer nicht; native API-, MVID- und
lokale Besitzerprüfungen gelten weiterhin.

Der eigene C#-Trainer wird mit dem lokalen .NET-SDK gegen die unveränderte
Installation kompiliert und als Bytes in die native Trainerbibliothek eingebettet.
Originalassemblies werden weder ins Modul kopiert noch in der Installation ersetzt.
Die Zustellung erfolgt über UniTasks tatsächliche PlayerLoop und ein eigenes
MonoBehaviour.Update; erst dort werden native TrainerDock-Aufträge ausgeführt.

Bauen: `python3 -B script/build.py --module escape-from-duckov`.
Dafür den Originalpfad bereits in TrainerDock wählen oder nur für den Build
`TRAINERDOCK_REFERENCE_BUNDLE` auf die Original-App setzen. Alle Ausgabe- und
Compilerzwischenstände bleiben außerhalb des Codes im stabilen Buildbaum.

API-Grundlage: [Mono-Einbettung](https://www.mono-project.com/docs/advanced/embedding/).
Propertynamen, Setter, Ereignisse und Berechnungen stammen aus der ausschließlich
lesenden Analyse der angegebenen Originalinstallation, nicht aus dem Windows-Trainer.
