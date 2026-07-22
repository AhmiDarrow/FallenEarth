## LocalMapView — Renders a 512x512 local playfield via Godot TileMapLayer.
##
## One scene per HubWorld. configure(map_data) paints all cells of a
## generated local map using PixelLab Wang tiles via TerrainSystem.
## Marker/mob/node/floor-pickup layers sit on top of the terrain.
##
## v0.13.0: Simplified — delegates tile loading/painting to TerrainSystem.
## Removed shade/tint/cliff procedural overlays (they fought PixelLab art).
class_name LocalMapView
extends Node2D

const TerrainSys = preload("res://scripts/terrain/TerrainSystem.gd")
const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")
const HarvestNodeScript = preload("res://scripts/HarvestNode.gd")
const FloorPickupScript = preload("res://scripts/FloorPickup.gd")
const SettlementNodeScript = preload("res://scripts/SettlementNode.gd")
const CookingTableScript = preload("res://scripts/CookingTable.gd")
const HarvestNodeScene = preload("res://scenes/HarvestNode.tscn")
const FloorPickupScene = preload("res://scenes/FloorPickup.tscn")
const SettlementNodeScene = preload("res://scenes/SettlementNode.tscn")
const CookingTableScene = preload("res://scenes/CookingTable.tscn")
const SettlementBuildingScene = preload("res://scenes/SettlementBuilding.tscn")
const ResourceVisualManagerScript = preload("res://scripts/ResourceVisualManager.gd")
const EntityVisualComponentScript = preload("res://scripts/procedural/EntityVisualComponent.gd")
const AppearanceManagerScript = preload("res://scripts/AppearanceManager.gd")

const CELL_SIZE := 64
const HEIGHT_STEP_PX := 36

var ground_layer: TileMapLayer
var marker_layer: Node2D
var mob_layer: Node2D
var node_layer: Node2D
var pickup_layer: Node2D
var decor_layer: Node2D
var settlement_layer: Node2D
var station_layer: Node2D

var _current_biome: String = ""
var _current_map_data: Dictionary = {}

var _node_by_cell: Dictionary = {}
var _pickup_by_cell: Dictionary = {}
var _settlement_by_cell: Dictionary = {}
var _building_by_cell: Dictionary = {}
var _visual_manager: ResourceVisualManagerScript = null


func _ready() -> void:
	ground_layer = get_node_or_null("Ground") as TileMapLayer
	marker_layer = get_node_or_null("MarkerLayer") as Node2D
	mob_layer = get_node_or_null("MobLayer") as Node2D
	node_layer = get_node_or_null("NodeLayer") as Node2D
	pickup_layer = get_node_or_null("PickupLayer") as Node2D
	decor_layer = get_node_or_null("DecorLayer") as Node2D
	settlement_layer = get_node_or_null("SettlementLayer") as Node2D
	station_layer = get_node_or_null("StationLayer") as Node2D

	for layer in [mob_layer, node_layer, pickup_layer, decor_layer, settlement_layer, station_layer]:
		if is_instance_valid(layer):
			layer.y_sort_enabled = true


func configure(map_data: Dictionary) -> void:
	if not is_instance_valid(ground_layer):
		push_error("[LocalMapView] Ground TileMapLayer missing in scene.")
		return

	_clear_all()

	_current_map_data = map_data
	var biome_name: String = str(map_data.get("biome", "Ash Wastes"))
	_current_biome = biome_name

	# ── Build terrain tiles ───────────────────────────────────────────────
	var tile_set := TerrainSys.tileset_for_biome(biome_name)
	if tile_set == null:
		push_error("[LocalMapView] TileSet build failed for biome: %s" % biome_name)
		return

	# ── Paint terrain ─────────────────────────────────────────────────────
	var size: int = int(map_data.get("size", LocalMapGen.MAP_SIZE))
	var terrain: PackedByteArray = map_data.get("terrain", PackedByteArray())
	if not terrain.is_empty():
		TerrainSys.paint_terrain(ground_layer, terrain, size)

	# ── Spawn entities ────────────────────────────────────────────────────
	_populate_resource_nodes(map_data.get("resource_nodes", []))
	_populate_floor_pickups(map_data.get("floor_pickups", []))
	_populate_decor(map_data.get("decor", []))

	if _visual_manager != null and is_instance_valid(_visual_manager):
		_visual_manager.queue_free()
	_visual_manager = ResourceVisualManagerScript.new()
	_visual_manager.name = "ResourceVisualManager"
	_visual_manager.z_index = 5
	_visual_manager.y_sort_enabled = true
	add_child(_visual_manager)
	_visual_manager.setup(node_layer, pickup_layer, decor_layer)

	_populate_cooking_tables(map_data.get("cooking_tables", []))
	_populate_settlements(_get_world_towns())
	_populate_buildings(map_data.get("settlement", {}).get("structures", []))


