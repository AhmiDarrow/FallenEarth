## SleepingBag — Placeable respawn point.
## Press E when adjacent to set this bag as the active respawn point
## or pick it back up into inventory. Follows the CookingTable pattern.
class_name SleepingBag extends Node2D

func _ready() -> void:
	var sprite := get_node_or_null("Sprite") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite"
		sprite.centered = true
		add_child(sprite)
	var path := "res://assets/sprites/stations/sleeping_bag.png"
	if not ResourceLoader.exists(path):
		path = "res://assets/sprites/stations/_generic.png"
	if ResourceLoader.exists(path):
		sprite.texture = load(path) as Texture2D
		if sprite.texture != null:
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func get_cell(cell_size: int = 64) -> Vector2i:
	if has_meta("cell"):
		return get_meta("cell") as Vector2i
	var _cs := cell_size
	return Vector2i(
		int(floor(global_position.x / float(_cs))),
		int(floor(global_position.y / float(_cs))),
	)
