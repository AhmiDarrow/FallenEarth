## DialogueUI — Modal dialogue panel for NPC conversations.
##
## Shows portrait area, speaker name, dialogue text, and choice buttons.
## Handles branching navigation and action callbacks (shop, mission board, etc.).
class_name DialogueUI
extends Control


signal dialogue_finished
signal choice_made(choice_index: int)
signal action_triggered(action: String)
signal invite_requested(npc_id: String)

const PORTRAIT_RACE_MAP := {
	"ai": "sentientai",
}

var _role: String = ""
var _current_node: Dictionary = {}
var _npc_name: String = ""
var _npc_race: String = ""
var _npc_gender: String = ""
var _npc_id: String = ""

var _panel: PanelContainer = null
var _speaker_label: Label = null
var _text_label: RichTextLabel = null
var _choices_container: VBoxContainer = null
var _close_button: Button = null
var _invite_button: Button = null

var _npc_portrait: TextureRect = null
var _player_portrait: TextureRect = null

const MT = preload("res://assets/ui/MasterTheme.gd")
const UH = preload("res://scripts/ui/UIHelper.gd")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	visible = false


func _build_ui() -> void:
	var backdrop := UH.make_backdrop()
	backdrop.name = "Backdrop"
	add_child(backdrop)

	# Panel container (centered at bottom)
	_panel = UH.make_surface_panel()
	_panel.name = "Panel"
	_panel.offset_left = 60
	_panel.offset_right = -60
	_panel.offset_top = -160
	_panel.offset_bottom = -20
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var margin := UH.make_margin(12)
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margin)

	var vbox := UH.make_vbox(6)
	vbox.name = "VBox"
	margin.add_child(vbox)

	# --- Speaker section: NPC portrait + name + text ---
	var speaker_hbox := UH.make_hbox(10)
	speaker_hbox.name = "SpeakerHBox"
	vbox.add_child(speaker_hbox)

	_npc_portrait = TextureRect.new()
	_npc_portrait.name = "NpcPortrait"
	_npc_portrait.custom_minimum_size = Vector2(64, 64)
	_npc_portrait.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	_npc_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_npc_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	speaker_hbox.add_child(_npc_portrait)

	var speaker_vbox := UH.make_vbox(4, true)
	speaker_vbox.name = "SpeakerVBox"
	speaker_hbox.add_child(speaker_vbox)

	# Speaker name
	_speaker_label = UH.make_accent_label("", 14)
	_speaker_label.name = "SpeakerLabel"
	_speaker_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_speaker_label.add_theme_constant_override("outline_size", 2)
	speaker_vbox.add_child(_speaker_label)

	# Dialogue text
	_text_label = UH.make_rich_section("")
	_text_label.name = "TextLabel"
	_text_label.fit_content = true
	_text_label.custom_minimum_size = Vector2(0, 40)
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speaker_vbox.add_child(_text_label)

	# --- Player section: player portrait + choices ---
	var player_hbox := UH.make_hbox(10)
	player_hbox.name = "PlayerHBox"
	player_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(player_hbox)

	_player_portrait = TextureRect.new()
	_player_portrait.name = "PlayerPortrait"
	_player_portrait.custom_minimum_size = Vector2(64, 64)
	_player_portrait.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	_player_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_player_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player_hbox.add_child(_player_portrait)

	var player_vbox := UH.make_vbox(4, true)
	player_vbox.name = "PlayerVBox"
	player_hbox.add_child(player_vbox)

	# Choices container
	_choices_container = UH.make_vbox(4)
	_choices_container.name = "Choices"
	player_vbox.add_child(_choices_container)

	# Close button (for end-of-dialogue)
	_close_button = UH.make_button("Close", "primary", 100, 28)
	_close_button.name = "CloseButton"
	_close_button.pressed.connect(_on_close_pressed)
	_close_button.visible = false
	player_vbox.add_child(_close_button)

	# Invite button (shown when NPC is recruitable)
	_invite_button = UH.make_button("Invite to Party", "primary", 140, 28)
	_invite_button.name = "InviteButton"
	_invite_button.pressed.connect(_on_invite_pressed)
	_invite_button.visible = false
	player_vbox.add_child(_invite_button)


