## Entity3DViewport — SubViewport manager for rendering 3D entities as 2D textures.
## Attach to any Control/Node2D that needs a 3D->2D hybrid view.
## Creates and manages a SubViewport with orthographic Camera3D, transparent
## background, lighting, and provides the ViewportTexture for use in Sprite2D/TextureRect.
class_name Entity3DViewport
extends Node

signal entity_selected(entity_node: Node3D)

@export var viewport_width: int = 1280
@export var viewport_height: int = 720
@export var camera_distance: float = 8.0
@export var orthographic_size: float = 4.0
@export var transparent_bg: bool = true
@export var enable_lighting: bool = true
@export var enable_ambient_light: bool = true
@export var enable_y_sort: bool = true
@export var y_sort_pixels_per_unit: float = 100.0

var sub_viewport: SubViewport
var camera: Camera3D
var entity_root: Node3D
var world_environment: WorldEnvironment
var directional_light: DirectionalLight3D
var viewport_texture: ViewportTexture
var display_sprite: Sprite2D
var display_texture_rect: TextureRect

var _point_lights: Dictionary = {}

func _ready() -> void:
	_setup_viewport()
	_wire_display()
	get_tree().root.size_changed.connect(_on_window_resized)

func _on_window_resized() -> void:
	if not get_tree() or not get_tree().root:
		return
	var size := get_tree().root.size
	resize(size.x, size.y)

func _process(_delta: float) -> void:
	if enable_y_sort:
		_sort_by_depth()

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

	if enable_lighting:
		_setup_lighting()

	viewport_texture = sub_viewport.get_texture()

func _setup_lighting() -> void:
	world_environment = WorldEnvironment.new()
	world_environment.name = "EntityWorldEnvironment"
	var env := Environment.new()
	if enable_ambient_light:
		env.ambient_light_color = Color(0.25, 0.25, 0.3)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	world_environment.environment = env
	sub_viewport.add_child(world_environment)

	directional_light = DirectionalLight3D.new()
	directional_light.name = "EntityDirectionalLight"
	directional_light.light_color = Color(1.0, 0.95, 0.9)
	directional_light.light_energy = 1.5
	directional_light.light_indirect_energy = 0.5
	directional_light.shadow_enabled = true
	directional_light.shadow_bias = 0.05
	directional_light.rotation.x = deg_to_rad(-45.0)
	directional_light.rotation.y = deg_to_rad(30.0)
	sub_viewport.add_child(directional_light)

func add_point_light(entity_id: String, color: Color, energy: float = 2.0, radius: float = 2.0) -> void:
	if _point_lights.has(entity_id):
		return
	var light := OmniLight3D.new()
	light.name = "PointLight_%s" % entity_id
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	sub_viewport.add_child(light)
	_point_lights[entity_id] = light

func update_point_light_position(entity_id: String, position_3d: Vector3) -> void:
	if _point_lights.has(entity_id):
		_point_lights[entity_id].position = position_3d

func remove_point_light(entity_id: String) -> void:
	if _point_lights.has(entity_id):
		_point_lights[entity_id].queue_free()
		_point_lights.erase(entity_id)

func _sort_by_depth() -> void:
	var children := entity_root.get_children()
	if children.size() < 2:
		return
	var unsorted := false
	for i in range(1, children.size()):
		if children[i].position.z < children[i - 1].position.z:
			unsorted = true
			break
	if not unsorted:
		return
	children.sort_custom(_depth_sorter)
	for child in entity_root.get_children():
		entity_root.remove_child(child)
	for child in children:
		entity_root.add_child(child)

static func _depth_sorter(a: Node3D, b: Node3D) -> bool:
	return a.position.z < b.position.z

func set_y_sort(enabled: bool) -> void:
	enable_y_sort = enabled

func _wire_display() -> void:
	var display := get_node_or_null("Entity3DDisplay") as TextureRect
	if display:
		display.texture = viewport_texture
		var shader := preload("res://assets/shaders/viewport_pixelate.gdshader") as Shader
		if shader:
			var mat := ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("pixel_size", Vector2(1.0 / viewport_width, 1.0 / viewport_height))
			mat.set_shader_parameter("stylize_strength", 0.3)
			display.material = mat

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
	var display := get_node_or_null("Entity3DDisplay") as TextureRect
	if display and display.material is ShaderMaterial:
		display.material.set_shader_parameter("pixel_size", Vector2(1.0 / width, 1.0 / height))

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
