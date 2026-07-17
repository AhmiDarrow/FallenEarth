class_name OverworldMapManager extends Node

signal markers_dirty()

const LocalMapViewScene = preload("res://scenes/LocalMapView.tscn")
const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")
const MobManagerScript = preload("res://scripts/mob/OverworldMobManager.gd")
const MobPoolScript = preload("res://scripts/mob/OverworldMobPool.gd")
const MobInstanceScript = preload("res://scripts/mob/MobInstance.gd")
const MobDataScript = preload("res://scripts/mob/MobData.gd")
const CharacterVisualScript = preload("res://scripts/CharacterVisual.gd")
const EntityVisualComponentScript = preload("res://scripts/procedural/EntityVisualComponent.gd")

var _hw: HubWorld


func _setup_map_view() -> void:
	if is_instance_valid(_hw._map_view):
		_hw._map_view.queue_free()
	_hw._map_view = LocalMapViewScene.instantiate()
	_hw._map_view.name = "LocalMapView"
	_hw.world_grid.add_child(_hw._map_view)
	if _hw.world_grid.get_child_count() > 0:
		_hw.world_grid.move_child(_hw._map_view, 0)

	_hw._marker_layer = _hw._map_view.get_marker_layer()
	_hw._mob_layer = _hw._map_view.get_mob_layer()
	_hw._node_layer = _hw._map_view.get_node_layer()
	_hw._pickup_layer = _hw._map_view.get_pickup_layer()

	# Dedicated sprite layer for mobs — child of world_grid, NOT MobLayer
	# (which has y_sort_enabled and broke _draw() rendering in Godot 4).
	if _hw._mob_sprite_layer != null and is_instance_valid(_hw._mob_sprite_layer):
		_hw._mob_sprite_layer.queue_free()
	_hw._mob_sprite_layer = Node2D.new()
	_hw._mob_sprite_layer.name = "MobSpriteLayer"
	_hw._mob_sprite_layer.z_index = 50
	_hw.world_grid.add_child(_hw._mob_sprite_layer)

	# OverworldMobManager + pool (new mob system)
	_hw._mob_manager = MobManagerScript.new()
	_hw._mob_manager.name = "MobManager"
	var gs_mob_key := Callable()
	var gs_node: GameState = get_node_or_null("/root/GameState") as GameState
	if is_instance_valid(gs_node):
		gs_mob_key = Callable(gs_node, "mob_key")
	_hw._mob_manager.setup(Callable(_hw._player_manager, "_is_cell_walkable"), _hw._player_q, _hw._player_r, gs_node, gs_mob_key)
	_hw._mob_manager.mob_reached_player.connect(_hw._on_mob_reached_player)
	_hw.world_grid.add_child(_hw._mob_manager)

	_hw._mob_pool = MobPoolScript.new()
	_hw._mob_pool.name = "MobPool"
	_hw._mob_pool.warm(20)
	_hw._mob_sprite_layer.add_child(_hw._mob_pool)

	# Dedicated World/Mobs container for active mobs — prevents teleport-to-origin
	_hw._mobs_container = Node2D.new()
	_hw._mobs_container.name = "Mobs"
	_hw.world_grid.add_child(_hw._mobs_container)


## Phase 2: attach a procedural EntityVisualComponent to an existing 2D entity
## node, resolving its visual from appearance.json. Each component owns a
## private 3D SubViewport studio, so no shared world is required. Returns the
## component or null when procedural graphics are disabled.
func _attach_procedural_visual(parent: Node2D, entity_data: Dictionary, group: String = "default") -> Node:
	var gs := _hw._gs
	if gs == null or not gs.use_procedural_graphics:
		return null
	var am: Node = get_node_or_null("/root/AppearanceManager")
	if am == null:
		return null
	var visual: Dictionary = am.call("resolve_entity_visual", entity_data)
	if visual.is_empty():
		return null
	var comp = EntityVisualComponentScript.new()
	comp.name = "ProcVisual"
	comp.configure(visual, group)
	parent.add_child(comp)
	return comp


