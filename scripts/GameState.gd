## GameState — Global game state, character creation tracking, save/load via SaveManager
## Autoload singleton managing core persistent data.

extends Node

const ClassProgScript = preload("res://scripts/ClassProgression.gd")
const EncounterDiffScript = preload("res://scripts/EncounterDifficulty.gd")
const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")

# -- signals --
signal character_created(character_id: String, race_id: String, class_id: String, origin: String)
signal game_saved(slot_id: int)
signal game_loaded(slot_id: int, save_data: Dictionary)
signal active_scene_changed(scene_name: String)
signal last_save_slot_updated(slot_id: int)
signal class_level_up(new_level: int, levels_gained: int)
signal class_xp_gained(amount: int, total_xp: int)


# -- exported (configurable in editor / autoload) --

@export var active_scene: String = ""
@export var last_save_slot: int = 0
# Procedural graphics fallback — enabled by default (no external assets required)
var use_procedural_graphics: bool = true

# Runtime-only tracking (not persisted directly — SaveManager handles persistence)
var _character_data: Dictionary = {}
var _appearance_data: Dictionary = {}
var _equipment_data: Dictionary = {}
var _world_data: Dictionary = {}  # {seed: String, tile_map: Dictionary, start_tile: Dictionary}
var _start_tile: Dictionary = {}  # Chosen starting grid {q, r, biome, ...}
var _player_q: int = 0
var _player_r: int = 0
var _local_x: int = 256
var _local_y: int = 256
var _hex_states: Dictionary = {}       # "q,r" -> local map state + per-hex persistence
var _discovered_hexes: Array[String] = []
var _pending_rift: Dictionary = {}  # Active rift entry context for RiftInstance
var _pending_combat: Dictionary = {}  # Unified FFT combat encounter payload
var _overworld_mobs: Dictionary = {}  # "q,r|lx,ly" -> mob template/instance dict
var _world_npcs: Dictionary = {}      # npc_id -> procedural NPC instance
var _faction_rep: Dictionary = {}   # faction_key -> reputation int
var _recruited_npc_ids: Array[String] = []
var _mission_save: Dictionary = {}


func _ready() -> void:
	_character_data = {}
	_appearance_data = {}
	_equipment_data = {}
	print("[GameState] Initialized.")

	# Start autosave timer on SaveManager autoload
	var sm: Node = get_node_or_null("/root/SaveManager")
	if is_instance_valid(sm):
		sm.start_autosave_timer()
		sm.auto_save_triggered.connect(_on_autosave_tick)

func _on_autosave_tick() -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if not is_instance_valid(sm):
		return
	if _character_data.is_empty():
		return
	# Write full state to AUTOSAVE_SLOT via SaveManager
	var hex_out: Dictionary = {}
	for key in _hex_states:
		var s: Dictionary = (_hex_states[key] as Dictionary).duplicate(true)
		s.erase("terrain")
		hex_out[key] = s
	sm.full_autosave(
		_character_data.duplicate(true),
		_appearance_data.duplicate(true) if _appearance_data else {},
		_equipment_data.duplicate(true) if _equipment_data else {},
		_world_data.duplicate(true) if _world_data else {},
		{"q": _player_q, "r": _player_r, "local_x": _local_x, "local_y": _local_y},
		hex_out,
		_discovered_hexes.duplicate(),
		_overworld_mobs.duplicate(true) if _overworld_mobs else {},
		{},
		_world_npcs.duplicate(true) if _world_npcs else {},
		_faction_rep.duplicate(true) if _faction_rep else {},
		_recruited_npc_ids.duplicate(),
		_mission_save.duplicate(true) if _mission_save else {}
	)


# ===================================================================
# -- Character creation --
# ===================================================================

