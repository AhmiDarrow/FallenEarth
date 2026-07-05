## Phase6PerformanceTest — Stress test for Phase 6 optimization systems.
## Spawns 50+ varied entities to measure FPS, LOD switching, pooling, and culling.
extends Control

var _viewport  # Entity3DViewport (untyped)
var _entities: Array = []  # Array of EntityVisualComponent
var _spawn_timer: float = 0.0
var _spawn_batch: int = 5
var _auto_spawn: bool = false
var _target_count: int = 60

var _preset_pool: Array[Dictionary] = [
	{"entity_id": "humanoid_1", "visual": {"base_type": "humanoid", "torso": {"height": 1.0, "color": [0.8, 0.7, 0.6]}, "head": {"scale": 0.2}, "limbs": {"count": 4, "leg_height": 0.6, "arm_height": 0.5}, "material": {"type": "organic", "roughness": 0.8}, "variation_seed": 100, "scale_range": [0.9, 1.1]}},
	{"entity_id": "humanoid_2", "visual": {"base_type": "humanoid", "torso": {"height": 1.1, "color": [0.35, 0.7, 0.3]}, "head": {"scale": 0.25, "attachments": ["horns"]}, "limbs": {"count": 4, "leg_height": 0.65, "arm_height": 0.55}, "material": {"type": "organic", "roughness": 0.85}, "variation_seed": 200, "scale_range": [0.9, 1.1]}},
	{"entity_id": "beast_quad", "visual": {"base_type": "beast", "torso": {"length": 1.2, "height": 0.6, "color": [0.35, 0.3, 0.25]}, "head": {"scale": 0.18}, "material": {"type": "organic", "roughness": 0.85}, "variation_seed": 300, "scale_range": [0.8, 1.2]}},
	{"entity_id": "beast_insect", "visual": {"base_type": "beast", "torso": {"length": 0.9, "height": 0.4, "color": [0.25, 0.35, 0.2]}, "head": {"scale": 0.15}, "material": {"type": "organic", "roughness": 0.6, "metallic": 0.3}, "variation_seed": 400, "scale_range": [0.7, 1.0]}},
	{"entity_id": "mech_default", "visual": {"base_type": "mechanical", "torso": {"height": 1.0, "color": [0.5, 0.5, 0.55]}, "head": {"scale": 0.2}, "limbs": {"count": 4, "leg_height": 0.6, "arm_height": 0.5}, "material": {"type": "metallic", "roughness": 0.3}, "variation_seed": 500, "scale_range": [0.9, 1.1]}},
	{"entity_id": "rift_void", "rift_type": 0, "visual": {"base_type": "rift", "radius": 1.5, "rift_type": 0, "material": {"type": "glow", "roughness": 0.1}, "variation_seed": 600, "scale_range": [0.8, 1.2]}},
	{"entity_id": "item_orb", "visual": {"base_type": "item", "style": "orb", "radius": 0.2, "color": [0.4, 0.7, 1.0], "material": {"type": "glow", "roughness": 0.3}, "variation_seed": 700, "scale_range": [0.8, 1.2]}},
	{"entity_id": "item_weapon", "visual": {"base_type": "item", "style": "weapon", "length": 0.6, "width": 0.06, "color": [0.7, 0.5, 0.3], "material": {"type": "metallic", "roughness": 0.4}, "variation_seed": 800, "scale_range": [0.9, 1.1]}},
	{"entity_id": "prop_door", "visual": {"base_type": "prop", "prop_type": "door", "width": 1.2, "height": 2.4, "color": [0.4, 0.3, 0.25], "material": {"type": "organic", "roughness": 0.9}, "variation_seed": 900, "scale_range": [0.9, 1.1]}},
	{"entity_id": "prop_container", "visual": {"base_type": "prop", "prop_type": "container", "width": 0.8, "height": 0.6, "depth": 0.6, "color": [0.45, 0.35, 0.3], "material": {"type": "metallic", "roughness": 0.5}, "variation_seed": 1000, "scale_range": [0.8, 1.2]}},
]

func _ready() -> void:
	_viewport = get_node_or_null("Entity3DLayer")
	if _viewport == null:
		push_warning("[Phase6PerformanceTest] Entity3DLayer node not found — test scene inactive")
		return
	_setup_ui()
	_spawn_batch_entities(10)

