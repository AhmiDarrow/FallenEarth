## OverworldMobAI — State machine for overworld mob behaviour.
##
## States: IDLE → WANDER → AGGRO → ATTACK
## - IDLE: stand still for a random delay, then pick WANDER or stay idle.
## - WANDER: pick a random adjacent walkable cell, move there, return to IDLE.
## - AGGRO: BFS path toward the player; follow it one cell per tick.
## - ATTACK: mob reached the player's cell — signal combat.
##
## Aggro triggers when the Chebyshev distance to the player ≤ aggro_range.
## Aggro drops when the Chebyshev distance > aggro_range + 2 (hysteresis).
## Wandering only happens when the mob is NOT aggro (passive mobs wander
## endlessly; aggressive mobs wander until they spot the player).

class_name OverworldMobAI
extends RefCounted

enum State { IDLE, WANDER, AGGRO, ATTACK }

var state: int = State.IDLE
var grid_x: int = 0
var grid_y: int = 0
var aggro_range: int = 5
var mob_type: String = "aggressive"

var _idle_timer: float = 0.0
var _wander_target: Vector2i = Vector2i.ZERO
var _path: Array[Vector2i] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


## Seed the RNG deterministically from the mob's position so repeated
## loads produce the same wander pattern (cosmetic consistency).
func seed_from_pos(px: int, py: int) -> void:
	_rng.seed = abs((px * 73856093) ^ (py * 19349663))


## Call every frame. `delta` = elapsed seconds, `local_map` = current
## hex state dict, `player_x/y` = player grid pos, `is_walkable` =
## callback (func(x,y)->bool). Returns the next state to process.
func tick(delta: float, local_map: Dictionary, player_x: int, player_y: int, walkable_check: Callable) -> int:
	var dist_to_player: int = maxi(abs(grid_x - player_x), abs(grid_y - player_y))

	# --- Aggro check (always evaluated first) ---
	if state != State.AGGRO and state != State.ATTACK:
		if dist_to_player <= aggro_range and mob_type == "aggressive":
			_enter_aggro(walkable_check, player_x, player_y)
			return state

	# --- Hysteresis: drop aggro if player ran away ---
	if state == State.AGGRO and dist_to_player > aggro_range + 2:
		state = State.IDLE
		_path.clear()
		_idle_timer = _rng.randf_range(0.5, 1.5)
		return state

	match state:
		State.IDLE:
			_tick_idle(delta)
		State.WANDER:
			_tick_wander(delta, local_map, walkable_check)
		State.AGGRO:
			_tick_aggro(local_map, walkable_check, player_x, player_y)
		State.ATTACK:
			pass  # handled by OverworldMob

	return state


## Force-set grid position (used when spawning or after GameState load).
func set_grid_pos(x: int, y: int) -> void:
	grid_x = x
	grid_y = y


## Returns true when the mob has reached the player's cell.
func is_at_player(player_x: int, player_y: int) -> bool:
	return grid_x == player_x and grid_y == player_y


# ---------------------------------------------------------------------------
# IDLE
# ---------------------------------------------------------------------------

func _tick_idle(delta: float) -> void:
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		state = State.WANDER
		_idle_timer = 0.0


# ---------------------------------------------------------------------------
# WANDER
# ---------------------------------------------------------------------------

func _tick_wander(_delta: float, _local_map: Dictionary, walkable_check: Callable) -> void:
	# Pick a random walkable neighbour
	var candidates: Array[Vector2i] = _walkable_neighbors(grid_x, grid_y, walkable_check)
	if candidates.is_empty():
		# No walkable neighbour — just idle
		state = State.IDLE
		_idle_timer = _rng.randf_range(1.0, 3.0)
		return

	_wander_target = candidates[_rng.randi() % candidates.size()]
	# Signal to OverworldMob to tween to _wander_target; we stay in WANDER
	# until the mob confirms arrival via confirm_arrival().
	# If the mob can't move (e.g. something blocked), it'll call
	# cancel_movement() which puts us back to IDLE.


func confirm_arrival() -> void:
	grid_x = _wander_target.x
	grid_y = _wander_target.y
	state = State.IDLE
	_idle_timer = _rng.randf_range(1.5, 4.0)


func cancel_movement() -> void:
	state = State.IDLE
	_idle_timer = _rng.randf_range(0.5, 2.0)


# ---------------------------------------------------------------------------
# AGGRO
# ---------------------------------------------------------------------------

func _enter_aggro(walkable_check: Callable, player_x: int, player_y: int) -> void:
	state = State.AGGRO
	_path.clear()
	_repath(walkable_check, player_x, player_y)


func _tick_aggro(local_map: Dictionary, walkable_check: Callable, player_x: int, player_y: int) -> void:
	# Re-path every few steps (player may have moved)
	if _path.is_empty() or _rng.randi() % 3 == 0:
		_repath(walkable_check, player_x, player_y)

	if _path.is_empty():
		# No path — give up and idle
		state = State.IDLE
		_idle_timer = _rng.randf_range(1.0, 2.0)
		return

	# Pop the next cell (skip the first which is our current pos)
	while _path.size() > 1 and _path[0] == Vector2i(grid_x, grid_y):
		_path.remove_at(0)

	if _path.size() <= 1:
		# Adjacent or on top — signal ATTACK
		if _path.size() == 1:
			_wander_target = _path[0]
		state = State.ATTACK
		return

	_wander_target = _path[1]  # [0] is current pos, [1] is next step
	_path.remove_at(0)


func get_next_aggro_step() -> Vector2i:
	if _path.size() >= 2:
		return _path[1]
	return Vector2i(_wander_target)


# ---------------------------------------------------------------------------
# BFS pathfinding
# ---------------------------------------------------------------------------

func _repath(walkable_check: Callable, player_x: int, player_y: int) -> void:
	_path = bfs_path(grid_x, grid_y, player_x, player_y, walkable_check)


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
			# Reconstruct path
			var path: Array[Vector2i] = []
			var node: Vector2i = current
			var node_key: String = "%d,%d" % [node.x, node.y]
			while parent.has(node_key):
				path.push_front(node)
				node = parent[node_key]
				node_key = "%d,%d" % [node.x, node.y]
			path.push_front(Vector2i(from_x, from_y))
			return path

		for offset in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var neighbor := Vector2i(current.x + offset.x, current.y + offset.y)
			var nkey := "%d,%d" % [neighbor.x, neighbor.y]
			if visited.has(nkey):
				continue
			if not walkable_check.call(neighbor.x, neighbor.y):
				continue
			visited[nkey] = true
			parent[nkey] = current
			queue.append(neighbor)

	return []  # no path


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _walkable_neighbors(x: int, y: int, walkable_check: Callable) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for offset in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var nx: int = x + offset.x
		var ny: int = y + offset.y
		if walkable_check.call(nx, ny):
			out.append(Vector2i(nx, ny))
	return out
