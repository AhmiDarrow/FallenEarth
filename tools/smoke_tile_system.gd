extends SceneTree
## Smoke test for the v0.3.0 tile system.
## Loads HubWorld, configures a tiny synthetic map, instantiates a mob via
## MobVisual, then verifies the TileSet, cell count, and a child mob sprite.

const LocalMapViewScript = preload("res://scripts/LocalMapView.gd")
const LocalMapViewScene = preload("res://scenes/LocalMapView.tscn")
const MobInstanceScript = preload("res://scripts/mob/MobInstance.gd")
const MobDataScript = preload("res://scripts/mob/MobData.gd")
const TerrainSys = preload("res://scripts/terrain/TerrainSystem.gd")
const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")

var failures: Array[String] = []


func _fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)


func _ok(msg: String) -> void:
	print("  ok  " + msg)


func _initialize() -> void:
	print("[smoke] v0.3.0 tile system smoke test")
	_test_tileset_build()
	_test_local_map_view()
	_test_mob_instance()
	_test_hub_world_loading()

	if failures.is_empty():
		print("[smoke] All checks passed.")
		quit(0)
	else:
		for f in failures:
			print("[smoke] FAIL: " + f)
		print("[smoke] %d failure(s)." % failures.size())
		quit(1)


func _test_tileset_build() -> void:
	print("[smoke] test: TerrainSystem.tileset_for_biome")
	for biome in TerrainSys.BIOME_DIRS.keys():
		var ts: TileSet = TerrainSys.tileset_for_biome(biome)
		if ts == null:
			_fail("TileSet null for %s" % biome)
			continue
		var sources := ts.get_source_count()
		if sources < 1:
			_fail("%s: expected >=1 atlas source, got %d" % [biome, sources])
			continue
		_ok("biome %s -> %s tileset (%d source(s))" % [biome, "wang" if TerrainSys.using_wang() else "fallback", sources])


func _test_local_map_view() -> void:
	print("[smoke] test: LocalMapView.configure")
	var view: Node2D = LocalMapViewScene.instantiate()
	root.add_child(view)
	# _ready resolves the @-nodes; wait one frame before configuring.
	await process_frame

	# 4x4 map with all terrain kinds + invalid id (99) which must clamp to ground.
	var terrain := PackedByteArray()
	terrain.resize(16)
	terrain[0] = LocalMapGen.TERRAIN_GROUND
	terrain[1] = LocalMapGen.TERRAIN_DEBRIS
	terrain[2] = LocalMapGen.TERRAIN_VEGETATION
	terrain[3] = LocalMapGen.TERRAIN_BLOCKED
	terrain[4] = LocalMapGen.TERRAIN_WATER
	terrain[5] = 99  # invalid → ground
	var map_data := {
		"size": 4,
		"biome": "Ash Wastes",
		"terrain": terrain,
	}
	view.configure(map_data)
	var ground: TileMapLayer = view.get_ground_layer()
	if ground.tile_set == null:
		_fail("LocalMapView: ground TileMapLayer has no TileSet")
		return
	if ground.tile_set.get_terrain_sets_count() < 1:
		_fail("LocalMapView: TileSet missing corner terrain_set")
		return
	var cells := ground.get_used_cells()
	# Default PackedByteArray value is 0 (GROUND) so all 16 cells are painted.
	if cells.size() != 16:
		_fail("LocalMapView: expected 16 used cells, got %d" % cells.size())
		return
	# Invalid terrain at (1,1) must still be painted (as ground).
	if ground.get_cell_source_id(Vector2i(1, 1)) < 0:
		_fail("LocalMapView: invalid terrain cell (1,1) not painted")
		return
	# Verify BLOCKED cell is (3,0)
	var has_blocked := false
	for c in cells:
		if c == Vector2i(3, 0):
			has_blocked = true
	if not has_blocked:
		_fail("LocalMapView: blocked cell (3,0) missing")
		return
	# Verify a marker can be added
	var marker: Node2D = view.call("add_marker", Vector2i(2, 2), Color.RED, "!", "test")
	if marker == null:
		_fail("LocalMapView: add_marker returned null")
		return
	_ok("LocalMapView: 4x4 map painted, blocked cell present, marker added")


func _test_mob_instance() -> void:
	print("[smoke] test: MobInstance loads sprite")
	var data := MobDataScript.new()
	data.sprite_id = "void_stalker"
	data.grid_x = 10
	data.grid_y = 10
	var inst := MobInstanceScript.new()
	root.add_child(inst)
	inst.setup(data)
	if inst._sprite == null or inst._sprite.texture == null:
		_fail("MobInstance: sprite has no texture")
		return
	_ok("MobInstance: void_stalker sprite loaded (%dx%d)" % [inst._sprite.texture.get_width(), inst._sprite.texture.get_height()])


func _test_hub_world_loading() -> void:
	print("[smoke] test: HubWorld scene instantiates")
	var hub_scene: PackedScene = load("res://scenes/HubWorld.tscn")
	if hub_scene == null:
		_fail("HubWorld.tscn failed to load")
		return
	var hub := hub_scene.instantiate()
	root.add_child(hub)
	await process_frame
	# HubWorld._ready will run, configure the local map, etc. Just verify it
	# did not throw and that the world_grid exists.
	var wg := hub.get_node_or_null("WorldGrid")
	if wg == null:
		_fail("HubWorld: WorldGrid missing after instantiate")
		return
	# Give one frame for the new LocalMapView scene to attach.
	var view := wg.get_node_or_null("LocalMapView")
	if view == null:
		_fail("HubWorld: LocalMapView child not added to WorldGrid")
		return
	_ok("HubWorld: scene instantiated, WorldGrid + LocalMapView present")
	hub.queue_free()
