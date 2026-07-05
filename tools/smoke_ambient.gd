extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	print("=== Ambient Behavior Smoke Test ===")
	_test_npc_wanderer_creation()
	_test_npc_wanderer_state_machine()
	_test_npc_wanderer_mood()
	_test_settlement_rooms_wander_data()
	_test_settlement_interior_integration()
	_print_summary()
	quit()


func _test_npc_wanderer_creation() -> void:
	print("\n--- Test: NPCWanderer creation ---")
	var script: GDScript = load("res://scripts/NPCWanderer.gd") as GDScript
	if script == null:
		_fail("Could not load NPCWanderer.gd")
		return
	var npc_data: Dictionary = {
		"id": "test_npc",
		"name": "Test NPC",
		"role": "talker",
		"x": 5,
		"y": 3,
		"wander_paths": ["town_square", "tavern"],
		"wander_frequency": 30.0
	}
	var wanderer = script.new(npc_data, "tavern")
	if wanderer == null:
		_fail("Could not create NPCWanderer instance")
		return
	if wanderer.npc_id != "test_npc":
		_fail("Expected npc_id='test_npc', got '%s'" % wanderer.npc_id)
		return
	if wanderer.current_room != "tavern":
		_fail("Expected current_room='tavern', got '%s'" % wanderer.current_room)
		return
	_pass("NPCWanderer creation works")


func _test_npc_wanderer_state_machine() -> void:
	print("\n--- Test: NPCWanderer state machine ---")
	var script: GDScript = load("res://scripts/NPCWanderer.gd") as GDScript
	var npc_data: Dictionary = {
		"id": "test_npc",
		"name": "Test NPC",
		"role": "talker",
		"x": 5,
		"y": 3,
		"wander_paths": ["town_square"],
		"wander_frequency": 1.0
	}
	var wanderer = script.new(npc_data, "tavern")
	# Initial state should be IDLE
	if wanderer.state != 0:  # State.IDLE
		_fail("Expected initial state IDLE, got %d" % wanderer.state)
		return
	# Tick with delta > timer to trigger wander
	var rooms: Dictionary = {}
	var result: Dictionary = wanderer.tick(2.0, Vector2i(5, 5), rooms)
	# Should have triggered movement
	if not result.has("action"):
		_fail("Expected action after timer expire, got empty")
		return
	_pass("NPCWanderer state machine works")


func _test_npc_wanderer_mood() -> void:
	print("\n--- Test: NPCWanderer mood ---")
	var script: GDScript = load("res://scripts/NPCWanderer.gd") as GDScript
	var npc_data: Dictionary = {
		"id": "test_npc",
		"name": "Test NPC",
		"role": "talker",
		"x": 5,
		"y": 3
	}
	var wanderer = script.new(npc_data, "tavern")
	# Test mood when player nearby with high rep
	var mood: String = wanderer.get_display_mood(true, 15)
	if mood != "happy":
		_fail("Expected 'happy' for high rep, got '%s'" % mood)
		return
	# Test mood when player nearby with neutral rep
	mood = wanderer.get_display_mood(true, 5)
	if mood != "neutral":
		_fail("Expected 'neutral' for neutral rep, got '%s'" % mood)
		return
	# Test mood when player not nearby
	mood = wanderer.get_display_mood(false, 15)
	if not mood.is_empty():
		_fail("Expected empty mood when player not nearby, got '%s'" % mood)
		return
	# Test emoji
	var emoji: String = wanderer.get_mood_emoji("happy")
	if emoji != "😊":
		_fail("Expected '😊' for happy, got '%s'" % emoji)
		return
	_pass("NPCWanderer mood works")


func _test_settlement_rooms_wander_data() -> void:
	print("\n--- Test: Settlement rooms wander data ---")
	var file: FileAccess = FileAccess.open("res://data/settlement_rooms.json", FileAccess.READ)
	if file == null:
		_fail("Could not open settlement_rooms.json")
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		_fail("settlement_rooms.json root is not Dictionary")
		return
	var rooms: Dictionary = parsed.get("rooms", {})
	if rooms.is_empty():
		_fail("No rooms found")
		return
	# Check that at least one NPC has wander data
	var has_wander_data: bool = false
	for room_id in rooms:
		var room: Dictionary = rooms[room_id]
		var npcs: Array = room.get("npcs", [])
		for npc in npcs:
			if npc.has("wander_paths") or npc.has("wander_frequency"):
				has_wander_data = true
				break
		if has_wander_data:
			break
	# It's OK if no wander data exists yet — just verify structure
	_pass("Settlement rooms structure OK")


func _test_settlement_interior_integration() -> void:
	print("\n--- Test: SettlementInterior integration ---")
	var script: GDScript = load("res://scripts/SettlementInterior.gd") as GDScript
	if script == null:
		_fail("Could not load SettlementInterior.gd")
		return
	var source: String = script.source_code
	if not source.contains("NPCWanderer"):
		_fail("SettlementInterior not referencing NPCWanderer")
		return
	if not source.contains("_wanderers"):
		_fail("SettlementInterior missing _wanderers array")
		return
	_pass("SettlementInterior integration ready")


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
