## HUD — Top-level in-game Character HUD overlay.
##
## Phase 2. Composes:
##   - Top bar: player name, race, class, level, EC
##   - HP / MP / XP bars (below top bar)
##   - Minimap (top-right)
##   - Hotbar (bottom)
##
## The character menu is opened via keyboard hotkeys (I/E/C/P/S/J).
## Menu and Save are accessed from the pause menu (Escape).
## World map has a dedicated hotkey (M).
##
## Listens to InventoryManager (inventory_changed), ProgressionManager
## (xp_changed, level_up, ec_changed), and HubWorld (cell_changed for
## the minimap player position).
class_name HUD
extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")

const TOP_BAR_H := 48.0
const BAR_H := 16.0
const BAR_W := 220.0
const HOTBAR_H := 80.0

signal character_menu_closed

var _name_label: Label
var _class_label: Label
var _level_label: Label
var _ec_label: Label
var _hp_bar: ProgressBar
var _mp_bar: ProgressBar
var _xp_bar: ProgressBar
var _minimap: Minimap
var _hotbar: Hotbar
var _region_info_label: Label
var _character_menu: Control = null

# Character display data (synced from GameState on _ready + on level_up)
var _display_name: String = "Recruit"
var _display_race: String = "?"
var _display_class: String = "?"


func _ready() -> void:
	# Anchor to fill parent (Full Rect), then sync size after first layout pass
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_top_bar()
	_build_resource_bars()
	_build_minimap()
	_build_hotbar()
	# Connect to parent resized so we resize when the viewport changes
	var parent := get_parent()
	if parent is Control:
		if not (parent as Control).resized.is_connected(_on_parent_resized):
			(parent as Control).resized.connect(_on_parent_resized)
	# Defer size sync so the parent Control has completed its layout
	_sync_size_to_parent.call_deferred()
	_connect_signals()
	_refresh_from_gamestate()


## Snap our `size` to the parent Control's rect. Required because we
## are added as a child of a non-Container Control and the engine
## doesn't auto-size us from anchors alone in every setup.
func _sync_size_to_parent() -> void:
	var parent := get_parent()
	if parent is Control:
		var p: Control = parent as Control
		if p.size.x > 0 and p.size.y > 0:
			size = p.size
			position = Vector2.ZERO


## Re-sync our size when the parent resizes.
func _on_parent_resized() -> void:
	_sync_size_to_parent()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_size_to_parent()


# ---------------------------------------------------------------------------
# Build sub-components
# ---------------------------------------------------------------------------

func _build_top_bar() -> void:
	# Top bar background — limited to left 45% to prevent bleed into center
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.07, 0.85)
	bg.anchor_left = 0.0
	bg.anchor_top = 0.0
	bg.anchor_right = 0.45
	bg.anchor_bottom = 0.0
	bg.offset_bottom = TOP_BAR_H
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Name (left)
	_name_label = Label.new()
	_name_label.text = _display_name
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.anchor_left = 0.0
	_name_label.anchor_top = 0.0
	_name_label.offset_left = 16
	_name_label.offset_top = 8
	add_child(_name_label)

	# Race / Class (under name)
	_class_label = Label.new()
	_class_label.text = "%s · %s" % [_display_race, _display_class]
	_class_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
	_class_label.add_theme_font_size_override("font_size", 12)
	_class_label.anchor_left = 0.0
	_class_label.anchor_top = 0.0
	_class_label.offset_left = 16
	_class_label.offset_top = 30
	add_child(_class_label)

	# Level (right of name in top bar)
	_level_label = Label.new()
	_level_label.text = "Lv. 1"
	_level_label.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	_level_label.add_theme_font_size_override("font_size", 14)
	_level_label.anchor_left = 0.0
	_level_label.anchor_top = 0.0
	_level_label.offset_left = 180
	_level_label.offset_top = 8
	add_child(_level_label)

	# EC (right of level in top bar)
	_ec_label = Label.new()
	_ec_label.text = "0 EC"
	_ec_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	_ec_label.add_theme_font_size_override("font_size", 14)
	_ec_label.anchor_left = 0.0
	_ec_label.anchor_top = 0.0
	_ec_label.offset_left = 260
	_ec_label.offset_top = 8
	add_child(_ec_label)


