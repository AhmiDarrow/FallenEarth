## CookingTable — Interactable crafting station.
##
## Press E when adjacent to open the CookingTableUI. The UI lists
## recipes whose `station == "cooking_table"` and lets the player
## craft them. Like Worktable / ArmorTable / Blacksmith (deferred),
## this is one of the v0.4.0 crafting stations.
##
## v0.6.0 follow-up: the food consumable (cooked_meat) added in
## v0.6.0 needs a crafting path. Without a station the player
## could only get cooked_meat via drops, which is not enough.
class_name CookingTable
extends Node2D

const STATION_ID := "cooking_table"

var _sprite: Sprite2D


func _ready() -> void:
	_sprite = get_node_or_null("Sprite") as Sprite2D
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite"
		_sprite.centered = true
		add_child(_sprite)
	# Try a procedural sprite path; fall back to a generic box if
	# the asset hasn't been generated yet.
	var path := "res://assets/sprites/stations/cooking_table.png"
	if not ResourceLoader.exists(path):
		path = "res://assets/sprites/stations/_generic.png"
	if ResourceLoader.exists(path):
		_sprite.texture = load(path) as Texture2D
		if _sprite.texture != null:
			_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Returns the cell (Vector2i) of this station.
func get_cell(cell_size: int = 64) -> Vector2i:
	return Vector2i(
		int(floor(global_position.x / cell_size)),
		int(floor(global_position.y / cell_size)),
	)


## Returns the station id used by CraftingManager (matches the
## `station` field on recipes).
func get_station_id() -> String:
	return STATION_ID
