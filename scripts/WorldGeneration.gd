## WorldGeneration — Visual 3D hex-sphere preview with click-to-select starting tile.
extends Control

@onready var seed_edit: LineEdit = $VBox/TopBar/SeedHBox/SeedEdit
@onready var random_btn: Button = $VBox/TopBar/SeedHBox/RandomButton
@onready var small_btn: Button = $VBox/TopBar/SizeHBox/SmallBtn
@onready var medium_btn: Button = $VBox/TopBar/SizeHBox/MediumBtn
@onready var large_btn: Button = $VBox/TopBar/SizeHBox/LargeBtn
@onready var generate_btn: Button = $VBox/TopBar/GenerateBtn
@onready var back_btn: Button = $VBox/TopRow/BackBtn
@onready var continue_btn: Button = $VBox/ContentHBox/SideVBox/ContinueBtn
@onready var hex_grid: Node2D = $VBox/ContentHBox/HexMargin/HexGrid
@onready var hex_margin: MarginContainer = $VBox/ContentHBox/HexMargin
@onready var globe_container: SubViewportContainer = $VBox/ContentHBox/HexMargin/GlobeFrame/GlobeContainer
@onready var sub_viewport: SubViewport = $VBox/ContentHBox/HexMargin/GlobeFrame/GlobeContainer/SubViewport
@onready var world_info_label: RichTextLabel = $VBox/ContentHBox/SideVBox/WorldInfoPanel/WorldInfoLabel
@onready var selected_info_label: RichTextLabel = $VBox/ContentHBox/SideVBox/SelectedInfoPanel/SelectedInfoLabel

var world_generator: WorldGenerator = null
var generated_seed: String = ""
var generated_world: Dictionary = {}
var start_tile_key: String = ""
var start_tile_info: Dictionary = {}
var _hex_nodes: Dictionary = {}
var _selected_key: String = ""
var _world_size: int = 12
var _updating_size: bool = false

# 3D globe state
var _globe_built: bool = false
var _yaw: float = 0.0
var _pitch: float = -0.25
var _cam_distance: float = 10.0
var _globe_root: Node3D
var _yaw_pivot: Node3D
var _pitch_pivot: Node3D
var _camera_3d: Camera3D
var _hex_3d: Dictionary = {}
var _hex_3d_base_mat: Dictionary = {}
var _is_dragging_globe: bool = false
var _last_drag_pos: Vector2 = Vector2.ZERO
var _drag_moved: bool = false

const DEFAULT_SEED := "FallenEarth"
const SIZE_RADII := {"small": 8, "medium": 12, "large": 18}
const BIOME_COLORS := {
	"Ash Wastes": Color(0.75, 0.65, 0.5),
	"Rust Canyons": Color(0.85, 0.45, 0.35),
	"Neon Bogs": Color(0.4, 0.85, 0.55),
	"Scorched Plains": Color(0.9, 0.6, 0.3),
	"Ironwood Thicket": Color(0.35, 0.6, 0.35),
	"Glass Dunes": Color(0.7, 0.8, 0.95),
	"Corpse Fields": Color(0.55, 0.45, 0.5),
	"Stormspire Highlands": Color(0.5, 0.55, 0.75),
	"Toxin Marshes": Color(0.45, 0.7, 0.4),
	"Dead City Outskirts": Color(0.5, 0.5, 0.55),
	"Riftspire": Color(1.0, 0.85, 0.2),
}
const RIFT_COLOR := Color(1.0, 0.85, 0.2)
const SETTLEMENT_COLOR := Color(0.9, 0.9, 0.95)


func _ready() -> void:
	var bg_col := get_node_or_null("BG") as ColorRect
	if bg_col != null:
		bg_col.color = Color(0.04, 0.04, 0.07, 0.85)

	ButtonStyleHelper.apply_secondary(back_btn)
	ButtonStyleHelper.apply_primary(generate_btn)
	ButtonStyleHelper.apply_primary(continue_btn)
	ButtonStyleHelper.apply_ghost(random_btn)

	back_btn.pressed.connect(_on_back_pressed)
	random_btn.pressed.connect(_on_random_seed_pressed)
	generate_btn.pressed.connect(_on_generate_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)
	small_btn.toggled.connect(_on_size_toggled.bind("small"))
	medium_btn.toggled.connect(_on_size_toggled.bind("medium"))
	large_btn.toggled.connect(_on_size_toggled.bind("large"))
	_sync_size_buttons("medium")

	hex_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(globe_container):
		globe_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_globe_frame()

	if is_instance_valid(seed_edit):
		seed_edit.text = DEFAULT_SEED
	if is_instance_valid(continue_btn):
		continue_btn.disabled = true
	_update_world_info_label()
	_update_selected_info_label()

	world_generator = WorldGenerator.new()
	add_child(world_generator)
	if not world_generator.initialize():
		if is_instance_valid(world_info_label):
			world_info_label.text = "[color=red]Failed to load biome data![/color]"
		if is_instance_valid(generate_btn):
			generate_btn.disabled = true


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


