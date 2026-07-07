extends SceneTree
## Smoke test for v0.8.0 settlement building layout.
## Tests: town layout generation, building placement, terrain marking,
## occupied array, SettlementBuilding scene, town boundary, and
## LocalMapView integration.

const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")
const LocalMapViewScene = preload("res://scenes/LocalMapView.tscn")
const SettlementBuildingScript = preload("res://scripts/SettlementBuilding.gd")

var failures: Array[String] = []


func _fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)


func _ok(msg: String) -> void:
	print("  ok  " + msg)


func _initialize() -> void:
	await process_frame
	print("[smoke] v0.8.0 settlement building smoke test")
	_test_towns_json()
	_test_town_layout_small()
	_test_town_layout_medium()
	_test_town_layout_large()
	_test_building_terrain_marking()
	_test_building_occupied_marking()
	_test_town_boundary()
	_test_settlement_building_scene()
	_test_local_map_view_buildings()
	_test_building_sprites_exist()

	if failures.is_empty():
		print("[smoke] All checks passed.")
		quit(0)
	else:
		for f in failures:
			print("[smoke] FAIL: " + f)
		print("[smoke] %d failure(s)." % failures.size())
		quit(1)


func _test_towns_json() -> void:
	print("[smoke] test: towns.json loads with building_types")
	var file: FileAccess = FileAccess.open("res://data/towns.json", FileAccess.READ)
	if file == null:
		_fail("Could not open data/towns.json")
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		_fail("towns.json root is not a Dictionary")
		return
	var bt: Dictionary = parsed.get("building_types", {})
	if bt.is_empty():
		_fail("towns.json has no building_types")
		return
	var expected := ["tavern", "trader", "worktable", "armor_table", "blacksmith", "quest_board", "faction_hq", "auction_house", "arena"]
	for b in expected:
		if not bt.has(b):
			_fail("building_types missing: %s" % b)
			return
	_ok("towns.json has %d building types" % bt.size())


