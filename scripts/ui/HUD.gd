## HUD — Top-level in-game Character HUD overlay.
##
## v0.4.0 polish: rewritten with BoxContainer / VBoxContainer layout so
## the panel scales with viewport size. Composes:
##   - Top bar:    player name, race, class, level, EC (top-left)
##   - Status:     HP / MP / XP bars grouped beneath the top bar
##   - Minimap:    top-right (local overworld: terrain tints, category
##                 dots, player-direction triangle)
##   - Hotbar:     bottom-centre (InventoryHandler row 0 +
##                 EquipmentManager mainhand overlay)
##   - Help line:  bottom-left, persistent — primary keys
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

const TOP_BAR_H := 56.0
const BAR_H := 18.0
const BAR_W := 240.0
const HELP_LINE_H := 30.0

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
var _help_line: RichTextLabel
var _character_menu: Control = null

# Character display data (synced from GameState on _ready + on level_up)
var _display_name: String = "Recruit"
var _display_race: String = "?"
var _display_class: String = "?"


func _ready() -> void:
	# Fill parent rect so the HUD occupies the entire viewport.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

	# Build all sub-components. Each builder parents into the appropriate
	# area of the HUD; no BoxContainer integrator here because the
	# sub-components anchor themselves to specific corners.
	_build_top_bar()
	_build_status_block()
	_build_minimap()
	_build_help_line()
	_build_hotbar()

	# Connect to parent resized so we resize when the viewport changes.
	var parent := get_parent()
	if parent is Control:
		if not (parent as Control).resized.is_connected(_on_parent_resized):
			(parent as Control).resized.connect(_on_parent_resized)
	_sync_size_to_parent.call_deferred()
	_connect_signals()
	_refresh_from_gamestate()


## Snap our `size` to the parent Control's rect. Required because we are
## added as a child of a non-Container Control.
func _sync_size_to_parent() -> void:
	var parent := get_parent()
	if parent is Control:
		var p: Control = parent as Control
		if p.size.x > 0 and p.size.y > 0:
			size = p.size
			position = Vector2.ZERO


func _on_parent_resized() -> void:
	_sync_size_to_parent()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_size_to_parent()


# ---------------------------------------------------------------------------
# Top bar — name / race / class / level / EC
# ---------------------------------------------------------------------------

func _build_top_bar() -> void:
	# Top bar background panel: anchored top-left, stretches 60% of width.
	var bg := Panel.new()
	bg.name = "TopBarBG"
	var sb := StyleBoxFlat.new()
	sb.bg_color = MT.OVERLAY_DARK
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_right = 6
	sb.corner_radius_bottom_left = 6
	bg.add_theme_stylebox_override("panel", sb)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.anchor_left = 0.0
	bg.anchor_top = 0.0
	bg.anchor_right = 0.6
	bg.anchor_bottom = 0.0
	bg.offset_left = 8
	bg.offset_top = 8
	bg.offset_right = -8
	bg.offset_bottom = TOP_BAR_H - 4
	add_child(bg)

	# Inner HBoxContainer lays out the four info cells auto-sized.
	var bar := HBoxContainer.new()
	bar.name = "TopBar"
	bg.add_child(bar)
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.offset_left = 8
	bar.offset_top = 4
	bar.offset_right = -8
	bar.offset_bottom = -4
	bar.add_theme_constant_override("separation", 18)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Name cell (icon: silhouette)
	var name_box := _make_stat_cell("Recruit", MT.FS_H3, MT.TEXT_ACCENT)
	bar.add_child(name_box)
	_name_label = name_box.find_child("Value", true, false) as Label

	# Race / Class cell
	var class_box := _make_stat_cell("?", MT.FS_SMALL, MT.TEXT_SECONDARY)
	bar.add_child(class_box)
	_class_label = class_box.find_child("Value", true, false) as Label

	# Level cell
	var level_box := _make_stat_cell("Lv. 1", MT.FS_H2, Color(1, 0.92, 0.55))
	bar.add_child(level_box)
	_level_label = level_box.find_child("Value", true, false) as Label

	# EC cell
	var ec_box := _make_stat_cell("0 EC", MT.FS_H2, MT.ACCENT_PRIMARY)
	bar.add_child(ec_box)
	_ec_label = ec_box.find_child("Value", true, false) as Label


