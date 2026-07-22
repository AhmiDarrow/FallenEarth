## HarvestNode — Gatherable resource entity on the local map.
##
## Holds the JSON entry from data/resource_nodes.json for a single node
## and exposes a try_gather() method that respects the player's equipped
## tool tier. Yields are awarded to the inventory via InventoryHandler.
##
## v0.9.1c: The visual sprite is rendered by MultiMeshResourceVisual in
## LocalMapView, not by this node. Per-node Sprite2D + texture load
## was the dominant chunk-load cost (3748 + 1966 = 5714 nodes each
## loading a PNG and adding a Sprite2D = ~1.8 s blocking). The node
## still lives in the scene tree for interaction, but has no
## CanvasItem children — pure data + logic.
##
## Each node has:
##   - a yield (item_id + count range) — only if gather_secs > 0
##   - a respawn timer (real-time seconds) — node hides for respawn_secs
##     after depletion, then comes back
##
## A node with gather_secs == 0 is a "decoration" (e.g. toxic pool) — it
## has no yield, no respawn, and the player just walks past it.
##
## Tool matching (tools.json harvests entries):
##   - exact id: "iron_outcrop"
##   - prefix: "withered_oak" matches "withered_oak_ash"
##   - category tag: "#trees", "#ore", "#rocks", "#formations", "#crystals"
##   - wildcard: "*"
class_name HarvestNode
extends Node2D

const INVENTORY_PATH := "/root/InventoryHandler"

@export var node_data: Dictionary = {}

var _depleted: bool = false
var _respawn_remaining: float = 0.0


func _ready() -> void:
	pass


func setup(data: Dictionary) -> void:
	node_data = data
	_sync_collision_shape()


func _refresh_sprite() -> void:
	pass


## Match Area2D footprint to the visual base (RVM bottom-aligns sprites).
func _sync_collision_shape() -> void:
	var shape_node := get_node_or_null("Area2D/CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	var sprite_id: String = str(node_data.get("sprite", ""))
	var scale_val := 1.0
	var radius := 18.0
	var foot_y := 0.0
	if sprite_id.begins_with("tree_"):
		scale_val = 1.5
		radius = 22.0
		foot_y = 4.0
	elif sprite_id.begins_with("formation_"):
		scale_val = 1.25
		radius = 24.0
		foot_y = 3.0
	elif sprite_id.begins_with("ore_") or sprite_id.begins_with("crystal_"):
		scale_val = 0.9
		radius = 16.0
		foot_y = 2.0
	elif sprite_id.begins_with("decor_rock"):
		radius = 20.0
		foot_y = 2.0
	elif sprite_id.begins_with("decor_"):
		scale_val = 0.95
		radius = 16.0
		foot_y = 1.0
	var circle := CircleShape2D.new()
	circle.radius = radius * scale_val
	shape_node.shape = circle
	# Feet sit near node origin (cell center); keep collider on the base, not canopy.
	shape_node.position = Vector2(0.0, foot_y)


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


func get_category() -> String:
	return str(node_data.get("category", ""))


## Whether tool_data.harvests can gather this node id/category.
static func tool_can_harvest(tool_data: Dictionary, node_id: String, category: String = "") -> bool:
	if tool_data.is_empty():
		return false
	var harvests: Array = tool_data.get("harvests", [])
	if harvests.is_empty():
		return false
	if harvests.has("*") or harvests.has(node_id):
		return true
	if not category.is_empty() and harvests.has("#" + category):
		return true
	for h in harvests:
		var hs := str(h)
		if hs.is_empty() or hs.begins_with("#"):
			continue
		if node_id == hs or node_id.begins_with(hs + "_"):
			return true
	return false


## Human-readable tool requirement for UI tips.
static func required_tool_type(category: String, node_id: String = "") -> String:
	match category:
		"trees":
			return "Axe"
		"ore", "rocks", "formations", "crystals":
			return "Pickaxe"
		_:
			if node_id.find("outcrop") >= 0 or node_id.find("rock") >= 0 \
					or node_id.find("ore") >= 0 or node_id.find("shard") >= 0 \
					or node_id.find("geode") >= 0 or node_id.find("pipe") >= 0 \
					or node_id.find("rubble") >= 0 or node_id.find("container") >= 0:
				return "Pickaxe"
			return "Axe"


## Tool check + yield result.
## Returns a Dictionary describing the result:
##   {ok: bool, reason: String, yield_item: String, yield_qty: int, tool_ok: bool, secs: float}
func try_gather(tool_data: Dictionary) -> Dictionary:
	if is_decoration():
		return {"ok": false, "reason": "decoration", "tool_ok": false}
	if _depleted:
		return {"ok": false, "reason": "depleted", "tool_ok": false}

	if tool_data.is_empty():
		return {"ok": false, "reason": "no_tool", "tool_ok": false}

	var node_id := get_node_id()
	var category := get_category()
	if not tool_can_harvest(tool_data, node_id, category):
		return {"ok": false, "reason": "wrong_tool", "tool_ok": false}

	var yield_dict: Dictionary = node_data.get("yield", {})
	if yield_dict.is_empty() or yield_dict == null:
		return {"ok": false, "reason": "decoration", "tool_ok": false}
	var yield_item: String = str(yield_dict.get("item_id", ""))
	if yield_item.is_empty():
		return {"ok": false, "reason": "decoration", "tool_ok": false}
	var qty_range: Array = yield_dict.get("count", [1, 1])
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


func deplete() -> void:
	_depleted = true
	_respawn_remaining = get_respawn_secs()


func _process(delta: float) -> void:
	if not _depleted:
		return
	_respawn_remaining -= delta
	if _respawn_remaining <= 0.0:
		_depleted = false
		_respawn_remaining = 0.0


func get_cell(cell_size: int = 64) -> Vector2i:
	# Prefer stored grid coords — position.y includes height_band offset so
	# floor(pos/cell_size) drifts by ~1 cell per elevation step.
	if node_data.has("x") and node_data.has("y"):
		return Vector2i(int(node_data.x), int(node_data.y))
	if has_meta("cell"):
		return get_meta("cell") as Vector2i
	var _cs := cell_size
	return Vector2i(
		int(floor(global_position.x / float(_cs))),
		int(floor(global_position.y / float(_cs))),
	)