func _test_town_layout_small() -> void:
	print("[smoke] test: town layout generation (small_outpost)")
	var town := {
		"hex": "5,5",
		"faction": "Iron Accord",
		"template": "small_outpost",
		"size": "small",
		"buildings": ["tavern", "trader", "worktable"],
	}
	var terrain := PackedByteArray()
	terrain.resize(LocalMapGen.MAP_SIZE * LocalMapGen.MAP_SIZE)
	terrain.fill(LocalMapGen.TERRAIN_GROUND)
	var occupied := PackedByteArray()
	occupied.resize(LocalMapGen.MAP_SIZE * LocalMapGen.MAP_SIZE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var center := Vector2i(int(LocalMapGen.MAP_SIZE / 2.0), int(LocalMapGen.MAP_SIZE / 2.0))

	var structures: Array = LocalMapGen._generate_town_layout(rng, town, terrain, occupied, center)
	if structures.size() != 3:
		_fail("small_outpost: expected 3 structures, got %d" % structures.size())
		return
	_ok("small_outpost: %d structures generated" % structures.size())


func _test_town_layout_medium() -> void:
	print("[smoke] test: town layout generation (medium_settlement)")
	var town := {
		"hex": "3,3",
		"faction": "Hollow Covenant",
		"template": "medium_settlement",
		"size": "medium",
		"buildings": ["tavern", "trader", "worktable", "armor_table", "blacksmith", "quest_board"],
	}
	var terrain := PackedByteArray()
	terrain.resize(LocalMapGen.MAP_SIZE * LocalMapGen.MAP_SIZE)
	terrain.fill(LocalMapGen.TERRAIN_GROUND)
	var occupied := PackedByteArray()
	occupied.resize(LocalMapGen.MAP_SIZE * LocalMapGen.MAP_SIZE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var center := Vector2i(int(LocalMapGen.MAP_SIZE / 2.0), int(LocalMapGen.MAP_SIZE / 2.0))

	var structures: Array = LocalMapGen._generate_town_layout(rng, town, terrain, occupied, center)
	if structures.size() != 6:
		_fail("medium_settlement: expected 6 structures, got %d" % structures.size())
		return
	_ok("medium_settlement: %d structures generated" % structures.size())


func _test_town_layout_large() -> void:
	print("[smoke] test: town layout generation (large_hub)")
	var town := {
		"hex": "0,0",
		"faction": "Ash Serpents",
		"template": "large_hub",
		"size": "large",
		"buildings": ["tavern", "trader", "worktable", "armor_table", "blacksmith", "quest_board", "faction_hq", "auction_house", "arena"],
	}
	var terrain := PackedByteArray()
	terrain.resize(LocalMapGen.MAP_SIZE * LocalMapGen.MAP_SIZE)
	terrain.fill(LocalMapGen.TERRAIN_GROUND)
	var occupied := PackedByteArray()
	occupied.resize(LocalMapGen.MAP_SIZE * LocalMapGen.MAP_SIZE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var center := Vector2i(int(LocalMapGen.MAP_SIZE / 2.0), int(LocalMapGen.MAP_SIZE / 2.0))

	var structures: Array = LocalMapGen._generate_town_layout(rng, town, terrain, occupied, center)
	if structures.size() != 9:
		_fail("large_hub: expected 9 structures, got %d" % structures.size())
		return
	_ok("large_hub: %d structures generated" % structures.size())


func _test_building_terrain_marking() -> void:
	print("[smoke] test: building footprints are TERRAIN_BLOCKED")
	var town := {
		"hex": "5,5",
		"faction": "Iron Accord",
		"template": "small_outpost",
		"size": "small",
		"buildings": ["tavern", "trader", "worktable"],
	}
	var terrain := PackedByteArray()
	terrain.resize(LocalMapGen.MAP_SIZE * LocalMapGen.MAP_SIZE)
	terrain.fill(LocalMapGen.TERRAIN_GROUND)
	var occupied := PackedByteArray()
	occupied.resize(LocalMapGen.MAP_SIZE * LocalMapGen.MAP_SIZE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var center := Vector2i(int(LocalMapGen.MAP_SIZE / 2.0), int(LocalMapGen.MAP_SIZE / 2.0))

	var structures: Array = LocalMapGen._generate_town_layout(rng, town, terrain, occupied, center)
	var blocked_count := 0
	for s in structures:
		if not (s is Dictionary):
			continue
		var sx: int = int(s.get("x", 0))
		var sy: int = int(s.get("y", 0))
		var sw: int = int(s.get("w", 2))
		var sh: int = int(s.get("h", 2))
		for dy in sh:
			for dx in sw:
				var px: int = sx + dx
				var py: int = sy + dy
				if px >= 0 and py >= 0 and px < LocalMapGen.MAP_SIZE and py < LocalMapGen.MAP_SIZE:
					var t: int = int(terrain[py * LocalMapGen.MAP_SIZE + px])
					if t == LocalMapGen.TERRAIN_BLOCKED:
						blocked_count += 1
	if blocked_count == 0:
		_fail("No TERRAIN_BLOCKED cells found in building footprints")
		return
	_ok("Building footprints: %d TERRAIN_BLOCKED cells" % blocked_count)


func _test_building_occupied_marking() -> void:
	print("[smoke] test: building cells are marked occupied")
	var town := {
		"hex": "5,5",
		"faction": "Iron Accord",
		"template": "small_outpost",
		"size": "small",
		"buildings": ["tavern", "trader", "worktable"],
	}
	var terrain := PackedByteArray()
	terrain.resize(LocalMapGen.MAP_SIZE * LocalMapGen.MAP_SIZE)
	terrain.fill(LocalMapGen.TERRAIN_GROUND)
	var occupied := PackedByteArray()
	occupied.resize(LocalMapGen.MAP_SIZE * LocalMapGen.MAP_SIZE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var center := Vector2i(int(LocalMapGen.MAP_SIZE / 2.0), int(LocalMapGen.MAP_SIZE / 2.0))

	var structures: Array = LocalMapGen._generate_town_layout(rng, town, terrain, occupied, center)
	var occupied_count := 0
	for s in structures:
		if not (s is Dictionary):
			continue
		var sx: int = int(s.get("x", 0))
		var sy: int = int(s.get("y", 0))
		var sw: int = int(s.get("w", 2))
		var sh: int = int(s.get("h", 2))
		for dy in sh:
			for dx in sw:
				var px: int = sx + dx
				var py: int = sy + dy
				if px >= 0 and py >= 0 and px < LocalMapGen.MAP_SIZE and py < LocalMapGen.MAP_SIZE:
					if int(occupied[py * LocalMapGen.MAP_SIZE + px]) != 0:
						occupied_count += 1
	if occupied_count == 0:
		_fail("No occupied cells found in building footprints")
		return
	_ok("Building footprints: %d occupied cells" % occupied_count)


func _test_town_boundary() -> void:
	print("[smoke] test: town boundary Rect2i")
	var center := Vector2i(int(LocalMapGen.MAP_SIZE / 2.0), int(LocalMapGen.MAP_SIZE / 2.0))
	var structures := [
		{"x": 240, "y": 240, "w": 3, "h": 3},
		{"x": 270, "y": 240, "w": 2, "h": 2},
	]
	var bnd: Rect2i = LocalMapGen._compute_town_boundary(structures, center)
	if bnd.size.x <= 0 or bnd.size.y <= 0:
		_fail("Boundary has zero size: %s" % bnd)
		return
	# Boundary should encompass the clearing (radius 15) plus buildings
	if bnd.position.x > center.x - 15:
		_fail("Boundary left edge too far right: %d > %d" % [bnd.position.x, center.x - 15])
		return
	_ok("Boundary: pos=%s size=%s" % [bnd.position, bnd.size])


func _test_settlement_building_scene() -> void:
	print("[smoke] test: SettlementBuilding scene loads")
	var scene: PackedScene = load("res://scenes/SettlementBuilding.tscn")
	if scene == null:
		_fail("Could not load SettlementBuilding.tscn")
		return
	var node: Node2D = scene.instantiate()
	if node == null:
		_fail("SettlementBuilding.instantiate() returned null")
		return
	if not node.has_method("setup"):
		_fail("SettlementBuilding missing setup() method")
		return
	# Test setup with synthetic data
	node.setup({
		"id": "tavern",
		"role": "innkeeper",
		"sprite": "tavern",
		"label": "Tavern",
		"x": 100,
		"y": 100,
		"w": 3,
		"h": 3,
		"entrance_x": 101,
		"entrance_y": 103,
	})
	if node.get_building_id() != "tavern":
		_fail("building_id mismatch: %s" % node.get_building_id())
		return
	if node.get_role() != "innkeeper":
		_fail("role mismatch: %s" % node.get_role())
		return
	if not node.is_cell_inside(Vector2i(101, 101)):
		_fail("is_cell_inside returned false for cell inside building")
		return
	if node.is_cell_inside(Vector2i(200, 200)):
		_fail("is_cell_inside returned true for cell outside building")
		return
	node.queue_free()
	_ok("SettlementBuilding scene loads and setup works")


func _test_local_map_view_buildings() -> void:
	print("[smoke] test: LocalMapView._populate_buildings")
	var view: Node2D = LocalMapViewScene.instantiate()
	root.add_child(view)
	await process_frame

	# Create a tiny synthetic map with settlement structures
	var terrain := PackedByteArray()
	terrain.resize(32 * 32)
	terrain.fill(LocalMapGen.TERRAIN_GROUND)
	var map_data := {
		"size": 32,
		"hex_key": "5,5",
		"q": 5,
		"r": 5,
		"biome": "Ash Wastes",
		"terrain": terrain,
		"spawn": Vector2i(16, 16),
		"resource_nodes": [],
		"floor_pickups": [],
		"cooking_tables": [],
		"settlement": {
			"structures": [
				{"id": "tavern", "role": "innkeeper", "sprite": "tavern", "label": "Tavern", "x": 5, "y": 5, "w": 3, "h": 3, "entrance_x": 6, "entrance_y": 8},
			],
			"town_data": {},
			"boundary": null,
		},
	}
	view.configure(map_data)
	await process_frame

	# Check that building was placed on settlement_layer
	var settlement_layer: Node2D = view.get_settlement_layer()
	if settlement_layer == null:
		_fail("settlement_layer is null")
		view.queue_free()
		return
	var building_found := false
	for child in settlement_layer.get_children():
		if child.has_method("is_cell_inside"):
			building_found = true
			break
	if not building_found:
		_fail("No SettlementBuilding found on settlement_layer after configure")
		view.queue_free()
		return
	# Test get_building_at
	var found: Node2D = view.get_building_at(Vector2i(6, 6))
	if found == null:
		_fail("get_building_at returned null for cell inside building")
		view.queue_free()
		return
	var not_found: Node2D = view.get_building_at(Vector2i(0, 0))
	if not_found != null:
		_fail("get_building_at returned non-null for cell outside building")
		view.queue_free()
		return
	view.queue_free()
	_ok("LocalMapView renders buildings and hit-test works")


func _test_building_sprites_exist() -> void:
	print("[smoke] test: building sprites exist")
	var sprites := ["tavern", "trader", "worktable", "armor_table", "blacksmith", "quest_board", "faction_hq", "auction_house", "arena"]
	var missing := 0
	for s in sprites:
		# Use FileAccess for newly-generated files that Godot hasn't imported yet
		var path := "res://assets/sprites/buildings/%s.png" % s
		if not FileAccess.file_exists(path):
			_fail("Missing building sprite: %s" % path)
			missing += 1
	if missing == 0:
		_ok("All %d building sprites exist" % sprites.size())
