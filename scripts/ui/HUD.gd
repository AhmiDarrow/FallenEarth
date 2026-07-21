## HUD — Top-level in-game Character HUD overlay.
##
## v0.4.0 polish: rewritten end-to-end on the MasterTheme design system.
## Every panel, button, label, progress bar, and sub-component comes
## from `UIHelper` or `MasterTheme` so a single token change rolls out
## the new look site-wide. Components:
##
##   - Player panel  : top-right — name, race, class, level, EC, HP/MP/XP bars
##   - Minimap       : top-right, below player panel (local overworld:
##                     terrain tints, category dots, player-direction arrow,
##                     region/coordinates footer strip)
##   - Hotbar        : bottom-centre (icon-based slots, InventoryHandler row 0 +
##                     EquipmentManager mainhand overlay)
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
var _player_panel: PanelContainer = null
var _name_label: Label = null
var _class_label: Label = null
var _level_label: Label = null
var _ec_label: Label = null

var _hp_bar: ProgressBar = null
var _mp_bar: ProgressBar = null
var _xp_bar: ProgressBar = null

var _minimap: Minimap = null
var _hotbar: Hotbar = null

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

	_build_player_panel()
	_build_minimap()
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

func _build_player_panel() -> void:
	_player_panel = UH.make_surface_panel()
	_player_panel.name = "PlayerPanel"
	_player_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_player_panel.offset_left = -284
	_player_panel.offset_top = 12
	_player_panel.offset_right = -12
	_player_panel.offset_bottom = 12 + 150
	_player_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_player_panel)

	var inner := UH.make_vbox(3)
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 10
	inner.offset_top = 6
	inner.offset_right = -10
	inner.offset_bottom = -6
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_panel.add_child(inner)

	var char_row := UH.make_hbox(6, true)
	char_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(char_row)

	_name_label = UH.make_label("Recruit", MT.FS_STAT, MT.TEXT_ACCENT)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	char_row.add_child(_name_label)

	_class_label = UH.make_small_label("? . ?")
	_class_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	char_row.add_child(_class_label)

	var spacer_1 := Control.new()
	spacer_1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer_1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	char_row.add_child(spacer_1)

	_level_label = UH.make_label("Lv. 1", MT.FS_STAT, Color(1, 0.92, 0.55))
	_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	char_row.add_child(_level_label)

	_ec_label = UH.make_label("0 EC", MT.FS_STAT, MT.ACCENT_PRIMARY)
	_ec_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	char_row.add_child(_ec_label)

	inner.add_child(UH.make_separator())

	# HP bar row
	var hp_row := UH.make_hbox(6, true)
	hp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(hp_row)
	var hp_lbl := UH.make_label("HP", MT.FS_TINY, MT.HP_FILL)
	hp_lbl.custom_minimum_size = Vector2(22, 0)
	hp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_row.add_child(hp_lbl)
	_hp_bar = UH.make_progress_bar(0, MT.BAR_HEIGHT_SM, MT.HP_FILL, MT.HP_BG)
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_bar.show_percentage = true
	_hp_bar.value = 0
	_hp_bar.max_value = 1
	hp_row.add_child(_hp_bar)

	# MP bar row
	var mp_row := UH.make_hbox(6, true)
	mp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(mp_row)
	var mp_lbl := UH.make_label("MP", MT.FS_TINY, MT.MP_FILL)
	mp_lbl.custom_minimum_size = Vector2(22, 0)
	mp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mp_row.add_child(mp_lbl)
	_mp_bar = UH.make_progress_bar(0, MT.BAR_HEIGHT_SM, MT.MP_FILL, MT.MP_BG)
	_mp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mp_bar.show_percentage = true
	_mp_bar.value = 0
	_mp_bar.max_value = 1
	mp_row.add_child(_mp_bar)

	# XP bar row
	var xp_row := UH.make_hbox(6, true)
	xp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(xp_row)
	var xp_lbl := UH.make_label("XP", MT.FS_TINY, MT.XP_FILL)
	xp_lbl.custom_minimum_size = Vector2(22, 0)
	xp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_row.add_child(xp_lbl)
	_xp_bar = UH.make_progress_bar(0, MT.BAR_HEIGHT_SM, MT.XP_FILL, MT.XP_BG)
	_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xp_bar.show_percentage = true
	_xp_bar.value = 0
	_xp_bar.max_value = 1
	xp_row.add_child(_xp_bar)


# ---------------------------------------------------------------------------
# Minimap — top-right
# ---------------------------------------------------------------------------

func _build_minimap() -> void:
	_minimap = MinimapScript.new()
	_minimap.name = "Minimap"
	_minimap.visible = true
	_minimap._manual_vertical_offset = 172
	_minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_minimap.offset_left = -260
	_minimap.offset_top = 172
	_minimap.offset_right = -12
	_minimap.offset_bottom = 332
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
		_class_label.text = "%s . %s" % [_display_race, _display_class]
		var hp: int = int(char_data.get("hp", char_data.get("current_hp", 100)))
		var max_hp: int = int(char_data.get("max_hp", 100))
		var mp: int = int(char_data.get("mp", char_data.get("current_mp", 0)))
		var max_mp: int = int(char_data.get("max_mp", char_data.get("mp_max", 100)))
		_refresh_hp_mp(hp, max_hp, mp, max_mp)
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


func _refresh_hp_mp(hp_val: int, hp_max: int, mp_val: int, mp_max: int) -> void:
	if is_instance_valid(_hp_bar):
		_hp_bar.max_value = float(hp_max) if hp_max > 0 else 1.0
		_hp_bar.value = float(hp_val)
	if is_instance_valid(_mp_bar):
		_mp_bar.max_value = float(mp_max) if mp_max > 0 else 1.0
		_mp_bar.value = float(mp_val)


func refresh_hp_mp_from_gamestate() -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if gs == null:
		return
	var char_data: Dictionary = gs.get_party_character_data()
	if char_data.is_empty():
		return
	var hp: int = int(char_data.get("hp", char_data.get("current_hp", 100)))
	var max_hp: int = int(char_data.get("max_hp", 100))
	var mp: int = int(char_data.get("mp", char_data.get("current_mp", 0)))
	var max_mp: int = int(char_data.get("max_mp", char_data.get("mp_max", 100)))
	_refresh_hp_mp(hp, max_hp, mp, max_mp)


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
