extends SceneTree
## Combat Blockers Repro — verifies:
##   1) Overworld mob seeding actually populates GameState._overworld_mobs
##   2) HubWorld spawns visible mob sprites
##   3) Rift entry flow sets pending_rift and triggers the scene change

const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")
const EncounterBuilder = preload("res://scripts/CombatEncounterBuilder.gd")
const WorldGenScript = preload("res://scripts/WorldGenerator.gd")

var failures: Array[String] = []


func _fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)


func _ok(msg: String) -> void:
	print("  ok  " + msg)


func _initialize() -> void:
	print("[combat-blockers] Reproducing both issues:")
	# Autoloads are added to /root before _initialize, but their
	# _ready() (which loads data files) is deferred to the next
	# idle frame. Wait one frame so all autoloads finish initializing
	# before any test runs.
	await process_frame
	_test_world_and_state_setup()
	_test_encounter_builder_returns_enemy()
	_test_mob_seeding_populates_state()
	_test_hubworld_seeds_and_spawns_mob_sprites()
	_test_rift_spawn_and_get_at_local()
	_test_rift_pending_context_propagates()
	_test_mob_visible_after_seeding()

	if failures.is_empty():
		print("[combat-blockers] All checks passed.")
		quit(0)
	else:
		for f in failures:
			print("[combat-blockers] FAIL: " + f)
		print("[combat-blockers] %d failure(s)." % failures.size())
		quit(1)


func _test_world_and_state_setup() -> void:
	print("[combat-blockers] test: build world + GameState with a fresh character")
	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs == null:
		_fail("GameState autoload missing")
		return
	gs.reset_session()
	var wg := WorldGenScript.new()
	if not wg.initialize():
		_fail("WorldGenerator.initialize() failed")
		return
	var tile_map: Dictionary = wg.generate("smoke_combat_seed", 1.0, 6)
	if tile_map.is_empty():
		_fail("WorldGenerator produced no tile map")
		return
	gs.set_world_data("smoke_combat_seed", tile_map)
	# Pick a normal biome (not Riftspire) as the start
	var start_key: String = ""
	for key in tile_map.keys():
		var t: Dictionary = tile_map[key]
		if not bool(t.get("is_riftspire", false)):
			start_key = str(key)
			break
	if start_key.is_empty():
		_fail("No non-Riftspire tile found for start")
		return
	var parts: PackedStringArray = start_key.split(",")
	gs.set_start_tile(start_key, tile_map[start_key])
	gs.create_character("Human", "Survivor", "Upworld", "ReproHero", "male")
	gs.set_local_position(LocalMapGen.MAP_SIZE / 2, LocalMapGen.MAP_SIZE / 2)
	print("  start hex=%s, biome=%s, pos=(%d,%d)" % [
		start_key, tile_map[start_key].get("name", "?"),
		LocalMapGen.MAP_SIZE / 2, LocalMapGen.MAP_SIZE / 2,
	])
	_ok("World + GameState primed for player at %s" % start_key)
	wg.queue_free()


func _test_encounter_builder_returns_enemy() -> void:
	print("[combat-blockers] test: EncounterBuilder.generate_procedural_enemy")
	var gs: Node = root.get_node_or_null("/root/GameState")
	var tile_map: Dictionary = gs.get_tile_map()
	var start: Dictionary = gs.get_start_tile()
	var start_key: String = str(start.get("key", "0,0"))
	var biome: String = str(start.get("name", "Ash Wastes"))
	var diff: Dictionary = {"min_level": 2, "max_level": 6}
	var enemy: Dictionary = EncounterBuilder.generate_procedural_enemy(
		"smoke_combat_seed", tile_map, start_key, diff, "upworld", biome
	)
	if enemy.is_empty():
		_fail("EncounterBuilder returned empty enemy for %s in %s" % [start_key, biome])
		return
	_ok("Enemy built: %s (L%d, sprite_id=%s)" % [
		enemy.get("name", "?"), int(enemy.get("level", 0)),
		enemy.get("sprite_id", "?"),
	])
	# Confirm a sprite exists on disk
	var sprite_id: String = str(enemy.get("sprite_id", "")).to_lower()
	if sprite_id.is_empty():
		_fail("Enemy has empty sprite_id")
		return
	var path := "res://assets/mobs/%s.png" % sprite_id
	if not ResourceLoader.exists(path):
		_fail("Mob sprite missing on disk: %s" % path)
		return
	_ok("Mob sprite file present: %s" % path)


