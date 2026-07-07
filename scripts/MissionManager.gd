## MissionManager — Procedural missions scaled to party average level.
## Generates offers from NPCs, tracks objectives, grants scaled rewards.
extends Node

signal mission_offered(mission: Dictionary)
signal mission_accepted(mission_id: String)
signal mission_progress(mission_id: String, progress: int, target: int)
signal mission_completed(mission_id: String, rewards: Dictionary)
signal mission_failed(mission_id: String, reason: String)

const TEMPLATES_PATH := "res://data/mission_templates.json"
const MissionGen = preload("res://scripts/MissionGenerator.gd")
const EncounterBuilder = preload("res://scripts/CombatEncounterBuilder.gd")
const Difficulty = preload("res://scripts/EncounterDifficulty.gd")
const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")

var _offered: Dictionary = {}       # mission_id -> mission
var _active: Dictionary = {}          # mission_id -> mission
var _completed_ids: Array[String] = []
var _npc_offers: Dictionary = {}      # npc_id -> Array[mission_id]
var _counter: int = 0


func _ready() -> void:
	print("[MissionManager] Initialized.")


func reset_for_new_game() -> void:
	_offered = {}
	_active = {}
	_completed_ids = []
	_npc_offers = {}
	_counter = 0


func get_active_missions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for mid in _active:
		out.append((_active[mid] as Dictionary).duplicate(true))
	return out