func create_character(race_id: String, class_id: String, origin: String, char_name: String = "", gender: String = "male") -> bool:
	if race_id.is_empty() or class_id.is_empty():
		push_error("[GameState] Cannot create character — missing race_id or class_id.")
		return false

	# Generate unique UUID using a simple hash-based approach (no Python uuid needed)
	var char_id := "char_" + _generate_unique_id()
	# Compute stats: race base + class mods (D&D style)
	var race_info: Dictionary = _get_race_base_stats(race_id)
	var class_mods: Dictionary = _get_class_stat_mods(class_id)
	var final_stats: Dictionary = {}
	for stat in ["str", "dex", "con", "int", "wis", "cha"]:
		var base: int = race_info.get(stat, 10) as int
		var mod: int = class_mods.get(stat, 0) as int
		final_stats[stat] = base + mod

	var display_name: String = char_name.strip_edges() if not char_name.is_empty() else "Unnamed %s" % race_id

	# Store gender in appearance data for downstream renderers
	_appearance_data["gender"] = gender

	var cm: ClassManager = get_node_or_null("/root/ClassManager") as ClassManager
	var max_hp: int = 80 + int(final_stats.get("con", 10)) * 5
	if is_instance_valid(cm):
		max_hp = cm.get_max_hp_at_level(class_id, 1, int(final_stats.get("con", 10)))

	_character_data = {
		"id": char_id,
		"name": display_name,
		"race": race_id,
		"class": class_id,
		"origin": origin,
		"level": 1,
		"xp": 0,
		"stats": final_stats,
		"health": max_hp,
		"max_health": max_hp,
		"inventory": [],
		"appearance": _appearance_data.duplicate() if not _appearance_data.is_empty() else {},
		"equipment": _equipment_data.duplicate() if not _equipment_data.is_empty() else {}
	}

	character_created.emit(char_id, race_id, class_id, origin)
	print("[GameState] Character created: %s '%s' (race=%s, class=%s, origin=%s)" % [char_id, display_name, race_id, class_id, origin])
	return true


func get_character_data() -> Dictionary:
	# Return a clean copy so callers can't mutate internal state
	return _character_data.duplicate(true) if not _character_data.is_empty() else {}


func set_character_health(health: int) -> void:
	if _character_data.is_empty():
		return
	var max_hp: int = int(_character_data.get("max_health", _character_data.get("health", 100)))
	_character_data["health"] = clampi(health, 0, max_hp)


func get_class_level() -> int:
	return int(_character_data.get("level", 1))


func get_party_average_level() -> int:
	return EncounterDiffScript.party_average_level(get_party_character_data()) if not _character_data.is_empty() else 1


## Character data merged with recruited companions for party-level scaling.
func get_party_character_data() -> Dictionary:
	if _character_data.is_empty():
		return {}
	var out: Dictionary = _character_data.duplicate(true)
	sync_party_companions()
	out["companions"] = _character_data.get("companions", [])
	return out


func sync_party_companions() -> void:
	if _character_data.is_empty():
		return
	var nm: NPCManager = get_node_or_null("/root/NPCManager") as NPCManager
	if not is_instance_valid(nm) or not nm.has_method("get_recruited_npcs"):
		return
	var companions: Array[Dictionary] = []
	for npc in nm.get_recruited_npcs():
		if not npc is Dictionary:
			continue
		var n: Dictionary = npc as Dictionary
		companions.append({
			"id": str(n.get("id", "")),
			"name": str(n.get("name", "?")),
			"level": int(n.get("level", 1)),
			"class": str(n.get("class", "?")),
			"race": str(n.get("race", "?")),
		})
	_character_data["companions"] = companions


func add_inventory_items(items: Array) -> void:
	if _character_data.is_empty() or items.is_empty():
		return
	var inv: Array = _character_data.get("inventory", []) as Array
	for item in items:
		if item is Dictionary:
			inv.append((item as Dictionary).duplicate(true))
	_character_data["inventory"] = inv


func get_class_xp() -> int:
	return int(_character_data.get("xp", 0))