func _setup_player_visual() -> void:
	var gs := _hw._gs
	if not is_instance_valid(gs):
		return
	var char_data: Dictionary = gs.get_character_data()
	if char_data.is_empty():
		return

	_hw._player_visual = CharacterVisualScript.new() as Node2D
	_hw._player_visual.name = "PlayerVisual"
	_hw.world_grid.add_child(_hw._player_visual)

	var race: String = str(char_data.get("race", "human"))
	var gender: String = str(char_data.get("gender", "male"))
	_hw._player_visual.call("set_base_sprite", race, gender)
	_hw._player_visual.position = Vector2(
		_hw._local_x * _hw._map_view.get_cell_size() + _hw._map_view.get_cell_size() * 0.5,
		_hw._local_y * _hw._map_view.get_cell_size() + _hw._map_view.get_cell_size() * 0.5
	)
	_hw._player_visual.z_index = 10
	# Point follow camera at the player visual
	var follow: FollowCamera = _hw.camera as FollowCamera
	if follow != null and is_instance_valid(_hw._player_visual):
		follow.target = _hw._player_visual

	# Phase 2: layered procedural 3D visual over the sprite.
	var pv: Node = _attach_procedural_visual(_hw._player_visual, char_data)
	if pv != null:
		pv.set_meta("entity_kind", "player")


func _build_local_view() -> void:
	if is_instance_valid(_hw._player_visual):
		var cell_size: int = _hw._map_view.get_cell_size() if is_instance_valid(_hw._map_view) else 24
		_hw._player_visual.position = Vector2(
			_hw._local_x * cell_size + cell_size * 0.5,
			_hw._local_y * cell_size + cell_size * 0.5
		)
	# v0.9.1c: Only refresh markers when the underlying world state
	# actually changed. Walking the player does NOT change which mobs,
	# rifts, or NPCs are on the map. Mobs change when combat ends (in
	# _start_local_combat) or after _seed_local_mobs. Rifts change on
	# the 30s timer in _tick_rifts. NPCs change rarely. Without this
	# guard, every move cost ~25ms to clear-and-rebuild 12 mob sprites
	# + 1-2 rift markers + 1 NPC marker. Now it's free.
	if _hw._world_markers_dirty:
		_refresh_markers()
		_hw._world_markers_dirty = false
	if is_instance_valid(_hw._player_manager):
		_hw._player_manager._update_camera()


func _refresh_markers() -> void:
	if is_instance_valid(_hw._marker_layer):
		for child in _hw._marker_layer.get_children():
			child.queue_free()
	_hw._marker_nodes.clear()
	# Clear mob sprites via pool + manager (new system)
	if _hw._mob_pool != null and is_instance_valid(_hw._mob_pool):
		_hw._mob_pool.return_all()
	if _hw._mob_manager != null and is_instance_valid(_hw._mob_manager):
		_hw._mob_manager.clear_all()
	var cell_size: int = _hw._map_view.get_cell_size() if is_instance_valid(_hw._map_view) else 24

	# Player visual is handled by _player_visual node — skip circle marker
	var gs := _hw._gs
	if not is_instance_valid(gs):
		return

	if is_instance_valid(_hw._mission_manager) and _hw._mission_manager.has_method("get_mission_at_tile"):
		var active_mission: Dictionary = _hw._mission_manager.call("get_mission_at_tile", _hw._player_q, _hw._player_r) as Dictionary
		if not active_mission.is_empty():
			var mobj: Dictionary = active_mission.get("objective", {}) as Dictionary
			var mx: int = int(mobj.get("target_local_x", -1))
			var my: int = int(mobj.get("target_local_y", -1))
			if mx >= 0 and my >= 0:
				_add_marker(mx, my, Color(0.5, 0.85, 0.95), "!", "mission", cell_size)

	var all_mobs: Dictionary = gs.get_overworld_mobs()
	var mob_count := 0
	for mob_key in all_mobs:
		if not str(mob_key).begins_with("%d,%d|" % [_hw._player_q, _hw._player_r]):
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
		_add_mob_sprite(mx, my, sprite_id, cell_size, mob_data)
		mob_count += 1
	if is_instance_valid(_hw._rift_runner) and _hw._rift_runner.has_method("get_rifts_in_hex"):
		for rift in _hw._rift_runner.get_rifts_in_hex(_hw._player_q, _hw._player_r, _hw._game_time):
			if not rift is Dictionary:
				continue
			var rd: Dictionary = rift as Dictionary
			_add_marker(
				int(rd.get("local_x", 0)), int(rd.get("local_y", 0)),
				Color(0.75, 0.4, 0.95), "\u26a1", "rift", cell_size
			)
			_add_rift_procedural_visual(rd, cell_size)


