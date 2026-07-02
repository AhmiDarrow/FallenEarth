## CombatManager — Final Fantasy Tactics-style tactical combat engine.
## CT (Charge Time) turn order, Move/Jump range, tile height, facing, back/side attacks.
class_name CombatManager
extends RefCounted

const TEAM_PLAYER := "player"
const TEAM_ENEMY := "enemy"

const CT_THRESHOLD := 100
const CT_ACTION_COST := 60
const CT_WAIT_COST := 20
const BACK_ATTACK_MULT := 1.5
const SIDE_ATTACK_MULT := 1.25
const HEIGHT_DMG_PER_LEVEL := 0.05

enum BattlePhase { ACTIVE, VICTORY, DEFEAT }
enum TurnSubphase { MOVE, ACTION, TARGET_ATTACK, TARGET_SKILL }
enum Facing { NORTH = 0, EAST = 1, SOUTH = 2, WEST = 3 }

signal battle_phase_changed(new_phase: BattlePhase)
signal active_unit_changed(unit_id: String)
signal subphase_changed(new_subphase: TurnSubphase)
signal unit_updated(unit_id: String)
signal log_message(text: String)

var grid_size: int = 7
var battle_phase: BattlePhase = BattlePhase.ACTIVE
var turn_subphase: TurnSubphase = TurnSubphase.MOVE
var active_unit_id: String = ""
var round_count: int = 1

var _units: Array[Dictionary] = []
var _height_map: Dictionary = {}
var _log: Array[String] = []
var _character_snapshot: Dictionary = {}
var _reachable_move: Array[Vector2i] = []
var _attackable_tiles: Array[Vector2i] = []
var _skillable_tiles: Array[Vector2i] = []
var _class_combat: Dictionary = {}
var _active_skill: Dictionary = {}


func setup_from_encounter(encounter: Dictionary) -> void:
	grid_size = int(encounter.get("grid_size", 7))
	battle_phase = BattlePhase.ACTIVE
	turn_subphase = TurnSubphase.MOVE
	active_unit_id = ""
	round_count = 1
	_units.clear()
	_log.clear()
	_height_map.clear()
	_reachable_move.clear()
	_attackable_tiles.clear()
	_character_snapshot = (encounter.get("character_data", {}) as Dictionary).duplicate(true)
	_class_combat = (encounter.get("class_combat", {}) as Dictionary).duplicate(true)
	_active_skill = {}
	_skillable_tiles.clear()

	_build_height_map(int(encounter.get("height_seed", 0)))
	var player_start: Vector2i = encounter.get("player_start", Vector2i(grid_size / 2, grid_size - 1))
	_spawn_player(player_start)

	var templates: Array = encounter.get("enemy_templates", []) as Array
	var used: Array[Vector2i] = [player_start]
	var idx: int = 0
	for t in templates:
		if not t is Dictionary:
			continue
		var template: Dictionary = t as Dictionary
		var pos: Vector2i = _random_open_tile(used, player_start, 2)
		if pos.x < 0:
			continue
		used.append(pos)
		_units.append(_template_to_unit(template, pos, bool(template.get("is_boss", false)), idx))
		idx += 1

	_init_ct_for_all_units()
	_add_log("FFT battle start — CT turn order active.")
	_advance_to_next_turn()


func get_units() -> Array[Dictionary]:
	return _units.duplicate(true)


func get_unit_at(pos: Vector2i) -> Dictionary:
	for u in _units:
		if u.get("pos", Vector2i(-1, -1)) == pos and int(u.get("hp", 0)) > 0:
			return u.duplicate(true)
	return {}


func get_active_unit() -> Dictionary:
	return _get_unit_copy(active_unit_id)


func is_player_active() -> bool:
	var u: Dictionary = _get_unit_copy(active_unit_id)
	return not u.is_empty() and u.get("team") == TEAM_PLAYER and battle_phase == BattlePhase.ACTIVE


func get_height_at(pos: Vector2i) -> int:
	return int(_height_map.get(_pos_key(pos), 0))


func get_reachable_move_tiles() -> Array[Vector2i]:
	return _reachable_move.duplicate()


