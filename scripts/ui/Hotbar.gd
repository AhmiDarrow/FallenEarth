## Hotbar — 10-slot quickselect bar at the bottom of the in-game HUD.
##
## Reads from InventoryManager.main_inventory row 0 (first 10 slots).
## Keyboard 1-0 selects slots. The selected item becomes the equipped tool.
class_name Hotbar
extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")
const SLOT_COUNT := 10
const SLOT_SIZE := 48
const INVENTORY_PATH := "/root/InventoryManager"

var _selected_index: int = 0
var _slot_buttons: Array[Button] = []

var equipped_item_id: String = ""
signal slot_selected(index: int, item_id: String)
signal slot_changed(index: int, item_id: String)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	anchor_left = 0.5
	anchor_top = 1.0
	anchor_right = 0.5
	anchor_bottom = 1.0
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = -SLOT_SIZE * SLOT_COUNT / 2.0 - (SLOT_COUNT - 1) * 4 / 2.0
	offset_top = -SLOT_SIZE - 16
	offset_right = SLOT_SIZE * SLOT_COUNT / 2.0 + (SLOT_COUNT - 1) * 4 / 2.0
	offset_bottom = -16
	custom_minimum_size = Vector2(SLOT_SIZE * SLOT_COUNT + (SLOT_COUNT - 1) * 4, SLOT_SIZE + 8)

	_build_buttons()
	refresh()
	select_slot(0)

	# Listen for inventory changes
	var inv: Node = get_node_or_null(INVENTORY_PATH)
	if inv != null and inv.has_signal("inventory_changed"):
		inv.connect("inventory_changed", refresh)


func _build_buttons() -> void:
	var bg := ColorRect.new()
	bg.name = "BG"
	bg.color = Color(0.05, 0.05, 0.07, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	for i in SLOT_COUNT:
		var btn := Button.new()
		btn.name = "Slot_%d" % (i + 1)
		btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		btn.position = Vector2(i * (SLOT_SIZE + 4), 4)
		btn.focus_mode = Control.FOCUS_ALL
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.add_theme_stylebox_override("focus", MT.focus_ring())
		btn.pressed.connect(_on_slot_pressed.bind(i))
		add_child(btn)
		_slot_buttons.append(btn)


func refresh() -> void:
	var inv: Node = get_node_or_null(INVENTORY_PATH)
	for i in SLOT_COUNT:
		var label := ""
		if inv != null and inv.has_method("get_hotbar_item"):
			var item: Dictionary = inv.get_hotbar_item(i)
			if not item.is_empty():
				label = "%d\n%s" % [((i + 1) % 10), _short_label(item.get("item_id", ""))]
		var btn := _slot_buttons[i]
		btn.text = label
		btn.modulate = Color(1.5, 1.5, 1.0) if i == _selected_index else Color(1, 1, 1)


func _short_label(item_id: String) -> String:
	if item_id.is_empty():
		return ""
	var s := item_id.replace("_", " ")
	var out := ""
	for word in s.split(" "):
		if word.length() > 0:
			out += word.substr(0, 1).to_upper()
	if out.length() > 4:
		out = out.substr(0, 4)
	return out


func _on_slot_pressed(i: int) -> void:
	select_slot(i)


func select_slot(i: int) -> void:
	if i < 0 or i >= SLOT_COUNT:
		return
	var prev: int = _selected_index
	_selected_index = i
	if prev != i:
		_refresh_button(prev)
	_refresh_button(i)
	equipped_item_id = _read_item_id(i)
	slot_selected.emit(i, equipped_item_id)


func _read_item_id(i: int) -> String:
	var inv: Node = get_node_or_null(INVENTORY_PATH)
	if inv == null or not inv.has_method("get_hotbar_item"):
		return ""
	return str(inv.get_hotbar_item(i).get("item_id", ""))


func _refresh_button(i: int) -> void:
	if i < 0 or i >= _slot_buttons.size():
		return
	var btn := _slot_buttons[i]
	btn.modulate = Color(1.5, 1.5, 1.0) if i == _selected_index else Color(1, 1, 1)


func set_slot(i: int, item_id: String) -> void:
	if i < 0 or i >= SLOT_COUNT or item_id.is_empty():
		return
	# Add the item to the first cell of the main grid, hotbar row
	var inv: Node = get_node_or_null(INVENTORY_PATH)
	if inv != null and inv.has_method("add_item"):
		inv.add_item(item_id, 1)
	slot_changed.emit(i, item_id)


func get_slot(i: int) -> String:
	return _read_item_id(i)


func get_slots() -> Array[String]:
	var arr: Array[String] = []
	for i in SLOT_COUNT:
		arr.append(_read_item_id(i))
	return arr


func set_slots(slots: Array) -> void:
	# Clear hotbar row and set from array
	var inv: Node = get_node_or_null(INVENTORY_PATH)
	if inv == null:
		return
	for i in SLOT_COUNT:
		var cur := _read_item_id(i)
		if not cur.is_empty() and inv.has_method("remove_item"):
			inv.remove_item(cur, 1)
	for i in min(slots.size(), SLOT_COUNT):
		var item_id := str(slots[i])
		if not item_id.is_empty() and inv.has_method("add_item"):
			inv.add_item(item_id, 1)
	refresh()
	equipped_item_id = _read_item_id(_selected_index)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.keycode
	var slot_index: int = -1
	if key >= KEY_1 and key <= KEY_9:
		slot_index = key - KEY_1
	elif key == KEY_0:
		slot_index = 9
	if slot_index >= 0:
		select_slot(slot_index)
		get_viewport().set_input_as_handled()


func get_selected_index() -> int:
	return _selected_index

