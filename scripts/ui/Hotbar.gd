## Hotbar — 10-slot quickselect bar at the bottom of the in-game HUD.
##
## Phase 2. Each slot holds an item_id (or "" for empty). Number keys
## 1-0 select slots; the selected slot is highlighted. The "equipped"
## concept in Phase 2 is just the selected slot — Phase 4 will replace
## this with the real MainHand swap via EquipmentManager.
##
## Slot data is stored in GameState._hotbar (Array[String] of length 10).
## When a slot is selected, the chosen item becomes the "current tool"
## for gathering (read by HubWorld's _equipped_tool).
##
## The hotbar is a Control with 10 Button children. Each button shows
## a small icon and the slot number. Hovering shows a tooltip with the
## item name (Phase 1b HoverTooltip pattern, but inline here for the
## hotbar).
class_name Hotbar
extends Control

const SLOT_COUNT := 10
const SLOT_SIZE := 48

const INVENTORY_PATH := "/root/InventoryManager"

var _slots: Array[String] = []  # length 10, "" for empty
var _selected_index: int = 0
var _slot_buttons: Array[Button] = []

var equipped_item_id: String = ""  # public; updated on select
signal slot_selected(index: int, item_id: String)
signal slot_changed(index: int, item_id: String)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	# Anchor bottom-center of the viewport
	anchor_left = 0.5
	anchor_top = 1.0
	anchor_right = 0.5
	anchor_bottom = 1.0
	offset_left = -SLOT_SIZE * SLOT_COUNT / 2.0 - (SLOT_COUNT - 1) * 4 / 2.0
	offset_top = -SLOT_SIZE - 16
	offset_right = SLOT_SIZE * SLOT_COUNT / 2.0 + (SLOT_COUNT - 1) * 4 / 2.0
	offset_bottom = -16
	custom_minimum_size = Vector2(SLOT_SIZE * SLOT_COUNT + (SLOT_COUNT - 1) * 4, SLOT_SIZE + 8)

	# Initialize slots from GameState if available, else empty
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if is_instance_valid(gs) and gs.has_method("get_hotbar"):
		var saved: Array = gs.get_hotbar()
		if saved.size() == SLOT_COUNT:
			for i in SLOT_COUNT:
				_slots.append(str(saved[i]))
		else:
			_reset_slots()
	else:
		_reset_slots()

	_build_buttons()
	_refresh_all_buttons()
	select_slot(0)


func _reset_slots() -> void:
	_slots.clear()
	for _i in SLOT_COUNT:
		_slots.append("")


func _build_buttons() -> void:
	# Background panel behind the slots
	var bg := ColorRect.new()
	bg.name = "BG"
	bg.color = Color(0.05, 0.05, 0.07, 0.85)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	for i in SLOT_COUNT:
		var btn := Button.new()
		btn.name = "Slot_%d" % (i + 1)
		btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		btn.position = Vector2(i * (SLOT_SIZE + 4), 4)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(_on_slot_pressed.bind(i))
		add_child(btn)
		_slot_buttons.append(btn)


func _refresh_all_buttons() -> void:
	for i in SLOT_COUNT:
		_refresh_button(i)


func _refresh_button(i: int) -> void:
	if i < 0 or i >= _slot_buttons.size():
		return
	var btn: Button = _slot_buttons[i]
	var item_id: String = _slots[i] if i < _slots.size() else ""
	btn.text = "%d\n%s" % [((i + 1) % 10), _short_label(item_id)]
	btn.modulate = Color(1.5, 1.5, 1.0) if i == _selected_index else Color(1, 1, 1)


func _short_label(item_id: String) -> String:
	if item_id.is_empty():
		return ""
	# Strip common prefixes
	var s := item_id.replace("_", " ")
	# Take first letter of each word (lowercase)
	var out := ""
	for word in s.split(" "):
		if word.length() > 0:
			out += word.substr(0, 1).to_upper()
	if out.length() > 4:
		out = out.substr(0, 4)
	return out


func _on_slot_pressed(i: int) -> void:
	select_slot(i)


## Programmatically select a slot. Updates the highlight, emits signals,
## and updates equipped_item_id.
func select_slot(i: int) -> void:
	if i < 0 or i >= SLOT_COUNT:
		return
	var prev: int = _selected_index
	_selected_index = i
	if prev != i:
		_refresh_button(prev)
	_refresh_button(i)
	equipped_item_id = _slots[i]
	emit_signal("slot_selected", i, equipped_item_id)
	print("[Hotbar] Slot %d selected, item=%s" % [i + 1, equipped_item_id])


## Set the item at a slot. Pass "" to clear.
func set_slot(i: int, item_id: String) -> void:
	if i < 0 or i >= SLOT_COUNT:
		return
	_slots[i] = item_id
	_refresh_button(i)
	if i == _selected_index:
		equipped_item_id = item_id
	emit_signal("slot_changed", i, item_id)


## Return the item id at a slot, or "" if empty.
func get_slot(i: int) -> String:
	if i < 0 or i >= _slots.size():
		return ""
	return _slots[i]


## Return the full hotbar as an Array of Strings (length 10).
func get_slots() -> Array[String]:
	return _slots.duplicate()


## Replace the hotbar contents (e.g. from a save).
func set_slots(slots: Array) -> void:
	if slots.size() != SLOT_COUNT:
		return
	_slots.clear()
	for s in slots:
		_slots.append(str(s))
	_refresh_all_buttons()
	# Update equipped item to whatever is in the selected slot
	equipped_item_id = _slots[_selected_index]


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.keycode
	# Keys 1-9 map to slots 0-8; key 0 maps to slot 9.
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
