## OverworldMobManager — Owns all active overworld mobs.
## Replaces HubWorld's _overworld_mobs dict + _tick_overworld_mobs + _start_mob_move.
## Child of the World node. Each managed mob = { data: MobData, node: MobInstance, ai: MobAIController }.
class_name OverworldMobManager
extends Node2D

signal mob_reached_player(mob_data: MobData)


const CELL_SIZE := 24
## Mobs farther than this (Chebyshev cells) from the player skip AI ticking.
const TICK_RANGE := 48

var _entries: Dictionary = {}  # "x,y" -> entry dict
var _is_cell_walkable: Callable
var _hex_q: int = 0
var _hex_r: int = 0

var _game_state: Node = null
var _mob_key_fn: Callable  # gs.mob_key(hex_q, hex_r, x, y)


func setup(walkable_check: Callable, hex_q: int = 0, hex_r: int = 0, game_state: Node = null, mob_key_fn: Callable = Callable()) -> void:
	_is_cell_walkable = walkable_check
	_hex_q = hex_q
	_hex_r = hex_r
	_game_state = game_state
	_mob_key_fn = mob_key_fn


func add_mob(data: MobData, mob_node: Node2D) -> void:
	var key := "%d,%d" % [data.grid_x, data.grid_y]
	if _entries.has(key):
		_remove_entry(key)
	var ai := MobAIController.new()
	ai.setup(data.grid_x, data.grid_y, _is_cell_walkable, Callable())
	ai.aggro_range = mini(data.aggro_range, 3)
	ai.mob_type = data.mob_type
	add_child(ai)
	_entries[key] = {
		"data": data,
		"node": mob_node,
		"ai": ai,
		"moving": false,
		"tween": null,
	}


func remove_mob_at(local_x: int, local_y: int) -> void:
	var key := "%d,%d" % [local_x, local_y]
	_remove_entry(key)


func has_mob_at(local_x: int, local_y: int) -> bool:
	return _entries.has("%d,%d" % [local_x, local_y])


func get_data_at(local_x: int, local_y: int) -> MobData:
	var entry: Variant = _entries.get("%d,%d" % [local_x, local_y])
	if entry != null:
		return (entry as Dictionary).get("data", null) as MobData
	return null


func clear_all() -> void:
	# Entries only — pool manages node lifecycle (return_all called by HubWorld before this)
	_entries.clear()


func set_hex_coords(q: int, r: int) -> void:
	_hex_q = q
	_hex_r = r


func get_entry_count() -> int:
	return _entries.size()


func tick_all(delta: float, player_x: int, player_y: int) -> void:
	if _entries.is_empty():
		return
	var to_remove: Array[String] = []
	for pos_key in _entries:
		var entry: Dictionary = _entries[pos_key] as Dictionary
		if entry.is_empty():
			to_remove.append(pos_key)
			continue
		var ai: MobAIController = entry.get("ai") as MobAIController
		var mob_node: Node2D = entry.get("node") as Node2D
		if ai == null or not is_instance_valid(mob_node):
			to_remove.append(pos_key)
			continue
		if entry.get("moving", false):
			continue
		var data: MobData = entry.get("data") as MobData
		if data == null:
			to_remove.append(pos_key)
			continue
		# Skip AI for mobs far outside the player's active area.
		if maxi(abs(data.grid_x - player_x), abs(data.grid_y - player_y)) > TICK_RANGE:
			continue
		var old_x: int = data.grid_x
		var old_y: int = data.grid_y
		ai.tick(delta, player_x, player_y)
		match ai.current_state:
			MobAIController.State.WANDER, MobAIController.State.AGGRO, MobAIController.State.RETURN_TO_SPAWN, MobAIController.State.FLEE:
				var target: Vector2i = ai.get_wander_target()
				if target.x != old_x or target.y != old_y:
					if _is_cell_walkable.call(target.x, target.y):
						_start_move(entry, target)
					else:
						ai.cancel_movement()
		MobAIController.State.ATTACK:
			if ai.is_at_player(player_x, player_y):
				var mob_data: MobData = entry.get("data") as MobData
				mob_reached_player.emit(mob_data)
				to_remove.append(pos_key)
			else:
				var target: Vector2i = ai.get_wander_target()
				if target.x != old_x or target.y != old_y:
					if _is_cell_walkable.call(target.x, target.y):
						_start_move(entry, target)
					else:
						ai.cancel_movement()
	for key in to_remove:
		_remove_entry(key)


func _start_move(entry: Dictionary, target: Vector2i) -> void:
	entry["moving"] = true
	var mob_node: Node2D = entry["node"]
	var data: MobData = entry["data"]
	var old_x: int = data.grid_x
	var old_y: int = data.grid_y
	var target_pos: Vector2 = Vector2(target.x * CELL_SIZE + CELL_SIZE * 0.5, target.y * CELL_SIZE + CELL_SIZE * 0.5)
	var old_tween: Tween = entry.get("tween") as Tween
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()
	var tw: Tween = create_tween()
	tw.tween_property(mob_node, "global_position", target_pos, 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		entry["moving"] = false
		data.grid_x = target.x
		data.grid_y = target.y
		var ai: MobAIController = entry.get("ai") as MobAIController
		if ai != null:
			if ai.current_state == MobAIController.State.WANDER:
				ai.confirm_arrival()
			elif ai.current_state == MobAIController.State.AGGRO or ai.current_state == MobAIController.State.ATTACK:
				ai.grid_x = target.x
				ai.grid_y = target.y
		# Update GameState position so persistence + combat work correctly
		if _game_state != null and is_instance_valid(_game_state) and _mob_key_fn.is_valid():
			var new_key: String = _mob_key_fn.call(_hex_q, _hex_r, target.x, target.y)
			var old_key: String = _mob_key_fn.call(_hex_q, _hex_r, old_x, old_y)
			if old_key != new_key:
				_game_state.remove_overworld_mob(old_key)
				var updated: Dictionary = data.to_enemy_dict()
				_game_state.set_overworld_mob(new_key, updated)
	)
	entry["tween"] = tw


func _remove_entry(key: String) -> void:
	if not _entries.has(key):
		return
	# Node lifecycle managed by pool — just remove the tracking entry
	_entries.erase(key)
