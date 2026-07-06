extends SceneTree
## v0.10.0 — Combat UI polish smoke test.
##
## Verifies the new BattleHUD, TurnOrderPanel, BattleResultPanel,
## CombatPopup, and TargetingReticle components load and respond
## to the combat lifecycle.

const BattleHUDScript = preload("res://scripts/combat/BattleHUD.gd")
const TurnOrderPanelScript = preload("res://scripts/combat/TurnOrderPanel.gd")
const BattleResultPanelScript = preload("res://scripts/combat/BattleResultPanel.gd")
const CombatPopupScript = preload("res://scripts/combat/CombatPopup.gd")
const TargetingReticleScript = preload("res://scripts/combat/TargetingReticle.gd")
const CombatMgr = preload("res://scripts/CombatManager.gd")

var failures: Array[String] = []


func _initialize() -> void:
	print("[smoke-v100-ui] v0.10.0 Combat UI Polish")
	_test_battle_hud_constructs()
	await process_frame
	_test_battle_hud_updates_on_active_change()
	await process_frame
	_test_turn_order_panel_lists_units()
	await process_frame
	_test_result_panel_victory_defeat()
	await process_frame
	_test_combat_popup_spawns()
	await process_frame
	_test_targeting_reticle_pulses()
	await process_frame
	_test_assets_exist()
	_print_summary()
	quit()


func _fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)


func _ok(msg: String) -> void:
	print("  ok  " + msg)


func _make_combat() -> Node:
	var c = CombatMgr.new()
	var encounter: Dictionary = {
		"grid_size": 5,
		"biome_key": "Ash Wastes",
		"height_seed": 1,
		"player_start": Vector2i(2, 4),
		"character_data": {"stats": {"str": 12, "dex": 12, "con": 12, "int": 10, "wis": 10}, "level": 1, "class": "scavenger", "name": "TestHero", "race": "human", "gender": "male", "abilities": [], "max_health": 100, "health": 100},
		"class_combat": {"move_bonus": 0, "jump_bonus": 0, "speed_bonus": 0, "mp_max": 24, "weapon_range": 1, "attack_bonus": 0, "armor_bonus": 0, "abilities": []},
		"enemy_templates": [
			{"id": "ash_crawler", "sprite_id": "ash_crawler", "name": "Ash Crawler", "hp": 30, "armor": 0, "attack_damage": 5, "speed": 6, "ai_archetype": "aggressive"},
		],
	}
	c.setup_from_encounter(encounter)
	return c


func _test_battle_hud_constructs() -> void:
	print("\n--- BattleHUD ---")
	var hud = BattleHUDScript.new()
	hud.name = "TestHUD"
	root.add_child(hud)
	await process_frame
	if hud == null:
		_fail("BattleHUD: instantiation failed")
		return
	if hud._portrait == null:
		_fail("BattleHUD: _portrait not built")
	else:
		_ok("BattleHUD: portrait built")
	if hud._hp_bar == null or hud._mp_bar == null or hud._ct_bar == null:
		_fail("BattleHUD: one or more bars not built")
	else:
		_ok("BattleHUD: HP / MP / CT bars built")
	hud.queue_free()


func _test_battle_hud_updates_on_active_change() -> void:
	print("\n--- BattleHUD: updates on active_unit_changed ---")
	var c = _make_combat()
	var hud = BattleHUDScript.new()
	root.add_child(hud)
	await process_frame
	hud.setup(c)
	# Force the CT to threshold for the player so they go first.
	for u in c.get_units():
		if str(u.get("id", "")) == "player":
			u["ct"] = 200
	# Manually tick CT until the player goes.
	c._advance_to_next_turn()
	if c.active_unit_id == "":
		_fail("BattleHUD: no active unit after advance")
		hud.queue_free()
		c.free()
		return
	hud.refresh()
	await process_frame
	var name_text: String = hud._name_label.text
	if name_text == "—":
		_fail("BattleHUD: did not update name after refresh")
	else:
		_ok("BattleHUD: name updated to '%s'" % name_text)
	if hud._hp_fill.size.x <= 0.0:
		_fail("BattleHUD: HP bar empty after refresh")
	else:
		_ok("BattleHUD: HP bar filled (%.1fpx)" % hud._hp_fill.size.x)
	hud.queue_free()
	c.free()


