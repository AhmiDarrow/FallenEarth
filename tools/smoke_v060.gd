extends SceneTree
## Smoke test for v0.6.0: real combat damage wiring (EquipmentManager
## stats read dynamically in _effective_attack / _effective_armor) +
## expanded consumables (mana_potion, cooked_meat, antidote).

const CombatMgrScript = preload("res://scripts/CombatManager.gd")
const EquipMgrScript = preload("res://scripts/EquipmentManager.gd")
const ProgMgrScript = preload("res://scripts/ProgressionManager.gd")
const InvMgrScript = preload("res://scripts/InventoryManager.gd")

var failures: Array[String] = []


func _fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)


func _ok(msg: String) -> void:
	print("  ok  " + msg)


func _initialize() -> void:
	print("[smoke-v060] v0.6.0 real combat damage wiring + expanded consumables")
	# Autoloads are added to the tree before _initialize, but their
	# _ready() (which loads data files) is deferred to the next idle
	# frame. Wait one frame so all autoloads finish initializing
	# before any test runs.
	await process_frame
	await _test_em_get_attack_uses_per_class_stats()
	await _test_em_get_attack_includes_accessory_mods()
	await _test_combat_manager_effective_attack_dynamic()
	await _test_combat_manager_effective_armor_dynamic()
	await _test_resolve_attack_uses_equipment()
	await _test_use_item_mana_potion_restores_mp()
	await _test_use_item_mana_potion_fails_when_none()
	await _test_use_item_cooked_meat_heals_and_buffs()
	await _test_use_item_antidote_heals()
	await _test_use_item_unknown_returns_error()
	await _test_buff_expires_after_turns()

	if failures.is_empty():
		print("[smoke-v060] All checks passed. (failures.size=%d)" % failures.size())
		quit(0)
	else:
		for f in failures:
			print("[smoke-v060] FAIL: " + f)
		print("[smoke-v060] %d failure(s). (failures=%s)" % [failures.size(), str(failures)])
		quit(1)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _spawn_player_at(str_val: int, con_val: int, level: int) -> Node:
	var cm: Node = CombatMgrScript.new()
	cm.name = "TestCombatV060"
	root.add_child(cm)
	await process_frame
	# v0.5.0: _spawn_player reads pm.level (autoload's ProgressionManager)
	# not the snapshot's level. Set the autoload's level to match the
	# snapshot so max_hp / mp_max come out as expected.
	var pm: Node = root.get_node_or_null("ProgressionManager")
	if pm != null:
		pm.level = level
	cm._character_snapshot = {
		"class": "Scavenger",
		"name": "TestPlayer",
		"level": level,
		"stats": {"str": str_val, "dex": 10, "con": con_val, "int": 10, "wis": 10},
		"health": 80,
		"max_health": 80,
		"move_bonus": 0, "jump_bonus": 0, "speed_bonus": 0,
		"mp_max": 40, "weapon_range": 1, "attack_bonus": 0, "armor_bonus": 0,
		"abilities": [],
	}
	cm._class_combat = {}
	cm._spawn_player(Vector2i(2, 2))
	cm.battle_phase = cm.BattlePhase.ACTIVE
	cm.active_unit_id = "player"
	return cm


func _get_em() -> Node:
	return root.get_node_or_null("EquipmentManager")


func _reset_em() -> void:
	var em: Node = _get_em()
	if em != null:
		em.restore_from_snapshot({"equipment_state": {}})


# ---------------------------------------------------------------------------
# v0.6.0 tests
# ---------------------------------------------------------------------------

