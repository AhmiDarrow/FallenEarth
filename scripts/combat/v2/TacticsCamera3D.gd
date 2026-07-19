class_name TacticsCamera3D
extends Camera3D
## 3D tactical camera with pan, rotate, zoom, and free-look.
##
## Adapted from ramaureirac/godot-tactical-rpg camera system.
## Provides smooth isometric view with keyboard/mouse controls.

## Camera config
@export var pan_speed: float = 5.0
@export var rotate_speed: float = 2.0
@export var zoom_speed: float = 2.0
@export var zoom_min: float = 4.0
@export var zoom_max: float = 45.0
@export var boundary_radius: float = 10.0

## Isometric angles
@export var pitch_angle: float = -30.0
@export var yaw_angle: float = 45.0

## State
var _target_position: Vector3 = Vector3.ZERO
var _current_zoom: float = 10.0
var _rotation_target: float = 0.0
var _snap_next_frame: bool = true


var _grid_size: int = 20
var _default_zoom: float = 10.0


func _ready() -> void:
	_rotation_target = deg_to_rad(yaw_angle)


## Adjust zoom and boundary for grid size, called from CombatLevel3D
func configure_for_grid(grid_size: int) -> void:
	_grid_size = maxi(grid_size, 3)
	boundary_radius = float(_grid_size) * 1.2
	var ideal_zoom: float = float(_grid_size) * 1.5 + 1.0
	ideal_zoom *= 0.6
	_default_zoom = clampf(ideal_zoom, zoom_min, zoom_max)
	_current_zoom = _default_zoom
	_snap_next_frame = true


func _process(delta: float) -> void:
	_handle_input(delta)

	var pitch_rad: float = deg_to_rad(pitch_angle)
	var offset := Vector3(0, _current_zoom, 0)
	offset = offset.rotated(Vector3.RIGHT, pitch_rad)
	offset = offset.rotated(Vector3.UP, _rotation_target)
	var desired_pos := _target_position + offset

	if _snap_next_frame:
		global_position = desired_pos
		_snap_next_frame = false
	else:
		global_position = desired_pos

	look_at(_target_position, Vector3.UP)


func _handle_input(delta: float) -> void:
	var pan_dir := Vector3.ZERO
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		pan_dir.z -= 1.0
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		pan_dir.z += 1.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		pan_dir.x -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		pan_dir.x += 1.0

	if pan_dir != Vector3.ZERO:
		var yaw_rot := Transform3D().rotated(Vector3.UP, _rotation_target)
		pan_dir = yaw_rot.basis * pan_dir.normalized()
		pan_dir.y = 0
		_target_position += pan_dir * pan_speed * delta

	if Input.is_key_pressed(KEY_Q):
		_rotation_target -= rotate_speed * delta
	if Input.is_key_pressed(KEY_E):
		_rotation_target += rotate_speed * delta

	if Input.is_action_just_released("ui_page_up") or Input.is_key_pressed(KEY_Z):
		_current_zoom = clampf(_current_zoom - zoom_speed, zoom_min, zoom_max)
	if Input.is_action_just_released("ui_page_down") or Input.is_key_pressed(KEY_X):
		_current_zoom = clampf(_current_zoom + zoom_speed, zoom_min, zoom_max)
	if Input.is_key_pressed(KEY_C):
		reset_zoom()

	_target_position.x = clampf(_target_position.x, -boundary_radius, boundary_radius)
	_target_position.z = clampf(_target_position.z, -boundary_radius, boundary_radius)


func reset_zoom() -> void:
	_current_zoom = _default_zoom
	_snap_next_frame = true


func follow_pawn(pawn: Node3D) -> void:
	if pawn == null:
		return
	_target_position = pawn.global_position
	_target_position.y = 0.0
	_snap_next_frame = true


func set_target(pos: Vector3) -> void:
	_target_position = Vector3(pos.x, 0.0, pos.z)
	_snap_next_frame = true