func _on_random_seed_pressed() -> void:
	if is_instance_valid(seed_edit):
		seed_edit.text = "SEED_" + str(randi() % 100000)


func _on_size_toggled(pressed: bool, size_name: String) -> void:
	if not pressed or _updating_size:
		return
	_sync_size_buttons(size_name)


func _sync_size_buttons(size_name: String) -> void:
	if not SIZE_RADII.has(size_name):
		return
	_updating_size = true
	_world_size = int(SIZE_RADII[size_name])
	var pairs: Array = [
		[small_btn, "small"],
		[medium_btn, "medium"],
		[large_btn, "large"],
	]
	for pair in pairs:
		var btn: Button = pair[0]
		var name: String = pair[1]
		if not is_instance_valid(btn):
			continue
		var on: bool = (name == size_name)
		btn.button_pressed = on
		if on:
			ButtonStyleHelper.apply_primary(btn)
		else:
			ButtonStyleHelper.apply_ghost(btn)
	_updating_size = false


func _style_globe_frame() -> void:
	var frame: PanelContainer = get_node_or_null("VBox/ContentHBox/HexMargin/GlobeFrame") as PanelContainer
	if not is_instance_valid(frame):
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.09, 0.92)
	sb.border_color = Color(0.55, 0.48, 0.38, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_top = 10
	sb.content_margin_right = 10
	sb.content_margin_bottom = 10
	frame.add_theme_stylebox_override("panel", sb)


func _on_generate_pressed() -> void:
	var chosen_seed: String = DEFAULT_SEED
	if is_instance_valid(seed_edit):
		chosen_seed = seed_edit.text.strip_edges()
	if chosen_seed.is_empty():
		chosen_seed = DEFAULT_SEED
		if is_instance_valid(seed_edit):
			seed_edit.text = chosen_seed

	if is_instance_valid(world_info_label):
		world_info_label.text = "[i]Generating hexagonal sphere world for seed: " + chosen_seed + "...[/i]"

	if world_generator == null:
		world_generator = WorldGenerator.new()
		add_child(world_generator)
	if not world_generator.initialize():
		if is_instance_valid(world_info_label):
			world_info_label.text = "[color=red]World generator not ready. Check biomes.json.[/color]"
		return

	generated_world = world_generator.generate(chosen_seed, 1.0, _world_size)
	generated_seed = chosen_seed

	var cands = world_generator.get_starting_candidates(5)
	if cands.size() > 0:
		start_tile_key = cands[0]["key"]
		start_tile_info = cands[0]["tile"]

	_render_3d_globe()
	_update_world_info_label()

	if start_tile_key != "":
		select_hex(start_tile_key)

	if is_instance_valid(continue_btn):
		continue_btn.disabled = false
	print("[WorldGeneration] Hex sphere generated with seed: ", chosen_seed)


func _render_3d_globe() -> void:
	var vp: SubViewport = sub_viewport
	if not is_instance_valid(vp) and is_instance_valid(globe_container):
		vp = globe_container.get_node_or_null("SubViewport") as SubViewport
	if not is_instance_valid(vp):
		vp = get_node_or_null("VBox/ContentHBox/HexMargin/GlobeFrame/GlobeContainer/SubViewport") as SubViewport
	if not is_instance_valid(vp):
		return

	for c in vp.get_children():
		c.queue_free()
	_hex_3d.clear()
	_hex_3d_base_mat.clear()
	_globe_root = null
	_yaw_pivot = null
	_pitch_pivot = null
	_camera_3d = null
	_globe_built = false

	if generated_world.is_empty():
		return

	var root := Node3D.new()
	root.name = "GlobeRoot"
	vp.add_child(root)
	_globe_root = root

	# Thin underlay only — hexasphere tiles cover the full globe
	var base := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 3.72
	sph.height = 7.44
	base.mesh = sph
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.06, 0.06, 0.08)
	base_mat.roughness = 0.95
	base.material_override = base_mat
	root.add_child(base)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.95
	sun.rotation_degrees = Vector3(-40, 35, 0)
	root.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(25, -140, 10)
	root.add_child(fill)

	_yaw_pivot = Node3D.new()
	root.add_child(_yaw_pivot)
	_pitch_pivot = Node3D.new()
	_yaw_pivot.add_child(_pitch_pivot)
	_camera_3d = Camera3D.new()
	_camera_3d.position = Vector3(0, 0, _cam_distance)
	_camera_3d.transform.basis = Basis.looking_at(-_camera_3d.position.normalized(), Vector3.UP)
	_pitch_pivot.add_child(_camera_3d)

	# Fit hex disk to sphere per world size; size meshes from measured min gap
	var sphere_r: float = 4.0
	var hex_radius: int = _world_size
	if world_generator != null:
		hex_radius = world_generator.get_hex_radius()

	var layout: Dictionary = WorldGenerator.build_hex_sphere_layout(generated_world, hex_radius, sphere_r)
	var positions: Dictionary = layout.get("positions", {})
	var hex_3d_size: float = float(layout.get("hex_size", 0.35))
	var hex_h: float = clampf(hex_3d_size * 0.42, 0.08, 0.22)
	var hex_mesh: ArrayMesh = WorldGenerator.create_hex_prism_mesh(hex_3d_size, hex_h)
	var marker_r: float = clampf(hex_3d_size * 0.22, 0.05, 0.12)

	for key in generated_world:
		var tile: Dictionary = generated_world[key]
		var q: int = int(tile.get("q", 0))
		var r: int = int(tile.get("r", 0))
		var pos: Vector3
		if positions.has(key):
			pos = positions[key] as Vector3
		else:
			pos = WorldGenerator.get_hex_spherical_pos(q, r, hex_radius, sphere_r)
		var radial: Vector3 = pos.normalized()

		# Tangent from first sphere-graph neighbor (hexasphere adjacency)
		var tangent: Vector3 = Vector3.ZERO
		var nkeys: Array = tile.get("neighbor_keys", [])
		if nkeys.size() > 0:
			var nkey: String = str(nkeys[0])
			var pos_n: Vector3 = pos
			if positions.has(nkey):
				pos_n = positions[nkey] as Vector3
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
		mat.albedo_color = _biome_color(str(tile.get("name", "")))
		mat.roughness = 0.7
		if tile.get("is_start_candidate", false):
			mat.emission_enabled = true
			mat.emission = mat.albedo_color * 0.25
		if tile.get("is_riftspire", false):
			mat.emission_enabled = true
			mat.emission = RIFT_COLOR * 0.6
		mi.material_override = mat
		root.add_child(mi)
		_hex_3d[key] = mi
		_hex_3d_base_mat[key] = mat

		if tile.get("is_riftspire", false) or tile.get("is_town", false):
			var marker := MeshInstance3D.new()
			var ms := SphereMesh.new()
			ms.radius = marker_r
			ms.height = marker_r * 2.0
			marker.mesh = ms
			marker.position = pos + radial * (hex_h * 0.5 + marker_r * 1.2)
			var mm := StandardMaterial3D.new()
			mm.albedo_color = RIFT_COLOR if tile.get("is_riftspire", false) else SETTLEMENT_COLOR
			mm.emission_enabled = true
			mm.emission = mm.albedo_color * 0.8
			marker.material_override = mm
			root.add_child(marker)

	_yaw = 0.35
	_pitch = -0.25
	_cam_distance = 10.0
	_update_globe_camera()
	_globe_built = true

	if start_tile_key != "" and _hex_3d.has(start_tile_key):
		_highlight_3d_selection(start_tile_key)

	print(
		"[WorldGeneration] 3D globe: %d hexes | r=%d | min_nn=%.3f avg_nn=%.3f hex_size=%.3f"
		% [
			_hex_3d.size(),
			hex_radius,
			float(layout.get("min_neighbor", 0.0)),
			float(layout.get("avg_neighbor", 0.0)),
			hex_3d_size,
		]
	)