## Each class's weapon scales with its own primary stat.
## Scavenger (str+1) → +1 from weapon; Technician (int+1) → +1 from int.
## NOTE: weapon id "weapon_X_t1" is tier 0 (damage=3); tier 1 is "t2" (damage=5).
func _test_em_get_attack_uses_per_class_stats() -> void:
	print("[smoke-v060] test: EquipmentManager.get_attack uses per-class stats")
	var em: Node = _get_em()
	if em == null:
		_fail("EquipmentManager autoload not available")
		return
	# Scavenger tier 0: weapon_damage=3, stat_mods={"str":1} → 3+1=4
	var scav: Dictionary = em.get_weapon("Scavenger", 0)
	if int(scav.get("damage", 0)) != 3:
		_fail("Scavenger t0 weapon_damage should be 3 (got %d)" % int(scav.get("damage", 0)))
		return
	# Technician tier 0: weapon_damage=3, stat_mods={"int":1} → 3+1=4 (int, not str)
	var tech: Dictionary = em.get_weapon("Technician", 0)
	if int(tech.get("damage", 0)) != 3:
		_fail("Technician t0 weapon_damage should be 3 (got %d)" % int(tech.get("damage", 0)))
		return
	if not tech.has("stat_mods") or int(tech.stat_mods.get("int", 0)) != 1:
		_fail("Technician t0 stat_mods should have int=1 (got %s)" % str(tech.get("stat_mods", {})))
		return
	# Equip Technician tier 1 (id = weapon_technician_t2) — damage=5, int=1 → 6
	_reset_em()
	em.equip("player", "weapon_technician_t2", "mainhand")
	var tech_atk: int = em.get_attack("player")
	# tech tier 1 = 5 damage + 1 int = 6
	if tech_atk != 6:
		_fail("Technician tier 1 equipped attack should be 6 (5 weapon + 1 int), got %d" % tech_atk)
		return
	# Now equip Scavenger tier 1 (id = weapon_scavenger_t2) — damage=5, str=1 → 6
	_reset_em()
	em.equip("player", "weapon_scavenger_t2", "mainhand")
	var scav_atk: int = em.get_attack("player")
	# scav tier 1 = 5 damage + 1 str = 6
	if scav_atk != 6:
		_fail("Scavenger tier 1 equipped attack should be 6 (5 weapon + 1 str), got %d" % scav_atk)
		return
	_ok("EquipmentManager.get_attack: per-class stats (Scavenger=str, Technician=int) both = 6 at tier 1")


## Accessory mods (e.g. iron_grip str+2) also contribute to attack.
func _test_em_get_attack_includes_accessory_mods() -> void:
	print("[smoke-v060] test: EquipmentManager.get_attack includes accessory mods")
	var em: Node = _get_em()
	if em == null:
		_fail("EquipmentManager autoload not available")
		return
	_reset_em()
	# No weapon, just iron_grip (+2 str) in acc1
	em.equip("player", "iron_grip", "acc1")
	var atk: int = em.get_attack("player")
	# weapon_damage=0 + 2 str = 2
	if atk != 2:
		_fail("attack with iron_grip acc only should be 2 (0 weapon + 2 str), got %d" % atk)
		return
	# Add a Scavenger tier 1 (id = weapon_scavenger_t2) — damage=5, str=1
	em.equip("player", "weapon_scavenger_t2", "mainhand")
	atk = em.get_attack("player")
	# 5 weapon + 1 str (weapon) + 2 str (acc) = 8
	if atk != 8:
		_fail("attack with iron_grip + Scavenger tier 1 should be 8 (5 + 1 + 2), got %d" % atk)
		return
	_ok("EquipmentManager.get_attack: accessory mods (iron_grip str+2) contribute to attack")


## _effective_attack reads EquipmentManager dynamically (not stored on unit).
func _test_combat_manager_effective_attack_dynamic() -> void:
	print("[smoke-v060] test: CombatManager._effective_attack is dynamic")
	var em: Node = _get_em()
	if em == null:
		_fail("EquipmentManager autoload not available")
		return
	_reset_em()
	var cm: Node = await _spawn_player_at(10, 10, 5)
	# Player base attack = str/2 + 2 = 7 (stored on unit)
	var unit: Dictionary = cm._get_unit_ref("player")
	var base: int = int(unit.get("attack", 0))
	if base != 7:
		_fail("Player base attack at str=10 should be 7 (str/2+2), got %d" % base)
		return
	# No weapon → equipment bonus = 0 → effective = 7
	var eff0: int = cm._effective_attack(unit)
	if eff0 != 7:
		_fail("_effective_attack with no weapon should be 7 (base only), got %d" % eff0)
		return
	# Equip a Scavenger tier 1 (id = weapon_scavenger_t2, damage=5, str=1)
	em.equip("player", "weapon_scavenger_t2", "mainhand")
	# DO NOT re-spawn — should be dynamic
	var eff1: int = cm._effective_attack(unit)
	# base 7 + equip 6 (5 dmg + 1 str) = 13
	if eff1 != 13:
		_fail("_effective_attack after equipping Scavenger tier 1 should be 13 (7 base + 6 equip), got %d" % eff1)
		return
	_ok("CombatManager._effective_attack: dynamic (7 → 13 after equip, no re-spawn)")


