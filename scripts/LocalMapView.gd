## LocalMapView — Renders a 512x512 local playfield via a Godot 4.3 TileMapLayer.
##
## One scene per HubWorld. configure(map_data) paints all cells of a generated
## local map into the TileMapLayer using a biome-specific TileSet built by
## TileSetService. Marker/mob layers sit on top of the terrain. No sprite
## batching, no procedural drawing — Godot 4.3 TileMap handles 512x512 (~262k
## cells) at 60 fps without chunking.
class_name LocalMapView
extends Node2D

const TileSetSvc = preload("res://scripts/TileSetService.gd")
const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")

const CELL_SIZE := 24

var ground_layer: TileMapLayer
var marker_layer: Node2D
var mob_layer: Node2D

var _current_biome: String = ""


func _ready() -> void:
	ground_layer = get_node_or_null("Ground") as TileMapLayer
	marker_layer = get_node_or_null("MarkerLayer") as Node2D
	mob_layer = get_node_or_null("MobLayer") as Node2D
	# Mob layer is y-sorted so entities stack correctly with the player.
	if is_instance_valid(mob_layer):
		mob_layer.y_sort_enabled = true


func configure(map_data: Dictionary) -> void:
	if not is_instance_valid(ground_layer):
		push_error("[LocalMapView] Ground TileMapLayer missing in scene.")
		return

	_clear_ground()
	_clear_markers()
	_clear_mobs()

	var biome_name: String = str(map_data.get("biome", "Ash Wastes"))
	_current_biome = biome_name

	var tile_set := TileSetSvc.create_for_biome(biome_name)
	if tile_set == null:
		push_error("[LocalMapView] TileSet build failed for biome: %s" % biome_name)
		return
	ground_layer.tile_set = tile_set

	var size: int = int(map_data.get("size", LocalMapGen.MAP_SIZE))
	var terrain: PackedByteArray = map_data.get("terrain", PackedByteArray())
	if terrain.is_empty():
		return

	for y in size:
		for x in size:
			var t := int(terrain[y * size + x])
			ground_layer.set_cell(Vector2i(x, y), 0, TileSetSvc.atlas_coords(t))


func get_cell_size() -> int:
	return CELL_SIZE


func get_ground_layer() -> TileMapLayer:
	return ground_layer


func get_marker_layer() -> Node2D:
	return marker_layer


func get_mob_layer() -> Node2D:
	return mob_layer


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL_SIZE + CELL_SIZE * 0.5, cell.y * CELL_SIZE + CELL_SIZE * 0.5)


## Drop a text+color-rect marker on the map. `kind` is a free-form tag used by
## HubWorld to track / refresh markers between frames.
func add_marker(cell: Vector2i, color: Color, symbol: String, kind: String) -> Node2D:
	if not is_instance_valid(marker_layer):
		return null
	var holder := Node2D.new()
	holder.name = "Marker_%s_%d_%d" % [kind, cell.x, cell.y]
	holder.position = cell_to_world(cell)
	holder.z_index = 100

	var bg := ColorRect.new()
	bg.name = "BG"
	bg.color = color
	bg.size = Vector2(18, 18)
	bg.position = Vector2(-9, -9)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bg)

	var label := Label.new()
	label.name = "Glyph"
	label.text = symbol
	label.add_theme_color_override("font_color", Color(0, 0, 0))
	label.add_theme_color_override("font_outline_color", Color(1, 1, 1))
	label.add_theme_constant_override("outline_size", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-12, -10)
	label.size = Vector2(24, 20)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(label)

	marker_layer.add_child(holder)
	return holder


func clear_markers() -> void:
	_clear_markers()


func clear_mobs() -> void:
	_clear_mobs()


func _clear_ground() -> void:
	if is_instance_valid(ground_layer):
		ground_layer.clear()


func _clear_markers() -> void:
	if is_instance_valid(marker_layer):
		for child in marker_layer.get_children():
			child.queue_free()


func _clear_mobs() -> void:
	if is_instance_valid(mob_layer):
		for child in mob_layer.get_children():
			child.queue_free()
