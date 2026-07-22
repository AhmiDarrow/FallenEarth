## SettlementNode — The exterior structure of a settlement on the
## world map. Larger than the player's base (which lands in Phase 6).
##
## Placed by `LocalMapGenerator` from `data/towns.json` via
## `WorldGenerator._place_towns`. Visually a compound sprite (multi-
## building) sized per the town's template (small_outpost, medium_
## settlement, large_hub). Interactable — pressing E adjacent enters
## the settlement interior (handled by HubWorld._try_enter_settlement).
class_name SettlementNode
extends Node2D

const SIZE_TILES := {
	"small":  [4, 4],
	"medium": [6, 6],
	"large":  [10, 10],
}

const TEMPLATE_NAMES := {
	"small_outpost": "Outpost",
	"medium_settlement": "Settlement",
	"large_hub": "Hub",
}

@export var town_data: Dictionary = {}

var _sprite: Sprite2D
var _label: Label
var _size_cells: Vector2i = Vector2i(4, 4)


func _ready() -> void:
	_sprite = get_node_or_null("Sprite") as Sprite2D
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite"
		_sprite.centered = true
		add_child(_sprite)
	_label = get_node_or_null("Label") as Label
	if _label == null:
		_label = Label.new()
		_label.name = "Label"
		_label.add_theme_color_override("font_color", Color.WHITE)
		_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_label.add_theme_constant_override("outline_size", 3)
		_label.add_theme_font_size_override("font_size", 12)
		_label.position = Vector2(-32, -48)
		_label.size = Vector2(64, 16)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_label)
	_refresh_sprite()


func setup(data: Dictionary) -> void:
	town_data = data
	var tpl_id: String = str(data.get("template", "medium_settlement"))
	var size_key: String = str(data.get("size", "medium"))
	_size_cells = Vector2i(SIZE_TILES.get(size_key, [4, 4])[0], SIZE_TILES.get(size_key, [4, 4])[1])
	_refresh_sprite()


func _refresh_sprite() -> void:
	if _sprite == null:
		return
	var sprite_id: String = "settlement_%s" % str(town_data.get("size", "medium"))
	var path := "res://assets/sprites/settlements/%s.png" % sprite_id
	if not ResourceLoader.exists(path):
		# Fallback to a generic icon
		path = "res://assets/sprites/settlements/_generic.png"
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			_sprite.texture = tex
			_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Label
	if _label != null:
		var name: String = str(town_data.get("template_name", "Settlement"))
		_label.text = "%s" % name


func get_cell(cell_size: int = 64) -> Vector2i:
	if has_meta("cell"):
		return get_meta("cell") as Vector2i
	var _cs := cell_size
	return Vector2i(
		int(floor(global_position.x / float(_cs))),
		int(floor(global_position.y / float(_cs))),
	)


func get_size_cells() -> Vector2i:
	return _size_cells
