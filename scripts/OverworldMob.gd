## OverworldMob — A single mob entity on the overworld local map.
##
## Wraps MobVisual (sprite) + OverworldMobAI (state machine) + tween
## movement. Spawned by HubWorld when mobs are seeded. Each frame HubWorld
## calls `tick_mob()` which ticks the AI and tweens the sprite toward the
## next grid cell.
##
## When the mob reaches the player's cell, `reached_player` is emitted
## and HubWorld starts combat.

class_name OverworldMob
extends Node2D

signal reached_player(mob_data: Dictionary)

const CELL_SIZE: int = 24
const MOVE_SPEED: float = 0.22  # seconds per cell (≈ 4.5 cells/sec)

var mob_data: Dictionary = {}
var grid_x: int = 0
var grid_y: int = 0

var _ai: OverworldMobAI = null
var _visual: MobVisual = null
var _local_map: Dictionary = {}
var _moving: bool = false
var _move_tween: Tween = null

# Reference to the parent's walkable check (set by HubWorld).
# Signature: func(x: int, y: int) -> bool
var _walkable_check: Callable = Callable()


func setup(p_mob_data: Dictionary, p_cell_size: int, p_walkable: Callable) -> void:
	mob_data = p_mob_data
	grid_x = int(mob_data.get("local_x", 0))
	grid_y = int(mob_data.get("local_y", 0))
	_walkable_check = p_walkable

	# Position at cell center
	position = Vector2(
		grid_x * p_cell_size + p_cell_size * 0.5,
		grid_y * p_cell_size + p_cell_size * 0.5
	)

	# Create AI
	_ai = OverworldMobAI.new()
	_ai.set_grid_pos(grid_x, grid_y)
	_ai.seed_from_pos(grid_x, grid_y)

	# Read aggro_range from mob data (default 5 for aggressive, 3 for neutral)
	var mob_type: String = str(mob_data.get("mob_type", "aggressive"))
	_ai.aggro_range = int(mob_data.get("aggro_range", 5 if mob_type == "aggressive" else 3))
	_ai.mob_type = mob_type

	# Create visual
	_visual = MobVisual.new()
	_visual.name = "Visual"
	add_child(_visual)
	var sprite_id: String = str(mob_data.get("sprite_id", mob_data.get("type", "")))
	_visual.set_mob_sprite(sprite_id)


func tick_mob(delta: float, local_map: Dictionary, player_x: int, player_y: int) -> int:
	if _ai == null:
		return OverworldMobAI.State.IDLE

	# Don't tick AI while moving
	if _moving:
		return _ai.state

	_local_map = local_map
	_ai.tick(delta, local_map, player_x, player_y, _walkable_check)

	match _ai.state:
		OverworldMobAI.State.WANDER:
			if not _moving:
				_start_move_to(_ai._wander_target)
		OverworldMobAI.State.AGGRO:
			if not _moving:
				_start_move_to(_ai._wander_target)
		OverworldMobAI.State.ATTACK:
			if _ai.is_at_player(player_x, player_y):
				reached_player.emit(mob_data)

	return _ai.state


func get_grid_pos() -> Vector2i:
	return Vector2i(grid_x, grid_y)


func get_ai_state() -> int:
	if _ai != null:
		return _ai.state
	return OverworldMobAI.State.IDLE


# ---------------------------------------------------------------------------
# Movement
# ---------------------------------------------------------------------------

func _start_move_to(target: Vector2i) -> void:
	if _moving:
		return
	if target.x == grid_x and target.y == grid_y:
		return

	# Validate walkability
	if not _walkable_check.call(target.x, target.y):
		if _ai != null:
			_ai.cancel_movement()
		return

	_moving = true
	var target_pos := Vector2(
		target.x * CELL_SIZE + CELL_SIZE * 0.5,
		target.y * CELL_SIZE + CELL_SIZE * 0.5
	)

	# Kill any existing tween
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()

	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", target_pos, MOVE_SPEED).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_move_tween.tween_callback(_on_move_complete)


func _on_move_complete() -> void:
	_moving = false
	grid_x = int(round((position.x - CELL_SIZE * 0.5) / CELL_SIZE))
	grid_y = int(round((position.y - CELL_SIZE * 0.5) / CELL_SIZE))

	if _ai != null:
		if _ai.state == OverworldMobAI.State.WANDER:
			_ai.confirm_arrival()
		elif _ai.state == OverworldMobAI.State.AGGRO:
			# Update grid pos in AI; keep aggro
			_ai.set_grid_pos(grid_x, grid_y)


## Update GameState with the mob's new position (call after movement
## completes). Removes the old key and sets the new one.
func update_game_state(gs: GameState, hex_q: int, hex_r: int, old_x: int, old_y: int) -> void:
	var old_key: String = gs.mob_key(hex_q, hex_r, old_x, old_y)
	var new_key: String = gs.mob_key(hex_q, hex_r, grid_x, grid_y)
	if old_key == new_key:
		return
	# Remove old entry
	gs.remove_overworld_mob(old_key)
	# Set at new position
	var updated_data: Dictionary = mob_data.duplicate(true)
	updated_data["local_x"] = grid_x
	updated_data["local_y"] = grid_y
	gs.set_overworld_mob(new_key, updated_data)
	mob_data = updated_data
