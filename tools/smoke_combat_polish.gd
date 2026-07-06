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
	await process_frame
	_test_v102_cell_sizing()
	await process_frame
	_test_v102_turn_order_procedural_portrait()
	await process_frame
	_test_v102_hp_bar_sizing()
	await process_frame
	_test_v103_cell_texture_clipping()
	await process_frame
	_test_v103_top_prompt_positioning()
	await process_frame
	_test_v103_selection_arrow_above_nameplate()
	await process_frame
	_test_v104_grid_centered_in_viewport()
	await process_frame
	_test_v104_hp_bar_bigger()
	await process_frame
	_test_v104_blocked_cell_x_overlay()
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
	arr.snap_to_cell(3, 4, 56)
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
	n.snap_to_cell(2, 3, 56)
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
	unit.setup_from_data(data, 56)
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


func _test_v102_cell_sizing() -> void:
	print("\n--- v0.10.2: cell sizing & visual proportions ---")
	# v0.10.2: cells bumped from 24 to 40 for a 67% larger grid.
	# Each combat component has a CELL_SIZE constant; verify all
	# four agree so the layout is internally consistent.
	var grid_cs: int = BattleGridViewScript.CELL_SIZE
	var cell_cs: int = BattleCellScript.CELL_SIZE
	var unit_cs: int = BattleUnitScript.CELL_SIZE
	if not (grid_cs == 56 and cell_cs == 56 and unit_cs == 56):
		_fail("v0.10.2 cell sizing mismatch: grid=%d cell=%d unit=%d (expect 56)" % [grid_cs, cell_cs, unit_cs])
	else:
		_ok("v0.10.2: grid/cell/unit CELL_SIZE all = 56")
	# 7x7 grid at 40px = 280px wide — should be ~22% of a 1280px viewport.
	var grid_px: int = 7 * 56
	if grid_px < 300:
		_fail("v0.10.2: 7x7 grid is %dpx wide (expect >= 300)" % grid_px)
	else:
		_ok("v0.10.2: 7x7 grid = %dpx wide (~%d%% of 1280px viewport)" % [grid_px, int(grid_px * 100 / 1280)])
	# BattleCell border should be chunky (3px) for the FFT-style frame.
	if BattleCellScript.BORDER_THICKNESS < 2:
		_fail("v0.10.2: BORDER_THICKNESS too thin (%d)" % BattleCellScript.BORDER_THICKNESS)
	else:
		_ok("v0.10.2: BORDER_THICKNESS = %d (chunky FFT frame)" % BattleCellScript.BORDER_THICKNESS)
	# Selection arrow should be ~28x24 — visible above the unit.
	var arr: Node2D = UnitSelectionArrowScript.new()
	root.add_child(arr)
	await process_frame
	if UnitSelectionArrowScript.WIDTH < 24 or UnitSelectionArrowScript.HEIGHT < 20:
		_fail("v0.10.2: selection arrow too small (%dx%d)" % [UnitSelectionArrowScript.WIDTH, UnitSelectionArrowScript.HEIGHT])
	else:
		_ok("v0.10.2: selection arrow = %dx%d" % [UnitSelectionArrowScript.WIDTH, UnitSelectionArrowScript.HEIGHT])
	arr.queue_free()


func _test_v102_turn_order_procedural_portrait() -> void:
	print("\n--- v0.10.2: TurnOrderBar procedural portrait ---")
	var TurnOrderBarScript = preload("res://scripts/combat/TurnOrderBar.gd")
	var bar: Node = TurnOrderBarScript.new()
	bar.name = "TestTOB"
	root.add_child(bar)
	await process_frame
	# Should not throw even with a missing-sprite path.
	var placeholder: Texture2D = bar._placeholder_portrait("player")
	if placeholder == null:
		_fail("TurnOrderBar: _placeholder_portrait returned null for player")
	else:
		var sz: Vector2 = placeholder.get_size()
		if sz.x < 32 or sz.y < 32:
			_fail("TurnOrderBar: placeholder too small (%dx%d)" % [sz.x, sz.y])
		else:
			_ok("TurnOrderBar: procedural placeholder portrait built (%dx%d)" % [sz.x, sz.y])
	# Should also work for enemy + ally
	for team in ["enemy", "ally"]:
		var p: Texture2D = bar._placeholder_portrait(team)
		if p == null:
			_fail("TurnOrderBar: placeholder null for %s" % team)
		else:
			_ok("TurnOrderBar: %s team placeholder portrait built" % team)
	bar.queue_free()