func get_attackable_tiles() -> Array[Vector2i]:
	return _attackable_tiles.duplicate()


func get_skillable_tiles() -> Array[Vector2i]:
	return _skillable_tiles.duplicate()


func get_player_abilities() -> Array[Dictionary]:
	var player: Dictionary = _get_unit_copy("player")
	if player.is_empty():
		return []
	var abilities: Variant = player.get("abilities", [])
	if abilities is Array:
		var out: Array[Dictionary] = []
		for a in abilities:
			if a is Dictionary:
				out.append((a as Dictionary).duplicate(true))
		return out
	return []


func get_player_mp() -> Dictionary:
	var player: Dictionary = _get_unit_ref("player")
	if player.is_empty():
		return {"current": 0, "max": 0}
	return {"current": int(player.get("mp", 0)), "max": int(player.get("mp_max", 0))}


func get_turn_order_preview(count: int = 5) -> Array[String]:
	var living: Array[Dictionary] = []
	for u in _units:
		if int(u.get("hp", 0)) > 0:
			living.append(u)
	living.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ct_a: int = int(a.get("ct", 0))
		var ct_b: int = int(b.get("ct", 0))
		if ct_a == ct_b:
			return int(a.get("speed", 0)) > int(b.get("speed", 0))
		return ct_a > ct_b
	)
	var names: Array[String] = []
	for i in range(mini(count, living.size())):
		names.append(str(living[i].get("name", "?")))
	return names


func get_log_lines() -> Array[String]:
	return _log.duplicate()


func all_enemies_defeated() -> bool:
	for u in _units:
		if u.get("team") == TEAM_ENEMY and int(u.get("hp", 0)) > 0:
			return false
	return true


func get_player_health_for_sync() -> int:
	for u in _units:
		if u.get("team") == TEAM_PLAYER and u.get("id") == "player":
			return int(u.get("hp", 0))
	return 0


func try_move_active_unit_to(pos: Vector2i) -> Dictionary:
	if battle_phase != BattlePhase.ACTIVE or turn_subphase != TurnSubphase.MOVE:
		return {"ok": false, "message": "Cannot move now."}
	var unit: Dictionary = _get_unit_ref(active_unit_id)
	if unit.is_empty():
		return {"ok": false, "message": "No active unit."}
	if unit.get("has_moved", false):
		return {"ok": false, "message": "Already moved."}
	if not _reachable_move.has(pos):
		return {"ok": false, "message": "Out of move range."}
	if not get_unit_at(pos).is_empty():
		return {"ok": false, "message": "Tile occupied."}

	var old_pos: Vector2i = unit.get("pos", Vector2i.ZERO)
	unit["pos"] = pos
	unit["has_moved"] = true
	unit["facing"] = _facing_from_delta(pos - old_pos)
	_emit_unit(active_unit_id)
	_refresh_player_ranges()
	_add_log("%s moved to (%d,%d)." % [unit.get("name", "?"), pos.x, pos.y])
	return {"ok": true, "message": "Moved."}


func begin_attack_action() -> Dictionary:
	if battle_phase != BattlePhase.ACTIVE or not is_player_active():
		return {"ok": false, "message": "Not your action phase."}
	if turn_subphase == TurnSubphase.TARGET_ATTACK:
		return {"ok": true, "message": "Already targeting."}
	var unit: Dictionary = _get_unit_ref(active_unit_id)
	if unit.get("has_acted", false):
		return {"ok": false, "message": "Already acted."}
	turn_subphase = TurnSubphase.TARGET_ATTACK
	_refresh_attack_range()
	subphase_changed.emit(turn_subphase)
	return {"ok": true, "message": "Select attack target."}


