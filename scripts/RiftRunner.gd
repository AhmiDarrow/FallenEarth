## RiftRunner -- Manages rifts as "tunnels" per spec.
## Spawn randomly in overworld for 5-30 min real/game time windows, or via quests.
## Enter leads to instanced procedural dungeon (RiftInstance).
## At end: close mechanism to exit back to overworld.
## Some have bosses. Hybrid RW events + SDV dungeons.
extends Node

const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")

signal rift_entered(rift_id: String)
signal rift_cleared(rift_id: String, loot_array: Array[Dictionary])
signal rift_collapsed(reason: String)

const VERSION := "0.2.0"
const LOOT_TABLE_PATH := "res://data/loot_tables.json"

var _current_rift_id: String = ""
var _run_is_active := false
var _rift_entrances: Array[Dictionary] = []  # {q, r, rift_id, biome_key, spawn_time, duration}
var _loot_tables: Dictionary = {}  # biome -> array of loot defs
var _loot_loaded := false
var _last_spawn_check: float = 0.0
const RIFT_MIN_DURATION_SEC := 300  # 5 min
const RIFT_MAX_DURATION_SEC := 1800  # 30 min


func _ensure_loot_tables() -> void:
	if _loot_loaded:
		return
	_loot_loaded = true
	var file := FileAccess.open(LOOT_TABLE_PATH, FileAccess.READ)
	if not is_instance_valid(file):
		push_warning("[RiftRunner] Could not open loot tables at %s" % LOOT_TABLE_PATH)
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_loot_tables = parsed
	else:
		push_warning("[RiftRunner] Loot tables JSON not a dictionary")


## Basic loot picker for a biome. Picks a few items (prefers higher drop_weight).
func get_random_loot(biome_key: String = "Ash Wastes", max_items: int = 3) -> Array[Dictionary]:
	_ensure_loot_tables()
	if not _loot_tables.has(biome_key):
		biome_key = "Ash Wastes"  # fallback
	var table: Array = _loot_tables.get(biome_key, []) as Array
	if table.is_empty():
		return []
	# Simple selection: take up to max_items, biased to higher weight
	var picked: Array[Dictionary] = []
	var sorted_table := table.duplicate()
	sorted_table.sort_custom(func(a, b): return (a.get("drop_weight", 0.0) as float) > (b.get("drop_weight", 0.0) as float))
	for i in range(min(max_items, sorted_table.size())):
		var item: Dictionary = (sorted_table[i] as Dictionary).duplicate(true)
		item["qty"] = 1  # default
		picked.append(item)
	return picked


func start_run(rift_id: String, difficulty_multiplier: float = 1.0, biome_key: String = "Ash Wastes") -> bool:
	_run_is_active = true
	_current_rift_id = rift_id
	rift_entered.emit(rift_id)
	# Basic: preload tables for this run
	_ensure_loot_tables()
	print("[RiftRunner] Started run %s in %s" % [rift_id, biome_key])
	return true


func clear_rift(loot_items: Array[Dictionary] = []) -> void:
	if not _run_is_active or _current_rift_id.is_empty():
		return
	if loot_items.is_empty():
		loot_items = get_random_loot("Ash Wastes", 3)  # basic default; callers can pass biome-specific
	rift_cleared.emit(_current_rift_id, loot_items)
	_run_is_active = false
	print("[RiftRunner] Rift %s cleared with %d loot items" % [_current_rift_id, loot_items.size()])
	# TODO: Update DynamicThreat state based on settlement growth


func collapse_rift(reason := "all_mobs_defeated") -> void:
	rift_collapsed.emit(reason)
	if _rift_entrances.size() > 0:
		var idx: int = 0
		for entry: Dictionary in _rift_entrances:
			if entry.get("rift_id", "") == _current_rift_id:
				_rift_entrances.remove_at(idx)
				break
			idx += 1


func get_active_rift_count() -> int:
	var active_count := 0
	for entry in _rift_entrances:
		if entry.get("active", false):
			active_count += 1
	return active_count


# TODO Methods (placeholder -- not yet implemented)

func add_rift_entrance(
	q: int,
	r: int,
	biome_key: String = "Ash Wastes",
	duration_sec: float = -1.0,
	rift_id_override: String = "",
	has_boss_override: Variant = null,
	local_x: int = -1,
	local_y: int = -1
) -> Dictionary:
	var rift_id: String = rift_id_override if not rift_id_override.is_empty() else "rift_%04d" % randi()
	var now := Time.get_ticks_msec() / 1000.0
	var duration := duration_sec if duration_sec > 0 else RIFT_MIN_DURATION_SEC + randf() * (RIFT_MAX_DURATION_SEC - RIFT_MIN_DURATION_SEC)
	var has_boss: bool = bool(has_boss_override) if has_boss_override != null else randf() < 0.2
	if local_x < 0:
		local_x = 200 + randi() % 112
	if local_y < 0:
		local_y = 200 + randi() % 112
	var entry := {
		"q": q,
		"r": r,
		"local_x": local_x,
		"local_y": local_y,
		"rift_id": rift_id,
		"biome_key": biome_key,
		"spawn_time": now,
		"duration": duration,
		"has_boss": has_boss,
		"active": true,
	}
	_rift_entrances.append(entry)
	return entry