func _update_globe_camera() -> void:
	if not is_instance_valid(_yaw_pivot) or not is_instance_valid(_pitch_pivot) or not is_instance_valid(_camera_3d):
		return
	_yaw_pivot.rotation.y = _yaw
	_pitch_pivot.rotation.x = _pitch
	_camera_3d.position = Vector3(0, 0, _cam_distance)
	_camera_3d.transform.basis = Basis.looking_at(-_camera_3d.position.normalized(), Vector3.UP)


func _highlight_3d_selection(key: String) -> void:
	# Reset every tile to its original base material + scale
	for k in _hex_3d:
		var mi: MeshInstance3D = _hex_3d[k]
		mi.scale = Vector3.ONE
		if _hex_3d_base_mat.has(k):
			mi.material_override = _hex_3d_base_mat[k]

	# Highlight only the newly selected tile
	if not _hex_3d.has(key):
		return
	var sel: MeshInstance3D = _hex_3d[key]
	sel.scale = Vector3(1.09, 1.09, 1.09)
	if _hex_3d_base_mat.has(key):
		var base: StandardMaterial3D = _hex_3d_base_mat[key] as StandardMaterial3D
		var m: StandardMaterial3D = base.duplicate() as StandardMaterial3D
		m.emission_enabled = true
		m.emission = Color(1.0, 0.95, 0.5) * 0.55
		sel.material_override = m


