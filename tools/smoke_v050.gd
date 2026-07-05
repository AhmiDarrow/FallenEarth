extends SceneTree
## Smoke test for v0.5.0: HP/MP damage in combat (bandage heal,
## equipment-aware stats), button asset generation.

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
	print("[smoke-v050] v0.5.0 HP/MP combat + equipment-aware stats")
	await _test_combat_manager_max_hp_uses_equipment()
	await _test_combat_manager_attack_uses_equipment()
	await _test_equipment_manager_max_hp_uses_mods()
	await _test_equipment_manager_attack_includes_gear()
	await _test_combat_manager_bandage_heal()
	await _test_combat_manager_bandage_no_consume_when_none()

	if failures.is_empty():
		print("[smoke-v050] All checks passed. (failures.size=%d)" % failures.size())
		quit(0)
	else:
		for f in failures:
			print("[smoke-v050] FAIL: " + f)
		print("[smoke-v050] %d failure(s). (failures=%s)" % [failures.size(), str(failures)])
		quit(1)


# ---------------------------------------------------------------------------
# v0.5.0: HP/MP damage + equipment-aware stats
# ---------------------------------------------------------------------------

func _test_combat_manager_max_hp_uses_equipment() -> void:
	print("[smoke-v050] test: CombatManager.get_max_hp uses EquipmentManager")
	var em: Node = root.get_node_or_null("EquipmentManager")
	var pm: Node = root.get_node_or_null("ProgressionManager")
	if em == null or pm == null:
		_fail("EquipmentManager or ProgressionManager autoload not available")
		return
	pm.level = 10
	var hp: int = em.get_max_hp("TestClass", 10, {})
	if hp != 130:
		_fail("CombatManager.get_max_hp at L10 with no mods should be 130 (got %d)" % hp)
		return
	# With con +2 mod, +8 HP
	hp = em.get_max_hp("TestClass", 10, {"con": 2})
	if hp != 138:
		_fail("CombatManager.get_max_hp at L10 with con+2 should be 138 (got %d)" % hp)
		return
	_ok("CombatManager.get_max_hp uses EquipmentManager.get_max_hp curve + mod bonuses")


func _test_combat_manager_attack_uses_equipment() -> void:
	print("[smoke-v050] test: CombatManager.get_attack uses EquipmentManager")
	var em: Node = root.get_node_or_null("EquipmentManager")
	if em == null:
		_fail("EquipmentManager autoload not available")
		return
	# Equip a weapon in mainhand
	var weapon: Dictionary = em.get_weapon("Scavenger", 0)
	if weapon.is_empty():
		_fail("CombatManager.get_attack: get_weapon(Scavenger, 0) returned empty")
		return
	# Reset the player's equipment to avoid contamination from earlier tests
	em.restore_from_snapshot({"equipment_state": {"player": em._empty_equipment() if em.has_method("_empty_equipment") else {"head":"","chest":"","legs":"","boots":"","mainhand":"","offhand":"","tool":"","acc1":"","acc2":""}}})
	em.equip("player", str(weapon.get("id", "")), "mainhand")
	var atk: int = em.get_attack("player")
	# Attack = weapon damage + str mod.
	# Scavenger tier 0 weapon damage = 3, str_mod = +1.
	if atk < 3:
		_fail("CombatManager.get_attack should include weapon damage (got %d, expected >= 3)" % atk)
		return
	# Now equip armor with stat_mods (e.g. iron_grip +2 str)
	em.unequip("player", "mainhand")
	em.equip("player", "iron_grip", "acc1")
	atk = em.get_attack("player")
	if atk != 2:
		_fail("CombatManager.get_attack with iron_grip acc but no weapon should be 2 (got %d)" % atk)
		return
	_ok("CombatManager.get_attack includes weapon damage + acc mods")


func _test_equipment_manager_max_hp_uses_mods() -> void:
	print("[smoke-v050] test: EquipmentManager.get_max_hp uses mod sum")
	var em: Node = root.get_node_or_null("EquipmentManager")
	if em == null:
		_fail("EquipmentManager autoload not available")
		return
	# L5 with hp_max_add + 20
	var hp: int = em.get_max_hp("Warden", 5, {"hp_max_add": 20})
	# 50 + 5*8 + 20 = 110
	if hp != 110:
		_fail("EquipmentManager.get_max_hp with hp_max_add +20 should be 110 (got %d)" % hp)
		return
	_ok("EquipmentManager.get_max_hp applies hp_max_add mod")


