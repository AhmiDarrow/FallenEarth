## EntityVisualComponent — Bridges a 2D game body to a procedural 3D visual.
##
## Attach as a child of a Node2D game entity (mob, NPC, player, item, rift,
## prop). It builds a self-contained 3D "studio": a private SubViewport holding
## the composed Node3D from ProceduralEntityGenerator plus an orthographic
## camera. A Sprite2D billboard on THIS node is fed by the viewport's
## ViewportTexture, so the entity renders as a normal 2D sprite but is drawn by
## the 3D engine (lighting, shadows, materials, animation) — a true drop-in
## replacement for a PNG sprite.
##
## The 3D root stays centered in its own viewport (camera looks at origin), so
## the 2D parent's position drives where the billboard appears on screen. Facing
## and animation state are forwarded to EntityAnimator. Each component is
## self-contained (its own SubViewport studio).
class_name EntityVisualComponent
extends Node2D

const ProceduralEntityGenerator := preload("res://scripts/procedural/ProceduralEntityGenerator.gd")
const EntityAnimator := preload("res://scripts/procedural/EntityAnimator.gd")
const MaterialLibrary := preload("res://scripts/procedural/MaterialLibrary.gd")

var visual_data: Dictionary = {}

var _root3d: Node3D = null
var _animator: EntityAnimator = null
var _sprite: Sprite2D = null
var _viewport: SubViewport = null
var _facing: float = 0.0
var _alive: bool = true
var _billboard_size: float = 128.0


func _ready() -> void:
	if visual_data.is_empty():
		return
	_setup()


## Configure before adding to tree, or call after assigning (if already in tree).
## `group` is accepted for API compatibility (reserved for future shared-world
## pooling) but the component is currently self-contained.
func configure(data: Dictionary, group: String = "default", billboard_size: float = 128.0) -> void:
	visual_data = data
	_billboard_size = billboard_size
	if is_inside_tree():
		_setup()


func _setup() -> void:
	if visual_data.is_empty():
		return
	# Build the composed 3D entity.
	_root3d = ProceduralEntityGenerator.create_visual(visual_data)
	if _root3d == null:
		return

	# Private 3D studio viewport, centered offscreen-ish so its texture only
	# shows through the billboard Sprite2D, not the 2D scene directly.
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(int(_billboard_size), int(_billboard_size))
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.handle_input_locally = false
	add_child(_viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_color = Color(0.6, 0.6, 0.7)
	env.ambient_light_energy = 0.55
	if _viewport.world_3d != null:
		_viewport.world_3d.environment = env
	else:
		_apply_env_deferred.call_deferred(env)

	_viewport.add_child(_root3d)

	# Orthographic camera framing the entity at origin.
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.0
	cam.position = Vector3(0, 2.0, 4.0)
	cam.rotation_degrees = Vector3(-30, 0, 0)
	_viewport.add_child(cam)

	var sun := DirectionalLight3D.new()
	sun.position = Vector3(2, 8, 3)
	sun.rotation_degrees.x = -60
	sun.light_energy = 1.3
	_viewport.add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-3, 3, -2)
	fill.light_energy = 0.4
	_viewport.add_child(fill)

	# Phase 3: per-entity point light for glow-type visuals (rifts, items).
	if _is_glow_visual(visual_data):
		var glow := OmniLight3D.new()
		glow.position = Vector3(0, 1.0, 0)
		glow.light_energy = 2.0
		glow.omni_range = 6.0
		glow.light_color = _glow_color(visual_data)
		_viewport.add_child(glow)

	# Animator.
	_animator = EntityAnimator.new()
	_animator.bind(_root3d)
	_viewport.add_child(_animator)
	_animator.set_state(EntityAnimator.State.IDLE)

	# Billboard sprite.
	_sprite = Sprite2D.new()
	_sprite.texture = _viewport.get_texture()
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)

	_sync_facing()


static func _is_glow_visual(data: Dictionary) -> bool:
	var m: Dictionary = data.get("material", {})
	if m.get("type", "") == "glow":
		return true
	if data.get("base_type", "") == "rift":
		return true
	if data.get("base_type", "") == "item":
		return true
	return false


