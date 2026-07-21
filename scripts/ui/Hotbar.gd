## Hotbar — 10-slot quickselect bar at the bottom of the in-game HUD.
##
## Slot layout (v0.4.0 polish):
##   - Slot 0 — source of truth is `InventoryHandler.main_grid[0][0]`.
##     Pressing 1 selects that item. `refresh()` ALSO inspects
##     `EquipmentManager.mainhand` and overlays an "equipped" badge
##     on the slot when the same item is in main hand — so the player
##     can see at a glance which slot holds the active weapon/tool.
##   - Slots 1-9 — items pulled from `InventoryHandler.main_grid[0][1..9]`.
##     Pressing 2-9 cycles through these consumables / tools / extras.
##
## Setting slot 0 via `set_slot(0, item_id)` ALSO calls
## `EquipmentManager.equip("player", item_id, "mainhand")` so the
## physical-character-equip state mirrors the slot. EquipmentManager
## stores what the character is *currently wielding*; the hotbar stores
## what is *currently selected for active use* (often the same item).
##
## Keyboard 1-0 selects slots. The selected item becomes the active tool
## used by `OverworldInteractionManager._resolve_hotbar_tool()`.
class_name Hotbar
extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")
const UH = preload("res://scripts/ui/UIHelper.gd")
const SLOT_COUNT := 10
const SLOT_SIZE := 48
const INVENTORY_PATH := "/root/InventoryHandler"

var _selected_index: int = 0
var _slot_buttons: Array[Button] = []
var _slot_frames: Array[ColorRect] = []
var _slot_icons: Array[ItemIcon] = []
var _slot_num_labels: Array[Label] = []

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
	var bg := UH.make_backdrop()
	bg.name = "BG"
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	for i in SLOT_COUNT:
		var x: float = i * (SLOT_SIZE + 4)

		# Slot background frame
		var slot_frame := ColorRect.new()
		slot_frame.name = "SlotFrame_%d" % i
		slot_frame.color = MT.BG_SURFACE
		slot_frame.position = Vector2(x, 4)
		slot_frame.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(slot_frame)
		_slot_frames.append(slot_frame)

		# Item icon
		var icon := ItemIcon.new("", 0, SLOT_SIZE - 8)
		icon.name = "Icon_%d" % i
		icon.position = Vector2(x + 4, 8)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon)
		_slot_icons.append(icon)

		# Slot number (bottom-right)
		var num_lbl := Label.new()
		num_lbl.name = "SlotNum_%d" % i
		num_lbl.text = str((i + 1) % 10)
		num_lbl.add_theme_font_size_override("font_size", 9)
		num_lbl.add_theme_color_override("font_color", MT.TEXT_MUTED)
		num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		num_lbl.position = Vector2(x + SLOT_SIZE - 15, 4 + SLOT_SIZE - 13)
		num_lbl.size = Vector2(13, 11)
		add_child(num_lbl)
		_slot_num_labels.append(num_lbl)

		# Invisible button for clicks
		var btn := Button.new()
		btn.name = "SlotBtn_%d" % i
		btn.flat = true
		btn.position = Vector2(x, 4)
		btn.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		btn.focus_mode = Control.FOCUS_ALL
		btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("focus", MT.focus_ring())
		btn.pressed.connect(_on_slot_pressed.bind(i))
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(btn)
		_slot_buttons.append(btn)


func refresh() -> void:
	var inv: Node = get_node_or_null(INVENTORY_PATH)
	var mainhand_id := _read_mainhand_item_id()
	for i in SLOT_COUNT:
		var item_id := ""
		var count := 1
		if inv != null and inv.has_method("get_hotbar_item"):
			var item: Dictionary = inv.get_hotbar_item(i)
			if not item.is_empty():
				item_id = str(item.get("id", ""))
				count = int(item.get("count", 1))
		if i < _slot_icons.size():
			_slot_icons[i].refresh(item_id, count)
		if i < _slot_frames.size():
			if i == 0 and not mainhand_id.is_empty() and mainhand_id == item_id:
				_slot_frames[i].color = MT.BG_ELEVATED
			else:
				_slot_frames[i].color = MT.BG_SURFACE
		if i < _slot_buttons.size():
			_slot_buttons[i].modulate = Color.WHITE


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
	# All 10 slots read from InventoryHandler.main_grid row 0. The
	# equipped MainHand from EquipmentManager is read separately by
	# `_read_mainhand_item_id()` for the visual overlay (refresh()).
	var inv: Node = get_node_or_null(INVENTORY_PATH)
	if inv == null or not inv.has_method("get_hotbar_item"):
		return ""
	return str(inv.get_hotbar_item(i).get("id", ""))


## Reads the player's currently-equipped MainHand item id from
## EquipmentManager. Returns "" when not equipped / autoload missing.
func _read_mainhand_item_id() -> String:
	var em: Node = get_node_or_null("/root/EquipmentManager")
	if em == null:
		return ""
	if em.has_method("get_main_hand_item"):
		var data: Variant = em.call("get_main_hand_item", "player")
		if data is Dictionary:
			return str((data as Dictionary).get("id", ""))
	# Fall back: the EquipmentManager dict often exposes the slot as a
	# plain key on the autoload ("player_main_hand" shorthand).
	if "player_main_hand" in em:
		return str(em.get("player_main_hand"))
	return ""


func _refresh_button(i: int) -> void:
	if i < 0 or i >= _slot_frames.size():
		return
	var frame := _slot_frames[i]
	frame.color = MT.SELECTED_BG if i == _selected_index else MT.BG_SURFACE


func set_slot(i: int, item_id: String) -> void:
	if i < 0 or i >= SLOT_COUNT or item_id.is_empty():
		return
	# Add the item to the first cell of the main grid, hotbar row
	var inv: Node = get_node_or_null(INVENTORY_PATH)
	if inv != null and inv.has_method("add_item"):
		inv.add_item(item_id, 1)
	# Slot 0 also equips the item into the player's MainHand so the
	# physical character state matches the ui selection. (Tools and
	# weapons share MainHand; only one item can be there at a time.)
	if i == 0:
		var em: Node = get_node_or_null("/root/EquipmentManager")
		if em != null and em.has_method("equip"):
			em.call("equip", "player", item_id, "mainhand")
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

