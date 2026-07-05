extends SceneTree
## Smoke test for the v0.3.0 Godot 4.3 tile system.
## Loads HubWorld, configures a tiny synthetic map, instantiates a mob via
## MobVisual, then verifies the TileSet, cell count, and a child mob sprite.

const LocalMapViewScript = preload("res://scripts/LocalMapView.gd")
const LocalMapViewScene = preload("res://scenes/LocalMapView.tscn")
const MobVisualScript = preload("res://scripts/MobVisual.gd")
const TileSetSvc = preload("res://scripts/TileSetService.gd")
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
	_test_mob_visual()
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
	print("[smoke] test: TileSetService.create_for_biome")
	for biome in TileSetSvc.BIOME_DIR.keys():
		var ts: TileSet = TileSetSvc.create_for_biome(biome)
		if ts == null:
			_fail("TileSet null for %s" % biome)
			continue
		var sources := ts.get_source_count()
		if sources != 1:
			_fail("%s: expected 1 atlas source, got %d" % [biome, sources])
			continue
		_ok("biome %s -> TileSet with %d source(s)" % [biome, sources])


func _test_local_map_view() -> void:
	print("[smoke] test: LocalMapView.configure")
	var view: Node2D = LocalMapViewScene.instantiate()
	root.add_child(view)
	# _ready resolves the @-nodes; wait one frame before configuring.
	await process_frame

	# Build a tiny 4x4 map_data. terrain[4] deliberately holds the legacy
	# rift_scar value (4) to verify that LocalMapView normalizes it to
	# TERRAIN_GROUND as documented in v0.4.0 Phase 0.
	var terrain := PackedByteArray()
	terrain.resize(16)
	terrain[0] = LocalMapGen.TERRAIN_GROUND
	terrain[1] = LocalMapGen.TERRAIN_DEBRIS
	terrain[2] = LocalMapGen.TERRAIN_VEGETATION
	terrain[3] = LocalMapGen.TERRAIN_BLOCKED
	terrain[4] = 4  # legacy rift_scar — should normalize to ground
	var map_data := {
		"size": 4,
		"biome": "Ash Wastes",
		"terrain": terrain,
	}
	view.configure(map_data)
	# Verify the legacy rift_scar cell (4,0) renders the same as a ground cell
	# — its atlas coord should be Vector2i(0, 0), not Vector2i(0, 4).
	var ground2: TileMapLayer = view.get_ground_layer()
	var legacy_atlas: Vector2i = ground2.get_cell_atlas_coords(Vector2i(4, 0))
	if legacy_atlas != Vector2i(0, TileSetSvc.TERRAIN_GROUND):
		_fail("LocalMapView: legacy rift_scar (terrain=4) at (4,0) did not normalize to ground; got %s" % legacy_atlas)
		return
	var ground: TileMapLayer = view.get_ground_layer()
	if ground.tile_set == null:
		_fail("LocalMapView: ground TileMapLayer has no TileSet")
		return
	var cells := ground.get_used_cells()
	# Default PackedByteArray value is 0 (GROUND) so all 16 cells are painted.
	if cells.size() != 16:
		_fail("LocalMapView: expected 16 used cells, got %d" % cells.size())
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


func _test_mob_visual() -> void:
	print("[smoke] test: MobVisual.set_mob_sprite")
	var mob: Node2D = MobVisualScript.new()
	root.add_child(mob)
	# Use a known-existing mob from assets/mobs/
	mob.set_mob_sprite("void_stalker")
	# The first child should be a Sprite2D with a non-null texture.
	if mob.get_child_count() == 0:
		_fail("MobVisual: no child Sprite2D after set_mob_sprite")
		return
	var spr := mob.get_child(0) as Sprite2D
	if spr == null or spr.texture == null:
		_fail("MobVisual: sprite has no texture")
		return
	_ok("MobVisual: void_stalker sprite loaded (%dx%d)" % [spr.texture.get_width(), spr.texture.get_height()])


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
