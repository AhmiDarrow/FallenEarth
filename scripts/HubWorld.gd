## HubWorld — Local 512×512 playfield for the current sphere hex region.
## Walk the local map; cross edges to adjacent hex regions; open World Map for strategic travel.
class_name HubWorld extends Control

signal enter_rift_requested(rift_id: String)
signal back_to_menu_requested()

const EncounterBuilder = preload("res://scripts/CombatEncounterBuilder.gd")
const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")
const LocalMapViewScene = preload("res://scenes/LocalMapView.tscn")
const MobVisualScript = preload("res://scripts/MobVisual.gd")
const CharacterVisualScript = preload("res://scripts/CharacterVisual.gd")

const RIFT_CHECK_INTERVAL := 30.0

@onready var char_label: RichTextLabel = $CharInfoBar/CharLabel as RichTextLabel
@onready var tile_info_label: RichTextLabel = $TileInfoPanel/TileInfoLabel as RichTextLabel
@onready var rift_info_label: RichTextLabel = $TileInfoPanel/RiftInfoLabel as RichTextLabel
@onready var world_grid: Node2D = $WorldGrid as Node2D
@onready var camera: Camera2D = $WorldGrid/Camera2D as Camera2D

var _world_gen: WorldGenerator = null
var _tile_map: Dictionary = {}
var _local_map: Dictionary = {}
var _player_q: int = 0
var _player_r: int = 0
var _local_x: int = 256
var _local_y: int = 256
var _map_view: Node2D = null
var _marker_layer: Node2D = null
var _mob_layer: Node2D = null
var _marker_nodes: Dictionary = {}
var _rift_runner: Node = null
var _game_time: float = 0.0
var _rift_check_timer: float = 0.0
var _enter_btn: Button = null
var _map_btn: Button = null
var _recruit_btn: Button = null
var _mission_btn: Button = null
var _npc_info_label: RichTextLabel = null
var _save_btn: Button = null
var _mission_info_label: RichTextLabel = null
var _npc_manager: Node = null
var _mission_manager: Node = null
var _pause_menu: PauseMenu = null
var _player_visual: Node2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[HubWorld] Local overworld map loading.")

	_enter_btn = $BottomBar/EnterRift as Button
	var menu_btn: Button = $BottomBar/BackToMenu as Button
	_map_btn = $BottomBar/WorldMap as Button
	if is_instance_valid(_enter_btn):
		_enter_btn.pressed.connect(_on_enter_rift_pressed)
		_enter_btn.disabled = true
	if is_instance_valid(menu_btn):
		menu_btn.pressed.connect(_on_back_to_menu_pressed)
	if is_instance_valid(_map_btn):
		_map_btn.pressed.connect(_on_world_map_pressed)

		# Manual save button
		_save_btn = Button.new()
		_save_btn.name = "SaveGame"
		_save_btn.custom_minimum_size = Vector2(160, 45)
		_save_btn.text = "SAVE"
		_save_btn.disabled = true
		_save_btn.pressed.connect(_on_save_pressed)
		$BottomBar.add_child(_save_btn)

	_rift_runner = get_node_or_null("/root/RiftRunner")
	_npc_manager = get_node_or_null("/root/NPCManager")
	_mission_manager = get_node_or_null("/root/MissionManager")
	_world_gen = WorldGenerator.new()
	add_child(_world_gen)

	_setup_npc_ui()
	_setup_mission_ui()

	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if is_instance_valid(gs):
		var char_data: Dictionary = gs.get_party_character_data()
		if not char_data.is_empty():
			_update_char_info(char_data)
			_save_btn.disabled = false

		_tile_map = gs.get_tile_map()
		if _tile_map.is_empty() and gs.has_world():
			var wd: Dictionary = gs.get_world_data()
			if wd.get("tile_map") is Dictionary:
				_tile_map = wd["tile_map"]

		if not _tile_map.is_empty():
			var seed_str: String = str(gs.get_world_data().get("seed", ""))
			_world_gen.load_from_tile_map(_tile_map, seed_str)

		var pos: Vector2i = gs.get_player_position()
		_player_q = pos.x
		_player_r = pos.y
		var local_pos: Vector2i = gs.get_local_position()
		_local_x = local_pos.x
		_local_y = local_pos.y

		_local_map = gs.ensure_hex_state(_player_q, _player_r)
		gs.set_local_position(_local_x, _local_y)

		var start: Dictionary = gs.get_start_tile()
		if not start.is_empty():
			_append_start_info(start)

	_setup_map_view()
	if is_instance_valid(_map_view):
		_map_view.configure(_local_map)
	_setup_player_visual()
	_game_time = Time.get_ticks_msec() / 1000.0
	_build_local_view()
	_update_tile_info()
	_update_rift_ui()
	_update_npc_ui()
	_update_mission_ui()
	_spawn_initial_rift_if_needed()
	_ensure_world_npcs()
	_seed_local_mobs()
	_build_local_view()
	_save_to_autoslot_if_can()


