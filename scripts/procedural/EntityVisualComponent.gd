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

var entity_id: String = ""
var entity_root: Node3D
var _viewport_ref: Entity3DViewport
var _parent_2d: Node2D
var _entity_data: Dictionary = {}

func setup(entity_data: Dictionary, viewport: Entity3DViewport) -> void:
	_entity_data = entity_data
	entity_id = entity_data.get("entity_id", str(entity_data.hash()))
	_viewport_ref = viewport

	entity_root = ProceduralEntityGenerator.create_visual(entity_data)
	if entity_root:
		entity_root.name = "Entity_%s" % entity_id
		_viewport_ref.add_entity(entity_root)

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
	if entity_root and _viewport_ref:
		entity_root.queue_free()
	entity_root = null
	_viewport_ref = null
	_parent_2d = null
	queue_free()

func set_animation_state(state: String) -> void:
	animation_state = state
	_update_animation()

func update_equipment(equip_data: Dictionary) -> void:
	if not entity_root:
		return
	for slot in equip_data:
		var att: Node3D = ProceduralEntityGenerator._create_attachment(
			str(equip_data[slot]),
			RandomNumberGenerator.new()
		)
		if att:
			att.name = "Equip_%s" % slot
			var existing := entity_root.get_node_or_null("Equip_%s" % slot)
			if existing:
				existing.queue_free()
			match slot:
				"head":
					att.position.y = 0.6
				"torso":
					att.position.y = 0.1
				"hand":
					att.position = Vector3(0.3, 0.2, 0.0)
			entity_root.add_child(att)

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

func _update_animation() -> void:
	pass

func _get_viewport_center() -> Vector2:
	var root := get_tree().root
	if not root:
		return Vector2(640, 360)
	var size := root.size
	return Vector2(size.x * 0.5, size.y * 0.5)

func _get_pixel_scale() -> float:
	return 0.01