func _try_pick_3d_hex(_global_mouse: Vector2) -> void:
	if not is_instance_valid(globe_container) or not is_instance_valid(_camera_3d) or _hex_3d.is_empty():
		return
	var local: Vector2 = globe_container.get_local_mouse_position()
	var cont_size: Vector2 = globe_container.size
	if cont_size.x <= 0.0 or cont_size.y <= 0.0:
		return
	var factor: Vector2 = Vector2(sub_viewport.size) / cont_size
	var vp_mouse: Vector2 = local * factor

	var closest_key: String = ""
	var min_d: float = 1e9
	for key in _hex_3d:
		var mi: MeshInstance3D = _hex_3d[key]
		var sp: Vector2 = _camera_3d.unproject_position(mi.global_position)
		var d: float = sp.distance_to(vp_mouse)
		if d < min_d:
			min_d = d
			closest_key = key
	if closest_key != "" and min_d < 55.0:
		select_hex(closest_key)


func _input(event: InputEvent) -> void:
	if _globe_built and is_instance_valid(globe_container):
		var grect: Rect2 = globe_container.get_global_rect()
		var gmouse: Vector2 = get_global_mouse_position()
		var over: bool = grect.has_point(gmouse)

		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed and over:
					_is_dragging_globe = true
					_last_drag_pos = gmouse
					_drag_moved = false
				elif not mb.pressed and _is_dragging_globe:
					_is_dragging_globe = false
					if not _drag_moved and over:
						_try_pick_3d_hex(gmouse)
				return
			if mb.pressed and over:
				if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
					_cam_distance = clampf(_cam_distance - 0.6, 5.0, 22.0)
					_update_globe_camera()
					return
				if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					_cam_distance = clampf(_cam_distance + 0.6, 5.0, 22.0)
					_update_globe_camera()
					return

		if event is InputEventMouseMotion and _is_dragging_globe:
			var mm: InputEventMouseMotion = event
			var delta: Vector2 = mm.global_position - _last_drag_pos
			if delta.length() > 2.0:
				_drag_moved = true
			_yaw -= delta.x * 0.004
			_pitch = clampf(_pitch - delta.y * 0.004, deg_to_rad(-82.0), deg_to_rad(82.0))
			_last_drag_pos = mm.global_position
			_update_globe_camera()
			return
		return


func _process(delta: float) -> void:
	if not _globe_built:
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
		_update_globe_camera()


func select_hex(key: String) -> void:
	_selected_key = key
	start_tile_key = key
	start_tile_info = generated_world.get(key, {})

	if _globe_built:
		_highlight_3d_selection(key)
		_update_selected_info_label()
		print("[WorldGeneration] Selected hex: %s" % key)
		return

	# Legacy 2D path (unused when globe is active)
	for k in _hex_nodes:
		var poly: Polygon2D = _hex_nodes[k]
		if k == key:
			poly.color = Color(1.0, 0.85, 0.4)
			poly.modulate = Color(1, 1, 1, 1)
		else:
			var tile: Dictionary = generated_world.get(k, {})
			poly.color = _biome_color(str(tile.get("name", "")))
			if tile.get("is_start_candidate", false):
				poly.modulate = Color(1, 1, 1, 1)
			else:
				poly.modulate = Color(0.85, 0.85, 0.85, 0.85)

	_update_selected_info_label()
	print("[WorldGeneration] Selected hex: %s" % key)


