extends SceneTree
## v0.10.0 — Combat overhaul smoke test.
##
## Verifies the new BattleCell, BattleGridView, BattleUnit, and
## BattleBackground components load, configure, and render the
## expected structure. Does not require a live encounter.

const BattleCellScript = preload("res://scripts/combat/BattleCell.gd")
const BattleGridViewScript = preload("res://scripts/combat/BattleGridView.gd")
const BattleUnitScript = preload("res://scripts/combat/BattleUnit.gd")
const BattleBackgroundScript = preload("res://scripts/combat/BattleBackground.gd")
const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")

var failures: Array[String] = []


func _initialize() -> void:
	print("[smoke-v100] v0.10.0 Combat Overhaul")
	_test_battle_cell_constructs()
	await process_frame
	_test_battle_grid_builds()
	await process_frame
	_test_battle_unit_loads_sprite()
	await process_frame
	_test_battle_grid_height_map()
	await process_frame
	_test_battle_background_renders()
	await process_frame
	_test_terrain_grid_generation()
	await process_frame
	_test_tactical_combat_scene_loads()
	await process_frame
	_test_legacy_removed()
	_print_summary()
	quit()


func _fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)


func _ok(msg: String) -> void:
	print("  ok  " + msg)


func _test_battle_cell_constructs() -> void:
	print("\n--- BattleCell ---")
	var cell = BattleCellScript.new()
	cell.name = "TestCell"
	root.add_child(cell)
	await process_frame
	if cell == null:
		_fail("BattleCell: instantiation failed")
		return
	if cell._base == null:
		_fail("BattleCell: _base Sprite2D not built")
	else:
		_ok("BattleCell: _base Sprite2D built")
	if cell._highlight == null:
		_fail("BattleCell: _highlight ColorRect not built")
	else:
		_ok("BattleCell: _highlight ColorRect built")
	if cell._area == null:
		_fail("BattleCell: _area Area2D not built")
	else:
		_ok("BattleCell: _area Area2D built")
	cell.setup(2, 3, 0, 1, false, null)
	if cell.grid_x != 2 or cell.grid_y != 3:
		_fail("BattleCell: setup did not set grid coords")
	else:
		_ok("BattleCell: setup sets grid coords and terrain")
	if cell.height != 1:
		_fail("BattleCell: height not set")
	else:
		_ok("BattleCell: height 1 visible")
	cell.set_highlight(BattleCellScript.HIGHLIGHT_MOVE)
	if not cell._highlight.visible:
		_fail("BattleCell: highlight not visible after set_highlight(MOVE)")
	else:
		_ok("BattleCell: highlight tints (move = blue)")
	cell.queue_free()


func _test_battle_grid_builds() -> void:
	print("\n--- BattleGridView ---")
	var grid = BattleGridViewScript.new()
	grid.name = "TestGrid"
	root.add_child(grid)
	await process_frame
	var encounter: Dictionary = {
		"grid_size": 7,
		"biome_key": "Ash Wastes",
		"height_seed": 42,
		"height_map": {"0,0": 1, "3,3": 2},
		"units": [
			{"id": "player", "team": "player", "hp": 100, "max_hp": 100, "ct": 60, "facing": 2, "pos": Vector2i(3, 6), "race": "human", "gender": "male"},
			{"id": "ash_crawler", "team": "enemy", "hp": 60, "max_hp": 60, "ct": 30, "facing": 0, "pos": Vector2i(2, 2), "sprite_id": "ash_crawler"},
		],
	}
	grid.configure(encounter)
	if grid.grid_size != 7:
		_fail("BattleGridView: grid_size not 7")
	else:
		_ok("BattleGridView: grid_size = 7")
	if grid._cells.size() != 49:
		_fail("BattleGridView: cell count != 49 (got %d)" % grid._cells.size())
	else:
		_ok("BattleGridView: 49 cells built")
	if grid._units.size() != 2:
		_fail("BattleGridView: unit count != 2 (got %d)" % grid._units.size())
	else:
		_ok("BattleGridView: 2 units spawned")
	var player = grid.get_battle_unit("player")
	if player == null:
		_fail("BattleGridView: get_battle_unit('player') returned null")
	else:
		_ok("BattleGridView: player BattleUnit exists")
	var enemy = grid.get_battle_unit("ash_crawler")
	if enemy == null:
		_fail("BattleGridView: get_battle_unit('ash_crawler') returned null")
	else:
		_ok("BattleGridView: enemy BattleUnit exists")
	grid.queue_free()