func grant_class_xp(amount: int) -> Dictionary:
	if _character_data.is_empty() or amount <= 0:
		return {"levels_gained": 0, "level": get_class_level(), "xp": get_class_xp()}

	var before_level: int = int(_character_data.get("level", 1))
	var before_xp: int = int(_character_data.get("xp", 0))
	var result: Dictionary = ClassProgScript.apply_xp(before_level, before_xp, amount)
	var after_level: int = int(result.get("level", before_level))
	var after_xp: int = int(result.get("xp", before_xp))
	var gained: int = int(result.get("levels_gained", 0))

	_character_data["level"] = after_level
	_character_data["xp"] = after_xp
	class_xp_gained.emit(amount, after_xp)

	if gained > 0:
		_recalculate_character_from_level(gained)
		class_level_up.emit(after_level, gained)
		print("[GameState] Level up! Now Lv.%d (+%d)" % [after_level, gained])

	return {"levels_gained": gained, "level": after_level, "xp": after_xp, "xp_granted": amount}


func _recalculate_character_from_level(levels_gained: int = 0) -> void:
	if _character_data.is_empty():
		return
	var cm: ClassManager = get_node_or_null("/root/ClassManager") as ClassManager
	if not is_instance_valid(cm):
		return

	var class_id: String = str(_character_data.get("class", "Survivor"))
	var level: int = int(_character_data.get("level", 1))
	var race_id: String = str(_character_data.get("race", "Human"))

	var race_info: Dictionary = _get_race_base_stats(race_id)
	var class_mods: Dictionary = _get_class_stat_mods(class_id)
	var base_stats: Dictionary = {}
	for stat in ["str", "dex", "con", "int", "wis", "cha"]:
		base_stats[stat] = int(race_info.get(stat, 10)) + int(class_mods.get(stat, 0))

	var scaled: Dictionary = cm.get_stats_at_level(class_id, level, base_stats)
	_character_data["stats"] = scaled

	var con: int = int(scaled.get("con", 10))
	var new_max: int = cm.get_max_hp_at_level(class_id, level, con)
	var cur_hp: int = int(_character_data.get("health", new_max))

	_character_data["max_health"] = new_max
	var heal_bonus: int = int(new_max * 0.15) * maxi(0, levels_gained)
	_character_data["health"] = mini(new_max, cur_hp + heal_bonus)


## Replace appearance data that will be baked into the character
func set_appearance_data(appearance: Dictionary) -> void:
	if appearance is Dictionary:
		_appearance_data = appearance.duplicate(true)
		print("[GameState] Appearance data updated (%d keys)." % _appearance_data.size())
	else:
		push_error("[GameState] set_appearance_data() requires a Dictionary.")


func set_equipment_data(equipment: Dictionary) -> void:
	if equipment is Dictionary:
		_equipment_data = equipment.duplicate(true)
	else:
		push_error("[GameState] set_equipment_data() requires a Dictionary.")


# ===================================================================
# -- Save / Load (delegates to SaveManager via autoload) --
# ===================================================================

