## LocalMapView — Renders a 512x512 local playfield via a Godot 4.3 TileMapLayer.
##
## One scene per HubWorld. configure(map_data) paints all cells of a generated
## local map into the TileMapLayer using a biome-specific TileSet built by
## TileSetService. Marker/mob/node/floor-pickup layers sit on top of the terrain.
## No sprite batching, no procedural drawing — Godot 4.3 TileMap handles
## 512x512 (~262k cells) at 60 fps without chunking.
class_name LocalMapView
extends Node2D

const TileSetSvc = preload("res://scripts/TileSetService.gd")
const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")
const HarvestNodeScript = preload("res://scripts/HarvestNode.gd")
const FloorPickupScript = preload("res://scripts/FloorPickup.gd")
const SettlementNodeScript = preload("res://scripts/SettlementNode.gd")
const CookingTableScript = preload("res://scripts/CookingTable.gd")
const HarvestNodeScene = preload("res://scenes/HarvestNode.tscn")
const FloorPickupScene = preload("res://scenes/FloorPickup.tscn")
const SettlementNodeScene = preload("res://scenes/SettlementNode.tscn")
const CookingTableScene = preload("res://scenes/CookingTable.tscn")

const CELL_SIZE := 24

var ground_layer: TileMapLayer
var marker_layer: Node2D
var mob_layer: Node2D
var node_layer: Node2D
var pickup_layer: Node2D
var settlement_layer: Node2D
var station_layer: Node2D

var _current_biome: String = ""


func _ready() -> void:
	ground_layer = get_node_or_null("Ground") as TileMapLayer
	marker_layer = get_node_or_null("MarkerLayer") as Node2D
	mob_layer = get_node_or_null("MobLayer") as Node2D
	node_layer = get_node_or_null("NodeLayer") as Node2D
	pickup_layer = get_node_or_null("PickupLayer") as Node2D
	settlement_layer = get_node_or_null("SettlementLayer") as Node2D
	# Mob layer is y-sorted so entities stack correctly with the player.
	if is_instance_valid(mob_layer):
		mob_layer.y_sort_enabled = true
	# Node/pickup layers sit above the ground but below the player visual
	# so y-sort in MobLayer still layers entities on top.
	if is_instance_valid(node_layer):
		node_layer.y_sort_enabled = true
	if is_instance_valid(pickup_layer):
		pickup_layer.y_sort_enabled = true
	if is_instance_valid(settlement_layer):
		settlement_layer.y_sort_enabled = true
	if is_instance_valid(station_layer):
		station_layer.y_sort_enabled = true


func configure(map_data: Dictionary) -> void:
	if not is_instance_valid(ground_layer):
		push_error("[LocalMapView] Ground TileMapLayer missing in scene.")
		return

	_clear_ground()
	_clear_markers()
	_clear_mobs()
	_clear_nodes()
	_clear_pickups()

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
			# Normalize legacy rift_scar=4 cells to ground (v0.4.0 Phase 0).
			if t < 0 or t > TileSetSvc.TERRAIN_BLOCKED:
				t = TileSetSvc.TERRAIN_GROUND
			ground_layer.set_cell(Vector2i(x, y), 0, TileSetSvc.atlas_coords(t))

	# Spawn resource nodes (trees, formations, ore, crystals, fauna)
	_populate_resource_nodes(map_data.get("resource_nodes", []))
	# Spawn floor pickups (sticks, stones)
	_populate_floor_pickups(map_data.get("floor_pickups", []))
	# Spawn cooking tables (Phase 3 follow-up: cooking station)
	_populate_cooking_tables(map_data.get("cooking_tables", []))
	# Spawn settlement structures (Phase 3: NPC towns). The settlement
	# data comes from world_data.towns_seeded; we look that up via
	# GameState. Each town is placed at its hex key (the player walks
	# adjacent and presses E to enter the interior).
	_populate_settlements(_get_world_towns())


func _get_world_towns() -> Array:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null or not gs.has_world():
		return []
	var wd: Dictionary = gs.get_world_data()
	return wd.get("towns_seeded", [])


func _populate_settlements(towns: Array) -> void:
	if not is_instance_valid(settlement_layer):
		return
	for entry in towns:
		if not (entry is Dictionary):
			continue
		var node: Node2D = SettlementNodeScene.instantiate()
		settlement_layer.add_child(node)
		node.setup((entry as Dictionary).duplicate(true))
		# Set the cell from the hex key
		var hex_str: String = str(entry.get("hex", ""))
		var parts: PackedStringArray = hex_str.split(",")
		if parts.size() == 2:
			node.position = cell_to_world(Vector2i(int(parts[0]), int(parts[1])))
			# Tag the node with the hex key for hit-test lookup
			node.set_meta("hex", hex_str)


## Returns the SettlementNode at the given cell, or null.
func get_settlement_at(cell: Vector2i) -> Node2D:
	if not is_instance_valid(settlement_layer):
		return null
	for child in settlement_layer.get_children():
		if child.get_script() != SettlementNodeScript:
			continue
		var p: Vector2 = child.global_position
		var cx: int = int(floor(p.x / CELL_SIZE))
		var cy: int = int(floor(p.y / CELL_SIZE))
		if cx == cell.x and cy == cell.y:
			return child
	return null


