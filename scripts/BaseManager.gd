## BaseManager — Tracks the player's home base (Phase 6).
##
## The base is auto-unlocked at L10. The player picks a placement cell
## (with a 50-tile buffer from any map edge) on first unlock. The base
## has 10 upgrade levels ending at L200; each upgrade has a cost
## (EC + materials) and grants +5 capacity. At 20 residents, the player
## can name the settlement.
##
## State:
##   - placement: {hex_key, local_x, local_y, placed_at} or {} if not
##     yet placed
##   - level: int (1-10)
##   - capacity: int (5 + 5 * (level - 1))
##   - residents: Array[String] of NPC ids (the dismissed-to-base roster)
##   - settlement_name: String (set when residents >= 20)
##
## Signals:
##   - base_placed(hex_key, local_x, local_y)
##   - base_upgraded(new_level, new_capacity)
##   - resident_added(npc_id) / resident_removed(npc_id)
##   - settlement_named(name)
##
## Persistence: like the rest of Phase 6, this is non-persistent for
## now. GameState.SaveManager is the canonical layer (Phase 8 will
## include the base dict).
extends Node

const BASE_PATH := "res://data/base.json"
const PROGRESSION_PATH := "/root/ProgressionManager"
const PARTY_PATH := "/root/PartyNPCManager"

signal base_placed(hex_key: String, local_x: int, local_y: int)
signal base_upgraded(new_level: int, new_capacity: int)
signal resident_added(npc_id: String)
signal resident_removed(npc_id: String)
signal settlement_named(name: String)

const RESIDENT_THRESHOLD_FOR_NAMING := 20

# Loaded in _ready
var _config: Dictionary = {}
var _upgrades: Array = []

# State
var placement: Dictionary = {}  # {hex_key, local_x, local_y, placed_at}
var level: int = 0  # 0 = not yet placed
var residents: Array = []  # Array of npc_ids
var settlement_name: String = ""


func _ready() -> void:
	_load_config()
	# Phase 3: settlement name is "My Outpost" by default if 20+ residents.
	# Phase 6: the player picks a name when they hit 20 residents.
	print("[BaseManager] Initialized (placement=%s, level=%d)." % [
		"yes" if not placement.is_empty() else "no", level
	])


func _load_config() -> void:
	if not ResourceLoader.exists(BASE_PATH):
		push_error("[BaseManager] %s missing" % BASE_PATH)
		return
	var raw = load(BASE_PATH)
	if raw == null:
		return
	var data = raw.data if "data" in raw else raw
	if not (data is Dictionary):
		return
	_config = data
	_upgrades = data.get("upgrades", [])


# ---------------------------------------------------------------------------
# Unlock / placement
# ---------------------------------------------------------------------------

## Returns true if the player meets the L10 requirement to unlock
## the base.
func can_unlock() -> bool:
	var prog: Node = get_node_or_null(PROGRESSION_PATH)
	if prog == null:
		return false
	return int(prog.level) >= int(_config.get("spawn_level_required", 10))


## Returns true if the base has not yet been placed (placement is empty).
func is_unplaced() -> bool:
	return placement.is_empty()


## Returns true if the given local cell is valid for base placement
## (at least 50 tiles from any edge of the 512x512 map).
func is_valid_placement_cell(cell: Vector2i) -> bool:
	var buffer: int = int(_config.get("placement_buffer_tiles", 50))
	if cell.x < buffer or cell.x >= 512 - buffer:
		return false
	if cell.y < buffer or cell.y >= 512 - buffer:
		return false
	return true


## Place the base at the given (hex_key, local_x, local_y). Returns
## true on success. The base starts at level 1 with capacity 5.
## Can only be called once.
func place(hex_key: String, local_x: int, local_y: int) -> bool:
	if not is_unplaced():
		return false
	if not is_valid_placement_cell(Vector2i(local_x, local_y)):
		return false
	placement = {
		"hex_key": hex_key,
		"local_x": local_x,
		"local_y": local_y,
		"placed_at": Time.get_unix_time_from_system(),
	}
	level = 1
	emit_signal("base_placed", hex_key, local_x, local_y)
	print("[BaseManager] Base placed at %s (%d, %d) — level 1, capacity %d" % [hex_key, local_x, local_y, get_capacity()])
	return true


# ---------------------------------------------------------------------------
# Upgrades
# ---------------------------------------------------------------------------

## Returns the upgrade entry for the given level (1-10), or {} if OOB.
func get_upgrade(lvl: int) -> Dictionary:
	if lvl < 1 or lvl > int(_config.get("max_level", 10)):
		return {}
	var idx: int = lvl - 1
	if idx >= _upgrades.size():
		return {}
	return _upgrades[idx]


## Returns the upgrade for the next level (current + 1), or {} if at max.
func get_next_upgrade() -> Dictionary:
	return get_upgrade(level + 1)


## Returns the current capacity (5 + 5 * (level - 1)).
func get_capacity() -> int:
	if level <= 0:
		return 0
	return int(_config.get("starting_capacity", 5)) + int(_config.get("capacity_per_upgrade", 5)) * (level - 1)