## Stat-cell helper: VBox of two labels (small icon, larger value). The
## inner "Value" label can be retrieved by name from `_refresh_*` callers.
func _make_stat_cell(value: String, _value_size: int, value_color: Color) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(0, TOP_BAR_H - 16)
	box.add_theme_constant_override("separation", -2)
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
	box.add_child(value_label)
	return box


# ---------------------------------------------------------------------------
# Status block — HP / MP / XP bars + region info
# ---------------------------------------------------------------------------

func _build_status_block() -> void:
	# Status panel (background)
	var panel := Panel.new()
	panel.name = "StatusPanel"
	var sb := StyleBoxFlat.new()
	sb.bg_color = MT.OVERLAY_DARK
	sb.border_color = MT.BORDER_SUBTLE
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	sb.corner_radius_bottom_left = 4
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 8
	panel.offset_top = TOP_BAR_H + 8
	panel.offset_right = 8 + BAR_W + 64
	panel.offset_bottom = TOP_BAR_H + 4 + (BAR_H + 2) * 3 + 18
	add_child(panel)

	# Region info label (top of the status panel)
	_region_info_label = UH.make_label("", 10, MT.TEXT_SECONDARY)
	_region_info_label.name = "RegionInfoLabel"
	_region_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_region_info_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_region_info_label.offset_top = 4
	_region_info_label.offset_left = 8
	_region_info_label.offset_right = -8
	panel.add_child(_region_info_label)

	# Inner VBox for the three bars, anchored below region label
	var strip := VBoxContainer.new()
	strip.name = "BarStrip"
	strip.set_anchors_preset(Control.PRESET_FULL_RECT)
	strip.offset_left = 6
	strip.offset_top = 22
	strip.offset_right = -6
	strip.offset_bottom = -6
	strip.add_theme_constant_override("separation", 2)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(strip)

	_hp_bar = _make_bar(BAR_W, MT.HP_FILL)
	strip.add_child(_hp_bar)
	_hp_bar.value = 0
	_hp_bar.max_value = 1

	_mp_bar = _make_bar(BAR_W, MT.MP_FILL)
	strip.add_child(_mp_bar)
	_mp_bar.value = 0
	_mp_bar.max_value = 1

	_xp_bar = _make_bar(BAR_W, MT.XP_FILL)
	strip.add_child(_xp_bar)
	_xp_bar.value = 0
	_xp_bar.max_value = 1


func _make_bar(bar_width: float, fill_color: Color) -> ProgressBar:
	var bar := UH.make_progress_bar(int(bar_width), BAR_H, fill_color)
	bar.custom_minimum_size = Vector2(bar_width, BAR_H)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return bar


# ---------------------------------------------------------------------------
# Minimap — top-right
# ---------------------------------------------------------------------------

func _build_minimap() -> void:
	_minimap = Minimap.new()
	_minimap.name = "Minimap"
	# v0.4.0 polish: terrain tints, category dots, player-direction arrow.
	# 240x160 panel anchored top-right (~6% side margins).
	_minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_minimap.offset_left = -260
	_minimap.offset_top = 8
	_minimap.offset_right = -8
	_minimap.offset_bottom = 232
	add_child(_minimap)


# ---------------------------------------------------------------------------
# Hotbar — bottom-centre
# ---------------------------------------------------------------------------

func _build_hotbar() -> void:
	_hotbar = Hotbar.new()
	_hotbar.name = "Hotbar"
	add_child(_hotbar)
	# Apply mod-registered HUD overlays
	_apply_mod_overlays()


# ---------------------------------------------------------------------------
# Help line — bottom-left
# ---------------------------------------------------------------------------

func _build_help_line() -> void:
	var bg := Panel.new()
	bg.name = "HelpLineBG"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.06, 0.6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	sb.corner_radius_bottom_left = 4
	bg.add_theme_stylebox_override("panel", sb)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.anchor_left = 0.0
	bg.anchor_top = 1.0
	bg.anchor_right = 0.0
	bg.anchor_bottom = 1.0
	bg.offset_left = 8
	bg.offset_top = -HELP_LINE_H - 6
	bg.offset_right = 560
	bg.offset_bottom = -4
	add_child(bg)

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
	_help_line.anchor_left = 0.0
	_help_line.anchor_top = 1.0
	_help_line.anchor_right = 0.0
	_help_line.anchor_bottom = 1.0
	_help_line.offset_left = 16
	_help_line.offset_top = -HELP_LINE_H - 4
	_help_line.offset_right = 540
	_help_line.offset_bottom = -4
	add_child(_help_line)


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