func save_game(slot_id: int, character_data: Dictionary = {}) -> bool:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if not is_instance_valid(sm):
		push_error("[GameState] SaveManager autoload not found.")
		return false

	var data: Dictionary = {}
	if not character_data.is_empty():
		data["character"] = character_data.duplicate()
	else:
		data["character"] = _character_data.duplicate(true)

	data["appearance"] = _appearance_data
	data["equipment"] = _equipment_data
	data["game_state"] = {
		"active_scene": active_scene,
		"save_slot": slot_id,
	}
	data["world_data"] = _world_data.duplicate(true) if not _world_data.is_empty() else {}
	data["player_position"] = {"q": _player_q, "r": _player_r, "local_x": _local_x, "local_y": _local_y}
	data["hex_states"] = _serialize_hex_states_for_save()
	data["discovered_hexes"] = _discovered_hexes.duplicate()
	data["overworld_mobs"] = _overworld_mobs.duplicate(true) if not _overworld_mobs.is_empty() else {}
	var runner: Node = get_node_or_null("/root/RiftRunner")
	if is_instance_valid(runner) and runner.has_method("get_save_payload"):
		data["rift_state"] = runner.get_save_payload()
	data["world_npcs"] = _world_npcs.duplicate(true) if not _world_npcs.is_empty() else {}
	data["faction_rep"] = _faction_rep.duplicate(true) if not _faction_rep.is_empty() else {}
	data["recruited_npc_ids"] = _recruited_npc_ids.duplicate()
	var mm: MissionManager = get_node_or_null("/root/MissionManager") as MissionManager
	if is_instance_valid(mm) and mm.has_method("get_save_payload"):
		data["missions"] = mm.get_save_payload()
	elif not _mission_save.is_empty():
		data["missions"] = _mission_save.duplicate(true)
	data["version"] = "0.2.0"

	# Phase 8: include manager snapshots (inventory, progression, party, equipment, base, base_shops)
	sm.populate_payload_with_managers(data)

	var slot_name := "Slot%d" % slot_id
	var success: bool = sm.save_to_game_file(data, slot_id, slot_name)
	if success:
		last_save_slot_updated.emit(slot_id)
		game_saved.emit(slot_id)
	else:
		push_error("[GameState] Failed to save game to slot %d." % slot_id)
	return success


func load_game(slot_id: int) -> bool:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if not is_instance_valid(sm):
		push_error("[GameState] SaveManager autoload not found.")
		return false

	var data: Dictionary = sm.load_from_slot(slot_id)
	if data.is_empty():
		push_warning("[GameState] No save file in slot %d." % slot_id)
		return false

	# Robust extraction: support new canonical top-level + old wrapped "game_state" shapes
	var char_src = data.get("character", {})
	if (not char_src is Dictionary) or char_src.is_empty():
		char_src = data.get("game_state", {}).get("character", {}) if data.get("game_state") is Dictionary else {}
	_character_data = char_src.duplicate(true) if char_src is Dictionary and not char_src.is_empty() else {}
	_migrate_character_level_fields()

	var app_src = data.get("appearance", {})
	if (not app_src is Dictionary) or app_src.is_empty():
		app_src = data.get("game_state", {}).get("appearance", {}) if data.get("game_state") is Dictionary else {}
	_appearance_data = app_src.duplicate(true) if app_src is Dictionary else {}

	var equip_src = data.get("equipment", {})
	if (not equip_src is Dictionary) or equip_src.is_empty():
		equip_src = data.get("game_state", {}).get("equipment", {}) if data.get("game_state") is Dictionary else {}
	_equipment_data = equip_src.duplicate(true) if equip_src is Dictionary else {}

	var gs_part = data.get("game_state", {})
	if gs_part is Dictionary:
		active_scene = gs_part.get("active_scene", active_scene)
	else:
		active_scene = data.get("active_scene", active_scene)

	var wd = data.get("world_data", {})
	if wd is Dictionary and not wd.is_empty():
		_world_data = wd.duplicate(true)
		var st = _world_data.get("start_tile", {})
		if st is Dictionary and not st.is_empty():
			_start_tile = st.duplicate(true)

	var pp = data.get("player_position", {})
	if pp is Dictionary and pp.has("q") and pp.has("r"):
		_player_q = int(pp["q"])
		_player_r = int(pp["r"])
		_local_x = int(pp.get("local_x", 256))
		_local_y = int(pp.get("local_y", 256))
	elif not _start_tile.is_empty():
		var key: String = str(_start_tile.get("key", "0,0"))
		var parts := key.split(",")
		if parts.size() >= 2:
			_player_q = int(parts[0])
			_player_r = int(parts[1])

	_hex_states = _deserialize_hex_states_from_save(data.get("hex_states", {}))
	_discovered_hexes = []
	var disc_src = data.get("discovered_hexes", [])
	if disc_src is Array:
		for hk in disc_src:
			_discovered_hexes.append(str(hk))

	var mob_src = data.get("overworld_mobs", {})
	_overworld_mobs = mob_src.duplicate(true) if mob_src is Dictionary else {}

	var rift_src = data.get("rift_state", {})
	var runner: Node = get_node_or_null("/root/RiftRunner")
	if is_instance_valid(runner) and runner.has_method("load_from_save") and rift_src is Dictionary:
		runner.load_from_save(rift_src)

	var npc_src = data.get("world_npcs", {})
	_world_npcs = npc_src.duplicate(true) if npc_src is Dictionary else {}
	var rep_src = data.get("faction_rep", {})
	_faction_rep = rep_src.duplicate(true) if rep_src is Dictionary else {}
	_recruited_npc_ids = []
	var recruited_src = data.get("recruited_npc_ids", [])
	if recruited_src is Array:
		for rid in recruited_src:
			_recruited_npc_ids.append(str(rid))

	var nm: NPCManager = get_node_or_null("/root/NPCManager") as NPCManager
	if is_instance_valid(nm):
		nm.load_from_save(_world_npcs, _faction_rep, _recruited_npc_ids)

	var mission_src = data.get("missions", {})
	_mission_save = mission_src.duplicate(true) if mission_src is Dictionary else {}
	var mm: MissionManager = get_node_or_null("/root/MissionManager") as MissionManager
	if is_instance_valid(mm) and mm.has_method("load_from_save") and _mission_save is Dictionary:
		mm.load_from_save(
			_mission_save.get("active", {}),
			_mission_save.get("offered", {}),
			_mission_save.get("completed_ids", []),
			_mission_save.get("npc_offers", {}),
			int(_mission_save.get("counter", 0))
		)
	sync_party_companions()

	# Phase 8: restore manager state (inventory, progression, party, equipment, base, base_shops)
	sm.apply_managers_from_payload(data)

	game_loaded.emit(slot_id, data)
	last_save_slot_updated.emit(slot_id)
	return true


