## RiftEntryUI — Modal overlay shown when player presses E on a rift cell.
## Displays rift info, party composition, and a "Proceed with Rift Run" button.
class_name RiftEntryUI
extends Control

signal proceed_requested(rift_data: Dictionary)
signal cancelled

var _rift_data: Dictionary = {}
var _panel: PanelContainer


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


func setup(rift: Dictionary) -> void:
	_rift_data = rift


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.65)
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	add_child(backdrop)

	_panel = PanelContainer.new()
	_panel.offset_left = -200
	_panel.offset_right = 200
	_panel.offset_top = -160
	_panel.offset_bottom = 160
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Rift Entry"
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 1.0))
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	var rift_id := Label.new()
	rift_id.text = str(_rift_data.get("rift_id", "Unknown Rift"))
	rift_id.add_theme_color_override("font_color", Color(0.7, 0.7, 0.85))
	rift_id.add_theme_font_size_override("font_size", 13)
	vbox.add_child(rift_id)

	var remaining: float = float(_rift_data.get("duration", 600.0))
	var mins := maxi(0, int(remaining / 60.0))
	var time_label := Label.new()
	time_label.text = "Time remaining: ~%d min" % mins
	time_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	time_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(time_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var party_header := Label.new()
	party_header.text = "Party"
	party_header.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	party_header.add_theme_font_size_override("font_size", 16)
	vbox.add_child(party_header)

	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	var char_data: Dictionary = gs.get_party_character_data() if is_instance_valid(gs) else {}

	# Player row
	var player_name: String = str(char_data.get("name", "Player"))
	var player_class: String = str(char_data.get("class", "?"))
	var player_level: int = int(char_data.get("level", 1))
	var player_label := Label.new()
	player_label.text = "★ %s — %s  Lv.%d  (You)" % [player_name, player_class, player_level]
	player_label.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	player_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(player_label)

	# Companion rows
	var companions: Array = char_data.get("companions", [])
	if companions.is_empty():
		var no_comp := Label.new()
		no_comp.text = "  (no companions recruited)"
		no_comp.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		no_comp.add_theme_font_size_override("font_size", 11)
		vbox.add_child(no_comp)
	else:
		for comp in companions:
			var comp_name: String = str(comp.get("name", "?"))
			var comp_class: String = str(comp.get("class", "?"))
			var comp_level: int = int(comp.get("level", 1))
			var comp_label := Label.new()
			comp_label.text = "  ◆ %s — %s  Lv.%d" % [comp_name, comp_class, comp_level]
			comp_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
			comp_label.add_theme_font_size_override("font_size", 12)
			vbox.add_child(comp_label)

	vbox.add_spacer(true)

	var proceed_btn := Button.new()
	proceed_btn.text = "Proceed with Rift Run"
	proceed_btn.custom_minimum_size = Vector2(260, 42)
	proceed_btn.pressed.connect(_on_proceed)
	vbox.add_child(proceed_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(120, 32)
	cancel_btn.pressed.connect(_on_cancel)
	vbox.add_child(cancel_btn)


func _on_proceed() -> void:
	proceed_requested.emit(_rift_data)
	queue_free()


func _on_cancel() -> void:
	cancelled.emit()
	queue_free()
