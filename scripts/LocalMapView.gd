## LocalMapView — Renders a 512x512 local playfield via a Godot 4.7 TileMapLayer.
##
## One scene per HubWorld. configure(map_data) paints all cells of a generated
## local map into the TileMapLayer using a biome-specific TileSet built by
## TileSetService. Marker/mob/node/floor-pickup layers sit on top of the terrain.
## No sprite batching, no procedural drawing — Godot TileMap handles
## 512x512 (~262k cells) at 60 fps without chunking.
##
## v0.9.1c: cell → node Dictionary indexes for O(1) lookups. Without these,
## every move cost ~40 ms because get_floor_pickup_at and
## get_resource_nodes_near iterated all 1966 + 3748 nodes.
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
const SettlementBuildingScene = preload("res://scenes/SettlementBuilding.tscn")
const ResourceVisualManagerScript = preload("res://scripts/ResourceVisualManager.gd")
const EntityVisualComponentScript = preload("res://scripts/procedural/EntityVisualComponent.gd")
const AppearanceManagerScript = preload("res://scripts/AppearanceManager.gd")

const CELL_SIZE := 32

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

# v0.9.1c: O(1) cell lookups. The old per-query iteration over all
# 1966 + 3748 nodes was the dominant per-move cost.
var _node_by_cell: Dictionary = {}     # Vector2i -> HarvestNode
var _pickup_by_cell: Dictionary = {}    # Vector2i -> FloorPickup
var _settlement_by_cell: Dictionary = {}  # Vector2i -> SettlementNode
var _building_by_cell: Dictionary = {}    # Vector2i -> SettlementBuilding (per footprint cell)
# v0.10.0: batched MultiMesh visuals for resource nodes + floor pickups.
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
	# Mob layer is y-sorted so entities stack correctly with the player.
	if is_instance_valid(mob_layer):
		mob_layer.y_sort_enabled = true
	# Node/pickup layers sit above the ground but below the player visual
	# so y-sort in MobLayer still layers entities on top.
	if is_instance_valid(node_layer):
		node_layer.y_sort_enabled = true
	if is_instance_valid(pickup_layer):
		pickup_layer.y_sort_enabled = true
	if is_instance_valid(decor_layer):
		decor_layer.y_sort_enabled = true
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
	_clear_decor()
	_clear_buildings()

	_current_map_data = map_data

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

	var edge_mask: PackedByteArray = map_data.get("edge_mask", PackedByteArray())
	var ground_variant: PackedByteArray = map_data.get("ground_variant", PackedByteArray())

	for y in size:
		for x in size:
			var t := int(terrain[y * size + x])
			if t < 0 or t > TileSetSvc.TERRAIN_WATER:
				t = TileSetSvc.TERRAIN_GROUND
			var em := 0
			if edge_mask.size() > 0:
				var ei := y * size + x
				if ei < edge_mask.size():
					em = edge_mask[ei]
			# Compute Wang ground pattern for this cell
			var wp := 0
			if t == TileSetSvc.TERRAIN_GROUND and ground_variant.size() > 0:
				var idx := y * size + x
				if idx < ground_variant.size():
					var sv := ground_variant[idx]
					var nv := ground_variant[(y - 1) * size + x] if y > 0 and terrain[(y - 1) * size + x] == t else -1
					var sv2 := ground_variant[(y + 1) * size + x] if y < size - 1 and terrain[(y + 1) * size + x] == t else -1
					var wv := ground_variant[y * size + (x - 1)] if x > 0 and terrain[y * size + (x - 1)] == t else -1
					var ev := ground_variant[y * size + (x + 1)] if x < size - 1 and terrain[y * size + (x + 1)] == t else -1
					wp = TileSetSvc.compute_wang_pattern(sv, nv, sv2, wv, ev)
			ground_layer.set_cell(Vector2i(x, y), 0, TileSetSvc.atlas_coords(t, int(em), wp))

	# Spawn resource nodes (trees, formations, ore, crystals, fauna)
	_populate_resource_nodes(map_data.get("resource_nodes", []))
	# Spawn floor pickups (sticks, stones)
	_populate_floor_pickups(map_data.get("floor_pickups", []))
	# Spawn visual decor (rocks, ruins, flora)
	_populate_decor(map_data.get("decor", []))
	# Shared-texture Sprite2D batch (MultiMesh transforms were unreliable on 4.7).
	if _visual_manager != null and is_instance_valid(_visual_manager):
		_visual_manager.queue_free()
	_visual_manager = ResourceVisualManagerScript.new()
	_visual_manager.name = "ResourceVisualManager"
	# Above ground tiles; y-sort so taller props occlude correctly.
	_visual_manager.z_index = 5
	_visual_manager.y_sort_enabled = true
	add_child(_visual_manager)
	_visual_manager.setup(node_layer, pickup_layer, decor_layer)
	# Spawn cooking tables (Phase 3 follow-up: cooking station)
	_populate_cooking_tables(map_data.get("cooking_tables", []))
	# Spawn settlement structures (Phase 3: NPC towns). The settlement
	# data comes from world_data.towns_seeded; we look that up via
	# GameState. Each town is placed at its hex key (the player walks
	# adjacent and presses F to enter the interior — F is the canonical
	# interact key per scripts/KeybindManager.gd).
	_populate_settlements(_get_world_towns())
	# v0.8.0: spawn building sprites from the procedural town layout
	_populate_buildings(map_data.get("settlement", {}).get("structures", []))


