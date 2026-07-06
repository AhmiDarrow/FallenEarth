extends SceneTree
## Quick F5-style boot test for the TacticalCombat scene.
## Instantiates the scene with a real (fallback) encounter and ticks
## 30 frames. Verifies the scene + all new components wire up
## cleanly and no script errors are raised.

const BattleBackgroundScript = preload("res://scripts/combat/BattleBackground.gd")
const BattleGridViewScript = preload("res://scripts/combat/BattleGridView.gd")
const BattleUnitScript = preload("res://scripts/combat/BattleUnit.gd")
const UnitSelectionArrowScript = preload("res://scripts/combat/UnitSelectionArrow.gd")
const UnitNamePlateScript = preload("res://scripts/combat/UnitNamePlate.gd")
const TopPromptScript = preload("res://scripts/combat/TopPrompt.gd")

var failures: Array[String] = []


func _initialize() -> void:
	print("[boot-combat] TacticalCombat F5-style boot test")
	await process_frame
	var packed: PackedScene = load("res://scenes/TacticalCombat.tscn") as PackedScene
	if packed == null:
		failures.append("TacticalCombat.tscn failed to load")
		_print_summary()
		quit()
		return
	var instance: Node = packed.instantiate()
	if instance == null:
		failures.append("TacticalCombat.tscn failed to instantiate")
		_print_summary()
		quit()
		return
	root.add_child(instance)
	# The TacticalCombat _ready() loads the encounter from
	# /root/GameState. In headless mode that may not be set, but
	# the script builds a fallback encounter. Either way, tick
	# enough frames to wire up all the new HUD components.
	for i in range(30):
		await process_frame
	# Verify key components are present
	var found: Array[String] = []
	if instance.has_node("BattleBackgroundLayer/BattleBackground"):
		found.append("BattleBackground")
	if instance.has_node("BattleLayer/BattleGridView"):
		found.append("BattleGridView")
	if instance.has_node("HUDLayer/TurnOrderBar"):
		found.append("TurnOrderBar")
	if instance.has_node("HUDLayer/UnitInfoCard"):
		found.append("UnitInfoCard")
	if instance.has_node("HUDLayer/SkillBar"):
		found.append("SkillBar")
	if instance.has_node("HUDLayer/TopPrompt"):
		found.append("TopPrompt")
	if instance.has_node("HUDLayer/BattleResultPanel"):
		found.append("BattleResultPanel")
	if instance.has_node("HUDLayer/TargetingReticle"):
		found.append("TargetingReticle")
	for expected in ["BattleBackground", "BattleGridView", "TurnOrderBar", "UnitInfoCard", "SkillBar", "TopPrompt", "BattleResultPanel", "TargetingReticle"]:
		if expected not in found:
			failures.append("TacticalCombat: %s child missing" % expected)
		else:
			print("  ok  TacticalCombat: %s present" % expected)
	# Verify the BattleGridView has units (the player + the enemy).
	var grid: Node = instance.get_node_or_null("BattleLayer/BattleGridView")
	if grid != null:
		var units: Array = grid.get_all_units()
		if units.size() < 1:
			failures.append("TacticalCombat: BattleGridView has 0 units")
		else:
			print("  ok  TacticalCombat: %d unit(s) on grid" % units.size())
			# Each unit should have a name plate and selection arrow
			var all_have_plates: bool = true
			for bu in units:
				if bu._name_plate == null:
					failures.append("BattleUnit %s: missing _name_plate" % bu.unit_id)
					all_have_plates = false
				if bu._selection_arrow == null:
					failures.append("BattleUnit %s: missing _selection_arrow" % bu.unit_id)
					all_have_plates = false
			if all_have_plates:
				print("  ok  All %d units have name plate + selection arrow" % units.size())
	# Verify the BattleBackground scattered decor
	var bg: Node = instance.get_node_or_null("BattleBackgroundLayer/BattleBackground")
	if bg != null:
		var decor: int = bg._tile_layer.get_child_count()
		if decor < 6:
			failures.append("BattleBackground: only %d decor scattered" % decor)
		else:
			print("  ok  BattleBackground: %d decor scattered" % decor)
	# Tick more frames to let tweens + signals settle
	for i in range(30):
		await process_frame
	print("[boot-combat] 60 frames observed.")
	_print_summary()
	quit()


func _fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)


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
