## CharacterMenu — Tabbed shell for all character screens.
##
## Hosts the Inventory, Equipment, Crafting, Party, and Stats tabs.
## A single instance is opened by the HUD "≡ Menu" button or by the
## keyboard hotkeys (I, E, C, P, S). Tab buttons at the top swap the
## content area beneath. Tab state is preserved when switching (e.g.
## Inventory's selected item is not lost when you peek at the Party tab).
##
## Keyboard:
##   - I, E, C, P, S: open the corresponding tab (or close the menu if
##     that tab is already active)
##   - Tab / Shift+Tab: cycle forward / backward through tabs
##   - Escape: close the menu
##
## The content area is a `PanelContainer` whose children are the
## individual screen Controls. Only the active tab's screen is visible
## at a time (others are hidden, not freed, so their state is preserved).
class_name CharacterMenu
extends Control

signal closed

const TABS := [
	{"id": "inventory", "label": "Inventory", "key": KEY_I},
	{"id": "equipment", "label": "Equipment", "key": KEY_E},
	{"id": "crafting",  "label": "Crafting",  "key": KEY_C},
	{"id": "party",     "label": "Party",     "key": KEY_P},
	{"id": "stats",     "label": "Stats",     "key": KEY_S},
]

const SCREEN_PATHS := {
	"inventory": "res://scripts/ui/InventoryScreen.gd",
	"equipment": "res://scripts/ui/EquipmentScreen.gd",
	"crafting":  "res://scripts/ui/CraftingScreen.gd",
	"party":     "res://scripts/ui/PartyScreen.gd",
	"stats":     "res://scripts/ui/StatsScreen.gd",
}

# Each tab's loaded Control (instantiated lazily on first open)
var _tab_controllers: Dictionary = {}
# Map tab id -> Button
var _tab_buttons: Dictionary = {}
# Currently active tab id
var _active_tab: String = ""
# Container for the content
var _content: Control = null


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50  # Ensure menu draws on top of HUD
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04, 0.92)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# Title
	var title := Label.new()
	title.text = "[ Character ]"
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_font_size_override("font_size", 28)
	title.position = Vector2(20, 12)
	add_child(title)
	# Close X
	var close := Button.new()
	close.text = "X"
	close.position = Vector2(size.x - 60, 12)
	close.custom_minimum_size = Vector2(40, 40)
	close.pressed.connect(close_menu)
	add_child(close)
	# Tab bar
	_build_tab_bar()
	# Content area
	_content = PanelContainer.new()
	_content.position = Vector2(20, 80)
	_content.size = Vector2(size.x - 40, size.y - 100)
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_content)
	# Open the inventory tab by default
	select_tab("inventory")


func _build_tab_bar() -> void:
	var bar := HBoxContainer.new()
	bar.name = "TabBar"
	bar.position = Vector2(20, 56)
	bar.add_theme_constant_override("separation", 4)
	add_child(bar)
	for tab in TABS:
		var btn := Button.new()
		btn.name = "Tab_%s" % tab.id
		btn.text = "%s [%s]" % [tab.label, OS.get_keycode_string(tab.key).replace("KEY_", "")]
		btn.custom_minimum_size = Vector2(140, 28)
		btn.toggle_mode = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(_on_tab_button_pressed.bind(tab.id))
		bar.add_child(btn)
		_tab_buttons[tab.id] = btn


func _on_tab_button_pressed(tab_id: String) -> void:
	# If the tab is already active, this button-press is a toggle-off.
	if _active_tab == tab_id:
		close_menu()
		return
	select_tab(tab_id)


## Open the given tab. Lazy-loads the tab's screen Control on first use.
func select_tab(tab_id: String) -> void:
	var found: bool = false
	for tab in TABS:
		if tab.id == tab_id:
			found = true
			break
	if not found:
		push_warning("[CharacterMenu] Unknown tab: %s" % tab_id)
		return
	# Deactivate old tab
	if _active_tab != "" and _tab_controllers.has(_active_tab):
		var old_screen: Control = _tab_controllers[_active_tab]
		old_screen.visible = false
	if _tab_buttons.has(_active_tab):
		_tab_buttons[_active_tab].button_pressed = false
	# Activate new tab
	_active_tab = tab_id
	if not _tab_controllers.has(tab_id):
		_lazy_load_tab(tab_id)
	_tab_controllers[tab_id].visible = true
	_tab_buttons[tab_id].button_pressed = true
	print("[CharacterMenu] Active tab: %s" % tab_id)


func _lazy_load_tab(tab_id: String) -> void:
	var path: String = SCREEN_PATHS.get(tab_id, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		# Placeholder for tabs that don't have a screen yet (e.g. Equipment
		# in Phase 3 ships as Phase 4; Stats ships in Phase 4).
		var ph := Label.new()
		ph.text = "(%s screen lands in Phase 4)" % tab_id.capitalize()
		ph.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		ph.add_theme_font_size_override("font_size", 18)
		ph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ph.anchor_right = 1.0
		ph.anchor_bottom = 1.0
		_content.add_child(ph)
		_tab_controllers[tab_id] = ph
		return
	var script: GDScript = load(path) as GDScript
	if script == null:
		push_error("[CharacterMenu] Failed to load tab script: %s" % path)
		return
	var screen = script.new()
	screen.anchor_right = 1.0
	screen.anchor_bottom = 1.0
	screen.name = "Screen_" + tab_id
	screen.mouse_filter = Control.MOUSE_FILTER_PASS
	_content.add_child(screen)
	_tab_controllers[tab_id] = screen


func get_active_tab() -> String:
	return _active_tab


func close_menu() -> void:
	emit_signal("closed")
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	var km: Node = get_node_or_null("/root/KeybindManager")

	# Tab / Shift+Tab cycle
	if (km != null and km.is_action_pressed("tab_next", event)) or event.keycode == KEY_TAB:
		var dir: int = -1 if event.shift_pressed else 1
		var current_idx: int = -1
		for i in TABS.size():
			if TABS[i].id == _active_tab:
				current_idx = i
				break
		if current_idx >= 0:
			var next_idx: int = (current_idx + dir) % TABS.size()
			if next_idx < 0:
				next_idx += TABS.size()
			select_tab(TABS[next_idx].id)
			get_viewport().set_input_as_handled()
		return
	# Escape closes
	if (km != null and km.is_action_pressed("pause_menu", event)) or event.keycode == KEY_ESCAPE:
		close_menu()
		get_viewport().set_input_as_handled()
		return
	# Character tab hotkeys via KeybindManager
	if km != null:
		if km.is_action_pressed("inventory", event):
			select_tab("inventory")
			get_viewport().set_input_as_handled()
			return
		if km.is_action_pressed("equipment", event):
			select_tab("equipment")
			get_viewport().set_input_as_handled()
			return
		if km.is_action_pressed("crafting", event):
			select_tab("crafting")
			get_viewport().set_input_as_handled()
			return
		if km.is_action_pressed("party", event):
			select_tab("party")
			get_viewport().set_input_as_handled()
			return
		if km.is_action_pressed("stats", event):
			select_tab("stats")
			get_viewport().set_input_as_handled()
			return
	# Fallback: hardcoded keys
	for tab in TABS:
		if event.keycode == tab.key:
			select_tab(tab.id)
			get_viewport().set_input_as_handled()
			return
