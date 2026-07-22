class_name OverworldPlayerManager extends Node

const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")

var _hw: HubWorld
var _move_cooldown: float = 0.0
const MOVE_COOLDOWN_BASE: float = 0.1


func _update_camera() -> void:
	# Update FollowCamera target (in case player visual wasn't ready)
	var follow: FollowCamera = _hw.camera as FollowCamera
	if follow != null and follow.target == null and is_instance_valid(_hw._player_visual):
		follow.target = _hw._player_visual
	# Fallback: snap camera if FollowCamera has no target yet
	if follow == null or follow.target == null:
		if is_instance_valid(_hw.camera) and is_instance_valid(_hw._map_view):
			if _hw._map_view.has_method("cell_to_world"):
				_hw.camera.position = _hw._map_view.cell_to_world(Vector2i(_hw._local_x, _hw._local_y))
			else:
				var cell_size: int = _hw._map_view.get_cell_size()
				_hw.camera.position = Vector2(
					_hw._local_x * cell_size + cell_size * 0.5,
					_hw._local_y * cell_size + cell_size * 0.5,
				)


func _process(delta: float) -> void:
	if _move_cooldown > 0.0:
		_move_cooldown -= delta


func _try_move_local(dx: int, dy: int) -> void:
	if _move_cooldown > 0.0:
		return
	var nx := _hw._local_x + dx
	var ny := _hw._local_y + dy
	var map_size: int = int(_hw._local_map.get("size", LocalMapGen.MAP_SIZE))

	if nx < 0 or ny < 0 or nx >= map_size or ny >= map_size:
		_try_cross_edge(dx, dy)
		return

	if not _is_cell_walkable(nx, ny):
		return

	var gs := _hw._gs
	if is_instance_valid(gs):
		var mob: Dictionary = gs.get_local_mob(_hw._player_q, _hw._player_r, nx, ny)
		if not mob.is_empty():
			var mission: Dictionary = {}
			if is_instance_valid(_hw._mission_manager) and _hw._mission_manager.has_method("should_block_move_for_mission"):
				mission = _hw._mission_manager.call(
					"should_block_move_for_mission", "%d,%d" % [_hw._player_q, _hw._player_r], nx, ny
				) as Dictionary
			_hw._start_local_combat(nx, ny, mob, mission)
			return

	_hw._local_x = nx
	_hw._local_y = ny
	if is_instance_valid(gs):
		gs.set_local_position(_hw._local_x, _hw._local_y)
		_hw._map_manager._mark_explored(gs)

	# Multiplayer: broadcast position to peers
	if _hw._is_multiplayer and _hw._net_sync != null and _hw._net_sync.has_method("sync_world_position"):
		if _hw.multiplayer.is_server():
			_hw._net_sync.sync_world_position(_hw._player_q, _hw._player_r, _hw._local_x, _hw._local_y)

	if is_instance_valid(_hw._player_visual):
		var dir_idx: int = _dir_from_dx_dy(dx, dy)
		_hw._player_visual.call("play_animation", "walk", dir_idx)
		_reset_to_idle(dir_idx)
		var pv: Node = _hw._player_visual.get_node_or_null("ProcVisual")
		if pv != null:
			pv.call("set_state", 1)
			pv.call("set_facing", float(dir_idx) / 8.0 * TAU)
	# Apply movement cooldown inversely scaled by mount speed
	var speed_mult: float = _hw._get_mount_speed_mult() if _hw.has_method("_get_mount_speed_mult") else 1.0
	_move_cooldown = MOVE_COOLDOWN_BASE / speed_mult

	# Phase 1: auto-collect any floor pickup at the new cell.
	var pickup_info: Dictionary = _hw._interaction_manager._try_collect_floor_pickup_at(_hw._local_x, _hw._local_y)
	# Phase 8: spawn a loot popup at the pickup location
	if not pickup_info.is_empty():
		_hw._interaction_manager._spawn_loot_popup("+%d x %s" % [pickup_info.get("qty", 1), pickup_info.get("item_id", "?")], Vector2.ZERO)

	_hw._map_manager._build_local_view()
	_hw._hud_manager._update_tile_info()
	_hw._rift_manager.update_rift_ui()
	_hw._npc_manager_ui._update_npc_ui()
	_hw._npc_manager_ui._update_mission_ui()


