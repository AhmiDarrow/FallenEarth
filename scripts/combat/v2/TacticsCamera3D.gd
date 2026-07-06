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
@export var zoom_max: float = 20.0
@export var boundary_radius: float = 10.0
@export var follow_smoothing: float = 5.0

## Isometric angles
@export var pitch_angle: float = -35.0  ## degrees from horizontal
@export var yaw_angle: float = 45.0     ## degrees rotation

## State
var _target_position: Vector3 = Vector3.ZERO
var _current_zoom: float = 10.0
var _is_rotating: bool = false
var _rotation_target: float = 0.0


func _ready() -> void:
	# Set up initial isometric position
	_rotation_target = deg_to_rad(yaw_angle)
	_apply_initial_pose()


func _apply_initial_pose() -> void:
	var pitch_rad: float = deg_to_rad(pitch_angle)
	var yaw_rad: float = _rotation_target
	var offset := Vector3(0, _current_zoom, 0)
	# Rotate by pitch then yaw
	offset = offset.rotated(Vector3.RIGHT, pitch_rad)
	offset = offset.rotated(Vector3.UP, yaw_rad)
	global_position = _target_position + offset
	look_at(_target_position, Vector3.UP)


func _process(delta: float) -> void:
	_handle_input(delta)
	_smooth_follow(delta)
	_apply_camera_pose(delta)


func _handle_input(delta: float) -> void:
	# Pan (WASD)
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
		# Rotate pan direction by camera yaw so it's relative to view
		var yaw_rot := Transform3D().rotated(Vector3.UP, _rotation_target)
		pan_dir = yaw_rot.basis * pan_dir.normalized()
		pan_dir.y = 0  # keep panning horizontal
		_target_position += pan_dir * pan_speed * delta

	# Rotate (Q/E)
	if Input.is_key_pressed(KEY_Q):
		_rotation_target -= rotate_speed * delta
	if Input.is_key_pressed(KEY_E):
		_rotation_target += rotate_speed * delta

	# Zoom (scroll wheel via input actions or direct)
	if Input.is_action_just_released("ui_page_up") or Input.is_key_pressed(KEY_Z):
		_current_zoom = clampf(_current_zoom - zoom_speed, zoom_min, zoom_max)
	if Input.is_action_just_released("ui_page_down") or Input.is_key_pressed(KEY_X):
		_current_zoom = clampf(_current_zoom + zoom_speed, zoom_min, zoom_max)

	# Clamp target to boundary
	_target_position.x = clampf(_target_position.x, -boundary_radius, boundary_radius)
	_target_position.z = clampf(_target_position.z, -boundary_radius, boundary_radius)


func _smooth_follow(delta: float) -> void:
	# Smooth interpolation toward target (already handled in _apply_camera_pose)
	pass


func _apply_camera_pose(delta: float) -> void:
	var pitch_rad: float = deg_to_rad(pitch_angle)
	var offset := Vector3(0, _current_zoom, 0)
	offset = offset.rotated(Vector3.RIGHT, pitch_rad)
	offset = offset.rotated(Vector3.UP, _rotation_target)
	var desired_pos := _target_position + offset
	global_position = global_position.lerp(desired_pos, follow_smoothing * delta)
	look_at(_target_position, Vector3.UP)


func follow_pawn(pawn: Node3D) -> void:
	if pawn == null:
		return
	_target_position = pawn.global_position
	_target_position.y = 0.0


func set_target(pos: Vector3) -> void:
	_target_position = Vector3(pos.x, 0.0, pos.z)
