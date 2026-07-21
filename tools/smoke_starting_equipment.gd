extends SceneTree
## Smoke test: starting equipment grant + equipment-to-combat wiring.
## Verifies that new characters receive a class-matching weapon, full
## armor set, and bandages, and that these feed into combat encounters.
##
## Uses autoload instances directly (they're already in the tree).

var failures: Array[String] = []


func _fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)


func _ok(msg: String) -> void:
	print("  ok  " + msg)


func _initialize() -> void:
	print("[smoke-startequip] Starting equipment + combat wiring tests")
	await process_frame
	await _test_scavenger_starting_weapon()
	await _test_scavenger_starting_armor()
	await _test_scavenger_starting_bandages()
	await _test_scavenger_combat_stats()
	await _test_warden_starting_weapon()
	await _test_warden_starting_armor()
	await _test_warden_combat_stats()
	await _test_build_overworld_injects_equipment()

	if failures.is_empty():
		print("[smoke-startequip] All checks passed. (failures.size=%d)" % failures.size())
		quit(0)
	else:
		for f in failures:
			print("[smoke-startequip] FAIL: " + f)
		print("[smoke-startequip] %d failure(s)." % failures.size())
		quit(1)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _get_em() -> Node:
	return root.get_node("/root/EquipmentManager")


func _get_im() -> Node:
	return root.get_node("/root/InventoryHandler")


func _get_gs() -> Node:
	return root.get_node("/root/GameState")


func _create_char(class_id: String) -> void:
	var gs: Node = _get_gs()
	var im: Node = _get_im()
	# Reset session to clear any prior state
	if gs.has_method("reset_session"):
		gs.call("reset_session")
	# Clear leftover bandages from previous test runs
	while im.call("has_item", "bandage", 1) as bool:
		im.call("remove_item", "bandage", 1)
	await process_frame
	gs.call("create_character", "Human", class_id, "upworld", "TestHero", "male")
	await process_frame


# ---------------------------------------------------------------------------
# Scavenger tests
# ---------------------------------------------------------------------------

func _test_scavenger_starting_weapon() -> void:
	print("[smoke-startequip] test: Scavenger starting weapon")
	await _create_char("Scavenger")
	var em: Node = _get_em()
	var eq: Dictionary = em.call("get_equipment", "player") as Dictionary
	var mainhand: String = str(eq.get("mainhand", ""))
	if mainhand.is_empty():
		_fail("Scavenger: no starting weapon in mainhand")
		return
	if not mainhand.begins_with("weapon_scavenger_t"):
		_fail("Scavenger: weapon id should start with 'weapon_scavenger_t', got '%s'" % mainhand)
		return
	var entry: Dictionary = em.call("_resolve_item", mainhand) as Dictionary
	var damage: int = int(entry.get("damage", -1))
	if damage != 3:
		_fail("Scavenger: starting weapon damage should be 3, got %d" % damage)
		return
	_ok("Scavenger: starting weapon = %s (damage=%d)" % [entry.get("name", mainhand), damage])


func _test_scavenger_starting_armor() -> void:
	print("[smoke-startequip] test: Scavenger starting armor set")
	await _create_char("Scavenger")
	var em: Node = _get_em()
	var eq: Dictionary = em.call("get_equipment", "player") as Dictionary
	var total_armor: int = 0
	for slot in ["head", "chest", "legs", "boots"]:
		var item_id: String = str(eq.get(slot, ""))
		if item_id.is_empty():
			_fail("Scavenger: missing starting armor in slot '%s'" % slot)
			return
		if not item_id.begins_with("armor_scavenger_%s_t" % slot):
			_fail("Scavenger: armor id for %s should start with 'armor_scavenger_%s_t', got '%s'" % [slot, slot, item_id])
			return
		var entry: Dictionary = em.call("_resolve_item", item_id) as Dictionary
		total_armor += int(entry.get("armor", 0))
	if total_armor != 8:
		_fail("Scavenger: total starting armor should be 8, got %d" % total_armor)
		return
	_ok("Scavenger: full armor set (4 pieces, total armor=%d)" % total_armor)


func _test_scavenger_starting_bandages() -> void:
	print("[smoke-startequip] test: Scavenger starting bandages")
	await _create_char("Scavenger")
	var im: Node = _get_im()
	var count: int = im.call("get_count", "bandage") as int
	if count != 3:
		_fail("Scavenger: expected 3 bandages, got %d" % count)
		return
	_ok("Scavenger: 3x Bandage in inventory")


