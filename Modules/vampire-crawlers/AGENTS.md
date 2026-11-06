# Vampire Crawlers

Die zentrale `/Users/jbw/Documents/MHT/AGENTS.md` gilt uneingeschränkt.

- Nur echte native Trainerwirkungen. Keine simulierten Erfolge oder Testobjekte ins Produkt.
- `Pancake.dll`/IL2CPP ist die tatsächliche Spielanbindung; keine Mono-Assemblies,
  fremden Spieladressen oder Windows-Signaturen übernehmen.
- Nur der bestätigte originale Unity-PlayerLoop-Rückruf darf Spielwerte lesen oder ändern.
- Profil-/Szenen-/Laufwechsel, lokale Besitzer, Weak-Handles und Rücknahme eigener
  Baselines erhalten. Mehrdeutige lokale Besitzer bleiben ungültig; Netzwerkstatus
  allein darf keine Funktion sperren.
- Werteditoren sind Einmalaktionen. Keine automatische Ausführung beim Start,
  Polling, Laden oder erneuter Zustellung. Kontextwechsel und abgelaufene Befehle verwerfen.
- Die Ausnahme `sha256-original` ist vom Nutzer ausschließlich für Steam 1.6.1 (11),
  Build-ID 25304267, genehmigt. Vollständige erfasste Dateien, Versions- und UUID-Prüfung
  erhalten. Keine anderen Builds ohne neuen Auftrag freigeben oder Hashes still erneuern.
- Spielsignaturen, Entitlements, ausführbare Dateien und Saves bleiben unverändert.
  Die Originalinstallation darf ausschließlich über reguläre Spiel-APIs zur Laufzeit
  angesprochen werden; vom Spiel selbst gespeicherte Traineränderungen sind möglich.
- Tests und ihre Notification-Loader nie in `Build.json` oder Produktbibliotheken aufnehmen.
- Wenige Spielstarts, mehrere Prüfungen pro Instanz. Weitere Starts oder Beenden nur
  innerhalb der aktuellen Nutzerfreigabe; keine stillen Zweitinstanzen.
- Builds und aktuelle App unter `~/Library/Developer/TrainerDock`, temporäre Prüfdaten außerhalb
  von Code und Audit. Nur bestätigte Ingame-Wirkungen als solche dokumentieren.