func try_attack_at(pos: Vector2i) -> Dictionary:
	if battle_phase != BattlePhase.ACTIVE or turn_subphase != TurnSubphase.TARGET_ATTACK:
		return {"ok": false, "message": "Not targeting."}
	var attacker: Dictionary = _get_unit_ref(active_unit_id)
	if attacker.is_empty() or attacker.get("has_acted", false):
		return {"ok": false, "message": "Cannot attack."}
	var target: Dictionary = get_unit_at(pos)
	if target.is_empty() or target.get("team") == attacker.get("team"):
		return {"ok": false, "message": "Invalid target."}
	if not _attackable_tiles.has(pos):
		return {"ok": false, "message": "Out of attack range."}

	var result: Dictionary = _resolve_attack(attacker, target)
	attacker["has_acted"] = true
	attacker["facing"] = _facing_toward(attacker.get("pos", Vector2i.ZERO), pos)
	_emit_unit(active_unit_id)
	_emit_unit(str(target.get("id", "")))
	_add_log(str(result.get("message", "Attack.")))
	_check_battle_end()
	if battle_phase == BattlePhase.ACTIVE:
		turn_subphase = TurnSubphase.ACTION
		_refresh_player_ranges()
		subphase_changed.emit(turn_subphase)
	return {"ok": true, "message": "Attack resolved."}


func wait_action() -> Dictionary:
	if battle_phase != BattlePhase.ACTIVE or not is_player_active():
		return {"ok": false, "message": "Cannot wait."}
	var unit: Dictionary = _get_unit_ref(active_unit_id)
	unit["has_acted"] = true
	unit["waited"] = true
	_add_log("%s waits (CT recovers faster)." % unit.get("name", "?"))
	_finish_active_turn()
	return {"ok": true, "message": "Wait."}


func finish_turn() -> Dictionary:
	if battle_phase != BattlePhase.ACTIVE or not is_player_active():
		return {"ok": false, "message": "Cannot end turn."}
	_finish_active_turn()
	return {"ok": true, "message": "Turn ended."}


func begin_skill_action(skill_id: String) -> Dictionary:
	if battle_phase != BattlePhase.ACTIVE or not is_player_active():
		return {"ok": false, "message": "Not your turn."}
	var unit: Dictionary = _get_unit_ref(active_unit_id)
	if unit.get("has_acted", false):
		return {"ok": false, "message": "Already acted."}
	var skill: Dictionary = _find_ability(unit, skill_id)
	if skill.is_empty():
		return {"ok": false, "message": "Unknown skill."}
	if int(unit.get("mp", 0)) < int(skill.get("mp_cost", 99)):
		return {"ok": false, "message": "Not enough MP."}
	_active_skill = skill.duplicate(true)
	turn_subphase = TurnSubphase.TARGET_SKILL
	_refresh_skill_range()
	subphase_changed.emit(turn_subphase)
	return {"ok": true, "message": "Select target for %s." % skill.get("name", "Skill")}


func try_skill_at(pos: Vector2i) -> Dictionary:
	if battle_phase != BattlePhase.ACTIVE or turn_subphase != TurnSubphase.TARGET_SKILL:
		return {"ok": false, "message": "Not using a skill."}
	if _active_skill.is_empty():
		return {"ok": false, "message": "No skill selected."}
	var caster: Dictionary = _get_unit_ref(active_unit_id)
	if caster.is_empty() or caster.get("has_acted", false):
		return {"ok": false, "message": "Cannot cast."}

	var skill: Dictionary = _active_skill
	var skill_range: int = int(skill.get("range", 1))
	var caster_pos: Vector2i = caster.get("pos", Vector2i.ZERO)
	var skill_type: String = str(skill.get("type", "physical"))

	if skill_range == 0:
		if pos != caster_pos:
			return {"ok": false, "message": "Self skill — select your tile."}
	elif not _skillable_tiles.has(pos):
		return {"ok": false, "message": "Out of skill range."}

	var target: Dictionary = get_unit_at(pos)
	if skill_type in ["physical", "magical"]:
		if target.is_empty() or target.get("team") == caster.get("team"):
			return {"ok": false, "message": "Need enemy target."}

	var result: Dictionary = _resolve_skill(caster, skill, pos, target)
	if not bool(result.get("ok", false)):
		return result

	caster["mp"] = maxi(0, int(caster.get("mp", 0)) - int(skill.get("mp_cost", 0)))
	caster["has_acted"] = true
	caster["facing"] = _facing_toward(caster_pos, pos) if pos != caster_pos else int(caster.get("facing", Facing.NORTH))
	_active_skill = {}
	_emit_unit(active_unit_id)
	_check_battle_end()
	if battle_phase == BattlePhase.ACTIVE:
		turn_subphase = TurnSubphase.ACTION
		_refresh_player_ranges()
		subphase_changed.emit(turn_subphase)
	return {"ok": true, "message": str(result.get("message", "Skill used."))}


