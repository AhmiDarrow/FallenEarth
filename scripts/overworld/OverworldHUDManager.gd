class_name OverworldHUDManager extends Node

const MT = preload("res://assets/ui/MasterTheme.gd")
const UH = preload("res://scripts/ui/UIHelper.gd")
const HUDScript = preload("res://scripts/ui/HUD.gd")
const HoverTooltipScript = preload("res://scripts/HoverTooltip.gd")
const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")

var _hw: HubWorld

var _hud: Control = null
var _hud_minimap_tick: float = 0.0
var _hover_tooltip: Control = null
var _character_menu: Control = null
var _pause_menu: PauseMenu = null
var _mob_name_cache: Dictionary = {}
var _mob_name_cache_loaded: bool = false
var _escape_was_pressed: bool = false


func process_hud(delta: float) -> void:
	var esc_pressed: bool = Input.is_key_pressed(KEY_ESCAPE)
	if esc_pressed and not _escape_was_pressed and not _is_ui_overlay_open():
		_toggle_pause_menu()
	_escape_was_pressed = esc_pressed

	_tick_hover_tooltip()

	_hud_minimap_tick += delta
	if _hud_minimap_tick >= 1.0 and is_instance_valid(_hud):
		_hud_minimap_tick = 0.0
		if _hud.has_method("notify_cell_changed"):
			_hud.notify_cell_changed()


func _setup_hud() -> void:
	_hud = HUDScript.new()
	_hud.name = "HUD"
	var ui_layer := _hw.get_node_or_null("UI_Canvas") as CanvasLayer
	if ui_layer != null:
		ui_layer.add_child(_hud)
	else:
		_hw.add_child(_hud)
	var old_bar := _hw.get_node_or_null("UI_Canvas/CharInfoBar") as CanvasItem
	if old_bar == null:
		old_bar = _hw.get_node_or_null("CharInfoBar") as CanvasItem
	if old_bar != null:
		old_bar.visible = false

	var info_panel := _hw.get_node_or_null("UI_Canvas/TileInfoPanel") as VBoxContainer
	if is_instance_valid(info_panel):
		UH.make_scrollable(info_panel)


func _open_character_menu() -> void:
	if _hud == null or not is_instance_valid(_hud):
		return
	_hud.open_character_menu("inventory")


func open_character_tab(tab_id: String) -> void:
	if _hud == null or not is_instance_valid(_hud):
		return
	_hud.open_character_menu(tab_id)


func _setup_hover_tooltip() -> void:
	_hover_tooltip = HoverTooltipScript.new()
	_hover_tooltip.name = "HoverTooltip"
	_hover_tooltip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hover_tooltip.position = Vector2.ZERO
	_hover_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ui_canvas := _hw.get_node_or_null("UI_Canvas") as CanvasLayer
	if ui_canvas != null:
		ui_canvas.add_child(_hover_tooltip)
	else:
		_hw.add_child(_hover_tooltip)


func _tick_hover_tooltip() -> void:
	if not is_instance_valid(_hover_tooltip):
		return
	if not is_instance_valid(_hw._map_view):
		return
	var mouse_local: Vector2 = _hw.get_local_mouse_position()
	var target_text: String = _hit_test_at_world(mouse_local)
	_hover_tooltip.update(mouse_local, target_text)


func _hit_test_at_world(world_pos: Vector2) -> String:
	if not is_instance_valid(_hw._map_view):
		return ""
	var cell_size: int = _hw._map_view.get_cell_size()
	var cell := Vector2i(
		int(floor(world_pos.x / cell_size)),
		int(floor(world_pos.y / cell_size)),
	)
	if cell == Vector2i(_hw._local_x, _hw._local_y):
		return ""

	for entry in _hw._map_view.get_resource_nodes_near(cell, 0):
		var n: Node = entry.get("node")
		if n != null and is_instance_valid(n):
			var d: Dictionary = n.node_data
			return str(d.get("name", d.get("id", "Resource")))

	var pickup: Node2D = _hw._map_view.get_floor_pickup_at(cell)
	if pickup != null and is_instance_valid(pickup):
		var item_id: String = pickup.get_item_id()
		var inv: Node = get_node_or_null("/root/InventoryHandler")
		if inv != null and inv.has_method("get_item_name"):
			return String(inv.get_item_name(item_id))
		return item_id

	var cell_key := "%d,%d" % [cell.x, cell.y]
	for kind in ["mob", "rift", "npc", "mission"]:
		var key: String = "%s|%s" % [kind, cell_key]
		if _hw._marker_nodes.has(key):
			match kind:
				"mob":
					return _mob_name_at_cell(cell)
				"rift":
					return "Rift"
				"npc":
					return _hw._npc_manager_ui._npc_name_at_hex()
				"mission":
					return "Mission"

	return _terrain_label_at_cell(cell)


