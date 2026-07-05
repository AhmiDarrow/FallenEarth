## SaveManager — Handles autosave, slot management, and corrupt save recovery.
##
## Phase 8: aggregate_snapshot / restore_all collect state from every
## Phase 1-7 manager (InventoryManager, ProgressionManager,
## PartyNPCManager, EquipmentManager, BaseManager, BaseShopManager)
## via their get_snapshot / restore_from_snapshot methods. Each
## manager owns its own data shape; SaveManager just routes.
extends Node

signal save_completed(slot_id: int)
signal save_load_failed(slot_id: int, reason: String)
signal auto_save_triggered()

const VERSION := "0.4.0"
const SAVE_DIR := "user://saves/"
const AUTOSAVE_SLOT := 0
const MAX_SLOTS := 9
const AUTOSAVE_INTERVAL_SEC := 120




# -- Public API --

func initialize() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)


func autosave(game_state: Variant, appearance_data: Variant = null, equipment_data: Variant = null) -> bool:
	var save_data := {"version": VERSION, "autosave": true, "slot": AUTOSAVE_SLOT}
	# Normalize: support full payload or bare game_state
	if game_state is Dictionary:
		var gs_dict: Dictionary = game_state
		if gs_dict.has("character"):
			save_data["character"] = gs_dict.get("character", {})
			if gs_dict.has("appearance"): save_data["appearance"] = gs_dict["appearance"]
			if gs_dict.has("equipment"): save_data["equipment"] = gs_dict["equipment"]
			if gs_dict.has("game_state"): save_data["game_state"] = gs_dict["game_state"]
		else:
			save_data["character"] = gs_dict
	if appearance_data != null:
		save_data["appearance"] = appearance_data
	if equipment_data != null:
		save_data["equipment"] = equipment_data
	save_data["save_name"] = "Autosave"

	return _write_slot(AUTOSAVE_SLOT, save_data)


func save_to_game_file(payload: Variant, slot_id: int, save_name: String = "Untitled") -> bool:
	var save_data := {"version": VERSION, "autosave": false, "slot": slot_id, "save_name": save_name}
	# Normalize payload: if it already has top-level "character" use it; else treat payload as the character dict.
	if payload is Dictionary:
		var p: Dictionary = payload
		if p.has("character"):
			save_data["character"] = p.get("character", {}).duplicate(true) if p.get("character") is Dictionary else p.get("character")
			if p.has("appearance"): save_data["appearance"] = p["appearance"]
			if p.has("equipment"): save_data["equipment"] = p["equipment"]
			if p.has("game_state"): save_data["game_state"] = p["game_state"]
			for extra_key in [
				"world_data", "player_position", "hex_states", "discovered_hexes",
				"overworld_mobs", "rift_state",
				"world_npcs", "faction_rep", "recruited_npc_ids", "missions", "version",
			]:
				if p.has(extra_key):
					save_data[extra_key] = p[extra_key]
		else:
			# bare character payload (e.g. from CharacterSelection)
			save_data["character"] = p.duplicate(true)
			# carry over any extra top keys the caller added (e.g. saved_to_slot)
			for k in p.keys():
				if not save_data.has(k) and k != "character":
					save_data[k] = p[k]

	return _write_slot(slot_id, save_data)


func load_from_slot(slot_id: int) -> Dictionary:
	var path := SAVE_DIR + "slot_%d.json" % slot_id
	if not FileAccess.file_exists(path):
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		save_load_failed.emit(slot_id, "Could not open save file")
		return {}

	var raw_text = file.get_as_text()
	file.close()  # Close before parsing to avoid resource leak

	var parse_result: Variant = JSON.parse_string(raw_text)
	if typeof(parse_result) != TYPE_DICTIONARY or parse_result.is_empty():
		push_error("[SaveManager] Error parsing save slot %d (invalid or empty JSON)" % slot_id)
		save_load_failed.emit(slot_id, "Parse failed")
		return {}

	# parse_result is guaranteed to be a Dictionary by the check above
	var json_result: Dictionary = parse_result as Dictionary
	if not json_result.is_empty():
		return json_result
	else:
		push_warning("[SaveManager] Corrupt data detected in slot %d (%s)" % [slot_id, path])
		recover_from_corruption(slot_id)
		return {}


