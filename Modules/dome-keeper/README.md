# Dome Keeper · Steam

Eigenständiger Trainer für **5.0.8.14**, Steam-Build **25038893**, natives arm64.
Bundle-Version: 1.0.0. Ein Universal-Binary wird über seine originale arm64-Slice
geprüft. Andere Spielupdates und Stores sind nicht automatisch unterstützt.

| Kürzel | Funktion |
|---|---|
| F1 | Keine Trageverlangsamung (Techniker/Ingenieur) |
| F2 | Eisen einmalig setzen |
| F3 | Wasser einmalig setzen |
| F4 | Kobalt einmalig setzen |
| F5 | Vorhandenen Schild laufend auffüllen |
| F6 | Native Schadensschutzzeit der lokalen Kuppel halten |
| F7 | Laserschadensfaktor 1000 |
| F8 | Bohrstärke 100000 (Techniker/Ingenieur) |
| F9 | Neue Wellen durch native Wellenverzögerung anhalten |
| F10 | Spieltempo 0,25–4× |

⌘ ^ öffnet das Ingame-Overlay samt Mausbedienung; ⇧ F9 schaltet alles aus.
Funktionen stehen nur im passenden lokalen Einzelspielerkontext zur Verfügung.
Schild und Laser benötigen die passende Ausrüstung. Aktive Monster werden vom
Wellenstopp nicht entfernt. Einmalaktionen können vom Spiel normal gespeichert
werden und werden durch „Alles aus“ nicht rückgängig gemacht.

Das Modul erzeugt einen eigenen Godot-Scriptkontext über die originale native
C-Schnittstelle; Gameplay-Aufträge laufen in Godots MessageQueue. Die Original-
installation wird weder verändert noch neu signiert. Klassische Spielpausen lösen
Dauereffekte und erhalten die Auswahl für das Fortsetzen. Vor einem direkten
Speichern mit aktiven Modifikationen kann zusätzlich „Alles aus“ verwendet werden.

Entwicklung: `python3 -B script/build.py --module dome-keeper`.
Quellen zum ABI-Vertrag:
[Godot 4.3 C-Schnittstelle](https://github.com/godotengine/godot/blob/4.3/core/extension/gdextension_interface.h),
[Godot Callable.call_deferred](https://docs.godotengine.org/en/4.3/classes/class_callable.html#class-callable-method-call-deferred).
Synthetische Bridge-/HiDPI-/Prozessprüfungen bleiben von Ingame-Belegen getrennt.