func get_offers_for_npc(npc_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not _npc_offers.has(npc_id):
		return out
	for mid in _npc_offers[npc_id]:
		if _offered.has(mid):
			out.append((_offered[mid] as Dictionary).duplicate(true))
	return out


func has_active_capacity() -> bool:
	var max_active: int = _scaling().get("max_active_missions", 3)
	return _active.size() < max_active


func refresh_npc_offers(
	npc_id: String,
	npc_data: Dictionary,
	world_seed: String,
	tile_map: Dictionary,
	player_q: int,
	player_r: int,
	character_data: Dictionary
) -> Array[Dictionary]:
	if not has_active_capacity() and _offered.is_empty():
		pass

	var existing: Array = _npc_offers.get(npc_id, []) as Array
	var still_valid: Array[String] = []
	for mid in existing:
		if _offered.has(mid):
			still_valid.append(str(mid))
	if not still_valid.is_empty():
		_npc_offers[npc_id] = still_valid
		return get_offers_for_npc(npc_id)

	var faction_key: String = str(npc_data.get("faction_key", "independent"))
	var party_level: int = Difficulty.party_average_level(character_data)
	var offer_count: int = int(_scaling().get("offer_count_default", 2))
	var generated: Array[Dictionary] = []
	var ids: Array[String] = []

	for i in range(offer_count):
		var mission: Dictionary = MissionGen.generate_offer(
			world_seed, party_level, tile_map, player_q, player_r, _counter + i,
			faction_key, npc_id
		)
		_counter += 1
		if mission.is_empty():
			continue
		var mid: String = str(mission.get("mission_id", ""))
		if mid.is_empty():
			continue
		_offered[mid] = mission
		ids.append(mid)
		generated.append(mission.duplicate(true))
		mission_offered.emit(mission)

	_npc_offers[npc_id] = ids
	return generated


func accept_mission(mission_id: String, current_time: float = 0.0) -> Dictionary:
	if not _offered.has(mission_id):
		return {"ok": false, "reason": "Mission not available."}
	if not has_active_capacity():
		return {"ok": false, "reason": "Active mission limit reached."}

	var mission: Dictionary = (_offered[mission_id] as Dictionary).duplicate(true)
	_offered.erase(mission_id)
	_remove_from_npc_offers(mission_id)

	mission["status"] = "active"
	mission["accepted_at"] = current_time if current_time > 0.0 else Time.get_ticks_msec() / 1000.0
	var expire_sec: float = float(_scaling().get("expire_after_sec", 1800))
	if expire_sec > 0.0:
		mission["expires_at"] = mission["accepted_at"] + expire_sec

	_active[mission_id] = mission
	_apply_accept_side_effects(mission)
	mission_accepted.emit(mission_id)
	print("[MissionManager] Accepted: %s (Party Lv.%d)" % [
		mission.get("title", mission_id), mission.get("party_avg_level", 1),
	])
	return {"ok": true, "mission": mission}


func report_tile_visit(q: int, r: int) -> Array[Dictionary]:
	var updates: Array[Dictionary] = []
	for mid in _active.keys():
		var mission: Dictionary = _active[mid] as Dictionary
		var obj: Dictionary = mission.get("objective", {}) as Dictionary
		if str(obj.get("type", "")) != "reach_tile":
			continue
		if int(obj.get("target_q", -1)) == q and int(obj.get("target_r", -1)) == r:
			obj["progress"] = 1
			mission["objective"] = obj
			_active[mid] = mission
			mission_progress.emit(mid, 1, 1)
			updates.append(mission.duplicate(true))
			_complete_mission(mid, "scouted")
	return updates


func report_combat_victory(encounter: Dictionary) -> Array[Dictionary]:
	var ctx: Dictionary = encounter.get("return_context", {}) as Dictionary
	var mission_id: String = str(ctx.get("mission_id", ""))
	if mission_id.is_empty() or not _active.has(mission_id):
		return _report_purge_progress(encounter)

	var mission: Dictionary = (_active[mission_id] as Dictionary).duplicate(true)
	var obj: Dictionary = mission.get("objective", {}) as Dictionary
	var obj_type: String = str(obj.get("type", ""))
	var tile_key: String = str(ctx.get("tile_key", ""))

	match obj_type:
		"kill_mob", "win_combat_at_tile":
			if tile_key == str(obj.get("target_tile_key", "")) or tile_key.is_empty():
				obj["progress"] = int(obj.get("target_count", 1))
				mission["objective"] = obj
				_active[mission_id] = mission
				mission_progress.emit(mission_id, obj["progress"], int(obj.get("target_count", 1)))
				_complete_mission(mission_id, "combat")
				return [mission]
		"kill_count":
			if _biome_matches(encounter, obj):
				obj["progress"] = int(obj.get("progress", 0)) + 1
				mission["objective"] = obj
				_active[mission_id] = mission
				mission_progress.emit(mission_id, obj["progress"], int(obj.get("target_count", 1)))
				if obj["progress"] >= int(obj.get("target_count", 1)):
					_complete_mission(mission_id, "purge")
				return [mission]
	return []


func report_rift_cleared(rift_id: String) -> Array[Dictionary]:
	var updates: Array[Dictionary] = []
	for mid in _active.keys():
		var mission: Dictionary = _active[mid] as Dictionary
		var obj: Dictionary = mission.get("objective", {}) as Dictionary
		if str(obj.get("type", "")) != "clear_quest_rift":
			continue
		if str(obj.get("rift_id", "")) != rift_id:
			continue
		obj["progress"] = 1
		mission["objective"] = obj
		_active[mid] = mission
		mission_progress.emit(mid, 1, 1)
		updates.append(mission.duplicate(true))
		_complete_mission(mid, "rift_sealed")
	return updates


func build_mission_encounter(mission_id: String, character_data: Dictionary, equip_stats: Dictionary = {}) -> Dictionary:
	if not _active.has(mission_id):
		return {}
	var mission: Dictionary = (_active[mission_id] as Dictionary).duplicate(true)
	var obj: Dictionary = mission.get("objective", {}) as Dictionary
	var hex_key: String = str(obj.get("target_tile_key", ""))
	var biome: String = str(obj.get("target_biome", "Ash Wastes"))
	var mob: Dictionary = obj.get("mob_template", {}) as Dictionary
	if mob.is_empty():
		mob = EncounterBuilder.random_overworld_mob(biome, true)

	var tile_key: String = hex_key
	var lx: int = int(obj.get("target_local_x", -1))
	var ly: int = int(obj.get("target_local_y", -1))
	if lx >= 0 and ly >= 0:
		var parts: PackedStringArray = hex_key.split(",")
		if parts.size() >= 2:
			# mob_key is a static func on GameState; call it via the
			# autoload instance (which is registered as a global) so
			# the parser doesn't need a class_name on GameState.
			var gs: Node = get_node_or_null("/root/GameState")
			if gs != null:
				tile_key = gs.mob_key(int(parts[0]), int(parts[1]), lx, ly)

	var encounter: Dictionary = EncounterBuilder.build_mission(
		character_data, mob, tile_key, biome, mission, equip_stats
	)
	return encounter


func get_mission_at_tile(q: int, r: int) -> Dictionary:
	var key := "%d,%d" % [q, r]
	for mid in _active:
		var mission: Dictionary = _active[mid] as Dictionary
		var obj: Dictionary = mission.get("objective", {}) as Dictionary
		if str(obj.get("target_tile_key", "")) != key:
			continue
		var obj_type: String = str(obj.get("type", ""))
		if obj_type in ["kill_mob", "win_combat_at_tile", "clear_quest_rift"]:
			return mission.duplicate(true)
	return {}


func should_block_move_for_mission(hex_key: String, local_x: int = -1, local_y: int = -1) -> Dictionary:
	for mid in _active:
		var mission: Dictionary = _active[mid] as Dictionary
		var obj: Dictionary = mission.get("objective", {}) as Dictionary
		if str(obj.get("target_tile_key", "")) != hex_key:
			continue
		if str(obj.get("type", "")) in ["kill_mob", "win_combat_at_tile"]:
			if local_x >= 0 and local_y >= 0:
				var tx: int = int(obj.get("target_local_x", -1))
				var ty: int = int(obj.get("target_local_y", -1))
				if tx >= 0 and ty >= 0 and (abs(tx - local_x) > 1 or abs(ty - local_y) > 1):
					continue
			return mission.duplicate(true)
	return {}


func tick_expired(current_time: float) -> int:
	var failed: int = 0
	for mid in _active.keys():
		var mission: Dictionary = _active[mid] as Dictionary
		var expires: float = float(mission.get("expires_at", 0.0))
		if expires > 0.0 and current_time >= expires:
			_fail_mission(mid, "timed out")
			failed += 1
	return failed


func load_from_save(
	active: Dictionary,
	offered: Dictionary,
	completed_ids: Array,
	npc_offers: Dictionary,
	counter: int = 0
) -> void:
	_active = active.duplicate(true) if active is Dictionary else {}
	_offered = offered.duplicate(true) if offered is Dictionary else {}
	_completed_ids = []
	if completed_ids is Array:
		for entry in completed_ids:
			_completed_ids.append(str(entry))
	_npc_offers = npc_offers.duplicate(true) if npc_offers is Dictionary else {}
	_counter = counter
	print("[MissionManager] Loaded %d active, %d offered mission(s)." % [_active.size(), _offered.size()])


func get_save_payload() -> Dictionary:
	return {
		"active": _active.duplicate(true),
		"offered": _offered.duplicate(true),
		"completed_ids": _completed_ids.duplicate(),
		"npc_offers": _npc_offers.duplicate(true),
		"counter": _counter,
	}


func _complete_mission(mission_id: String, reason: String) -> void:
	if not _active.has(mission_id):
		return
	var mission: Dictionary = (_active[mission_id] as Dictionary).duplicate(true)
	mission["status"] = "completed"
	mission["completed_at"] = Time.get_ticks_msec() / 1000.0
	mission["completion_reason"] = reason

	var rewards: Dictionary = mission.get("rewards", {}) as Dictionary
	_grant_rewards(mission, rewards)

	_active.erase(mission_id)
	if mission_id not in _completed_ids:
		_completed_ids.append(mission_id)

	mission_completed.emit(mission_id, rewards)
	print("[MissionManager] Completed '%s' — +%d XP, +%d rep (%s)" % [
		mission.get("title", mission_id),
		rewards.get("xp", 0),
		rewards.get("faction_rep", 0),
		reason,
	])


func _fail_mission(mission_id: String, reason: String) -> void:
	if not _active.has(mission_id):
		return
	var mission: Dictionary = _active[mission_id] as Dictionary
	mission["status"] = "failed"
	_active.erase(mission_id)
	_cleanup_mission_world_state(mission)
	mission_failed.emit(mission_id, reason)
	print("[MissionManager] Failed '%s': %s" % [mission.get("title", mission_id), reason])


func _grant_rewards(mission: Dictionary, rewards: Dictionary) -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs):
		return

	var xp: int = int(rewards.get("xp", 0))
	if xp > 0:
		gs.grant_class_xp(xp)

	var faction_key: String = str(mission.get("faction_key", ""))
	var rep: int = int(rewards.get("faction_rep", 0))
	if rep != 0 and not faction_key.is_empty():
		var nm: NPCManager = get_node_or_null("/root/NPCManager") as NPCManager
		if is_instance_valid(nm):
			nm.modify_faction_rep(faction_key, rep)

	var loot_count: int = int(rewards.get("loot_count", 0))
	if loot_count > 0:
		var runner: Node = get_node_or_null("/root/RiftRunner")
		if is_instance_valid(runner):
			var biome: String = str(rewards.get("biome_key", "Ash Wastes"))
			var loot: Array = runner.get_random_loot(biome, loot_count)
			_add_loot_to_character(gs, loot)

	_cleanup_mission_world_state(mission)