## Autosave — called by SaveManager's autosave timer signal.
func auto_save() -> bool:
	return save_game(last_save_slot)


## Internal callback from SaveManager.auto_save_triggered.
func _autosave_tick_handler() -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if not is_instance_valid(sm):
		return
	if _character_data.is_empty():
		return
	# Write full state to AUTOSAVE_SLOT via SaveManager
	var hex_out: Dictionary = {}
	for key in _hex_states:
		var s: Dictionary = (_hex_states[key] as Dictionary).duplicate(true)
		s.erase("terrain")
		hex_out[key] = s
	sm.full_autosave(
		_character_data.duplicate(true),
		_appearance_data.duplicate(true) if _appearance_data else {},
		_equipment_data.duplicate(true) if _equipment_data else {},
		_world_data.duplicate(true) if _world_data else {},
		{"q": _player_q, "r": _player_r, "local_x": _local_x, "local_y": _local_y},
		hex_out,
		_discovered_hexes.duplicate(),
		_overworld_mobs.duplicate(true) if _overworld_mobs else {},
		{},
		_world_npcs.duplicate(true) if _world_npcs else {},
		_faction_rep.duplicate(true) if _faction_rep else {},
		_recruited_npc_ids.duplicate(),
		_mission_save.duplicate(true) if _mission_save else {}
	)


# ===================================================================
# -- Scene management --
# ===================================================================

func change_scene(scene_name: String) -> void:
	active_scene = scene_name
	print("[GameState] Active scene changed to: %s" % scene_name)
	active_scene_changed.emit(scene_name)


## Reset all tracking state (e.g. after game start / fresh session)
func reset_session() -> void:
	_character_data = {}
	_appearance_data = {}
	_equipment_data = {}
	_world_data = {}
	_start_tile = {}
	_local_x = 256
	_local_y = 256
	_hex_states = {}
	_discovered_hexes = []
	_overworld_mobs = {}
	_world_npcs = {}
	_faction_rep = {}
	_recruited_npc_ids = []
	_mission_save = {}
	active_scene = ""
	var nm: NPCManager = get_node_or_null("/root/NPCManager") as NPCManager
	if is_instance_valid(nm):
		nm.reset_for_new_game()
	var mm: MissionManager = get_node_or_null("/root/MissionManager") as MissionManager
	if is_instance_valid(mm) and mm.has_method("reset_for_new_game"):
		mm.reset_for_new_game()
	var runner: Node = get_node_or_null("/root/RiftRunner")
	if is_instance_valid(runner) and runner.has_method("reset_for_new_game"):
		runner.reset_for_new_game()
	print("[GameState] Session reset.")