var _escape_was_pressed: bool = false


func _process(delta: float) -> void:
	var esc_pressed: bool = Input.is_key_pressed(KEY_ESCAPE)
	if esc_pressed and not _escape_was_pressed:
		_toggle_pause_menu()
	_escape_was_pressed = esc_pressed

	_game_time = Time.get_ticks_msec() / 1000.0
	_rift_check_timer += delta
	if _rift_check_timer >= RIFT_CHECK_INTERVAL:
		_rift_check_timer = 0.0
		_tick_rifts()
		_tick_missions()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	if get_tree().paused:
		return
	var dir := Vector2i.ZERO
	match event.keycode:
		KEY_UP, KEY_W:
			dir = Vector2i(0, -1)
		KEY_DOWN, KEY_S:
			dir = Vector2i(0, 1)
		KEY_LEFT, KEY_A:
			dir = Vector2i(-1, 0)
		KEY_RIGHT, KEY_D:
			dir = Vector2i(1, 0)
		KEY_M:
			_on_world_map_pressed()
			return
		_:
			return
	_try_move_local(dir.x, dir.y)


func set_character_data(data: Dictionary) -> void:
	_update_char_info(data)


func _setup_map_view() -> void:
	if is_instance_valid(_map_view):
		_map_view.queue_free()
	_map_view = LocalMapViewScene.instantiate()
	_map_view.name = "LocalMapView"
	world_grid.add_child(_map_view)
	if world_grid.get_child_count() > 0:
		world_grid.move_child(_map_view, 0)

	_marker_layer = _map_view.get_marker_layer()
	_mob_layer = _map_view.get_mob_layer()


func _setup_player_visual() -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs):
		return
	var char_data: Dictionary = gs.get_character_data()
	if char_data.is_empty():
		return

	_player_visual = CharacterVisualScript.new() as Node2D
	_player_visual.name = "PlayerVisual"
	world_grid.add_child(_player_visual)

	var race: String = str(char_data.get("race", "human"))
	var gender: String = str(char_data.get("gender", "male"))
	_player_visual.call("set_base_sprite", race, gender)
	_player_visual.position = Vector2(
		_local_x * _map_view.get_cell_size() + _map_view.get_cell_size() * 0.5,
		_local_y * _map_view.get_cell_size() + _map_view.get_cell_size() * 0.5
	)
	_player_visual.z_index = 10
	print("[HubWorld] Player visual set: race=%s gender=%s" % [race, gender])


func _build_local_view() -> void:
	if is_instance_valid(_player_visual):
		var cell_size: int = _map_view.get_cell_size() if is_instance_valid(_map_view) else 24
		_player_visual.position = Vector2(
			_local_x * cell_size + cell_size * 0.5,
			_local_y * cell_size + cell_size * 0.5
		)
	_refresh_markers()
	_update_camera()