func _add_loot_to_character(gs: GameState, loot: Array) -> void:
	gs.add_inventory_items(loot)


func _apply_accept_side_effects(mission: Dictionary) -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs):
		return

	var obj: Dictionary = mission.get("objective", {}) as Dictionary
	var obj_type: String = str(obj.get("type", ""))
	var tile_key: String = str(obj.get("target_tile_key", ""))

	if obj_type in ["kill_mob", "win_combat_at_tile", "salvage"]:
		var mob: Dictionary = obj.get("mob_template", {}) as Dictionary
		if not mob.is_empty():
			mob["mission_id"] = str(mission.get("mission_id", ""))
			var parts: PackedStringArray = tile_key.split(",")
			var q: int = int(parts[0]) if parts.size() >= 1 else 0
			var r: int = int(parts[1]) if parts.size() >= 2 else 0
			var local_pos: Vector2i = _mission_local_position(str(mission.get("mission_id", "")), q, r)
			obj["target_local_x"] = local_pos.x
			obj["target_local_y"] = local_pos.y
			mission["objective"] = obj
			_active[str(mission.get("mission_id", ""))] = mission
			gs.set_local_mob(q, r, local_pos.x, local_pos.y, mob)

	if obj_type == "clear_quest_rift":
		var runner: Node = get_node_or_null("/root/RiftRunner")
		if is_instance_valid(runner) and runner.has_method("add_rift_entrance"):
			var parts: PackedStringArray = tile_key.split(",")
			var q: int = int(parts[0]) if parts.size() >= 1 else 0
			var r: int = int(parts[1]) if parts.size() >= 2 else 0
			var biome: String = str(obj.get("target_biome", "Ash Wastes"))
			var quest_rift_id: String = str(obj.get("rift_id", ""))
			var wants_boss: bool = int(mission.get("party_avg_level", 1)) >= 8
			var local_pos: Vector2i = _mission_local_position(str(mission.get("mission_id", "")), q, r)
			var entry: Dictionary = runner.add_rift_entrance(
				q, r, biome, 2400.0, quest_rift_id, wants_boss, local_pos.x, local_pos.y
			)
			entry["quest_mission_id"] = str(mission.get("mission_id", ""))
			obj["rift_id"] = str(entry.get("rift_id", ""))
			mission["objective"] = obj
			_active[str(mission.get("mission_id", ""))] = mission