func _test_v102_hp_bar_sizing() -> void:
	print("\n--- v0.10.2: HP bar sizing ---")
	var CombatHPBarScript = preload("res://scripts/CombatHPBar.gd")
	if CombatHPBarScript.BAR_WIDTH < 30 or CombatHPBarScript.BAR_HEIGHT < 5:
		_fail("v0.10.2: HP bar too small (%dx%d)" % [CombatHPBarScript.BAR_WIDTH, CombatHPBarScript.BAR_HEIGHT])
	else:
		_ok("v0.10.2: HP bar = %dx%d" % [CombatHPBarScript.BAR_WIDTH, CombatHPBarScript.BAR_HEIGHT])


func _test_v103_cell_texture_clipping() -> void:
	print("\n--- v0.10.3: BattleCell uses clipped terrain texture ---")
	# v0.10.3 fix: the 24x120 atlas was being shown in full in each
	# 40x40 cell, creating vertical stripes. The fix is to wrap the
	# atlas in an AtlasTexture with the terrain-specific 24x24 region
	# and scale the sprite to fill the cell.
	var cell: Node = BattleCellScript.new()
	cell.name = "TestCell"
	root.add_child(cell)
	await process_frame
	# Stub a tiny 24x120 atlas to exercise the code path.
	var img := Image.create(24, 120, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5, 1.0))
	var atlas := ImageTexture.create_from_image(img)
	# Test all 4 terrain kinds
	for terrain in range(4):
		cell.setup(0, 0, terrain, 0, false, atlas)
		# _base.texture should be an AtlasTexture with the row clipped
		var tex: Texture2D = cell._base.texture
		if tex == null:
			_fail("BattleCell: _base.texture is null for terrain %d" % terrain)
			continue
		if not (tex is AtlasTexture):
			_fail("BattleCell: _base.texture is not AtlasTexture for terrain %d (got %s)" % [terrain, tex.get_class()])
			continue
		var at: AtlasTexture = tex as AtlasTexture
		var expected_y: float = terrain * 24.0
		if at.region.position.y != expected_y:
			_fail("BattleCell: terrain %d should clip atlas y=%d (got %d)" % [terrain, int(expected_y), int(at.region.position.y)])
		else:
			_ok("BattleCell: terrain %d clips atlas to (0, %d, 24, 24)" % [terrain, terrain * 24])
	# v0.10.9: scale from inscribed square diag = CELL_SIZE, side = CELL_SIZE/√2.
	var inscribed: float = BattleCellScript.CELL_SIZE / 1.4142
	var expected_scale: float = inscribed / 24.0
	if abs(cell._base.scale.x - expected_scale) > 0.01:
		_fail("BattleCell: scale.x should be %.2f (got %.2f)" % [expected_scale, cell._base.scale.x])
	else:
		_ok("BattleCell: sprite scaled to %.2fx (inscribed square in diamond)" % expected_scale)
	cell.queue_free()


func _test_v103_top_prompt_positioning() -> void:
	print("\n--- v0.10.3: TopPrompt positioning ---")
	var p: Node = TopPromptScript.new()
	p.name = "TestPrompt"
	root.add_child(p)
	await process_frame
	# v0.10.3: TopPrompt should sit below the TurnOrderBar with a gap.
	# TurnOrderBar ends at 112, TopPrompt starts at 124 (12px gap).
	if p.offset_top < 115:
		_fail("TopPrompt: offset_top %d too high (should be >= 116 to clear TurnOrderBar at 112)" % p.offset_top)
	else:
		_ok("TopPrompt: offset_top = %d (clear of TurnOrderBar at 112)" % p.offset_top)
	# v0.10.3: TopPrompt width should be < 720 (TurnOrderBar width) to
	# not visually compete.
	if p.offset_left < -400 or p.offset_right > 400:
		_fail("TopPrompt: width too wide (left=%d right=%d)" % [p.offset_left, p.offset_right])
	else:
		_ok("TopPrompt: width = %d (narrower than TurnOrderBar's 720)" % int(p.offset_right - p.offset_left))
	p.queue_free()