func _refresh_markers() -> void:
	if is_instance_valid(_marker_layer):
		for child in _marker_layer.get_children():
			child.queue_free()
	_marker_nodes.clear()
	var cell_size: int = _map_view.get_cell_size() if is_instance_valid(_map_view) else 24

	# Player visual is handled by _player_visual node — skip circle marker
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs):
		return

	if is_instance_valid(_mission_manager) and _mission_manager.has_method("get_mission_at_tile"):
		var active_mission: Dictionary = _mission_manager.call("get_mission_at_tile", _player_q, _player_r) as Dictionary
		if not active_mission.is_empty():
			var mobj: Dictionary = active_mission.get("objective", {}) as Dictionary
			var mx: int = int(mobj.get("target_local_x", -1))
			var my: int = int(mobj.get("target_local_y", -1))
			if mx >= 0 and my >= 0:
				_add_marker(mx, my, Color(0.5, 0.85, 0.95), "!", "mission", cell_size)

	var all_mobs: Dictionary = gs.get_overworld_mobs()
	var mob_count := 0
	for mob_key in all_mobs:
		if not str(mob_key).begins_with("%d,%d|" % [_player_q, _player_r]):
			continue
		var parts: PackedStringArray = str(mob_key).split("|")
		if parts.size() < 2:
			continue
		var local_parts: PackedStringArray = parts[1].split(",")
		if local_parts.size() < 2:
			continue
		var mx := int(local_parts[0])
		var my := int(local_parts[1])
		var mob_data: Dictionary = all_mobs[mob_key] as Dictionary
		var sprite_id: String = str(mob_data.get("sprite_id", mob_data.get("type", "")))
		_add_mob_sprite(mx, my, sprite_id, cell_size)
		mob_count += 1

	if is_instance_valid(_rift_runner) and _rift_runner.has_method("get_rifts_in_hex"):
		for rift in _rift_runner.get_rifts_in_hex(_player_q, _player_r, _game_time):
			if not rift is Dictionary:
				continue
			var rd: Dictionary = rift as Dictionary
			_add_marker(
				int(rd.get("local_x", 0)), int(rd.get("local_y", 0)),
				Color(0.75, 0.4, 0.95), "⚡", "rift", cell_size
			)

	var npc: Dictionary = _get_npc_at_hex()
	if not npc.is_empty():
		var npos := _npc_local_position(npc)
		_add_marker(npos.x, npos.y, Color(1.0, 0.85, 0.4), "★", "npc", cell_size)


func _dir_from_dx_dy(dx: int, dy: int) -> int:
	# S=0, SE=1, E=2, NE=3, N=4, NW=5, W=6, SW=7
	if dx == 0 and dy > 0: return 0   # S
	if dx > 0 and dy > 0: return 1    # SE
	if dx > 0 and dy == 0: return 2   # E
	if dx > 0 and dy < 0: return 3    # NE
	if dx == 0 and dy < 0: return 4   # N
	if dx < 0 and dy < 0: return 5    # NW
	if dx < 0 and dy == 0: return 6   # W
	if dx < 0 and dy > 0: return 7    # SW
	return 0


func _reset_to_idle(dir_idx: int) -> void:
	await get_tree().create_timer(0.25).timeout
	if is_instance_valid(_player_visual):
		_player_visual.call("play_animation", "idle", dir_idx)


func _add_marker(x: int, y: int, color: Color, symbol: String, kind: String, cell_size: int = 24) -> void:
	if not is_instance_valid(_map_view):
		return
	var node: Node2D = _map_view.call("add_marker", Vector2i(x, y), color, symbol, kind) as Node2D
	if node != null:
		_marker_nodes["%s|%s" % [kind, LocalMapGen.local_key(x, y)]] = node


func _add_mob_sprite(x: int, y: int, sprite_id: String, cell_size: int = 24) -> void:
	if sprite_id.is_empty():
		return
	var mob_node: Node2D = MobVisualScript.new()
	mob_node.position = Vector2(x * cell_size + cell_size * 0.5, y * cell_size + cell_size * 0.5)
	mob_node.z_index = 50
	mob_node.set_mob_sprite(sprite_id)
	if is_instance_valid(_mob_layer):
		_mob_layer.add_child(mob_node)
	elif is_instance_valid(_map_view):
		_map_view.get_mob_layer().add_child(mob_node)
	_marker_nodes["mob|%s" % LocalMapGen.local_key(x, y)] = mob_node


func _update_camera() -> void:
	if is_instance_valid(camera) and is_instance_valid(_map_view):
		var cell_size: int = _map_view.get_cell_size()
		camera.position = Vector2(
			_local_x * cell_size + cell_size * 0.5,
			_local_y * cell_size + cell_size * 0.5,
		)


