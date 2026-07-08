## JobsScreen — Active missions and available jobs/quests.
## Displayed as a tab in the CharacterMenu. Shows accepted missions
## (tracked from MissionManager) and their objectives/progress.
class_name JobsScreen
extends Control

const MISSION_PATH := "/root/MissionManager"

var _missions_container: VBoxContainer
var _empty_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()
	_refresh()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Jobs & Quests"
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_missions_container = VBoxContainer.new()
	_missions_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_missions_container.add_theme_constant_override("separation", 6)
	scroll.add_child(_missions_container)

	_empty_label = Label.new()
	_empty_label.text = "No active jobs or quests.\nVisit NPCs in settlements to find work."
	_empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_empty_label.add_theme_font_size_override("font_size", 12)
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_missions_container.add_child(_empty_label)


func _refresh() -> void:
	for child in _missions_container.get_children():
		if child != _empty_label:
			child.queue_free()

	var mm: Node = get_node_or_null(MISSION_PATH)
	if mm == null or not mm.has_method("get_active_missions"):
		_empty_label.visible = true
		return

	var active: Array = mm.call("get_active_missions") if mm.has_method("get_active_missions") else []
	_empty_label.visible = active.is_empty()

	for mission in active:
		if mission is Dictionary:
			var entry := _create_mission_entry(mission as Dictionary)
			_missions_container.add_child(entry)


func _create_mission_entry(mission: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = str(mission.get("title", "Unknown Mission"))
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var objectives: Array = mission.get("objectives", [])
	for i in objectives.size():
		var obj: Dictionary = objectives[i]
		var obj_text: String = str(obj.get("description", "Objective"))
		var current: int = int(obj.get("current", 0))
		var target: int = int(obj.get("target", 1))
		var done: bool = current >= target

		var obj_label := Label.new()
		if done:
			obj_label.text = "  ✓ %s (Complete)" % obj_text
			obj_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		else:
			obj_label.text = "  ○ %s (%d/%d)" % [obj_text, current, target]
			obj_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		obj_label.add_theme_font_size_override("font_size", 11)
		vbox.add_child(obj_label)

	var rewards: Dictionary = mission.get("rewards", {})
	var reward_text: String = ""
	if rewards.has("xp"):
		reward_text += "%d XP " % int(rewards["xp"])
	if rewards.has("ec"):
		reward_text += "%d EC " % int(rewards["ec"])
	if not reward_text.is_empty():
		var reward_label := Label.new()
		reward_label.text = "  Reward: %s" % reward_text.strip_edges()
		reward_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		reward_label.add_theme_font_size_override("font_size", 10)
		vbox.add_child(reward_label)

	return panel
