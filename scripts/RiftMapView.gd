class_name RiftMapView
extends Node2D

const RiftTileSetSvc = preload("res://scripts/RiftTileSetService.gd")
const FogOfWarScript = preload("res://scripts/FogOfWar.gd")
const DungeonGen = preload("res://scripts/RiftDungeonGenerator.gd")

enum TileType { FLOOR, WALL, DECOR }

var ground_layer: TileMapLayer
var marker_layer: Node2D
var player_sprite: Node2D
var camera: Camera2D
var fog_of_war: FogOfWarScript = null

var _current_biome: String = ""
var _dungeon_data: Dictionary = {}
var _markers: Dictionary = {}


func _ready() -> void:
	ground_layer = get_node_or_null("Ground") as TileMapLayer
	marker_layer = get_node_or_null("MarkerLayer") as Node2D
	player_sprite = get_node_or_null("PlayerSprite") as Node2D
	camera = get_node_or_null("Camera2D") as Camera2D
	if player_sprite == null:
		player_sprite = Node2D.new()
		player_sprite.name = "PlayerSprite"
		add_child(player_sprite)
	if camera != null and player_sprite != null:
		if camera.has_method("set_target") or camera.has_method("set"):  # FollowCamera
			camera.set("target", player_sprite)


func configure(dungeon: Dictionary, biome_name: String) -> void:
	if not is_instance_valid(ground_layer):
		return
	_current_biome = biome_name
	_dungeon_data = dungeon
	ground_layer.clear()
	if is_instance_valid(marker_layer):
		_clear_markers()

	var tile_set := RiftTileSetSvc.create_for_biome(biome_name)
	if tile_set == null:
		return
	ground_layer.tile_set = tile_set

	var width: int = dungeon.get("width", 31)
	var height: int = dungeon.get("height", 23)
	var tiles: Dictionary = dungeon.get("tiles", {})

	for y in range(height):
		for x in range(width):
			var key := "%d,%d" % [x, y]
			var cell_data: Dictionary = tiles.get(key, {"type": DungeonGen.TILE_WALL})
			var t: String = str(cell_data.get("type", DungeonGen.TILE_WALL))
			var tile_id := TileType.FLOOR
			if t == DungeonGen.TILE_WALL:
				tile_id = TileType.WALL
			elif t == DungeonGen.TILE_DECOR:
				tile_id = TileType.DECOR
			ground_layer.set_cell(Vector2i(x, y), 0, RiftTileSetSvc.atlas_coords(tile_id))

	_place_markers(dungeon, width, height)
	_setup_fog_of_war(width, height)


func _place_markers(dungeon: Dictionary, width: int, height: int) -> void:
	if not is_instance_valid(marker_layer):
		return
	var tiles: Dictionary = dungeon.get("tiles", {})
	for y in range(height):
		for x in range(width):
			var key := "%d,%d" % [x, y]
			var cell_data: Dictionary = tiles.get(key, {})
			var t: String = str(cell_data.get("type", ""))
			if t == DungeonGen.TILE_ENCOUNTER:
				if not bool(cell_data.get("cleared", false)):
					_add_marker(Vector2i(x, y), Color(0.85, 0.15, 0.15), "⚔")
			elif t == DungeonGen.TILE_BOSS:
				if not bool(dungeon.get("boss_defeated", false)):
					_add_marker(Vector2i(x, y), Color(0.9, 0.05, 0.05), "☠")
			elif t == DungeonGen.TILE_CORE:
				var locked := bool(cell_data.get("locked", true))
				var sym := "◆" if locked else "◇"
				_add_marker(Vector2i(x, y), Color(0.4, 0.2, 0.7), sym)
			elif t == DungeonGen.TILE_ENTRANCE:
				_add_marker(Vector2i(x, y), Color(0.2, 0.7, 0.3), "◈")


func _add_marker(cell: Vector2i, color: Color, symbol: String) -> Node2D:
	if not is_instance_valid(marker_layer):
		return null
	var holder := Node2D.new()
	holder.name = "Marker_%d_%d" % [cell.x, cell.y]
	holder.position = _cell_to_world(cell)
	holder.z_index = 100

	var bg := ColorRect.new()
	bg.name = "BG"
	bg.color = color
	bg.size = Vector2(16, 16)
	bg.position = Vector2(-8, -8)
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
	label.position = Vector2(-10, -8)
	label.size = Vector2(20, 16)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(label)

	marker_layer.add_child(holder)
	_markers["%d,%d" % [cell.x, cell.y]] = holder
	return holder


func refresh_markers(dungeon: Dictionary) -> void:
	_clear_markers()
	var width: int = dungeon.get("width", 31)
	var height: int = dungeon.get("height", 23)
	_place_markers(dungeon, width, height)


func _setup_fog_of_war(width: int, height: int) -> void:
	if fog_of_war == null or not is_instance_valid(fog_of_war):
		fog_of_war = FogOfWarScript.new()
		fog_of_war.name = "FogOfWar"
		add_child(fog_of_war)
	if is_instance_valid(ground_layer):
		var reveal_radius := 4
		if width >= 128:
			reveal_radius = 5
		if width >= 256:
			reveal_radius = 6
		fog_of_war.setup(ground_layer, width, height, reveal_radius)


func reveal_around_player(cell: Vector2i) -> void:
	if fog_of_war != null and is_instance_valid(fog_of_war):
		fog_of_war.reveal_around(cell)


func _clear_markers() -> void:
	if not is_instance_valid(marker_layer):
		return
	for child in marker_layer.get_children():
		child.queue_free()
	_markers.clear()


func set_player_cell(cell: Vector2i) -> void:
	if is_instance_valid(player_sprite):
		player_sprite.position = _cell_to_world(cell)


func get_player_cell() -> Vector2i:
	if not is_instance_valid(player_sprite):
		return Vector2i.ZERO
	var p := player_sprite.position
	var cell_size := RiftTileSetSvc.CELL_SIZE
	return Vector2i(int(round(p.x / cell_size)), int(round(p.y / cell_size)))


static func _cell_to_world(cell: Vector2i) -> Vector2:
	var cell_size := RiftTileSetSvc.CELL_SIZE
	return Vector2(cell.x * cell_size + cell_size * 0.5, cell.y * cell_size + cell_size * 0.5)


func get_ground_layer() -> TileMapLayer:
	return ground_layer


func get_marker_layer() -> Node2D:
	return marker_layer


func get_fog_of_war() -> Node:
	return fog_of_war
