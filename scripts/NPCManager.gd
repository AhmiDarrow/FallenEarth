## NPCManager — Procedural world NPC roster, faction rep, and recruitment.
extends Node

signal npcs_generated(count: int)
signal npc_recruited(npc_id: String, npc_data: Dictionary)
signal faction_rep_changed(faction_key: String, new_rep: int)
signal procedural_mob_generated(npc_id: String, mob: ProceduralMob)

const FACTIONS_PATH := "res://data/factions.json"
const NPCGeneratorScript = preload("res://scripts/NPCGenerator.gd")

var _world_npcs: Dictionary = {}       # id -> npc dict
var _tile_index: Dictionary = {}       # tile_key -> npc_id
var _faction_rep: Dictionary = {}        # faction_key -> int
var _recruited_ids: Array[String] = []
var _world_seed: String = ""


func _ready() -> void:
	_reset_faction_rep()
	print("[NPCManager] Initialized.")


func reset_for_new_game() -> void:
	_world_npcs = {}
	_tile_index = {}
	_recruited_ids = []
	_world_seed = ""
	_reset_faction_rep()


func _reset_faction_rep() -> void:
	_faction_rep = {}
	var factions: Array = _load_factions()
	for entry in factions:
		if not entry is Dictionary:
			continue
		var faction: Dictionary = entry as Dictionary
		var key: String = _slugify(str(faction.get("name", "")))
		_faction_rep[key] = int(faction.get("starting_rep", 0))


func generate_for_world(world_seed: String, tile_map: Dictionary, start_tile_key: String) -> Dictionary:
	if world_seed.is_empty() or tile_map.is_empty():
		push_warning("[NPCManager] Cannot generate NPCs without world seed/tiles.")
		return {}

	_world_seed = world_seed
	_world_npcs = NPCGeneratorScript.generate_world_roster(world_seed, tile_map, start_tile_key)
	_rebuild_tile_index()
	_recruited_ids = []

	# Generate procedural mob fallbacks for NPCs missing assets
	var procedural_pool: Dictionary = {}
	for npc_id in _world_npcs:
		var npc: Dictionary = _world_npcs[npc_id] as Dictionary
		var proto: Dictionary = _build_procedural_mob(npc)
		if proto.has("archetype") and proto.has("color"):
			procedural_pool[npc_id] = proto

	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if is_instance_valid(gs):
		gs.set_world_npcs(_world_npcs, _faction_rep, _recruited_ids)
		# Wire GameState's procedural mob handler so it can log/forward NPC procedural generation
		gs.set_npc_manager_procedural_mob_handler(self, Callable.new())

	npcs_generated.emit(_world_npcs.size())
	print("[NPCManager] Generated %d procedural NPC(s) for seed '%s'." % [_world_npcs.size(), world_seed])
	return _world_npcs.duplicate(true)


func has_roster() -> bool:
	return not _world_npcs.is_empty()


func get_world_seed() -> String:
	return _world_seed


func get_all_npcs() -> Dictionary:
	return _world_npcs.duplicate(true)


func get_available_npcs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for npc_id in _world_npcs:
		var npc: Dictionary = (_world_npcs[npc_id] as Dictionary).duplicate(true)
		if not bool(npc.get("recruited", false)) and str(npc.get("status", "")) == "available":
			out.append(npc)
	return out


func get_recruited_npcs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for npc_id in _recruited_ids:
		if _world_npcs.has(npc_id):
			out.append((_world_npcs[npc_id] as Dictionary).duplicate(true))
	return out


func get_npc(npc_id: String) -> Dictionary:
	if _world_npcs.has(npc_id):
		return (_world_npcs[npc_id] as Dictionary).duplicate(true)
	return {}


func get_npc_at_tile(tile_key: String) -> Dictionary:
	if not _tile_index.has(tile_key):
		return {}
	var npc_id: String = str(_tile_index[tile_key])
	return get_npc(npc_id)


func get_faction_rep(faction_key: String) -> int:
	return int(_faction_rep.get(faction_key, 0))


func set_faction_rep(faction_key: String, value: int) -> void:
	_faction_rep[faction_key] = value
	faction_rep_changed.emit(faction_key, value)
	_sync_to_game_state()


func modify_faction_rep(faction_key: String, delta: int) -> int:
	var new_val: int = get_faction_rep(faction_key) + delta
	set_faction_rep(faction_key, new_val)
	return new_val


func get_all_faction_rep() -> Dictionary:
	return _faction_rep.duplicate(true)


