## RiftEntryUI — Modal overlay shown when player presses E on a rift cell.
## Displays rift info, party composition, and a "Proceed with Rift Run" button.
class_name RiftEntryUI
extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")
const UH = preload("res://scripts/ui/UIHelper.gd")

signal proceed_requested(rift_data: Dictionary)
signal cancelled

var _rift_data: Dictionary = {}
var _panel: PanelContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


func setup(rift: Dictionary) -> void:
	_rift_data = rift


func _build_ui() -> void:
	UH.apply_backdrop(self)

	var _center := CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_center)
	_panel = UH.make_elevated_panel()
	_center.add_child(_panel)

	var margin := UH.make_margin(16)
	_panel.add_child(margin)

	var vbox := UH.make_vbox(8)
	margin.add_child(vbox)

	var title := UH.make_label("Rift Entry", 22, MT.ACCENT_NEON)
	vbox.add_child(title)

	var rift_id := UH.make_label(str(_rift_data.get("rift_id", "Unknown Rift")), 13, MT.TEXT_SECONDARY)
	vbox.add_child(rift_id)

	var remaining: float = float(_rift_data.get("duration", 600.0))
	var mins := maxi(0, int(remaining / 60.0))
	var time_label := UH.make_label("Time remaining: ~%d min" % mins, 12, MT.TEXT_SECONDARY)
	vbox.add_child(time_label)

	vbox.add_child(UH.make_separator())

	var party_header := UH.make_label("Party", 16, Color(0.85, 0.95, 1.0))
	vbox.add_child(party_header)

	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	var char_data: Dictionary = gs.get_party_character_data() if is_instance_valid(gs) else {}

	# Player row
	var player_name: String = str(char_data.get("name", "Player"))
	var player_class: String = str(char_data.get("class", "?"))
	var player_level: int = int(char_data.get("level", 1))
	var player_label := UH.make_label("★ %s — %s  Lv.%d  (You)" % [player_name, player_class, player_level], 13, Color(0.4, 0.85, 1.0))
	vbox.add_child(player_label)

	# Companion rows
	var companions: Array = char_data.get("companions", [])
	if companions.is_empty():
		var no_comp := UH.make_label("  (no companions recruited)", 11, Color(0.55, 0.55, 0.6))
		vbox.add_child(no_comp)
	else:
		for comp in companions:
			var comp_name: String = str(comp.get("name", "?"))
			var comp_class: String = str(comp.get("class", "?"))
			var comp_level: int = int(comp.get("level", 1))
			var comp_label := UH.make_label("  ◆ %s — %s  Lv.%d" % [comp_name, comp_class, comp_level], 12, Color(0.75, 0.85, 0.95))
			vbox.add_child(comp_label)

	vbox.add_spacer(true)

	var proceed_btn := UH.make_button("Proceed with Rift Run", "primary", 260, 42)
	proceed_btn.pressed.connect(_on_proceed)
	vbox.add_child(proceed_btn)

	var cancel_btn := UH.make_button("Cancel", "secondary", 120, 32)
	cancel_btn.pressed.connect(_on_cancel)
	vbox.add_child(cancel_btn)

	UH.make_scrollable(vbox)


func _on_proceed() -> void:
	proceed_requested.emit(_rift_data)
	queue_free()


func _on_cancel() -> void:
	cancelled.emit()
	queue_free()