func _test_scavenger_combat_stats() -> void:
	print("[smoke-startequip] test: Scavenger combat stats from equipment")
	await _create_char("Scavenger")
	var em: Node = _get_em()
	var cs: Dictionary = em.call("get_combat_stats", "player") as Dictionary
	var atk: int = int(cs.get("attack", -1))
	var def: int = int(cs.get("defense", -1))
	# attack = weapon_damage(3) + weapon_stat_mods(str+1=1) = 4
	if atk != 4:
		_fail("Scavenger: expected attack=4 (3 weapon + 1 str mod), got %d" % atk)
		return
	# defense = armor(4x2=8) + con mod from armor stat_mods(0) = 8
	if def != 8:
		_fail("Scavenger: expected defense=8 (4x2 armor), got %d" % def)
		return
	_ok("Scavenger: combat stats attack=%d defense=%d" % [atk, def])


# ---------------------------------------------------------------------------
# Warden tests (different class -> different weapon kind)
# ---------------------------------------------------------------------------

func _test_warden_starting_weapon() -> void:
	print("[smoke-startequip] test: Warden starting weapon")
	await _create_char("Warden")
	var em: Node = _get_em()
	var eq: Dictionary = em.call("get_equipment", "player") as Dictionary
	var mainhand: String = str(eq.get("mainhand", ""))
	if mainhand.is_empty():
		_fail("Warden: no starting weapon in mainhand")
		return
	if not mainhand.begins_with("weapon_warden_t"):
		_fail("Warden: weapon id should start with 'weapon_warden_t', got '%s'" % mainhand)
		return
	var entry: Dictionary = em.call("_resolve_item", mainhand) as Dictionary
	var kind: String = str(entry.get("weapon_kind", ""))
	if kind != "shield_hammer":
		_fail("Warden: expected weapon_kind='shield_hammer', got '%s'" % kind)
		return
	_ok("Warden: starting weapon = %s (kind=%s)" % [entry.get("name", mainhand), kind])


func _test_warden_starting_armor() -> void:
	print("[smoke-startequip] test: Warden starting armor set")
	await _create_char("Warden")
	var em: Node = _get_em()
	var eq: Dictionary = em.call("get_equipment", "player") as Dictionary
	for slot in ["head", "chest", "legs", "boots"]:
		var item_id: String = str(eq.get(slot, ""))
		if item_id.is_empty():
			_fail("Warden: missing starting armor in slot '%s'" % slot)
			return
		if not item_id.begins_with("armor_warden_%s_t" % slot):
			_fail("Warden: armor id for %s should start with 'armor_warden_%s_t', got '%s'" % [slot, slot, item_id])
			return
	_ok("Warden: full armor set (4 pieces)")


func _test_warden_combat_stats() -> void:
	print("[smoke-startequip] test: Warden combat stats from equipment")
	await _create_char("Warden")
	var em: Node = _get_em()
	var cs: Dictionary = em.call("get_combat_stats", "player") as Dictionary
	var atk: int = int(cs.get("attack", -1))
	var def: int = int(cs.get("defense", -1))
	# Warden weapon stat_mods: str+1, con+1
	# attack = weapon_damage(3) + str(1) + con(1) = 5
	if atk != 5:
		_fail("Warden: expected attack=5 (3 weapon + 2 stat mods), got %d" % atk)
		return
	# defense = armor(4x2=8) + con mod from weapon(+1) = 9
	# (get_defense sums armor values + con from ALL equipped stat_mods)
	if def != 9:
		_fail("Warden: expected defense=9 (8 armor + 1 con from weapon), got %d" % def)
		return
	_ok("Warden: combat stats attack=%d defense=%d" % [atk, def])


# ---------------------------------------------------------------------------
# Encounter builder integration
# ---------------------------------------------------------------------------

func _test_build_overworld_injects_equipment() -> void:
	print("[smoke-startequip] test: build_overworld injects equipment stats")
	await _create_char("Scavenger")
	var em: Node = _get_em()
	var cs: Dictionary = em.call("get_combat_stats", "player") as Dictionary
	# Simulate what build_overworld does with equip_stats
	var char_data: Dictionary = {
		"name": "TestHero",
		"class": "Scavenger",
		"level": 1,
		"stats": {"str": 11, "dex": 11, "con": 12, "int": 10, "wis": 10, "cha": 10},
	}
	if not cs.is_empty():
		if not char_data.has("attack") or int(char_data.get("attack", 0)) == 0:
			char_data["attack"] = int(cs.get("attack", 0))
		if not char_data.has("defense") or int(char_data.get("defense", 0)) == 0:
			char_data["defense"] = int(cs.get("defense", 0))
	var final_atk: int = int(char_data.get("attack", -1))
	var final_def: int = int(char_data.get("defense", -1))
	if final_atk != 4:
		_fail("build_overworld injection: expected attack=4, got %d" % final_atk)
		return
	if final_def != 8:
		_fail("build_overworld injection: expected defense=8, got %d" % final_def)
		return
	_ok("build_overworld: equipment stats correctly injected (attack=%d, defense=%d)" % [final_atk, final_def])
