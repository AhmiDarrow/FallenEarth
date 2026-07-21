## HUD — Top-level in-game Character HUD overlay.
##
## v0.4.0 polish: rewritten end-to-end on the MasterTheme design system.
## Every panel, button, label, progress bar, and sub-component comes
## from `UIHelper` or `MasterTheme` so a single token change rolls out
## the new look site-wide. Components:
##
##   - Top bar       : player name, race, class, level, EC (top-left)
##   - Status block  : HP / MP / XP bars grouped beneath the top bar
##   - Minimap       : top-right (local overworld: terrain tints,
##                     category dots, player-direction arrow)
##   - Hotbar        : bottom-centre (InventoryHandler row 0 +
##                     EquipmentManager mainhand overlay)
##   - Help line     : bottom-left, persistent — primary keys
##
## Character menu is opened via keyboard hotkeys (I/E/C/P/S/J).
## Pause menu via Escape. World map via M.
##
## Listens to:
##   - InventoryHandler (inventory_changed) → refresh hotbar
##   - ProgressionManager (xp_changed, level_up, ec_changed) → refresh bars
##   - HubWorld (notify_cell_changed) → refresh minimap
class_name HUD
extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")
const UH = preload("res://scripts/ui/UIHelper.gd")
const MinimapScript = preload("res://scripts/ui/Minimap.gd")
const HotbarScript = preload("res://scripts/ui/Hotbar.gd")

signal character_menu_closed

# Component refs (created in _ready; typed for safety in consumer scripts)
var _top_bar_panel: PanelContainer = null
var _name_label: Label = null
var _class_label: Label = null
var _level_label: Label = null
var _ec_label: Label = null

var _status_panel: PanelContainer = null
var _region_info_label: RichTextLabel = null
var _hp_bar: ProgressBar = null
var _mp_bar: ProgressBar = null
var _xp_bar: ProgressBar = null

var _minimap: Minimap = null
var _hotbar: Hotbar = null

var _help_line_panel: PanelContainer = null
var _help_line: RichTextLabel = null

var _character_menu: Control = null

# Character display data (synced from GameState on _ready + on level_up)
var _display_name: String = "Recruit"
var _display_race: String = "?"
var _display_class: String = "?"


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	# Size matters for anchor math. We don't trust the parent chain
	# (when we're added to a CanvasLayer the parent's "rect" is the
	# viewport itself, but child-control offset math requires a
	# non-zero size). Snap to the viewport rect on _ready.
	var vp_rect := get_viewport_rect()
	if vp_rect.size.x > 0 and vp_rect.size.y > 0:
		size = vp_rect.size
		position = Vector2.ZERO
	else:
		# Fallback if viewport hasn't sized yet — re-sync next frame.
		call_deferred("_sync_to_viewport")

	_build_top_bar()
	_build_status_block()
	_build_minimap()
	_build_help_line()
	_build_hotbar()

	# Keep updating layout when the viewport resizes (window resize,
	# fullscreen toggle, etc.)
	get_viewport().size_changed.connect(_sync_to_viewport)

	_connect_signals()
	_refresh_from_gamestate()


func _sync_to_viewport() -> void:
	var vp_rect := get_viewport_rect()
	if vp_rect.size.x > 0 and vp_rect.size.y > 0:
		size = vp_rect.size
		position = Vector2.ZERO


# ---------------------------------------------------------------------------
# Top bar panel — name / race / class / level / EC
# ---------------------------------------------------------------------------

func _build_top_bar() -> void:
	_top_bar_panel = UH.make_surface_panel()
	_top_bar_panel.name = "TopBarPanel"
	_top_bar_panel.anchor_left = 0.0
	_top_bar_panel.anchor_top = 0.0
	_top_bar_panel.anchor_right = 0.0
	_top_bar_panel.anchor_bottom = 0.0
	_top_bar_panel.offset_left = 12
	_top_bar_panel.offset_top = 12
	_top_bar_panel.offset_right = 480
	_top_bar_panel.offset_bottom = 12 + UIHelper.compute_top_bar_height()
	_top_bar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top_bar_panel)

	var bar := UH.make_hbox(18, true)
	bar.name = "TopBar"
	_top_bar_panel.add_child(bar)
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.offset_left = 12
	bar.offset_top = 8
	bar.offset_right = -12
	bar.offset_bottom = -8
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Name cell (icon accent + value)
	var name_cell := _make_stat_cell("Recruit", MT.FS_H3, MT.TEXT_ACCENT)
	bar.add_child(name_cell)
	_name_label = name_cell.find_child("Value", true, false) as Label

	# Race / Class cell
	var class_cell := _make_stat_cell("?", MT.FS_SMALL, MT.TEXT_SECONDARY)
	bar.add_child(class_cell)
	_class_label = class_cell.find_child("Value", true, false) as Label

	# Level cell
	var level_cell := _make_stat_cell("Lv. 1", MT.FS_H2, Color(1, 0.92, 0.55))
	bar.add_child(level_cell)
	_level_label = level_cell.find_child("Value", true, false) as Label

	# EC cell
	var ec_cell := _make_stat_cell("0 EC", MT.FS_H2, MT.ACCENT_PRIMARY)
	bar.add_child(ec_cell)
	_ec_label = ec_cell.find_child("Value", true, false) as Label