func _get_world_towns() -> Array:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null or not gs.has_world():
		return []
	var wd: Dictionary = gs.get_world_data()
	return wd.get("towns_seeded", [])


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
		# Set the cell from the hex key
		var hex_str: String = str(entry.get("hex", ""))
		var parts: PackedStringArray = hex_str.split(",")
		if parts.size() == 2:
			var cell := Vector2i(int(parts[0]), int(parts[1]))
			node.position = cell_to_world(cell)
			# Tag the node with the hex key for hit-test lookup
			node.set_meta("hex", hex_str)
			_settlement_by_cell[cell] = node


## Returns the SettlementNode at the given cell, or null. O(1) via cell index.
func get_settlement_at(cell: Vector2i) -> Node2D:
	var n: Node = _settlement_by_cell.get(cell)
	if n != null and is_instance_valid(n):
		return n
	return null


## v0.8.0: populate building sprites from the procedural town layout.
## Each structure dict has {id, role, sprite, label, x, y, w, h, entrance_x, entrance_y}.
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
		# Index every footprint cell for O(1) lookup.
		var bx: int = int(entry.get("x", 0))
		var by: int = int(entry.get("y", 0))
		for cy in range(by, by + int(entry.get("h", 1))):
			for cx in range(bx, bx + int(entry.get("w", 1))):
				_building_by_cell[Vector2i(cx, cy)] = node
		# Phase (extend coverage): procedural 3D visual for settlement structures.
		_attach_procedural_if_enabled(node, {"visual_preset": "prop_structure", "id": str(entry.get("id", "bld"))})


## Returns the SettlementBuilding whose footprint contains the given cell,
## or null. O(1) via per-cell footprint index.
func get_building_at(cell: Vector2i) -> Node2D:
	var n: Node = _building_by_cell.get(cell)
	if n != null and is_instance_valid(n):
		return n
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


## Returns the SleepingBag at the given cell, or null.
func get_sleeping_bag_at(cell: Vector2i) -> Node2D:
	if not is_instance_valid(station_layer):
		return null
	for child in station_layer.get_children():
		if not (child is SleepingBag):
			continue
		var p: Vector2 = child.global_position
		var cx: int = int(floor(p.x / CELL_SIZE))
		var cy: int = int(floor(p.y / CELL_SIZE))
		if cx == cell.x and cy == cell.y:
			return child
	return null


## Add a sleeping bag node to the station layer at the given cell.
func add_sleeping_bag(cell: Vector2i, bag: Node2D) -> void:
	if not is_instance_valid(station_layer):
		return
	if not is_instance_valid(bag):
		return
	station_layer.add_child(bag)
	bag.position = cell_to_world(cell)


## Returns the station layer (for HubWorld to query stations).
func get_station_layer() -> Node2D:
	return station_layer


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
		node.position = cell_to_world(cell)
		# v0.9.1c: cell → node index for O(1) gather lookups.
		_node_by_cell[cell] = node
		# NOTE: Resource nodes are rendered by the batched MultiMesh
		# ResourceVisualManager (one draw call for hundreds of nodes) for
		# performance. Per-node procedural 3D studios would conflict (double
		# draw) and regress perf, so they are intentionally NOT overlaid here.
		# The procedural resource shapes (tree/crystal/ore/plant) are available
		# via ProceduralEntityGenerator + appearance.json presets and shown in
		# the Phase1Previewer for visual QA.


## Phase (extend coverage): attach a procedural 3D EntityVisualComponent to a
## discrete overworld node (resource node, settlement building) when procedural
## graphics are enabled, and hide the original sprite so it isn't double-drawn.
## Resource data resolves via resource_node_visual_map (by type); buildings use
## an explicit visual_preset. Failures are non-fatal (original sprite remains).
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
	# Hide the original sprite-driven visual to avoid overlap.
	for child in node.get_children():
		if child is Sprite2D or child.get_class() == "AnimatedSprite2D":
			child.visible = false
	comp.set_meta("entity_kind", str(entity_data.get("type", entity_data.get("visual_preset", "resource"))))


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
		pickup.setup(str(entry.get("id", "")), int(entry.get("qty", 1)))
		pickup.position = cell_to_world(cell)
		# v0.9.1c: cell → pickup index for O(1) auto-collect.
		_pickup_by_cell[cell] = pickup