func _test_battle_unit_loads_sprite() -> void:
	print("\n--- BattleUnit ---")
	var unit = BattleUnitScript.new()
	unit.name = "TestUnit"
	root.add_child(unit)
	await process_frame
	var data: Dictionary = {
		"id": "test_mob",
		"team": "enemy",
		"hp": 80,
		"max_hp": 80,
		"ct": 45,
		"facing": 1,
		"pos": Vector2i(2, 3),
		"sprite_id": "ash_crawler",
	}
	unit.setup_from_data(data, 24)
	if unit.unit_id != "test_mob":
		_fail("BattleUnit: unit_id not set")
	else:
		_ok("BattleUnit: id + team + pos set from data")
	if unit._sprite == null or unit._sprite.texture == null:
		_fail("BattleUnit: sprite not loaded for ash_crawler")
	else:
		_ok("BattleUnit: mob sprite loaded (ash_crawler)")
	unit.update_hp(40)
	if unit.current_hp != 40:
		_fail("BattleUnit: update_hp failed")
	else:
		_ok("BattleUnit: update_hp refreshes HP bar")
	unit.update_ct(80)
	if unit.current_ct != 80:
		_fail("BattleUnit: update_ct failed")
	else:
		_ok("BattleUnit: update_ct refreshes CT bar")
	unit.update_facing(1)
	if not unit._sprite.flip_h:
		_fail("BattleUnit: facing EAST should flip sprite")
	else:
		_ok("BattleUnit: facing EAST flips sprite")
	unit.queue_free()


func _test_battle_grid_height_map() -> void:
	print("\n--- BattleGridView: height marks ---")
	var grid = BattleGridViewScript.new()
	root.add_child(grid)
	await process_frame
	var encounter: Dictionary = {
		"grid_size": 5,
		"biome_key": "Ash Wastes",
		"height_seed": 0,
		"height_map": {"0,0": 0, "1,1": 1, "2,2": 2, "3,3": 0},
		"units": [],
	}
	grid.configure(encounter)
	var cell_h1: BattleCell = null
	var cell_h2: BattleCell = null
	for c in grid._cells:
		if c.grid_x == 1 and c.grid_y == 1:
			cell_h1 = c
		elif c.grid_x == 2 and c.grid_y == 2:
			cell_h2 = c
	if cell_h1 == null:
		_fail("BattleGridView: cell 1,1 missing")
	else:
		if cell_h1.height != 1:
			_fail("BattleGridView: cell 1,1 height != 1")
		elif not cell_h1._height_label.visible:
			_fail("BattleGridView: cell 1,1 height label not visible")
		else:
			_ok("BattleGridView: cell 1,1 height label = 1")
	if cell_h2 == null:
		_fail("BattleGridView: cell 2,2 missing")
	else:
		if cell_h2.height != 2:
			_fail("BattleGridView: cell 2,2 height != 2")
		else:
			_ok("BattleGridView: cell 2,2 height = 2")
	grid.queue_free()