func _try_move_local(dx: int, dy: int) -> void:
	var nx := _local_x + dx
	var ny := _local_y + dy
	var map_size: int = int(_local_map.get("size", LocalMapGen.MAP_SIZE))

	if nx < 0 or ny < 0 or nx >= map_size or ny >= map_size:
		_try_cross_edge(dx, dy)
		return

	if not _is_cell_walkable(nx, ny):
		return

	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if is_instance_valid(gs):
		var mob: Dictionary = gs.get_local_mob(_player_q, _player_r, nx, ny)
		if not mob.is_empty():
			var mission: Dictionary = {}
			if is_instance_valid(_mission_manager) and _mission_manager.has_method("should_block_move_for_mission"):
				mission = _mission_manager.call(
					"should_block_move_for_mission", "%d,%d" % [_player_q, _player_r], nx, ny
				) as Dictionary
			_start_local_combat(nx, ny, mob, mission)
			return

	_local_x = nx
	_local_y = ny
	if is_instance_valid(gs):
		gs.set_local_position(_local_x, _local_y)
		_mark_explored(gs)

	if is_instance_valid(_player_visual):
		var dir_idx: int = _dir_from_dx_dy(dx, dy)
		_player_visual.call("play_animation", "walk", dir_idx)
		# Return to idle after brief walk frame cycle
		_reset_to_idle(dir_idx)

	_build_local_view()
	_update_tile_info()
	_update_rift_ui()
	_update_npc_ui()
	_update_mission_ui()


func _is_cell_walkable(x: int, y: int) -> bool:
	return LocalMapGen.is_walkable(_local_map, x, y)


func _try_cross_edge(dx: int, dy: int) -> void:
	var edge := LocalMapGen.edge_from_delta(dx, dy)
	if edge < 0:
		return
	var neighbor: Vector2i = LocalMapGen.get_neighbor_hex(_player_q, _player_r, edge)
	var nkey := LocalMapGen.hex_key(neighbor.x, neighbor.y)
	if not _tile_map.has(nkey):
		print("[HubWorld] No adjacent region at edge.")
		return

	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs):
		return

	var opposite_edge := -1
	match edge:
		LocalMapGen.EDGE_NORTH:
			opposite_edge = LocalMapGen.EDGE_SOUTH
		LocalMapGen.EDGE_SOUTH:
			opposite_edge = LocalMapGen.EDGE_NORTH
		LocalMapGen.EDGE_EAST:
			opposite_edge = LocalMapGen.EDGE_WEST
		LocalMapGen.EDGE_WEST:
			opposite_edge = LocalMapGen.EDGE_EAST

	gs.travel_to_hex(neighbor.x, neighbor.y, opposite_edge)
	_player_q = neighbor.x
	_player_r = neighbor.y
	_local_map = gs.get_current_hex_state()
	var local_pos: Vector2i = gs.get_local_position()
	_local_x = local_pos.x
	_local_y = local_pos.y

	if is_instance_valid(_mission_manager) and _mission_manager.has_method("report_tile_visit"):
		_mission_manager.call("report_tile_visit", _player_q, _player_r)

	_local_map = gs.get_current_hex_state()
	_seed_local_mobs()
	_build_local_view()
	_update_tile_info()
	_update_rift_ui()
	_update_npc_ui()
	_update_mission_ui()
	print("[HubWorld] Crossed to region (%d, %d) at local (%d, %d)" % [_player_q, _player_r, _local_x, _local_y])


func _mark_explored(gs: GameState) -> void:
	var state: Dictionary = gs.get_current_hex_state()
	if state.is_empty():
		return
	var explored: float = float(state.get("explored_pct", 0.0))
	state["explored_pct"] = minf(explored + 0.02, 1.0)
	gs.save_hex_state(_player_q, _player_r, state)
	_local_map = state


func _update_tile_info() -> void:
	var tile: Dictionary = _tile_map.get("%d,%d" % [_player_q, _player_r], {})
	var biome: String = str(tile.get("name", _local_map.get("biome", "?")))
	var terrain: int = LocalMapGen.get_terrain(_local_map, _local_x, _local_y)
	var explored: float = float(_local_map.get("explored_pct", 0.0)) * 100.0
	tile_info_label.text = (
		"[b]Region (%d,%d)[/b] — [color=#c8e6c9]%s[/color]\n" % [_player_q, _player_r, biome] +
		"Local pos: (%d, %d) | Terrain: %s | Explored: %.0f%%\n" % [
			_local_x, _local_y, LocalMapGen.terrain_label(terrain), explored,
		] +
		"[i]WASD to explore 512×512 map. Walk off edge to enter adjacent region. [b]M[/b] = World Map.[/i]"
	)