func _build_resource_bars() -> void:
	# Container background for the bar group — centered in the top-left area
	var bar_group := PanelContainer.new()
	bar_group.anchor_left = 0.0
	bar_group.anchor_top = 0.0
	bar_group.anchor_right = 0.0
	bar_group.anchor_bottom = 0.0
	bar_group.offset_left = 12
	bar_group.offset_top = TOP_BAR_H + 4
	bar_group.offset_right = 12 + BAR_W + 20
	bar_group.offset_bottom = TOP_BAR_H + 4 + BAR_H * 3 + 16
	bar_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.04, 0.04, 0.06, 0.45)
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	bar_group.add_theme_stylebox_override("panel", bg_style)
	add_child(bar_group)

	# Region info label (inside bar group, top)
	_region_info_label = Label.new()
	_region_info_label.text = ""
	_region_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_region_info_label.anchor_left = 0.0
	_region_info_label.anchor_top = 0.0
	_region_info_label.offset_left = 16
	_region_info_label.offset_top = TOP_BAR_H + 6
	_region_info_label.add_theme_font_size_override("font_size", 10)
	_region_info_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	add_child(_region_info_label)

	var bar_x := 20
	var bar_y: float = TOP_BAR_H + 22

	# HP
	var hp_label := Label.new()
	hp_label.text = "HP"
	hp_label.add_theme_color_override("font_color", Color(0.95, 0.4, 0.4))
	hp_label.add_theme_font_size_override("font_size", 10)
	hp_label.anchor_left = 0.0
	hp_label.anchor_top = 0.0
	hp_label.offset_left = bar_x
	hp_label.offset_top = bar_y + 1
	add_child(hp_label)
	_hp_bar = _make_bar(bar_x + 26, bar_y, BAR_W, Color(0.75, 0.2, 0.2))
	add_child(_hp_bar)
	bar_y += BAR_H + 4

	# MP
	var mp_label := Label.new()
	mp_label.text = "MP"
	mp_label.add_theme_color_override("font_color", Color(0.5, 0.65, 0.95))
	mp_label.add_theme_font_size_override("font_size", 10)
	mp_label.anchor_left = 0.0
	mp_label.anchor_top = 0.0
	mp_label.offset_left = bar_x
	mp_label.offset_top = bar_y + 1
	add_child(mp_label)
	_mp_bar = _make_bar(bar_x + 26, bar_y, BAR_W, Color(0.3, 0.45, 0.9))
	add_child(_mp_bar)
	bar_y += BAR_H + 4

	# XP
	var xp_label := Label.new()
	xp_label.text = "XP"
	xp_label.add_theme_color_override("font_color", Color(0.6, 0.95, 0.5))
	xp_label.add_theme_font_size_override("font_size", 10)
	xp_label.anchor_left = 0.0
	xp_label.anchor_top = 0.0
	xp_label.offset_left = bar_x
	xp_label.offset_top = bar_y + 1
	add_child(xp_label)
	_xp_bar = _make_bar(bar_x + 26, bar_y, BAR_W, Color(0.35, 0.7, 0.25))
	add_child(_xp_bar)


func _make_bar(offset_left: float, offset_top: float, bar_width: float, fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.anchor_left = 0.0
	bar.anchor_top = 0.0
	bar.offset_left = offset_left
	bar.offset_top = offset_top
	bar.anchor_right = 0.0
	bar.offset_right = offset_left + bar_width
	bar.custom_minimum_size = Vector2(80, BAR_H)
	bar.max_value = 100
	bar.value = 100
	bar.show_percentage = true

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.08, 0.1, 0.9)
	bg_style.border_width_left = 1
	bg_style.border_width_right = 1
	bg_style.border_width_top = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color(0.2, 0.2, 0.22, 0.8)
	bg_style.corner_radius_top_left = 3
	bg_style.corner_radius_top_right = 3
	bg_style.corner_radius_bottom_left = 3
	bg_style.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("fill", fill_style)

	return bar


func _build_minimap() -> void:
	_minimap = Minimap.new()
	_minimap.name = "Minimap"
	_minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_minimap.offset_left = -220
	_minimap.offset_top = 20
	_minimap.offset_right = -20
	_minimap.offset_bottom = 220
	# Try to parent inside MinimapPanel (sibling under UI_Canvas)
	var parent_ctrl := get_parent()  # UI_Canvas
	if parent_ctrl != null:
		var panel := parent_ctrl.get_node_or_null("MinimapPanel") as Control
		if panel != null:
			panel.add_child(_minimap)
			return
	# Fallback: add directly to HUD
	add_child(_minimap)


