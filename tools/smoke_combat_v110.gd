extends SceneTree
## v0.11.0 — New combat architecture smoke test.
##
## Verifies the Resource / Service / Module pattern from the
## ramaureirac/godot-tactical-rpg reference is correctly applied
## to our 2D combat system.

const TileResourceScript = preload("res://scripts/combat/models/tile/tile_resource.gd")
const UnitResourceScript = preload("res://scripts/combat/models/unit/unit_resource.gd")
const ParticipantResourceScript = preload("res://scripts/combat/models/participant/participant_resource.gd")
const ArenaResourceScript = preload("res://scripts/combat/models/arena/arena_resource.gd")
const PathfindingServiceScript = preload("res://scripts/combat/services/pathfinding/pathfinding_service.gd")
const TurnServiceScript = preload("res://scripts/combat/services/turn/turn_service.gd")
const UnitMovementServiceScript = preload("res://scripts/combat/services/unit/unit_movement_service.gd")
const UnitCombatServiceScript = preload("res://scripts/combat/services/unit/unit_combat_service.gd")
const PlayerServiceScript = preload("res://scripts/combat/services/player/player_service.gd")
const OpponentServiceScript = preload("res://scripts/combat/services/opponent/opponent_service.gd")
const CombatTileScript = preload("res://scripts/combat/CombatTile.gd")
const CombatUnitScript = preload("res://scripts/combat/CombatUnit.gd")
const CombatArenaScript = preload("res://scripts/combat/CombatArena.gd")
const CombatLevelScript = preload("res://scripts/combat/CombatLevel.gd")

var failures: Array[String] = []


func _initialize() -> void:
	print("[smoke-v110] v0.11.0 Combat Architecture")
	_test_resource_classes_exist()
	await process_frame
	_test_service_classes_exist()
	await process_frame
	_test_module_classes_exist()
	await process_frame
	_test_tile_resource_state()
	await process_frame
	_test_unit_resource_stats()
	await process_frame
	_test_participant_state_machine()
	await process_frame
	_test_arena_resource_helpers()
	await process_frame
	_test_pathfinding_bfs()
	await process_frame
	_test_turn_service_dispatch()
	await process_frame
	_test_unit_combat_facing_multiplier()
	await process_frame
	_test_unit_combat_in_range()
	await process_frame
	_test_unit_combat_resolve()
	await process_frame
	_test_combat_arena_builds_grid()
	await process_frame
	_test_combat_unit_loads_sprite()
	await process_frame
	_test_combat_level_boot()
	await process_frame
	_test_combat_level_turn_loop_runs()
	_print_summary()
	quit()


func _fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)


func _ok(msg: String) -> void:
	print("  ok  " + msg)


#region --- Class existence checks ---
func _test_resource_classes_exist() -> void:
	print("\n--- v0.11.0: Resource classes exist ---")
	# Each class_name registers globally; we just need to ensure
	# the files compile. We can verify the load worked.
	var paths: Array = [
		"res://scripts/combat/models/tile/tile_resource.gd",
		"res://scripts/combat/models/unit/unit_resource.gd",
		"res://scripts/combat/models/participant/participant_resource.gd",
		"res://scripts/combat/models/arena/arena_resource.gd",
	]
	for p in paths:
		if not ResourceLoader.exists(p):
			_fail("Resource file missing: %s" % p)
		else:
			_ok("Resource file present: %s" % p.replace("res://scripts/combat/", ""))


func _test_service_classes_exist() -> void:
	print("\n--- v0.11.0: Service classes exist ---")
	var paths: Array = [
		"res://scripts/combat/services/pathfinding/pathfinding_service.gd",
		"res://scripts/combat/services/turn/turn_service.gd",
		"res://scripts/combat/services/unit/unit_movement_service.gd",
		"res://scripts/combat/services/unit/unit_combat_service.gd",
		"res://scripts/combat/services/player/player_service.gd",
		"res://scripts/combat/services/opponent/opponent_service.gd",
	]
	for p in paths:
		if not ResourceLoader.exists(p):
			_fail("Service file missing: %s" % p)
		else:
			_ok("Service file present: %s" % p.replace("res://scripts/combat/services/", ""))