# ── Settlements ──────────────────────────────────────────────────────────

func _get_world_towns() -> Array:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null or not gs.has_world():
		return []
	return gs.get_world_data().get("towns_seeded", [])


func _populate_settlements(towns: Array) -> void:
	if not is_instance_valid(settlement_layer):
		return
	_settlement_by_cell.clear()
	for entry in towns:
		if not (entry is Dictionary):
			continue
		var node: Node2D = SettlementNodeScene.instantiate()
		settlement_layer.add_child(node)
		node.setup((entry as Dictionary).duplicate(true))
		var hex_str: String = str(entry.get("hex", ""))
		var parts: PackedStringArray = hex_str.split(",")
		if parts.size() == 2:
			var cell := Vector2i(int(parts[0]), int(parts[1]))
			node.position = cell_to_world(cell)
			node.set_meta("hex", hex_str)
			node.set_meta("cell", cell)
			_settlement_by_cell[cell] = node


func get_settlement_at(cell: Vector2i) -> Node2D:
	var n: Node = _settlement_by_cell.get(cell)
	if n != null and is_instance_valid(n):
		return n
	return null


func _populate_buildings(structures: Array) -> void:
	if not is_instance_valid(settlement_layer):
		return
	_building_by_cell.clear()
	for entry in structures:
		if not (entry is Dictionary):
			continue
		var node: Node2D = SettlementBuildingScene.instantiate()
		settlement_layer.add_child(node)
		node.setup((entry as Dictionary).duplicate(true))
		var bx: int = int(entry.get("x", 0))
		var by: int = int(entry.get("y", 0))
		for cy in range(by, by + int(entry.get("h", 1))):
			for cx in range(bx, bx + int(entry.get("w", 1))):
				_building_by_cell[Vector2i(cx, cy)] = node
		_attach_procedural_if_enabled(node, {"visual_preset": "prop_structure", "id": str(entry.get("id", "bld"))})


func get_building_at(cell: Vector2i) -> Node2D:
	var n: Node = _building_by_cell.get(cell)
	if n != null and is_instance_valid(n):
		return n
	return null


# ── Cooking tables / stations ────────────────────────────────────────────

func _populate_cooking_tables(tables: Array) -> void:
	if not is_instance_valid(station_layer):
		return
	for entry in tables:
		if not (entry is Dictionary):
			continue
		var cell := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		var node: Node2D = CookingTableScene.instantiate()
		station_layer.add_child(node)
		node.set_meta("cell", cell)
		node.position = cell_to_world(cell)


func get_cooking_table_at(cell: Vector2i) -> Node2D:
	if not is_instance_valid(station_layer):
		return null
	for child in station_layer.get_children():
		if not (child is Node2D) or not child.has_method("get_station_id"):
			continue
		if child.has_method("get_cell") and child.get_cell(CELL_SIZE) == cell:
			return child
		if child.has_meta("cell") and (child.get_meta("cell") as Vector2i) == cell:
			return child
	return null


func get_sleeping_bag_at(cell: Vector2i) -> Node2D:
	if not is_instance_valid(station_layer):
		return null
	for child in station_layer.get_children():
		if not (child is SleepingBag):
			continue
		if child.has_method("get_cell") and child.get_cell(CELL_SIZE) == cell:
			return child
		if child.has_meta("cell") and (child.get_meta("cell") as Vector2i) == cell:
			return child
	return null


