extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	print("=== Combat Feedback Smoke Test ===")
	_test_floating_damage_script()
	_test_combat_hp_bar_script()
	_test_combat_feedback_script()
	_test_validate_scripts()
	_print_summary()
	quit()


func _test_floating_damage_script() -> void:
	print("\n--- Test: FloatingDamage script ---")
	var script: GDScript = load("res://scripts/FloatingDamage.gd") as GDScript
	if script == null:
		_fail("Could not load FloatingDamage.gd")
		return
	# Check key constants
	var source: String = script.source_code
	if not source.contains("DURATION"):
		_fail("Missing DURATION constant")
		return
	if not source.contains("COLOR_PHYSICAL"):
		_fail("Missing COLOR_PHYSICAL constant")
		return
	if not source.contains("COLOR_HEAL"):
		_fail("Missing COLOR_HEAL constant")
		return
	_pass("FloatingDamage script OK")


func _test_combat_hp_bar_script() -> void:
	print("\n--- Test: CombatHPBar script ---")
	var script: GDScript = load("res://scripts/CombatHPBar.gd") as GDScript
	if script == null:
		_fail("Could not load CombatHPBar.gd")
		return
	# Check key constants
	var source: String = script.source_code
	if not source.contains("BAR_WIDTH"):
		_fail("Missing BAR_WIDTH constant")
		return
	if not source.contains("COLOR_PLAYER"):
		_fail("Missing COLOR_PLAYER constant")
		return
	if not source.contains("COLOR_ENEMY"):
		_fail("Missing COLOR_ENEMY constant")
		return
	_pass("CombatHPBar script OK")


func _test_combat_feedback_script() -> void:
	print("\n--- Test: CombatFeedback script ---")
	var script: GDScript = load("res://scripts/CombatFeedback.gd") as GDScript
	if script == null:
		_fail("Could not load CombatFeedback.gd")
		return
	# Check key constants
	var source: String = script.source_code
	if not source.contains("MAX_FLOATING"):
		_fail("Missing MAX_FLOATING constant")
		return
	if not source.contains("FloatingDamageScript"):
		_fail("Missing FloatingDamageScript preload")
		return
	if not source.contains("CombatHPBarScript"):
		_fail("Missing CombatHPBarScript preload")
		return
	# Check methods
	if not source.contains("func setup("):
		_fail("Missing setup method")
		return
	if not source.contains("func setup_hp_bars("):
		_fail("Missing setup_hp_bars method")
		return
	if not source.contains("func get_kill_count("):
		_fail("Missing get_kill_count method")
		return
	_pass("CombatFeedback script OK")


func _test_validate_scripts() -> void:
	print("\n--- Test: validate_scripts includes new files ---")
	var script: GDScript = load("res://validate_scripts.gd") as GDScript
	if script == null:
		_fail("Could not load validate_scripts.gd")
		return
	var source: String = script.source_code
	if not source.contains("FloatingDamage.gd"):
		_fail("validate_scripts missing FloatingDamage.gd")
		return
	if not source.contains("CombatHPBar.gd"):
		_fail("validate_scripts missing CombatHPBar.gd")
		return
	if not source.contains("CombatFeedback.gd"):
		_fail("validate_scripts missing CombatFeedback.gd")
		return
	_pass("validate_scripts includes new files")


func _pass(test_name: String) -> void:
	print("ok %s" % test_name)


func _fail(test_name: String) -> void:
	print("FAIL %s" % test_name)
	_failures.append(test_name)


func _print_summary() -> void:
	print("\n=== Summary ===")
	if _failures.is_empty():
		print("All checks passed. (failures.size=0)")
	else:
		print("Some checks failed. (failures.size=%d)" % _failures.size())
		for f in _failures:
			print("  FAILED: %s" % f)
