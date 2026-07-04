## EntityPreviewer — @tool editor script for previewing JSON entity visuals.
## Attach to any Node3D in the editor to preview procedural entity generation.
## Reads from appearance.json presets and displays the result in the viewport.
@tool
extends Node3D

@export var preview_preset: String = "humanoid_default":
	set(value):
		preview_preset = value
		if Engine.is_editor_hint():
			_rebuild_preview()

@export var auto_refresh: bool = true
@export var show_wireframe: bool = false
@export var preview_scale: float = 1.0

var _current_visual: Node3D
var _preview_camera: Camera3D

func _ready() -> void:
	if Engine.is_editor_hint():
		_setup_editor_camera()
		_rebuild_preview()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and auto_refresh:
		if _current_visual and not is_instance_valid(_current_visual):
			_rebuild_preview()

func _rebuild_preview() -> void:
	for child in get_children():
		if child != _preview_camera:
			child.queue_free()

	var data := _load_preset_data(preview_preset)
	if data.is_empty():
		_spawn_error_marker()
		return

	_current_visual = ProceduralEntityGenerator.create_visual({"visual": data})
	if _current_visual:
		_current_visual.name = "Preview_%s" % preview_preset
		_current_visual.scale = Vector3(preview_scale, preview_scale, preview_scale)
		add_child(_current_visual)
		_current_visual.owner = get_tree().edited_scene_root if get_tree() else null

func _load_preset_data(preset_name: String) -> Dictionary:
	var file := FileAccess.open("res://data/appearance.json", FileAccess.READ)
	if not file:
		return {}
	var json := JSON.parse_string(file.get_as_text())
	file.close()
	if json is Dictionary:
		var presets: Dictionary = json.get("visual_presets", {})
		if presets.has(preset_name):
			return presets[preset_name].duplicate(true)
	return {}

func _setup_editor_camera() -> void:
	_preview_camera = Camera3D.new()
	_preview_camera.name = "PreviewCamera"
	_preview_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_preview_camera.size = 3.0
	_preview_camera.position = Vector3(0.0, 3.0, 5.0)
	_preview_camera.rotation.x = deg_to_rad(-35.0)
	add_child(_preview_camera)
	_preview_camera.make_current()

func _spawn_error_marker() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "ErrorMarker"
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.5, 0.5)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.RED
	mi.material_override = mat
	add_child(mi)

func get_available_presets() -> Array[String]:
	var presets: Array[String] = []
	var file := FileAccess.open("res://data/appearance.json", FileAccess.READ)
	if not file:
		return presets
	var json := JSON.parse_string(file.get_as_text())
	file.close()
	if json is Dictionary:
		var preset_dict: Dictionary = json.get("visual_presets", {})
		for key in preset_dict:
			presets.append(key)
	return presets

func set_preset(preset_name: String) -> void:
	preview_preset = preset_name

func cycle_preset(direction: int = 1) -> void:
	var presets := get_available_presets()
	if presets.is_empty():
		return
	var idx := presets.find(preview_preset)
	idx = (idx + direction) % presets.size()
	if idx < 0:
		idx = presets.size() - 1
	preview_preset = presets[idx]