## Phase 5: spawn a procedural 3D rift visual (large glow geometry).
func _add_rift_procedural_visual(rd: Dictionary, cell_size: int) -> void:
	var key: String = "riftvis|%s" % str(rd.get("id", "%d,%d" % [int(rd.get("local_x", 0)), int(rd.get("local_y", 0))]))
	if _hw._marker_nodes.has(key):
		return
	var rift_type: int = int(rd.get("rift_type", 0))
	var preset_name: String = ["rift_void", "rift_life", "rift_energy"][rift_type % 3]
	var rift_vis: Dictionary = {
		"visual_preset": preset_name,
		"id": str(rd.get("id", "rift")),
	}
	var node: Node2D = Node2D.new()
	var rx: int = int(rd.get("local_x", 0))
	var ry: int = int(rd.get("local_y", 0))
	node.position = Vector2(rx * cell_size + cell_size * 0.5, ry * cell_size + cell_size * 0.5)
	node.z_index = 900
	node.scale = Vector2(1.6, 1.6)
	_hw.world_grid.add_child(node)
	var pv: Node = _attach_procedural_visual(node, rift_vis)
	if pv != null:
		pv.set_meta("entity_kind", "rift")
	_hw._marker_nodes[key] = node

	var npc: Dictionary = _hw._npc_manager_ui._get_npc_at_hex()
	if not npc.is_empty():
		var npos: Vector2i = _hw._npc_manager_ui._npc_local_position(npc)
		_add_marker(npos.x, npos.y, Color(1.0, 0.85, 0.4), "\u2605", "npc", cell_size)
		_add_npc_procedural_visual(npc, npos, cell_size)


## Phase 5: spawn a procedural 3D visual for the NPC at the current hex.
func _add_npc_procedural_visual(npc: Dictionary, npos: Vector2i, cell_size: int) -> void:
	var key: String = "npcvis|%s" % str(npc.get("id", "?"))
	if _hw._marker_nodes.has(key):
		return
	var npc_vis: Dictionary = {
		"visual_preset": "humanoid_default",
		"id": str(npc.get("id", "npc")),
		"faction": npc.get("faction", ""),
	}
	var node: Node2D = Node2D.new()
	node.position = Vector2(npos.x * cell_size + cell_size * 0.5, npos.y * cell_size + cell_size * 0.5)
	node.z_index = 1000
	_hw.world_grid.add_child(node)
	var pv: Node = _attach_procedural_visual(node, npc_vis)
	if pv != null:
		pv.set_meta("entity_kind", "npc")
		# Faction tint if known.
		var fac: String = str(npc.get("faction", ""))
		if not fac.is_empty():
			var fcol: Color = _faction_color(fac)
			pv.set_faction_tint(fcol, 0.3)
	_hw._marker_nodes[key] = node


## Stable faction -> color (same hue-hash approach used by the minimap).
func _faction_color(faction_key: String) -> Color:
	var h := float(str(faction_key).hash() % 360) / 360.0
	return Color.from_hsv(h, 0.6, 0.9)


func _add_marker(x: int, y: int, color: Color, symbol: String, kind: String, cell_size: int = 24) -> void:
	if not is_instance_valid(_hw._map_view):
		return
	var node: Node2D = _hw._map_view.call("add_marker", Vector2i(x, y), color, symbol, kind) as Node2D
	if node != null:
		_hw._marker_nodes["%s|%s" % [kind, LocalMapGen.local_key(x, y)]] = node


func _add_mob_sprite(x: int, y: int, sprite_id: String, cell_size: int = 24, mob_data: Dictionary = {}) -> void:
	if sprite_id.is_empty():
		return
	# New system: MobInstance from pool + MobData + MobManager.
	var data := MobDataScript.from_enemy_dict(mob_data, x, y)
	data.sprite_id = sprite_id
	var mob_node := _hw._mob_pool.borrow() as MobInstance
	# Reparent from pool to World/Mobs so local position == global position
	if is_instance_valid(_hw._mobs_container):
		_hw._mobs_container.add_child(mob_node)
	mob_node.global_position = Vector2(x * cell_size + cell_size * 0.5, y * cell_size + cell_size * 0.5)
	mob_node.z_index = 0
	mob_node.setup(data)
	_hw._mob_manager.add_mob(data, mob_node)
	_hw._marker_nodes["mob|%s" % LocalMapGen.local_key(x, y)] = mob_node


func _mark_explored(gs: GameState) -> void:
	var state: Dictionary = gs.get_current_hex_state()
	if state.is_empty():
		return
	var explored: float = float(state.get("explored_pct", 0.0))
	state["explored_pct"] = minf(explored + 0.02, 1.0)
	gs.save_hex_state(_hw._player_q, _hw._player_r, state)
	_hw._local_map = state


# v0.9.1c: Helper called whenever the mob/rift/NPC set changes.
# Skips the per-move marker rebuild unless something actually moved.
func _mark_world_markers_dirty() -> void:
	_hw._world_markers_dirty = true
	markers_dirty.emit()
