## QuestTrackerUI — Collapsible side panel showing active missions.
##
## Displays mission list with objectives, progress checkboxes, and reward preview.
## Toggled with Tab key.
class_name QuestTrackerUI
extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")
const UH = preload("res://scripts/ui/UIHelper.gd")

var _panel: PanelContainer = null
var _title_label: Label = null
var _missions_container: VBoxContainer = null
var _toggle_button: Button = null
var _is_visible: bool = false


func _ready() -> void:
	# Use `anchors_preset` (property syntax) instead of `anchor_right = 1.0`
	# to avoid Godot's "size overridden after _ready" warning — see
	# BaseShopUI for the full explanation. This UI doesn't read `size`
	# directly, but the consistent syntax keeps the project clean.
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	visible = false


func _build_ui() -> void:
	# Toggle button (top-right corner)
	_toggle_button = UH.make_button("QUESTS", "primary", 80, 24)
	_toggle_button.name = "ToggleQuests"
	_toggle_button.position = Vector2(-100, 10)
	_toggle_button.anchors_preset = Control.PRESET_TOP_RIGHT
	_toggle_button.offset_left = -100
	_toggle_button.offset_right = -10
	_toggle_button.offset_top = 10
	_toggle_button.offset_bottom = 34
	_toggle_button.pressed.connect(_on_toggle_pressed)
	add_child(_toggle_button)

	# Panel (right side)
	_panel = UH.make_surface_panel()
	_panel.name = "Panel"
	_panel.offset_left = -260
	_panel.offset_right = -10
	_panel.offset_top = 40
	_panel.offset_bottom = -10
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var margin := UH.make_margin(8)
	margin.name = "Margin"
	_panel.add_child(margin)

	var scroll := UH.make_scroll_container()
	scroll.name = "Scroll"
	margin.add_child(scroll)

	var vbox := UH.make_vbox(8, true)
	vbox.name = "VBox"
	scroll.add_child(vbox)

	# Title
	_title_label = UH.make_accent_label("Active Missions", 14)
	_title_label.name = "Title"
	_title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_title_label.add_theme_constant_override("outline_size", 2)
	vbox.add_child(_title_label)

	# Missions container
	_missions_container = UH.make_vbox(6, true)
	_missions_container.name = "Missions"
	vbox.add_child(_missions_container)

	# Empty state label
	var empty := UH.make_muted_label("No active missions.\nTalk to NPCs to find work.")
	empty.name = "EmptyLabel"
	empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(empty)


func _on_toggle_pressed() -> void:
	_is_visible = not _is_visible
	visible = _is_visible
	_toggle_button.text = "QUESTS" if not _is_visible else "HIDE"


func toggle() -> void:
	_on_toggle_pressed()


func show_panel() -> void:
	_is_visible = true
	visible = true
	_toggle_button.text = "HIDE"


func hide_panel() -> void:
	_is_visible = false
	visible = false
	_toggle_button.text = "QUESTS"


func refresh(missions: Array[Dictionary]) -> void:
	# Clear old mission entries
	for child in _missions_container.get_children():
		child.queue_free()

	# Update empty label
	var empty: Label = _missions_container.get_node_or_null("../EmptyLabel") as Label
	if empty != null:
		empty.visible = missions.is_empty()

	# Add mission entries
	for mission in missions:
		var entry := _create_mission_entry(mission)
		_missions_container.add_child(entry)


func _create_mission_entry(mission: Dictionary) -> PanelContainer:
	var panel := UH.make_surface_panel()
	panel.name = "Mission_%s" % str(mission.get("mission_id", ""))

	var margin := UH.make_margin(6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var vbox := UH.make_vbox(2)
	margin.add_child(vbox)

	# Mission title
	var title := UH.make_label(str(mission.get("title", "Unknown Mission")), 12, Color(1, 0.9, 0.6))
	title.name = "Title"
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 1)
	vbox.add_child(title)

	# Objectives
	var objectives: Array = mission.get("objectives", [])
	for i in range(objectives.size()):
		var obj: Dictionary = objectives[i]
		var obj_text: String = str(obj.get("description", "Objective"))
		var current: int = int(obj.get("current", 0))
		var target: int = int(obj.get("target", 1))
		var done: bool = current >= target

		var obj_label := UH.make_label(
			"  ✓ %s (Complete)" % obj_text if done else "  ○ %s (%d/%d)" % [obj_text, current, target],
			10,
			Color(0.5, 0.8, 0.5) if done else Color(0.8, 0.8, 0.8)
		)
		obj_label.name = "Objective%d" % i
		vbox.add_child(obj_label)

	# Reward preview
	var rewards: Dictionary = mission.get("rewards", {})
	var reward_text: String = ""
	if rewards.has("xp"):
		reward_text += "%d XP " % int(rewards["xp"])
	if rewards.has("ec"):
		reward_text += "%d EC " % int(rewards["ec"])
	if not reward_text.is_empty():
		var reward_label := UH.make_label("  Reward: %s" % reward_text.strip_edges(), 9, Color(0.7, 0.85, 1.0))
		reward_label.name = "Reward"
		vbox.add_child(reward_label)

	return panel