func add_sleeping_bag(cell: Vector2i, bag: Node2D) -> void:
	if not is_instance_valid(station_layer) or not is_instance_valid(bag):
		return
	station_layer.add_child(bag)
	bag.set_meta("cell", cell)
	bag.position = cell_to_world(cell)


func get_station_layer() -> Node2D:
	return station_layer


# ── Resource nodes / pickups / decor ─────────────────────────────────────

func _populate_resource_nodes(nodes: Array) -> void:
	if not is_instance_valid(node_layer):
		return
	_node_by_cell.clear()
	for entry in nodes:
		if not (entry is Dictionary):
			continue
		var cell: Vector2i = Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		var node: Node2D = HarvestNodeScene.instantiate()
		node_layer.add_child(node)
		node.setup((entry as Dictionary).duplicate(true))
		node.set_meta("cell", cell)
		# Jitter on the entity so collision + sprite share one origin.
		node.position = cell_to_world(cell) + ResourceVisualManagerScript._cell_jitter(cell)
		_node_by_cell[cell] = node


func _populate_floor_pickups(pickups: Array) -> void:
	if not is_instance_valid(pickup_layer):
		return
	_pickup_by_cell.clear()
	for entry in pickups:
		if not (entry is Dictionary):
			continue
		var cell: Vector2i = Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		var pickup: Node2D = FloorPickupScene.instantiate()
		pickup_layer.add_child(pickup)
		pickup.setup(str(entry.get("id", "")), int(entry.get("qty", 1)), cell)
		pickup.set_meta("cell", cell)
		pickup.position = cell_to_world(cell) + ResourceVisualManagerScript._cell_jitter(cell)
		_pickup_by_cell[cell] = pickup


func _populate_decor(decor: Array) -> void:
	if not is_instance_valid(decor_layer):
		return
	for entry in decor:
		if not (entry is Dictionary):
			continue
		var cell: Vector2i = Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		var node := Node2D.new()
		node.name = "Decor_%s_%d_%d" % [str(entry.get("id", "")), cell.x, cell.y]
		node.set_meta("cell", cell)
		node.set_meta("decor_data", (entry as Dictionary).duplicate(true))
		node.position = cell_to_world(cell) + ResourceVisualManagerScript._cell_jitter(cell)
		_attach_decor_collision(node, entry as Dictionary)
		decor_layer.add_child(node)


## Blocking decor gets a base collider aligned to the sprite foot (debug + future queries).
func _attach_decor_collision(node: Node2D, entry: Dictionary) -> void:
	if bool(entry.get("passable", false)):
		return
	var sprite_id: String = str(entry.get("sprite", ""))
	var radius := 18.0
	var foot_y := 1.0
	if sprite_id.find("crater") >= 0 or sprite_id.find("wall") >= 0 or sprite_id.find("ruin") >= 0:
		radius = 26.0
		foot_y = 0.0
	elif sprite_id.find("tower") >= 0 or sprite_id.find("vent") >= 0:
		radius = 22.0
		foot_y = 3.0
	elif sprite_id.find("rock") >= 0 or sprite_id.find("boulder") >= 0:
		radius = 20.0
		foot_y = 2.0
	elif sprite_id.find("bone") >= 0 or sprite_id.find("skull") >= 0:
		radius = 14.0
		foot_y = 2.0
	var area := Area2D.new()
	area.name = "Area2D"
	area.collision_layer = 4
	area.collision_mask = 0
	area.monitoring = false
	var shape_node := CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape_node.shape = circle
	shape_node.position = Vector2(0.0, foot_y)
	area.add_child(shape_node)
	node.add_child(area)


# ── Lookup helpers ───────────────────────────────────────────────────────

func get_resource_nodes() -> Array:
	if not is_instance_valid(node_layer):
		return []
	var out: Array = []
	for child in node_layer.get_children():
		if child is Node2D and child.get_script() == HarvestNodeScript:
			out.append(child)
	return out


func get_floor_pickups() -> Array:
	if not is_instance_valid(pickup_layer):
		return []
	var out: Array = []
	for child in pickup_layer.get_children():
		if child is Node2D and child.get_script() == FloorPickupScript:
			out.append(child)
	return out


