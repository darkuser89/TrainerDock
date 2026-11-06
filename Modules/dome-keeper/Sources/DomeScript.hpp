// SPDX-License-Identifier: GPL-3.0-only
// Own in-process script. Calls the installed game's native Godot objects;
// no original scripts, resource packs, saves or executables are replaced.
static const char *DKScriptSource=R"MHTGD(
extends RefCounted
var entries = {}
var identity = ""
var data_node
var keeper
var dome
var team = ""
var player = ""
var speed_base = -1.0
var speed_last = -1.0
var mouse_base = -1
var mouse_last = -1

func _init():
    var tree = Engine.get_main_loop()
    if tree is SceneTree:
        tree.process_frame.connect(_on_frame)

func _on_frame():
    if entries.is_empty() and speed_base < 0.0 and mouse_base < 0:
        return
    var state = JSON.parse_string(inspect())
    if not state is Dictionary or int(state.get("kind", 0)) != 2:
        release()

func _root():
    var tree = Engine.get_main_loop()
    return tree.root if tree is SceneTree else null

func inspect() -> String:
    var root = _root()
    var result = {"kind": 0, "identity": "unavailable", "note": "Warte auf Godot-Spielkontext."}
    if root == null:
        return JSON.stringify(result)
    var level = root.get_node_or_null("Level")
    var world = root.get_node_or_null("GameWorld")
    var keepers = root.get_node_or_null("Keepers")
    var data = root.get_node_or_null("Data")
    if not is_instance_valid(level) or not is_instance_valid(world) or not is_instance_valid(keepers) or not is_instance_valid(data):
        return JSON.stringify(result)
    if not is_instance_valid(level.stage) or not is_instance_valid(level.map) or not level.stage.is_level_built or world.gameover:
        return JSON.stringify({"kind": 1, "identity": "loading", "note": "Warte auf einen laufenden lokalen Einzelspieler-Lauf."})
    var local = keepers.local.getAll()
    if local.size() != 1:
        return JSON.stringify({"kind": 1, "identity": "local-owner", "note": "Genau eine eindeutig zugeordnete lokale Spielfigur erforderlich."})
    var manager = root.get_node_or_null("StageManager")
    if world.paused or (is_instance_valid(manager) and is_instance_valid(manager.currentStage) and manager.currentStage.stage_ending):
        return JSON.stringify({"kind": 1, "identity": "pause", "note": "Spielpause: eigene Dauereffekte gelöst; Auswahl bleibt erhalten."})
    var current = local[0]
    if not is_instance_valid(current) or not current.initialized or current.killed or not current.is_multiplayer_authority():
        return JSON.stringify({"kind": 1, "identity": "player", "note": "Lokale Spielfigur ist noch nicht bereit."})
    var current_dome = level.getDome(str(current.teamId))
    if not is_instance_valid(current_dome):
        return JSON.stringify({"kind": 1, "identity": "dome", "note": "Warte auf die lokale Kuppel."})
    var new_identity = "%s:%s:%s:%s:%s" % [level.stage.get_instance_id(), level.map.get_instance_id(), current.get_instance_id(), current_dome.get_instance_id(), world.loadCount]
    identity = new_identity
    data_node = data
    keeper = current
    dome = current_dome
    team = str(current.teamId)
    player = str(current.playerId)
    return JSON.stringify({"kind": 2, "identity": identity, "note": "Dome Keeper 5.0.8.14 · lokaler Einzelspieler."})

func _valid() -> bool:
    var state = JSON.parse_string(inspect())
    return state is Dictionary and int(state.get("kind", 0)) == 2

func _same_owner(record) -> bool:
    # Cleanup is permitted after a mode transition, but only for the same live
    # world and original local owner. Never restore keys into a replacement run.
    var root = _root()
    if root == null or not is_instance_valid(data_node) or root.get_node_or_null("Data") != data_node:
        return false
    var level = root.get_node_or_null("Level")
    var world = root.get_node_or_null("GameWorld")
    var keepers = root.get_node_or_null("Keepers")
    if not is_instance_valid(level) or not is_instance_valid(world) or not is_instance_valid(keepers):
        return false
    if not is_instance_valid(level.stage) or not is_instance_valid(level.map):
        return false
    for current in keepers.local.getAll():
        if not is_instance_valid(current):
            continue
        var current_dome = level.getDome(str(current.teamId))
        if not is_instance_valid(current_dome):
            continue
        var current_id = "%s:%s:%s:%s:%s" % [level.stage.get_instance_id(), level.map.get_instance_id(), current.get_instance_id(), current_dome.get_instance_id(), world.loadCount]
        if current_id == record.context:
            return true
    return false

func release_feature(feature: int) -> bool:
    if not entries.has(feature):
        return true
    var record = entries[feature]
    entries.erase(feature)
    if not _same_owner(record):
        return true
    var current = float(data_node.ofOr(record.key, NAN))
    if not is_finite(current):
        entries[feature] = record
        return false
    var restore = float(record.base)
    if record.transient:
        # Countdown consumption is expected. Preserve a larger outside buff.
        if current > record.last + 0.01:
            return true
        restore = maxf(0.0, restore - float(Time.get_ticks_msec() - record.started) / 1000.0)
    elif not is_equal_approx(current, record.last):
        return true
    data_node.apply(record.key, restore)
    var confirmed = is_equal_approx(float(data_node.ofOr(record.key, NAN)), restore)
    if not confirmed:
        entries[feature] = record
    return confirmed