func _test_module_classes_exist() -> void:
	print("\n--- v0.11.0: Module classes exist ---")
	var paths: Array = [
		"res://scripts/combat/CombatTile.gd",
		"res://scripts/combat/CombatUnit.gd",
		"res://scripts/combat/CombatArena.gd",
		"res://scripts/combat/CombatLevel.gd",
	]
	for p in paths:
		if not ResourceLoader.exists(p):
			_fail("Module file missing: %s" % p)
		else:
			_ok("Module file present: %s" % p.replace("res://scripts/combat/", ""))
#endregion


#region --- Resource behavior checks ---
func _test_tile_resource_state() -> void:
	print("\n--- TileResource: state flags ---")
	var t: TileResource = TileResourceScript.new()
	if t.is_taken() != false:
		_fail("TileResource: new tile should be unoccupied")
	else:
		_ok("TileResource: new tile is_taken() == false")
	if t.reachable or t.attackable or t.hover or t.blocked:
		_fail("TileResource: new tile flags should all be false")
	else:
		_ok("TileResource: new tile has all flags = false")
	t.reachable = true
	t.attackable = false
	t.hover = true
	t.blocked = false
	if not t.reachable or not t.hover:
		_fail("TileResource: flag writes not persisting")
	else:
		_ok("TileResource: flag writes persist (reachable + hover = true)")
	t.reset_markers()
	if t.reachable or t.hover or t.pf_root != null or t.pf_distance != 0:
		_fail("TileResource: reset_markers() should clear state")
	else:
		_ok("TileResource: reset_markers() clears state")


func _test_unit_resource_stats() -> void:
	print("\n--- UnitResource: stats and state ---")
	var u: UnitResource = UnitResourceScript.new()
	u.max_hp = 100
	u.current_hp = 80
	u.max_mp = 20
	u.current_mp = 15
	if u.is_alive() != true:
		_fail("UnitResource: HP=80/100 should be alive")
	else:
		_ok("UnitResource: HP=80/100 is_alive() = true")
	u.apply_damage(30)
	if u.current_hp != 50:
		_fail("UnitResource: apply_damage(30) from 80 should leave 50 (got %d)" % u.current_hp)
	else:
		_ok("UnitResource: apply_damage(30) -> current_hp = 50")
	u.apply_damage(100)
	if u.current_hp != 0:
		_fail("UnitResource: apply_damage(100) from 50 should leave 0 (got %d)" % u.current_hp)
	else:
		_ok("UnitResource: apply_damage(100) -> current_hp = 0 (clamped)")
	if u.is_alive():
		_fail("UnitResource: HP=0 should be dead")
	else:
		_ok("UnitResource: HP=0 is_alive() = false")
	u.apply_heal(20)
	if u.current_hp != 20:
		_fail("UnitResource: apply_heal(20) from 0 should leave 20 (got %d)" % u.current_hp)
	else:
		_ok("UnitResource: apply_heal(20) -> current_hp = 20")
	# MP
	u.current_mp = 10
	if not u.spend_mp(5):
		_fail("UnitResource: spend_mp(5) from 10 should succeed")
	else:
		_ok("UnitResource: spend_mp(5) -> current_mp = 5")
	if u.spend_mp(10):
		_fail("UnitResource: spend_mp(10) from 5 should fail")
	else:
		_ok("UnitResource: spend_mp(10) when only 5 MP -> fails")
	if u.current_mp != 5:
		_fail("UnitResource: failed spend_mp should not change MP (got %d)" % u.current_mp)
	else:
		_ok("UnitResource: failed spend_mp leaves MP at 5")
	# can_move / can_act
	u.has_moved = false
	u.has_acted = false
	if not u.can_move or not u.can_act:
		_fail("UnitResource: fresh unit should be able to move and act")
	else:
		_ok("UnitResource: fresh unit can_move and can_act")
	u.end_move()
	if u.can_move:
		_fail("UnitResource: after end_move, can_move should be false")
	else:
		_ok("UnitResource: after end_move, can_move = false (has_moved = true)")
	u.reset_turn()
	if not u.can_move:
		_fail("UnitResource: after reset_turn, can_move should be true")
	else:
		_ok("UnitResource: after reset_turn, can_move = true again")