func _try_cross_edge(dx: int, dy: int) -> void:
	var edge := LocalMapGen.edge_from_delta(dx, dy)
	if edge < 0:
		return

	var gs := _hw._gs
	if not is_instance_valid(gs):
		return

	var tile_key := LocalMapGen.hex_key(_hw._player_q, _hw._player_r)
	var sphere_nbr := WorldGenerator.neighbor_for_edge(tile_key, edge, _hw._tile_map)

	var neighbor: Vector2i
	if not sphere_nbr.is_empty():
		neighbor = Vector2i(int(sphere_nbr.get("q", 0)), int(sphere_nbr.get("r", 0)))
	else:
		neighbor = LocalMapGen.get_neighbor_hex(_hw._player_q, _hw._player_r, edge)

	var nkey := LocalMapGen.hex_key(neighbor.x, neighbor.y)
	if not _hw._tile_map.has(nkey):
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
	_hw._player_q = neighbor.x
	_hw._player_r = neighbor.y
	# Multiplayer: broadcast hex transition
	if _hw._is_multiplayer and _hw._net_sync != null and _hw._net_sync.has_method("sync_hex_transition"):
		if _hw.multiplayer.is_server():
			_hw._net_sync.sync_hex_transition(_hw._player_q, _hw._player_r)
	_hw._local_map = gs.get_current_hex_state()
	var local_pos: Vector2i = gs.get_local_position()
	_hw._local_x = local_pos.x
	_hw._local_y = local_pos.y
	# Reset mount follower to player position on hex transition
	if _hw._mount_follower != null and is_instance_valid(_hw._mount_follower) and _hw._mount_follower.has_method("set_grid_position"):
		_hw._mount_follower.set_grid_position(_hw._local_x, _hw._local_y)
	# Sync hex coords to mob manager
	if _hw._mob_manager != null and is_instance_valid(_hw._mob_manager):
		_hw._mob_manager.set_hex_coords(_hw._player_q, _hw._player_r)

	if is_instance_valid(_hw._mission_manager) and _hw._mission_manager.has_method("report_tile_visit"):
		_hw._mission_manager.call("report_tile_visit", _hw._player_q, _hw._player_r)

	_hw._local_map = gs.get_current_hex_state()
	_hw._seed_local_mobs()
	# v0.9.1c: Force marker refresh — new hex has new mobs.
	_hw._map_manager._mark_world_markers_dirty()
	_hw._map_manager._build_local_view()
	_hw._hud_manager._update_tile_info()
	_hw._rift_manager.update_rift_ui()
	_hw._npc_manager_ui._update_npc_ui()
	_hw._npc_manager_ui._update_mission_ui()
	# Audio: re-evaluate ambient bed for the new biome.
	_hw._start_audio_for_current_region()


func _is_cell_walkable(x: int, y: int) -> bool:
	return LocalMapGen.is_walkable(_hw._local_map, x, y)


func _dir_from_dx_dy(dx: int, dy: int) -> int:
	if dx == 0 and dy == 1:
		return 0   # south
	if dx == -1 and dy == 1:
		return 1   # south-west
	if dx == -1 and dy == 0:
		return 2   # west
	if dx == -1 and dy == -1:
		return 3   # north-west
	if dx == 0 and dy == -1:
		return 4   # north
	if dx == 1 and dy == -1:
		return 5   # north-east
	if dx == 1 and dy == 0:
		return 6   # east
	if dx == 1 and dy == 1:
		return 7   # south-east
	return 0


func _reset_to_idle(dir_idx: int) -> void:
	if not is_instance_valid(_hw._player_visual):
		return
	# Brief timer callback: after the walk anim plays, switch back to idle.
	var speed_mult: float = _hw._get_mount_speed_mult() if _hw.has_method("_get_mount_speed_mult") else 1.0
	var timer := Timer.new()
	timer.name = "_ResetIdleTimer"
	timer.one_shot = true
	timer.wait_time = 0.15 / speed_mult
	timer.timeout.connect(func() -> void:
		if is_instance_valid(_hw._player_visual):
			_hw._player_visual.call("play_animation", "idle", dir_idx)
		timer.queue_free()
	)
	_hw._player_visual.add_child(timer)
	timer.start()
