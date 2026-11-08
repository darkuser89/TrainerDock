# The Long Dark – Modulregeln

Es gelten die projektweite AGENTS.md, der Modulvertrag und die Hinweise in README.md.
Dieses Modul ist ein echter nativer Trainer mit 44 freigegebenen Funktionen.
Prüfumfang und ausdrücklich fehlende Ende-zu-Ende-Prüfungen stehen in README.md.
Keine simulierten Wirkungen oder vorgetäuschten Erfolge. Neue Builds und ungeprüfte
Funktionen nicht kosmetisch freigeben.

- Vollständige IL2CPP-/Unity-Anbindung und Overlay bleiben hier; keine Spiellogik im Host.
- Nur exakter Steam-Build 26450964 bzw. Epic-Build Mac_181032_321 gemäß Profil.
  Epic 2.55 verwendet eine gültige originale arm64-Signatur und vollständige
  Dateihashes; die Steam-Signaturausnahme nicht übernehmen. Profilkennung und
  Hauptdatei-/GameAssembly-/UnityPlayer-UUID müssen als Store-Tupel zusammenpassen.
  Epic-Ingame-Nachweise sind noch offen; der Nutzer übernimmt diese Prüfung.
- Gameplay nur im bestätigten Original-Unity-Rückruf; lokale Besitzer und Ladezustand prüfen.
- Typisierte Referenzsetter und Werttypenlisten-Verträge gemäß NativeContractTests erhalten.
- Unten rechts MHTGlassSlider und persistentes glassIntensity 0…1 erhalten.
- Spielstarts und reguläres Beenden nur mit passendem Nutzerauftrag; Prüfungen bündeln.
- Keine geladenen Testbibliotheken überschreiben, keine Doppelstarts und keine Savebearbeitung.
- Tests und synthetische Fixtures ausschließlich unter Tests; Builds extern, keine Logs hier.
- Waffenaktion nur bewusst einmal ausführen; sie fügt bei Wiederholung erneut Gegenstände hinzu.
- `SaveGuard` nur für originale Pfade des aktuellen Laufs scharfstellen. Keine breiten
  Verzeichnisfilter, Savekopien, Savebyte-Änderungen oder dauerhafte Löschsperren.
- Originale Löschfixture ist kein echter Spielertod; native Schadensrücklesung und
  geprüfter Projektilpfad sind kein gezielter Tierabschuss. Diese Grenzen benennen.
