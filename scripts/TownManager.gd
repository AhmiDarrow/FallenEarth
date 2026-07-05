## TownManager — Tracks NPC towns and the Riftspire capital.
##
## Phase 3. Reads from `world_data.towns_seeded` and `world_data.riftspire_hex_key`
## (populated by WorldGenerator._place_towns at world-gen time). Provides
## lookup-by-hex helpers and gates Riftspire entry on the player level.
##
## NPCs in towns are tracked in town.npc_ids (a list of NPC IDs that
## will be spawned in town by NPCManager — Phase 5 wires that).
extends Node

const WORLD_DATA_PATH := "/root/GameState"
const RIFTSPIRE_UNLOCK_LEVEL := 50


func _ready() -> void:
	print("[TownManager] Initialized.")


## Returns the list of towns (each is {hex, faction, template, npc_ids})
## that were placed during world-gen.
func get_towns() -> Array:
	var gs: Node = get_node_or_null(WORLD_DATA_PATH)
	if gs == null or not gs.has_world():
		return []
	var wd: Dictionary = gs.get_world_data()
	return wd.get("towns_seeded", [])


## Returns the town dict for a given hex, or {} if not a town.
func get_town_at(hex_key: String) -> Dictionary:
	for t in get_towns():
		if str(t.get("hex", "")) == hex_key:
			return t
	return {}


## True if the given hex is the Riftspire.
func is_riftspire(hex_key: String) -> bool:
	var gs: Node = get_node_or_null(WORLD_DATA_PATH)
	if gs == null or not gs.has_world():
		return false
	var wd: Dictionary = gs.get_world_data()
	return str(wd.get("riftspire_hex_key", "")) == hex_key


## Returns the Riftspire's hex key, or "" if not placed.
func get_riftspire_hex() -> String:
	var gs: Node = get_node_or_null(WORLD_DATA_PATH)
	if gs == null or not gs.has_world():
		return ""
	var wd: Dictionary = gs.get_world_data()
	return str(wd.get("riftspire_hex_key", ""))


## Returns true if the player meets the level requirement to enter
## the Riftspire. The level check is separate from the hex check
## (use is_riftspire(hex_key) to confirm the hex is the capital).
func can_enter_riftspire(player_level: int) -> bool:
	return player_level >= RIFTSPIRE_UNLOCK_LEVEL


## Returns a user-facing reason string when Riftspire entry is blocked,
## or "" if allowed.
func riftspire_block_reason(player_level: int) -> String:
	if player_level >= RIFTSPIRE_UNLOCK_LEVEL:
		return ""
	return "Riftspire is sealed at your level. Reach level %d to enter (current: %d)." % [
		RIFTSPIRE_UNLOCK_LEVEL, player_level
	]


## Get the NPC IDs assigned to a town. Empty list if town not found.
func get_town_npcs(hex_key: String) -> Array:
	var t: Dictionary = get_town_at(hex_key)
	return t.get("npc_ids", [])