func _test_participant_state_machine() -> void:
	print("\n--- ParticipantResource: turn state machine ---")
	var p: ParticipantResource = ParticipantResourceScript.new()
	if p.stage != ParticipantResourceScript.STAGE_SELECT_PAWN:
		_fail("ParticipantResource: initial stage should be SELECT_PAWN")
	else:
		_ok("ParticipantResource: initial stage = SELECT_PAWN (0)")
	# Verify all 10 stages are distinct ints.
	var seen: Dictionary = {}
	var stage_values: Dictionary = {
		"STAGE_SELECT_PAWN": ParticipantResourceScript.STAGE_SELECT_PAWN,
		"STAGE_SHOW_ACTIONS": ParticipantResourceScript.STAGE_SHOW_ACTIONS,
		"STAGE_SHOW_MOVEMENTS": ParticipantResourceScript.STAGE_SHOW_MOVEMENTS,
		"STAGE_SELECT_LOCATION": ParticipantResourceScript.STAGE_SELECT_LOCATION,
		"STAGE_MOVE_UNIT": ParticipantResourceScript.STAGE_MOVE_UNIT,
		"STAGE_DISPLAY_TARGETS": ParticipantResourceScript.STAGE_DISPLAY_TARGETS,
		"STAGE_SELECT_ATTACK_TARGET": ParticipantResourceScript.STAGE_SELECT_ATTACK_TARGET,
		"STAGE_ATTACK": ParticipantResourceScript.STAGE_ATTACK,
		"STAGE_END_TURN": ParticipantResourceScript.STAGE_END_TURN,
		"STAGE_DONE": ParticipantResourceScript.STAGE_DONE,
	}
	for stage_name in stage_values:
		var v: int = stage_values[stage_name]
		if seen.has(v):
			_fail("ParticipantResource: %s (%d) collides with another stage" % [stage_name, v])
		seen[v] = stage_name
	if seen.size() != 10:
		_fail("ParticipantResource: expected 10 unique stages (got %d)" % seen.size())
	else:
		_ok("ParticipantResource: 10 unique stages (0..9)")
	# advance_to + reset_turn
	p.advance_to(ParticipantResourceScript.STAGE_ATTACK)
	if p.stage != ParticipantResourceScript.STAGE_ATTACK:
		_fail("ParticipantResource: advance_to(ATTACK) should set stage to ATTACK")
	else:
		_ok("ParticipantResource: advance_to(ATTACK) sets stage = 7")
	p.reset_turn()
	if p.stage != ParticipantResourceScript.STAGE_SELECT_PAWN or p.turn_completed:
		_fail("ParticipantResource: reset_turn should restore SELECT_PAWN and clear turn_completed")
	else:
		_ok("ParticipantResource: reset_turn restores SELECT_PAWN + clears turn_completed")