# -- Internal FFT systems --

func _spawn_player(start_pos: Vector2i) -> void:
	var stats: Dictionary = _character_snapshot.get("stats", {}) as Dictionary
	var str_val: int = int(stats.get("str", 10))
	var dex_val: int = int(stats.get("dex", 10))
	var con_val: int = int(stats.get("con", 10))
	var wis_val: int = int(stats.get("wis", 10))
	var int_val: int = int(stats.get("int", 10))
	var max_hp: int = int(_character_snapshot.get("max_health", _character_snapshot.get("health", 80 + con_val * 5)))
	var cur_hp: int = int(_character_snapshot.get("health", max_hp))
	var cc: Dictionary = _class_combat

	var move_bonus: int = int(cc.get("move_bonus", 0))
	var jump_bonus: int = int(cc.get("jump_bonus", 0))
	var speed_bonus: int = int(cc.get("speed_bonus", 0))
	var mp_max: int = int(cc.get("mp_max", 24))
	var weapon_range: int = int(cc.get("weapon_range", 1))
	var attack_bonus: int = int(cc.get("attack_bonus", 0))
	var armor_bonus: int = int(cc.get("armor_bonus", 0))
	var abilities: Array = cc.get("abilities", []) as Array
	var player_class: String = str(_character_snapshot.get("class", ""))

	_units.append({
		"id": "player",
		"team": TEAM_PLAYER,
		"name": str(_character_snapshot.get("name", "Runner")),
		"class": player_class,
		"pos": start_pos,
		"hp": mini(cur_hp, max_hp),
		"max_hp": max_hp,
		"level": int(_character_snapshot.get("level", 1)),
		"mp": mp_max,
		"mp_max": mp_max,
		"armor": con_val / 3 + dex_val / 5 + armor_bonus,
		"attack": maxi(4, str_val / 2 + 2 + attack_bonus),
		"magic": maxi(4, int_val / 2 + 2),
		"speed": clampi(dex_val + wis_val / 2 + speed_bonus, 3, 20),
		"move": clampi(dex_val / 3 + 3 + move_bonus, 2, 8),
		"jump": clampi(str_val / 4 + 2 + jump_bonus, 1, 6),
		"weapon_range": weapon_range,
		"abilities": abilities.duplicate(true),
		"buffs": {},
		"facing": Facing.NORTH,
		"ct": 0,
		"has_moved": false,
		"has_acted": false,
		"waited": false,
		"is_boss": false,
		"player_controlled": true,
	})
	_add_log("%s Lv.%d %s enters (MP %d)." % [
		_character_snapshot.get("name", "Runner"),
		int(_character_snapshot.get("level", 1)),
		player_class,
		mp_max,
	])


func _template_to_unit(template: Dictionary, pos: Vector2i, is_boss: bool, index: int) -> Dictionary:
	var hp: int = int(template.get("hp", 50)) + randi_range(-5, 5)
	var speed: int = int(template.get("speed", 7))
	var enemy_level: int = int(template.get("level", 1))
	var enemy_name: String = str(template.get("name", "Mob"))
	if is_boss:
		enemy_name = "[Boss] %s" % enemy_name
	_add_log("%s Lv.%d enters (HP %d)." % [enemy_name, enemy_level, maxi(1, hp)])
	return {
		"id": "enemy_%d" % index,
		"team": TEAM_ENEMY,
		"name": enemy_name,
		"pos": pos,
		"hp": maxi(1, hp),
		"max_hp": maxi(1, hp),
		"level": enemy_level,
		"armor": int(template.get("armor", 0)),
		"attack": int(template.get("attack_damage", 8)),
		"speed": speed,
		"move": clampi(speed / 2 + 2, 2, 5),
		"jump": 2,
		"weapon_range": 1,
		"facing": Facing.SOUTH,
		"ct": 0,
		"has_moved": false,
		"has_acted": false,
		"waited": false,
		"is_boss": is_boss,
		"player_controlled": false,
	}


