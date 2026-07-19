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

const MT = preload("res://assets/ui/MasterTheme.gd")

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	visible = false


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0, 0, 0, 0.75)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	# Panel container (centered at bottom)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.offset_left = 60
	_panel.offset_right = -60
	_panel.offset_top = -160
	_panel.offset_bottom = -20
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Speaker name
	_speaker_label = Label.new()
	_speaker_label.name = "SpeakerLabel"
	_speaker_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	_speaker_label.add_theme_font_size_override("font_size", 14)
	_speaker_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_speaker_label.add_theme_constant_override("outline_size", 2)
	vbox.add_child(_speaker_label)

	# Dialogue text
	_text_label = RichTextLabel.new()
	_text_label.name = "TextLabel"
	_text_label.bbcode_enabled = true
	_text_label.fit_content = true
	_text_label.custom_minimum_size = Vector2(0, 60)
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_text_label)

	# Choices container
	_choices_container = VBoxContainer.new()
	_choices_container.name = "Choices"
	_choices_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_choices_container)

	# Close button (for end-of-dialogue)
	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(100, 28)
	_close_button.pressed.connect(_on_close_pressed)
	_close_button.visible = false
	vbox.add_child(_close_button)

	# Invite button (shown when NPC is recruitable)
	_invite_button = Button.new()
	_invite_button.name = "InviteButton"
	_invite_button.text = "Invite to Party"
	_invite_button.custom_minimum_size = Vector2(140, 28)
	_invite_button.pressed.connect(_on_invite_pressed)
	_invite_button.visible = false
	vbox.add_child(_invite_button)


func start_dialogue(role: String, npc_name: String, npc_race: String = "", npc_gender: String = "", npc_id: String = "") -> void:
	_role = role
	_npc_name = npc_name
	_npc_race = npc_race
	_npc_gender = npc_gender
	_npc_id = npc_id
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
			var btn := Button.new()
			btn.name = "Choice%d" % i
			btn.text = choice_text
			btn.custom_minimum_size = Vector2(0, 28)
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
