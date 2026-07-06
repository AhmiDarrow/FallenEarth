extends SceneTree
## v0.10.1 — Combat UI polish smoke test.
##
## Verifies the new UnitSelectionArrow, TopPrompt, UnitNamePlate,
## and the BattleBackground decor scattering. Also verifies the
## BattleCell border-frame highlight.

const UnitSelectionArrowScript = preload("res://scripts/combat/UnitSelectionArrow.gd")
const TopPromptScript = preload("res://scripts/combat/TopPrompt.gd")
const UnitNamePlateScript = preload("res://scripts/combat/UnitNamePlate.gd")
const BattleBackgroundScript = preload("res://scripts/combat/BattleBackground.gd")
const BattleCellScript = preload("res://scripts/combat/BattleCell.gd")
const BattleGridViewScript = preload("res://scripts/combat/BattleGridView.gd")
const BattleUnitScript = preload("res://scripts/combat/BattleUnit.gd")
const CombatMgr = preload("res://scripts/CombatManager.gd")

var failures: Array[String] = []


func _initialize() -> void:
	print("[smoke-v101] v0.10.1 Combat UI Polish")
	_test_unit_selection_arrow()
	await process_frame
	_test_top_prompt()
	await process_frame
	_test_unit_name_plate()
	await process_frame
	_test_battle_cell_border_highlight()
	await process_frame
	_test_battle_background_decor_assets()
	await process_frame
	_test_battle_unit_owns_name_plate_and_arrow()
	await process_frame
	_test_pixellab_assets_exist()
	_print_summary()
	quit()


func _fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)


func _ok(msg: String) -> void:
	print("  ok  " + msg)


func _test_unit_selection_arrow() -> void:
	print("\n--- UnitSelectionArrow ---")
	var arr = UnitSelectionArrowScript.new()
	arr.name = "TestArrow"
	root.add_child(arr)
	await process_frame
	if arr == null:
		_fail("UnitSelectionArrow: instantiation failed")
		return
	if not is_instance_valid(arr) or not arr.has_method("set_active"):
		_fail("UnitSelectionArrow: missing set_active method")
	else:
		_ok("UnitSelectionArrow: built with set_active")
	# Default: hidden (set_active(false))
	if arr.visible:
		_fail("UnitSelectionArrow: should start hidden")
	else:
		_ok("UnitSelectionArrow: starts hidden (visible=false)")
	# Activate
	arr.set_active(true)
	if not arr.visible:
		_fail("UnitSelectionArrow: should be visible after set_active(true)")
	else:
		_ok("UnitSelectionArrow: visible after set_active(true)")
	arr.set_active(false)
	if arr.visible:
		_fail("UnitSelectionArrow: should be hidden after set_active(false)")
	else:
		_ok("UnitSelectionArrow: hidden after set_active(false)")
	# Snap to a cell
	arr.snap_to_cell(3, 4, 24)
	if arr.position.x <= 0.0 or arr.position.y <= 0.0:
		_fail("UnitSelectionArrow: snap_to_cell did not move arrow")
	else:
		_ok("UnitSelectionArrow: snap_to_cell positions arrow at (%.1f, %.1f)" % [arr.position.x, arr.position.y])
	arr.queue_free()


