## SettlementManager — Manages the active settlement interior instance.
##
## Phase 3. Mirrors the player-base pattern (Phase 6 will use the
## same flow): when the player presses E adjacent to a SettlementNode
## on the world map, the overworld is hidden and a Settlement interior
## scene is instantiated. When the player leaves (via the in-interior
## "Leave" button or by pressing E near the entrance tile), the
## overworld is restored and the interior is freed.
##
## State:
##   - `active_settlement_hex: String` — the hex key of the active
##     settlement, or "" if not in a settlement
##   - `active_settlement_data: Dictionary` — the town dict from
##     world_data.towns_seeded
##   - `interior: Control` — the loaded Settlement.tscn instance
##
## Signals:
##   - entered_settlement(hex_key, town_data)
##   - left_settlement(hex_key)
##
## Persistence: like the rest of the Phase 3 managers, this is not
## persistent yet. GameState.SaveManager is the canonical layer
## (Phase 8 will include the active settlement).
extends Node

signal entered_settlement(hex_key: String, town_data: Dictionary)
signal left_settlement(hex_key: String)

const SETTLEMENT_SCENE := "res://scenes/SettlementInterior.tscn"

const WORLD_DATA_PATH := "/root/GameState"

var active_settlement_hex: String = ""
var active_settlement_data: Dictionary = {}
var interior: Control = null


func _ready() -> void:
	print("[SettlementManager] Initialized.")


## True if the player is currently inside a settlement interior.
func is_inside_settlement() -> bool:
	return not active_settlement_hex.is_empty()


## Enter a settlement. Looks up the town by hex in world_data.towns_seeded,
## instantiates the Settlement scene, hides the HubWorld's world, and
## shows the interior. Returns true on success.
##
## v0.7.1 polish: trigger the procedural NPC spawn (party.spawn_for_settlement)
## at enter time so the Settlement scene shows biome+faction-flavored
## residents from the moment the player walks in.
func enter_settlement(hex_key: String, hub: Node, focus_building: String = "") -> bool:
	if is_inside_settlement():
		push_warning("[SettlementManager] Already inside a settlement; ignore")
		return false
	var gs: Node = get_node_or_null(WORLD_DATA_PATH)
	if gs == null or not gs.has_world():
		return false
	var wd: Dictionary = gs.get_world_data()
	var towns: Array = wd.get("towns_seeded", [])
	var town: Dictionary = {}
	for t in towns:
		if str(t.get("hex", "")) == hex_key:
			town = t
			break
	if town.is_empty():
		push_warning("[SettlementManager] Hex %s is not a town" % hex_key)
		return false
	# v0.7.1 fix: load the scene as a PackedScene (not a GDScript). The
	# previous `as GDScript` cast was wrong — .tscn files load as
	# PackedScene. Use PackedScene.instantiate() to get the scene root.
	var packed: PackedScene = load(SETTLEMENT_SCENE) as PackedScene
	if packed == null:
		push_error("[SettlementManager] Missing Settlement scene: %s" % SETTLEMENT_SCENE)
		return false
	active_settlement_hex = hex_key
	active_settlement_data = town
	interior = packed.instantiate()
	interior.name = "Settlement_%s" % hex_key.replace(",", "_")
	interior.setup(town, hub, focus_building)
	# Find a CanvasLayer in HubWorld to host the interior
	if hub != null and is_instance_valid(hub):
		hub.add_child(interior)
	# v0.7.1 polish: trigger the procedural NPC spawn (party.spawn_for_settlement)
	# at enter time so the Settlement scene shows biome+faction-flavored
	# residents from the moment the player walks in.
	var pm: Node = get_node_or_null("/root/PartyNPCManager")
	if pm != null and pm.has_method("spawn_for_settlement"):
		var biome: String = str(town.get("biome", ""))
		if biome.is_empty():
			biome = "Ash Wastes"  # fallback
		var faction: String = str(town.get("faction", ""))
		var size_str: String = str(town.get("size", "medium"))
		var spawned: Array = pm.spawn_for_settlement(hex_key, biome, faction, size_str)
		for n in spawned:
			print("[SettlementManager] Spawned resident %s in settlement %s" % [
				n.get("name", "?"), hex_key
			])
	emit_signal("entered_settlement", hex_key, town)
	print("[SettlementManager] Entered settlement %s (%s, %s, %s)" % [
		hex_key, town.get("template_name", "?"), town.get("faction", "?"), town.get("biome", "?")
	])
	return true


## Leave the active settlement. Tears down the interior, shows the
## HubWorld world, fires `left_settlement`.
func leave_settlement() -> void:
	if not is_inside_settlement():
		return
	var hex: String = active_settlement_hex
	if is_instance_valid(interior):
		interior.queue_free()
	interior = null
	active_settlement_hex = ""
	active_settlement_data = {}
	emit_signal("left_settlement", hex)
	print("[SettlementManager] Left settlement %s" % hex)


## Returns the town data for the active settlement (or {}).
func get_active_town() -> Dictionary:
	return active_settlement_data.duplicate()
