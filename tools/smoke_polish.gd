extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	print("=== Polish Smoke Test ===")
	_test_transition_screen_script()
	_test_transition_screen_scene()
	_test_loading_tips_script()
	_test_tips_json()
	_test_ambient_audio_script()
	_test_music_manager_script()
	_test_validate_scripts()
	_print_summary()
	quit()


func _test_transition_screen_script() -> void:
	print("\n--- Test: TransitionScreen script ---")
	var script: GDScript = load("res://scripts/TransitionScreen.gd") as GDScript
	if script == null:
		_fail("Could not load TransitionScreen.gd")
		return
	var source: String = script.source_code
	if not source.contains("func fade_out("):
		_fail("Missing fade_out method")
		return
	if not source.contains("func fade_in("):
		_fail("Missing fade_in method")
		return
	if not source.contains("func transition_scene("):
		_fail("Missing transition_scene method")
		return
	if not source.contains("var _rect"):
		_fail("Missing _rect variable")
		return
	_pass("TransitionScreen script OK")


func _test_transition_screen_scene() -> void:
	print("\n--- Test: TransitionScreen scene loads ---")
	if not ResourceLoader.exists("res://scenes/TransitionScreen.tscn"):
		_fail("TransitionScreen.tscn not found")
		return
	var packed: PackedScene = load("res://scenes/TransitionScreen.tscn") as PackedScene
	if packed == null:
		_fail("Could not load TransitionScreen.tscn")
		return
	_pass("TransitionScreen scene loads")


func _test_loading_tips_script() -> void:
	print("\n--- Test: LoadingTips script ---")
	var script: GDScript = load("res://scripts/LoadingTips.gd") as GDScript
	if script == null:
		_fail("Could not load LoadingTips.gd")
		return
	var source: String = script.source_code
	if not source.contains("func get_random_tip("):
		_fail("Missing get_random_tip method")
		return
	if not source.contains("func get_tip_count("):
		_fail("Missing get_tip_count method")
		return
	if not source.contains("tips.json"):
		_fail("Missing tips.json reference")
		return
	_pass("LoadingTips script OK")


func _test_tips_json() -> void:
	print("\n--- Test: data/tips.json valid ---")
	if not FileAccess.file_exists("res://data/tips.json"):
		_fail("data/tips.json not found")
		return
	var file := FileAccess.open("res://data/tips.json", FileAccess.READ)
	if file == null:
		_fail("Could not open data/tips.json")
		return
	var json := JSON.new()
	var err: Error = json.parse(file.get_as_text())
	if err != OK:
		_fail("JSON parse error: %s" % json.get_error_message())
		return
	var data: Variant = json.data
	if not data is Dictionary:
		_fail("Invalid JSON format")
		return
	var tips: Variant = (data as Dictionary).get("tips", [])
	if not tips is Array:
		_fail("Missing 'tips' array")
		return
	if (tips as Array).size() < 10:
		_fail("Expected at least 10 tips, got %d" % (tips as Array).size())
		return
	_pass("data/tips.json valid (%d tips)" % (tips as Array).size())


func _test_ambient_audio_script() -> void:
	print("\n--- Test: AmbientAudio script ---")
	var script: GDScript = load("res://scripts/AmbientAudio.gd") as GDScript
	if script == null:
		_fail("Could not load AmbientAudio.gd")
		return
	var source: String = script.source_code
	if not source.contains("func play_biome("):
		_fail("Missing play_biome method")
		return
	if not source.contains("func stop_all("):
		_fail("Missing stop_all method")
		return
	if not source.contains("func set_volume("):
		_fail("Missing set_volume method")
		return
	if not source.contains("_biome_sounds"):
		_fail("Missing _biome_sounds dictionary")
		return
	_pass("AmbientAudio script OK")


func _test_music_manager_script() -> void:
	print("\n--- Test: MusicManager script ---")
	var script: GDScript = load("res://scripts/MusicManager.gd") as GDScript
	if script == null:
		_fail("Could not load MusicManager.gd")
		return
	var source: String = script.source_code
	if not source.contains("func play_track("):
		_fail("Missing play_track method")
		return
	if not source.contains("func stop("):
		_fail("Missing stop method")
		return
	if not source.contains("func set_volume("):
		_fail("Missing set_volume method")
		return
	if not source.contains("_tracks"):
		_fail("Missing _tracks dictionary")
		return
	_pass("MusicManager script OK")


func _test_validate_scripts() -> void:
	print("\n--- Test: validate_scripts includes new files ---")
	var script: GDScript = load("res://validate_scripts.gd") as GDScript
	if script == null:
		_fail("Could not load validate_scripts.gd")
		return
	var source: String = script.source_code
	if not source.contains("TransitionScreen.gd"):
		_fail("validate_scripts missing TransitionScreen.gd")
		return
	if not source.contains("LoadingTips.gd"):
		_fail("validate_scripts missing LoadingTips.gd")
		return
	if not source.contains("AmbientAudio.gd"):
		_fail("validate_scripts missing AmbientAudio.gd")
		return
	if not source.contains("MusicManager.gd"):
		_fail("validate_scripts missing MusicManager.gd")
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