# ===================================================================
# -- Utilities (native GDScript UUID-like id generator) --
# ===================================================================

var _last_id_counter := int(Time.get_ticks_msec())

func _generate_unique_id() -> String:
	_last_id_counter += 1
	return "c%d_%d" % [_last_id_counter, Time.get_unix_time_from_system()]


func _migrate_character_level_fields() -> void:
	if _character_data.is_empty():
		return
	if not _character_data.has("level"):
		_character_data["level"] = 1
	if not _character_data.has("xp"):
		_character_data["xp"] = 0
	if not _character_data.has("max_health"):
		_character_data["max_health"] = int(_character_data.get("health", 100))
	var lvl: int = int(_character_data.get("level", 1))
	if lvl >= 1:
		_recalculate_character_from_level(0)


# ===================================================================
# -- Stat helpers (D&D style) --
# ===================================================================

func _get_race_base_stats(race_id: String) -> Dictionary:
	var rm: RaceManager = get_node("/root/RaceManager") if has_node("/root/RaceManager") else null
	if not is_instance_valid(rm):
		# fallback low bases
		return {"str": 10, "dex": 10, "con": 10, "int": 10, "wis": 10, "cha": 10}
	var races: Dictionary = rm.get_all_races()
	for origin in races:
		var origin_list: Array = races[origin] as Array
		for race: Dictionary in origin_list:
			if race.get("id") == race_id or race.get("name") == race_id:
				return race.get("base_stats", {})
	return {"str": 10, "dex": 10, "con": 10, "int": 10, "wis": 10, "cha": 10}


func _get_class_stat_mods(class_id: String) -> Dictionary:
	var cm: ClassManager = get_node("/root/ClassManager") if has_node("/root/ClassManager") else null
	if not is_instance_valid(cm):
		return {}
	var cls_data: Dictionary = cm.get_all_classes().get(class_id, {}) as Dictionary
	return cls_data.get("stat_mods", {})

# -- World data (generated before character selection) --

func set_world_data(seed_string: String, tile_map: Dictionary) -> void:
	_world_data = {
		"seed": seed_string,
		"tile_map": tile_map.duplicate(true),
		"generated_at": Time.get_unix_time_from_system()
	}
	print("[GameState] World data stored for seed: ", seed_string)

func set_start_tile(tile_key: String, tile_data: Dictionary) -> void:
	_start_tile = tile_data.duplicate(true)
	_start_tile["key"] = tile_key
	_world_data["start_tile"] = _start_tile
	var parts := tile_key.split(",")
	if parts.size() >= 2:
		_player_q = int(parts[0])
		_player_r = int(parts[1])
	_local_x = int(LocalMapGen.MAP_SIZE / 2.0)
	_local_y = int(LocalMapGen.MAP_SIZE / 2.0)
	discover_hex(_player_q, _player_r)
	ensure_hex_state(_player_q, _player_r)
	print("[GameState] Starting grid chosen: ", tile_key, " biome: ", tile_data.get("name", "?"))

func get_start_tile() -> Dictionary:
	return _start_tile.duplicate(true) if not _start_tile.is_empty() else {}

func get_world_data() -> Dictionary:
	return _world_data.duplicate(true) if not _world_data.is_empty() else {}

func has_world() -> bool:
	return not _world_data.is_empty()

func get_tile_map() -> Dictionary:
	if _world_data.has("tile_map") and _world_data["tile_map"] is Dictionary:
		return (_world_data["tile_map"] as Dictionary).duplicate(true)
	return {}