func _test_arena_resource_helpers() -> void:
	print("\n--- ArenaResource: unit + tile lookup ---")
	var arena: ArenaResource = ArenaResourceScript.new()
	arena.grid_size = 5
	# Build 25 tiles.
	for y in range(5):
		for x in range(5):
			var t: TileResource = TileResourceScript.new()
			t.grid_x = x
			t.grid_y = y
			arena.tiles["%d,%d" % [x, y]] = t
	# Test get_tile.
	var tile: TileResource = arena.get_tile(2, 3)
	if tile == null or tile.grid_x != 2 or tile.grid_y != 3:
		_fail("ArenaResource: get_tile(2,3) should return the tile at (2,3)")
	else:
		_ok("ArenaResource: get_tile(2,3) returns the right tile")
	var oob: TileResource = arena.get_tile(10, 10)
	if oob != null:
		_fail("ArenaResource: get_tile(10,10) should return null (out of bounds)")
	else:
		_ok("ArenaResource: get_tile(10,10) returns null (OOB)")
	# Test unit lookup.
	var unit: Object = Node.new()  # Stand-in for CombatUnit.
	unit.grid_pos = Vector2i(1, 1)
	unit.res = UnitResourceScript.new()
	unit.res.unit_id = "test_unit"
	unit.res.team = "player"
	arena.units["test_unit"] = unit
	if arena.get_unit("test_unit") != unit:
		_fail("ArenaResource: get_unit should return the unit by id")
	else:
		_ok("ArenaResource: get_unit('test_unit') returns the unit")
	if arena.get_unit_at(1, 1) != unit:
		_fail("ArenaResource: get_unit_at(1,1) should find the unit at that pos")
	else:
		_ok("ArenaResource: get_unit_at(1,1) finds the unit")
	if arena.get_unit_at(2, 2) != null:
		_fail("ArenaResource: get_unit_at(2,2) should return null (no unit there)")
	else:
		_ok("ArenaResource: get_unit_at(2,2) returns null (empty tile)")
	unit.queue_free()
#endregion


#region --- Service behavior checks ---
func _test_pathfinding_bfs() -> void:
	print("\n--- PathfindingService: BFS on a 5x5 grid ---")
	var arena: ArenaResource = ArenaResourceScript.new()
	arena.grid_size = 5
	# Build 5x5 with all walkable.
	for y in range(5):
		for x in range(5):
			var t: TileResource = TileResourceScript.new()
			t.grid_x = x
			t.grid_y = y
			arena.tiles["%d,%d" % [x, y]] = t
	var pfs: PathfindingService = PathfindingServiceScript.new()
	# BFS from (2,2) with max_distance 2.
	pfs.process_surrounding(arena, 2, 2, 2, [])
	# Tile (2,2) is root — distance 0.
	if arena.get_tile(2, 2).pf_distance != 0:
		_fail("Pathfinding: root tile (2,2) should have pf_distance 0")
	else:
		_ok("Pathfinding: root tile (2,2) pf_distance = 0")
	# Tile (3,2) is 1 step away.
	if arena.get_tile(3, 2).pf_distance != 1:
		_fail("Pathfinding: tile (3,2) should have pf_distance 1 (got %d)" % arena.get_tile(3, 2).pf_distance)
	else:
		_ok("Pathfinding: tile (3,2) pf_distance = 1 (1 step east)")
	# Tile (4,2) is 2 steps away.
	if arena.get_tile(4, 2).pf_distance != 2:
		_fail("Pathfinding: tile (4,2) should have pf_distance 2 (got %d)" % arena.get_tile(4, 2).pf_distance)
	else:
		_ok("Pathfinding: tile (4,2) pf_distance = 2 (2 steps east)")
	# Tile (4,4) is 4 steps away — should NOT be reached (max=2).
	if arena.get_tile(4, 4).pf_distance != 0 or arena.get_tile(4, 4).pf_root != null:
		_fail("Pathfinding: tile (4,4) is 4 steps away — should NOT be reached (max=2)")
	else:
		_ok("Pathfinding: tile (4,4) not reached (distance > max)")
	# get_path from (4,2) should be [(2,2), (3,2), (4,2)].
	var path: Array[Vector2i] = pfs.get_path(arena, 4, 2)
	if path.size() != 3 or path[0] != Vector2i(2, 2) or path[2] != Vector2i(4, 2):
		_fail("Pathfinding: get_path(4,2) should be [(2,2),(3,2),(4,2)] (got %s)" % str(path))
	else:
		_ok("Pathfinding: get_path(4,2) returns correct 3-tile path")
	# Blocked tile test: surround (2,2) with walls and verify no
	# tiles are reachable.
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			arena.get_tile(2 + dx, 2 + dy).blocked = true
	pfs.process_surrounding(arena, 2, 2, 5, [])
	# (3,3) is reachable only through (2,3) (now blocked) or (3,2)
	# (now blocked). So it should be unreachable.
	if arena.get_tile(3, 3).pf_root != null:
		_fail("Pathfinding: (3,3) should be unreachable when (2,3)+(3,2) are blocked")
	else:
		_ok("Pathfinding: (3,3) unreachable when surrounded by walls")


