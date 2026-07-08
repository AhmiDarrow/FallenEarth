## QuestTrackerUI — Collapsible side panel showing active missions.
##
## Displays mission list with objectives, progress checkboxes, and reward preview.
## Toggled with Tab key.
class_name QuestTrackerUI
extends Control

const UIBackgrounds = preload("res://scripts/UIBackgrounds.gd")

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
	_toggle_button = Button.new()
	_toggle_button.name = "ToggleQuests"
	_toggle_button.text = "QUESTS"
	_toggle_button.custom_minimum_size = Vector2(80, 24)
	_toggle_button.position = Vector2(-100, 10)
	_toggle_button.anchors_preset = Control.PRESET_TOP_RIGHT
	_toggle_button.offset_left = -100
	_toggle_button.offset_right = -10
	_toggle_button.offset_top = 10
	_toggle_button.offset_bottom = 34
	_toggle_button.pressed.connect(_on_toggle_pressed)
	add_child(_toggle_button)

	# Panel (right side)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.offset_left = -260
	_panel.offset_right = -10
	_panel.offset_top = 40
	_panel.offset_bottom = -10
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	UIBackgrounds.apply_side_panel(_panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.text = "Active Missions"
	_title_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_title_label.add_theme_constant_override("outline_size", 2)
	vbox.add_child(_title_label)

	# Missions container
	_missions_container = VBoxContainer.new()
	_missions_container.name = "Missions"
	_missions_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_missions_container.add_theme_constant_override("separation", 6)
	vbox.add_child(_missions_container)

	# Empty state label
	var empty := Label.new()
	empty.name = "EmptyLabel"
	empty.text = "No active missions.\nTalk to NPCs to find work."
	empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	empty.add_theme_font_size_override("font_size", 11)
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
	var panel := PanelContainer.new()
	panel.name = "Mission_%s" % str(mission.get("mission_id", ""))
	panel.custom_minimum_size = Vector2(0, 0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)

	# Mission title
	var title := Label.new()
	title.name = "Title"
	title.text = str(mission.get("title", "Unknown Mission"))
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	title.add_theme_font_size_override("font_size", 12)
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

		var obj_label := Label.new()
		obj_label.name = "Objective%d" % i
		if done:
			obj_label.text = "  ✓ %s (Complete)" % obj_text
			obj_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		else:
			obj_label.text = "  ○ %s (%d/%d)" % [obj_text, current, target]
			obj_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		obj_label.add_theme_font_size_override("font_size", 10)
		vbox.add_child(obj_label)

	# Reward preview
	var rewards: Dictionary = mission.get("rewards", {})
	var reward_text: String = ""
	if rewards.has("xp"):
		reward_text += "%d XP " % int(rewards["xp"])
	if rewards.has("ec"):
		reward_text += "%d EC " % int(rewards["ec"])
	if not reward_text.is_empty():
		var reward_label := Label.new()
		reward_label.name = "Reward"
		reward_label.text = "  Reward: %s" % reward_text.strip_edges()
		reward_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		reward_label.add_theme_font_size_override("font_size", 9)
		vbox.add_child(reward_label)

	return panel
