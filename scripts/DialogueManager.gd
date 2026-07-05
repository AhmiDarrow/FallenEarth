## DialogueManager — Loads and manages branching dialogue trees.
##
## Singleton autoload that resolves NPC dialogue by role, tracks choices,
## and applies effects (reputation changes, item grants, etc.).
extends Node

const DIALOGUE_PATH := "res://data/dialogue.json"

var _dialogues: Dictionary = {}
var _faction_rep: Dictionary = {}


func _ready() -> void:
	_load_dialogues()
	_load_faction_rep()


func _load_dialogues() -> void:
	var file: FileAccess = FileAccess.open(DIALOGUE_PATH, FileAccess.READ)
	if file == null:
		push_error("[DialogueManager] Could not open %s" % DIALOGUE_PATH)
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("[DialogueManager] dialogue.json root is not Dictionary")
		return
	_dialogues = parsed.get("dialogues", {})
	print("[DialogueManager] Loaded %d dialogue trees" % _dialogues.size())


func _load_faction_rep() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("get_faction_rep"):
		_faction_rep = gs.get_faction_rep()
	if _faction_rep.is_empty():
		_faction_rep = {}


func get_dialogue_for_role(role: String) -> Dictionary:
	if _dialogues.has(role):
		var tree: Dictionary = _dialogues[role]
		if tree.has("greeting"):
			return tree["greeting"]
	return {}


func get_dialogue_node(role: String, node_id: String) -> Dictionary:
	if _dialogues.has(role):
		var tree: Dictionary = _dialogues[role]
		if tree.has(node_id):
			return tree[node_id]
	return {}


func resolve_choice(role: String, current_id: String, choice_index: int) -> Dictionary:
	var node: Dictionary = get_dialogue_node(role, current_id)
	if node.is_empty():
		return {}
	var choices: Array = node.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return {}
	var choice: Dictionary = choices[choice_index]
	var next_id: String = str(choice.get("next", ""))
	if next_id.is_empty():
		return {}
	var next_node: Dictionary = get_dialogue_node(role, next_id)
	if next_node.is_empty():
		return {}
	# Apply effects from the choice
	_apply_effects(choice.get("effects", {}))
	return next_node


func apply_node_effects(role: String, node_id: String) -> void:
	var node: Dictionary = get_dialogue_node(role, node_id)
	if node.is_empty():
		return
	_apply_effects(node.get("effects", {}))


func _apply_effects(effects: Dictionary) -> void:
	if effects.is_empty():
		return
	# Reputation changes
	var rep_changes: Dictionary = effects.get("reputation", {})
	for faction_key in rep_changes:
		var amount: int = int(rep_changes[faction_key])
		if amount != 0:
			_change_faction_rep(faction_key, amount)
	# EC changes
	var remove_ec: int = int(effects.get("remove_ec", 0))
	if remove_ec > 0:
		var inv: Node = get_node_or_null("/root/InventoryManager")
		if inv != null and inv.has_method("remove_item"):
			inv.remove_item("ec", remove_ec)
	# Heal
	var heal_full: bool = effects.get("heal_full", false)
	if heal_full:
		var pm: Node = get_node_or_null("/root/ProgressionManager")
		if pm != null:
			pm.set("hp", pm.get("max_hp"))


func _change_faction_rep(faction_key: String, amount: int) -> void:
	if not _faction_rep.has(faction_key):
		_faction_rep[faction_key] = 0
	_faction_rep[faction_key] = int(_faction_rep[faction_key]) + amount
	# Sync to GameState
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("set_faction_rep"):
		gs.set_faction_rep(faction_key, _faction_rep[faction_key])
	print("[DialogueManager] %s reputation: %d (%+d)" % [faction_key, _faction_rep[faction_key], amount])


func get_faction_rep(faction_key: String) -> int:
	return int(_faction_rep.get(faction_key, 0))


func has_role_dialogue(role: String) -> bool:
	return _dialogues.has(role)


func get_available_roles() -> Array:
	return _dialogues.keys()
