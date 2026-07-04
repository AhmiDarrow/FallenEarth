## EntityVisualComponent — Attaches procedural 3D visuals to existing 2D nodes.
## Syncs position/rotation between the 2D node and its 3D representation
## in the Entity3DViewport every frame via _process.
class_name EntityVisualComponent
extends Node

signal visual_updated(entity_node: Node3D)

@export var animation_state: String = "idle"
@export var facing_angle: float = 0.0
@export var height_offset: float = 0.0
@export var track_2d_node: bool = true
@export var billboard: bool = false
@export var glow_color: Color = Color.TRANSPARENT

var entity_id: String = ""
var entity_root: Node3D
var animator: EntityAnimator
var _viewport_ref: Entity3DViewport
var _parent_2d: Node2D
var _entity_data: Dictionary = {}
var _face_camera: FaceCamera3D

func setup(entity_data: Dictionary, viewport: Entity3DViewport) -> void:
	_entity_data = entity_data
	entity_id = entity_data.get("entity_id", str(entity_data.hash()))
	_viewport_ref = viewport

	entity_root = ProceduralEntityGenerator.create_visual(entity_data)
	if entity_root:
		entity_root.name = "Entity_%s" % entity_id
		_viewport_ref.add_entity(entity_root)
		_setup_animator(entity_data)

	if billboard:
		_add_billboard()

	if glow_color.a > 0.0:
		_viewport_ref.add_point_light(entity_id, glow_color, 1.5, 3.0)

func _setup_animator(data: Dictionary) -> void:
	animator = EntityAnimator.new()
	animator.name = "EntityAnimator"
	var vis: Dictionary = data.get("visual", {})
	var preset: String = vis.get("base_type", "humanoid")
	animator.entity_type = preset
	entity_root.add_child(animator)

func attach_to_2d(node: Node2D) -> void:
	_parent_2d = node
	if not _parent_2d:
		return
	if not is_instance_valid(_parent_2d):
		return
	_sync_position()
	if track_2d_node:
		set_process(true)

func detach() -> void:
	if glow_color.a > 0.0:
		_viewport_ref.remove_point_light(entity_id)
	if animator:
		animator.queue_free()
		animator = null
	if entity_root and _viewport_ref:
		entity_root.queue_free()
	entity_root = null
	_viewport_ref = null
	_parent_2d = null
	queue_free()

func set_animation_state(state: String) -> void:
	animation_state = state
	if animator:
		animator.set_state_by_name(state)

func trigger_attack() -> void:
	if animator:
		animator.trigger_attack()

func update_equipment(equip_data: Dictionary) -> void:
	if not entity_root:
		return
	for slot in equip_data:
		var item_data: Variant = equip_data[slot]
		var att: Node3D = null
		var item_dict: Dictionary = {}

		if item_data is Dictionary:
			item_dict = item_data
			att = ProceduralEntityGenerator.create_visual(item_dict)
		elif item_data is String:
			att = ProceduralEntityGenerator._create_attachment(
				item_data,
				RandomNumberGenerator.new()
			)

		if att:
			att.name = "Equip_%s" % slot
			var existing := entity_root.get_node_or_null("Equip_%s" % slot)
			if existing:
				existing.queue_free()

			var hand_pos := Vector3(0.45, 0.2, 0.0)
			var head_pos := Vector3(0.0, 0.8, 0.0)
			var torso_pos := Vector3(0.0, 0.1, 0.0)
			var back_pos := Vector3(0.0, 0.3, -0.3)

			match slot:
				"hand", "main_hand":
					att.position = hand_pos
					att.scale = Vector3(0.5, 0.5, 0.5)
				"off_hand":
					att.position = Vector3(-0.45, 0.2, 0.0)
					att.scale = Vector3(0.4, 0.4, 0.4)
				"head":
					att.position = head_pos
					att.scale = Vector3(0.6, 0.6, 0.6)
				"torso":
					att.position = torso_pos
					att.scale = Vector3(0.8, 0.8, 0.8)
				"back":
					att.position = back_pos
					att.scale = Vector3(0.6, 0.6, 0.6)
				_:
					att.position = hand_pos
					att.scale = Vector3(0.5, 0.5, 0.5)

			entity_root.add_child(att)

func unequip_slot(slot: String) -> void:
	if not entity_root:
		return
	var existing := entity_root.get_node_or_null("Equip_%s" % slot)
	if existing:
		existing.queue_free()

func set_glow(color: Color, energy: float = 1.5, radius: float = 3.0) -> void:
	glow_color = color
	if glow_color.a > 0.0:
		_viewport_ref.add_point_light(entity_id, color, energy, radius)
	else:
		_viewport_ref.remove_point_light(entity_id)

func _add_billboard() -> void:
	if not entity_root:
		return
	_face_camera = FaceCamera3D.new()
	_face_camera.name = "FaceCamera"
	entity_root.add_child(_face_camera)
	for child in entity_root.get_children():
		if child != _face_camera and child is Node3D and child != animator:
			child.reparent(_face_camera)

func _process(_delta: float) -> void:
	if track_2d_node and _parent_2d:
		_sync_position()

func _sync_position() -> void:
	if not _parent_2d or not entity_root:
		return
	if not is_instance_valid(_parent_2d):
		return
	var world_pos := _parent_2d.global_position
	var screen_center := _get_viewport_center()
	var scale_factor: float = _get_pixel_scale()

	var x_3d := (world_pos.x - screen_center.x) * scale_factor
	var y_3d := height_offset
	var z_3d := (world_pos.y - screen_center.y) * scale_factor

	entity_root.position = Vector3(x_3d, y_3d, z_3d)
	entity_root.rotation.y = facing_angle

	if _viewport_ref and glow_color.a > 0.0:
		_viewport_ref.update_point_light_position(entity_id, entity_root.position)

func _update_animation() -> void:
	if animator:
		animator.set_state_by_name(animation_state)

func _get_viewport_center() -> Vector2:
	var root := get_tree().root
	if not root:
		return Vector2(640, 360)
	var size := root.size
	return Vector2(size.x * 0.5, size.y * 0.5)

func _get_pixel_scale() -> float:
	return 0.01