func _tick_rifts() -> void:
	if not is_instance_valid(_rift_runner):
		return
	if _rift_runner.has_method("prune_expired_rifts"):
		var removed: int = _rift_runner.prune_expired_rifts(_game_time)
		if removed > 0:
			print("[HubWorld] %d rift(s) collapsed." % removed)

	if _rift_runner.has_method("try_spawn_local_rift"):
		var tile: Dictionary = _tile_map.get("%d,%d" % [_player_q, _player_r], {})
		var spawned: Dictionary = _rift_runner.try_spawn_local_rift(
			_player_q, _player_r, str(tile.get("name", "Ash Wastes")), _local_map, _game_time
		)
		if not spawned.is_empty():
			print("[HubWorld] Rift spawned at local (%d,%d)" % [spawned.get("local_x", 0), spawned.get("local_y", 0)])

	_build_local_view()
	_update_rift_ui()


func _spawn_initial_rift_if_needed() -> void:
	if not is_instance_valid(_rift_runner):
		return
	if _rift_runner.has_method("get_rifts_in_hex"):
		var existing: Array = _rift_runner.get_rifts_in_hex(_player_q, _player_r, _game_time)
		if not existing.is_empty():
			return
	var tile: Dictionary = _tile_map.get("%d,%d" % [_player_q, _player_r], {})
	if _rift_runner.has_method("add_rift_entrance"):
		var rng := RandomNumberGenerator.new()
		var gs_rift: GameState = get_node_or_null("/root/GameState") as GameState
		var seed_for_rift: String = str(gs_rift.get_world_data().get("seed", "start")) if is_instance_valid(gs_rift) else "start"
		rng.seed = LocalMapGen.hash_seed(LocalMapGen.make_local_seed(seed_for_rift, _player_q, _player_r))
		var lx := rng.randi_range(_local_x + 8, _local_x + 20)
		var ly := rng.randi_range(_local_y - 5, _local_y + 5)
		_rift_runner.add_rift_entrance(
			_player_q, _player_r,
			str(tile.get("name", "Ash Wastes")),
			600.0, "", null, lx, ly
		)
	_build_local_view()
	_update_rift_ui()


func _get_rift_at_player() -> Dictionary:
	if not is_instance_valid(_rift_runner) or not _rift_runner.has_method("get_rift_at_local"):
		return {}
	return _rift_runner.get_rift_at_local(_player_q, _player_r, _local_x, _local_y, _game_time)


func _update_rift_ui() -> void:
	var rift: Dictionary = _get_rift_at_player()
	var on_rift := not rift.is_empty()

	if is_instance_valid(_enter_btn):
		_enter_btn.disabled = not on_rift
		_enter_btn.text = "▶ ENTER RIFT" if on_rift else "▶ NO RIFT HERE"

	if on_rift:
		var remaining: float = float(rift.get("duration", 0.0)) - (_game_time - float(rift.get("spawn_time", 0.0)))
		rift_info_label.text = (
			"[color=#e1bee7][b]RIFT TUNNEL ACTIVE[/b][/color] — %s\n" % rift.get("rift_id", "?") +
			"Local (%d,%d) | ~%d min left" % [
				int(rift.get("local_x", 0)), int(rift.get("local_y", 0)),
				maxi(0, int(remaining / 60.0)),
			]
		)
	else:
		var count := 0
		if is_instance_valid(_rift_runner) and _rift_runner.has_method("get_rifts_in_hex"):
			count = (_rift_runner.get_rifts_in_hex(_player_q, _player_r, _game_time) as Array).size()
		rift_info_label.text = "[i]%d rift(s) in this region. Walk onto ⚡ to enter.[/i]" % count


func _update_char_info(data: Dictionary) -> void:
	var char_name: String = str(data.get("name", data.get("id", "???")))
	var race: String = str(data.get("race", "???"))
	var cls: String = str(data.get("class", "???"))
	var lvl: int = int(data.get("level", 1))
	var xp: int = int(data.get("xp", 0))
	char_label.text = "[b]%s[/b] — %s / %s  [color=#fff59d]Lv.%d[/color] (%d XP)  [color=#90caf9]Local Map[/color]" % [
		char_name, race, cls, lvl, xp,
	]


func _append_start_info(start: Dictionary) -> void:
	var biome: String = str(start.get("name", "Unknown"))
	var extra := RichTextLabel.new()
	extra.name = "StartInfoLabel"
	extra.bbcode_enabled = true
	extra.fit_content = true
	extra.text = "[i]Homestead region: %s (%s) — 512×512 local playfield[/i]" % [biome, start.get("key", "?")]
	$CharInfoBar.add_child(extra)