## _effective_armor reads EquipmentManager dynamically.
func _test_combat_manager_effective_armor_dynamic() -> void:
	print("[smoke-v060] test: CombatManager._effective_armor is dynamic")
	var em: Node = _get_em()
	if em == null:
		_fail("EquipmentManager autoload not available")
		return
	_reset_em()
	var cm: Node = await _spawn_player_at(10, 10, 5)
	var unit: Dictionary = cm._get_unit_ref("player")
	# Player base armor = con/3 + dex/5 = 10/3 + 10/5 = 3 + 2 = 5
	var base: int = int(unit.get("armor", 0))
	if base != 5:
		_fail("Player base armor at con=10, dex=10 should be 5, got %d" % base)
		return
	# No armor → effective = 5
	var eff0: int = cm._effective_armor(unit)
	if eff0 != 5:
		_fail("_effective_armor with no armor should be 5 (base only), got %d" % eff0)
		return
	# Equip warden_charm (+2 con, +15 HP) — its stat_mods is {"con": 2}
	em.equip("player", "warden_charm", "acc1")
	var eff1: int = cm._effective_armor(unit)
	# base 5 + con mod 2 = 7
	if eff1 != 7:
		_fail("_effective_armor after equipping warden_charm should be 7 (5 base + 2 con), got %d" % eff1)
		return
	_ok("CombatManager._effective_armor: dynamic (5 → 7 after warden_charm equip)")


## _resolve_attack uses the equipment-aware attack/armor.
## Note: the facing multiplier affects the result. The attacker is at
## (2,2) facing south (default). The target is at (3,2) facing south.
## Attack from west to south-facing = SIDE attack (1.25x).
## dmg = max(1, attack - armor) * 1.25 * 1.0 (no height).
func _test_resolve_attack_uses_equipment() -> void:
	print("[smoke-v060] test: CombatManager._resolve_attack uses equipment")
	var em: Node = _get_em()
	if em == null:
		_fail("EquipmentManager autoload not available")
		return
	_reset_em()
	var cm: Node = await _spawn_player_at(10, 10, 5)
	# Add a target enemy to the units list. Place at (2,1) so attack
	# from south (player at 2,2) hits south-facing target = FRONT (1.0x).
	cm._units.append({
		"id": "enemy_test",
		"team": "enemy",
		"name": "Test Dummy",
		"pos": Vector2i(2, 1),
		"hp": 100, "max_hp": 100,
		"armor": 0, "attack": 5,
		"speed": 5, "move": 3, "jump": 1, "weapon_range": 1,
		"facing": 2,  # SOUTH (facing toward the attacker for a FRONT attack)
		"ct": 0,
		"has_moved": false, "has_acted": false, "waited": false,
		"is_boss": false, "player_controlled": false,
		"buffs": {},
	})
	var player: Dictionary = cm._get_unit_ref("player")
	# No weapon — resolve_attack with attacker=str=10, target=armor=0
	# attacker effective = 7, target effective = 0, dmg = max(1, 7-0) * 1.0 = 7
	var result0: Dictionary = cm._resolve_attack(player, cm._get_unit_ref("enemy_test"))
	var dmg0: int = int(result0.get("damage", 0))
	if dmg0 != 7:
		_fail("damage with no weapon (str=10, target armor=0, front attack) should be 7, got %d" % dmg0)
		return
	# Equip Scavenger tier 1 (id = weapon_scavenger_t2) — damage=5, str=1
	em.equip("player", "weapon_scavenger_t2", "mainhand")
	var result1: Dictionary = cm._resolve_attack(player, cm._get_unit_ref("enemy_test"))
	var dmg1: int = int(result1.get("damage", 0))
	# effective attack = 7 base + 6 equip = 13, dmg = 13
	if dmg1 != 13:
		_fail("damage with Scavenger tier 1 equipped (str=10, target armor=0) should be 13, got %d" % dmg1)
		return
	_ok("CombatManager._resolve_attack: damage uses equipment (7 → 13 with Scavenger tier 1)")


