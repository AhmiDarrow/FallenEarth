## CharacterMenu — Tabbed shell for all character screens.
##
## Hosts the Inventory, Equipment, Crafting, Jobs, Party, and Stats tabs.
## A single instance is opened by the keyboard hotkeys (I, E, C, J, P, S).
## Tab buttons at the top swap the content area beneath. Tab state is
## preserved when switching (e.g. Inventory's selected item is not lost
## when you peek at the Party tab).
##
## Keyboard:
##   - I, E, C, J, P, S: open the corresponding tab (or close the menu if
##     that tab is already active)
##   - Tab / Shift+Tab: cycle forward / backward through tabs
##   - Escape: close the menu
##
## Architecture: this Control is a SCENE (`scenes/ui/CharacterMenu.tscn`)
## with the shell layout (background, title, close X, tab bar, content
## panel) defined up-front and the dynamic tab content (the per-tab
## screen Controls) lazy-loaded by the script. The shell mirrors the
## `PauseMenu` pattern: an `.tscn` with `anchors_preset = 15` and
## `grow_horizontal/vertical = 2`, plus an `open(initial_tab)` method
## that explicitly sets `size = viewport_size` so the menu is correctly
## sized whether its parent is a Container or a plain Control.
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
	{"id": "jobs",      "label": "Jobs",      "key": KEY_J},
	{"id": "party",     "label": "Party",     "key": KEY_P},
	{"id": "stats",     "label": "Stats",     "key": KEY_S},
]

const SCREEN_PATHS := {
	"inventory": "res://scripts/ui/InventoryScreen.gd",
	"equipment": "res://scripts/ui/EquipmentScreen.gd",
	"crafting":  "res://scripts/ui/CraftingScreen.gd",
	"jobs":      "res://scripts/ui/JobsScreen.gd",
	"party":     "res://scripts/ui/PartyScreen.gd",
	"stats":     "res://scripts/ui/StatsScreen.gd",
}

# Scene references (resolved by Godot from the .tscn at load time).
# These are `@onready` so they're resolved after the scene's children
# are added. If the script is instantiated without the scene (e.g.
# from a smoke test via `script.new()`), they will be null and the
# defensive build in `_ready` constructs them on the fly.
@onready var _background: ColorRect = get_node_or_null("Background") as ColorRect
@onready var _title_label: Label = get_node_or_null("TitleLabel") as Label
@onready var _close_btn: Button = get_node_or_null("CloseButton") as Button
@onready var _tab_bar: HBoxContainer = get_node_or_null("TabBar") as HBoxContainer
@onready var _content: PanelContainer = get_node_or_null("ContentPanel") as PanelContainer

# Each tab's loaded Control (instantiated lazily on first open)
var _tab_controllers: Dictionary = {}
# Map tab id -> Button
var _tab_buttons: Dictionary = {}
# Currently active tab id
var _active_tab: String = ""


func _ready() -> void:
	# Process even when the game is paused (so Escape / I / E / C / P
	# / S keys reach us). Mirrors PauseMenu's `process_mode`.
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50
	# If we were instantiated via `script.new()` (e.g. in a smoke
	# test), the @onready scene references will be null. Build the
	# shell on the fly so the script works either way. In production
	# the .tscn provides the shell and these no-op.
	_ensure_shell()
	# Connect shell buttons
	if _close_btn != null and not _close_btn.pressed.is_connected(close_menu):
		_close_btn.pressed.connect(close_menu)
	_build_tab_bar()
	# Open the inventory tab by default. `open()` will also call
	# `select_tab(initial_tab)` for the scene-loaded case (the HUD
	# always invokes `open` after instantiating the scene), so this
	# default covers both paths.
	if _active_tab == "":
		select_tab("inventory")


## Build the shell (background, title, close X, tab bar, content
## panel) on the fly if it isn't already there (i.e. when the script
## is instantiated without its scene). Idempotent.
func _ensure_shell() -> void:
	if _background == null:
		_background = ColorRect.new()
		_background.name = "Background"
		_background.color = Color(0.02, 0.02, 0.04, 0.92)
		_background.set_anchors_preset(Control.PRESET_FULL_RECT)
		_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_background)
	if _title_label == null:
		_title_label = Label.new()
		_title_label.name = "TitleLabel"
		_title_label.text = "[ Character ]"
		_title_label.add_theme_color_override("font_color", Color.WHITE)
		_title_label.add_theme_font_size_override("font_size", 28)
		_title_label.position = Vector2(20, 12)
		add_child(_title_label)
	if _close_btn == null:
		_close_btn = Button.new()
		_close_btn.name = "CloseButton"
		_close_btn.text = "X"
		_close_btn.custom_minimum_size = Vector2(40, 40)
		add_child(_close_btn)
	if _tab_bar == null:
		_tab_bar = HBoxContainer.new()
		_tab_bar.name = "TabBar"
		_tab_bar.position = Vector2(20, 56)
		_tab_bar.add_theme_constant_override("separation", 4)
		add_child(_tab_bar)
	if _content == null:
		_content = PanelContainer.new()
		_content.name = "ContentPanel"
		_content.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(_content)


## Open the menu to the given tab. Mirrors PauseMenu.open(): explicitly
## size the shell to the viewport so the layout is correct regardless
## of whether the parent is a Container or a plain Control.
func open(initial_tab: String = "inventory") -> void:
	# Force full-viewport geometry since parent may not propagate layout
	var vp_size: Vector2 = get_viewport_rect().size
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = vp_size
	size = vp_size
	position = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50
	move_to_front()
	visible = true
	# Select the requested tab (this is the first time, so the screen
	# gets lazy-loaded). Also re-selects the same tab if the user
	# presses the hotkey again while the menu is open.
	if not _tab_controllers.has(initial_tab):
		_lazy_load_tab(initial_tab)
	select_tab(initial_tab)


func _build_tab_bar() -> void:
	if _tab_bar == null:
		return
	for tab in TABS:
		var btn := Button.new()
		btn.name = "Tab_%s" % tab.id
		btn.text = "%s [%s]" % [tab.label, OS.get_keycode_string(tab.key).replace("KEY_", "")]
		btn.custom_minimum_size = Vector2(140, 28)
		btn.toggle_mode = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(_on_tab_button_pressed.bind(tab.id))
		_tab_bar.add_child(btn)
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
		if km.is_action_pressed("jobs", event):
			select_tab("jobs")
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
