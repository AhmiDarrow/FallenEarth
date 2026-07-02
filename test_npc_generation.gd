extends SceneTree

const NPCGeneratorScript = preload("res://scripts/NPCGenerator.gd")

func _initialize() -> void:
	var errors: Array[String] = []
	var tile_map: Dictionary = {
		"0,0": {"name": "Ash Wastes", "rift_chance": 0.2, "temperature": 0.5, "rainfall": 0.4, "elevation": 0.5},
		"1,0": {"name": "Rust Canyons", "rift_chance": 0.6, "temperature": 0.6, "rainfall": 0.3, "elevation": 0.4},
		"2,0": {"name": "Neon Bogs", "rift_chance": 0.5, "temperature": 0.7, "rainfall": 0.8, "elevation": 0.3},
		"-1,1": {"name": "Scorched Plains", "rift_chance": 0.3, "temperature": 0.8, "rainfall": 0.2, "elevation": 0.6},
		"3,-1": {"name": "Glass Dunes", "rift_chance": 0.7, "temperature": 0.5, "rainfall": 0.1, "elevation": 0.7},
	}

	var roster_a: Dictionary = NPCGeneratorScript.generate_world_roster("TEST_SEED_42", tile_map, "0,0")
	var roster_b: Dictionary = NPCGeneratorScript.generate_world_roster("TEST_SEED_42", tile_map, "0,0")
	var roster_c: Dictionary = NPCGeneratorScript.generate_world_roster("OTHER_SEED_99", tile_map, "0,0")

	if roster_a.is_empty():
		errors.append("Roster A empty")
	if roster_a.size() != roster_b.size():
		errors.append("Determinism size mismatch: %d vs %d" % [roster_a.size(), roster_b.size()])

	var ids_a: Array = roster_a.keys()
	ids_a.sort()
	var ids_b: Array = roster_b.keys()
	ids_b.sort()
	if ids_a != ids_b:
		errors.append("Determinism id mismatch")

	for npc_id in roster_a:
		var npc: Dictionary = roster_a[npc_id]
		for field in ["id", "name", "race", "class", "faction", "tile_key", "recruitment", "vendor"]:
			if not npc.has(field):
				errors.append("NPC %s missing field %s" % [npc_id, field])

	if roster_a.hash() == roster_c.hash() and roster_a.size() > 0:
		errors.append("Different seeds produced identical roster hash (unexpected)")

	if errors.is_empty():
		print("[test_npc_generation] PASS — %d NPCs, deterministic across runs." % roster_a.size())
	else:
		for e in errors:
			push_error(e)
		print("[test_npc_generation] FAIL — %d error(s)." % errors.size())
	quit()