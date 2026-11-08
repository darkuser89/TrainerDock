# Turok 2: Seeds of Evil

Eigenständiger Trainer für Steam-Build **20961743**, Bundle 2.0 (1), x86_64 unter
Rosetta auf macOS 27+. Der arm64-Launcher lädt nur die Modulmetadaten.

- Unbegrenzte Gesundheit: originale Unverwundbarkeit der eigenen Spielfigur.
- Unbegrenzte Munition: originaler Schutz vor Munitionsverbrauch; fügt keine Waffen hinzu.
- Nebel entfernen: übersteuert nur die tatsächlich ermittelten skalaren Nebelparameter
  am Renderer. Geometriesichtweite und Originaldateien bleiben unverändert.

Die fünf Originaldateien im Profil werden vollständig per SHA-256 geprüft.
Der Nutzer hat ausschließlich diesen unsignierten Originalbuild freigegeben.
Keine Originaldateien oder Signaturen werden geändert. Neue Builds bleiben gesperrt.

Die Enginezustellung erfolgt am originalen SDL-Bildwechsel auf dem bestätigten
Haupt-/Spielthread. Lokale Spielfigur und Ladezustand werden über originale
Besitzerfelder geprüft. Eigene Schutzbits werden zurückgelesen und beim Ausschalten
unter Erhaltung anderer Flags gelöst. Eine zuvor aktive Originalunverwundbarkeit
bleibt erhalten. Die Mausfreigabe umfasst relative Eingabe, Fensterbindung und
Mauszentrierung; ein klickdurchlässiger Vektorpfeil bleibt bei 1×/2× sichtbar.

## Prüfung

Originalidentität und vollständige Dateihashes wurden bestätigt. Der tatsächliche
SDL-Rückruf, lokale Besitzer und gesetzte Schutzbits wurden im geladenen Spiel
zurückgelesen. Der Nutzer hat die Funktionen anschließend im Spiel bestätigt.
Der originale Munitionsverbrauch bleibt eingeschaltet bei 7 → 7. Ausgeschaltet
sinkt er auf 6; die eine Testpatrone wurde sofort über den Originalpfad zurückgegeben.
Alle drei Funktionen wurden im laufenden Spiel nativ bestätigt; der Nutzer meldete
danach „geht alles“. Eine separate gezielte Schadenssituation wurde nicht ausgelöst.

Zusätzlich bestehen native Besitz-/Bit-/Rücknahmegrenzen, Bridge- und HiDPI-Tests
sowie ein echter GPU-Pixeltest mit einem eigenen synthetischen Shader. Dieser
prüft Nebelabschaltung, frameweise Originaluploads und Wiederherstellung der jeweils
letzten Originalwerte. Shader-/SDL-Fixtures bleiben ausschließlich unter Tests/Kex;
sie gehören nicht zur Trainerbibliothek. Synthetische Tests sind kein Ingame-Ersatz.

Die Ingame-Prüfungen verwenden separate kurzlebige Kandidaten. Bereits geladene
Bibliotheken nicht überschreiben; laufende Spiele niemals für einen Build beenden.
