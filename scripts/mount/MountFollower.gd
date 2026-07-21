class_name MountFollower
extends Node2D

const CELL_SIZE := 32
const FOLLOW_DISTANCE := 1
const MOVE_DURATION := 0.6

var mob_instance: MobInstance = null
var grid_x: int = 0
var grid_y: int = 0
var _is_moving: bool = false
var _walkable_check: Callable = Callable()


func setup(sprite_id: String, start_x: int, start_y: int, walkable: Callable) -> void:
	grid_x = start_x
	grid_y = start_y
	position = Vector2(start_x * CELL_SIZE + CELL_SIZE * 0.5, start_y * CELL_SIZE + CELL_SIZE * 0.5)
	_walkable_check = walkable

	var data := MobData.new()
	data.sprite_id = sprite_id
	data.display_name = "Mount"
	data.grid_x = start_x
	data.grid_y = start_y
	data.mob_type = "passive"

	mob_instance = MobInstance.new()
	mob_instance.setup(data)
	add_child(mob_instance)


func set_grid_position(gx: int, gy: int) -> void:
	grid_x = gx
	grid_y = gy
	position = Vector2(gx * CELL_SIZE + CELL_SIZE * 0.5, gy * CELL_SIZE + CELL_SIZE * 0.5)


func set_walkable_check(check: Callable) -> void:
	_walkable_check = check


func is_adjacent_to(tx: int, ty: int, range_cells: int = 1) -> bool:
	return abs(grid_x - tx) + abs(grid_y - ty) <= range_cells


func is_moving() -> bool:
	return _is_moving


func follow_player(player_x: int, player_y: int) -> void:
	if _is_moving:
		return
	var dist := maxi(abs(grid_x - player_x), abs(grid_y - player_y))
	if dist <= FOLLOW_DISTANCE:
		return

	var path := MobAIController.bfs_path(grid_x, grid_y, player_x, player_y, _walkable_check)
	if path.size() < 2:
		return

	var next := path[1]
	_start_move_to(next.x, next.y)


func _start_move_to(tx: int, ty: int) -> void:
	_is_moving = true
	var target_pos := Vector2(tx * CELL_SIZE + CELL_SIZE * 0.5, ty * CELL_SIZE + CELL_SIZE * 0.5)
	var tw: Tween = create_tween()
	tw.tween_property(self, "position", target_pos, MOVE_DURATION).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		grid_x = tx
		grid_y = ty
		_is_moving = false
	)