func _on_enter_rift_pressed() -> void:
	var rift: Dictionary = _get_rift_at_player()
	if rift.is_empty():
		return
	var rift_id: String = str(rift.get("rift_id", "rift_0001"))
	var biome: String = str(rift.get("biome_key", "Ash Wastes"))
	enter_rift_requested.emit(rift_id)
	var gm: GameManager = get_node_or_null("/root/GameManager") as GameManager
	if is_instance_valid(gm):
		rift["entry_q"] = _player_q
		rift["entry_r"] = _player_r
		rift["entry_local_x"] = _local_x
		rift["entry_local_y"] = _local_y
		gm.go_to_rift(rift_id, biome, rift)


func _on_world_map_pressed() -> void:
	var gm: GameManager = get_node_or_null("/root/GameManager") as GameManager
	if is_instance_valid(gm):
		gm.go_to_world_map()


func _setup_mission_ui() -> void:
	var panel: VBoxContainer = $TileInfoPanel as VBoxContainer
	if not is_instance_valid(panel):
		return
	_mission_info_label = RichTextLabel.new()
	_mission_info_label.name = "MissionInfoLabel"
	_mission_info_label.bbcode_enabled = true
	_mission_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mission_info_label.fit_content = true
	_mission_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(_mission_info_label)

	var bottom: HBoxContainer = $BottomBar as HBoxContainer
	if is_instance_valid(bottom):
		_mission_btn = Button.new()
		_mission_btn.name = "AcceptMission"
		_mission_btn.custom_minimum_size = Vector2(170, 45)
		_mission_btn.text = "◆ ACCEPT JOB"
		_mission_btn.disabled = true
		_mission_btn.pressed.connect(_on_accept_mission_pressed)
		bottom.add_child(_mission_btn)
		bottom.move_child(_mission_btn, 0)


func _setup_npc_ui() -> void:
	var panel: VBoxContainer = $TileInfoPanel as VBoxContainer
	if not is_instance_valid(panel):
		return
	_npc_info_label = RichTextLabel.new()
	_npc_info_label.name = "NpcInfoLabel"
	_npc_info_label.bbcode_enabled = true
	_npc_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_npc_info_label.fit_content = true
	_npc_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(_npc_info_label)

	var bottom: HBoxContainer = $BottomBar as HBoxContainer
	if is_instance_valid(bottom):
		_recruit_btn = Button.new()
		_recruit_btn.name = "RecruitNpc"
		_recruit_btn.custom_minimum_size = Vector2(160, 45)
		_recruit_btn.text = "★ RECRUIT"
		_recruit_btn.disabled = true
		_recruit_btn.pressed.connect(_on_recruit_pressed)
		bottom.add_child(_recruit_btn)
		bottom.move_child(_recruit_btn, 0)


func _ensure_world_npcs() -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs) or not gs.get_world_npcs().is_empty():
		return
	if not is_instance_valid(_npc_manager) or not _npc_manager.has_method("generate_for_world"):
		return
	var wd: Dictionary = gs.get_world_data()
	var seed_str: String = str(wd.get("seed", ""))
	var start: Dictionary = gs.get_start_tile()
	var start_key: String = str(start.get("key", "%d,%d" % [_player_q, _player_r]))
	if seed_str.is_empty() or _tile_map.is_empty():
		return
	_npc_manager.call("generate_for_world", seed_str, _tile_map, start_key)


func _npc_local_position(npc: Dictionary) -> Vector2i:
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(str(npc.get("id", "npc")).hash())
	var base := Vector2i(LocalMapGen.MAP_SIZE / 2, LocalMapGen.MAP_SIZE / 2)
	return Vector2i(
		clampi(base.x + rng.randi_range(-40, 40), 8, LocalMapGen.MAP_SIZE - 8),
		clampi(base.y + rng.randi_range(-40, 40), 8, LocalMapGen.MAP_SIZE - 8),
	)


func _get_npc_at_hex() -> Dictionary:
	if not is_instance_valid(_npc_manager) or not _npc_manager.has_method("get_npc_at_tile"):
		return {}
	return _npc_manager.call("get_npc_at_tile", "%d,%d" % [_player_q, _player_r]) as Dictionary


func _is_near_npc() -> bool:
	var npc: Dictionary = _get_npc_at_hex()
	if npc.is_empty():
		return false
	var npos := _npc_local_position(npc)
	return abs(npos.x - _local_x) <= 2 and abs(npos.y - _local_y) <= 2


