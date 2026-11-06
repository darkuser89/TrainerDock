# Balatro Trainer

Es gilt die AGENTS.md im Projektstamm und der Modulvertrag in docs/MODULES.md.

- Ausschließlich echte Wirkungen in der bestätigten originalen LuaJIT-Laufzeit.
  Spielquellen, Assets und synthetische Fixtures gehören nicht ins Produkt.
- Gameplay nur im registrierten LÖVE-Update-Rückruf. Lua-State niemals außerhalb
  des Engine-Rückrufs betreten. Native Warteschlange und Stackbalance erhalten.
- Exakte Originalidentität und vollständige Ressourcenhashes erhalten. Keine
  Signaturänderungen, Spielpatches, Savebearbeitung oder Freigabe unbekannter Builds.
- `Total Score` bezeichnet Rundenchips, `Round Score` das nächste Handergebnis.
  Einmalaktionen bleiben ausdrücklich und werden nie beim Start wiederholt.
- Native Besitzerprüfung, Ladepausen und Rücklesen erhalten. Keine Netzwerksperre einbauen.
  Punkte erst nach echter Schlusswertung als aktiv melden.
- LÖVE-Eingaben vor den ursprünglichen Spielhandlern behandeln; niemals Klicks doppelt an Trainer und Spiel geben.
  Glas und HiDPI bleiben in einem isolierten MHTOverlayHost, ohne Engine-Subviews.
- Testhilfen ausschließlich unter Tests/Balatro. Vor Ingame-Tests konkrete
  Nutzerfreigabe beachten. Keine Änderungen am allgemeinen Launcher nötig.