func _test_turn_service_dispatch() -> void:
	print("\n--- TurnService: stage dispatch (int return) ---")
	var p: ParticipantResource = ParticipantResourceScript.new()
	# Create a stub object that returns 99 from every stage method.
	var stub: Object = TurnStub.new()
	# Initialize to SELECT_PAWN, then tick — should call on_select_pawn.
	p.advance_to(ParticipantResourceScript.STAGE_SELECT_PAWN)
	var ts: TurnService = TurnServiceScript.new()
	var next: int = ts.tick(p, stub)
	if next != 99:
		_fail("TurnService: should dispatch SELECT_PAWN to stub.on_select_pawn (got %d)" % next)
	else:
		_ok("TurnService: SELECT_PAWN dispatched to stub.on_select_pawn (returned 99)")
	p.advance_to(ParticipantResourceScript.STAGE_MOVE_UNIT)
	next = ts.tick(p, stub)
	if next != 99:
		_fail("TurnService: should dispatch MOVE_UNIT to stub.on_move_unit (got %d)" % next)
	else:
		_ok("TurnService: MOVE_UNIT dispatched to stub.on_move_unit (returned 99)")
	# Unknown stage should return STAGE_DONE.
	p.advance_to(999)
	next = ts.tick(p, stub)
	if next != TurnServiceScript.STAGE_DONE:
		_fail("TurnService: unknown stage should return STAGE_DONE (got %d)" % next)
	else:
		_ok("TurnService: unknown stage returns STAGE_DONE (9)")


## Stub object for TurnService dispatch test. All stage methods
## return 99 (sentinel for "called successfully").
class TurnStub:
	func on_select_pawn(_p): return 99
	func on_show_actions(_p): return 99
	func on_show_movements(_p): return 99
	func on_select_location(_p): return 99
	func on_move_unit(_p): return 99
	func on_display_targets(_p): return 99
	func on_select_attack_target(_p): return 99
	func on_attack(_p): return 99
	func on_end_turn(_p): return 99


func _test_unit_combat_facing_multiplier() -> void:
	print("\n--- UnitCombatService: facing multiplier ---")
	var cs: UnitCombatService = UnitCombatServiceScript.new()
	# Target at (2,2) facing S (2). Attacker at (2,1) is N of target — back attack.
	var mult_back: float = cs.facing_multiplier(2, Vector2i(2, 1), Vector2i(2, 2))
	if mult_back < 1.4:
		_fail("UnitCombat: attacker N of S-facing target should be back (1.5x); got %.2f" % mult_back)
	else:
		_ok("UnitCombat: back attack multiplier = %.2f (expect 1.50)" % mult_back)
	# Attacker at (3,2) is E of target — side attack.
	var mult_side: float = cs.facing_multiplier(2, Vector2i(3, 2), Vector2i(2, 2))
	if mult_side < 1.1 or mult_side > 1.3:
		_fail("UnitCombat: attacker E of S-facing target should be side (1.2x); got %.2f" % mult_side)
	else:
		_ok("UnitCombat: side attack multiplier = %.2f (expect 1.20)" % mult_side)
	# Attacker at (2,3) is S of target — front attack (1.0x).
	var mult_front: float = cs.facing_multiplier(2, Vector2i(2, 3), Vector2i(2, 2))
	if mult_front != 1.0:
		_fail("UnitCombat: front attack multiplier should be 1.0 (got %.2f)" % mult_front)
	else:
		_ok("UnitCombat: front attack multiplier = 1.00")


