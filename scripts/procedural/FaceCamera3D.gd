## FaceCamera3D — Billboard node that always faces the active camera.
## Attach as a child of any Node3D; the node will rotate each frame
## to face the nearest camera, keeping its local Z axis pointing at the camera.
## Useful for items, floating orbs, billboard sprites in 3D space.
class_name FaceCamera3D
extends Node3D

@export var enabled: bool = true
@export var flip: bool = false
@export var lock_x: bool = false
@export var lock_y: bool = false
@export var lock_z: bool = false

func _process(_delta: float) -> void:
	if not enabled:
		return
	_face_camera()

func _face_camera() -> void:
	var viewport := _get_viewport()
	if not viewport or not viewport.get_camera_3d():
		return
	var cam: Camera3D = viewport.get_camera_3d()
	var target_pos: Vector3 = cam.global_position
	var current_pos: Vector3 = global_position

	var look_target := target_pos
	if lock_x:
		look_target.x = current_pos.x
	if lock_y:
		look_target.y = current_pos.y
	if lock_z:
		look_target.z = current_pos.z

	if flip:
		var dir := (current_pos - look_target).normalized()
		look_target = current_pos + dir

	look_at(look_target, Vector3.UP)

func _get_viewport() -> Viewport:
	var node: Node = self
	while node:
		if node is Viewport:
			return node as Viewport
		node = node.get_parent()
	return null