func start_dialogue(role: String, npc_name: String, npc_race: String = "", npc_gender: String = "", npc_id: String = "") -> void:
	_role = role
	_npc_name = npc_name
	_npc_race = npc_race
	_npc_gender = npc_gender
	_npc_id = npc_id
	_load_npc_portrait()
	_load_player_portrait()
	_check_invite_eligibility()

	var dm: Node = get_node_or_null("/root/DialogueManager")
	if dm == null:
		push_error("[DialogueUI] DialogueManager not found")
		return

	var greeting: Dictionary = dm.call("get_dialogue_for_role", role)
	if greeting.is_empty():
		push_warning("[DialogueUI] No dialogue for role: %s" % role)
		_fallback_greeting(npc_name, role)
		return

	_show_node(greeting)
	visible = true


func _load_npc_portrait() -> void:
	if not is_instance_valid(_npc_portrait):
		return
	var race_key: String = _resolve_portrait_race(_npc_race)
	var idx: int = abs(_npc_id.hash()) % 6 + 1
	var path: String = "res://assets/portraits/%s_%s/portrait_%02d.png" % [race_key, _npc_gender, idx]
	if ResourceLoader.exists(path):
		_npc_portrait.texture = load(path)
		_npc_portrait.visible = true
	else:
		_npc_portrait.texture = null
		_npc_portrait.visible = false


func _load_player_portrait() -> void:
	if not is_instance_valid(_player_portrait):
		return
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null or not gs.has_method("get_character_data"):
		_player_portrait.visible = false
		return
	var data: Dictionary = gs.get_character_data()
	if data.is_empty():
		_player_portrait.visible = false
		return
	var race: String = str(data.get("race", ""))
	var appearance: Dictionary = data.get("appearance", {})
	var gender: String = str(appearance.get("gender", "male"))
	var portrait: int = int(appearance.get("portrait", 1))
	var race_key: String = _resolve_portrait_race(race)
	var path: String = "res://assets/portraits/%s_%s/portrait_%02d.png" % [race_key, gender, portrait]
	if ResourceLoader.exists(path):
		_player_portrait.texture = load(path)
		_player_portrait.visible = true
	else:
		_player_portrait.texture = null
		_player_portrait.visible = false


func _resolve_portrait_race(race_key: String) -> String:
	if PORTRAIT_RACE_MAP.has(race_key.to_lower()):
		return PORTRAIT_RACE_MAP[race_key.to_lower()]
	return race_key.to_lower()


func _check_invite_eligibility() -> void:
	if _npc_id.is_empty() or not is_instance_valid(_invite_button):
		return
	var pm: Node = get_node_or_null("/root/PartyNPCManager")
	if pm == null or not pm.has_method("can_invite"):
		return
	if pm.has_method("can_invite") and pm.call("can_invite", _npc_id):
		_invite_button.visible = true
	else:
		_invite_button.visible = false


func _fallback_greeting(npc_name: String, role: String) -> void:
	_speaker_label.text = npc_name
	_text_label.text = "[i]Nice to meet you.[/i]"
	for child in _choices_container.get_children():
		child.queue_free()
	_close_button.visible = true
	visible = true


func _show_node(node: Dictionary) -> void:
	_current_node = node
	var speaker: String = str(node.get("speaker", _npc_name))
	var text: String = str(node.get("text", ""))
	var choices: Array = node.get("choices", [])
	var action: String = str(node.get("action", ""))

	_speaker_label.text = speaker
	_text_label.text = text

	# Clear old choices
	for child in _choices_container.get_children():
		child.queue_free()

	# Check for action
	if not action.is_empty():
		action_triggered.emit(action)

	# Add choice buttons or close button
	if choices.is_empty():
		_close_button.visible = true
	else:
		_close_button.visible = false
		for i in range(choices.size()):
			var choice: Dictionary = choices[i]
			var choice_text: String = str(choice.get("text", ""))
			var btn := UH.make_button(choice_text, "ghost", 0, 28)
			btn.name = "Choice%d" % i
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var idx: int = i
			btn.pressed.connect(func(): _on_choice_pressed(idx))
			_choices_container.add_child(btn)


func _on_choice_pressed(index: int) -> void:
	choice_made.emit(index)
	var dm: Node = get_node_or_null("/root/DialogueManager")
	if dm == null:
		return

	var next_node: Dictionary = dm.call("resolve_choice", _role, _current_node.get("id", ""), index)
	if next_node.is_empty():
		# End of dialogue
		_close_button.visible = true
		return

	_show_node(next_node)


func _on_invite_pressed() -> void:
	invite_requested.emit(_npc_id)
	visible = false
	dialogue_finished.emit()
	queue_free()


func _on_close_pressed() -> void:
	visible = false
	dialogue_finished.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_close_pressed()
		get_viewport().set_input_as_handled()