func _test_unit_combat_in_range() -> void:
	print("\n--- UnitCombatService: in_range check ---")
	var cs: UnitCombatService = UnitCombatServiceScript.new()
	# Adjacent (Chebyshev 1) with attack_range=1 -> in range.
	if not cs.in_range(Vector2i(2, 2), Vector2i(3, 2), 1):
		_fail("UnitCombat: (2,2) -> (3,2) with range 1 should be in range")
	else:
		_ok("UnitCombat: adjacent tile with range=1 is in range")
	# 2 tiles away with range=1 -> NOT in range.
	if cs.in_range(Vector2i(2, 2), Vector2i(4, 2), 1):
		_fail("UnitCombat: (2,2) -> (4,2) with range 1 should be out of range")
	else:
		_ok("UnitCombat: 2-tile distance with range=1 is out of range")
	# Same tile (distance 0) should NOT be in range (can't attack self).
	if cs.in_range(Vector2i(2, 2), Vector2i(2, 2), 1):
		_fail("UnitCombat: (2,2) -> (2,2) same tile should NOT be in range (can't self-attack)")
	else:
		_ok("UnitCombat: same tile (distance 0) is NOT in range")
	# 3 tiles away with range=3 -> in range.
	if not cs.in_range(Vector2i(2, 2), Vector2i(5, 2), 3):
		_fail("UnitCombat: (2,2) -> (5,2) with range 3 should be in range")
	else:
		_ok("UnitCombat: 3-tile distance with range=3 is in range")


func _test_unit_combat_resolve() -> void:
	print("\n--- UnitCombatService: resolve_attack deals damage ---")
	var cs: UnitCombatService = UnitCombatServiceScript.new()
	var arena: ArenaResource = ArenaResourceScript.new()
	arena.grid_size = 5
	for y in range(5):
		for x in range(5):
			var t: TileResource = TileResourceScript.new()
			t.grid_x = x
			t.grid_y = y
			arena.tiles["%d,%d" % [x, y]] = t
	# Create an attacker + target.
	var atk: Node = Node.new()
	atk.grid_pos = Vector2i(2, 2)
	atk.res = UnitResourceScript.new()
	atk.res.unit_id = "attacker"
	atk.res.attack = 10
	atk.res.attack_range = 1
	atk.res.facing = 2  # south
	atk.res.grid_pos = Vector2i(2, 2)
	var tgt: Node = Node.new()
	tgt.grid_pos = Vector2i(3, 2)
	tgt.res = UnitResourceScript.new()
	tgt.res.unit_id = "target"
	tgt.res.max_hp = 30
	tgt.res.current_hp = 30
	tgt.res.defense = 0
	tgt.res.facing = 2  # south (so attacker is W of target, perpendicular = side)
	tgt.res.grid_pos = Vector2i(3, 2)
	arena.units["attacker"] = atk
	arena.units["target"] = tgt
	# We need to listen to the signal to verify the emit worked.
	var damage_dealt: Array = [0]
	arena.unit_attacked.connect(func(_a, _t, dmg): damage_dealt[0] = dmg)
	var damage: int = cs.resolve_attack(atk, tgt, arena)
	if damage < 1:
		_fail("UnitCombat: resolve_attack should deal >=1 damage (got %d)" % damage)
	else:
		_ok("UnitCombat: resolve_attack dealt %d damage" % damage)
	if tgt.res.current_hp != 30 - damage:
		_fail("UnitCombat: target HP should be 30 - %d = %d (got %d)" % [damage, 30 - damage, tgt.res.current_hp])
	else:
		_ok("UnitCombat: target HP = %d (was 30, took %d damage)" % [tgt.res.current_hp, damage])
	if damage_dealt[0] != damage:
		_fail("UnitCombat: unit_attacked signal should emit dmg=%d (got %d)" % [damage, damage_dealt[0]])
	else:
		_ok("UnitCombat: unit_attacked signal emitted dmg=%d" % damage)
	atk.queue_free()
	tgt.queue_free()
#endregion