func get_player_position() -> Vector2i:
	return Vector2i(_player_q, _player_r)

func set_player_position(q: int, r: int) -> void:
	_player_q = q
	_player_r = r


func get_local_position() -> Vector2i:
	return Vector2i(_local_x, _local_y)


func set_local_position(x: int, y: int) -> void:
	_local_x = clampi(x, 0, LocalMapGen.MAP_SIZE - 1)
	_local_y = clampi(y, 0, LocalMapGen.MAP_SIZE - 1)


func discover_hex(q: int, r: int) -> void:
	var key := LocalMapGen.hex_key(q, r)
	if key not in _discovered_hexes:
		_discovered_hexes.append(key)


func is_hex_discovered(q: int, r: int) -> bool:
	return LocalMapGen.hex_key(q, r) in _discovered_hexes


func get_discovered_hexes() -> Array[String]:
	return _discovered_hexes.duplicate()


func ensure_hex_state(q: int, r: int) -> Dictionary:
	# v0.9.1c: shallow copy. The deep copy was costing 25+ ms per
	# move when called via get_current_hex_state. Callers don't
	# mutate the returned dict in place (HubWorld._mark_explored
	# writes explored_pct then immediately saves, not holding the
	# reference long-term).
	var key := LocalMapGen.hex_key(q, r)
	if _hex_states.has(key):
		return (_hex_states[key] as Dictionary).duplicate(false)

	var tile: Dictionary = get_tile_map().get(key, {})
	if tile.is_empty():
		tile = {"name": "Ash Wastes", "q": q, "r": r}

	var seed_str: String = str(get_world_data().get("seed", "fallback"))
	var generated: Dictionary = LocalMapGen.generate(seed_str, q, r, tile)
	generated["visited"] = true
	_hex_states[key] = generated
	discover_hex(q, r)
	return generated.duplicate(false)


## v0.9.1c: Returns a SHALLOW copy of the hex state. The old
## `duplicate(true)` was costing ~25ms per move because each hex
## state has 262k bytes of terrain (PackedByteArray) plus 5714
## dicts in resource_nodes / floor_pickups, all of which were
## being deep-copied on every read. Callers (HubWorld._mark_explored
## etc.) only modify top-level keys (explored_pct, visited), so a
## shallow copy is safe. The PackedByteArray terrain is immutable
## in practice (set once at generation, read-only thereafter), and
## the resource/pickup dicts are never mutated by callers — if they
## were, that's a bug to fix at the source, not paper over with
## deep copies.
func get_hex_state(q: int, r: int) -> Dictionary:
	var key := LocalMapGen.hex_key(q, r)
	if _hex_states.has(key):
		return (_hex_states[key] as Dictionary).duplicate(false)
	return {}


func get_current_hex_state() -> Dictionary:
	return get_hex_state(_player_q, _player_r)


func save_hex_state(q: int, r: int, state: Dictionary) -> void:
	if state.is_empty():
		return
	var key := LocalMapGen.hex_key(q, r)
	# v0.9.1c: shallow store. The old `duplicate(true)` was costing
	# ~10ms per move because the hex state has 262k bytes of terrain
	# + 5714 nested dicts. Callers don't mutate the stored dict
	# after saving (HubWorld._mark_explored immediately discards its
	# local reference), so a shallow store is safe.
	_hex_states[key] = state


func _serialize_hex_states_for_save() -> Dictionary:
	var out: Dictionary = {}
	for key in _hex_states:
		var state: Dictionary = (_hex_states[key] as Dictionary).duplicate(true)
		state.erase("terrain")
		out[key] = state
	return out


