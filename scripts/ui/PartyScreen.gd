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

const INVENTORY_PATH := "/root/InventoryHandler"
const PARTY_PATH := "/root/PartyNPCManager"
const MT = preload("res://assets/ui/MasterTheme.gd")
const UH = preload("res://scripts/ui/UIHelper.gd")

# Equipment slot order (matches PartyNPCManager.EQUIP_SLOTS and the
# future EquipmentManager).
const EQUIP_SLOTS := ["armor", "mainhand", "offhand", "tool", "acc1", "acc2"]
const EQUIP_SLOT_LABELS := {
	"armor": "Armor",
	"mainhand": "Mainhand", "offhand": "Offhand", "tool": "Tool",
	"acc1": "Acc 1", "acc2": "Acc 2",
}

var SLOT_BG_COLOR := MT.BG_SURFACE
var SLOT_HOVER_COLOR := MT.BG_ELEVATED

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
	var hbox := UH.make_hbox(8)
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(hbox)

	# Left: party list (1/3 width)
	var left_panel := UH.make_surface_panel(Vector2(280, 0))
	hbox.add_child(left_panel)
	var left_vbox := UH.make_vbox()
	left_panel.add_child(left_vbox)
	var list_label := UH.make_label("Party Members", MT.FS_BODY, MT.TEXT_LINK)
	left_vbox.add_child(list_label)
	_list_vbox = UH.make_vbox()
	left_vbox.add_child(_list_vbox)
	# Bottom bar in the left panel: Add from available + Invite button
	var add_btn := UH.make_button("+ Add from available")
	add_btn.pressed.connect(_open_add_popup)
	left_vbox.add_child(add_btn)

	UH.make_scrollable(left_vbox)

	# Right: detail panel
	_detail_panel = UH.make_surface_panel()
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
		var empty := UH.make_muted_label("(no party members)\nClick 'Add from available' to invite NPCs.")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list_vbox.add_child(empty)
		return
	for i in members.size():
		var n: Dictionary = members[i]
		var row := _make_party_row(n, i)
		_list_vbox.add_child(row)


func _make_party_row(npc: Dictionary, idx: int) -> Button:
	var btn := UH.make_button("%s\n%s · Lv.%d" % [npc.get("name", "?"), npc.get("class", "?"), int(npc.get("level", 1))], "primary", 0, 56, true)
	btn.name = "PartyRow_%d" % idx
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(_on_party_row_pressed.bind(idx))
	return btn


func _on_party_row_pressed(idx: int) -> void:
	_selected_index = idx
	_refresh_detail()


func _refresh_detail() -> void:
	for child in _detail_panel.get_children():
		child.queue_free()
	if _selected_index < 0:
		var ph := UH.make_muted_label("Select a member")
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
	var vbox := UH.make_vbox(4)
	_detail_panel.add_child(vbox)
	# Header
	var hdr := UH.make_label("%s" % npc.get("name", "?"), 18, Color.WHITE)
	vbox.add_child(hdr)
	var sub := UH.make_label("%s %s · %s · Lv.%d" % [
		npc.get("race", "?"), npc.get("class", "?"), npc.get("gender", "?"),
		int(npc.get("level", 1)),
	], MT.FS_BODY, MT.TEXT_SECONDARY)
	vbox.add_child(sub)
	# Equipment grid
	var eq_label := UH.make_label("Equipment (read-only in Phase 3 — drag-to-equip lands in Phase 4)", 11, MT.TEXT_MUTED)
	vbox.add_child(eq_label)
	var eq_grid := GridContainer.new()
	eq_grid.columns = 3
	vbox.add_child(eq_grid)
	var equip: Dictionary = npc.get("equipment", {})
	for slot in EQUIP_SLOTS:
		var item_id: String = str(equip.get(slot, ""))
		var slot_box := UH.make_surface_panel(Vector2(120, 36))
		eq_grid.add_child(slot_box)
		if item_id.is_empty():
			var slot_label := UH.make_label("%s: (empty)" % EQUIP_SLOT_LABELS[slot], MT.FS_BODY, MT.TEXT_MUTED)
			slot_box.add_child(slot_label)
		else:
			var slot_label := UH.make_label("%s: %s" % [EQUIP_SLOT_LABELS[slot], item_id], MT.FS_BODY, MT.TEXT_LINK)
			slot_box.add_child(slot_label)
	# Dismiss button
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(spacer)
	var dismiss_btn := UH.make_button("Dismiss from party")
	dismiss_btn.pressed.connect(_on_dismiss_pressed)
	vbox.add_child(dismiss_btn)

	UH.make_scrollable(vbox)


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
	var vbox := UH.make_vbox(4)
	_add_popup.add_child(vbox)
	var title := UH.make_label("Available NPCs (invite)", MT.FS_BODY, MT.TEXT_LINK)
	vbox.add_child(title)
	var pm: Node = get_node_or_null(PARTY_PATH)
	if pm == null:
		var warn := UH.make_label("PartyNPCManager missing")
		vbox.add_child(warn)
		_add_popup.popup_centered()
		return
	var avail: Array = pm.available_npcs
	if avail.is_empty():
		var empty := UH.make_muted_label("(no one available right now)")
		vbox.add_child(empty)
	else:
		for n in avail:
			var npc: Dictionary = n
			var row := UH.make_hbox(0)
			row.custom_minimum_size = Vector2(0, 28)
			vbox.add_child(row)
			var info := UH.make_label("%s (%s Lv.%d)" % [
				npc.get("name", "?"), npc.get("class", "?"), int(npc.get("level", 1))
			])
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(info)
			var invite_btn := UH.make_button("Invite")
			invite_btn.pressed.connect(_on_invite_pressed.bind(str(npc.get("id", ""))))
			row.add_child(invite_btn)
			var decline_btn := UH.make_button("Decline")
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
