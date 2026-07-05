extends SceneTree
## Smoke test for v0.4.0 Phase 4: equipment + weapons + armor + accessories.

const EquipMgrScript = preload("res://scripts/EquipmentManager.gd")
const InvMgrScript = preload("res://scripts/InventoryManager.gd")
const ProgMgrScript = preload("res://scripts/ProgressionManager.gd")
const PartyMgrScript = preload("res://scripts/PartyNPCManager.gd")
const EquipmentScreenScript = preload("res://scripts/ui/EquipmentScreen.gd")
const StatsScreenScript = preload("res://scripts/ui/StatsScreen.gd")

var failures: Array[String] = []


func _fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)


func _ok(msg: String) -> void:
	print("  ok  " + msg)


func _initialize() -> void:
	print("[smoke-p4] v0.4.0 Phase 4 equipment + weapons + armor + stats")
	await _test_equipment_manager_basic()
	await _test_equipment_manager_equip_unequip()
	await _test_equipment_manager_stat_mods()
	await _test_weapon_template_expansion()
	await _test_armor_template_expansion()
	await _test_equipment_screen_instantiate()
	await _test_stats_screen_instantiate()

	if failures.is_empty():
		print("[smoke-p4] All checks passed. (failures.size=%d)" % failures.size())
		quit(0)
	else:
		for f in failures:
			print("[smoke-p4] FAIL: " + f)
		print("[smoke-p4] %d failure(s). (failures=%s)" % [failures.size(), str(failures)])
		quit(1)


# ---------------------------------------------------------------------------
# EquipmentManager
# ---------------------------------------------------------------------------

func _test_equipment_manager_basic() -> void:
	print("[smoke-p4] test: EquipmentManager basic API")
	var em: Node = EquipMgrScript.new()
	em.name = "TestEM"
	root.add_child(em)
	await process_frame
	# Should have loaded 6 weapon classes, 6 armor classes, 10 accessories
	if em._weapons_data.size() != 6:
		_fail("EquipmentManager: expected 6 weapon classes, got %d" % em._weapons_data.size())
		return
	if em._armor_data.size() != 6:
		_fail("EquipmentManager: expected 6 armor classes, got %d" % em._armor_data.size())
		return
	if em._accessories.size() != 10:
		_fail("EquipmentManager: expected 10 accessories, got %d" % em._accessories.size())
		return
	# Tier curve should be 26 long
	if em._weapon_curve.get("levels", []).size() != 26:
		_fail("EquipmentManager: weapon levels should be 26, got %d" % em._weapon_curve.get("levels", []).size())
		return
	_ok("EquipmentManager: 6 weapon + 6 armor classes + 10 accessories + 26-tier curve")


func _test_equipment_manager_equip_unequip() -> void:
	print("[smoke-p4] test: EquipmentManager equip / unequip")
	var em: Node = EquipMgrScript.new()
	em.name = "TestEM2"
	root.add_child(em)
	await process_frame
	# Equip a tier-1 weapon (tier 0)
	var w1: Dictionary = em.get_weapon("Scavenger", 0)
	if w1.is_empty():
		_fail("EquipmentManager: get_weapon(Scavenger, 0) returned empty")
		return
	var weapon_id: String = str(w1.get("id", ""))
	if weapon_id.is_empty():
		_fail("EquipmentManager: weapon entry has no id")
		return
	# Equip
	if not em.equip("player", weapon_id, "mainhand"):
		_fail("EquipmentManager: equip(Scavenger_t1, mainhand) should succeed")
		return
	# Verify it's in the equipment dict
	if em.get_main_hand_item("player") != weapon_id:
		_fail("EquipmentManager: main hand should be %s, got %s" % [weapon_id, em.get_main_hand_item("player")])
		return
	# Unequip
	if not em.unequip("player", "mainhand"):
		_fail("EquipmentManager: unequip mainhand should succeed")
		return
	if not em.get_main_hand_item("player").is_empty():
		_fail("EquipmentManager: main hand should be empty after unequip, got %s" % em.get_main_hand_item("player"))
		return
	_ok("EquipmentManager: equip + unequip round-trip works")