func _init_ct_for_all_units() -> void:
	for u in _units:
		u["ct"] = randi_range(0, 50)


func _advance_to_next_turn() -> void:
	if battle_phase != BattlePhase.ACTIVE:
		return

	while true:
		var ready: Dictionary = _highest_ct_unit()
		if ready.is_empty():
			_tick_ct(1)
			continue

		if int(ready.get("ct", 0)) < CT_THRESHOLD:
			_tick_ct(CT_THRESHOLD - int(ready.get("ct", 0)))
			continue

		active_unit_id = str(ready.get("id", ""))
		var unit: Dictionary = _get_unit_ref(active_unit_id)
		unit["has_moved"] = false
		unit["has_acted"] = false
		unit["waited"] = false
		_tick_buffs(unit)
		round_count += 1
		active_unit_changed.emit(active_unit_id)

		if unit.get("player_controlled", false):
			turn_subphase = TurnSubphase.MOVE
			_refresh_player_ranges()
			subphase_changed.emit(turn_subphase)
			_add_log("— %s's turn (Move → Action)." % unit.get("name", "?"))
			return

		_run_enemy_turn(unit)
		if battle_phase != BattlePhase.ACTIVE:
			return


func _tick_ct(amount: int) -> void:
	for u in _units:
		if int(u.get("hp", 0)) > 0:
			u["ct"] = int(u.get("ct", 0)) + int(u.get("speed", 5)) * amount


func _highest_ct_unit() -> Dictionary:
	var best: Dictionary = {}
	for u in _units:
		if int(u.get("hp", 0)) <= 0:
			continue
		if best.is_empty() or int(u.get("ct", 0)) > int(best.get("ct", 0)):
			best = u
		elif int(u.get("ct", 0)) == int(best.get("ct", 0)) and int(u.get("speed", 0)) > int(best.get("speed", 0)):
			best = u
	return best.duplicate(true)


func _finish_active_turn() -> void:
	var unit: Dictionary = _get_unit_ref(active_unit_id)
	if unit.is_empty():
		return
	var cost: int = CT_WAIT_COST if bool(unit.get("waited", false)) else CT_ACTION_COST
	unit["ct"] = maxi(0, int(unit.get("ct", 0)) - cost)
	_emit_unit(active_unit_id)
	turn_subphase = TurnSubphase.MOVE
	_reachable_move.clear()
	_attackable_tiles.clear()
	_skillable_tiles.clear()
	_active_skill = {}
	_advance_to_next_turn()


func _run_enemy_turn(unit: Dictionary) -> void:
	var uid: String = str(unit.get("id", ""))
	var target: Dictionary = _nearest_player(unit.get("pos", Vector2i.ZERO))
	if target.is_empty():
		_finish_enemy_turn(uid)
		return

	var target_pos: Vector2i = target.get("pos", Vector2i.ZERO)
	var my_pos: Vector2i = unit.get("pos", Vector2i.ZERO)

	if _manhattan(my_pos, target_pos) <= int(unit.get("weapon_range", 1)):
		var result: Dictionary = _resolve_attack(unit, target)
		unit["has_acted"] = true
		unit["facing"] = _facing_toward(my_pos, target_pos)
		_add_log(str(result.get("message", "Enemy attack.")))
	else:
		var reachable: Array[Vector2i] = _compute_reachable(my_pos, int(unit.get("move", 3)), int(unit.get("jump", 2)), uid)
		var best: Vector2i = my_pos
		var best_dist: int = _manhattan(my_pos, target_pos)
		for tile in reachable:
			var d: int = _manhattan(tile, target_pos)
			if d < best_dist:
				best_dist = d
				best = tile
		if best != my_pos:
			unit["pos"] = best
			unit["has_moved"] = true
			unit["facing"] = _facing_from_delta(best - my_pos)
			_add_log("%s advances." % unit.get("name", "Enemy"))

	_emit_unit(uid)
	_check_battle_end()
	_finish_enemy_turn(uid)


