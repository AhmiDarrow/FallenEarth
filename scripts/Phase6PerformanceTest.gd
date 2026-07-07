## Phase6PerformanceTest — Stress test for the procedural entity system.
##
## Spawns a configurable number of varied entities (default 60) laid out on a
## 2D grid under a Camera2D, each backed by a self-contained procedural
## EntityVisualComponent (private 3D studio SubViewport). Exercises the Phase 6
## culling path: offscreen studios stop rendering. Reports entity count, active
## (onscreen) viewport count, and frame timing so FPS can be eyeballed.
extends Control

const EntityVisualComponent := preload("res://scripts/procedural/EntityVisualComponent.gd")
const AppearanceManagerScript := preload("res://scripts/AppearanceManager.gd")

var _entities: Array = []
var _target_count: int = 60
var _spawned: int = 0
var _grid: Node2D = null
var _cam: Camera2D = null
var _am: Node = null

var _frame_times: Array = []
var _fps_label: RichTextLabel = null


func _ready() -> void:
	_am = AppearanceManagerScript.new()
	add_child(_am)
	_am.load_appearance_from_json()

	# 2D playfield + camera to drive culling.
	_grid = Node2D.new()
	_grid.name = "Grid"
	add_child(_grid)
	_cam = Camera2D.new()
	_cam.position = Vector2(640, 360)
	_grid.add_child(_cam)

	_fps_label = RichTextLabel.new()
	_fps_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_fps_label.custom_minimum_size = Vector2(360, 160)
	add_child(_fps_label)

	_spawn_batch(_target_count)


func _spawn_batch(count: int) -> void:
	var presets: Dictionary = _am.get_appearance_data().get("visual_presets", {})
	var keys: Array = presets.keys()
	if keys.is_empty():
		push_warning("[Phase6] No presets available.")
		return
	var cols := 12
	var spacing := 48
	for i in count:
		var key: String = keys[randi() % keys.size()]
		var vis: Dictionary = presets[key].duplicate(true)
		vis["id"] = "stress_%d" % (_spawned + i)
		var node := Node2D.new()
		node.position = Vector2((i % cols) * spacing, (i / cols) * spacing)
		_grid.add_child(node)
		var comp = EntityVisualComponent.new()
		comp.configure(vis, "default", 64.0)
		comp.culling_enabled = true
		node.add_child(comp)
		comp._setup()
		comp.set_state(randi() % 3)
		_entities.append(comp)
	_spawned += count
	print("[Phase6] spawned %d entities (total %d)." % [count, _spawned])


func _process(delta: float) -> void:
	_frame_times.append(delta)
	if _frame_times.size() > 120:
		_frame_times.pop_front()
	_update_stats()


func _update_stats() -> void:
	if _fps_label == null:
		return
	var active := 0
	for c in _entities:
		if is_instance_valid(c) and c.get("_sprite") != null and c.get("_sprite").visible:
			active += 1
	var avg_dt := 0.0
	for f in _frame_times:
		avg_dt += f
	avg_dt /= maxf(1, _frame_times.size())
	var fps := 0.0 if avg_dt <= 0.0 else 1.0 / avg_dt
	var col := "green" if fps >= 55.0 else ("yellow" if fps >= 30.0 else "red")
	_fps_label.text = "[b]Phase 6 Perf Test[/b]\n"
	_fps_label.text += "[color=%s]~FPS: %d[/color] (avg dt %.1f ms)\n" % [col, int(fps), avg_dt * 1000.0]
	_fps_label.text += "[b]Entities:[/b] %d\n" % _entities.size()
	_fps_label.text += "[b]Onscreen studios:[/b] %d (culled: %d)\n" % [active, _entities.size() - active]
	_fps_label.text += "[b]Culling:[/b] ON\n"
	fps = fps  # silence unused
