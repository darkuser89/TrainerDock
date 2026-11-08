# Weiterarbeit an Terraria

AGENTS.md, README.md und docs/OVERLAY_INPUT.md lesen; trainer-template und
Graphify offline verwenden. Dieses eigenständige Modul weiterentwickeln, keine
neue Vorlage erzeugen. Ausschließlich den exakt freigegebenen Steam-Build verwenden.

Zwölf native Anbindungen liegen in TerrariaBackend.mm; Mono.mm kapselt nur die
Original-C-API. Keine Managed-Assembly und keine ausführbaren Patches erforderlich.
GameProfile.m kompiliert den gemeinsamen Identitätsprüfer in dieses Modul ein.
Der Launcher kennt nur generische Profile und darf keine Terraria-Fallunterscheidung erhalten.

Prüfstatus und Funktionsgrenzen stehen im README. Nicht vollständig geprüfte
Situationen niemals als bestanden darstellen. Tests müssen außerhalb des Produkts
bleiben. Geladene Kandidaten nicht überschreiben; Spielstarts und Beenden nur im
Umfang des konkreten Nutzerauftrags, in einem Lauf bündeln.