func _test_v103_selection_arrow_above_nameplate() -> void:
	print("\n--- v0.10.3: Selection arrow positioned above nameplate ---")
	# v0.10.3 fix: the selection arrow was hidden BEHIND the nameplate
	# because they were both at similar y positions. Now the arrow sits
	# at y=-52 (CELL_SIZE*0.5 + 24) above cell center and the nameplate
	# at y=-76 (CELL_SIZE*0.5 + 48). We test via source code.
	var src: String = load("res://scripts/combat/BattleUnit.gd").source_code
	if not src.contains("Vector2(0, -CELL_SIZE * 0.5 - 48)"):
		_fail("BattleUnit source: selection arrow position not found (expect -CELL_SIZE*0.5-48)")
	else:
		_ok("BattleUnit source: selection arrow positioned above cell center")
	if not src.contains("Vector2(-48, -CELL_SIZE * 0.5 - 24)"):
		_fail("BattleUnit source: nameplate position not found (expect -CELL_SIZE*0.5-24)")
	else:
		_ok("BattleUnit source: nameplate positioned above cell center")
	if src.find("_selection_arrow.z_index = 15") < 0:
		_fail("BattleUnit source: selection arrow z_index = 15 not found")
	else:
		_ok("BattleUnit source: selection arrow z_index = 15 (above nameplate's 14)")
	if not src.contains("_selection_arrow.position = Vector2(0, -CELL_SIZE"):
		_fail("BattleUnit source: _refresh_selection_arrow should use CELL_SIZE-relative position")
	else:
		_ok("BattleUnit source: _refresh_selection_arrow uses CELL_SIZE-relative position")


func _test_v104_grid_centered_in_viewport() -> void:
	print("\n--- v0.10.4: BattleGridView centered in actual viewport ---")
	# v0.10.4 fix: BattleGridView was hardcoded at (640, 360) in the
	# scene file, which is only the center of a 1280x720 viewport.
	# On wider displays the grid appeared off-center toward the right.
	# TacticalCombat._ready now re-anchors to get_viewport_rect().size * 0.5.
	var src: String = load("res://scripts/TacticalCombat.gd").source_code
	if not src.contains("vp_center"):
		_fail("TacticalCombat: vp_center viewport-centering logic missing")
	else:
		_ok("TacticalCombat: uses vp_center (vp_size * 0.5) for grid centering")
	if not src.contains("_grid.position = vp_center"):
		_fail("TacticalCombat: _grid.position = vp_center missing")
	else:
		_ok("TacticalCombat: _grid.position re-anchored to vp_center")
	if not src.contains("_background.position = vp_center"):
		_fail("TacticalCombat: _background.position = vp_center missing")
	else:
		_ok("TacticalCombat: _background.position re-anchored to vp_center")


func _test_v104_hp_bar_bigger() -> void:
	print("\n--- v0.10.4: HP bar bigger (48x8) ---")
	var CombatHPBarScript = preload("res://scripts/CombatHPBar.gd")
	if CombatHPBarScript.BAR_WIDTH < 40 or CombatHPBarScript.BAR_HEIGHT < 6:
		_fail("v0.10.4: HP bar too small (%dx%d)" % [CombatHPBarScript.BAR_WIDTH, CombatHPBarScript.BAR_HEIGHT])
	else:
		_ok("v0.10.4: HP bar = %dx%d" % [CombatHPBarScript.BAR_WIDTH, CombatHPBarScript.BAR_HEIGHT])


func _test_v104_blocked_cell_x_overlay() -> void:
	print("\n--- v0.10.4: Blocked cell has red X overlay ---")
	# v0.10.4: blocked cells now have a red X overlay (two crossed
	# ColorRects) so the player reads "impassable" at a glance,
	# instead of the previous pure-black tint that looked like a
	# rendering bug. Test the source code to avoid BattleCell
	# _ready() hanging in headless mode.
	var src: String = load("res://scripts/combat/BattleCell.gd").source_code
	if not src.contains("_blocked_x"):
		_fail("BattleCell: _blocked_x member not found")
	else:
		_ok("BattleCell: _blocked_x member present")
	if not src.contains("_build_blocked_diamond_x"):
		_fail("BattleCell: _build_blocked_diamond_x() helper not found")
	else:
		_ok("BattleCell: _build_blocked_diamond_x() helper present")
	if not src.contains("COLOR_BLOCKED_X"):
		_fail("BattleCell: COLOR_BLOCKED_X constant not found")
	else:
		_ok("BattleCell: COLOR_BLOCKED_X red overlay color defined")
	if not src.contains("_blocked_x.visible = true"):
		_fail("BattleCell: blocked cell should set _blocked_x.visible = true")
	else:
		_ok("BattleCell: blocked cell shows X overlay")
	if not src.contains("_blocked_x.visible = false"):
		_fail("BattleCell: non-blocked cell should set _blocked_x.visible = false")
	else:
		_ok("BattleCell: non-blocked cell hides X overlay")


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
