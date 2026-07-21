class_name ItemSlot
extends Control
## Slot that displays an item icon and handles click/drag interactions.
## Can be used in both InventoryGrid (grid_x, grid_y) and
## EquipmentDoll (slot_key = equip slot name).

const MT = preload("res://assets/ui/MasterTheme.gd")
const UH = preload("res://scripts/ui/UIHelper.gd")

var grid_x: int = -1
var grid_y: int = -1
var slot_key: String = ""  # equip slot name for paperdoll
var item_id: String = ""
var count: int = 0

var _icon: ItemIcon
var _label: Label
var _selected: bool = false

var _click_enabled: bool = true

signal clicked(x: int, y: int, item_id: String, right_click: bool)
signal right_clicked(slot: String, item_id: String)
signal double_clicked(slot: String, item_id: String)
signal hovered(slot: String)
signal unhovered


func _init(size: int = 48, label_text: String = "") -> void:
	custom_minimum_size = Vector2(size, size)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	if label_text != "":
		_label = UH.make_label(label_text, 8, MT.TEXT_SECONDARY)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(_label)

	_icon = ItemIcon.new("", 0, maxi(size - 8, 16))
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_icon)


func refresh(slot_data: Dictionary) -> void:
	if slot_data.is_empty():
		item_id = ""
		count = 0
	else:
		item_id = slot_data.get("id", "")
		count = slot_data.get("count", 0)

	if _label != null and slot_key != "":
		var em := get_node_or_null("/root/EquipmentManager") as EquipmentManager
		if em != null:
			var eq: Dictionary = em.get_equipment("player")
			var equipped_id: String = str(eq.get(slot_key, ""))
			if equipped_id != "":
				_label.text = equipped_id.replace("_", " ").trim_prefix("weapon ").trim_prefix("armor ")
			else:
				_label.text = SLOT_LABELS.get(slot_key, slot_key)

	if _icon != null:
		_icon.refresh(item_id, count)
	queue_redraw()


func set_selected(sel: bool) -> void:
	_selected = sel
	if _icon != null:
		_icon.set_selected(sel)


# --- Paperdoll helpers ---
const SLOT_LABELS := {
	"armor": "Armor",
	"mainhand": "Mainhand", "offhand": "Offhand", "tool": "Tool",
	"acc1": "Acc 1", "acc2": "Acc 2",
}


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if not _click_enabled:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if item_id == "":
				return
			if event.double_click:
				double_clicked.emit(slot_key if slot_key != "" else "", item_id)
				return
			var dh := get_node_or_null("/root/DragHandler") as DragHandler
			if dh != null:
				dh.begin_drag(self, get_parent(), item_id, count)
			clicked.emit(grid_x, grid_y, item_id, false)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			clicked.emit(grid_x, grid_y, item_id, true)
			right_clicked.emit(slot_key, item_id)


func _mouse_enter() -> void:
	hovered.emit(slot_key if slot_key != "" else "%d,%d" % [grid_x, grid_y])


func _mouse_exit() -> void:
	unhovered.emit()


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	if _selected:
		draw_rect(Rect2(Vector2.ZERO, size), MT.SELECTED_TINT, false, 2.0)