func _cleanup_mission_world_state(mission: Dictionary) -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs):
		return
	var obj: Dictionary = mission.get("objective", {}) as Dictionary
	var tile_key: String = str(obj.get("target_tile_key", ""))
	if tile_key.is_empty():
		return
	var parts: PackedStringArray = tile_key.split(",")
	if parts.size() < 2:
		return
	var q: int = int(parts[0])
	var r: int = int(parts[1])
	var lx: int = int(obj.get("target_local_x", -1))
	var ly: int = int(obj.get("target_local_y", -1))
	if lx >= 0 and ly >= 0:
		var mob_key: String = gs.mob_key(q, r, lx, ly)
		var mob: Dictionary = gs.get_overworld_mob(mob_key)
		if str(mob.get("mission_id", "")) == str(mission.get("mission_id", "")):
			gs.remove_overworld_mob(mob_key)
	else:
		var mob: Dictionary = gs.get_overworld_mob(tile_key)
		if str(mob.get("mission_id", "")) == str(mission.get("mission_id", "")):
			gs.remove_overworld_mob(tile_key)


func _mission_local_position(mission_id: String, q: int, r: int) -> Vector2i:
	var rng := RandomNumberGenerator.new()
	rng.seed = LocalMapGen.hash_seed("%s|%d,%d" % [mission_id, q, r])
	var center: int = int(LocalMapGen.MAP_SIZE / 2.0)
	return Vector2i(
		clampi(center + rng.randi_range(-80, 80), 24, LocalMapGen.MAP_SIZE - 24),
		clampi(center + rng.randi_range(-80, 80), 24, LocalMapGen.MAP_SIZE - 24),
	)


func _report_purge_progress(encounter: Dictionary) -> Array[Dictionary]:
	var updates: Array[Dictionary] = []
	var biome: String = str(encounter.get("biome_key", ""))
	for mid in _active.keys():
		var mission: Dictionary = _active[mid] as Dictionary
		var obj: Dictionary = mission.get("objective", {}) as Dictionary
		if str(obj.get("type", "")) != "kill_count":
			continue
		if str(obj.get("target_biome", "")) != biome:
			continue
		obj["progress"] = int(obj.get("progress", 0)) + 1
		mission["objective"] = obj
		_active[mid] = mission
		mission_progress.emit(mid, obj["progress"], int(obj.get("target_count", 1)))
		updates.append(mission.duplicate(true))
		if obj["progress"] >= int(obj.get("target_count", 1)):
			_complete_mission(mid, "purge")
	return updates


func _biome_matches(encounter: Dictionary, objective: Dictionary) -> bool:
	return str(encounter.get("biome_key", "")) == str(objective.get("target_biome", ""))


func _remove_from_npc_offers(mission_id: String) -> void:
	for npc_id in _npc_offers.keys():
		var ids: Array = (_npc_offers[npc_id] as Array).duplicate()
		ids.erase(mission_id)
		_npc_offers[npc_id] = ids


func _scaling() -> Dictionary:
	var file: FileAccess = FileAccess.open(TEMPLATES_PATH, FileAccess.READ)
	if not is_instance_valid(file):
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return (parsed as Dictionary).get("scaling", {}) as Dictionary
	return {}