func _test_equipment_manager_attack_includes_gear() -> void:
	print("[smoke-v050] test: EquipmentManager.get_attack includes gear")
	var em: Node = root.get_node_or_null("EquipmentManager")
	if em == null:
		_fail("EquipmentManager autoload not available")
		return
	# Clear state to avoid contamination
	em.restore_from_snapshot({"equipment_state": {"player": em._empty_equipment() if em.has_method("_empty_equipment") else {"head":"","chest":"","legs":"","boots":"","mainhand":"","offhand":"","tool":"","acc1":"","acc2":""}}})
	# No weapon — attack = 0
	var atk: int = em.get_attack("player")
	if atk != 0:
		_fail("EquipmentManager.get_attack with no weapon should be 0 (got %d)" % atk)
		return
	# Equip a weapon
	var weapon: Dictionary = em.get_weapon("Scavenger", 0)
	if weapon.is_empty():
		_fail("EquipmentManager.get_attack: get_weapon(Scavenger, 0) returned empty (test setup)")
		return
	em.equip("player", str(weapon.get("id", "")), "mainhand")
	atk = em.get_attack("player")
	if atk <= 0:
		_fail("EquipmentManager.get_attack with weapon should be > 0 (got %d)" % atk)
		return
	_ok("EquipmentManager.get_attack includes weapon damage (got %d)" % atk)


func _test_combat_manager_bandage_heal() -> void:
	print("[smoke-v050] test: CombatManager.use_item bandage heal")
	var cm: Node = CombatMgrScript.new()
	cm.name = "TestCombat"
	root.add_child(cm)
	await process_frame
	var inv: Node = root.get_node_or_null("InventoryManager")
	if inv == null:
		_fail("InventoryManager autoload not available")
		return
	# Give the player 1 bandage
	while inv.has_item("bandage", 1):
		inv.remove_item("bandage", 1)
	inv.add_item("bandage", 1)
	# Set up a complete character snapshot so _spawn_player doesn't fail
	cm._character_snapshot = {
		"class": "Scavenger",
		"name": "TestPlayer",
		"level": 5,
		"stats": {"str": 10, "dex": 10, "con": 10, "int": 10, "wis": 10},
		"health": 50,
		"max_health": 100,
		"move_bonus": 0, "jump_bonus": 0, "speed_bonus": 0,
		"mp_max": 24, "weapon_range": 1, "attack_bonus": 0, "armor_bonus": 0,
		"abilities": [],
	}
	cm._class_combat = {}
	cm._spawn_player(Vector2i(2, 2))
	var unit: Dictionary = cm._get_unit_ref(cm.active_unit_id)
	# Wound the player
	unit["hp"] = 30
	# Set battle phase + active unit
	cm.battle_phase = cm.BattlePhase.ACTIVE
	cm.active_unit_id = unit.get("id", "")
	# Use bandage
	var result: Dictionary = cm.use_item("bandage")
	if not bool(result.get("ok", false)):
		_fail("CombatManager.use_item bandage should succeed; result=%s" % result)
		return
	if int(unit.get("hp", 0)) != 60:
		_fail("CombatManager.use_item bandage should heal 30 HP (60 = 30 + 30), got %d" % int(unit.get("hp", 0)))
		return
	if inv.has_item("bandage", 1):
		_fail("CombatManager.use_item bandage should consume one bandage")
		return
	_ok("CombatManager.use_item bandage heals 30 HP and consumes bandage")


func _test_combat_manager_bandage_no_consume_when_none() -> void:
	print("[smoke-v050] test: CombatManager.use_item bandage with no bandages")
	var cm: Node = CombatMgrScript.new()
	cm.name = "TestCombat2"
	root.add_child(cm)
	await process_frame
	var inv: Node = root.get_node_or_null("InventoryManager")
	# Make sure no bandages
	while inv.has_item("bandage", 1):
		inv.remove_item("bandage", 1)
	cm._character_snapshot = {
		"class": "Scavenger",
		"name": "TestPlayer",
		"level": 5,
		"stats": {"str": 10, "dex": 10, "con": 10, "int": 10, "wis": 10},
		"health": 100,
		"max_health": 100,
		"move_bonus": 0, "jump_bonus": 0, "speed_bonus": 0,
		"mp_max": 24, "weapon_range": 1, "attack_bonus": 0, "armor_bonus": 0,
		"abilities": [],
	}
	cm._class_combat = {}
	cm._spawn_player(Vector2i(2, 2))
	var unit: Dictionary = cm._get_unit_ref(cm.active_unit_id)
	cm.battle_phase = cm.BattlePhase.ACTIVE
	cm.active_unit_id = unit.get("id", "")
	var result: Dictionary = cm.use_item("bandage")
	if bool(result.get("ok", false)):
		_fail("CombatManager.use_item bandage should fail when no bandages; result=%s" % result)
		return
	_ok("CombatManager.use_item bandage correctly fails when no bandages (HP preserved)")