func _test_turn_order_panel_lists_units() -> void:
	print("\n--- TurnOrderPanel ---")
	var c = _make_combat()
	var panel = TurnOrderPanelScript.new()
	root.add_child(panel)
	await process_frame
	panel.setup(c)
	panel.refresh()
	await process_frame
	if panel._vbox.get_child_count() <= 1:
		_fail("TurnOrderPanel: no rows added (got %d, expect header + at least 1 row)" % panel._vbox.get_child_count())
	else:
		_ok("TurnOrderPanel: %d rows (header + units)" % panel._vbox.get_child_count())
	panel.queue_free()
	c.free()


func _test_result_panel_victory_defeat() -> void:
	print("\n--- BattleResultPanel ---")
	var panel = BattleResultPanelScript.new()
	panel.name = "TestResult"
	root.add_child(panel)
	await process_frame
	if panel._title_label == null:
		_fail("BattleResultPanel: _title_label not built")
		return
	panel.set_outcome("victory", "VICTORY", "[center]+50 XP[/center]")
	if panel._title_label.text != "VICTORY":
		_fail("BattleResultPanel: title not 'VICTORY' after set_outcome")
	else:
		_ok("BattleResultPanel: victory outcome sets title")
	panel.set_outcome("defeat", "DEFEAT", "[center]Game over.[/center]")
	if panel._title_label.text != "DEFEAT":
		_fail("BattleResultPanel: title not 'DEFEAT' after set_outcome")
	else:
		_ok("BattleResultPanel: defeat outcome sets title")
	if not panel.visible:
		_fail("BattleResultPanel: should be visible after set_outcome")
	else:
		_ok("BattleResultPanel: visible after set_outcome")
	panel.queue_free()


func _test_combat_popup_spawns() -> void:
	print("\n--- CombatPopup ---")
	var popup = CombatPopupScript.new()
	popup.name = "TestPopup"
	root.add_child(popup)
	await process_frame
	popup.show_popup("critical", Vector2(100, 100))
	if popup._label.text != "CRITICAL":
		_fail("CombatPopup: text not 'CRITICAL', got '%s'" % popup._label.text)
	else:
		_ok("CombatPopup: shows 'CRITICAL' text")
	popup.queue_free()


func _test_targeting_reticle_pulses() -> void:
	print("\n--- TargetingReticle ---")
	var reticle = TargetingReticleScript.new()
	reticle.name = "TestReticle"
	root.add_child(reticle)
	await process_frame
	if reticle._tl == null:
		_fail("TargetingReticle: corner lines not built")
		return
	_ok("TargetingReticle: 4 corner lines built")
	reticle.set_kind("attack")
	if not reticle._tl.default_color.is_equal_approx(TargetingReticleScript.COLOR_ATTACK):
		_fail("TargetingReticle: color did not change to attack")
	else:
		_ok("TargetingReticle: set_kind('attack') updates color")
	reticle.set_kind("skill")
	if not reticle._tl.default_color.is_equal_approx(TargetingReticleScript.COLOR_SKILL):
		_fail("TargetingReticle: color did not change to skill")
	else:
		_ok("TargetingReticle: set_kind('skill') updates color")
	reticle.queue_free()


func _test_assets_exist() -> void:
	print("\n--- battle UI assets present ---")
	for path in [
		"res://assets/battle_ui/battle_hud_panel.png",
		"res://assets/battle_ui/victory_panel.png",
		"res://assets/battle_ui/defeat_panel.png",
		"res://assets/battle_ui/reticle.png",
		"res://assets/battle_ui/icon_attack.png",
		"res://assets/battle_ui/icon_skill.png",
		"res://assets/battle_ui/icon_wait.png",
	]:
		if not ResourceLoader.exists(path):
			_fail("missing asset: %s" % path)
		else:
			_ok("asset present: %s" % path.replace("res://assets/battle_ui/", ""))


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
