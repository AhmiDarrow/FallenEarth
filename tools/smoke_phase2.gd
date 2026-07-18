extends SceneTree
## Smoke test for the v0.4.0 Phase 2 full Character HUD + hotbar + minimap
## + ProgressionManager + LootRoller.
##
## Exercises:
##   - ProgressionManager.add_xp / add_ec / spend_ec / level up
##   - LootRoller.roll + roll_and_apply (mob drops + XP + EC)
##   - Hotbar.set_slot / get_slot / select_slot / 10 slots
##   - Minimap renders without errors (visual: 180x180, has a viewport)
##   - HUD instantiates and composes all sub-components

const ProgressionMgrScript = preload("res://scripts/ProgressionManager.gd")
const LootRollerScript = preload("res://scripts/LootRoller.gd")
const HotbarScript = preload("res://scripts/ui/Hotbar.gd")
const MinimapScript = preload("res://scripts/ui/Minimap.gd")
const HUDScript = preload("res://scripts/ui/HUD.gd")
const InventoryScreenScript = preload("res://scripts/ui/InventoryScreen.gd")
const HoverTooltipScript = preload("res://scripts/HoverTooltip.gd")

var failures: Array[String] = []


func _fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)


func _ok(msg: String) -> void:
	print("  ok  " + msg)


func _initialize() -> void:
	print("[smoke-p2] v0.4.0 Phase 2 HUD + hotbar + minimap + progression + loot")
	_test_progression_manager()
	_test_loot_roller_dry()
	_test_loot_roller_with_managers()
	_test_hotbar_basic()
	_test_minimap_renders()
	_test_hud_composes()

	if failures.is_empty():
		print("[smoke-p2] All checks passed.")
		quit(0)
	else:
		for f in failures:
			print("[smoke-p2] FAIL: " + f)
		print("[smoke-p2] %d failure(s)." % failures.size())
		quit(1)


func _test_progression_manager() -> void:
	print("[smoke-p2] test: ProgressionManager")
	var prog: Node = ProgressionMgrScript.new()
	prog.name = "TestProgressionManager"
	root.add_child(prog)
	await process_frame
	# Default level 1
	if int(prog.level) != 1:
		_fail("Default level should be 1, got %d" % prog.level)
		return
	if int(prog.ec) < 1:
		_fail("Starting EC should be > 0, got %d" % prog.ec)
		return
	# add_xp(75) should level up to 2 (xp_to_next(1) = 50+25=75)
	prog.add_xp(75)
	if int(prog.level) != 2:
		_fail("After add_xp(75), level should be 2, got %d" % prog.level)
		return
	# Spend EC: 10 should succeed, 999999 should fail
	if not prog.spend_ec(10):
		_fail("spend_ec(10) should succeed")
		return
	if prog.spend_ec(999999):
		_fail("spend_ec(999999) should fail (insufficient) but returned true")
		return
	_ok("ProgressionManager: add_xp levels, spend_ec gates correctly")


func _test_loot_roller_dry() -> void:
	print("[smoke-p2] test: LootRoller.roll (no apply)")
	var mob := {
		"id": "blight_toad",
		"sprite_id": "blight_toad",
		"level": 5,
	}
	var result: Dictionary = LootRollerScript.roll(mob, "Neon Bogs")
	if int(result.get("xp", 0)) <= 0:
		_fail("LootRoller.roll: xp should be > 0, got %s" % result.get("xp", 0))
		return
	if int(result.get("ec", 0)) <= 0:
		_fail("LootRoller.roll: ec should be > 0, got %s" % result.get("ec", 0))
		return
	# Level 5 mob: 5*5+5=30 XP, 5*2+(1..5)=11-15 EC
	if int(result.get("xp", 0)) != 30:
		_fail("LootRoller.roll: expected xp=30 for L5, got %s" % result.get("xp", 0))
		return
	_ok("LootRoller.roll: dry run produces xp=%d ec=%d" % [int(result.get("xp", 0)), int(result.get("ec", 0))])