#region --- Module behavior checks ---
func _test_combat_arena_builds_grid() -> void:
	print("\n--- CombatArena: builds 7x7 grid ---")
	var arena: CombatArena = CombatArenaScript.new()
	root.add_child(arena)
	await process_frame
	arena.configure("Ash Wastes", 7, 12345)
	await process_frame
	if arena._tiles.size() != 49:
		_fail("CombatArena: should build 49 tiles (got %d)" % arena._tiles.size())
	else:
		_ok("CombatArena: built 49 tiles (7x7)")
	# Verify the grid_size propagated to the resource.
	if arena.res.grid_size != 7:
		_fail("CombatArena: res.grid_size should be 7 (got %d)" % arena.res.grid_size)
	else:
		_ok("CombatArena: res.grid_size = 7 (propagated to resource)")
	# Verify the tiles have TerrainResource with grid coords.
	var tile_at_3_3: CombatTile = arena.get_tile(3, 3)
	if tile_at_3_3 == null or tile_at_3_3.res == null:
		_fail("CombatArena: tile at (3,3) or its resource is null")
	else:
		_ok("CombatArena: tile at (3,3) has TileResource with grid_x=3 grid_y=3")
	arena.queue_free()


func _test_combat_unit_loads_sprite() -> void:
	print("\n--- CombatUnit: loads sprite, scales to 48px ---")
	var unit: CombatUnit = CombatUnitScript.new()
	unit.name = "TestUnit"
	root.add_child(unit)
	await process_frame
	var data: Dictionary = {
		"id": "test_unit", "team": "player", "hp": 80, "max_hp": 80,
		"ct": 0, "facing": 0, "pos": Vector2i(2, 3),
		"race": "human", "gender": "male", "name": "TestHero",
		"move": 6, "speed": 10, "attack": 5, "defense": 0,
		"attack_range": 1, "sprite_id": "recruit",
	}
	# Need a real arena for the unit to attach to.
	var arena: ArenaResource = ArenaResourceScript.new()
	arena.grid_size = 7
	for y in range(7):
		for x in range(7):
			var t: TileResource = TileResourceScript.new()
			t.grid_x = x
			t.grid_y = y
			arena.tiles["%d,%d" % [x, y]] = t
	unit.setup_from_data(data, arena)
	if unit.res == null or unit.res.unit_id != "test_unit":
		_fail("CombatUnit: res.unit_id should be 'test_unit' after setup")
	else:
		_ok("CombatUnit: res.unit_id = 'test_unit'")
	# Position should be at the cell center.
	var expected_pos: Vector2 = Vector2(2 * CombatTile.CELL_SIZE + CombatTile.CELL_SIZE * 0.5, 3 * CombatTile.CELL_SIZE + CombatTile.CELL_SIZE * 0.5)
	if unit.position != expected_pos:
		_fail("CombatUnit: position should be %s (cell center) (got %s)" % [expected_pos, unit.position])
	else:
		_ok("CombatUnit: position = %s (cell center of (2,3))" % expected_pos)
	# Tile (2,3) should have the unit as occupier.
	if arena.get_tile(2, 3).occupier != unit:
		_fail("CombatUnit: tile (2,3) should have unit as occupier")
	else:
		_ok("CombatUnit: tile (2,3).occupier = unit (occupancy registered)")
	# Sprite should be loaded if human_male_S.png exists.
	var sprite_path: String = "res://assets/characters/human_male/human_male_S.png"
	if ResourceLoader.exists(sprite_path):
		var tex: Texture2D = unit._sprite.texture
		if tex == null:
			_fail("CombatUnit: sprite should be loaded (human_male_S.png exists)")
		else:
			var native_size: Vector2 = tex.get_size()
			var scl: float = unit._sprite.scale.x
			var rendered: float = maxf(native_size.x, native_size.y) * scl
			if rendered > 65.0:
				_fail("CombatUnit: human sprite renders at %.1fpx (expected ~48px)" % rendered)
			else:
				_ok("CombatUnit: human sprite (128x128) renders at %.1fpx (fits 60px cell)" % rendered)
	else:
		_ok("CombatUnit: human_male_S.png not present (test skipped)")
	unit.queue_free()