func _finish_enemy_turn(uid: String) -> void:
	var unit: Dictionary = _get_unit_ref(uid)
	if unit.is_empty():
		return
	unit["ct"] = maxi(0, int(unit.get("ct", 0)) - CT_ACTION_COST)
	_advance_to_next_turn()


func _resolve_attack(attacker: Dictionary, target: Dictionary) -> Dictionary:
	var atk_pos: Vector2i = attacker.get("pos", Vector2i.ZERO)
	var tgt_pos: Vector2i = target.get("pos", Vector2i.ZERO)
	var base: int = maxi(1, _effective_attack(attacker) - _effective_armor(target))

	var facing_mult: float = _facing_multiplier(int(target.get("facing", Facing.SOUTH)), atk_pos, tgt_pos)
	var height_mult: float = 1.0 + float(get_height_at(atk_pos) - get_height_at(tgt_pos)) * HEIGHT_DMG_PER_LEVEL
	var dmg: int = maxi(1, int(float(base) * facing_mult * height_mult))

	_apply_damage(str(target.get("id", "")), dmg)

	var hit_type: String = "front"
	if facing_mult >= BACK_ATTACK_MULT - 0.01:
		hit_type = "back"
	elif facing_mult >= SIDE_ATTACK_MULT - 0.01:
		hit_type = "side"

	return {
		"damage": dmg,
		"message": "%s hits %s (%s) for %d." % [
			attacker.get("name", "?"), target.get("name", "?"), hit_type, dmg,
		],
	}


func _facing_multiplier(defender_facing: int, atk_pos: Vector2i, def_pos: Vector2i) -> float:
	var delta: Vector2i = atk_pos - def_pos
	if delta == Vector2i.ZERO:
		return 1.0
	var attack_dir: int = _facing_from_delta(delta)
	var diff: int = absi(attack_dir - defender_facing) % 4
	if diff == 2:
		return BACK_ATTACK_MULT
	if diff == 1 or diff == 3:
		return SIDE_ATTACK_MULT
	return 1.0


func _facing_from_delta(delta: Vector2i) -> int:
	if absi(delta.x) >= absi(delta.y):
		return Facing.EAST if delta.x > 0 else Facing.WEST
	return Facing.SOUTH if delta.y > 0 else Facing.NORTH


func _facing_toward(from: Vector2i, to: Vector2i) -> int:
	return _facing_from_delta(to - from)


func _refresh_player_ranges() -> void:
	_reachable_move.clear()
	_attackable_tiles.clear()
	if not is_player_active():
		return
	var unit: Dictionary = _get_unit_ref(active_unit_id)
	if unit.get("has_moved", false):
		turn_subphase = TurnSubphase.ACTION
	else:
		_reachable_move = _compute_reachable(
			unit.get("pos", Vector2i.ZERO),
			int(unit.get("move", 3)),
			int(unit.get("jump", 2)),
			active_unit_id
		)
	if turn_subphase == TurnSubphase.TARGET_ATTACK:
		_refresh_attack_range()


func _refresh_attack_range() -> void:
	_attackable_tiles.clear()
	var unit: Dictionary = _get_unit_ref(active_unit_id)
	var origin: Vector2i = unit.get("pos", Vector2i.ZERO)
	var rng: int = int(unit.get("weapon_range", 1))
	for y in range(grid_size):
		for x in range(grid_size):
			var p: Vector2i = Vector2i(x, y)
			if _manhattan(origin, p) <= rng:
				var u: Dictionary = get_unit_at(p)
				if not u.is_empty() and u.get("team") != unit.get("team"):
					_attackable_tiles.append(p)


func _refresh_skill_range() -> void:
	_skillable_tiles.clear()
	if _active_skill.is_empty():
		return
	var unit: Dictionary = _get_unit_ref(active_unit_id)
	var origin: Vector2i = unit.get("pos", Vector2i.ZERO)
	var rng: int = int(_active_skill.get("range", 1))
	var skill_type: String = str(_active_skill.get("type", ""))
	if rng == 0:
		_skillable_tiles.append(origin)
		return
	for y in range(grid_size):
		for x in range(grid_size):
			var p: Vector2i = Vector2i(x, y)
			if _manhattan(origin, p) > rng:
				continue
			if skill_type in ["physical", "magical"]:
				var u: Dictionary = get_unit_at(p)
				if not u.is_empty() and u.get("team") != unit.get("team"):
					_skillable_tiles.append(p)
			else:
				_skillable_tiles.append(p)