func _terrain_label_at_cell(cell: Vector2i) -> String:
	if not is_instance_valid(_hw._map_view):
		return ""
	var t: int = _hw._map_view.get_ground_layer().get_cell_source_id(Vector2i(cell.x, cell.y))
	var atlas: Vector2i = _hw._map_view.get_ground_layer().get_cell_atlas_coords(Vector2i(cell.x, cell.y))
	var t_id: int = atlas.y
	if t_id == LocalMapGen.TERRAIN_GROUND:
		return "Ground"
	if t_id == LocalMapGen.TERRAIN_DEBRIS:
		return "Debris"
	if t_id == LocalMapGen.TERRAIN_VEGETATION:
		return "Vegetation"
	if t_id == LocalMapGen.TERRAIN_BLOCKED:
		return "Blocked"
	return ""


func _mob_name_at_cell(cell: Vector2i) -> String:
	var gs := _hw._gs
	if gs == null:
		return "Mob"
	var key: String = gs.mob_key(_hw._player_q, _hw._player_r, cell.x, cell.y)
	var mob: Dictionary = gs.get_overworld_mob(key)
	if mob.is_empty():
		return "Mob"
	var sprite_id: String = str(mob.get("sprite_id", mob.get("id", "mob")))
	return _resolve_mob_display_name(sprite_id) + " (Lv.%d)" % int(mob.get("level", 1))


func _resolve_mob_display_name(sprite_id: String) -> String:
	if not _mob_name_cache_loaded:
		_load_mob_name_cache()
	return _mob_name_cache.get(sprite_id, sprite_id)


func _load_mob_name_cache() -> void:
	_mob_name_cache_loaded = true
	var path := "res://data/mobs.json"
	if not ResourceLoader.exists(path):
		return
	var raw = load(path)
	if raw == null:
		return
	var data = raw.data if "data" in raw else raw
	if not (data is Dictionary):
		return
	for section in ["overworld", "rift_only"]:
		var bucket = data.get(section, {})
		if bucket is Dictionary:
			for cat in ["neutral", "aggressive"]:
				for m in bucket.get(cat, []):
					var sid := str(m.get("sprite_id", m.get("id", "")))
					if not sid.is_empty():
						_mob_name_cache[sid] = str(m.get("name", sid))
		elif bucket is Array:
			for m in bucket:
				var sid := str(m.get("sprite_id", m.get("id", "")))
				if not sid.is_empty():
					_mob_name_cache[sid] = str(m.get("name", sid))


func _update_tile_info() -> void:
	var tile: Dictionary = _hw._tile_map.get("%d,%d" % [_hw._player_q, _hw._player_r], {})
	var biome: String = str(tile.get("name", _hw._local_map.get("biome", "?")))
	var terrain: int = LocalMapGen.get_terrain(_hw._local_map, _hw._local_x, _hw._local_y)
	var explored: float = float(_hw._local_map.get("explored_pct", 0.0)) * 100.0
	var gs := _hw._gs
	var mob_count: int = 0
	var nearest_mob_dist: int = -1
	if is_instance_valid(gs):
		var all_mobs: Dictionary = gs.get_overworld_mobs()
		var prefix: String = "%d,%d|" % [_hw._player_q, _hw._player_r]
		for mob_key in all_mobs.keys():
			if not str(mob_key).begins_with(prefix):
				continue
			mob_count += 1
			var rest: String = str(mob_key).substr(prefix.length())
			var parts: PackedStringArray = rest.split(",")
			if parts.size() < 2:
				continue
			var d: int = abs(int(parts[0]) - _hw._local_x) + abs(int(parts[1]) - _hw._local_y)
			if nearest_mob_dist < 0 or d < nearest_mob_dist:
				nearest_mob_dist = d
	var mob_line: String = ""
	if mob_count > 0:
		var dist_str: String = str(nearest_mob_dist) + " cells away" if nearest_mob_dist > 0 else "ADJACENT — walk into one"
		mob_line = "\n[color=#ff8a65][b]%d mob(s)[/b][/color] in this region. Nearest: %s." % [mob_count, dist_str]
	_hw.tile_info_label.text = (
		"[b]Region (%d,%d)[/b] — [color=#c8e6c9]%s[/color]\n" % [_hw._player_q, _hw._player_r, biome] +
		"Local pos: (%d, %d) | Terrain: %s | Explored: %.0f%%%s\n" % [
			_hw._local_x, _hw._local_y, LocalMapGen.terrain_label(terrain), explored, mob_line,
		] +
		"[i]WASD to walk. Step onto a mob to fight. ⚡ = rift — press F to enter. [b]M[/b] = World Map.[/i]"
	)


