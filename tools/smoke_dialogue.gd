extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	print("=== Dialogue System Smoke Test ===")
	_test_dialogue_loads()
	_test_dialogue_resolution()
	_test_dialogue_effects()
	_test_dialogue_ui_scene()
	_test_settlement_interior_integration()
	_print_summary()
	quit()


func _test_dialogue_loads() -> void:
	print("\n--- Test: Dialogue JSON loads ---")
	var file: FileAccess = FileAccess.open("res://data/dialogue.json", FileAccess.READ)
	if file == null:
		_fail("Could not open dialogue.json")
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		_fail("dialogue.json root is not Dictionary")
		return
	var dialogues: Dictionary = parsed.get("dialogues", {})
	if dialogues.is_empty():
		_fail("No dialogue trees found")
		return
	if not dialogues.has("trader"):
		_fail("Missing trader dialogue")
		return
	var trader: Dictionary = dialogues["trader"]
	if not trader.has("greeting"):
		_fail("Trader missing greeting")
		return
	_pass("Dialogue JSON loads correctly")


func _test_dialogue_resolution() -> void:
	print("\n--- Test: Dialogue resolution ---")
	var file: FileAccess = FileAccess.open("res://data/dialogue.json", FileAccess.READ)
	if file == null:
		_fail("Could not open dialogue.json")
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	var dialogues: Dictionary = parsed.get("dialogues", {})
	var trader: Dictionary = dialogues.get("trader", {})
	var greeting: Dictionary = trader.get("greeting", {})
	var choices: Array = greeting.get("choices", [])
	if choices.is_empty():
		_fail("No choices in greeting")
		return
	var first_choice: Dictionary = choices[0]
	var next_id: String = str(first_choice.get("next", ""))
	if next_id.is_empty():
		_fail("First choice has no next")
		return
	var next_node: Dictionary = trader.get(next_id, {})
	if next_node.is_empty():
		_fail("Could not resolve to '%s'" % next_id)
		return
	_pass("Dialogue resolution works")


func _test_dialogue_effects() -> void:
	print("\n--- Test: Dialogue effects ---")
	var file: FileAccess = FileAccess.open("res://data/dialogue.json", FileAccess.READ)
	if file == null:
		_fail("Could not open dialogue.json")
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	var dialogues: Dictionary = parsed.get("dialogues", {})
	var innkeeper: Dictionary = dialogues.get("innkeeper", {})
	var rift_rumor: Dictionary = innkeeper.get("rift_rumor", {})
	var effects: Dictionary = rift_rumor.get("effects", {})
	var rep: Dictionary = effects.get("reputation", {})
	if not rep.has("echo_wardens"):
		_fail("rift_rumor missing echo_wardens rep effect")
		return
	var amount: int = int(rep["echo_wardens"])
	if amount != 1:
		_fail("Expected echo_wardens rep=1, got %d" % amount)
		return
	_pass("Dialogue effects defined correctly")


func _test_dialogue_ui_scene() -> void:
	print("\n--- Test: DialogueUI scene loads ---")
	if not ResourceLoader.exists("res://scenes/DialogueUI.tscn"):
		_fail("DialogueUI.tscn not found")
		return
	var packed: PackedScene = load("res://scenes/DialogueUI.tscn") as PackedScene
	if packed == null:
		_fail("Could not load DialogueUI.tscn")
		return
	_pass("DialogueUI scene loads")


func _test_settlement_interior_integration() -> void:
	print("\n--- Test: SettlementInterior integration ---")
	var script: GDScript = load("res://scripts/SettlementInterior.gd") as GDScript
	if script == null:
		_fail("Could not load SettlementInterior.gd")
		return
	# Check that _open_dialogue_ui method exists by looking at source
	var source: String = script.source_code
	if not source.contains("_open_dialogue_ui"):
		_fail("SettlementInterior missing _open_dialogue_ui method")
		return
	if not source.contains("DialogueManager"):
		_fail("SettlementInterior not referencing DialogueManager")
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
