extends SceneTree
## v0.10.0 — Combat AI smoke test.
##
## Verifies each AI archetype produces sensible decisions on a
## controlled 7x7 grid. Each test stands up the AI, builds a
## state with a specific layout, and checks the returned action
## is reasonable.

const CombatAIEngine = preload("res://scripts/ai/CombatAIEngine.gd")
const AggressiveAI = preload("res://scripts/ai/AggressiveAI.gd")
const RangedAI = preload("res://scripts/ai/RangedAI.gd")
const CasterAI = preload("res://scripts/ai/CasterAI.gd")
const DefensiveAI = preload("res://scripts/ai/DefensiveAI.gd")
const BossAI = preload("res://scripts/ai/BossAI.gd")

var failures: Array[String] = []


func _initialize() -> void:
	print("[smoke-v100-ai] v0.10.0 Combat AI")
	_test_aggressive_attacks_when_in_range()
	await process_frame
	_test_aggressive_moves_closer_when_out_of_range()
	await process_frame
	_test_ranged_maintains_distance()
	await process_frame
	_test_caster_prefers_skill_with_mp()
	await process_frame
	_test_defensive_retreats_at_low_hp()
	await process_frame
	_test_boss_enrages_at_low_hp()
	await process_frame
	_test_mobs_have_ai_archetype()
	_print_summary()
	quit()


func _fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)


func _ok(msg: String) -> void:
	print("  ok  " + msg)


func _make_self(pos: Vector2i, team: String, hp_ratio: float, weapon_range: int, move: int, ai_archetype: String) -> Dictionary:
	var hp: int = int(100.0 * hp_ratio)
	return {
		"id": "self",
		"team": team,
		"name": "TestSelf",
		"pos": pos,
		"hp": hp,
		"max_hp": 100,
		"ct": 100,
		"facing": 2,
		"speed": 8,
		"move": move,
		"jump": 2,
		"weapon_range": weapon_range,
		"ai_archetype": ai_archetype,
		"abilities": [
			{"id": "fireball", "name": "Fireball", "mp_cost": 8, "range": 3, "radius": 1, "type": "magical"},
			{"id": "signature_strike", "name": "Signature Strike", "mp_cost": 20, "range": 2, "radius": 1, "type": "physical", "is_signature": true},
		],
		"mp": 20,
		"is_boss": ai_archetype == "boss",
	}


func _make_enemy(pos: Vector2i, hp: int = 50) -> Dictionary:
	return {
		"id": "enemy_%d_%d" % [pos.x, pos.y],
		"team": "player" if false else "player",
		"name": "Enemy",
		"pos": pos,
		"hp": hp,
		"max_hp": 100,
		"facing": 2,
	}


func _test_aggressive_attacks_when_in_range() -> void:
	print("\n--- AggressiveAI: attack when in range ---")
	var ai = AggressiveAI.new()
	var self_unit: Dictionary = _make_self(Vector2i(2, 2), "enemy", 1.0, 1, 3, "aggressive")
	var enemies: Array = [
		_make_enemy(Vector2i(2, 1)),  # within range 1
		_make_enemy(Vector2i(2, 0)),  # closer to back
	]
	var reachable: Array = [Vector2i(2, 1), Vector2i(2, 2), Vector2i(1, 2), Vector2i(3, 2)]
	var attackable: Array = [Vector2i(2, 1), Vector2i(2, 3)]
	var state: Dictionary = CombatAIEngine.build_state(
		self_unit, enemies, 7, {}, reachable, attackable, [], [], true
	)
	var action: Dictionary = ai.decide(state)
	if action.get("type", "wait") != "attack":
		_fail("AggressiveAI: should attack when in range, got %s" % action.get("type", "?"))
	else:
		_ok("AggressiveAI: attacks when enemy in range (target %s)" % str(action.get("target", Vector2i.ZERO)))
	ai.free()


func _test_aggressive_moves_closer_when_out_of_range() -> void:
	print("\n--- AggressiveAI: move closer when out of range ---")
	var ai = AggressiveAI.new()
	var self_unit: Dictionary = _make_self(Vector2i(0, 0), "enemy", 1.0, 1, 3, "aggressive")
	var enemies: Array = [
		_make_enemy(Vector2i(5, 5)),  # far away
	]
	var reachable: Array = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1),
		Vector2i(2, 0), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2),
	]
	var attackable: Array = []
	var state: Dictionary = CombatAIEngine.build_state(
		self_unit, enemies, 7, {}, reachable, attackable, [], [], true
	)
	var action: Dictionary = ai.decide(state)
	if action.get("type", "wait") != "move":
		_fail("AggressiveAI: should move when out of range, got %s" % action.get("type", "?"))
	else:
		var tgt: Vector2i = action.get("target", Vector2i.ZERO)
		# We should move to a tile that's at least 1 closer to (5,5).
		if tgt.x + tgt.y <= 0:
			_fail("AggressiveAI: didn't move toward enemy (target %s)" % str(tgt))
		else:
			_ok("AggressiveAI: moves toward distant enemy (target %s)" % str(tgt))
	ai.free()