func can_recruit(npc_id: String, character_data: Dictionary = {}) -> Dictionary:
	var npc: Dictionary = get_npc(npc_id)
	if npc.is_empty():
		return {"ok": false, "reason": "NPC not found."}
	if bool(npc.get("recruited", false)):
		return {"ok": false, "reason": "Already recruited."}

	var req: Dictionary = npc.get("recruitment", {}) as Dictionary
	var rep_need: int = int(req.get("rep_required", 0))
	var lvl_need: int = int(req.get("level_required", 1))
	var faction_key: String = str(npc.get("faction_key", ""))
	var rep_have: int = get_faction_rep(faction_key)
	var lvl_have: int = int(character_data.get("level", 1))

	if rep_have < rep_need:
		return {
			"ok": false,
			"reason": "Need %d rep with %s (have %d)." % [rep_need, npc.get("faction", faction_key), rep_have],
			"rep_required": rep_need,
			"rep_have": rep_have,
			"level_required": lvl_need,
			"level_have": lvl_have,
		}
	if lvl_have < lvl_need:
		return {
			"ok": false,
			"reason": "Need player level %d (have %d)." % [lvl_need, lvl_have],
			"rep_required": rep_need,
			"rep_have": rep_have,
			"level_required": lvl_need,
			"level_have": lvl_have,
		}
	return {
		"ok": true,
		"reason": "Requirements met.",
		"rep_required": rep_need,
		"rep_have": rep_have,
		"level_required": lvl_need,
		"level_have": lvl_have,
	}


func recruit_npc(npc_id: String, character_data: Dictionary = {}) -> bool:
	var check: Dictionary = can_recruit(npc_id, character_data)
	if not bool(check.get("ok", false)):
		push_warning("[NPCManager] Recruitment failed: %s" % check.get("reason", "?"))
		return false
	if not _world_npcs.has(npc_id):
		return false

	var npc: Dictionary = (_world_npcs[npc_id] as Dictionary).duplicate(true)
	npc["recruited"] = true
	npc["status"] = "recruited"
	_world_npcs[npc_id] = npc

	if npc_id not in _recruited_ids:
		_recruited_ids.append(npc_id)

	var tile_key: String = str(npc.get("tile_key", ""))
	if not tile_key.is_empty():
		_tile_index.erase(tile_key)

	_sync_to_game_state()
	npc_recruited.emit(npc_id, npc.duplicate(true))
	print("[NPCManager] Recruited %s (%s) to settlement." % [npc.get("name", npc_id), npc.get("role", "?")])
	return true


func load_from_save(
	world_npcs: Dictionary,
	faction_rep: Dictionary,
	recruited_ids: Array = []
) -> void:
	_world_npcs = world_npcs.duplicate(true) if world_npcs is Dictionary else {}
	_faction_rep = faction_rep.duplicate(true) if faction_rep is Dictionary else {}
	_recruited_ids = []
	if recruited_ids is Array:
		for entry in recruited_ids:
			_recruited_ids.append(str(entry))
	_rebuild_tile_index()
	print("[NPCManager] Loaded %d NPC(s), %d recruited." % [_world_npcs.size(), _recruited_ids.size()])


func _rebuild_tile_index() -> void:
	_tile_index = {}
	for npc_id in _world_npcs:
		var npc: Dictionary = _world_npcs[npc_id] as Dictionary
		if bool(npc.get("recruited", false)):
			continue
		var tile_key: String = str(npc.get("tile_key", ""))
		if not tile_key.is_empty():
			_tile_index[tile_key] = str(npc_id)


func _sync_to_game_state() -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if is_instance_valid(gs):
		gs.set_world_npcs(_world_npcs, _faction_rep, _recruited_ids)


func _load_factions() -> Array:
	var file: FileAccess = FileAccess.open(FACTIONS_PATH, FileAccess.READ)
	if not is_instance_valid(file):
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Array else []


func _build_procedural_mob(npc_data: Dictionary) -> Dictionary:
	"""Build a procedural mob data dictionary for NPCs missing assets.

	Returns a proto dict with archetype and color (and optional size) for
	ProceduralMob to consume. Called from generate_for_world after NPC roster
	is built, before GameState is updated.
	"""
	archetypes = ["quadruped", "insectoid", "behemoth", "aberrant"]
	# Derive archetype from npc_data's type/role hints
	archetype = str(npc_data.get("type", "quadruped")).to_lower()
	if archetype not in archetypes:
		archetype = str(npc_data.get("role", "quadruped")).to_lower()
		if archetype not in archetypes:
			archetype = "quadruped"
	# Color comes from npc_data's color field or default
	color = str(npc_data.get("color", "rags"))
	# Size is optional; ProceduralMob uses 48 if not provided
	size = float(npc_data.get("size", 48))
	return {"archetype": archetype, "color": color, "size": size}

func get_procedural_mob(npc_data: Dictionary):
	"""Return a ProceduralMob instance for NPC spawning.

	Called from NPCManager.gd after roster generation. Returns null if npc_data
	already has assets (handled by CharacterVisual/GameState fallback), or
	instantiates a new ProceduralMob with the npc's archetype/color/size.
	"""
	proto = _build_procedural_mob(npc_data)
	if proto.is_empty():
		return null
	mob = ProceduralMob.new()
	mob.setup_for(proto)
	return mob

func has_procedural_assets(npc_data: Dictionary = {}) -> bool:
	# Placeholder — ProceduralMob is data-driven; we just need to ensure
	# NPCManager generates it, GameState will handle asset fallback.
	return false

func _slugify(name: String) -> String:
	return name.to_lower().replace(" ", "_").replace("'", "")