func get_resource_nodes_near(player_cell: Vector2i, radius: int) -> Array:
	var out: Array = []
	var r: int = maxi(0, radius)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var cell: Vector2i = player_cell + Vector2i(dx, dy)
			var n: Node = _node_by_cell.get(cell)
			if is_instance_valid(n):
				out.append({"node": n, "cell": cell, "dist": maxi(abs(dx), abs(dy))})
	return out


func get_floor_pickups_near(player_cell: Vector2i, radius: int) -> Array:
	var out: Array = []
	var r: int = maxi(0, radius)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var cell: Vector2i = player_cell + Vector2i(dx, dy)
			var n: Node = _pickup_by_cell.get(cell)
			if is_instance_valid(n):
				out.append({"node": n, "cell": cell, "dist": maxi(abs(dx), abs(dy))})
	return out


func get_floor_pickup_at(cell: Vector2i) -> Node2D:
	var n: Node = _pickup_by_cell.get(cell)
	return n if is_instance_valid(n) else null


# ── Procedural visuals ───────────────────────────────────────────────────

func _attach_procedural_if_enabled(node: Node2D, entity_data: Dictionary) -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if gs == null or not gs.use_procedural_graphics:
		return
	var am: Node = get_node_or_null("/root/AppearanceManager")
	if am == null:
		return
	var visual: Dictionary = am.call("resolve_entity_visual", entity_data)
	if visual.is_empty():
		return
	var comp = EntityVisualComponentScript.new()
	comp.name = "ProcVisual"
	comp.configure(visual, "default", 72.0)
	node.add_child(comp)
	for child in node.get_children():
		if child is Sprite2D or child.get_class() == "AnimatedSprite2D":
			child.visible = false
	comp.set_meta("entity_kind", str(entity_data.get("type", entity_data.get("visual_preset", "resource"))))


# ── Cell/World coordinate helpers ────────────────────────────────────────

func get_cell_size() -> int:
	return CELL_SIZE


func get_ground_layer() -> TileMapLayer:
	return ground_layer


func get_marker_layer() -> Node2D:
	return marker_layer


func get_mob_layer() -> Node2D:
	return mob_layer


func get_node_layer() -> Node2D:
	return node_layer


func get_pickup_layer() -> Node2D:
	return pickup_layer


func get_settlement_layer() -> Node2D:
	return settlement_layer


func get_map_data() -> Dictionary:
	return _current_map_data


func get_height_band(cell: Vector2i) -> int:
	var hb: PackedByteArray = _current_map_data.get("height_band", PackedByteArray())
	var size: int = int(_current_map_data.get("size", LocalMapGen.MAP_SIZE))
	if hb.is_empty() or size <= 0:
		return 0
	if cell.x < 0 or cell.y < 0 or cell.x >= size or cell.y >= size:
		return 0
	var idx := cell.y * size + cell.x
	return int(hb[idx]) if idx < hb.size() else 0


func height_y_offset(cell: Vector2i) -> float:
	return float(-get_height_band(cell) * HEIGHT_STEP_PX)


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * CELL_SIZE + CELL_SIZE * 0.5,
		cell.y * CELL_SIZE + CELL_SIZE * 0.5 + height_y_offset(cell)
	)


func world_to_cell(world: Vector2) -> Vector2i:
	var cx := int(floor(world.x / float(CELL_SIZE)))
	var cy_est := int(floor(world.y / float(CELL_SIZE)))
	var best := Vector2i(cx, cy_est)
	var best_d := INF
	for dy in range(-3, 4):
		var c := Vector2i(cx, cy_est + dy)
		var d: float = cell_to_world(c).distance_squared_to(world)
		if d < best_d:
			best_d = d; best = c
	return best


