## PartyScreen — List of party members + invite from available.
##
## Phase 3 ships the UI. Real NPC generation is Phase 5; for now the
## PartyNPCManager has a hard-coded set of 3 test NPCs in `available_npcs`.
##
## Layout:
##   - Left column: vertical list of current party members. Each row
##     shows name, class, level, a small HP bar, and a ">" button to
##     select that member.
##   - Right column: detail panel for the selected member (or "Select
##     a member" if none selected). Shows: name, race, class, gender,
##     level, a 9-slot equipment grid (read-only), Dismiss button.
##   - Bottom bar: "Add from available" button — opens a sub-panel
##     listing the available NPCs. Each row has Invite / Decline.
class_name PartyScreen
extends Control

const INVENTORY_PATH := "/root/InventoryManager"
const PARTY_PATH := "/root/PartyNPCManager"

# Equipment slot order (matches PartyNPCManager.EQUIP_SLOTS and the
# future EquipmentManager).
const EQUIP_SLOTS := ["head", "chest", "legs", "boots", "mainhand", "offhand", "tool", "acc1", "acc2"]
const EQUIP_SLOT_LABELS := {
	"head": "Head", "chest": "Chest", "legs": "Legs", "boots": "Boots",
	"mainhand": "Mainhand", "offhand": "Offhand", "tool": "Tool",
	"acc1": "Acc 1", "acc2": "Acc 2",
}

const SLOT_BG_COLOR := Color(0.12, 0.12, 0.15, 0.9)
const SLOT_HOVER_COLOR := Color(0.22, 0.22, 0.28, 0.9)

var _list_vbox: VBoxContainer
var _detail_panel: PanelContainer
var _selected_index: int = -1
var _add_popup: PopupPanel = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()
	var pm: Node = get_node_or_null(PARTY_PATH)
	if pm != null and not pm.is_connected("party_changed", _refresh):
		pm.connect("party_changed", _refresh)
	_refresh()


func _build_ui() -> void:
	# Layout: HBoxContainer splits the screen into list (left) and detail (right)
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 8)
	add_child(hbox)

	# Left: party list (1/3 width)
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(280, 0)
	hbox.add_child(left_panel)
	var left_vbox := VBoxContainer.new()
	left_panel.add_child(left_vbox)
	var list_label := Label.new()
	list_label.text = "Party Members"
	list_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	left_vbox.add_child(list_label)
	_list_vbox = VBoxContainer.new()
	left_vbox.add_child(_list_vbox)
	# Bottom bar in the left panel: Add from available + Invite button
	var add_btn := Button.new()
	add_btn.text = "+ Add from available"
	add_btn.pressed.connect(_open_add_popup)
	left_vbox.add_child(add_btn)

	# Right: detail panel
	_detail_panel = PanelContainer.new()
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_detail_panel)
	# Detail content populated lazily on selection


func _refresh() -> void:
	# Clear the list
	for child in _list_vbox.get_children():
		child.queue_free()
	# Populate from the current party_members
	var pm: Node = get_node_or_null(PARTY_PATH)
	if pm == null:
		return
	var members: Array = pm.party_members
	if members.is_empty():
		var empty := Label.new()
		empty.text = "(no party members)\nClick 'Add from available' to invite NPCs."
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list_vbox.add_child(empty)
		return
	for i in members.size():
		var n: Dictionary = members[i]
		var row := _make_party_row(n, i)
		_list_vbox.add_child(row)


func _make_party_row(npc: Dictionary, idx: int) -> Button:
	var btn := Button.new()
	btn.name = "PartyRow_%d" % idx
	btn.text = "%s\n%s · Lv.%d" % [npc.get("name", "?"), npc.get("class", "?"), int(npc.get("level", 1))]
	btn.custom_minimum_size = Vector2(0, 56)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(_on_party_row_pressed.bind(idx))
	btn.toggle_mode = true
	return btn


func _on_party_row_pressed(idx: int) -> void:
	_selected_index = idx
	_refresh_detail()