## Returns true if the player can afford the next upgrade (level
## gate + EC + materials). Returns a dict with {ok, reason} so the
## UI can show the unmet requirement.
func can_upgrade() -> Dictionary:
	if level <= 0:
		return {"ok": false, "reason": "Base not placed"}
	if level >= int(_config.get("max_level", 10)):
		return {"ok": false, "reason": "Base is at max level"}
	var next: Dictionary = get_next_upgrade()
	if next.is_empty():
		return {"ok": false, "reason": "No next upgrade"}
	var prog: Node = get_node_or_null(PROGRESSION_PATH)
	var player_level: int = int(prog.level) if prog != null else 1
	if player_level < int(next.get("level_required", 1)):
		return {"ok": false, "reason": "Requires level %d (you are %d)" % [int(next.get("level_required", 1)), player_level]}
	# Check EC
	var ec_needed: int = int(next.get("cost_ec", 0))
	if prog != null and int(prog.ec) < ec_needed:
		return {"ok": false, "reason": "Not enough EC (need %d)" % ec_needed}
	# Check materials
	for ing in next.get("cost_items", []):
		if not (ing is Dictionary):
			continue
		var item_id: String = str(ing.get("item", ""))
		var qty: int = int(ing.get("qty", 1))
		var inv: Node = get_node_or_null("/root/InventoryManager")
		if inv == null or int(inv.get_count(item_id)) < qty:
			return {"ok": false, "reason": "Missing %dx %s" % [qty, item_id]}
	return {"ok": true, "reason": ""}


## Apply the next upgrade. Deducts cost (EC + items) and increments
## level. Returns true on success.
func upgrade() -> bool:
	var check: Dictionary = can_upgrade()
	if not bool(check.get("ok", false)):
		return false
	var next: Dictionary = get_next_upgrade()
	var prog: Node = get_node_or_null(PROGRESSION_PATH)
	var inv: Node = get_node_or_null("/root/InventoryManager")
	# Deduct EC
	if prog != null and int(next.get("cost_ec", 0)) > 0:
		prog.spend_ec(int(next.get("cost_ec", 0)))
	# Deduct materials
	for ing in next.get("cost_items", []):
		if not (ing is Dictionary):
			continue
		if inv != null:
			inv.remove_item(str(ing.get("item", "")), int(ing.get("qty", 1)))
	level = int(next.get("level", level + 1))
	emit_signal("base_upgraded", level, get_capacity())
	print("[BaseManager] Upgraded to level %d, capacity %d" % [level, get_capacity()])
	return true


# ---------------------------------------------------------------------------
# Residents (dismissed-from-party NPCs that return to base)
# ---------------------------------------------------------------------------

## Returns true if the NPC can be added as a resident. Phase 6 stub:
## always true if level > 0 and capacity not full.
func can_add_resident() -> bool:
	if level <= 0:
		return false
	return residents.size() < get_capacity()


## Adds the NPC id to the residents list. Returns true on success.
func add_resident(npc_id: String) -> bool:
	if not can_add_resident():
		return false
	if npc_id in residents:
		return false
	residents.append(npc_id)
	emit_signal("resident_added", npc_id)
	# If residents >= 20 and no name yet, the UI prompts for a name.
	if residents.size() >= RESIDENT_THRESHOLD_FOR_NAMING and settlement_name.is_empty():
		print("[BaseManager] 20+ residents — ready for settlement naming")
	return true


## Removes an NPC id from the residents list.
func remove_resident(npc_id: String) -> bool:
	for i in residents.size():
		if str(residents[i]) == npc_id:
			residents.remove_at(i)
			emit_signal("resident_removed", npc_id)
			return true
	return false


## Sets the settlement name (Phase 6: player names it at 20+ residents).
## The name is shown on the World Map at the base's hex (Phase 8 wiring).
func set_settlement_name(name: String) -> bool:
	if residents.size() < RESIDENT_THRESHOLD_FOR_NAMING:
		return false
	if name.is_empty():
		return false
	settlement_name = name
	emit_signal("settlement_named", name)
	print("[BaseManager] Settlement named: %s" % name)
	return true


# ---------------------------------------------------------------------------
# Public read accessors
# ---------------------------------------------------------------------------

func get_residents() -> Array:
	return residents.duplicate()


func get_settlement_name() -> String:
	return settlement_name


func get_config() -> Dictionary:
	return _config.duplicate()


func get_upgrades() -> Array:
	return _upgrades.duplicate()


# ---------------------------------------------------------------------------
# Snapshot / restore (save/load in Phase 8)
# ---------------------------------------------------------------------------

func get_snapshot() -> Dictionary:
	return {
		"placement": placement.duplicate(true),
		"level": level,
		"residents": residents.duplicate(),
		"settlement_name": settlement_name,
	}


func restore_from_snapshot(snap: Dictionary) -> void:
	placement = snap.get("placement", {}).duplicate(true)
	level = int(snap.get("level", 0))
	residents = snap.get("residents", []).duplicate()
	for r in residents:
		if not (r is String):
			residents.erase(r)
	settlement_name = str(snap.get("settlement_name", ""))
	if not placement.is_empty():
		emit_signal("base_placed", str(placement.get("hex_key", "")), int(placement.get("local_x", 0)), int(placement.get("local_y", 0)))