func _on_continue_pressed() -> void:
	if generated_world.is_empty() or start_tile_key.is_empty():
		return

	var gs := get_node_or_null("/root/GameState")
	if is_instance_valid(gs) and gs.has_method("set_world_data"):
		gs.call("set_world_data", generated_seed, generated_world)
		if gs.has_method("set_start_tile"):
			gs.call("set_start_tile", start_tile_key, start_tile_info)

	var nm := get_node_or_null("/root/NPCManager")
	if is_instance_valid(nm) and nm.has_method("generate_for_world"):
		var roster: Variant = nm.call("generate_for_world", generated_seed, generated_world, start_tile_key)
		var npc_count: int = roster.size() if roster is Dictionary else 0
		print("[WorldGeneration] Procedural NPC roster: %d unique recruits." % npc_count)

	print("[WorldGeneration] World ready. Start tile: ", start_tile_key)
	var gm := get_node_or_null("/root/GameManager")
	if is_instance_valid(gm) and gm.has_method("go_to_character_select"):
		gm.call_deferred("go_to_character_select")


func _update_world_info_label() -> void:
	if not is_instance_valid(world_info_label):
		return
	if generated_world.is_empty():
		world_info_label.text = "[i]Generate a world, then LMB-drag / WASD to spin the hex sphere and click a tile to start.[/i]"
		return

	var size_name := "Medium"
	if _world_size <= int(SIZE_RADII["small"]):
		size_name = "Small"
	elif _world_size >= int(SIZE_RADII["large"]):
		size_name = "Large"

	var biome_counts: Dictionary = {}
	for key in generated_world:
		var b: String = str(generated_world[key].get("name", "?"))
		biome_counts[b] = biome_counts.get(b, 0) + 1

	var biome_lines: PackedStringArray = []
	for b in biome_counts:
		biome_lines.append("%s: %d" % [b, biome_counts[b]])

	world_info_label.text = (
		"[b]WORLD INFO[/b]\n" +
		"Seed: %s | %s (r=%d)\n" % [generated_seed, size_name, _world_size] +
		"Tiles: %d | Biomes: %d\n" % [generated_world.size(), biome_counts.size()] +
		"%s" % ", ".join(biome_lines)
	)


func _update_selected_info_label() -> void:
	if not is_instance_valid(selected_info_label):
		return
	if _selected_key.is_empty() or start_tile_info.is_empty():
		selected_info_label.text = "[i]Click a hex to see tile info.[/i]"
		return

	var t: Dictionary = start_tile_info
	var biome: String = str(t.get("name", "?"))
	var temp: float = float(t.get("temperature", 0)) * 100.0
	var rain: float = float(t.get("rainfall", 0)) * 100.0
	var elev: float = float(t.get("elevation", 0))
	var rift: float = float(t.get("rift_chance", 0)) * 100.0
	var danger: String = str(t.get("danger_level", "unknown"))
	var tier: int = int(t.get("difficulty_tier", 0))
	var lr: Dictionary = t.get("level_range", {})
	var features: Array = t.get("features", [])
	var risks: Array = t.get("survival_risks", [])

	var tier_colors: Dictionary = {1: "#66bb6a", 2: "#aed581", 3: "#fff176", 4: "#ffab91", 5: "#ef5350"}
	var tier_color: String = str(tier_colors.get(tier, "#ffffff"))

	var lines: PackedStringArray = [
		"[b]SELECTED HEX[/b]",
		"[color=#c8e6c9]%s[/color] (%s)" % [biome, _selected_key],
		"Temp: %.0f%% | Rain: %.0f%%" % [temp, rain],
		"Elev: %.2f | Rift: %.0f%%" % [elev, rift],
		"[color=%s]Tier %d[/color] | Lv %d-%d" % [tier_color, tier, int(lr.get("min_level", 1)), int(lr.get("max_level", 1))],
		"Danger: %s" % danger.capitalize(),
	]
	if features.size() > 0:
		lines.append("Features: %s" % ", ".join(features))
	if risks.size() > 0:
		lines.append("[color=#ffab91]Risks: %s[/color]" % ", ".join(risks))

	selected_info_label.text = "\n".join(lines)


static func _biome_color(biome: String) -> Color:
	return BIOME_COLORS.get(biome, Color(0.35, 0.35, 0.4))