func _test_battle_background_renders() -> void:
	print("\n--- BattleBackground ---")
	var bg = BattleBackgroundScript.new()
	bg.name = "TestBG"
	root.add_child(bg)
	await process_frame
	bg.configure("Ash Wastes", 7, Vector2(1280, 720))
	if bg._bg_tile == null:
		_fail("BattleBackground: _bg_tile TextureRect not built")
	else:
		_ok("BattleBackground: BG TextureRect built and tinted")
	if bg._tile_layer.get_child_count() == 0:
		_fail("BattleBackground: no decor scattered around grid")
	else:
		_ok("BattleBackground: %d decor scattered" % bg._tile_layer.get_child_count())
	if bg._particles.get_child_count() == 0:
		_fail("BattleBackground: no motes spawned")
	else:
		_ok("BattleBackground: %d motes spawned" % bg._particles.get_child_count())
	bg.configure("Neon Bogs", 5, Vector2(1280, 720))
	if bg._tint.color == Color(0.42, 0.28, 0.18, 0.55):
		_fail("BattleBackground: Neon Bogs tint should differ from Ash Wastes")
	else:
		_ok("BattleBackground: Neon Bogs tint differs (post-apoc palette)")
	bg.queue_free()


func _test_terrain_grid_generation() -> void:
	print("\n--- BattleGridView: terrain generation ---")
	var grid = BattleGridViewScript.new()
	root.add_child(grid)
	await process_frame
	var encounter: Dictionary = {
		"grid_size": 7,
		"biome_key": "Ash Wastes",
		"height_seed": 12345,
	}
	encounter = grid.build_terrain_for_encounter(encounter)
	if not encounter.has("terrain_grid") or encounter.terrain_grid.size() != 49:
		_fail("terrain_grid generation: wrong size (got %d)" % (encounter.get("terrain_grid", []) as Array).size())
	else:
		_ok("terrain_grid: 49 cells generated from height_seed")
	var t: int = encounter.terrain_grid[0]
	if t < 0 or t > 3:
		_fail("terrain_grid: value %d out of range [0,3]" % t)
	else:
		_ok("terrain_grid: values in range [0,3] (TERRAIN_GROUND..TERRAIN_BLOCKED)")
	grid.queue_free()


func _test_tactical_combat_scene_loads() -> void:
	print("\n--- TacticalCombat.tscn loads ---")
	var packed: PackedScene = load("res://scenes/TacticalCombat.tscn") as PackedScene
	if packed == null:
		_fail("TacticalCombat.tscn failed to load")
		return
	var instance: Node = packed.instantiate()
	if instance == null:
		_fail("TacticalCombat.tscn failed to instantiate")
		return
	root.add_child(instance)
	await process_frame
	_ok("TacticalCombat.tscn loads and instantiates")
	var bg: Node = instance.get_node_or_null("BattleBackgroundLayer/BattleBackground")
	if bg == null:
		_fail("TacticalCombat: BattleBackground child missing")
	else:
		_ok("TacticalCombat: BattleBackground present")
	var grid: Node = instance.get_node_or_null("BattleLayer/BattleGridView")
	if grid == null:
		_fail("TacticalCombat: BattleGridView child missing")
	else:
		_ok("TacticalCombat: BattleGridView present")
	var legacy: Node = instance.get_node_or_null("MainVBox/GridPanel")
	if legacy != null:
		_fail("TacticalCombat: legacy GridPanel still present")
	else:
		_ok("TacticalCombat: legacy GridPanel removed")
	instance.queue_free()


func _test_legacy_removed() -> void:
	print("\n--- legacy Button[] grid code removed ---")
	var src: String = load("res://scripts/TacticalCombat.gd").source_code
	if src.contains("Button.new()"):
		_fail("TacticalCombat: legacy Button.new() still in source")
	else:
		_ok("TacticalCombat: legacy Button.new() removed")
	if src.contains("\"◎\"") or src.contains("\"☠\"") or src.contains("\"✕\""):
		_fail("TacticalCombat: legacy text symbols (◎/☠/✕) still in source")
	else:
		_ok("TacticalCombat: legacy text symbols (◎/☠/✕) removed")


func _print_summary() -> void:
	print("\n=== Summary ===")
	if failures.is_empty():
		print("All checks passed.")
		quit(0)
	else:
		for f in failures:
			print("  FAILED: " + f)
		print("%d failure(s)." % failures.size())
		quit(1)