func _resolve_skill(caster: Dictionary, skill: Dictionary, pos: Vector2i, target: Dictionary) -> Dictionary:
	var skill_type: String = str(skill.get("type", "physical"))
	var skill_name: String = str(skill.get("name", "Skill"))

	if skill_type == "heal_self":
		var heal: int = int(skill.get("heal_amount", 15))
		var uid: String = str(caster.get("id", ""))
		var u: Dictionary = _get_unit_ref(uid)
		u["hp"] = mini(int(u.get("max_hp", 100)), int(u.get("hp", 0)) + heal)
		_emit_unit(uid)
		_add_log("%s uses %s (+ %d HP)." % [caster.get("name", "?"), skill_name, heal])
		return {"ok": true, "message": "Healed."}

	if skill_type == "buff_self":
		var buffs: Dictionary = caster.get("buffs", {}) as Dictionary
		buffs = buffs.duplicate(true)
		buffs["armor_add"] = int(skill.get("armor_add", 0))
		buffs["attack_add"] = int(skill.get("attack_add", 0))
		buffs["turns"] = int(skill.get("duration_turns", 2))
		caster["buffs"] = buffs
		_add_log("%s uses %s (buff %d turns)." % [caster.get("name", "?"), skill_name, buffs["turns"]])
		return {"ok": true, "message": "Buff applied."}

	if target.is_empty():
		return {"ok": false, "message": "Invalid target."}

	var atk_pos: Vector2i = caster.get("pos", Vector2i.ZERO)
	var tgt_pos: Vector2i = target.get("pos", Vector2i.ZERO)
	var power: int = _effective_attack(caster) if skill_type == "physical" else int(caster.get("magic", 8))
	var mult: float = float(skill.get("damage_mult", 1.2))
	var base: int = maxi(1, int(float(power) * mult) - _effective_armor(target))
	var facing_mult: float = _facing_multiplier(int(target.get("facing", Facing.SOUTH)), atk_pos, tgt_pos)
	var height_mult: float = 1.0 + float(get_height_at(atk_pos) - get_height_at(tgt_pos)) * HEIGHT_DMG_PER_LEVEL
	var dmg: int = maxi(1, int(float(base) * facing_mult * height_mult))
	_apply_damage(str(target.get("id", "")), dmg)

	if skill.has("heal_self_pct"):
		var heal_back: int = int(float(dmg) * float(skill.get("heal_self_pct", 0.0)))
		var cu: Dictionary = _get_unit_ref(str(caster.get("id", "")))
		cu["hp"] = mini(int(cu.get("max_hp", 100)), int(cu.get("hp", 0)) + heal_back)

	_add_log("%s casts %s on %s for %d." % [caster.get("name", "?"), skill_name, target.get("name", "?"), dmg])
	return {"ok": true, "message": "Skill hit."}


func _find_ability(unit: Dictionary, skill_id: String) -> Dictionary:
	var abilities: Variant = unit.get("abilities", [])
	if abilities is Array:
		for a in abilities:
			if a is Dictionary and str((a as Dictionary).get("id", "")) == skill_id:
				return (a as Dictionary).duplicate(true)
	return {}


func _effective_armor(unit: Dictionary) -> int:
	var base: int = int(unit.get("armor", 0))
	var buffs: Dictionary = unit.get("buffs", {}) as Dictionary
	return base + int(buffs.get("armor_add", 0))


func _effective_attack(unit: Dictionary) -> int:
	var base: int = int(unit.get("attack", 1))
	var buffs: Dictionary = unit.get("buffs", {}) as Dictionary
	return base + int(buffs.get("attack_add", 0))