func _update_npc_ui() -> void:
	if not is_instance_valid(_npc_info_label):
		return
	var npc: Dictionary = _get_npc_at_hex()
	if npc.is_empty() or not _is_near_npc():
		_npc_info_label.text = ""
		if is_instance_valid(_recruit_btn):
			_recruit_btn.disabled = true
		if is_instance_valid(_mission_btn):
			_mission_btn.disabled = true
			_mission_btn.text = "◆ NO JOBS"
		return

	_refresh_npc_mission_offers(npc)
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	var char_data: Dictionary = gs.get_character_data() if is_instance_valid(gs) else {}
	var check: Dictionary = {}
	if is_instance_valid(_npc_manager) and _npc_manager.has_method("can_recruit"):
		check = _npc_manager.call("can_recruit", str(npc.get("id", "")), char_data) as Dictionary

	_npc_info_label.text = (
		"[color=#ffe082][b]★ %s[/b][/color] — %s (%s)\n[i]%s[/i]" % [
			npc.get("name", "?"), npc.get("role", "?"), npc.get("faction", "?"),
			npc.get("personality_summary", ""),
		]
	)
	if is_instance_valid(_recruit_btn):
		_recruit_btn.disabled = not bool(check.get("ok", false))
		_recruit_btn.text = "★ RECRUIT" if bool(check.get("ok", false)) else "★ LOCKED"
	_update_mission_offer_button(npc)


func _on_recruit_pressed() -> void:
	var npc: Dictionary = _get_npc_at_hex()
	if npc.is_empty() or not is_instance_valid(_npc_manager):
		return
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if is_instance_valid(_npc_manager) and _npc_manager.has_method("recruit_npc"):
		if _npc_manager.call("recruit_npc", str(npc.get("id", "")), gs.get_character_data()):
			if is_instance_valid(gs):
				gs.sync_party_companions()
			_build_local_view()
			_update_npc_ui()
			_update_char_info(gs.get_party_character_data())


func _seed_local_mobs() -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs):
		return

	if _tile_map.is_empty():
		push_warning("[HubWorld] _tile_map is empty — cannot seed mobs.")
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = LocalMapGen.hash_seed(LocalMapGen.make_local_seed(
		str(gs.get_world_data().get("seed", "mobs")), _player_q, _player_r
	))
	var tile: Dictionary = _tile_map.get("%d,%d" % [_player_q, _player_r], {})
	var biome: String = str(tile.get("name", "Ash Wastes"))
	var danger: float = float(tile.get("rift_chance", 0.25))
	var count := rng.randi_range(2, 5 + int(danger * 4))
	var seeded := 0
	var skipped_blocked := 0
	var skipped_near := 0
	var skipped_duplicate := 0
	var skipped_no_enemy := 0

	for i in count:
		var lx := rng.randi_range(20, LocalMapGen.MAP_SIZE - 20)
		var ly := rng.randi_range(20, LocalMapGen.MAP_SIZE - 20)
		if LocalMapGen.get_movement_cost(_local_map, lx, ly) < 0:
			skipped_blocked += 1
			continue
		if abs(lx - _local_x) + abs(ly - _local_y) < 12:
			skipped_near += 1
			continue
		var key := GameState.mob_key(_player_q, _player_r, lx, ly)
		if not gs.get_overworld_mob(key).is_empty():
			skipped_duplicate += 1
			continue

		# Generate enemy via EncounterBuilder (independent of NPC system)
		var difficulty: Dictionary = {"min_level": 2, "max_level": 6}
		var enemy: Dictionary = EncounterBuilder.generate_procedural_enemy(
			str(gs.get_world_data().get("seed", "")), _tile_map,
			"%d,%d" % [_player_q, _player_r], difficulty, "upworld", biome
		)
		if enemy.is_empty():
			skipped_no_enemy += 1
			continue

		gs.set_local_mob(_player_q, _player_r, lx, ly, enemy)
		seeded += 1

	print("[HubWorld] Mob seed: biome=%s danger=%.2f attempts=%d seeded=%d (blocked=%d near=%d dup=%d no_enemy=%d) at q,r=%d,%d" % [
		biome, danger, count, seeded, skipped_blocked, skipped_near, skipped_duplicate, skipped_no_enemy,
		_player_q, _player_r
	])