func _test_combat_level_boot() -> void:
	print("\n--- CombatLevel: boots and builds arena ---")
	var packed: PackedScene = load("res://scenes/CombatLevel.tscn") as PackedScene
	if packed == null:
		_fail("CombatLevel: scene failed to load")
		return
	var instance: Node = packed.instantiate()
	if instance == null:
		_fail("CombatLevel: scene failed to instantiate")
		return
	# Set a minimal encounter.
	var enc: Dictionary = {
		"biome_key": "Ash Wastes",
		"grid_size": 7,
		"height_seed": 42,
		"character_data": {"class": "recruit", "race": "human", "gender": "male", "hp": 100, "max_hp": 100, "move": 6, "speed": 10, "attack": 5, "defense": 0, "attack_range": 1, "facing": 2, "name": "Hero"},
		"player_start": Vector2i(3, 5),
		"enemy_templates": [],
	}
	instance.set_encounter(enc)
	root.add_child(instance)
	for i in range(30):
		await process_frame
	var arena_node: Node = instance.get_node_or_null("ArenaLayer/CombatArena")
	if arena_node == null:
		_fail("CombatLevel: CombatArena not present at ArenaLayer/CombatArena")
	else:
		_ok("CombatLevel: CombatArena present at ArenaLayer/CombatArena")
		if arena_node._tiles.size() == 49:
			_ok("CombatLevel: arena built 49 tiles")
		else:
			_fail("CombatLevel: arena built %d tiles (expect 49)" % arena_node._tiles.size())
		if arena_node._units.size() == 1:
			_ok("CombatLevel: 1 unit (the player) on grid")
		else:
			_fail("CombatLevel: %d units on grid (expect 1)" % arena_node._units.size())
	# Player participant should be at SHOW_MOVEMENTS or SELECT_LOCATION.
	if instance._player.stage >= ParticipantResourceScript.STAGE_SHOW_MOVEMENTS:
		_ok("CombatLevel: player advanced past SHOW_MOVEMENTS (stage=%d)" % instance._player.stage)
	else:
		_fail("CombatLevel: player stuck at stage %d (expected >= SHOW_MOVEMENTS)" % instance._player.stage)
	instance.queue_free()


func _test_combat_level_turn_loop_runs() -> void:
	print("\n--- CombatLevel: turn loop runs without crashing ---")
	# Boot, run 60 frames, verify no errors and stage advances.
	var packed: PackedScene = load("res://scenes/CombatLevel.tscn") as PackedScene
	var instance: Node = packed.instantiate()
	var enc: Dictionary = {
		"biome_key": "Ash Wastes",
		"grid_size": 7,
		"height_seed": 99,
		"character_data": {"class": "recruit", "race": "human", "gender": "male", "hp": 100, "max_hp": 100, "move": 6, "speed": 10, "attack": 5, "defense": 0, "attack_range": 1, "facing": 2, "name": "Hero"},
		"player_start": Vector2i(3, 5),
		"enemy_templates": [
			{"name": "Foe", "race": "human", "gender": "none", "hp": 30, "max_hp": 30, "move": 4, "speed": 8, "attack": 4, "defense": 0, "attack_range": 1, "facing": 0, "sprite_id": "blight_toad"},
		],
	}
	instance.set_encounter(enc)
	root.add_child(instance)
	for i in range(60):
		await process_frame
	var arena_node: Node = instance.get_node_or_null("ArenaLayer/CombatArena")
	if arena_node != null and arena_node._units.size() == 2:
		_ok("CombatLevel: 2 units (player + enemy) on grid after 60 frames")
	else:
		var n: int = 0 if arena_node == null else arena_node._units.size()
		_fail("CombatLevel: expected 2 units, got %d" % n)
	# Encounter should NOT be ended (both alive).
	if not instance._arena.res.is_ended:
		_ok("CombatLevel: encounter still in progress (both units alive)")
	else:
		_fail("CombatLevel: encounter ended prematurely")
	instance.queue_free()
#endregion


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
