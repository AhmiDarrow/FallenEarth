extends SceneTree
## Quick boot test for the new CombatLevel scene (v0.11.0).

const EncounterBuilder = preload("res://scripts/CombatEncounterBuilder.gd")

var failures: Array[String] = []


func _initialize() -> void:
	print("[boot-combat-v110] v0.11.0 CombatLevel F5-style boot test")
	# Build a simple encounter.
	var encounter: Dictionary = EncounterBuilder.build_rift_room(
		{"class": "recruit", "race": "human", "gender": "male"},
		"Ash Wastes", "rift_test_v110", 0, 0, "encounter", ""
	)
	# Instantiate the scene.
	var packed: PackedScene = load("res://scenes/CombatLevel.tscn") as PackedScene
	if packed == null:
		failures.append("CombatLevel.tscn failed to load")
		_print_summary()
		quit()
		return
	var instance: Node = packed.instantiate()
	if instance == null:
		failures.append("CombatLevel.tscn failed to instantiate")
		_print_summary()
		quit()
		return
	# Set the encounter BEFORE adding to the tree so _ready sees it.
	instance.set_encounter(encounter)
	root.add_child(instance)
	# Tick frames to let _ready build the arena + units.
	for i in range(30):
		await process_frame
	# Verify the arena built the tiles + units.
	var arena: Node = instance.get_node_or_null("ArenaLayer/CombatArena")
	if arena == null:
		failures.append("CombatArena not present at ArenaLayer/CombatArena")
	else:
		var tile_count: int = arena._tiles.size()
		if tile_count != 49:
			failures.append("CombatArena built %d tiles (expect 49 for 7x7)" % tile_count)
		else:
			print("  ok  CombatArena: %d tiles built (7x7)" % tile_count)
		var unit_count: int = arena._units.size()
		print("  ok  CombatArena: %d unit(s) on grid" % unit_count)
		for uid in arena._units:
			var u: Node = arena._units[uid]
			if u == null or not is_instance_valid(u):
				continue
			print("    - unit: %s team=%s pos=%s hp=%d/%d" % [u.res.unit_id, u.res.team, u.res.grid_pos, u.res.current_hp, u.res.max_hp])
	# Verify the participants exist.
	var player_res = instance._player
	if player_res == null:
		failures.append("CombatLevel: player participant not initialized")
	else:
		print("  ok  CombatLevel: player participant at stage %d" % player_res.stage)
	var opponent_res = instance._opponent
	if opponent_res == null:
		failures.append("CombatLevel: opponent participant not initialized")
	else:
		print("  ok  CombatLevel: opponent participant at stage %d" % opponent_res.stage)
	# Tick more frames to let the turn state machine run.
	for i in range(30):
		await process_frame
	print("[boot-combat-v110] 60 frames observed.")
	_print_summary()
	quit()


func _fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)


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