func save_run_result(rift_id: String, duration_sec: int, xp_gained: int) -> void:
	pass

## Check and spawn random timed rifts in overworld (call periodically from Hub/Overworld).
## Duration 5-30 min real time.
func try_spawn_rifts(overworld_tiles: Array, current_time: float) -> Array:
	if current_time - _last_spawn_check < 60:  # check every min
		return []
	_last_spawn_check = current_time
	
	var new_rifts = []
	if randf() < 0.3:  # 30% chance per check
		var tile = overworld_tiles[randi() % overworld_tiles.size()] if overworld_tiles else {"q":0,"r":0,"name":"Ash Wastes"}
		var rift_id = "rift_%04d" % randi()
		var duration = RIFT_MIN_DURATION_SEC + randf() * (RIFT_MAX_DURATION_SEC - RIFT_MIN_DURATION_SEC)
		var rift = {
			"q": tile.get("q", 0),
			"r": tile.get("r", 0),
			"local_x": 128 + randi() % 256,
			"local_y": 128 + randi() % 256,
			"rift_id": rift_id,
			"biome_key": tile.get("name", "Ash Wastes"),
			"spawn_time": current_time,
			"duration": duration,
			"has_boss": randf() < 0.2
		}
		rift["active"] = true
		_rift_entrances.append(rift)
		new_rifts.append(rift)
		print("[RiftRunner] Rift tunnel spawned at ", rift["q"], ",", rift["r"], " for ", int(duration/60), " min. Boss: ", rift["has_boss"])
	return new_rifts


func prune_expired_rifts(current_time: float) -> int:
	var before := _rift_entrances.size()
	_rift_entrances = _rift_entrances.filter(func(e: Dictionary) -> bool:
		return (current_time - e.get("spawn_time", 0.0)) < e.get("duration", 0.0)
	)
	return before - _rift_entrances.size()


func get_rift_at(q: int, r: int, current_time: float) -> Dictionary:
	for e in _rift_entrances:
		if e.get("q", -999) == q and e.get("r", -999) == r:
			if (current_time - e.get("spawn_time", 0.0)) < e.get("duration", 0.0):
				return e.duplicate(true)
	return {}


func get_rift_at_local(q: int, r: int, local_x: int, local_y: int, current_time: float) -> Dictionary:
	for e in _rift_entrances:
		if e.get("q", -999) != q or e.get("r", -999) != r:
			continue
		if (current_time - e.get("spawn_time", 0.0)) >= e.get("duration", 0.0):
			continue
		var lx: int = int(e.get("local_x", -1))
		var ly: int = int(e.get("local_y", -1))
		if abs(lx - local_x) <= 1 and abs(ly - local_y) <= 1:
			return e.duplicate(true)
	return {}


func get_rifts_in_hex(q: int, r: int, current_time: float) -> Array:
	var out: Array = []
	for e in _rift_entrances:
		if e.get("q", -999) == q and e.get("r", -999) == r:
			if (current_time - e.get("spawn_time", 0.0)) < e.get("duration", 0.0):
				out.append(e.duplicate(true))
	return out


func try_spawn_local_rift(
	hex_q: int,
	hex_r: int,
	biome_key: String,
	local_map: Dictionary,
	current_time: float
) -> Dictionary:
	if current_time - _last_spawn_check < 60.0:
		return {}
	_last_spawn_check = current_time
	if randf() > 0.25:
		return {}
	var lx := 64 + randi() % 384
	var ly := 64 + randi() % 384
	for _attempt in 8:
		if LocalMapGen.is_walkable(local_map, lx, ly):
			break
		lx = 64 + randi() % 384
		ly = 64 + randi() % 384
	return add_rift_entrance(hex_q, hex_r, biome_key, -1.0, "", null, lx, ly)

## Check if a rift at position is still active.
func is_rift_active_at(q: int, r: int, current_time: float) -> bool:
	for e in _rift_entrances:
		if e["q"] == q and e["r"] == r:
			return (current_time - e["spawn_time"]) < e["duration"]
	return false

## Get active rifts for overworld display.
func get_active_rifts(current_time: float) -> Array:
	var active = []
	for e in _rift_entrances:
		if (current_time - e["spawn_time"]) < e["duration"]:
			active.append(e)
	return active

## Close rift (called from dungeon end).
func close_rift(rift_id: String) -> Dictionary:
	for i in range(_rift_entrances.size()):
		if _rift_entrances[i]["rift_id"] == rift_id:
			var closed: Dictionary = _rift_entrances.pop_at(i)
			print("[RiftRunner] Rift closed: ", rift_id)
			return closed
	return {}


func get_save_payload() -> Dictionary:
	return {"entrances": _rift_entrances.duplicate(true)}


func load_from_save(data: Dictionary) -> void:
	_rift_entrances = []
	if not data is Dictionary:
		return
	var src: Array = data.get("entrances", []) as Array
	for entry in src:
		if entry is Dictionary:
			_rift_entrances.append((entry as Dictionary).duplicate(true))
	print("[RiftRunner] Loaded %d rift entrance(s) from save." % _rift_entrances.size())


func reset_for_new_game() -> void:
	_rift_entrances = []
	_current_rift_id = ""
	_run_is_active = false
	_last_spawn_check = 0.0
