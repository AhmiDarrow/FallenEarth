## HUD — Top-level in-game Character HUD overlay.
##
## Phase 2. Composes:
##   - Top bar: player name, race, class, level, EC
##   - HP / MP / XP bars (below top bar)
##   - Minimap (top-right)
##   - Hotbar (bottom)
##   - "Menu" button (opens inventory, etc.)
##
## Listens to InventoryManager (inventory_changed), ProgressionManager
## (xp_changed, level_up, ec_changed), and HubWorld (cell_changed for
## the minimap player position).
class_name HUD
extends Control

const TOP_BAR_H := 56.0
const BAR_H := 12.0
const HOTBAR_H := 80.0

signal menu_requested  # emitted when the user clicks "≡ Menu"
signal character_menu_closed

var _name_label: Label
var _class_label: Label
var _level_label: Label
var _ec_label: Label
var _hp_bar: ProgressBar
var _mp_bar: ProgressBar
var _xp_bar: ProgressBar
var _menu_button: Button
var _minimap: Minimap
var _hotbar: Hotbar
var _character_menu: Control = null

# Character display data (synced from GameState on _ready + on level_up)
var _display_name: String = "Recruit"
var _display_race: String = "?"
var _display_class: String = "?"


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_PASS  # let clicks fall through except on UI
	_build_top_bar()
	_build_resource_bars()
	_build_minimap()
	_build_hotbar()
	_build_menu_button()
	_connect_signals()
	_refresh_from_gamestate()


# ---------------------------------------------------------------------------
# Build sub-components
# ---------------------------------------------------------------------------

func _build_top_bar() -> void:
	# Top bar background
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.07, 0.75)
	bg.anchor_right = 1.0
	bg.custom_minimum_size = Vector2(0, TOP_BAR_H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Name (left)
	_name_label = Label.new()
	_name_label.text = _display_name
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.position = Vector2(16, 8)
	add_child(_name_label)

	# Race / Class (under name)
	_class_label = Label.new()
	_class_label.text = "%s · %s" % [_display_race, _display_class]
	_class_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
	_class_label.add_theme_font_size_override("font_size", 12)
	_class_label.position = Vector2(16, 30)
	add_child(_class_label)

	# Level (left-center)
	_level_label = Label.new()
	_level_label.text = "Lv. 1"
	_level_label.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	_level_label.add_theme_font_size_override("font_size", 16)
	_level_label.position = Vector2(360, 16)
	add_child(_level_label)

	# EC (right of level)
	_ec_label = Label.new()
	_ec_label.text = "0 EC"
	_ec_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	_ec_label.add_theme_font_size_override("font_size", 16)
	_ec_label.position = Vector2(440, 16)
	add_child(_ec_label)


func _build_resource_bars() -> void:
	var bar_x: float = 16
	var bar_y: float = TOP_BAR_H + 8
	var bar_w: float = 360
	# HP
	var hp_label := Label.new()
	hp_label.text = "HP"
	hp_label.add_theme_color_override("font_color", Color(0.95, 0.4, 0.4))
	hp_label.position = Vector2(bar_x, bar_y - 2)
	add_child(hp_label)
	_hp_bar = _make_bar(bar_x + 28, bar_y, bar_w - 28, Color(0.7, 0.2, 0.2))
	add_child(_hp_bar)
	bar_y += BAR_H + 4
	# MP
	var mp_label := Label.new()
	mp_label.text = "MP"
	mp_label.add_theme_color_override("font_color", Color(0.5, 0.65, 0.95))
	mp_label.position = Vector2(bar_x, bar_y - 2)
	add_child(mp_label)
	_mp_bar = _make_bar(bar_x + 28, bar_y, bar_w - 28, Color(0.25, 0.4, 0.85))
	add_child(_mp_bar)
	bar_y += BAR_H + 4
	# XP
	var xp_label := Label.new()
	xp_label.text = "XP"
	xp_label.add_theme_color_override("font_color", Color(0.6, 0.95, 0.5))
	xp_label.position = Vector2(bar_x, bar_y - 2)
	add_child(xp_label)
	_xp_bar = _make_bar(bar_x + 28, bar_y, bar_w - 28, Color(0.3, 0.65, 0.25))
	add_child(_xp_bar)


func _make_bar(x: float, y: float, w: float, fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = Vector2(x, y)
	bar.custom_minimum_size = Vector2(w, BAR_H)
	bar.max_value = 100
	bar.value = 100
	bar.show_percentage = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.14, 0.85)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0, 0, 0, 0.6)
	bar.add_theme_stylebox_override("background", style)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	bar.add_theme_stylebox_override("fill", fill_style)
	return bar