func has_save_in_slot(slot_id: int) -> bool:
	var path := SAVE_DIR + "slot_%d.json" % slot_id
	return FileAccess.file_exists(path)


func list_all_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for i in range(MAX_SLOTS):
		var path := SAVE_DIR + "slot_%d.json" % i
		if FileAccess.file_exists(path):
			var file: FileAccess = FileAccess.open(path, FileAccess.READ)
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			file.close()  # Close after reading to avoid resource leak
			var data: Dictionary = parsed if (parsed is Dictionary) else {}
			# Robust name extraction for old/new save shapes
			var char_part: Variant = data.get("character", data.get("game_state", {}))
			var char_name: String = ""
			if char_part is Dictionary:
				char_name = str(char_part.get("name", char_part.get("id", "")))
			var display_name: String = str(data.get("save_name", "")) if data.get("save_name", "") != "" else (char_name if char_name != "" else "Untitled")
			slots.append({"slot": i, "name": display_name, "autosave": data.get("autosave", false)})
		else:
			slots.append({"slot": i, "name": "", "autosave": false})
	return slots


# -- Private Helpers --

func _write_slot(slot_id: int, data: Dictionary) -> bool:
	var path := SAVE_DIR + "slot_%d.json" % slot_id
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("[SaveManager] Failed to write save file: %s" % path)
		save_load_failed.emit(slot_id, "Write failed")
		return false

	var json_string: String = JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()
	save_completed.emit(slot_id)
	return true


## Called by the autosave timer every 120 seconds.
func _auto_save_tick() -> void:
	auto_save_triggered.emit()


## Call this once to start the autosave timer.
var _autosave_timer: Timer = null

func start_autosave_timer() -> void:
	if is_instance_valid(_autosave_timer):
		return
	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = AUTOSAVE_INTERVAL_SEC
	_autosave_timer.autostart = true
	_autosave_timer.one_shot = false
	add_child(_autosave_timer)
	_autosave_timer.timeout.connect(_auto_save_tick)


## Full-state autosave helper. GameState calls this from the autosave signal handler.
func full_autosave(char_data: Dictionary, appearance: Dictionary, equipment: Dictionary,
					world_data: Dictionary = {}, player_position: Dictionary = {},
					hex_states: Dictionary = {}, discovered_hexes: Array = [],
					overworld_mobs: Dictionary = {}, rift_state: Dictionary = {},
					world_npcs: Dictionary = {}, faction_rep: Dictionary = {},
					recruited_npc_ids: Array = [], missions: Dictionary = {}) -> bool:
	var save_data := {"version": VERSION, "autosave": true, "slot": AUTOSAVE_SLOT}

	if char_data is Dictionary and not char_data.is_empty():
		save_data["character"] = char_data.duplicate(true)
	else:
		save_data["character"] = {}
	save_data["appearance"] = appearance if appearance is Dictionary else {}
	save_data["equipment"] = equipment if equipment is Dictionary else {}
	save_data["game_state"] = {"active_scene": "", "save_slot": AUTOSAVE_SLOT}

	if world_data is Dictionary and not world_data.is_empty():
		save_data["world_data"] = world_data.duplicate(true)
	save_data["player_position"] = player_position if player_position is Dictionary else {}
	if hex_states is Dictionary:
		var hex_out: Dictionary = {}
		for key in hex_states:
			var state: Dictionary = (hex_states[key] as Dictionary).duplicate(true)
			state.erase("terrain")
			hex_out[key] = state
		save_data["hex_states"] = hex_out
	else:
		save_data["hex_states"] = {}

	if discovered_hexes is Array:
		save_data["discovered_hexes"] = discovered_hexes.duplicate()
	if overworld_mobs is Dictionary:
		save_data["overworld_mobs"] = overworld_mobs.duplicate(true)
	if rift_state is Dictionary and not rift_state.is_empty():
		save_data["rift_state"] = rift_state.duplicate(true)
	if world_npcs is Dictionary and not world_npcs.is_empty():
		save_data["world_npcs"] = world_npcs.duplicate(true)
	if faction_rep is Dictionary:
		save_data["faction_rep"] = faction_rep.duplicate(true)
	if recruited_npc_ids is Array:
		save_data["recruited_npc_ids"] = recruited_npc_ids.duplicate()
	if missions is Dictionary and not missions.is_empty():
		save_data["missions"] = missions.duplicate(true)

	save_data["save_name"] = "Autosave"
	return _write_slot(AUTOSAVE_SLOT, save_data)


