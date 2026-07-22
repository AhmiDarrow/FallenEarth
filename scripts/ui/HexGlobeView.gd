## HexGlobeView — Reusable 3D hexasphere globe with orbit camera and click-to-pick.
class_name HexGlobeView
extends Control

signal tile_clicked(tile_key: String)
signal tile_hovered(tile_key: String)

var _built: bool = false
var _yaw: float = 0.35
var _pitch: float = -0.25
var _cam_distance: float = 10.0

var _yaw_pivot: Node3D
var _pitch_pivot: Node3D
var _camera_3d: Camera3D
var _globe_root: Node3D

var _hex_meshes: Dictionary = {}
var _hex_base_mats: Dictionary = {}
var _marker_meshes: Dictionary = {}

var _sub_viewport: SubViewport
var _texture_rect: TextureRect

var _is_dragging: bool = false
var _last_drag_pos: Vector2 = Vector2.ZERO
var _drag_moved: bool = false

var _hex_size: float = 0.0
var _sphere_r: float = 4.0
var _tile_map: Dictionary = {}
var _interaction_enabled: bool = true


func setup(tile_map: Dictionary, hex_radius: int = 12, sphere_radius: float = 4.0) -> void:
	_tile_map = tile_map
	_sphere_r = sphere_radius

	_sub_viewport = SubViewport.new()
	_sub_viewport.disable_3d = false
	_sub_viewport.handle_input_locally = false
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_sub_viewport)

	_texture_rect = TextureRect.new()
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_texture_rect.texture = _sub_viewport.get_texture()
	_texture_rect.gui_input.connect(_on_globebox_gui_input)
	add_child(_texture_rect)

	resized.connect(_on_resized)
	_build_globe(hex_radius, sphere_radius)


func _on_resized() -> void:
	if not is_instance_valid(_sub_viewport) or not is_instance_valid(_texture_rect):
		return
	var ps: Vector2
	var ctrl: Control = get_parent_control()
	if ctrl != null and ctrl.size.x > 1.0 and ctrl.size.y > 1.0:
		ps = ctrl.size
	elif size.x > 1.0 and size.y > 1.0:
		ps = size
	else:
		ps = Vector2(1280, 720)
	var w: int = maxi(1, int(ps.x))
	var h: int = maxi(1, int(ps.y))
	_sub_viewport.size = Vector2i(w, h)
	_texture_rect.position = Vector2.ZERO
	_texture_rect.size = Vector2(w, h)


func is_built() -> bool:
	return _built


func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled


func _build_globe(hex_radius: int, sphere_radius: float) -> void:
	if not is_inside_tree():
		return
	_on_resized()

	var layout: Dictionary = WorldGenerator.build_hex_sphere_layout(_tile_map, hex_radius, sphere_radius)
	var positions: Dictionary = layout.get("positions", {})
	var hex_3d_size: float = float(layout.get("hex_size", 0.35))
	_hex_size = hex_3d_size
	var hex_h: float = clampf(hex_3d_size * 0.42, 0.08, 0.22)
	var hex_mesh: ArrayMesh = WorldGenerator.create_hex_prism_mesh(hex_3d_size, hex_h)

	var root := Node3D.new()
	root.name = "HexGlobeViewRoot"
	_sub_viewport.add_child(root)
	_globe_root = root

	var base_mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = sphere_radius * 0.93
	sph.height = sph.radius * 2.0
	base_mi.mesh = sph
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.03, 0.04, 0.07)
	base_mat.roughness = 0.95
	base_mi.material_override = base_mat
	root.add_child(base_mi)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.4
	sun.rotation_degrees = Vector3(-40, 35, 0)
	root.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.45
	fill.rotation_degrees = Vector3(25, -140, 10)
	root.add_child(fill)

	_yaw_pivot = Node3D.new()
	root.add_child(_yaw_pivot)
	_pitch_pivot = Node3D.new()
	_yaw_pivot.add_child(_pitch_pivot)
	_camera_3d = Camera3D.new()
	_camera_3d.current = true
	_camera_3d.position = Vector3(0, 0, _cam_distance)
	_camera_3d.transform.basis = Basis.looking_at(-_camera_3d.position.normalized(), Vector3.UP)
	_pitch_pivot.add_child(_camera_3d)

	for key in _tile_map:
		var tile: Dictionary = _tile_map[key]
		var pos: Vector3
		if positions.has(key):
			pos = positions[key] as Vector3
		else:
			continue

		var radial: Vector3 = pos.normalized()

		var tangent: Vector3 = Vector3.ZERO
		var nkeys: Array = tile.get("neighbor_keys", [])
		if nkeys.size() > 0:
			var nk: String = str(nkeys[0])
			var pos_n: Vector3 = pos
			if positions.has(nk):
				pos_n = positions[nk] as Vector3
			tangent = pos_n - pos
		if tangent.length_squared() < 1e-10:
			tangent = radial.cross(Vector3.UP)
			if tangent.length_squared() < 1e-10:
				tangent = radial.cross(Vector3.RIGHT)
		tangent = tangent.normalized()
		var bitangent: Vector3 = radial.cross(tangent).normalized()
		tangent = bitangent.cross(radial).normalized()
		var basis := Basis(tangent, bitangent, radial)

		var mi := MeshInstance3D.new()
		mi.mesh = hex_mesh
		mi.transform = Transform3D(basis, pos + radial * (hex_h * 0.28))

		var mat := StandardMaterial3D.new()
		mat.albedo_color = WorldGenerator.biome_color(str(tile.get("name", "")))
		mat.roughness = 0.7
		mi.material_override = mat

		root.add_child(mi)
		_hex_meshes[key] = mi
		_hex_base_mats[key] = mat

	_update_camera()
	_built = true


