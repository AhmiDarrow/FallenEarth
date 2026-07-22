## FloorPickup — Tiny auto-pickup entity (sticks, stones, etc.).
##
## v0.9.1c: Visual sprite is rendered by MultiMeshResourceVisual in
## LocalMapView, not by this node. The node carries data + interaction
## (item_id, qty, collect()) but has no CanvasItem children.
##
## When the player walks onto the pickup's cell, the item is added to
## their inventory and the node is queue_free()'d. Pickups don't respawn
## (single-shot per map generation; player walks over them once).
class_name FloorPickup
extends Node2D

const INVENTORY_PATH := "/root/InventoryHandler"

@export var item_id: String = ""
@export var item_qty: int = 1

# v0.9.1c: removed _sprite. Visual comes from MultiMeshResourceVisual.
var _collected: bool = false
var _cell: Vector2i = Vector2i(-1, -1)


func _ready() -> void:
	# v0.9.1c: no per-node Sprite2D.
	pass


func setup(p_item_id: String, p_qty: int, cell: Vector2i = Vector2i(-1, -1)) -> void:
	item_id = p_item_id
	item_qty = p_qty
	if cell.x >= 0 and cell.y >= 0:
		_cell = cell
		set_meta("cell", cell)


func _refresh_sprite() -> void:
	# v0.9.1c: no-op.
	pass


func get_item_id() -> String:
	return item_id


func get_item_qty() -> int:
	return item_qty


## Called by HubWorld when the player walks onto the pickup's cell.
## Returns the qty collected (0 if already collected or item_id empty).
func collect() -> int:
	if _collected:
		return 0
	if item_id.is_empty():
		return 0
	_collected = true
	# v0.9.1c: don't queue_free yet — HubWorld hides the visual via
	# LocalMapView.hide_pickup(cell) first, then queue_frees after a
	# brief delay (or just immediately, since the visual is already
	# hidden). We keep the queue_free to clear scene tree state.
	queue_free()
	return item_qty


func get_cell(cell_size: int = 64) -> Vector2i:
	if _cell.x >= 0 and _cell.y >= 0:
		return _cell
	if has_meta("cell"):
		return get_meta("cell") as Vector2i
	var _cs := cell_size
	return Vector2i(
		int(floor(global_position.x / float(_cs))),
		int(floor(global_position.y / float(_cs)))
	)