func _test_top_prompt() -> void:
	print("\n--- TopPrompt ---")
	var p = TopPromptScript.new()
	p.name = "TestPrompt"
	root.add_child(p)
	await process_frame
	if p == null:
		_fail("TopPrompt: instantiation failed")
		return
	if not p.has_method("show_prompt"):
		_fail("TopPrompt: missing show_prompt method")
	else:
		_ok("TopPrompt: built with show_prompt")
	# Initially hidden
	if p.visible:
		_fail("TopPrompt: should start hidden")
	else:
		_ok("TopPrompt: starts hidden")
	# Show a prompt
	p.show_prompt("Select a white tile to move", "Then choose an action", 0.0)
	if not p.visible:
		_fail("TopPrompt: should be visible after show_prompt")
	else:
		_ok("TopPrompt: visible after show_prompt")
	if p._label.text != "Select a white tile to move":
		_fail("TopPrompt: title text wrong (got '%s')" % p._label.text)
	else:
		_ok("TopPrompt: title set to 'Select a white tile to move'")
	# Show with a sub line
	p.show_prompt("Choose an action", "Skill / Attack / Wait / Finish", 0.0)
	if not p._sub.visible:
		_fail("TopPrompt: sub label should be visible when sub provided")
	else:
		_ok("TopPrompt: sub label visible when sub text provided")
	# Hide
	p.hide_prompt()
	if p.visible:
		_fail("TopPrompt: should be hidden after hide_prompt")
	else:
		_ok("TopPrompt: hidden after hide_prompt")
	p.queue_free()


func _test_unit_name_plate() -> void:
	print("\n--- UnitNamePlate ---")
	var n = UnitNamePlateScript.new()
	n.name = "TestName"
	root.add_child(n)
	await process_frame
	if n == null:
		_fail("UnitNamePlate: instantiation failed")
		return
	if n._bg == null:
		_fail("UnitNamePlate: _bg ColorRect not built")
	else:
		_ok("UnitNamePlate: _bg ColorRect built")
	if n._label == null:
		_fail("UnitNamePlate: _label Label not built")
	else:
		_ok("UnitNamePlate: _label Label built")
	# Set unit info for a player
	n.set_unit_info("Hero", "player", false)
	if n._label.text != "Hero":
		_fail("UnitNamePlate: label text wrong (got '%s')" % n._label.text)
	else:
		_ok("UnitNamePlate: label set to 'Hero' for player team")
	# Set for a boss
	n.set_unit_info("Rift Maw", "enemy", true)
	if n._label.text != "Rift Maw":
		_fail("UnitNamePlate: boss label text wrong (got '%s')" % n._label.text)
	else:
		_ok("UnitNamePlate: boss label set to 'Rift Maw'")
	# Snap to a cell
	n.snap_to_cell(2, 3, 24)
	if n.position.x <= 0.0 or n.position.y <= 0.0:
		_fail("UnitNamePlate: snap_to_cell did not move plate")
	else:
		_ok("UnitNamePlate: snap_to_cell positions plate at (%.1f, %.1f)" % [n.position.x, n.position.y])
	n.queue_free()


func _test_battle_cell_border_highlight() -> void:
	print("\n--- BattleCell: border-frame highlight ---")
	var cell = BattleCellScript.new()
	cell.name = "TestCell"
	root.add_child(cell)
	await process_frame
	cell.setup(0, 0, 0, 0, false, null)
	# Move range: full-cell tint (white)
	cell.set_highlight(BattleCellScript.HIGHLIGHT_MOVE)
	if not cell._highlight.visible:
		_fail("BattleCell: HIGHLIGHT_MOVE should show full-cell tint")
	else:
		_ok("BattleCell: HIGHLIGHT_MOVE shows full-cell tint")
	# Attack: border only, no full-cell tint
	cell.set_highlight(BattleCellScript.HIGHLIGHT_ATTACK)
	if cell._highlight.visible:
		_fail("BattleCell: HIGHLIGHT_ATTACK should HIDE full-cell tint")
	else:
		_ok("BattleCell: HIGHLIGHT_ATTACK hides full-cell tint (border-only)")
	if not cell._highlight_border.visible:
		_fail("BattleCell: HIGHLIGHT_ATTACK should show border")
	else:
		_ok("BattleCell: HIGHLIGHT_ATTACK shows border frame")
	# Skill: same pattern
	cell.set_highlight(BattleCellScript.HIGHLIGHT_SKILL)
	if not cell._highlight_border.visible:
		_fail("BattleCell: HIGHLIGHT_SKILL should show border")
	else:
		_ok("BattleCell: HIGHLIGHT_SKILL shows border frame")
	# Clear
	cell.set_highlight(BattleCellScript.HIGHLIGHT_NONE)
	if cell._highlight.visible or cell._highlight_border.visible:
		_fail("BattleCell: HIGHLIGHT_NONE should hide both tint + border")
	else:
		_ok("BattleCell: HIGHLIGHT_NONE hides both")
	cell.queue_free()