func release():
    for feature in entries.keys():
        release_feature(int(feature))
    # Global settings must also be released on a scene/owner transition.
    if speed_base >= 0.0 and is_equal_approx(Engine.time_scale, speed_last):
        Engine.time_scale = speed_base
    speed_base = -1.0
    speed_last = -1.0
    if mouse_base >= 0 and Input.mouse_mode == mouse_last:
        Input.mouse_mode = mouse_base
    mouse_base = -1
    mouse_last = -1

func _set_property(feature: int, key: String, target: float, transient: bool = false) -> bool:
    if not _valid():
        return false
    # The native damage routine reads invulnerabletime with a zero default;
    # this transient field is not necessarily present until the first hit.
    if not data_node.has(key) and feature != 5:
        return false
    var current = data_node.ofOr(key, 0.0)
    if not (current is int or current is float) or not is_finite(float(current)):
        return false
    if entries.has(feature) and (entries[feature].context != identity or entries[feature].key != key):
        release_feature(feature)
    if not entries.has(feature):
        entries[feature] = {"context": identity, "key": key, "base": float(current), "last": float(current), "transient": transient, "started": Time.get_ticks_msec()}
    var record = entries[feature]
    if not transient and not is_equal_approx(float(current), record.last):
        # An upgrade changed the underlying property. Preserve that new baseline.
        record.base = float(current)
    var wanted = maxf(float(current), target) if transient else target
    if not is_equal_approx(float(current), wanted):
        data_node.apply(key, wanted)
    record.last = wanted
    return is_equal_approx(float(data_node.of(key)), wanted)

func effect(feature: int, wanted: bool, value: float) -> String:
    var result = {"available": false, "active": false, "note": "Im aktuellen Spielkontext nicht verfügbar."}
    if not _valid():
        return JSON.stringify(result)
    if feature in [1, 2, 3]:
        result.available = data_node.has(team + ".inventory." + ["iron", "water", "sand"][feature - 1])
        result.note = "Einmalaktion. Kann vom Spiel im Lauf gespeichert werden."
        return JSON.stringify(result)
    if not wanted:
        var restored = release_feature(feature)
        if feature == 9 and speed_base >= 0.0:
            if is_equal_approx(Engine.time_scale, speed_last):
                Engine.time_scale = speed_base
                restored = is_equal_approx(Engine.time_scale, speed_base)
            if restored:
                speed_base = -1.0
                speed_last = -1.0
        result.available = _available(feature)
        result.note = "Aus · Rücknahme bestätigt." if restored else "Rücknahme noch nicht bestätigt; erneuter Versuch folgt."
        return JSON.stringify(result)
    if not _available(feature):
        return JSON.stringify(result)
    result.available = true
    var ok = false
    match feature:
        0:
            ok = _set_property(feature, player + ".keeper1.speedlosspercarry", 0.0)
        4:
            var cap = float(data_node.of(team + ".shield.maxstrength"))
            ok = cap > 0.0 and _set_property(feature, team + ".shield.strength", cap)
        5:
            ok = _set_property(feature, team + ".dome.invulnerabletime", 2.0, true)
        6:
            ok = _set_property(feature, team + ".laser.dpsmod", 1000.0)
        7:
            ok = _set_property(feature, player + ".keeper1.drillstrength", 100000.0)
        8:
            ok = _set_property(feature, team + ".monsters.wavedelay", 2.0, true)
        9:
            if is_finite(value) and value >= 0.25 and value <= 4.0:
                if speed_base < 0.0:
                    speed_base = Engine.time_scale
                Engine.time_scale = value
                speed_last = value
                ok = is_equal_approx(Engine.time_scale, value)
    result.active = ok
    result.note = "Nativ bestätigt." if ok else "Native Rückleseprüfung fehlgeschlagen."
    return JSON.stringify(result)

func _available(feature: int) -> bool:
    match feature:
        0:
            return str(keeper.techId) == "keeper1" and data_node.has(player + ".keeper1.speedlosspercarry")
        4:
            return data_node.has(team + ".shield.strength") and float(data_node.ofOr(team + ".shield.maxstrength", 0)) > 0.0
        5:
            return data_node.has(team + ".dome.health") and data_node.has(team + ".dome.maxhealth")
        6:
            return str(dome.primaryWeapon) == "laser" and data_node.has(team + ".laser.dpsmod")
        7:
            return str(keeper.techId) == "keeper1" and data_node.has(player + ".keeper1.drillstrength")
        8:
            return data_node.has(team + ".monsters.wavedelay")
        9:
            return true
    return false

func one_shot(feature: int, value: float) -> String:
    if not _valid() or not feature in [1, 2, 3] or not is_finite(value) or value < 0 or value > 1000000 or floor(value) != value:
        return "Aktion verworfen: ungültiger Kontext oder Wert."
    var key = team + ".inventory." + ["iron", "water", "sand"][feature - 1]
    if not data_node.has(key):
        return "Rohstoff ist in diesem Lauf nicht verfügbar."
    data_node.apply(key, int(value))
    return "Rohstoffwert nativ bestätigt." if int(data_node.of(key)) == int(value) else "Keine native Bestätigung."

func mouse(enabled: bool) -> bool:
    if not _valid():
        if mouse_base >= 0 and Input.mouse_mode == mouse_last:
            Input.mouse_mode = mouse_base
        mouse_base = -1
        mouse_last = -1
        return false
    if enabled:
        if mouse_base < 0:
            mouse_base = Input.mouse_mode
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        mouse_last = Input.MOUSE_MODE_VISIBLE
        return Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
    if mouse_base >= 0 and Input.mouse_mode == mouse_last:
        Input.mouse_mode = mouse_base
    mouse_base = -1
    mouse_last = -1
    return false
)MHTGD";
