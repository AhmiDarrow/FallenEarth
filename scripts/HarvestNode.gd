## HarvestNode — Gatherable resource entity on the local map.
##
## Holds the JSON entry from data/resource_nodes.json for a single node
## and exposes a try_gather() method that respects the player's equipped
## tool tier. Yields are awarded to the inventory via InventoryManager.
##
## v0.9.1c: The visual sprite is rendered by MultiMeshResourceVisual in
## LocalMapView, not by this node. Per-node Sprite2D + texture load
## was the dominant chunk-load cost (3748 + 1966 = 5714 nodes each
## loading a PNG and adding a Sprite2D = ~1.8 s blocking). The node
## still lives in the scene tree for interaction, but has no
## CanvasItem children — pure data + logic.
##
## Each node has:
##   - a yield (item + qty range) — only if gather_secs > 0
##   - a respawn timer (real-time seconds) — node hides for respawn_secs
##     after depletion, then comes back
##
## A node with gather_secs == 0 is a "decoration" (e.g. toxic pool) — it
## has no yield, no respawn, and the player just walks past it.
class_name HarvestNode
extends Node2D

const INVENTORY_PATH := "/root/InventoryManager"

@export var node_data: Dictionary = {}

# v0.9.1c: removed _sprite. Visual comes from MultiMeshResourceVisual.
var _depleted: bool = false
var _respawn_remaining: float = 0.0


func _ready() -> void:
	# v0.9.1c: no per-node Sprite2D — visuals are batched in a
	# MultiMesh by LocalMapView. Saves ~5714 × load(path) + add_child.
	pass


func setup(data: Dictionary) -> void:
	node_data = data
	# v0.9.1c: no per-node sprite setup; visual is in MultiMesh.


func _refresh_sprite() -> void:
	# v0.9.1c: no-op. The MultiMeshResourceVisual owns the sprite.
	pass


func is_decoration() -> bool:
	return float(node_data.get("gather_secs", 0.0)) <= 0.0


func is_depleted() -> bool:
	return _depleted


func get_gather_secs() -> float:
	return float(node_data.get("gather_secs", 0.0))


func get_respawn_secs() -> float:
	return float(node_data.get("respawn_secs", 0.0))


func get_node_id() -> String:
	return str(node_data.get("id", ""))


## Tool check + yield result.
## Returns a Dictionary describing the result:
##   {ok: bool, reason: String, yield_item: String, yield_qty: int, tool_ok: bool, secs: float}
## The caller (HubWorld) is responsible for the gather timer + awarding
## the yield; this just reports what WOULD happen.
func try_gather(tool_data: Dictionary) -> Dictionary:
	if is_decoration():
		return {"ok": false, "reason": "decoration", "tool_ok": false}
	if _depleted:
		return {"ok": false, "reason": "depleted", "tool_ok": false}

	if tool_data.is_empty():
		return {"ok": false, "reason": "no_tool", "tool_ok": false}

	var harvests: Array = tool_data.get("harvests", [])
	# Wildcard "*" in harvests means "can gather anything" — used for
	# bare-hands gather in Phase 1 before EquipmentManager lands.
	if not harvests.has(get_node_id()) and not harvests.has("*"):
		return {"ok": false, "reason": "wrong_tool", "tool_ok": false}

	var yield_dict: Dictionary = node_data.get("yield", {})
	var yield_item: String = str(yield_dict.get("item", ""))
	var qty_range: Array = yield_dict.get("qty", [1, 1])
	var qty_lo: int = int(qty_range[0]) if qty_range.size() > 0 else 1
	var qty_hi: int = int(qty_range[1]) if qty_range.size() > 1 else qty_lo
	var qty: int = randi_range(qty_lo, qty_hi)
	if int(tool_data.get("bonus_yield", 0)) > 0:
		qty += int(tool_data.get("bonus_yield", 0))

	var secs: float = get_gather_secs() / max(0.01, float(tool_data.get("speed_mult", 1.0)))

	return {
		"ok": true,
		"reason": "",
		"tool_ok": true,
		"yield_item": yield_item,
		"yield_qty": qty,
		"secs": secs,
	}


## Mark the node depleted after a successful gather.
func deplete() -> void:
	_depleted = true
	_respawn_remaining = get_respawn_secs()
	# v0.9.1c: no _sprite.modulate. HubWorld (caller) updates the
	# MultiMesh visual via LocalMapView.dim_resource_node(cell, true).


## Respawn tick (real-time). Returns true if respawn completed this frame.
func _process(delta: float) -> void:
	if not _depleted:
		return
	_respawn_remaining -= delta
	if _respawn_remaining <= 0.0:
		_depleted = false
		_respawn_remaining = 0.0
		# v0.9.1c: no _sprite.modulate. HubWorld (caller) updates the
		# MultiMesh visual via LocalMapView.dim_resource_node(cell, false).


## Returns the cell (Vector2i) of this node, computed from its world position.
## Assumes CELL_SIZE == 24 (matches TileSetService.CELL_SIZE).
func get_cell(cell_size: int = 24) -> Vector2i:
	return Vector2i(
		int(floor(global_position.x / cell_size)),
		int(floor(global_position.y / cell_size)),
	)