## mana_potion: restore 25 MP.
func _test_use_item_mana_potion_restores_mp() -> void:
	print("[smoke-v060] test: CombatManager.use_item mana_potion restores MP")
	var inv: Node = root.get_node_or_null("InventoryManager")
	if inv == null:
		_fail("InventoryManager autoload not available")
		return
	# Set up a player. pm.level is set to 5 in _spawn_player_at, so
	# em.get_max_mp = 20 + 5*3 = 35.
	var cm: Node = await _spawn_player_at(10, 10, 5)
	# Give the player 1 mana potion
	while inv.has_item("mana_potion", 1):
		inv.remove_item("mana_potion", 1)
	inv.add_item("mana_potion", 1)
	# Drain MP first
	var unit: Dictionary = cm._get_unit_ref("player")
	unit["mp"] = 5
	# Use mana_potion
	var result: Dictionary = cm.use_item("mana_potion")
	if not bool(result.get("ok", false)):
		_fail("use_item(mana_potion) should succeed; result=%s" % result)
		return
	if int(unit.get("mp", 0)) != 30:
		_fail("use_item(mana_potion) should restore 25 MP (5 → 30), got %d (mp_max=%d)" % [int(unit.get("mp", 0)), int(unit.get("mp_max", 0))])
		return
	if inv.has_item("mana_potion", 1):
		_fail("use_item(mana_potion) should consume one potion")
		return
	_ok("CombatManager.use_item mana_potion restores 25 MP and consumes potion")


## mana_potion fails when no potions.
func _test_use_item_mana_potion_fails_when_none() -> void:
	print("[smoke-v060] test: CombatManager.use_item mana_potion with no potions")
	var inv: Node = root.get_node_or_null("InventoryManager")
	if inv == null:
		_fail("InventoryManager autoload not available")
		return
	# Make sure no mana potions
	while inv.has_item("mana_potion", 1):
		inv.remove_item("mana_potion", 1)
	var cm: Node = await _spawn_player_at(10, 10, 5)
	var result: Dictionary = cm.use_item("mana_potion")
	if bool(result.get("ok", false)):
		_fail("use_item(mana_potion) should fail when no potions; result=%s" % result)
		return
	_ok("CombatManager.use_item mana_potion correctly fails when no potions")


## cooked_meat: heals 15 HP + grants +1 attack buff for 3 turns.
## Note: use_item calls _finish_active_turn → _advance_to_next_turn
## → _tick_buffs on the player. So the buff's "turns" decrements by 1
## before the test can read it. The buff starts at 3 turns and is
## immediately decremented to 2.
func _test_use_item_cooked_meat_heals_and_buffs() -> void:
	print("[smoke-v060] test: CombatManager.use_item cooked_meat heals and buffs")
	var inv: Node = root.get_node_or_null("InventoryManager")
	if inv == null:
		_fail("InventoryManager autoload not available")
		return
	# Set up a player
	var cm: Node = await _spawn_player_at(10, 10, 5)
	# Give the player 1 cooked_meat
	while inv.has_item("cooked_meat", 1):
		inv.remove_item("cooked_meat", 1)
	inv.add_item("cooked_meat", 1)
	# Wound the player
	var unit: Dictionary = cm._get_unit_ref("player")
	unit["hp"] = 30
	# Use cooked_meat
	var result: Dictionary = cm.use_item("cooked_meat")
	if not bool(result.get("ok", false)):
		_fail("use_item(cooked_meat) should succeed; result=%s" % result)
		return
	if int(unit.get("hp", 0)) != 45:
		_fail("use_item(cooked_meat) should heal 15 HP (30 → 45), got %d" % int(unit.get("hp", 0)))
		return
	var buffs: Dictionary = unit.get("buffs", {})
	if int(buffs.get("attack_add", 0)) != 1:
		_fail("use_item(cooked_meat) should add +1 attack buff, got buffs=%s" % str(buffs))
		return
	# After use_item, _finish_active_turn has been called → _tick_buffs
	# ran → turns decremented from 3 to 2.
	if int(buffs.get("turns", 0)) != 2:
		_fail("cooked_meat buff should be 2 turns after use (3 → 2 via _tick_buffs), got %d" % int(buffs.get("turns", 0)))
		return
	_ok("CombatManager.use_item cooked_meat: +15 HP and +1 attack buff (turns 3 → 2 after use)")