static func _glow_color(data: Dictionary) -> Color:
	if data.get("base_type", "") == "rift":
		var rt: int = int(data.get("rift_type", 0))
		var cols := [Color(0.6, 0.3, 1.0), Color(0.3, 1.0, 0.5), Color(1.0, 0.8, 0.3)]
		return cols[rt % cols.size()]
	var mat: Dictionary = data.get("material", {})
	if data.has("color"):
		var c = data["color"]
		if c is Array and c.size() >= 3:
			return Color(float(c[0]), float(c[1]), float(c[2]))
	return Color(0.5, 0.8, 1.0)


func _apply_env_deferred(env: Environment) -> void:
	if is_instance_valid(_viewport) and _viewport.world_3d != null:
		_viewport.world_3d.environment = env


## Culling margin (px) around the camera rect within which we keep rendering.
var cull_margin: float = 96.0
## When true (default) the 3D studio viewport is disabled while offscreen.
var culling_enabled: bool = true

func _process(_delta: float) -> void:
	if _root3d == null or not _alive:
		return
	_sync_facing()
	if culling_enabled:
		_update_culling()


## Phase 6: disable the per-entity 3D viewport when the billboard is outside
## the main camera's view rect (plus margin). This is the dominant perf win for
## many entities — offscreen studios stop consuming GPU/render time.
func _update_culling() -> void:
	if _viewport == null or _sprite == null:
		return
	var cam: Camera2D = get_viewport().get_camera_2d() if get_viewport() != null else null
	var onscreen: bool = true
	if cam != null:
		var vp: Viewport = get_viewport()
		var half: Vector2 = vp.size * 0.5 / cam.zoom
		var rect := Rect2(cam.global_position - half, half * 2.0)
		var expanded := Rect2(rect.position - Vector2(cull_margin, cull_margin),
			rect.size + Vector2(cull_margin * 2, cull_margin * 2))
		onscreen = expanded.has_point(get_global_position())
	if onscreen and _viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_sprite.visible = true
	elif not onscreen and _viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_sprite.visible = false


func _sync_facing() -> void:
	if _root3d != null:
		_root3d.rotation.y = _facing


## ---- Public API used by gameplay ---------------------------------------

func set_facing(angle: float) -> void:
	_facing = angle


func set_state(state: int) -> void:
	if _animator != null:
		_animator.set_state(state)


func play_death() -> void:
	_alive = false
	if _animator != null:
		_animator.set_state(EntityAnimator.State.DEAD)


func set_hover(outline: bool) -> void:
	if _root3d == null:
		return
	for mi in _iter_mesh_instances(_root3d):
		if outline:
			mi.material_overlay = MaterialLibrary.make_shader_variant(_base_mat_for(mi), MaterialLibrary.ShaderVariant.OUTLINE, {"outline_color": Color.CYAN})
		else:
			mi.material_overlay = null


func set_faction_tint(color: Color, strength: float = 0.35) -> void:
	if _root3d == null:
		return
	for mi in _iter_mesh_instances(_root3d):
		mi.material_overlay = MaterialLibrary.make_shader_variant(_base_mat_for(mi), MaterialLibrary.ShaderVariant.FACTION_TINT, {"faction_color": color, "tint_strength": strength})


static func _base_mat_for(mi: MeshInstance3D) -> StandardMaterial3D:
	if mi.material_override is StandardMaterial3D:
		return mi.material_override
	return null


func flash_damage(color: Color = Color(1.0, 0.2, 0.2)) -> void:
	if _animator != null:
		_animator.flash_damage(color)


static func _iter_mesh_instances(root: Node) -> Array:
	var out: Array = []
	for child in root.get_children():
		if child is MeshInstance3D:
			out.append(child)
		out.append_array(_iter_mesh_instances(child))
	return out


func _exit_tree() -> void:
	if is_instance_valid(_viewport):
		_viewport.queue_free()