func _build_minimap() -> void:
	_minimap = Minimap.new()
	_minimap.name = "Minimap"
	add_child(_minimap)


func _build_hotbar() -> void:
	_hotbar = Hotbar.new()
	_hotbar.name = "Hotbar"
	add_child(_hotbar)


func _build_menu_button() -> void:
	_menu_button = Button.new()
	_menu_button.name = "MenuButton"
	_menu_button.text = "≡ Menu"
	_menu_button.position = Vector2(size.x - 80, 8)
	_menu_button.custom_minimum_size = Vector2(64, 40)
	_menu_button.pressed.connect(_on_menu_pressed)
	add_child(_menu_button)


# ---------------------------------------------------------------------------
# Wire up signal listeners
# ---------------------------------------------------------------------------

func _connect_signals() -> void:
	var prog: Node = get_node_or_null("/root/ProgressionManager")
	if prog != null:
		prog.connect("xp_changed", _on_xp_changed)
		prog.connect("level_up", _on_level_up)
		prog.connect("ec_changed", _on_ec_changed)
	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv != null:
		inv.connect("inventory_changed", _on_inventory_changed)


# ---------------------------------------------------------------------------
# Refresh from GameState
# ---------------------------------------------------------------------------

func _refresh_from_gamestate() -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if gs == null:
		return
	var char_data: Dictionary = gs.get_party_character_data()
	if not char_data.is_empty():
		_display_name = str(char_data.get("name", "Recruit"))
		_display_race = str(char_data.get("race", "?"))
		_display_class = str(char_data.get("class", "?"))
		_name_label.text = _display_name
		_class_label.text = "%s · %s" % [_display_race, _display_class]
	# Progression values
	var prog: Node = get_node_or_null("/root/ProgressionManager")
	if prog != null:
		_refresh_level(prog.level, prog.xp, prog.xp_to_next(prog.level))
		_ec_label.text = "%d EC" % prog.ec
	_refresh_minimap()


func _refresh_level(lvl: int, current_xp: int, xp_to_next: int) -> void:
	_level_label.text = "Lv. %d" % lvl
	if xp_to_next > 0:
		_xp_bar.max_value = xp_to_next
		_xp_bar.value = current_xp
	else:
		_xp_bar.max_value = 1
		_xp_bar.value = 1  # max level


func _refresh_minimap() -> void:
	if is_instance_valid(_minimap):
		_minimap.refresh()


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_xp_changed(current_xp: int, xp_to_next: int) -> void:
	if xp_to_next > 0:
		_xp_bar.max_value = xp_to_next
		_xp_bar.value = current_xp


func _on_level_up(new_level: int, _levels_gained: int) -> void:
	_level_label.text = "Lv. %d" % new_level


func _on_ec_changed(current_ec: int) -> void:
	_ec_label.text = "%d EC" % current_ec


func _on_inventory_changed() -> void:
	# Hotbar will re-read on its own; we just trigger a redraw of the
	# top bar / minimap etc.
	pass


func _on_menu_pressed() -> void:
	emit_signal("menu_requested")
	open_character_menu()


## Open the CharacterMenu (tabbed shell). Called by HubWorld when the
## "≡ Menu" button is clicked or when a character-screen hotkey fires
## (I/E/C/P/S). Idempotent: a second open of the same tab closes
## the menu.
func open_character_menu(initial_tab: String = "inventory") -> void:
	if _character_menu != null and is_instance_valid(_character_menu):
		# Already open. Toggle off if the same tab is requested.
		if _character_menu.has_method("get_active_tab") and _character_menu.get_active_tab() == initial_tab:
			_character_menu.close_menu()
			return
		# Otherwise switch to the new tab.
		_character_menu.select_tab(initial_tab)
		return
	var script: GDScript = load("res://scripts/ui/CharacterMenu.gd")
	if script == null:
		push_error("[HUD] CharacterMenu.gd not found")
		return
	_character_menu = script.new()
	_character_menu.name = "CharacterMenu"
	_character_menu.closed.connect(_on_character_menu_closed)
	add_child(_character_menu)
	_character_menu.select_tab(initial_tab)


func _on_character_menu_closed() -> void:
	_character_menu = null
	emit_signal("character_menu_closed")


# ---------------------------------------------------------------------------
# Public API for HubWorld
# ---------------------------------------------------------------------------

## Called by HubWorld on cell change so the minimap highlights correctly.
func notify_cell_changed() -> void:
	_refresh_minimap()


## Returns the hotbar (or null if not yet ready).
func get_hotbar() -> Hotbar:
	return _hotbar


## Returns true if the character menu is currently open.
func is_character_menu_open() -> bool:
	return _character_menu != null and is_instance_valid(_character_menu)