## antidote: heals 10 HP.
func _test_use_item_antidote_heals() -> void:
	print("[smoke-v060] test: CombatManager.use_item antidote heals")
	var inv: Node = root.get_node_or_null("InventoryManager")
	if inv == null:
		_fail("InventoryManager autoload not available")
		return
	var cm: Node = await _spawn_player_at(10, 10, 5)
	# Give the player 1 antidote
	while inv.has_item("antidote", 1):
		inv.remove_item("antidote", 1)
	inv.add_item("antidote", 1)
	# Wound the player
	var unit: Dictionary = cm._get_unit_ref("player")
	unit["hp"] = 20
	# Use antidote
	var result: Dictionary = cm.use_item("antidote")
	if not bool(result.get("ok", false)):
		_fail("use_item(antidote) should succeed; result=%s" % result)
		return
	if int(unit.get("hp", 0)) != 30:
		_fail("use_item(antidote) should heal 10 HP (20 → 30), got %d" % int(unit.get("hp", 0)))
		return
	_ok("CombatManager.use_item antidote: +10 HP")


## Unknown item returns error.
func _test_use_item_unknown_returns_error() -> void:
	print("[smoke-v060] test: CombatManager.use_item unknown item returns error")
	var cm: Node = await _spawn_player_at(10, 10, 5)
	var result: Dictionary = cm.use_item("nonexistent_item")
	if bool(result.get("ok", false)):
		_fail("use_item(nonexistent) should fail; result=%s" % result)
		return
	_ok("CombatManager.use_item unknown item returns error")


## Buff duration decrements each turn and expires at 0.
## Note: use_item already called _tick_buffs once, so by the time we
## get here the buff is at 2 turns. We need 1 more tick to go to 1,
## and 2 more ticks to expire.
func _test_buff_expires_after_turns() -> void:
	print("[smoke-v060] test: buff duration decrements + expires")
	var inv: Node = root.get_node_or_null("InventoryManager")
	if inv == null:
		_fail("InventoryManager autoload not available")
		return
	var cm: Node = await _spawn_player_at(10, 10, 5)
	# Give the player 1 cooked_meat
	while inv.has_item("cooked_meat", 1):
		inv.remove_item("cooked_meat", 1)
	inv.add_item("cooked_meat", 1)
	cm.use_item("cooked_meat")
	var unit: Dictionary = cm._get_unit_ref("player")
	var buffs: Dictionary = unit.get("buffs", {})
	# After use_item, _tick_buffs has run once, so turns is 2 (3 - 1)
	if int(buffs.get("turns", 0)) != 2:
		_fail("after use, buff turns should be 2 (3 - 1 from _tick_buffs), got %d" % int(buffs.get("turns", 0)))
		return
	# _tick_buffs decrements turns. Call it once more → 1
	cm._tick_buffs(unit)
	if int(unit.get("buffs", {}).get("turns", 0)) != 1:
		_fail("after 1 more tick, buff turns should be 1, got %d" % int(unit.get("buffs", {}).get("turns", 0)))
		return
	cm._tick_buffs(unit)
	# 2 more ticks → turns 0 → buff cleared
	if not unit.get("buffs", {}).is_empty():
		_fail("after 2 more ticks, buff should be cleared, got %s" % str(unit.get("buffs", {})))
		return
	_ok("CombatManager._tick_buffs: buff duration decrements and expires at 0")