func _test_ranged_maintains_distance() -> void:
	print("\n--- RangedAI: maintains distance ---")
	var ai = RangedAI.new()
	# Self at (1,1), enemy at (1,2) — way too close. AI should retreat.
	var self_unit: Dictionary = _make_self(Vector2i(1, 1), "enemy", 1.0, 3, 4, "ranged")
	var enemies: Array = [_make_enemy(Vector2i(1, 2))]
	var reachable: Array = [
		Vector2i(1, 1), Vector2i(0, 1), Vector2i(0, 0), Vector2i(0, 2),
		Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2),
	]
	var attackable: Array = []
	var state: Dictionary = CombatAIEngine.build_state(
		self_unit, enemies, 7, {}, reachable, attackable, [], [], true
	)
	var action: Dictionary = ai.decide(state)
	if action.get("type", "wait") != "move":
		_fail("RangedAI: should retreat when too close, got %s" % action.get("type", "?"))
	else:
		var tgt: Vector2i = action.get("target", Vector2i.ZERO)
		# Distance to (1,2) should INCREASE after the move.
		var old_d: int = maxi(abs(1 - 1), abs(1 - 2))
		var new_d: int = maxi(abs(tgt.x - 1), abs(tgt.y - 2))
		if new_d <= old_d:
			_fail("RangedAI: didn't retreat (old d=%d, new d=%d)" % [old_d, new_d])
		else:
			_ok("RangedAI: retreats when too close (old d=%d, new d=%d)" % [old_d, new_d])
	# Now test attacking when in range.
	var self2: Dictionary = _make_self(Vector2i(1, 1), "enemy", 1.0, 3, 4, "ranged")
	var enemies2: Array = [_make_enemy(Vector2i(1, 4))]  # 3 tiles away
	var attackable2: Array = [Vector2i(1, 4), Vector2i(1, 2)]
	var state2: Dictionary = CombatAIEngine.build_state(
		self2, enemies2, 7, {}, [], attackable2, [], [], true
	)
	var action2: Dictionary = ai.decide(state2)
	if action2.get("type", "wait") != "attack":
		_fail("RangedAI: should attack when in range, got %s" % action2.get("type", "?"))
	else:
		_ok("RangedAI: attacks when enemy in range")
	ai.free()


func _test_caster_prefers_skill_with_mp() -> void:
	print("\n--- CasterAI: prefers skill with MP ---")
	var ai = CasterAI.new()
	var self_unit: Dictionary = _make_self(Vector2i(3, 3), "enemy", 1.0, 2, 3, "caster")
	self_unit["mp"] = 20
	var enemies: Array = [
		_make_enemy(Vector2i(3, 2)),
		_make_enemy(Vector2i(3, 4)),
	]
	var reachable: Array = [Vector2i(3, 3)]
	var attackable: Array = [Vector2i(3, 2), Vector2i(3, 4)]
	var skillable: Array = [Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4), Vector2i(2, 3), Vector2i(4, 3)]
	var state: Dictionary = CombatAIEngine.build_state(
		self_unit, enemies, 7, {}, reachable, attackable, skillable, [], true
	)
	var action: Dictionary = ai.decide(state)
	if action.get("type", "wait") != "skill":
		_fail("CasterAI: should cast skill with MP available, got %s" % action.get("type", "?"))
	else:
		_ok("CasterAI: casts fireball (%s to %s)" % [action.get("skill_id", "?"), str(action.get("target", Vector2i.ZERO))])
	# Now test with no MP: should fall back to attack.
	self_unit["mp"] = 0
	var state2: Dictionary = CombatAIEngine.build_state(
		self_unit, enemies, 7, {}, reachable, attackable, skillable, [], true
	)
	var action2: Dictionary = ai.decide(state2)
	if action2.get("type", "wait") != "attack":
		_fail("CasterAI: should fall back to attack without MP, got %s" % action2.get("type", "?"))
	else:
		_ok("CasterAI: falls back to attack without MP")
	ai.free()


