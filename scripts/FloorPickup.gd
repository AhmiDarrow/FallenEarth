## FloorPickup — Tiny auto-pickup entity (sticks, stones, etc.).
##
## When the player walks onto the pickup's cell, the item is added to
## their inventory and the node is queue_free()'d. Pickups don't respawn
## (single-shot per map generation; player walks over them once).
class_name FloorPickup
extends Node2D

const INVENTORY_PATH := "/root/InventoryManager"

@export var item_id: String = ""
@export var item_qty: int = 1

var _sprite: Sprite2D
var _collected: bool = false


func _ready() -> void:
	_sprite = get_node_or_null("Sprite") as Sprite2D
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite"
		_sprite.centered = true
		add_child(_sprite)
	_refresh_sprite()


func setup(p_item_id: String, p_qty: int) -> void:
	item_id = p_item_id
	item_qty = p_qty
	_refresh_sprite()


func _refresh_sprite() -> void:
	if _sprite == null:
		return
	if item_id.is_empty():
		return
	var path := "res://assets/sprites/floor_pickups/%s.png" % item_id
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			_sprite.texture = tex
			_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


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
	queue_free()
	return item_qty


func get_cell(cell_size: int = 24) -> Vector2i:
	return Vector2i(
		int(floor(global_position.x / cell_size)),
		int(floor(global_position.y / cell_size)),
	)
