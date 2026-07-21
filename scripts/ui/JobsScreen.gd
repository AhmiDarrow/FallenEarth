## JobsScreen — Active missions and available jobs/quests.
## Displayed as a tab in the CharacterMenu. Shows accepted missions
## (tracked from MissionManager) and their objectives/progress.
class_name JobsScreen
extends Control

const MISSION_PATH := "/root/MissionManager"
const MT = preload("res://assets/ui/MasterTheme.gd")
const UH = preload("res://scripts/ui/UIHelper.gd")

var _missions_container: VBoxContainer
var _empty_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()
	_refresh()


func _build_ui() -> void:
	var margin := UH.make_margin(8)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var vbox := UH.make_vbox(8, true, false)
	margin.add_child(vbox)

	var title := UH.make_accent_label("Jobs & Quests", 18)
	vbox.add_child(title)

	var scroll := UH.make_scroll_container()
	vbox.add_child(scroll)

	_missions_container = UH.make_vbox(6, true, false)
	scroll.add_child(_missions_container)

	_empty_label = UH.make_muted_label("No active jobs or quests.\nVisit NPCs in settlements to find work.")
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_missions_container.add_child(_empty_label)

	UH.make_scrollable(vbox)


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
	var panel := UH.make_surface_panel()
	panel.custom_minimum_size = Vector2(0, 0)

	var margin := UH.make_margin(8)
	panel.add_child(margin)

	var vbox := UH.make_vbox(4)
	margin.add_child(vbox)

	var title := UH.make_label(str(mission.get("title", "Unknown Mission")), 14, MT.ACCENT_PRIMARY)
	vbox.add_child(title)

	var objectives: Array = mission.get("objectives", [])
	for i in objectives.size():
		var obj: Dictionary = objectives[i]
		var obj_text: String = str(obj.get("description", "Objective"))
		var current: int = int(obj.get("current", 0))
		var target: int = int(obj.get("target", 1))
		var done: bool = current >= target

		var obj_label: Label
		if done:
			obj_label = UH.make_success_label("  ✓ %s (Complete)" % obj_text, 11)
		else:
			obj_label = UH.make_label("  ○ %s (%d/%d)" % [obj_text, current, target], 11, MT.TEXT_SECONDARY)
		vbox.add_child(obj_label)

	var rewards: Dictionary = mission.get("rewards", {})
	var reward_text: String = ""
	if rewards.has("xp"):
		reward_text += "%d XP " % int(rewards["xp"])
	if rewards.has("ec"):
		reward_text += "%d EC " % int(rewards["ec"])
	if not reward_text.is_empty():
		var reward_label := UH.make_label("  Reward: %s" % reward_text.strip_edges(), 10, MT.TEXT_LINK)
		vbox.add_child(reward_label)

	return panel
