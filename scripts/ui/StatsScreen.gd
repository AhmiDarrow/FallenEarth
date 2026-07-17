## StatsScreen — Player + party member stats display.
##
## Phase 4 real version (was a placeholder in Phase 3). Shows the
## currently selected party member's stats (HP / MP / Attack / Defense
## + stat bonuses from gear). Default selection is the player.
##
## Layout:
##   - Left: list of party members + "Player" option; click to select
##   - Right: stats panel for the selected member
##
## Real HP/MP damage system lands in a follow-up. For now this screen
## shows max HP/MP from EquipmentManager.get_max_hp / get_max_mp.
class_name StatsScreen
extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")
const INVENTORY_PATH := "/root/InventoryManager"
const EQUIPMENT_PATH := "/root/EquipmentManager"
const PARTY_PATH := "/root/PartyNPCManager"
const PROG_PATH := "/root/ProgressionManager"

const PLAYER_ID := "player"

var _list_vbox: VBoxContainer
var _stats_label: Label
var _selected_id: String = PLAYER_ID


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()
	_refresh()


func _build_ui() -> void:
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 12)
	add_child(hbox)
	# Left: member list
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(200, 0)
	hbox.add_child(left_panel)
	var left_vbox := VBoxContainer.new()
	left_panel.add_child(left_vbox)
	var title := Label.new()
	title.text = "[ Stats — Select Member ]"
	title.add_theme_color_override("font_color", MT.TEXT_ACCENT)
	title.add_theme_font_size_override("font_size", MT.FS_H2)
	left_vbox.add_child(title)
	_list_vbox = VBoxContainer.new()
	_list_vbox.add_theme_constant_override("separation", 4)
	left_vbox.add_child(_list_vbox)
	# Right: stats panel
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(right_panel)
	var right_vbox := VBoxContainer.new()
	right_panel.add_child(right_vbox)
	_stats_label = Label.new()
	_stats_label.text = ""
	_stats_label.add_theme_color_override("font_color", MT.TEXT_PRIMARY)
	_stats_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_stats_label.add_theme_constant_override("outline_size", 2)
	_stats_label.add_theme_font_size_override("font_size", MT.FS_STAT)
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_vbox.add_child(_stats_label)


func _refresh() -> void:
	_refresh_member_list()
	_refresh_stats()


func _refresh_member_list() -> void:
	if _list_vbox == null:
		return
	for child in _list_vbox.get_children():
		child.queue_free()
	# "Player" row
	var pm_btn := Button.new()
	pm_btn.text = "Player"
	pm_btn.toggle_mode = true
	pm_btn.focus_mode = Control.FOCUS_ALL
	pm_btn.add_theme_stylebox_override("focus", MT.focus_ring())
	pm_btn.button_pressed = (_selected_id == PLAYER_ID)
	pm_btn.pressed.connect(_on_member_pressed.bind(PLAYER_ID))
	_list_vbox.add_child(pm_btn)
	# Party members
	var pm: Node = get_node_or_null(PARTY_PATH)
	if pm == null:
		return
	for n in pm.party_members:
		var member_name: String = str(n.get("name", "?"))
		var member_class: String = str(n.get("class", "?"))
		var level: int = int(n.get("level", 1))
		var row := Button.new()
		row.text = "%s (%s · Lv.%d)" % [member_name, member_class, level]
		row.toggle_mode = true
		row.focus_mode = Control.FOCUS_ALL
		row.add_theme_stylebox_override("focus", MT.focus_ring())
		row.button_pressed = (_selected_id == str(n.get("id", "")))
		row.pressed.connect(_on_member_pressed.bind(str(n.get("id", ""))))
		_list_vbox.add_child(row)


func _on_member_pressed(npc_id: String) -> void:
	_selected_id = npc_id
	_refresh()


func _refresh_stats() -> void:
	if _stats_label == null:
		return
	var em: Node = get_node_or_null(EQUIPMENT_PATH)
	if em == null:
		_stats_label.text = "(EquipmentManager unavailable)"
		return
	var mods: Dictionary = em.get_stat_mods(_selected_id)
	var atk: int = em.get_attack(_selected_id)
	var defn: int = em.get_defense(_selected_id)
	var eq: Dictionary = em.get_equipment(_selected_id)
	var armor_total: int = 0
	for slot in ["head", "chest", "legs", "boots"]:
		var item_id: String = str(eq.get(slot, ""))
		if item_id.is_empty():
			continue
		var entry: Dictionary = em._resolve_item(item_id)
		armor_total += int(entry.get("armor", 0))
	# Level (from ProgressionManager for the player, from the NPC dict
	# for party members).
	var level: int = 1
	if _selected_id == PLAYER_ID:
		var prog: Node = get_node_or_null(PROG_PATH)
		if prog != null:
			level = int(prog.level)
	else:
		var pm: Node = get_node_or_null(PARTY_PATH)
		if pm != null:
			for n in pm.party_members:
				if str(n.get("id", "")) == _selected_id:
					level = int(n.get("level", 1))
					break
	var hp: int = em.get_max_hp(level, mods)
	var mp: int = em.get_max_mp(level, mods)
	var main_hand: String = em.get_main_hand_item(_selected_id)
	_stats_label.text = "Member: %s\nLevel: %d\n\nMax HP: %d   Max MP: %d\n\nAttack: %d   Defense: %d\nArmor (gear): %d\n\nSTR: %+d   INT: %+d   CON: %+d   WIS: %+d   DEX: %+d\n\nMain hand: %s" % [
		_selected_id, level,
		hp, mp,
		atk, defn, armor_total,
		int(mods.get("str", 0)), int(mods.get("int", 0)), int(mods.get("con", 0)),
		int(mods.get("wis", 0)), int(mods.get("dex", 0)),
		main_hand if not main_hand.is_empty() else "(empty)",
	]
