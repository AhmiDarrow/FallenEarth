## FollowCamera — Simple camera that follows a target node each frame.
## Attach to a Camera2D. Drag the target (e.g. player) into the export var.
class_name FollowCamera
extends Camera2D

@export var target: Node2D = null
@export var smoothing_enabled: bool = true
@export var smoothing_speed: float = 8.0


func _ready() -> void:
	position_smoothing_enabled = smoothing_enabled
	position_smoothing_speed = smoothing_speed


func _process(_delta: float) -> void:
	if target != null and is_instance_valid(target):
		global_position = target.global_position