## Stat-cell helper: VBox of an icon-dot accent + a value label.
## The inner "Value" label can be retrieved by name from `_refresh_*` callers.
func _make_stat_cell(value: String, _value_size: int, value_color: Color) -> VBoxContainer:
	var box := UH.make_vbox(-2, false, false)
	box.name = "StatCell"
	box.custom_minimum_size = Vector2(0, UIHelper.compute_top_bar_height() - 16)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_dot := ColorRect.new()
	icon_dot.color = MT.ACCENT_PRIMARY
	icon_dot.custom_minimum_size = Vector2(8, 2)
	box.add_child(icon_dot)
	var value_label := Label.new()
	value_label.name = "Value"
	value_label.text = value
	value_label.add_theme_color_override("font_color", value_color)
	value_label.add_theme_font_size_override("font_size", _value_size)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(value_label)
	return box


# ---------------------------------------------------------------------------
# Status block — HP / MP / XP bars + region info
# ---------------------------------------------------------------------------

func _build_status_block() -> void:
	_status_panel = UH.make_panel(MT.OVERLAY_DARK, MT.BORDER_SUBTLE, MT.RADIUS_MD, 1)
	_status_panel.name = "StatusPanel"
	_status_panel.anchor_left = 0.0
	_status_panel.anchor_top = 0.0
	_status_panel.anchor_right = 0.0
	_status_panel.anchor_bottom = 0.0
	_status_panel.offset_left = 12
	_status_panel.offset_top = 12 + UIHelper.compute_top_bar_height() + 8
	_status_panel.offset_right = 12 + 320
	_status_panel.offset_bottom = 12 + UIHelper.compute_top_bar_height() + 8 + UIHelper.compute_status_block_height()
	_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status_panel)

	# Region info label
	_region_info_label = RichTextLabel.new()
	_region_info_label.name = "RegionInfoLabel"
	_region_info_label.bbcode_enabled = true
	_region_info_label.fit_content = true
	_region_info_label.scroll_active = false
	_region_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_region_info_label.add_theme_color_override("default_color", MT.TEXT_SECONDARY)
	_region_info_label.add_theme_font_size_override("normal_font_size", 11)
	_region_info_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_region_info_label.offset_top = 4
	_region_info_label.offset_left = 8
	_region_info_label.offset_right = -8
	_status_panel.add_child(_region_info_label)

	# Bar strip
	var strip := UH.make_vbox(2, true, false)
	strip.name = "BarStrip"
	strip.set_anchors_preset(Control.PRESET_FULL_RECT)
	strip.offset_left = 6
	strip.offset_top = 30
	strip.offset_right = -6
	strip.offset_bottom = -6
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_panel.add_child(strip)

	_hp_bar = UH.make_progress_bar(0, 16, MT.HP_FILL)
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_bar.custom_minimum_size = Vector2(0, 16)
	strip.add_child(_hp_bar)
	_hp_bar.value = 0
	_hp_bar.max_value = 1

	_mp_bar = UH.make_progress_bar(0, 16, MT.MP_FILL)
	_mp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mp_bar.custom_minimum_size = Vector2(0, 16)
	strip.add_child(_mp_bar)
	_mp_bar.value = 0
	_mp_bar.max_value = 1

	_xp_bar = UH.make_progress_bar(0, 16, MT.XP_FILL)
	_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xp_bar.custom_minimum_size = Vector2(0, 16)
	strip.add_child(_xp_bar)
	_xp_bar.value = 0
	_xp_bar.max_value = 1


# ---------------------------------------------------------------------------
# Minimap — top-right
# ---------------------------------------------------------------------------

func _build_minimap() -> void:
	_minimap = MinimapScript.new()
	_minimap.name = "Minimap"
	_minimap.visible = true
	_minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_minimap.offset_left = -260
	_minimap.offset_top = 12
	_minimap.offset_right = -12
	_minimap.offset_bottom = 12 + 160
	add_child(_minimap)