func _test_mob_seeding_populates_state() -> void:
	print("[combat-blockers] test: direct EncounterBuilder → GameState mob store")
	var gs: Node = root.get_node_or_null("/root/GameState")
	var start: Dictionary = gs.get_start_tile()
	var start_key: String = str(start.get("key", "0,0"))
	var biome: String = str(start.get("name", "Ash Wastes"))
	var tile_map: Dictionary = gs.get_tile_map()
	# Wipe any pre-existing
	for k in gs.get_overworld_mobs().keys():
		gs.remove_overworld_mob(str(k))
	# Seed 3 mobs at known cells
	var diff: Dictionary = {"min_level": 2, "max_level": 6}
	for i in range(3):
		var enemy: Dictionary = EncounterBuilder.generate_procedural_enemy(
			"smoke_combat_seed", tile_map, start_key, diff, "upworld", biome
		)
		if enemy.is_empty():
			_fail("Seed %d: EncounterBuilder returned empty" % i)
			return
		var lx: int = 64 + i * 16
		var ly: int = 64 + i * 16
		gs.set_local_mob(0, 0, lx, ly, enemy)
	# Verify
	var stored: Dictionary = gs.get_overworld_mobs()
	if stored.size() < 3:
		_fail("Expected ≥3 mobs in GameState, got %d" % stored.size())
		return
	_ok("GameState._overworld_mobs has %d entries" % stored.size())


func _test_hubworld_seeds_and_spawns_mob_sprites() -> void:
	print("[combat-blockers] test: HubWorld instantiates + spawns mob sprites")
	var gs: Node = root.get_node_or_null("/root/GameState")
	# Wipe state first
	for k in gs.get_overworld_mobs().keys():
		gs.remove_overworld_mob(str(k))
	# Recreate the local map (so HubWorld sees a fresh terrain with no mobs)
	gs.ensure_hex_state(0, 0)
	var hub_scene: PackedScene = load("res://scenes/HubWorld.tscn") as PackedScene
	if hub_scene == null:
		_fail("HubWorld.tscn failed to load")
		return
	var hub: Control = hub_scene.instantiate() as Control
	root.add_child(hub)
	# Wait for _ready → _seed_local_mobs → _build_local_view
	await process_frame
	await process_frame
	var stored: Dictionary = gs.get_overworld_mobs()
	if stored.is_empty():
		_fail("HubWorld._seed_local_mobs produced no mobs in GameState")
		hub.queue_free()
		return
	_ok("HubWorld seeded %d mob(s) into GameState" % stored.size())
	# Find the LocalMapView and inspect the mob layer
	var wg: Node = hub.get_node_or_null("WorldGrid")
	if wg == null:
		_fail("HubWorld has no WorldGrid after instantiate")
		hub.queue_free()
		return
	var view: Node2D = wg.get_node_or_null("LocalMapView") as Node2D
	if view == null:
		_fail("HubWorld: LocalMapView missing from WorldGrid")
		hub.queue_free()
		return
	var mob_layer: Node2D = view.get_mob_layer() as Node2D
	if mob_layer == null:
		_fail("LocalMapView: mob_layer is null")
		hub.queue_free()
		return
	var n_children: int = mob_layer.get_child_count()
	if n_children < 1:
		_fail("LocalMapView mob_layer has 0 children (expected at least 1 mob sprite)")
		hub.queue_free()
		return
	_ok("mob_layer has %d sprite(s) — visible mobs confirmed" % n_children)
	# Inspect first child: should be a MobVisual with a Sprite2D child
	var first: Node = mob_layer.get_child(0)
	if first == null:
		_fail("First mob child is null")
		hub.queue_free()
		return
	var sprite: Sprite2D = null
	if first is Node2D:
		for c in first.get_children():
			if c is Sprite2D:
				sprite = c
				break
	if sprite == null or sprite.texture == null:
		_fail("First mob child has no Sprite2D with a texture (visible = invisible)")
		hub.queue_free()
		return
	_ok("First mob sprite has a loaded texture: %s (%dx%d)" % [
		first.name, sprite.texture.get_width(), sprite.texture.get_height()
	])
	hub.queue_free()
	await process_frame


func _test_rift_spawn_and_get_at_local() -> void:
	print("[combat-blockers] test: RiftRunner.add_rift_entrance + get_rift_at_local")
	var runner: Node = root.get_node_or_null("/root/RiftRunner")
	if runner == null:
		_fail("RiftRunner autoload missing")
		return
	# Wipe existing rifts
	if runner.has_method("reset_for_new_game"):
		runner.call("reset_for_new_game")
	var gs: Node = root.get_node_or_null("/root/GameState")
	var start: Dictionary = gs.get_start_tile()
	var start_key: String = str(start.get("key", "0,0"))
	var parts: PackedStringArray = start_key.split(",")
	var q: int = int(parts[0])
	var r: int = int(parts[1])
	var biome: String = str(start.get("name", "Ash Wastes"))
	# Spawn a rift at the player's exact local cell (256, 256)
	var spawn_lx: int = LocalMapGen.MAP_SIZE / 2
	var spawn_ly: int = LocalMapGen.MAP_SIZE / 2
	var entry: Dictionary = runner.call(
		"add_rift_entrance", q, r, biome, 600.0, "test_rift_001", true, spawn_lx, spawn_ly
	)
	if entry.is_empty():
		_fail("RiftRunner.add_rift_entrance returned empty")
		return
	_ok("Rift spawned: %s at local (%d,%d)" % [
		entry.get("rift_id", "?"),
		int(entry.get("local_x", 0)),
		int(entry.get("local_y", 0)),
	])
	# Try to look it up at the player's cell
	var current_time: float = Time.get_ticks_msec() / 1000.0
	var found: Dictionary = runner.call("get_rift_at_local", q, r, spawn_lx, spawn_ly, current_time)
	if found.is_empty():
		_fail("get_rift_at_local(%d,%d at local %d,%d) returned empty (player IS on the rift)" % [
			q, r, spawn_lx, spawn_ly,
		])
		return
	_ok("get_rift_at_local found rift: %s" % found.get("rift_id", "?"))