func _test_equipment_manager_stat_mods() -> void:
	print("[smoke-p4] test: EquipmentManager stat_mods sum")
	var em: Node = EquipMgrScript.new()
	em.name = "TestEM3"
	root.add_child(em)
	await process_frame
	# Equip a Scavenger weapon (has +1 str from class stat_mods)
	var w1: Dictionary = em.get_weapon("Scavenger", 0)
	em.equip("player", str(w1.get("id", "")), "mainhand")
	# Equip an accessory with str bonus
	em.equip("player", "iron_grip", "acc1")
	# Sum stat_mods
	var mods: Dictionary = em.get_stat_mods("player")
	var str_bonus: int = int(mods.get("str", 0))
	if str_bonus != 3:  # 1 from weapon + 2 from iron_grip
		_fail("EquipmentManager: expected str=3, got %d" % str_bonus)
		return
	_ok("EquipmentManager: stat_mods sum correctly (weapon +1 str + iron_grip +2 str = 3)")


# ---------------------------------------------------------------------------
# Template expansion
# ---------------------------------------------------------------------------

func _test_weapon_template_expansion() -> void:
	print("[smoke-p4] test: weapon template expansion")
	var em: Node = EquipMgrScript.new()
	em.name = "TestEM4"
	root.add_child(em)
	await process_frame
	# T0 weapon
	var w0: Dictionary = em.get_weapon("Scavenger", 0)
	if w0.is_empty():
		_fail("EquipmentManager: tier 0 weapon empty")
		return
	if int(w0.get("damage", 0)) != 3:
		_fail("EquipmentManager: tier 0 Scavenger damage should be 3, got %d" % int(w0.get("damage", 0)))
		return
	if int(w0.get("level_required", 0)) != 1:
		_fail("EquipmentManager: tier 0 level_required should be 1, got %d" % int(w0.get("level_required", 0)))
		return
	# T25 weapon
	var w25: Dictionary = em.get_weapon("Scavenger", 25)
	if w25.is_empty():
		_fail("EquipmentManager: tier 25 weapon empty")
		return
	if int(w25.get("damage", 0)) != 300:
		_fail("EquipmentManager: tier 25 Scavenger damage should be 300, got %d" % int(w25.get("damage", 0)))
		return
	# Different class different base
	var w_tech: Dictionary = em.get_weapon("Technician", 0)
	if int(w_tech.get("damage", 0)) == int(w0.get("damage", 0)) and str(w0.get("weapon_kind", "")) == str(w_tech.get("weapon_kind", "")):
		# Same damage OK (both tier 0) but weapon_kind should differ
		if w0.get("weapon_kind") == w_tech.get("weapon_kind"):
			_fail("EquipmentManager: different classes should have different weapon_kind")
			return
	_ok("EquipmentManager: weapons expand from tier_curve, different per class")


func _test_armor_template_expansion() -> void:
	print("[smoke-p4] test: armor template expansion")
	var em: Node = EquipMgrScript.new()
	em.name = "TestEM5"
	root.add_child(em)
	await process_frame
	# T0 armor head for Scavenger
	var a0: Dictionary = em.get_armor("Scavenger", "head", 0)
	if a0.is_empty():
		_fail("EquipmentManager: tier 0 armor empty")
		return
	if int(a0.get("armor", 0)) != 2:
		_fail("EquipmentManager: tier 0 armor should be 2, got %d" % int(a0.get("armor", 0)))
		return
	# T12 armor (max tier for armor is 13)
	var a12: Dictionary = em.get_armor("Scavenger", "head", 12)
	if a12.is_empty():
		_fail("EquipmentManager: tier 12 armor empty")
		return
	if int(a12.get("armor", 0)) != 150:
		_fail("EquipmentManager: tier 12 Scavenger head armor should be 150, got %d" % int(a12.get("armor", 0)))
		return
	_ok("EquipmentManager: armor expands from tier_curve, 13 tiers per (class, slot)")


# ---------------------------------------------------------------------------
# Screen placeholders
# ---------------------------------------------------------------------------

func _test_equipment_screen_instantiate() -> void:
	print("[smoke-p4] test: EquipmentScreen instantiate")
	var screen: Control = EquipmentScreenScript.new()
	screen.name = "TestEquipScreen"
	root.add_child(screen)
	await process_frame
	if screen.get_child_count() == 0:
		_fail("EquipmentScreen: should have child UI nodes after _ready")
		return
	_ok("EquipmentScreen: instantiates with %d child nodes" % screen.get_child_count())


func _test_stats_screen_instantiate() -> void:
	print("[smoke-p4] test: StatsScreen instantiate")
	var screen: Control = StatsScreenScript.new()
	screen.name = "TestStatsScreen"
	root.add_child(screen)
	await process_frame
	if screen.get_child_count() == 0:
		_fail("StatsScreen: should have child UI nodes after _ready")
		return
	_ok("StatsScreen: instantiates with %d child nodes" % screen.get_child_count())