## v0.6.0 follow-up: populate cooking table stations on the map.
## The `tables` array contains {x, y, station_id} dicts (station_id is
## always "cooking_table" for v0.6.0; future phases may add more).
func _populate_cooking_tables(tables: Array) -> void:
	if not is_instance_valid(station_layer):
		return
	for entry in tables:
		if not (entry is Dictionary):
			continue
		var node: Node2D = CookingTableScene.instantiate()
		station_layer.add_child(node)
		node.position = cell_to_world(Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0))))


## Returns the CookingTable at the given cell, or null.
func get_cooking_table_at(cell: Vector2i) -> Node2D:
	if not is_instance_valid(station_layer):
		return null
	for child in station_layer.get_children():
		if not (child is Node2D):
			continue
		if not child.has_method("get_station_id"):
			continue
		var p: Vector2 = child.global_position
		var cx: int = int(floor(p.x / CELL_SIZE))
		var cy: int = int(floor(p.y / CELL_SIZE))
		if cx == cell.x and cy == cell.y:
			return child
	return null


## Returns the station layer (for HubWorld to query stations).
func get_station_layer() -> Node2D:
	return station_layer


func _populate_resource_nodes(nodes: Array) -> void:
	if not is_instance_valid(node_layer):
		return
	for entry in nodes:
		if not (entry is Dictionary):
			continue
		var node: Node2D = HarvestNodeScene.instantiate()
		node_layer.add_child(node)
		node.setup((entry as Dictionary).duplicate(true))
		node.position = cell_to_world(Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0))))


func _populate_floor_pickups(pickups: Array) -> void:
	if not is_instance_valid(pickup_layer):
		return
	for entry in pickups:
		if not (entry is Dictionary):
			continue
		var pickup: Node2D = FloorPickupScene.instantiate()
		pickup_layer.add_child(pickup)
		pickup.setup(str(entry.get("id", "")), int(entry.get("qty", 1)))
		pickup.position = cell_to_world(Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0))))


func get_resource_nodes() -> Array:
	# Returns the live HarvestNode nodes currently in node_layer.
	if not is_instance_valid(node_layer):
		return []
	var out: Array = []
	for child in node_layer.get_children():
		if child is Node2D and child.get_script() == HarvestNodeScript:
			out.append(child)
	return out


func get_floor_pickups() -> Array:
	# Returns the live FloorPickup nodes currently in pickup_layer.
	if not is_instance_valid(pickup_layer):
		return []
	var out: Array = []
	for child in pickup_layer.get_children():
		if child is Node2D and child.get_script() == FloorPickupScript:
			out.append(child)
	return out


## Iterate every HarvestNode within `radius` cells of the player's cell.
## Returns Array of {node: HarvestNode, cell: Vector2i, dist: int}.
func get_resource_nodes_near(player_cell: Vector2i, radius: int) -> Array:
	var out: Array = []
	for child in get_resource_nodes():
		if not is_instance_valid(child):
			continue
		var c: Vector2i = child.get_cell(CELL_SIZE)
		var d: int = maxi(abs(c.x - player_cell.x), abs(c.y - player_cell.y))
		if d <= radius:
			out.append({"node": child, "cell": c, "dist": d})
	return out


## Iterate every FloorPickup within `radius` cells of the player's cell.
func get_floor_pickups_near(player_cell: Vector2i, radius: int) -> Array:
	var out: Array = []
	for child in get_floor_pickups():
		if not is_instance_valid(child):
			continue
		var c: Vector2i = child.get_cell(CELL_SIZE)
		var d: int = maxi(abs(c.x - player_cell.x), abs(c.y - player_cell.y))
		if d <= radius:
			out.append({"node": child, "cell": c, "dist": d})
	return out


## Returns the FloorPickup at a specific cell, or null.
func get_floor_pickup_at(cell: Vector2i) -> Node2D:
	for entry in get_floor_pickups_near(cell, 0):
		return entry["node"]
	return null


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


func get_node_layer() -> Node2D:
	return node_layer


func get_pickup_layer() -> Node2D:
	return pickup_layer


func get_settlement_layer() -> Node2D:
	return settlement_layer


func _clear_ground() -> void:
	if is_instance_valid(ground_layer):
		ground_layer.clear()


func _clear_nodes() -> void:
	if is_instance_valid(node_layer):
		for child in node_layer.get_children():
			child.queue_free()


func _clear_pickups() -> void:
	if is_instance_valid(pickup_layer):
		for child in pickup_layer.get_children():
			child.queue_free()


func _clear_settlements() -> void:
	if is_instance_valid(settlement_layer):
		for child in settlement_layer.get_children():
			child.queue_free()


func _clear_markers() -> void:
	if is_instance_valid(marker_layer):
		for child in marker_layer.get_children():
			child.queue_free()


func _clear_mobs() -> void:
	if is_instance_valid(mob_layer):
		for child in mob_layer.get_children():
			child.queue_free()