func _refresh_detail() -> void:
	for child in _detail_panel.get_children():
		child.queue_free()
	if _selected_index < 0:
		var ph := Label.new()
		ph.text = "Select a member"
		ph.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		ph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ph.set_anchors_preset(Control.PRESET_FULL_RECT)
		_detail_panel.add_child(ph)
		return
	var pm: Node = get_node_or_null(PARTY_PATH)
	if pm == null:
		return
	if _selected_index >= pm.party_members.size():
		_selected_index = -1
		_refresh_detail()
		return
	var npc: Dictionary = pm.party_members[_selected_index]
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_detail_panel.add_child(vbox)
	# Header
	var hdr := Label.new()
	hdr.text = "%s" % npc.get("name", "?")
	hdr.add_theme_color_override("font_color", Color.WHITE)
	hdr.add_theme_font_size_override("font_size", 18)
	vbox.add_child(hdr)
	var sub := Label.new()
	sub.text = "%s %s · %s · Lv.%d" % [
		npc.get("race", "?"), npc.get("class", "?"), npc.get("gender", "?"),
		int(npc.get("level", 1)),
	]
	sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(sub)
	# Equipment grid
	var eq_label := Label.new()
	eq_label.text = "Equipment (read-only in Phase 3 — drag-to-equip lands in Phase 4)"
	eq_label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.65))
	eq_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(eq_label)
	var eq_grid := GridContainer.new()
	eq_grid.columns = 3
	vbox.add_child(eq_grid)
	var equip: Dictionary = npc.get("equipment", {})
	for slot in EQUIP_SLOTS:
		var item_id: String = str(equip.get(slot, ""))
		var slot_box := PanelContainer.new()
		slot_box.custom_minimum_size = Vector2(120, 36)
		eq_grid.add_child(slot_box)
		var slot_label := Label.new()
		if item_id.is_empty():
			slot_label.text = "%s: (empty)" % EQUIP_SLOT_LABELS[slot]
			slot_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		else:
			slot_label.text = "%s: %s" % [EQUIP_SLOT_LABELS[slot], item_id]
			slot_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
		slot_box.add_child(slot_label)
	# Dismiss button
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(spacer)
	var dismiss_btn := Button.new()
	dismiss_btn.text = "Dismiss from party"
	dismiss_btn.pressed.connect(_on_dismiss_pressed)
	vbox.add_child(dismiss_btn)


func _on_dismiss_pressed() -> void:
	if _selected_index < 0:
		return
	var pm: Node = get_node_or_null(PARTY_PATH)
	if pm == null:
		return
	if _selected_index >= pm.party_members.size():
		return
	var npc_id: String = str(pm.party_members[_selected_index].get("id", ""))
	pm.dismiss(npc_id)
	_selected_index = -1
	_refresh()


# ---------------------------------------------------------------------------
# "Add from available" sub-panel
# ---------------------------------------------------------------------------

func _open_add_popup() -> void:
	if _add_popup != null and is_instance_valid(_add_popup):
		_add_popup.queue_free()
	_add_popup = PopupPanel.new()
	_add_popup.size = Vector2(360, 320)
	_add_popup.position = Vector2(60, 80)
	add_child(_add_popup)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_add_popup.add_child(vbox)
	var title := Label.new()
	title.text = "Available NPCs (invite)"
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	vbox.add_child(title)
	var pm: Node = get_node_or_null(PARTY_PATH)
	if pm == null:
		var warn := Label.new()
		warn.text = "PartyNPCManager missing"
		vbox.add_child(warn)
		_add_popup.popup_centered()
		return
	var avail: Array = pm.available_npcs
	if avail.is_empty():
		var empty := Label.new()
		empty.text = "(no one available right now)"
		empty.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		vbox.add_child(empty)
	else:
		for n in avail:
			var npc: Dictionary = n
			var row := HBoxContainer.new()
			row.custom_minimum_size = Vector2(0, 28)
			vbox.add_child(row)
			var info := Label.new()
			info.text = "%s (%s Lv.%d)" % [
				npc.get("name", "?"), npc.get("class", "?"), int(npc.get("level", 1))
			]
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(info)
			var invite_btn := Button.new()
			invite_btn.text = "Invite"
			invite_btn.pressed.connect(_on_invite_pressed.bind(str(npc.get("id", ""))))
			row.add_child(invite_btn)
			var decline_btn := Button.new()
			decline_btn.text = "Decline"
			decline_btn.pressed.connect(_on_decline_pressed.bind(str(npc.get("id", ""))))
			row.add_child(decline_btn)
	_add_popup.popup_centered()


func _on_invite_pressed(npc_id: String) -> void:
	var pm: Node = get_node_or_null(PARTY_PATH)
	if pm == null:
		return
	pm.invite(npc_id)
	if _add_popup != null and is_instance_valid(_add_popup):
		_add_popup.queue_free()
	_add_popup = null
	_refresh()


func _on_decline_pressed(npc_id: String) -> void:
	var pm: Node = get_node_or_null(PARTY_PATH)
	if pm == null:
		return
	# Decline = remove from available (for now). Phase 5 changes this to
	# a proper decline flow (refuses to respawn, etc.).
	for i in pm.available_npcs.size():
		if str(pm.available_npcs[i].get("id", "")) == npc_id:
			pm.available_npcs.remove_at(i)
			pm.available_changed.emit()
			break
	if _add_popup != null and is_instance_valid(_add_popup):
		_add_popup.queue_free()
	_add_popup = null
	_refresh()