func _deserialize_hex_states_from_save(src: Variant) -> Dictionary:
	if not src is Dictionary:
		return {}
	var out: Dictionary = {}
	for key in src:
		var state: Dictionary = (src[key] as Dictionary).duplicate(true)
		if not state.has("terrain"):
			var parts: PackedStringArray = str(key).split(",")
			if parts.size() >= 2:
				var q := int(parts[0])
				var r := int(parts[1])
				var tile: Dictionary = get_tile_map().get(str(key), {})
				var seed_str: String = str(get_world_data().get("seed", "fallback"))
				var regen: Dictionary = LocalMapGen.generate(seed_str, q, r, tile)
				state["terrain"] = regen.get("terrain", PackedByteArray())
				if not state.has("spawn"):
					state["spawn"] = regen.get("spawn", Vector2i(int(LocalMapGen.MAP_SIZE / 2.0), int(LocalMapGen.MAP_SIZE / 2.0)))
		out[key] = state
	return out


func travel_to_hex(q: int, r: int, entry_edge: int = -1) -> void:
	_player_q = q
	_player_r = r
	discover_hex(q, r)
	var state: Dictionary = ensure_hex_state(q, r)
	if entry_edge >= 0:
		var entry: Vector2i = LocalMapGen.get_entry_position(entry_edge)
		_local_x = entry.x
		_local_y = entry.y
	elif state.has("spawn"):
		var spawn: Vector2i = state["spawn"]
		_local_x = spawn.x
		_local_y = spawn.y
	state["visited"] = true
	save_hex_state(q, r, state)

func set_pending_rift(rift_data: Dictionary) -> void:
	_pending_rift = rift_data.duplicate(true) if not rift_data.is_empty() else {}

func get_pending_rift() -> Dictionary:
	return _pending_rift.duplicate(true) if not _pending_rift.is_empty() else {}

func clear_pending_rift() -> void:
	_pending_rift = {}


func set_pending_combat(encounter: Dictionary) -> void:
	_pending_combat = encounter.duplicate(true) if not encounter.is_empty() else {}

func get_pending_combat() -> Dictionary:
	return _pending_combat.duplicate(true) if not _pending_combat.is_empty() else {}

func clear_pending_combat() -> void:
	_pending_combat = {}


static func mob_key(hex_q: int, hex_r: int, local_x: int, local_y: int) -> String:
	return "%s|%s" % [LocalMapGen.hex_key(hex_q, hex_r), LocalMapGen.local_key(local_x, local_y)]


func set_overworld_mob(tile_key: String, mob_data: Dictionary) -> void:
	if tile_key.is_empty() or mob_data.is_empty():
		return
	_overworld_mobs[tile_key] = mob_data.duplicate(true)


func set_local_mob(hex_q: int, hex_r: int, local_x: int, local_y: int, mob_data: Dictionary) -> void:
	set_overworld_mob(mob_key(hex_q, hex_r, local_x, local_y), mob_data)


func get_overworld_mob(tile_key: String) -> Dictionary:
	if _overworld_mobs.has(tile_key):
		return (_overworld_mobs[tile_key] as Dictionary).duplicate(true)
	return {}


func get_local_mob(hex_q: int, hex_r: int, local_x: int, local_y: int) -> Dictionary:
	return get_overworld_mob(mob_key(hex_q, hex_r, local_x, local_y))

func remove_overworld_mob(tile_key: String) -> void:
	_overworld_mobs.erase(tile_key)

func get_overworld_mobs() -> Dictionary:
	return _overworld_mobs.duplicate(true)


func set_world_npcs(
	npcs: Dictionary,
	faction_rep: Dictionary = {},
	recruited_ids: Array = []
) -> void:
	_world_npcs = npcs.duplicate(true) if npcs is Dictionary else {}
	_faction_rep = faction_rep.duplicate(true) if faction_rep is Dictionary else {}
	_recruited_npc_ids = []
	if recruited_ids is Array:
		for entry in recruited_ids:
			_recruited_npc_ids.append(str(entry))


func get_world_npcs() -> Dictionary:
	return _world_npcs.duplicate(true)


func get_faction_rep() -> Dictionary:
	return _faction_rep.duplicate(true)


func get_recruited_npc_ids() -> Array[String]:
	return _recruited_npc_ids.duplicate()