func _update_camera() -> void:
	if not is_instance_valid(_yaw_pivot) or not is_instance_valid(_pitch_pivot) or not is_instance_valid(_camera_3d):
		return
	_yaw_pivot.rotation.y = _yaw
	_pitch_pivot.rotation.x = _pitch
	_camera_3d.position = Vector3(0, 0, _cam_distance)
	_camera_3d.transform.basis = Basis.looking_at(-_camera_3d.position.normalized(), Vector3.UP)


func highlight_tile(key: String) -> void:
	if not _hex_meshes.has(key):
		return
	var mi: MeshInstance3D = _hex_meshes[key]
	mi.scale = Vector3(1.09, 1.09, 1.09)
	if _hex_base_mats.has(key):
		var base: StandardMaterial3D = _hex_base_mats[key] as StandardMaterial3D
		var m: StandardMaterial3D = base.duplicate() as StandardMaterial3D
		m.emission_enabled = true
		m.emission = Color(1.0, 0.95, 0.5) * 0.55
		mi.material_override = m


func clear_highlights() -> void:
	for key in _hex_meshes:
		var mi: MeshInstance3D = _hex_meshes[key]
		mi.scale = Vector3.ONE
		if _hex_base_mats.has(key):
			mi.material_override = _hex_base_mats[key]


func set_tile_color(key: String, color: Color) -> void:
	if not _hex_meshes.has(key):
		return
	if not _hex_base_mats.has(key):
		return
	var base: StandardMaterial3D = _hex_base_mats[key] as StandardMaterial3D
	var m: StandardMaterial3D = base.duplicate() as StandardMaterial3D
	m.albedo_color = color
	_hex_meshes[key].material_override = m


func set_tile_emission(key: String, color: Color, strength: float = 0.55) -> void:
	if not _hex_meshes.has(key):
		return
	if not _hex_base_mats.has(key):
		return
	var base: StandardMaterial3D = _hex_base_mats[key] as StandardMaterial3D
	var m: StandardMaterial3D = base.duplicate() as StandardMaterial3D
	m.emission_enabled = true
	m.emission = color * strength
	_hex_meshes[key].material_override = m


func reset_tile(key: String) -> void:
	if not _hex_meshes.has(key) or not _hex_base_mats.has(key):
		return
	_hex_meshes[key].scale = Vector3.ONE
	_hex_meshes[key].material_override = _hex_base_mats[key]


func reset_all_tiles() -> void:
	for key in _hex_meshes:
		reset_tile(key)


func _on_globebox_gui_input(event: InputEvent) -> void:
	if not _built or not _interaction_enabled:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_is_dragging = true
				_last_drag_pos = get_global_mouse_position()
				_drag_moved = false
			elif not mb.pressed and _is_dragging:
				_is_dragging = false
				if not _drag_moved:
					_try_pick_tile()
			accept_event()
			return
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_cam_distance = clampf(_cam_distance - 0.6, 5.0, 22.0)
				_update_camera()
				accept_event()
				return
			if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_cam_distance = clampf(_cam_distance + 0.6, 5.0, 22.0)
				_update_camera()
				accept_event()
				return
	if event is InputEventMouseMotion and _is_dragging:
		var mm: InputEventMouseMotion = event
		var delta: Vector2 = mm.global_position - _last_drag_pos
		if delta.length() > 2.0:
			_drag_moved = true
		_yaw -= delta.x * 0.004
		_pitch = clampf(_pitch - delta.y * 0.004, deg_to_rad(-82.0), deg_to_rad(82.0))
		_last_drag_pos = mm.global_position
		_update_camera()
		accept_event()
		return


func _try_pick_tile() -> void:
	if not is_instance_valid(_texture_rect) or not is_instance_valid(_camera_3d) or _hex_meshes.is_empty():
		return
	var local: Vector2 = _texture_rect.get_local_mouse_position()
	var cont_size: Vector2 = _texture_rect.size
	if cont_size.x <= 0.0 or cont_size.y <= 0.0:
		return
	var factor: Vector2 = Vector2(_sub_viewport.size) / cont_size
	var vp_mouse: Vector2 = local * factor

	var closest_key: String = ""
	var min_d: float = 1e9
	for key in _hex_meshes:
		var mi: MeshInstance3D = _hex_meshes[key]
		var sp: Vector2 = _camera_3d.unproject_position(mi.global_position)
		var d: float = sp.distance_to(vp_mouse)
		if d < min_d:
			min_d = d
			closest_key = key
	if closest_key != "" and min_d < 55.0:
		tile_clicked.emit(closest_key)


func _process(delta: float) -> void:
	if not _built or not _interaction_enabled:
		return
	var speed: float = 1.6 * delta
	var moved: bool = false
	if Input.is_key_pressed(KEY_A):
		_yaw += speed
		moved = true
	if Input.is_key_pressed(KEY_D):
		_yaw -= speed
		moved = true
	if Input.is_key_pressed(KEY_W):
		_pitch = clampf(_pitch + speed, deg_to_rad(-82.0), deg_to_rad(82.0))
		moved = true
	if Input.is_key_pressed(KEY_S):
		_pitch = clampf(_pitch - speed, deg_to_rad(-82.0), deg_to_rad(82.0))
		moved = true
	if moved:
		_update_camera()


func _exit_tree() -> void:
	_built = false
	_hex_meshes.clear()
	_hex_base_mats.clear()
	_marker_meshes.clear()
