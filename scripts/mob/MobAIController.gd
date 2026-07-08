## MobAIController — Node-based overworld mob AI.
## Extends the original OverworldMobAI state machine as a Node so it
## can use _process / _physics_process directly. Adds FLEE, PATROL,
## and RETURN_TO_SPAWN states.
class_name MobAIController
extends Node

enum State { IDLE, WANDER, AGGRO, ATTACK, FLEE, PATROL, RETURN_TO_SPAWN }

signal state_changed(old_state: int, new_state: int)

var current_state: int = State.IDLE
var grid_x: int = 0
var grid_y: int = 0
var spawn_x: int = 0
var spawn_y: int = 0
var aggro_range: int = 3
var mob_type: String = "aggressive"
var patrol_radius: int = 8

var _idle_timer: float = 0.0
var _wander_target: Vector2i = Vector2i.ZERO
var _path: Array[Vector2i] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _flee_target: Vector2i = Vector2i.ZERO
var _move_callback: Callable
var _spawn_grace: float = 0.0


func _init() -> void:
	_rng.randomize()


func setup(pos_x: int, pos_y: int, walkable_check: Callable, move_callback: Callable) -> void:
	grid_x = pos_x
	grid_y = pos_y
	spawn_x = pos_x
	spawn_y = pos_y
	_is_cell_walkable = walkable_check
	_move_callback = move_callback
	_rng.seed = abs((pos_x * 73856093) ^ (pos_y * 19349663))
	_idle_timer = _rng.randf_range(0.5, 2.0)
	_spawn_grace = 3.0


var _is_cell_walkable: Callable = func(_x, _y): return true


func tick(delta: float, player_x: int, player_y: int) -> void:
	var dist_to_player := maxi(abs(grid_x - player_x), abs(grid_y - player_y))
	var dist_to_spawn := maxi(abs(grid_x - spawn_x), abs(grid_y - spawn_y))

	# Spawn grace period — mob stands still for a few seconds before any action
	if _spawn_grace > 0.0:
		_spawn_grace -= delta
		return

	# Aggro check — sets state + path, then falls through so _tick_aggro
	# populates _wander_target (avoids stale Vector2i.ZERO bug).
	if current_state != State.AGGRO and current_state != State.ATTACK and current_state != State.FLEE:
		if dist_to_player <= aggro_range and mob_type == "aggressive":
			print("[MobAI] AGGRO at (%d,%d) → player (%d,%d)" % [grid_x, grid_y, player_x, player_y])
			_set_state(State.AGGRO)
			_repath(player_x, player_y)

	# Flee if too far from spawn (only for non-aggressive)
	if current_state != State.FLEE and current_state != State.RETURN_TO_SPAWN:
		if dist_to_spawn > patrol_radius * 2 and mob_type != "aggressive":
			_set_state(State.RETURN_TO_SPAWN)
			_repath(spawn_x, spawn_y)

	# Hysteresis: drop aggro
	if current_state == State.AGGRO and dist_to_player > aggro_range + 2:
		_set_state(State.IDLE)
		_path.clear()
		_idle_timer = _rng.randf_range(0.5, 1.5)
		return

	match current_state:
		State.IDLE:
			_tick_idle(delta)
		State.WANDER:
			_tick_wander()
		State.AGGRO:
			_tick_aggro(player_x, player_y)
		State.RETURN_TO_SPAWN:
			_tick_return_to_spawn()
		State.FLEE:
			_tick_flee(player_x, player_y)
		State.ATTACK:
			pass


func is_at_player(player_x: int, player_y: int) -> bool:
	return grid_x == player_x and grid_y == player_y


func confirm_arrival() -> void:
	grid_x = _wander_target.x
	grid_y = _wander_target.y
	_set_state(State.IDLE)
	_idle_timer = _rng.randf_range(1.5, 4.0)


func cancel_movement() -> void:
	_set_state(State.IDLE)
	_idle_timer = _rng.randf_range(0.5, 2.0)


# ---- Internal State Ticks ----

func _tick_idle(delta: float) -> void:
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_set_state(State.WANDER)
		_idle_timer = 0.0
		_tick_wander()  # populate _wander_target now, before tick_all reads it


func _tick_wander() -> void:
	var candidates := _walkable_neighbors(grid_x, grid_y)
	if candidates.is_empty():
		_set_state(State.IDLE)
		_idle_timer = _rng.randf_range(1.0, 3.0)
		return
	_wander_target = candidates[_rng.randi() % candidates.size()]
	_try_move()


