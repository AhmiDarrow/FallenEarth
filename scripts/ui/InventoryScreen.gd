## InventoryScreen — 30-slot inventory grid screen.
##
## Phase 2. Shows the player's stack-based inventory in a 6x5 grid.
## Each cell displays the item's icon (small ColorRect placeholder for
## Phase 2) and stack qty. Hovering a slot shows the item name. Right-click
## opens a context menu (Use / Drop / Add to Hotbar / Equip if equipment).
##
## The screen is opened from the Character menu in the HUD. Close button
## returns to the world.
class_name InventoryScreen
extends Control

const SLOT_COUNT := 30
const COLS := 6
const SLOT_SIZE := 56

const INVENTORY_PATH := "/root/InventoryManager"

signal closed

var _slot_buttons: Array[Button] = []
var _context_menu: PopupMenu = null
var _context_slot_index: int = -1

var _hover_tooltip: HoverTooltip


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04, 0.92)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# Title bar
	var title := Label.new()
	title.text = "[ Inventory ]"
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_font_size_override("font_size", 24)
	title.position = Vector2(20, 12)
	add_child(title)
	# Close button
	var close := Button.new()
	close.text = "X"
	close.position = Vector2(size.x - 60, 12)
	close.custom_minimum_size = Vector2(40, 40)
	close.pressed.connect(_on_close_pressed)
	add_child(close)
	# Grid
	_build_grid()
	# Context menu
	_context_menu = PopupMenu.new()
	_context_menu.add_item("Use")
	_context_menu.add_item("Add to Hotbar")
	_context_menu.add_item("Drop")
	_context_menu.id_pressed.connect(_on_context_id_pressed)
	add_child(_context_menu)
	# Hook inventory signal
	var inv: Node = get_node_or_null(INVENTORY_PATH)
	if inv != null and inv.has_signal("inventory_changed"):
		inv.connect("inventory_changed", _refresh_slots)
	_refresh_slots()


func _build_grid() -> void:
	var start_x: int = 40
	var start_y: int = 80
	for i in SLOT_COUNT:
		var btn := Button.new()
		btn.name = "Slot_%d" % i
		btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		btn.position = Vector2(
			start_x + (i % COLS) * (SLOT_SIZE + 4),
			start_y + (i / COLS) * (SLOT_SIZE + 4),
		)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(_on_slot_pressed.bind(i))
		btn.gui_input.connect(_on_slot_gui_input.bind(i))
		add_child(btn)
		_slot_buttons.append(btn)


func _refresh_slots() -> void:
	var inv: Node = get_node_or_null(INVENTORY_PATH)
	if inv == null:
		return
	var snapshot: Array = inv.get_inventory_snapshot()
	for i in SLOT_COUNT:
		if i >= _slot_buttons.size():
			break
		var btn: Button = _slot_buttons[i]
		if i < snapshot.size():
			var slot: Dictionary = snapshot[i]
			var item_id: String = str(slot.get("item_id", ""))
			var qty: int = int(slot.get("qty", 0))
			var name: String = str(inv.get_item_name(item_id)) if inv.has_method("get_item_name") else item_id
			btn.text = "%s\nx%d" % [name, qty] if not name.is_empty() else ""
			btn.tooltip_text = name
		else:
			btn.text = ""
			btn.tooltip_text = ""


func _on_slot_pressed(_i: int) -> void:
	# Default click does nothing for Phase 2; right-click opens context.
	pass


func _on_slot_gui_input(i: int, event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_context_slot_index = i
		var inv: Node = get_node_or_null(INVENTORY_PATH)
		var snapshot: Array = inv.get_inventory_snapshot() if inv else []
		if i < snapshot.size():
			_context_menu.popup(Rect2(get_global_mouse_position(), Vector2(120, 80)))


func _on_context_id_pressed(id: int) -> void:
	if _context_slot_index < 0:
		return
	var inv: Node = get_node_or_null(INVENTORY_PATH)
	if inv == null:
		return
	var snapshot: Array = inv.get_inventory_snapshot()
	if _context_slot_index >= snapshot.size():
		return
	var slot: Dictionary = snapshot[_context_slot_index]
	var item_id: String = str(slot.get("item_id", ""))
	match id:
		0:  # Use
			_apply_use(item_id)
		1:  # Add to Hotbar
			_add_to_hotbar(item_id)
		2:  # Drop
			inv.remove_item(item_id, 1)
			print("[InventoryScreen] Dropped 1 x %s" % item_id)
	_context_slot_index = -1


func _apply_use(item_id: String) -> void:
	# Phase 2: only "bandage" is usable. Heals 30 HP.
	if item_id != "bandage":
		print("[InventoryScreen] %s is not usable yet (Phase 2)" % item_id)
		return
	var inv: Node = get_node_or_null(INVENTORY_PATH)
	if inv == null:
		return
	inv.remove_item("bandage", 1)
	print("[InventoryScreen] Used bandage (heal 30 HP) — HP system lands in Phase 4")


func _add_to_hotbar(item_id: String) -> void:
	# Find the Hotbar in the HUD and assign to the first empty slot.
	var hud: Control = _find_hud()
	if hud == null:
		print("[InventoryScreen] No HUD found; cannot add to hotbar")
		return
	var hb: Node = hud.find_child("Hotbar", true, false)
	if hb == null or not hb.has_method("set_slot"):
		print("[InventoryScreen] No Hotbar in HUD")
		return
	for i in 10:
		if hb.get_slot(i).is_empty():
			hb.set_slot(i, item_id)
			print("[InventoryScreen] Added %s to hotbar slot %d" % [item_id, i + 1])
			return
	print("[InventoryScreen] Hotbar full")


func _find_hud() -> Control:
	# Walk up the tree
	var n: Node = get_parent()
	while n != null:
		if n is Control and n.has_node("Hotbar"):
			return n as Control
		n = n.get_parent()
	return null


func _on_close_pressed() -> void:
	emit_signal("closed")
	queue_free()