func recover_from_corruption(slot_id: int) -> void:
	var backup_path := SAVE_DIR + "slot_%d.json.bak" % slot_id
	var primary_path := SAVE_DIR + "slot_%d.json" % slot_id
	if FileAccess.file_exists(backup_path):
		var backup_file: FileAccess = FileAccess.open(backup_path, FileAccess.READ)
		var primary_file: FileAccess = FileAccess.open(primary_path, FileAccess.WRITE)
		primary_file.store_string(backup_file.get_as_text())
		backup_file.close()
		primary_file.close()
		push_warning("[SaveManager] Recovered from backup for slot %d" % slot_id)


# ---------------------------------------------------------------------------
# Phase 8: aggregate snapshot / restore
# ---------------------------------------------------------------------------

## Returns a dict of {manager_name: snapshot} for every Phase 1-7
## manager that exposes get_snapshot(). Safe to call when managers
## are not yet instantiated (returns an empty dict in that case).
func aggregate_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for entry in [
		["inventory", "/root/InventoryManager"],
		["progression", "/root/ProgressionManager"],
		["party", "/root/PartyNPCManager"],
		["equipment", "/root/EquipmentManager"],
		["base", "/root/BaseManager"],
		["base_shops", "/root/BaseShopManager"],
	]:
		var mgr: Node = get_node_or_null(entry[1])
		if mgr == null or not mgr.has_method("get_snapshot"):
			continue
		out[entry[0]] = mgr.get_snapshot()
	return out


## Restores each manager's state from the dict produced by
## aggregate_snapshot. Skips managers that aren't present or don't
## have restore_from_snapshot. Handles per-manager wrapper formats
## (e.g. InventoryManager wraps its slots in a dict).
func restore_all(snap: Dictionary) -> void:
	for entry in [
		["inventory", "/root/InventoryManager", "slots"],
		["progression", "/root/ProgressionManager", null],
		["party", "/root/PartyNPCManager", null],
		["equipment", "/root/EquipmentManager", null],
		["base", "/root/BaseManager", null],
		["base_shops", "/root/BaseShopManager", null],
	]:
		if not snap.has(entry[0]):
			continue
		var mgr: Node = get_node_or_null(entry[1])
		if mgr == null or not mgr.has_method("restore_from_snapshot"):
			continue
		var data: Variant = snap[entry[0]]
		# Per-manager wrapper: InventoryManager wraps its slots in a dict
		if entry[2] != null and data is Dictionary and data.has(entry[2]):
			data = data[entry[2]]
		mgr.restore_from_snapshot(data)


## Aggregates all manager state and writes it into the given save
## payload dict (typically the existing `save_data` in autosave).
## Safe to call before _write_slot.
func populate_payload_with_managers(save_data: Dictionary) -> void:
	var snaps: Dictionary = aggregate_snapshot()
	for k in snaps:
		save_data[k] = snaps[k]


## Pulls manager state out of the loaded payload dict and routes it
## to each manager's restore_from_snapshot. Safe to call after
## load_from_slot.
func apply_managers_from_payload(save_data: Dictionary) -> void:
	var manager_state: Dictionary = {}
	for k in ["inventory", "progression", "party", "equipment", "base", "base_shops"]:
		if save_data.has(k):
			manager_state[k] = save_data[k]
	restore_all(manager_state)


func _auto_save() -> void:
	auto_save_triggered.emit()