func _tick_aggro(player_x: int, player_y: int) -> void:
	if _path.is_empty() or _rng.randi() % 3 == 0:
		_repath(player_x, player_y)
	if _path.is_empty():
		_set_state(State.IDLE)
		_idle_timer = _rng.randf_range(1.0, 2.0)
		return
	while _path.size() > 1 and _path[0] == Vector2i(grid_x, grid_y):
		_path.remove_at(0)
	if _path.size() <= 1:
		if _path.size() == 1:
			_wander_target = _path[0]
		_set_state(State.ATTACK)
		return
	_wander_target = _path[1]
	_path.remove_at(0)
	_try_move()


func _tick_return_to_spawn() -> void:
	if Vector2i(grid_x, grid_y) == Vector2i(spawn_x, spawn_y):
		_set_state(State.IDLE)
		_idle_timer = _rng.randf_range(1.0, 2.0)
		return
	if _path.is_empty():
		_repath(spawn_x, spawn_y)
	if _path.is_empty():
		_set_state(State.WANDER)
		return
	while _path.size() > 1 and _path[0] == Vector2i(grid_x, grid_y):
		_path.remove_at(0)
	if _path.size() <= 1:
		_set_state(State.IDLE)
		_idle_timer = _rng.randf_range(1.0, 2.0)
		return
	_wander_target = _path[1]
	_path.remove_at(0)
	_try_move()


func _tick_flee(player_x: int, player_y: int) -> void:
	if maxi(abs(grid_x - player_x), abs(grid_y - player_y)) > aggro_range + 4:
		_set_state(State.IDLE)
		_idle_timer = _rng.randf_range(1.0, 2.0)
		return
	var opposite_dir: Vector2i = Vector2i(grid_x - player_x, grid_y - player_y)
	var candidates: Array[Vector2i] = []
	var flee_offsets: Array[Vector2i] = [
		Vector2i(clamp(opposite_dir.x, -1, 1), clamp(opposite_dir.y, -1, 1)),
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	for offset: Vector2i in flee_offsets:
		var nx: int = grid_x + offset.x
		var ny: int = grid_y + offset.y
		if _is_cell_walkable.call(nx, ny):
			candidates.append(Vector2i(nx, ny))
	if candidates.is_empty():
		_set_state(State.IDLE)
		return
	_wander_target = candidates[0]
	_try_move()


func _try_move() -> void:
	if _wander_target.x != grid_x or _wander_target.y != grid_y:
		if _is_cell_walkable.call(_wander_target.x, _wander_target.y):
			if _move_callback.is_valid():
				_move_callback.call(_wander_target)
		else:
			cancel_movement()


func _set_state(new_state: int) -> void:
	if new_state == current_state:
		return
	var old := current_state
	current_state = new_state
	state_changed.emit(old, new_state)


# ---- BFS Pathfinding ----

func _repath(to_x: int, to_y: int) -> void:
	_path = bfs_path(grid_x, grid_y, to_x, to_y, _is_cell_walkable)


static func bfs_path(from_x: int, from_y: int, to_x: int, to_y: int, walkable_check: Callable) -> Array[Vector2i]:
	if from_x == to_x and from_y == to_y:
		return [Vector2i(from_x, from_y)]
	var visited: Dictionary = {}
	var parent: Dictionary = {}
	var queue: Array[Vector2i] = [Vector2i(from_x, from_y)]
	var start_key := "%d,%d" % [from_x, from_y]
	visited[start_key] = true
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current.x == to_x and current.y == to_y:
			var path: Array[Vector2i] = []
			var node: Vector2i = current
			var node_key: String = "%d,%d" % [node.x, node.y]
			while parent.has(node_key):
				path.push_front(node)
				node = parent.get(node_key, node) as Vector2i
				node_key = "%d,%d" % [node.x, node.y]
			path.push_front(Vector2i(from_x, from_y))
			return path
		var bfs_offsets: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
		for offset: Vector2i in bfs_offsets:
			var neighbor: Vector2i = Vector2i(current.x + offset.x, current.y + offset.y)
			var nkey := "%d,%d" % [neighbor.x, neighbor.y]
			if visited.has(nkey):
				continue
			if not walkable_check.call(neighbor.x, neighbor.y):
				continue
			visited[nkey] = true
			parent[nkey] = current
			queue.append(neighbor)
	return []


func _walkable_neighbors(x: int, y: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var neighbor_offsets: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for offset: Vector2i in neighbor_offsets:
		var nx: int = x + offset.x
		var ny: int = y + offset.y
		if _is_cell_walkable.call(nx, ny):
			out.append(Vector2i(nx, ny))
	return out