func _setup_ui() -> void:
	$UI/Controls/Spawn10Button.pressed.connect(func(): _spawn_batch_entities(10))
	$UI/Controls/Spawn30Button.pressed.connect(func(): _spawn_batch_entities(30))
	$UI/Controls/Spawn60Button.pressed.connect(func(): _spawn_batch_entities(60))
	$UI/Controls/ClearButton.pressed.connect(_on_clear)
	$UI/Controls/AutoSpawnButton.pressed.connect(_on_toggle_auto)
	$UI/Controls/ZoomInButton.pressed.connect(_on_zoom_in)
	$UI/Controls/ZoomOutButton.pressed.connect(_on_zoom_out)

func _process(delta: float) -> void:
	_update_stats()
	if _auto_spawn:
		_spawn_timer += delta
		if _spawn_timer >= 0.1:
			_spawn_timer = 0.0
			if _entities.size() < _target_count:
				_spawn_batch_entities(_spawn_batch)

func _spawn_batch_entities(count: int) -> void:
	var comp_script = load("res://scripts/procedural/EntityVisualComponent.gd")
	if comp_script == null:
		push_warning("[Phase6PerformanceTest] EntityVisualComponent.gd not found")
		return
	for i in count:
		var preset_idx := randi() % _preset_pool.size()
		var data: Dictionary = _preset_pool[preset_idx].duplicate(true)
		data["entity_id"] = "stress_%d_%d" % [Time.get_ticks_msec(), randi()]

		var comp = comp_script.new()
		comp.setup(data, _viewport)

		if comp.entity_root:
			var angle := randf() * TAU
			var dist := randf_range(2.0, 20.0)
			comp.entity_root.position = Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)

		comp.set_animation_state("idle")
		_entities.append(comp)

func _on_clear() -> void:
	for comp in _entities:
		if comp:
			comp.detach()
	_entities.clear()
	_auto_spawn = false
	$UI/Controls/AutoSpawnButton.text = "Auto: OFF"

func _on_toggle_auto() -> void:
	_auto_spawn = not _auto_spawn
	$UI/Controls/AutoSpawnButton.text = "Auto: ON" if _auto_spawn else "Auto: OFF"

func _on_zoom_in() -> void:
	_viewport.orthographic_size = maxf(_viewport.orthographic_size - 0.5, 1.0)
	_viewport.camera.size = _viewport.orthographic_size

func _on_zoom_out() -> void:
	_viewport.orthographic_size = minf(_viewport.orthographic_size + 0.5, 20.0)
	_viewport.camera.size = _viewport.orthographic_size

func _update_stats() -> void:
	var stats_label: RichTextLabel = $UI/StatsLabel
	if not stats_label:
		return
	var fps: float = _viewport.get_fps() if _viewport else 0.0
	var avg_fps: float = _viewport.get_avg_fps() if _viewport else 0.0
	var entity_count: int = _entities.size()
	var viewport_stats: Dictionary = _viewport.get_entity_stats() if _viewport else {}

	var fps_color := "green" if fps >= 55.0 else ("yellow" if fps >= 30.0 else "red")

	stats_label.text = "[b]Phase 6 Performance Test[/b]\n"
	stats_label.text += "[color=%s]FPS: %d (avg: %d)[/color]\n" % [fps_color, int(fps), int(avg_fps)]
	stats_label.text += "[b]Entities:[/b] %d / %d\n" % [entity_count, _viewport.max_entities if _viewport else 0]
	stats_label.text += "[b]LOD Full:[/b] %d | [b]Simplified:[/b] %d | [b]Culled:[/b] %d\n" % [
		viewport_stats.get("lod_full", 0),
		viewport_stats.get("lod_simplified", 0),
		viewport_stats.get("lod_culled", 0)
	]
	stats_label.text += "[b]Pool Active:[/b] %d | [b]Reserve:[/b] %d\n" % [
		viewport_stats.get("pool_active", 0),
		viewport_stats.get("pool_reserve", 0)
	]
	stats_label.text += "[b]Render Distance:[/b] %.1f\n" % (_viewport.render_distance if _viewport else 0.0)
	stats_label.text += "[b]LOD:[/b] %s | [b]Culling:[/b] %s | [b]Pooling:[/b] %s" % [
		"ON" if (_viewport and _viewport.enable_lod) else "OFF",
		"ON" if (_viewport and _viewport.enable_culling) else "OFF",
		"ON" if (_viewport and _viewport.enable_pooling) else "OFF"
	]
