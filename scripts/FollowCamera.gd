## FollowCamera — Simple camera that follows a target node each frame.
## Attach to a Camera2D. Drag the target (e.g. player) into the export var.
class_name FollowCamera
extends Camera2D

@export var target: Node2D = null:
	set(value):
		target = value
		set_process(target != null)
@export var smoothing_enabled: bool = true
@export var smoothing_speed: float = 8.0
@export var zoom_min: float = 0.25
@export var zoom_max: float = 3.0
@export var zoom_speed: float = 0.15


func _ready() -> void:
	position_smoothing_enabled = smoothing_enabled
	position_smoothing_speed = smoothing_speed
	set_process(target != null)


func _process(_delta: float) -> void:
	if target != null and is_instance_valid(target):
		global_position = target.global_position
	else:
		set_process(false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var z: float = zoom.x
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				z = clampf(z - zoom_speed, zoom_min, zoom_max)
			MOUSE_BUTTON_WHEEL_DOWN:
				z = clampf(z + zoom_speed, zoom_min, zoom_max)
			_:
				return
		zoom = Vector2(z, z)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var z: float = zoom.x
		match event.keycode:
			KEY_PAGEUP, KEY_EQUAL, KEY_KP_ADD:
				z = clampf(z - zoom_speed, zoom_min, zoom_max)
			KEY_PAGEDOWN, KEY_MINUS, KEY_KP_SUBTRACT:
				z = clampf(z + zoom_speed, zoom_min, zoom_max)
			_:
				return
		zoom = Vector2(z, z)
		get_viewport().set_input_as_handled()
