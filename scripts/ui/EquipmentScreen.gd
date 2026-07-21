## EquipmentScreen — Paperdoll equipment screen.
## Left: EquipmentDoll with orbital slots.
## Right: InventoryGrid of player inventory for drag-to-equip.
## Unequip sends items to player inventory. No duplication.
class_name EquipmentScreen
extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")
const UH = preload("res://scripts/ui/UIHelper.gd")
const EQUIPMENT_PATH := "/root/EquipmentManager"
const PLAYER_ID := "player"
const CELL_SIZE := 44

const EQUIP_SLOTS := ["armor", "mainhand", "offhand", "tool", "acc1", "acc2"]
const SLOT_LABELS := {
	"armor": "Armor",
	"mainhand": "Mainhand", "offhand": "Offhand", "tool": "Tool",
	"acc1": "Acc 1", "acc2": "Acc 2",
}

signal closed


func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := UH.make_backdrop()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var hbox := UH.make_hbox(12)
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 8
	hbox.offset_top = 8
	hbox.offset_right = -8
	hbox.offset_bottom = -8
	add_child(hbox)

	# Left: paperdoll
	var doll_panel := UH.make_surface_panel(Vector2(360, 0))
	doll_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(doll_panel)

	var doll_vbox := UH.make_vbox(6)
	doll_panel.add_child(doll_vbox)

	var doll_title := _make_title("Equipment")
	doll_vbox.add_child(doll_title)

	var doll := EquipmentDoll.new()
	doll.name = "Paperdoll"
	doll.custom_minimum_size = Vector2(340, 420)
	doll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	doll_vbox.add_child(doll)

	# Right: inventory grid
	var inv_panel := UH.make_surface_panel()
	inv_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(inv_panel)

	var inv_vbox := UH.make_vbox(6)
	inv_panel.add_child(inv_vbox)

	var inv_title := _make_title("Inventory (drag to equip)")
	inv_vbox.add_child(inv_title)

	var grid := InventoryGrid.new(InventoryHandler.GRID_W, InventoryHandler.GRID_H, CELL_SIZE)
	grid.name = "EquipInvGrid"
	grid.slot_clicked.connect(_on_inv_slot_clicked)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inv_vbox.add_child(grid)

	# Connect double-click on inventory grid slots
	for slot in grid._slots:
		if not slot.double_clicked.is_connected(_on_inv_slot_double_clicked):
			slot.double_clicked.connect(_on_inv_slot_double_clicked)

	# Top-right close button
	var close_btn := UH.make_button("X", "danger", 28, 24)
	close_btn.position = Vector2(-36, 4)
	close_btn.pressed.connect(_on_close)
	add_child(close_btn)


func _make_title(text: String) -> Label:
	return UH.make_accent_label(text, MT.FS_H3)


func _on_inv_slot_clicked(x: int, y: int, item_id: String, right_click: bool) -> void:
	if item_id == "":
		return
	var target_slot := _resolve_target_slot(item_id)
	if target_slot.is_empty():
		return
	var em := get_node_or_null(EQUIPMENT_PATH) as EquipmentManager
	var ih := get_node_or_null("/root/InventoryHandler") as InventoryHandler
	if em == null or ih == null:
		return
	var slot_data := ih.get_slot(x, y)
	if slot_data.is_empty():
		return
	# Remove from inventory, equip
	if not ih.remove_item(item_id, 1):
		return
	if not em.equip(PLAYER_ID, item_id, target_slot):
		ih.add_item(item_id, 1)
		return
	# Refresh grid + doll
	var pd := get_node_or_null("Paperdoll") as EquipmentDoll
	if pd != null:
		pd.refresh()
	# Also refresh the inventory grid to reflect the removed item
	var grid := get_node_or_null("EquipInvGrid") as InventoryGrid
	if grid != null:
		grid.refresh()


func _on_inv_slot_double_clicked(_slot_key: String, item_id: String) -> void:
	_equip_item(item_id)


func _on_close() -> void:
	closed.emit()
	queue_free()


func _equip_item(item_id: String) -> void:
	if item_id == "":
		return
	var target_slot := _resolve_target_slot(item_id)
	if target_slot.is_empty():
		return
	var em := get_node_or_null(EQUIPMENT_PATH) as EquipmentManager
	var ih := get_node_or_null("/root/InventoryHandler") as InventoryHandler
	if em == null or ih == null:
		return
	if not ih.remove_item(item_id, 1):
		return
	if not em.equip(PLAYER_ID, item_id, target_slot):
		ih.add_item(item_id, 1)
		return
	var pd := get_node_or_null("Paperdoll") as EquipmentDoll
	if pd != null:
		pd.refresh()
	var grid := get_node_or_null("EquipInvGrid") as InventoryGrid
	if grid != null:
		grid.refresh()


# ---------------------------------------------------------------------------
# Slot resolution (mirrored from EquipmentManager's parsing logic so the
# UI can route incoming inventory drags to the right slot).
# ---------------------------------------------------------------------------

func _resolve_target_slot(item_id: String) -> String:
	if item_id.begins_with("weapon_"):
		var eq := _get_equipment()
		if str(eq.get("mainhand", "")).is_empty():
			return "mainhand"
		if str(eq.get("offhand", "")).is_empty():
			return "offhand"
		return "mainhand"
	if item_id.begins_with("armor_"):
		# Single-slot model: every armor_<class>_t<n> id routes to "armor".
		# No slot-in-id to parse anymore.
		if item_id.substr("armor_".length()).split("_t").size() == 2:
			return "armor"
	var em := get_node_or_null(EQUIPMENT_PATH) as EquipmentManager
	if em != null and em.has_method("get_accessory"):
		if not em.get_accessory(item_id).is_empty():
			var eq2 := _get_equipment()
			if str(eq2.get("acc1", "")).is_empty():
				return "acc1"
			if str(eq2.get("acc2", "")).is_empty():
				return "acc2"
			return "acc1"
	return "tool"


func _get_equipment() -> Dictionary:
	var em := get_node_or_null(EQUIPMENT_PATH) as EquipmentManager
	if em == null:
		return {}
	return em.get_equipment(PLAYER_ID)