func _start_local_combat(lx: int, ly: int, mob: Dictionary, mission: Dictionary = {}) -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs):
		return
	var tile: Dictionary = _tile_map.get("%d,%d" % [_player_q, _player_r], {})
	var biome: String = str(tile.get("name", "Ash Wastes"))
	var tile_key := "%d,%d|%d,%d" % [_player_q, _player_r, lx, ly]
	var char_data: Dictionary = gs.get_party_character_data()
	var encounter: Dictionary = {}
	var mission_id: String = str(mob.get("mission_id", mission.get("mission_id", "")))
	if not mission_id.is_empty() and is_instance_valid(_mission_manager) and _mission_manager.has_method("build_mission_encounter"):
		encounter = _mission_manager.call("build_mission_encounter", mission_id, char_data) as Dictionary
	if encounter.is_empty():
		encounter = EncounterBuilder.build_overworld(char_data, mob, tile_key, biome)
	var gm: GameManager = get_node_or_null("/root/GameManager") as GameManager
	if is_instance_valid(gm):
		gm.go_to_tactical_combat(encounter)


func _refresh_npc_mission_offers(npc: Dictionary) -> void:
	if not is_instance_valid(_mission_manager) or not _mission_manager.has_method("refresh_npc_offers"):
		return
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs):
		return
	_mission_manager.call(
		"refresh_npc_offers",
		str(npc.get("id", "")), npc,
		str(gs.get_world_data().get("seed", "")),
		_tile_map, _player_q, _player_r, gs.get_party_character_data()
	)


func _update_mission_offer_button(npc: Dictionary) -> void:
	if not is_instance_valid(_mission_btn) or not is_instance_valid(_mission_manager):
		return
	var offers: Array = _mission_manager.call("get_offers_for_npc", str(npc.get("id", ""))) if _mission_manager.has_method("get_offers_for_npc") else []
	var can_accept: bool = _mission_manager.call("has_active_capacity") if _mission_manager.has_method("has_active_capacity") else false
	_mission_btn.disabled = offers.is_empty() or not can_accept or not _is_near_npc()
	_mission_btn.text = "◆ ACCEPT JOB" if not offers.is_empty() else "◆ NO JOBS"


func _update_mission_ui() -> void:
	if not is_instance_valid(_mission_info_label) or not is_instance_valid(_mission_manager):
		return
	var active: Array = _mission_manager.call("get_active_missions") if _mission_manager.has_method("get_active_missions") else []
	if active.is_empty():
		_mission_info_label.text = "[i]No active missions. Visit ★ settlements on the World Map.[/i]"
		return
	var lines: PackedStringArray = ["[color=#80cbc4][b]ACTIVE MISSIONS[/b][/color]"]
	for mission in active:
		if mission is Dictionary:
			var m: Dictionary = mission as Dictionary
			lines.append("• %s" % m.get("title", "?"))
	_mission_info_label.text = "\n".join(lines)


func _on_accept_mission_pressed() -> void:
	var npc: Dictionary = _get_npc_at_hex()
	if npc.is_empty() or not is_instance_valid(_mission_manager):
		return
	var offers: Array = _mission_manager.call("get_offers_for_npc", str(npc.get("id", ""))) if _mission_manager.has_method("get_offers_for_npc") else []
	if offers.is_empty():
		return
	var offer: Dictionary = offers[0] as Dictionary
	var mid: String = str(offer.get("mission_id", ""))
	if _mission_manager.has_method("accept_mission"):
		_mission_manager.call("accept_mission", mid, _game_time)
	_update_mission_ui()


func _tick_missions() -> void:
	if is_instance_valid(_mission_manager) and _mission_manager.has_method("tick_expired"):
		if int(_mission_manager.call("tick_expired", _game_time)) > 0:
			_update_mission_ui()


func _on_back_to_menu_pressed() -> void:
	back_to_menu_requested.emit()
	var gm: GameManager = get_node_or_null("/root/GameManager") as GameManager
	if is_instance_valid(gm):
		gm.go_to_menu()



func _save_to_autoslot_if_can() -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs) or gs.get_character_data().is_empty():
		return
	# Trigger a save to autoslot (slot 0)
	gs.save_game(0)
	print("[HubWorld] Saved to autoslot on entry.")

func _on_save_pressed() -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs) or not _save_btn:
		return
	var success: bool = gs.save_game(0)
	_save_btn.text = "SAVED!" if success else "FAILED"
	_save_btn.disabled = true
	await get_tree().create_timer(1.5).timeout
	if _save_btn:
		_save_btn.text = "SAVE"
		_save_btn.disabled = false


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
			add_child(layer)
			layer.add_child(_pause_menu)
	if is_instance_valid(_pause_menu):
		_pause_menu.open()