func _test_battle_background_decor_assets() -> void:
	print("\n--- BattleBackground: decor scattering ---")
	var bg = BattleBackgroundScript.new()
	bg.name = "TestBG"
	root.add_child(bg)
	await process_frame
	# Each biome should populate decor from the new battle_decor folder.
	var biomes: Array = [
		"Ash Wastes", "Neon Bogs", "Ironwood Thicket", "Rust Canyons", "Stormspire Highlands",
	]
	for biome in biomes:
		bg.configure(biome, 7, Vector2(1280, 720))
		var count: int = bg._tile_layer.get_child_count()
		if count < 6:
			_fail("BattleBackground: %s scattered only %d props (expect >= 6)" % [biome, count])
		else:
			_ok("BattleBackground: %s scattered %d props" % [biome, count])
	bg.queue_free()


func _test_battle_unit_owns_name_plate_and_arrow() -> void:
	print("\n--- BattleUnit: owns name plate + selection arrow ---")
	var unit = BattleUnitScript.new()
	unit.name = "TestUnit"
	root.add_child(unit)
	await process_frame
	var data: Dictionary = {
		"id": "hero", "team": "player", "hp": 80, "max_hp": 80, "ct": 45, "facing": 0,
		"pos": Vector2i(2, 3), "race": "human", "gender": "male", "name": "TestHero",
	}
	unit.setup_from_data(data, 24)
	if unit._name_plate == null:
		_fail("BattleUnit: _name_plate not built")
	else:
		_ok("BattleUnit: _name_plate Control built (white-bg name label)")
	if unit._selection_arrow == null:
		_fail("BattleUnit: _selection_arrow not built")
	else:
		_ok("BattleUnit: _selection_arrow Node2D built (cyan down-arrow)")
	# Initially arrow is hidden
	if unit._selection_arrow.visible:
		_fail("BattleUnit: selection arrow should start hidden")
	else:
		_ok("BattleUnit: selection arrow starts hidden")
	# Activate
	unit.set_active(true)
	if not unit._selection_arrow.visible:
		_fail("BattleUnit: selection arrow should be visible when active")
	else:
		_ok("BattleUnit: selection arrow visible when active")
	# Nameplate is populated
	if unit._name_plate._label.text != "TestHero":
		_fail("BattleUnit: nameplate text wrong (got '%s')" % unit._name_plate._label.text)
	else:
		_ok("BattleUnit: nameplate text set to 'TestHero'")
	unit.queue_free()


func _test_pixellab_assets_exist() -> void:
	print("\n--- new battle assets present ---")
	for path in [
		"res://assets/battle_ui/selection_arrow.png",
		"res://assets/battle_ui/top_prompt_panel.png",
		"res://assets/battle_ui/name_plate_panel.png",
		"res://assets/battle_ui/button_red.png",
		"res://assets/battle_ui/button_blue.png",
		"res://assets/battle_ui/button_grey.png",
		"res://assets/battle_ui/button_gold.png",
		"res://assets/battle_decor/boulder/boulder_0.png",
		"res://assets/battle_decor/skull/skull_0.png",
		"res://assets/battle_decor/cactus/cactus_0.png",
		"res://assets/battle_decor/rubble/rubble_0.png",
		"res://assets/battle_decor/thorns/thorns_0.png",
		"res://assets/battle_decor/stump/stump_0.png",
		"res://assets/battle_decor/roots/roots_0.png",
	]:
		if not ResourceLoader.exists(path):
			_fail("missing asset: %s" % path)
		else:
			_ok("asset present: %s" % path.replace("res://", ""))


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