func _update_char_info(data: Dictionary) -> void:
	if _hud != null and is_instance_valid(_hud):
		return
	var char_name: String = str(data.get("name", data.get("id", "???")))
	var race: String = str(data.get("race", "???"))
	var cls: String = str(data.get("class", "???"))
	var lvl: int = int(data.get("level", 1))
	var xp: int = int(data.get("xp", 0))
	_hw.char_label.text = "[b]%s[/b] — %s / %s  [color=#fff59d]Lv.%d[/color] (%d XP)  [color=#90caf9]Local Map[/color]" % [
		char_name, race, cls, lvl, xp,
	]


func _append_start_info(start: Dictionary) -> void:
	var biome: String = str(start.get("name", "Unknown"))
	var extra := UH.make_rich_section("[i]Homestead region: %s (%s) — 512×512 local playfield[/i]" % [biome, start.get("key", "?")])
	extra.name = "StartInfoLabel"
	extra.fit_content = true
	var char_bar := _hw.get_node_or_null("UI_Canvas/CharInfoBar") as HBoxContainer
	if char_bar != null:
		char_bar.add_child(extra)


func _setup_ui_scaling() -> void:
	if is_instance_valid(_hud):
		_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
		_hud.size = Vector2.ZERO
		_hud.call_deferred("_sync_size_to_parent")


func _is_ui_overlay_open() -> bool:
	if _hud != null and is_instance_valid(_hud) and _hud.has_method("is_character_menu_open"):
		if _hud.is_character_menu_open():
			return true
	if _hw._cooking_table_ui != null and is_instance_valid(_hw._cooking_table_ui):
		return true
	if _hw._base_interior != null and is_instance_valid(_hw._base_interior):
		return true
	var sm: Node = get_node_or_null("/root/SettlementManager")
	if sm != null and sm.has_method("is_inside_settlement") and sm.is_inside_settlement():
		return true
	return false


func _toggle_pause_menu() -> void:
	if is_instance_valid(_pause_menu) and _pause_menu.visible:
		_pause_menu.close()
		return
	if not is_instance_valid(_pause_menu):
		var scene: PackedScene = load("res://scenes/ui/PauseMenu.tscn") as PackedScene
		if is_instance_valid(scene):
			_pause_menu = scene.instantiate() as PauseMenu
			var layer := CanvasLayer.new()
			layer.name = "PauseMenuLayer"
			layer.layer = 100
			_hw.add_child(layer)
			layer.add_child(_pause_menu)
	if is_instance_valid(_pause_menu):
		_pause_menu.open()


func _on_back_to_menu_pressed() -> void:
	_hw.back_to_menu_requested.emit()
	var gm: GameManager = _hw._gm
	if is_instance_valid(gm):
		gm.go_to_menu()


func _show_notification(text: String) -> void:
	var label := UH.make_label(text, MT.FS_BODY, Color(0.2, 0.8, 0.4))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(400, 300)
	label.size = Vector2(480, 30)
	label.z_index = 200
	var canvas := _hw.get_node_or_null("UI_Canvas") as CanvasLayer
	if canvas == null:
		canvas = CanvasLayer.new()
		canvas.name = "UINotify"
		_hw.add_child(canvas)
	canvas.add_child(label)
	var timer := Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.timeout.connect(func() -> void:
		if is_instance_valid(label):
			label.queue_free()
		timer.queue_free()
	)
	_hw.add_child(timer)
	timer.start()


func _save_to_autoslot_if_can() -> void:
	var gs := _hw._gs
	if not is_instance_valid(gs) or gs.get_character_data().is_empty():
		return
	gs.save_game(0)


## v0.4.0 polish: getter for the minimap so it can show the current
## region name in its title strip. Loads the local map's biome name.
func get_region_info() -> String:
	if _hw == null:
		return ""
	if not is_instance_valid(_hw._local_map) or _hw._local_map.is_empty():
		return "?"
	var biome: String = str(_hw._local_map.get("biome", "?"))
	var pos: String = "%d,%d" % [_hw._local_x, _hw._local_y]
	return "%s  %s" % [biome, pos]


## v0.4.0 polish: minimap also needs a "current facing direction" for
## the player arrow. Pulls from CharacterVisual if available.
func get_player_facing() -> int:
	if _hw == null:
		return 0
	var child = _hw.find_child("PlayerVisual", true, false)
	if child != null and "current_direction" in child:
		return int(child.get("current_direction"))
	return 0