# ---------------------------------------------------------------------------
# Hotbar — bottom-centre
# ---------------------------------------------------------------------------

func _build_hotbar() -> void:
	_hotbar = HotbarScript.new()
	_hotbar.name = "Hotbar"
	_hotbar.visible = true
	add_child(_hotbar)
	# Apply mod-registered HUD overlays
	_apply_mod_overlays()


# ---------------------------------------------------------------------------
# Help line — bottom-left
# ---------------------------------------------------------------------------

func _build_help_line() -> void:
	_help_line_panel = UH.make_panel(MT.OVERLAY_DARK, Color.TRANSPARENT, MT.RADIUS_MD, 0)
	_help_line_panel.name = "HelpLinePanel"
	_help_line_panel.anchor_left = 0.0
	_help_line_panel.anchor_top = 1.0
	_help_line_panel.anchor_right = 0.0
	_help_line_panel.anchor_bottom = 1.0
	_help_line_panel.offset_left = 12
	_help_line_panel.offset_top = -52
	_help_line_panel.offset_right = 12 + 560
	_help_line_panel.offset_bottom = -12
	_help_line_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_help_line_panel)

	_help_line = RichTextLabel.new()
	_help_line.name = "HelpLine"
	_help_line.bbcode_enabled = true
	_help_line.fit_content = true
	_help_line.scroll_active = false
	_help_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help_line.add_theme_color_override("default_color", MT.TEXT_SECONDARY)
	_help_line.add_theme_font_size_override("normal_font_size", 11)
	_help_line.text = (
		"[b]WASD[/b] move  ·  [b]F[/b] gather/interact  ·  [b]1-0[/b] hotbar  ·  "
		+ "[b]I/E/C/P/S/J[/b] menus  ·  [b]M[/b] map  ·  [b]Esc[/b] pause"
	)
	_help_line.set_anchors_preset(Control.PRESET_FULL_RECT)
	_help_line.offset_left = 14
	_help_line.offset_top = 6
	_help_line.offset_right = -14
	_help_line.offset_bottom = -6
	_help_line_panel.add_child(_help_line)


# ---------------------------------------------------------------------------
# Wire up signal listeners
# ---------------------------------------------------------------------------

func _connect_signals() -> void:
	var prog: Node = get_node_or_null("/root/ProgressionManager")
	if prog != null:
		prog.connect("xp_changed", _on_xp_changed)
		prog.connect("level_up", _on_level_up)
		prog.connect("ec_changed", _on_ec_changed)
	var inv: Node = get_node_or_null("/root/InventoryHandler")
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
	var prog: Node = get_node_or_null("/root/ProgressionManager")
	if prog != null:
		_refresh_level(prog.level, prog.xp, prog.xp_to_next(prog.level))
		_ec_label.text = "%d EC" % prog.ec
	_refresh_minimap()


func refresh_from_gamestate() -> void:
	_refresh_from_gamestate()


func _refresh_level(lvl: int, current_xp: int, xp_to_next: int) -> void:
	_level_label.text = "Lv. %d" % lvl
	if xp_to_next > 0:
		_xp_bar.max_value = xp_to_next
		_xp_bar.value = current_xp
	else:
		_xp_bar.max_value = 1
		_xp_bar.value = 1


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


# ---------------------------------------------------------------------------
# Public API for HubWorld
# ---------------------------------------------------------------------------

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
	var root: Node = get_tree().current_scene
	var layer := CanvasLayer.new()
	layer.name = "CharacterMenuLayer"
	layer.layer = 100
	root.add_child(layer)
	_character_menu.set_meta(&"_menu_layer", layer)
	layer.add_child(_character_menu)
	_character_menu.open(initial_tab)
	visible = false


func _on_character_menu_closed() -> void:
	if _character_menu != null and _character_menu.has_meta(&"_menu_layer"):
		var layer: CanvasLayer = _character_menu.get_meta(&"_menu_layer")
		if is_instance_valid(layer):
			layer.queue_free()
	_character_menu = null
	visible = true
	character_menu_closed.emit()


func notify_cell_changed() -> void:
	_refresh_minimap()


func set_region_info(text: String) -> void:
	if is_instance_valid(_region_info_label):
		_region_info_label.text = text


func get_hotbar() -> Hotbar:
	return _hotbar


func is_character_menu_open() -> bool:
	return _character_menu != null and is_instance_valid(_character_menu)


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