func _build_hotbar() -> void:
	_hotbar = Hotbar.new()
	_hotbar.name = "Hotbar"
	add_child(_hotbar)
	# Apply mod-registered HUD overlays
	_apply_mod_overlays()





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
	if is_instance_valid(_hotbar) and _hotbar.has_method("refresh"):
		_hotbar.refresh()


## Open the CharacterMenu (tabbed shell). Called by HubWorld when a
## character-screen hotkey fires (I/E/C/P/S/J). Idempotent: a second
## open of the same tab closes the menu.
##
## Mirrors the `PauseMenu` pattern: the menu is loaded from its
## dedicated scene (`scenes/ui/CharacterMenu.tscn`) and added to a
## `CanvasLayer` so it overlays everything, including the pause menu.
## The menu's own `open()` method handles sizing and z-order.
func open_character_menu(initial_tab: String = "inventory") -> void:
	if _character_menu != null and is_instance_valid(_character_menu):
		if _character_menu.has_method("get_active_tab") and _character_menu.get_active_tab() == initial_tab:
			_character_menu.close_menu()
			return
		_character_menu.select_tab(initial_tab)
		return
	var scene: PackedScene = load("res://scenes/ui/CharacterMenu.tscn") as PackedScene
	if scene == null:
		push_error("[HUD] CharacterMenu.tscn not found")
		return
	_character_menu = scene.instantiate() as CharacterMenu
	if _character_menu == null:
		push_error("[HUD] CharacterMenu scene root is not a CharacterMenu")
		return
	_character_menu.name = "CharacterMenu"
	_character_menu.closed.connect(_on_character_menu_closed)

	# Parent CanvasLayer to the root scene so the menu is independent of HUD.
	# Same layer as UI_Canvas (100); added later so renders on top.
	var root: Node = get_tree().current_scene
	var layer := CanvasLayer.new()
	layer.name = "CharacterMenuLayer"
	layer.layer = 100
	root.add_child(layer)
	_character_menu.set_meta(&"_menu_layer", layer)
	layer.add_child(_character_menu)
	_character_menu.open(initial_tab)

	# Hide HUD elements while the menu is open.
	visible = false


func _on_character_menu_closed() -> void:
	if _character_menu != null and _character_menu.has_meta(&"_menu_layer"):
		var layer: CanvasLayer = _character_menu.get_meta(&"_menu_layer")
		if is_instance_valid(layer):
			layer.queue_free()
	_character_menu = null
	visible = true
	character_menu_closed.emit()


# ---------------------------------------------------------------------------
# Public API for HubWorld
# ---------------------------------------------------------------------------

## Called by HubWorld on cell change so the minimap highlights correctly.
func notify_cell_changed() -> void:
	_refresh_minimap()


## Called by HubWorld to update the region info text (biome, mob count, etc.)
## shown between the top bar and resource bars.
func set_region_info(text: String) -> void:
	if is_instance_valid(_region_info_label):
		_region_info_label.text = text


## Returns the hotbar (or null if not yet ready).
func get_hotbar() -> Hotbar:
	return _hotbar


## Returns true if the character menu is currently open.
func is_character_menu_open() -> bool:
	return _character_menu != null and is_instance_valid(_character_menu)


## Add mod-registered overlay scenes to the HUD
func _apply_mod_overlays() -> void:
	var mod_api := get_node_or_null("/root/ModAPI")
	if mod_api == null:
		return
	var overlays: Array = mod_api.get_extensions("hud_overlays")
	for overlay in overlays:
		if not ResourceLoader.exists(overlay.scene_path):
			push_warning("[HUD] Mod overlay scene not found: %s" % overlay.scene_path)
			continue
		var scene = load(overlay.scene_path).instantiate()
		scene.name = "ModOverlay_%s" % overlay.id
		match overlay.anchor:
			"top_right":
				scene.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			"bottom_left":
				scene.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
			"bottom_right":
				scene.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			"center":
				scene.set_anchors_preset(Control.PRESET_CENTER)
		add_child(scene)