## Populate visual decor layer (rocks, ruins, flora). Each decor item is a
## lightweight Node2D with position only — no interaction, no sprite (rendered
## by ResourceVisualManager's MultiMesh batch).
func _populate_decor(decor: Array) -> void:
	if not is_instance_valid(decor_layer):
		return
	for entry in decor:
		if not (entry is Dictionary):
			continue
		var cell: Vector2i = Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		var node := Node2D.new()
		node.name = "Decor_%s_%d_%d" % [str(entry.get("id", "")), cell.x, cell.y]
		node.position = cell_to_world(cell)
		# Attach decor data as metadata for ResourceVisualManager (Node2D has no
		# declared `decor_data` property so `node.set("decor_data", ...)` would
		# silently drop the value; set_meta survives the round trip).
		node.set_meta("decor_data", (entry as Dictionary).duplicate(true))
		decor_layer.add_child(node)


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
## v0.9.1c: O(K) where K is the number of cells in the radius
## (was O(N) over all 3748 nodes per query).
func get_resource_nodes_near(player_cell: Vector2i, radius: int) -> Array:
	var out: Array = []
	# Check all cells in the (2*radius+1)² box around the player.
	# For radius=1 that's 9 cells; for radius=2, 25 cells. Cheap.
	var r: int = maxi(0, radius)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var cell: Vector2i = player_cell + Vector2i(dx, dy)
			var n: Node = _node_by_cell.get(cell)
			if is_instance_valid(n):
				var d: int = maxi(abs(dx), abs(dy))
				out.append({"node": n, "cell": cell, "dist": d})
	return out


## Iterate every FloorPickup within `radius` cells of the player's cell.
## v0.9.1c: O(K) via _pickup_by_cell.
func get_floor_pickups_near(player_cell: Vector2i, radius: int) -> Array:
	var out: Array = []
	var r: int = maxi(0, radius)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var cell: Vector2i = player_cell + Vector2i(dx, dy)
			var n: Node = _pickup_by_cell.get(cell)
			if is_instance_valid(n):
				var d: int = maxi(abs(dx), abs(dy))
				out.append({"node": n, "cell": cell, "dist": d})
	return out


## Returns the FloorPickup at a specific cell, or null.
## v0.9.1c: O(1) via _pickup_by_cell (was O(N) over all pickups).
func get_floor_pickup_at(cell: Vector2i) -> Node2D:
	var n: Node = _pickup_by_cell.get(cell)
	if is_instance_valid(n):
		return n
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


## v0.10.0: Dim or restore a resource node visual at the given cell.
func dim_resource_node(cell: Vector2i, dimmed: bool) -> void:
	if _visual_manager != null and is_instance_valid(_visual_manager):
		_visual_manager.dim_node(cell, dimmed)


## v0.10.0: Hide a floor pickup visual at the given cell (after collection).
func hide_pickup_visual(cell: Vector2i) -> void:
	if _visual_manager != null and is_instance_valid(_visual_manager):
		_visual_manager.hide_pickup(cell)


func get_settlement_layer() -> Node2D:
	return settlement_layer


## v0.8.0: Returns the current map_data dictionary (set during configure()).
func get_map_data() -> Dictionary:
	return _current_map_data


func _clear_ground() -> void:
	if is_instance_valid(ground_layer):
		ground_layer.clear()


func _clear_nodes() -> void:
	if is_instance_valid(node_layer):
		for child in node_layer.get_children():
			child.queue_free()
	# v0.9.1c: clear the cell index too.
	_node_by_cell.clear()
	if _visual_manager != null and is_instance_valid(_visual_manager):
		_visual_manager.queue_free()
		_visual_manager = null


func _clear_pickups() -> void:
	if is_instance_valid(pickup_layer):
		for child in pickup_layer.get_children():
			child.queue_free()
	# v0.9.1c: clear the cell index too.
	_pickup_by_cell.clear()


func _clear_decor() -> void:
	if is_instance_valid(decor_layer):
		for child in decor_layer.get_children():
			child.queue_free()


func _clear_settlements() -> void:
	if is_instance_valid(settlement_layer):
		for child in settlement_layer.get_children():
			child.queue_free()
	_settlement_by_cell.clear()
	_building_by_cell.clear()


func _clear_buildings() -> void:
	if is_instance_valid(settlement_layer):
		for child in settlement_layer.get_children():
			if child.has_method("is_cell_inside"):
				child.queue_free()
	_building_by_cell.clear()


func _clear_markers() -> void:
	if is_instance_valid(marker_layer):
		for child in marker_layer.get_children():
			child.queue_free()


func _clear_mobs() -> void:
	if is_instance_valid(mob_layer):
		for child in mob_layer.get_children():
			child.queue_free()