func _test_defensive_retreats_at_low_hp() -> void:
	print("\n--- DefensiveAI: retreats at < 30% HP ---")
	var ai = DefensiveAI.new()
	# Critically low HP — should try to retreat.
	var self_unit: Dictionary = _make_self(Vector2i(3, 3), "enemy", 0.20, 1, 3, "defensive")
	var enemies: Array = [_make_enemy(Vector2i(3, 4))]
	var reachable: Array = [
		Vector2i(3, 3), Vector2i(2, 3), Vector2i(4, 3),
		Vector2i(3, 2), Vector2i(3, 1), Vector2i(2, 2), Vector2i(4, 2),
		Vector2i(0, 3), Vector2i(1, 3),  # far tiles
	]
	var attackable: Array = [Vector2i(3, 4)]
	var state: Dictionary = CombatAIEngine.build_state(
		self_unit, enemies, 7, {}, reachable, attackable, [], [], true
	)
	var action: Dictionary = ai.decide(state)
	if action.get("type", "wait") != "move":
		_fail("DefensiveAI: should retreat at < 30% HP, got %s" % action.get("type", "?"))
	else:
		var tgt: Vector2i = action.get("target", Vector2i.ZERO)
		# Target should be FARTHER from the enemy at (3,4) than (3,3).
		var old_d: int = maxi(abs(3 - 3), abs(3 - 4))
		var new_d: int = maxi(abs(tgt.x - 3), abs(tgt.y - 4))
		if new_d <= old_d:
			_fail("DefensiveAI: retreat didn't increase distance (old=%d, new=%d)" % [old_d, new_d])
		else:
			_ok("DefensiveAI: retreats at < 30%% HP (old d=%d, new d=%d)" % [old_d, new_d])
	ai.free()


func _test_boss_enrages_at_low_hp() -> void:
	print("\n--- BossAI: enrages at < 25% HP ---")
	var ai = BossAI.new()
	# 20% HP — should use signature ability.
	var self_unit: Dictionary = _make_self(Vector2i(3, 3), "enemy", 0.20, 1, 3, "boss")
	var enemies: Array = [_make_enemy(Vector2i(3, 4))]
	var reachable: Array = [Vector2i(3, 3)]
	var attackable: Array = [Vector2i(3, 4)]
	var skillable: Array = [Vector2i(2, 3), Vector2i(3, 3), Vector2i(3, 4), Vector2i(4, 3)]
	var state: Dictionary = CombatAIEngine.build_state(
		self_unit, enemies, 7, {}, reachable, attackable, skillable, [], true
	)
	var action: Dictionary = ai.decide(state)
	if action.get("type", "wait") != "skill":
		_fail("BossAI: enrage phase should use signature ability, got %s" % action.get("type", "?"))
	elif action.get("skill_id", "") != "signature_strike":
		_fail("BossAI: enrage should use signature_strike, got %s" % action.get("skill_id", "?"))
	else:
		_ok("BossAI: enrages and uses signature_strike at 20%% HP")
	ai.free()


func _test_mobs_have_ai_archetype() -> void:
	print("\n--- mobs.json: ai_archetype on every mob ---")
	var path: String = "res://data/mobs.json"
	if not ResourceLoader.exists(path):
		_fail("mobs.json not found")
		return
	var raw: Variant = load(path)
	if raw == null:
		_fail("mobs.json failed to load")
		return
	var data: Dictionary = raw.data if "data" in raw else raw
	var total: int = 0
	var missing: Array[String] = []
	for section in ["overworld", "rift_only"]:
		var bucket = data.get(section, {})
		if bucket is Dictionary:
			for cat in ["neutral", "aggressive"]:
				for m in bucket.get(cat, []):
					if not m.has("ai_archetype"):
						missing.append(str(m.get("id", "?")))
					total += 1
		elif bucket is Array:
			for m in bucket:
				if not m.has("ai_archetype"):
					missing.append(str(m.get("id", "?")))
				total += 1
	if total == 0:
		_fail("mobs.json: 0 mobs found")
		return
	if not missing.is_empty():
		_fail("mobs.json: %d mobs missing ai_archetype: %s" % [missing.size(), str(missing)])
	else:
		_ok("mobs.json: all %d mobs have ai_archetype" % total)
	# Distribution check
	var by_arch: Dictionary = {}
	for section in ["overworld", "rift_only"]:
		var bucket = data.get(section, {})
		if bucket is Dictionary:
			for cat in ["neutral", "aggressive"]:
				for m in bucket.get(cat, []):
					var a: String = str(m.get("ai_archetype", "?"))
					by_arch[a] = int(by_arch.get(a, 0)) + 1
		elif bucket is Array:
			for m in bucket:
				var a2: String = str(m.get("ai_archetype", "?"))
				by_arch[a2] = int(by_arch.get(a2, 0)) + 1
	var pairs: Array[String] = []
	for k in by_arch:
		pairs.append("%s=%d" % [k, by_arch[k]])
	var summary: String = ", ".join(pairs)
	_ok("mobs.json: archetype distribution: %s" % summary)


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