func _tick_buffs(unit: Dictionary) -> void:
	var buffs: Dictionary = unit.get("buffs", {}) as Dictionary
	if buffs.is_empty() or not buffs.has("turns"):
		return
	var turns: int = int(buffs.get("turns", 0)) - 1
	if turns <= 0:
		unit["buffs"] = {}
	else:
		buffs["turns"] = turns
		unit["buffs"] = buffs


func _compute_reachable(start: Vector2i, move_range: int, jump: int, unit_id: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var visited: Dictionary = {}
	var queue: Array = [[start, 0]]
	visited[_pos_key(start)] = 0

	while not queue.is_empty():
		var node: Array = queue.pop_front() as Array
		var pos: Vector2i = node[0] as Vector2i
		var cost: int = int(node[1])
		if cost > 0:
			result.append(pos)

		if cost >= move_range:
			continue

		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = pos + d
			if not _is_in_bounds(nxt):
				continue
			if _is_occupied(nxt, unit_id):
				continue
			var h_diff: int = get_height_at(nxt) - get_height_at(pos)
			if h_diff > jump:
				continue
			var step_cost: int = cost + 1 + maxi(0, h_diff)
			if step_cost > move_range:
				continue
			var key: String = _pos_key(nxt)
			if visited.has(key) and int(visited[key]) <= step_cost:
				continue
			visited[key] = step_cost
			queue.append([nxt, step_cost])

	return result


func _build_height_map(seed_val: int) -> void:
	seed(seed_val)
	for y in range(grid_size):
		for x in range(grid_size):
			_height_map["%d,%d" % [x, y]] = randi_range(0, 2)


func _nearest_player(from: Vector2i) -> Dictionary:
	var best: Dictionary = {}
	var best_d: int = 9999
	for u in _units:
		if u.get("team") != TEAM_PLAYER or int(u.get("hp", 0)) <= 0:
			continue
		var d: int = _manhattan(from, u.get("pos", Vector2i.ZERO))
		if d < best_d:
			best_d = d
			best = u
	return best.duplicate(true)


func _check_battle_end() -> void:
	if all_enemies_defeated():
		battle_phase = BattlePhase.VICTORY
		_add_log("Victory — all enemies defeated.")
		battle_phase_changed.emit(battle_phase)
		return
	var player_alive: bool = false
	for u in _units:
		if u.get("team") == TEAM_PLAYER and int(u.get("hp", 0)) > 0:
			player_alive = true
			break
	if not player_alive:
		battle_phase = BattlePhase.DEFEAT
		_add_log("Defeat — party wiped.")
		battle_phase_changed.emit(battle_phase)


func _apply_damage(unit_id: String, amount: int) -> void:
	var u: Dictionary = _get_unit_ref(unit_id)
	if u.is_empty():
		return
	u["hp"] = maxi(0, int(u.get("hp", 0)) - amount)
	_emit_unit(unit_id)


func _random_open_tile(used: Array[Vector2i], avoid: Vector2i, min_dist: int) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for y in range(grid_size):
		for x in range(grid_size):
			var p: Vector2i = Vector2i(x, y)
			if p == avoid or used.has(p) or not get_unit_at(p).is_empty():
				continue
			if _manhattan(p, avoid) < min_dist:
				continue
			candidates.append(p)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	return candidates[randi() % candidates.size()]


func _get_unit_ref(unit_id: String) -> Dictionary:
	for u in _units:
		if u.get("id") == unit_id:
			return u
	return {}


func _get_unit_copy(unit_id: String) -> Dictionary:
	var u: Dictionary = _get_unit_ref(unit_id)
	return u.duplicate(true) if not u.is_empty() else {}


func _is_occupied(pos: Vector2i, except_id: String) -> bool:
	for u in _units:
		if u.get("id") == except_id:
			continue
		if u.get("pos", Vector2i(-1, -1)) == pos and int(u.get("hp", 0)) > 0:
			return true
	return false


func _is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < grid_size and pos.y < grid_size


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _pos_key(pos: Vector2i) -> String:
	return "%d,%d" % [pos.x, pos.y]


func _emit_unit(unit_id: String) -> void:
	unit_updated.emit(unit_id)


func _add_log(text: String) -> void:
	_log.append(text)
	log_message.emit(text)