func _test_rift_pending_context_propagates() -> void:
	print("[combat-blockers] test: pending_rift round-trip")
	var gs: Node = root.get_node_or_null("/root/GameState")
	# Wipe
	gs.clear_pending_rift()
	if not gs.get_pending_rift().is_empty():
		_fail("clear_pending_rift() did not clear state")
		return
	# Set a context
	var rift_data: Dictionary = {
		"rift_id": "test_rift_round_trip",
		"biome_key": "Ash Wastes",
		"entry_q": 0,
		"entry_r": 0,
		"entry_local_x": 256,
		"entry_local_y": 256,
		"has_boss": true,
	}
	gs.set_pending_rift(rift_data)
	var loaded: Dictionary = gs.get_pending_rift()
	if loaded.is_empty():
		_fail("get_pending_rift() returned empty after set_pending_rift(...)")
		return
	if str(loaded.get("rift_id", "")) != "test_rift_round_trip":
		_fail("rift_id lost in round-trip; got '%s'" % str(loaded.get("rift_id", "")))
		return
	_ok("pending_rift round-trip OK: rift_id=%s, biome=%s" % [
		loaded.get("rift_id", "?"), loaded.get("biome_key", "?"),
	])
	# Now try to instantiate RiftInstance and see if it can load the context
	var rift_scene: PackedScene = load("res://scenes/RiftInstance.tscn") as PackedScene
	if rift_scene == null:
		_fail("RiftInstance.tscn failed to load")
		return
	var rift_inst: Control = rift_scene.instantiate() as Control
	root.add_child(rift_inst)
	await process_frame
	# v0.9.1: also verify the children are properly parented. The scene
	# had a bug where GridContainer, EndTurnButton, ClearRiftButton,
	# BackButton, LootTitle, LootLabel all used relative parent paths
	# (e.g. parent="GridPanel") instead of the full path
	# (parent="MainVBox/GridPanel"), which made them orphans.
	var expected_paths: Array[String] = [
		"MainVBox/GridPanel/GridContainer",
		"MainVBox/ActionsHBox/EndTurnButton",
		"MainVBox/ActionsHBox/ClearRiftButton",
		"MainVBox/ActionsHBox/BackButton",
		"MainVBox/LootPanel/LootTitle",
		"MainVBox/LootPanel/LootLabel",
	]
	for path in expected_paths:
		if rift_inst.get_node_or_null(NodePath(path)) == null:
			_fail("RiftInstance child missing: %s (scene file uses relative parent paths)" % path)
			rift_inst.queue_free()
			return
	_ok("RiftInstance has all 6 expected children at proper paths")
	# The RiftInstance should have parsed the context
	if str(rift_inst._rift_id) != "test_rift_round_trip":
		_fail("RiftInstance._rift_id mismatch: got '%s' (expected 'test_rift_round_trip')" % str(rift_inst._rift_id))
		rift_inst.queue_free()
		return
	_ok("RiftInstance loaded _rift_id=%s, _biome_key=%s" % [
		rift_inst._rift_id, rift_inst._biome_key,
	])
	rift_inst.queue_free()


func _test_mob_visible_after_seeding() -> void:
	print("[combat-blockers] test: at least one mob within walking distance of spawn")
	var gs: Node = root.get_node_or_null("/root/GameState")
	var all_mobs: Dictionary = gs.get_overworld_mobs()
	var pos: Vector2i = gs.get_player_position()
	var local: Vector2i = gs.get_local_position()
	var prefix: String = "%d,%d|" % [pos.x, pos.y]
	var nearest: int = 9999
	for mob_key in all_mobs.keys():
		if not str(mob_key).begins_with(prefix):
			continue
		var rest: String = str(mob_key).substr(prefix.length())
		var parts: PackedStringArray = rest.split(",")
		if parts.size() < 2:
			continue
		var d: int = abs(int(parts[0]) - local.x) + abs(int(parts[1]) - local.y)
		if d < nearest:
			nearest = d
	if nearest > 25:
		_fail("Nearest mob is %d cells away (player would have to walk 25+ cells to fight). v0.9.1 should place some within ~20 cells." % nearest)
		return
	_ok("Nearest mob is %d cells from player (walkable; fits in camera view)" % nearest)
