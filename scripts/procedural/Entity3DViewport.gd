## Entity3DViewport — SubViewport manager for rendering 3D entities as 2D textures.
## Attach to any Control/Node2D that needs a 3D->2D hybrid view.
## Creates and manages a SubViewport with orthographic Camera3D, transparent
## background, and provides the ViewportTexture for use in Sprite2D/TextureRect.
class_name Entity3DViewport
extends Node

signal entity_selected(entity_node: Node3D)

@export var viewport_width: int = 1280
@export var viewport_height: int = 720
@export var camera_distance: float = 8.0
@export var orthographic_size: float = 4.0
@export var transparent_bg: bool = true

var sub_viewport: SubViewport
var camera: Camera3D
var entity_root: Node3D
var viewport_texture: ViewportTexture
var display_sprite: Sprite2D
var display_texture_rect: TextureRect

func _ready() -> void:
	_setup_viewport()
	_wire_display()

func _setup_viewport() -> void:
	sub_viewport = SubViewport.new()
	sub_viewport.name = "Entity3DSubViewport"
	sub_viewport.size = Vector2i(viewport_width, viewport_height)
	sub_viewport.transparent_bg = transparent_bg
	sub_viewport.disable_3d = false
	sub_viewport.handle_input_locally = false
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	sub_viewport.render_target_v_flip = true
	add_child(sub_viewport)

	camera = Camera3D.new()
	camera.name = "EntityCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = orthographic_size
	camera.position = Vector3(0.0, camera_distance, camera_distance * 0.5)
	camera.rotation.x = deg_to_rad(-45.0)
	sub_viewport.add_child(camera)

	entity_root = Node3D.new()
	entity_root.name = "EntityRoot"
	sub_viewport.add_child(entity_root)

	viewport_texture = sub_viewport.get_texture()

func _wire_display() -> void:
	var display := get_node_or_null("Entity3DDisplay") as TextureRect
	if display:
		display.texture = viewport_texture

func set_world_environment(world_env: WorldEnvironment) -> void:
	if world_env:
		sub_viewport.world_3d = world_env.world_3d.duplicate()

func add_entity(entity: Node3D) -> void:
	entity_root.add_child(entity)

func clear_entities() -> void:
	for child in entity_root.get_children():
		child.queue_free()

func get_entity_count() -> int:
	return entity_root.get_child_count()

func set_camera_angle(pitch: float, yaw: float) -> void:
	camera.rotation.x = pitch
	camera.rotation.y = yaw

func set_camera_distance(dist: float) -> void:
	camera_distance = dist
	camera.position = Vector3(0.0, dist, dist * 0.5)

func resize(width: int, height: int) -> void:
	viewport_width = width
	viewport_height = height
	if sub_viewport:
		sub_viewport.size = Vector2i(width, height)

func create_display_sprite() -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = viewport_texture
	spr.name = "EntityDisplay"
	display_sprite = spr
	return spr

func create_display_texture_rect() -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = viewport_texture
	tr.name = "EntityDisplay"
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	display_texture_rect = tr
	return tr
