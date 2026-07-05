extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	print("=== Quest Tracker Smoke Test ===")
	_test_quest_tracker_creation()
	_test_quest_tracker_add_mission()
	_test_quest_tracker_update_objective()
	_test_quest_tracker_signals()
	_test_quest_tracker_ui_scene()
	_print_summary()
	quit()


func _test_quest_tracker_creation() -> void:
	print("\n--- Test: QuestTracker creation ---")
	var script: GDScript = load("res://scripts/QuestTracker.gd") as GDScript
	if script == null:
		_fail("Could not load QuestTracker.gd")
		return
	var tracker = script.new()
	if tracker == null:
		_fail("Could not create QuestTracker instance")
		return
	if tracker.get_mission_count() != 0:
		_fail("Expected 0 missions, got %d" % tracker.get_mission_count())
		return
	_pass("QuestTracker creation works")


func _test_quest_tracker_add_mission() -> void:
	print("\n--- Test: QuestTracker add mission ---")
	var script: GDScript = load("res://scripts/QuestTracker.gd") as GDScript
	var tracker = script.new()
	var mission: Dictionary = {
		"mission_id": "test_mission_1",
		"title": "Test Mission",
		"objectives": [
			{"description": "Kill 5 rats", "target": 5, "current": 0}
		],
		"rewards": {"xp": 100, "ec": 50}
	}
	tracker.add_mission(mission)
	if tracker.get_mission_count() != 1:
		_fail("Expected 1 mission, got %d" % tracker.get_mission_count())
		return
	var stored: Dictionary = tracker.get_mission("test_mission_1")
	if stored.is_empty():
		_fail("Could not retrieve mission")
		return
	if str(stored.get("title", "")) != "Test Mission":
		_fail("Expected title 'Test Mission', got '%s'" % str(stored.get("title", "")))
		return
	_pass("QuestTracker add mission works")


func _test_quest_tracker_update_objective() -> void:
	print("\n--- Test: QuestTracker update objective ---")
	var script: GDScript = load("res://scripts/QuestTracker.gd") as GDScript
	var tracker = script.new()
	var mission: Dictionary = {
		"mission_id": "test_mission_2",
		"title": "Kill Rats",
		"objectives": [
			{"description": "Kill 5 rats", "target": 5, "current": 0}
		],
		"rewards": {"xp": 100}
	}
	tracker.add_mission(mission)
	# Update progress
	tracker.update_objective("test_mission_2", 0, 3)
	var stored: Dictionary = tracker.get_mission("test_mission_2")
	var obj: Dictionary = stored.get("objectives", [{}])[0]
	if int(obj.get("current", 0)) != 3:
		_fail("Expected current=3, got %d" % int(obj.get("current", 0)))
		return
	# Complete the mission
	tracker.update_objective("test_mission_2", 0, 5)
	if tracker.has_mission("test_mission_2"):
		# Mission should still be there (completion is via signal)
		pass
	_pass("QuestTracker update objective works")


func _test_quest_tracker_signals() -> void:
	print("\n--- Test: QuestTracker signals ---")
	var script: GDScript = load("res://scripts/QuestTracker.gd") as GDScript
	if script == null:
		_fail("Could not load QuestTracker.gd")
		return
	# Check signals in source code
	var source: String = script.source_code
	if not source.contains("signal mission_added"):
		_fail("Missing mission_added signal")
		return
	if not source.contains("signal mission_removed"):
		_fail("Missing mission_removed signal")
		return
	if not source.contains("signal objective_updated"):
		_fail("Missing objective_updated signal")
		return
	if not source.contains("signal mission_completed"):
		_fail("Missing mission_completed signal")
		return
	_pass("QuestTracker signals defined")


func _test_quest_tracker_ui_scene() -> void:
	print("\n--- Test: QuestTrackerUI scene loads ---")
	if not ResourceLoader.exists("res://scenes/QuestTrackerUI.tscn"):
		_fail("QuestTrackerUI.tscn not found")
		return
	var packed: PackedScene = load("res://scenes/QuestTrackerUI.tscn") as PackedScene
	if packed == null:
		_fail("Could not load QuestTrackerUI.tscn")
		return
	_pass("QuestTrackerUI scene loads")


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