func _test_loot_roller_with_managers() -> void:
	print("[smoke-p2] test: LootRoller.roll_and_apply")
	var prog: Node = ProgressionMgrScript.new()
	var inv: Node = preload("res://scripts/InventoryManager.gd").new()
	root.add_child(prog)
	root.add_child(inv)
	await process_frame
	var start_xp: int = int(prog.xp)
	var start_ec: int = int(prog.ec)
	var mob := {
		"id": "test_mob",
		"sprite_id": "test_mob",
		"level": 3,
		"drops": [
			{"item_id": "iron_ore", "qty": 2, "chance": 1.0},
		],
	}
	var result: Dictionary = LootRollerScript.roll_and_apply(mob, "Ash Wastes", inv, prog)
	if int(inv.get_count("iron_ore")) != 2:
		_fail("LootRoller.roll_and_apply: inventory should have 2 iron_ore, got %d" % inv.get_count("iron_ore"))
		return
	if int(prog.xp) - start_xp != int(result.get("xp", 0)):
		_fail("LootRoller.roll_and_apply: xp gain mismatch")
		return
	if int(prog.ec) <= start_ec:
		_fail("LootRoller.roll_and_apply: ec should have increased")
		return
	_ok("LootRoller.roll_and_apply: drops to inventory, xp+ec to progression")


func _test_hotbar_basic() -> void:
	print("[smoke-p2] test: Hotbar")
	var hb: Control = HotbarScript.new()
	root.add_child(hb)
	await process_frame
	# 10 slots, all empty
	if hb.get_slots().size() != 10:
		_fail("Hotbar: expected 10 slots, got %d" % hb.get_slots().size())
		return
	for s in hb.get_slots():
		if s != "":
			_fail("Hotbar: fresh slot should be empty")
			return
	# Set slot 0
	hb.set_slot(0, "axe_stone")
	if hb.get_slot(0) != "axe_stone":
		_fail("Hotbar: set_slot(0) failed")
		return
	# Select slot 0 → equipped_item_id should be axe_stone
	hb.select_slot(0)
	if hb.equipped_item_id != "axe_stone":
		_fail("Hotbar: equipped_item_id after select_slot wrong: %s" % hb.equipped_item_id)
		return
	# Select slot 9 (last)
	hb.select_slot(9)
	if hb.equipped_item_id != "":
		_fail("Hotbar: selecting empty slot should give empty equipped")
		return
	_ok("Hotbar: 10 slots, set/get/select all work")


func _test_minimap_renders() -> void:
	print("[smoke-p2] test: Minimap renders")
	var mm: Control = MinimapScript.new()
	root.add_child(mm)
	await process_frame
	# Force a refresh and redraw (we don't have GameState here, so it
	# should gracefully no-op and still draw the background)
	mm.refresh()
	await process_frame
	_ok("Minimap: instantiates + refreshes without error")


func _test_hud_composes() -> void:
	print("[smoke-p2] test: HUD composes all sub-components")
	var prog: Node = ProgressionMgrScript.new()
	root.add_child(prog)
	var inv: Node = preload("res://scripts/InventoryManager.gd").new()
	root.add_child(inv)
	await process_frame
	# Build a HUD as a child of the scene tree root
	var hud: Control = HUDScript.new()
	hud.name = "HUD"
	root.add_child(hud)
	await process_frame
	# It should have children: top bar bg, name, class, level, ec, hp/mp/xp bars + labels, minimap, hotbar, menu button
	var found_minimap := false
	var found_hotbar := false
	for child in hud.get_children():
		if child.name == "Minimap":
			found_minimap = true
		if child.name == "Hotbar":
			found_hotbar = true
	if not found_minimap:
		_fail("HUD: Minimap child not found")
		return
	if not found_hotbar:
		_fail("HUD: Hotbar child not found")
		return
	# Verify the hotbar is functional through the HUD
	var hb: Control = hud.get_hotbar() as Control
	if hb == null:
		_fail("HUD: get_hotbar() returned null")
		return
	# Programmatic XP/EC update flows through signals
	prog.add_xp(75)  # level up to 2
	await process_frame
	# HUD's level label should now read "Lv. 2"
	var lvl_text: String = ""
	for child in hud.get_children():
		if child is Label and "Lv. " in child.text:
			lvl_text = child.text
			break
	if not "Lv. 2" in lvl_text:
		_fail("HUD: level label didn't update on level up: %s" % lvl_text)
		return
	_ok("HUD: composes minimap+hotbar, level up flows through signal")
