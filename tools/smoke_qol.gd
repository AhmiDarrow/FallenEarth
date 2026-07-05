extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	print("=== QoL Smoke Test ===")
	_test_minimap_overhaul_script()
	_test_options_menu_script()
	_test_options_menu_scene()
	_test_validate_scripts()
	_print_summary()
	quit()


func _test_minimap_overhaul_script() -> void:
	print("\n--- Test: MinimapOverhaul script ---")
	var script: GDScript = load("res://scripts/ui/MinimapOverhaul.gd") as GDScript
	if script == null:
		_fail("Could not load MinimapOverhaul.gd")
		return
	var source: String = script.source_code
	if not source.contains("SIZE"):
		_fail("Missing SIZE constant")
		return
	if not source.contains("PLAYER_COLOR"):
		_fail("Missing PLAYER_COLOR constant")
		return
	if not source.contains("NPC_COLOR"):
		_fail("Missing NPC_COLOR constant")
		return
	if not source.contains("BUILDING_COLOR"):
		_fail("Missing BUILDING_COLOR constant")
		return
	if not source.contains("func update_data("):
		_fail("Missing update_data method")
		return
	_pass("MinimapOverhaul script OK")


func _test_options_menu_script() -> void:
	print("\n--- Test: OptionsMenu script ---")
	var script: GDScript = load("res://scripts/ui/OptionsMenu.gd") as GDScript
	if script == null:
		_fail("Could not load OptionsMenu.gd")
		return
	var source: String = script.source_code
	if not source.contains("SETTINGS_PATH"):
		_fail("Missing SETTINGS_PATH constant")
		return
	if not source.contains("_music_slider"):
		_fail("Missing _music_slider variable")
		return
	if not source.contains("_sfx_slider"):
		_fail("Missing _sfx_slider variable")
		return
	if not source.contains("_fullscreen_check"):
		_fail("Missing _fullscreen_check variable")
		return
	if not source.contains("func _save_settings("):
		_fail("Missing _save_settings method")
		return
	if not source.contains("func _load_settings("):
		_fail("Missing _load_settings method")
		return
	_pass("OptionsMenu script OK")


func _test_options_menu_scene() -> void:
	print("\n--- Test: OptionsMenu scene loads ---")
	if not ResourceLoader.exists("res://scenes/ui/OptionsMenu.tscn"):
		_fail("OptionsMenu.tscn not found")
		return
	var packed: PackedScene = load("res://scenes/ui/OptionsMenu.tscn") as PackedScene
	if packed == null:
		_fail("Could not load OptionsMenu.tscn")
		return
	_pass("OptionsMenu scene loads")


func _test_validate_scripts() -> void:
	print("\n--- Test: validate_scripts includes new files ---")
	var script: GDScript = load("res://validate_scripts.gd") as GDScript
	if script == null:
		_fail("Could not load validate_scripts.gd")
		return
	var source: String = script.source_code
	if not source.contains("MinimapOverhaul.gd"):
		_fail("validate_scripts missing MinimapOverhaul.gd")
		return
	if not source.contains("OptionsMenu.gd"):
		_fail("validate_scripts missing OptionsMenu.gd")
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