## Click hit-test: prefer a resource node whose visual covers world_pos
## (tall trees/formations extend above their foot cell).
func hit_test_resource_cell(world: Vector2) -> Vector2i:
	var base := world_to_cell(world)
	var best_cell := Vector2i(-9999, -9999)
	var best_d := INF
	for dy in range(-3, 2):
		for dx in range(-2, 3):
			var c := base + Vector2i(dx, dy)
			var n: Node = _node_by_cell.get(c)
			if not is_instance_valid(n):
				continue
			var foot: Vector2 = (n as Node2D).position
			var nd: Dictionary = n.get("node_data") if "node_data" in n else {}
			var sprite_id: String = str(nd.get("sprite", ""))
			var scale_val := 1.0
			var foot_pad := 1.0
			if sprite_id.begins_with("tree_"):
				scale_val = 1.5
				foot_pad = 4.0
			elif sprite_id.begins_with("formation_"):
				scale_val = 1.25
				foot_pad = 3.0
			elif sprite_id.begins_with("ore_") or sprite_id.begins_with("crystal_"):
				scale_val = 0.9
				foot_pad = 2.0
			var h: float = float(CELL_SIZE) * scale_val
			var w: float = float(CELL_SIZE) * scale_val * 0.85
			# Bottom-aligned sprite: feet near foot + foot_pad, body extends up.
			var rect := Rect2(
				foot.x - w * 0.5,
				foot.y - h + foot_pad,
				w,
				h + 8.0
			)
			if not rect.has_point(world):
				continue
			var d: float = foot.distance_squared_to(world)
			if d < best_d:
				best_d = d
				best_cell = c
	if best_cell.x > -9000:
		return best_cell
	return base


# ── Markers ──────────────────────────────────────────────────────────────

func add_marker(cell: Vector2i, color: Color, symbol: String, kind: String) -> Node2D:
	if not is_instance_valid(marker_layer):
		return null
	var holder := Node2D.new()
	holder.name = "Marker_%s_%d_%d" % [kind, cell.x, cell.y]
	holder.position = cell_to_world(cell)
	holder.z_index = 100

	var bg := ColorRect.new()
	bg.name = "BG"; bg.color = color
	bg.size = Vector2(18, 18); bg.position = Vector2(-9, -9)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bg)

	var label := Label.new()
	label.name = "Glyph"; label.text = symbol
	label.add_theme_color_override("font_color", Color(0, 0, 0))
	label.add_theme_color_override("font_outline_color", Color(1, 1, 1))
	label.add_theme_constant_override("outline_size", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-12, -10); label.size = Vector2(24, 20)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(label)

	marker_layer.add_child(holder)
	return holder


func clear_markers() -> void: _clear_markers()
func clear_mobs() -> void: _clear_mobs()


func dim_resource_node(cell: Vector2i, dimmed: bool) -> void:
	if _visual_manager != null and is_instance_valid(_visual_manager):
		_visual_manager.dim_node(cell, dimmed)


func hide_pickup_visual(cell: Vector2i) -> void:
	if _visual_manager != null and is_instance_valid(_visual_manager):
		_visual_manager.hide_pickup(cell)


# ── Clearing ─────────────────────────────────────────────────────────────

func _clear_all() -> void:
	_clear_ground()
	_clear_markers()
	_clear_mobs()
	_clear_nodes()
	_clear_pickups()
	_clear_decor()
	_clear_buildings()


func _clear_ground() -> void:
	if is_instance_valid(ground_layer):
		ground_layer.clear()


func _clear_nodes() -> void:
	if is_instance_valid(node_layer):
		for child in node_layer.get_children():
			child.queue_free()
	_node_by_cell.clear()
	if _visual_manager != null and is_instance_valid(_visual_manager):
		_visual_manager.queue_free()
		_visual_manager = null


func _clear_pickups() -> void:
	if is_instance_valid(pickup_layer):
		for child in pickup_layer.get_children():
			child.queue_free()
	_pickup_by_cell.clear()


func _clear_decor() -> void:
	if is_instance_valid(decor_layer):
		for child in decor_layer.get_children():
			child.queue_free()


func _clear_markers() -> void:
	if is_instance_valid(marker_layer):
		for child in marker_layer.get_children():
			child.queue_free()


func _clear_mobs() -> void:
	if is_instance_valid(mob_layer):
		for child in mob_layer.get_children():
			child.queue_free()


func _clear_buildings() -> void:
	if is_instance_valid(settlement_layer):
		for child in settlement_layer.get_children():
			if child.has_method("is_cell_inside"):
				child.queue_free()
	_building_by_cell.clear()
