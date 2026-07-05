## SettlementBuilding — Visual representation of a building on the local map.
##
## Placed by LocalMapView._populate_buildings() from map_data["settlement"]["structures"].
## Each building is a Sprite2D + Label on the settlement_layer. The player can
## walk up to the entrance cell and press E to interact (open shop, mission board,
## or enter the settlement interior).
class_name SettlementBuilding
extends Node2D

const CELL_SIZE := 24

var building_id: String = ""
var role: String = ""
var sprite_id: String = ""
var label_text: String = ""
var entrance_cell: Vector2i = Vector2i(-1, -1)
var building_rect: Rect2i = Rect2i(0, 0, 0, 0)

var _sprite: Sprite2D
var _label: Label


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)

	_label = Label.new()
	_label.name = "Label"
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 2)
	_label.add_theme_font_size_override("font_size", 10)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

	_refresh_visual()


func setup(data: Dictionary) -> void:
	building_id = str(data.get("id", ""))
	role = str(data.get("role", "vendor"))
	sprite_id = str(data.get("sprite", building_id))
	label_text = str(data.get("label", building_id))

	var bx: int = int(data.get("x", 0))
	var by: int = int(data.get("y", 0))
	var bw: int = int(data.get("w", 2))
	var bh: int = int(data.get("h", 2))

	building_rect = Rect2i(bx, by, bw, bh)
	position = Vector2(bx * CELL_SIZE, by * CELL_SIZE)

	var ex: int = int(data.get("entrance_x", bx + bw / 2))
	var ey: int = int(data.get("entrance_y", by + bh))
	entrance_cell = Vector2i(ex, ey)

	_refresh_visual()


func _refresh_visual() -> void:
	if _sprite == null:
		return
	if sprite_id.is_empty():
		return
	var path := "res://assets/sprites/buildings/%s.png" % sprite_id
	if FileAccess.file_exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			_sprite.texture = tex
	# Label below the building
	if _label != null:
		_label.text = label_text
		var bw: int = building_rect.size.x
		_label.position = Vector2(0, building_rect.size.y * CELL_SIZE + 2)
		_label.size = Vector2(bw * CELL_SIZE, 14)


## Returns true if the given cell is inside this building's footprint.
func is_cell_inside(cell: Vector2i) -> bool:
	return building_rect.has_point(cell)


## Returns the entrance cell (where the player stands to interact).
func get_entrance_cell() -> Vector2i:
	return entrance_cell


## Returns the building's role string (e.g. "trader", "crafter").
func get_role() -> String:
	return role


## Returns the building's ID (e.g. "tavern", "worktable").
func get_building_id() -> String:
	return building_id
