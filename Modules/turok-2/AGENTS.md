# Turok 2: Seeds of Evil – Modulregeln

Projektweite AGENTS.md, docs/MODULES.md und docs/OVERLAY_INPUT.md beachten.
Nur Steam-Build 20961743, Intel-UUID `AB442E80-6C9C-3FB0-9653-B349C088C250`, vollständige Originalhashes.
Die ausdrückliche Nutzerfreigabe betrifft nur diesen unsignierten Originalbuild.
Native Originale, Signaturen und Saves nicht ändern. Keine Netzwerksperre.

Vollständige x86_64-Runtime, Overlay und persistenter Glasregler gehören ins Modul.
Gemeinsame Entwicklungsquellen unter Modules/_Shared/Kex werden separat eingebaut;
jeder gebaute Trainer bleibt eigenständig. Keine Spiellogik im Launcher.
Gesundheit und Munition müssen die je Spiel belegten nativen Felder verwenden;
keine Offsets zwischen den Spielen übertragen. Alle sichtbaren Texte Deutsch.
Nur am bestätigten Originalrückruf arbeiten und die aktuelle lokale Besitzerkette
prüfen. Eigene Bits lösen, fremde Bits erhalten, Aktiv nur nach Rücklesen.
Spielstarts/-enden nur im Nutzerauftrag, keine Doppelstarts. Tests getrennt halten.
