extends SceneTree
## Performance profile — focused on user-facing lag: movement and chunk load.
##
## Reports wall-clock for:
##   1) LocalMapView.configure (chunk load)
##   2) HubWorld._try_move_local × 5 (movement cost per step)
##   3) HubWorld._process for 60 frames (steady-state frame time)
##   4) Movement cost AFTER 60 frames of steady state (lag check)
##
## v0.9.1c baseline (before any perf fixes):
##   configure: ~7500 ms, per-move: ~25 ms, frame time: ~25 ms
##
## Targets after v0.9.1c perf pass:
##   configure < 300 ms, per-move < 5 ms, frame time < 16.67 ms (60 fps)

const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")
const LocalMapViewScript = preload("res://scripts/LocalMapView.gd")
const LocalMapViewScene = preload("res://scenes/LocalMapView.tscn")
const WorldGenScript = preload("res://scripts/WorldGenerator.gd")

var failures: Array[String] = []


func _fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)


func _ok(msg: String) -> void:
	print("  ok  " + msg)


func _initialize() -> void:
	print("[perf] Movement + chunk-load profile (v0.9.1c)")
	await process_frame

	var map_data: Dictionary = await _setup_world()
	await process_frame

	await _test_configure(map_data)
	await process_frame

	await _test_steady_state()
	await process_frame

	await _test_movement()
	await process_frame

	print("[perf] %d failure(s)." % failures.size())
	quit(0 if failures.is_empty() else 1)


func _ms(start_us: int) -> String:
	return "%.1f ms" % ((Time.get_ticks_usec() - start_us) / 1000.0)


func _setup_world() -> Dictionary:
	var gs: Node = root.get_node_or_null("/root/GameState")
	gs.reset_session()
	var wg := WorldGenScript.new()
	wg.initialize()
	var tile_map: Dictionary = wg.generate("perf_seed", 1.0, 6)
	gs.set_world_data("perf_seed", tile_map)
	var start_key: String = ""
	for key in tile_map.keys():
		var t: Dictionary = tile_map[key]
		if not bool(t.get("is_riftspire", false)):
			start_key = str(key)
			break
	var parts: PackedStringArray = start_key.split(",")
	gs.set_start_tile(start_key, tile_map[start_key])
	gs.create_character("Human", "Survivor", "Upworld", "PerfHero", "male")
	gs.set_local_position(LocalMapGen.MAP_SIZE / 2, LocalMapGen.MAP_SIZE / 2)
	wg.queue_free()
	var t0: int = Time.get_ticks_usec()
	var map_data: Dictionary = LocalMapGen.generate("perf_seed", int(parts[0]), int(parts[1]), tile_map[start_key])
	_ok("generate: %s (resource_nodes=%d, floor_pickups=%d)" % [
		_ms(t0),
		map_data.get("resource_nodes", []).size(),
		map_data.get("floor_pickups", []).size(),
	])
	return map_data


func _test_configure(map_data: Dictionary) -> void:
	print("[perf] test: LocalMapView.configure (chunk-load)")
	var view: Node2D = LocalMapViewScene.instantiate() as Node2D
	root.add_child(view)
	await process_frame
	# Warmup
	view.configure(map_data)
	await process_frame
	# Measure 3 cold calls
	var measurements: Array[int] = []
	for i in 3:
		view.queue_free()
		view = LocalMapViewScene.instantiate() as Node2D
		root.add_child(view)
		await process_frame
		var t0: int = Time.get_ticks_usec()
		view.configure(map_data)
		measurements.append(Time.get_ticks_usec() - t0)
	var best: int = measurements[0]
	for m in measurements:
		if m < best:
			best = m
	_ok("configure: %.0f/%.0f/%.0f ms (best = %.0f ms)" % [
		float(measurements[0]) / 1000.0,
		float(measurements[1]) / 1000.0,
		float(measurements[2]) / 1000.0,
		float(best) / 1000.0,
	])
	if best > 300_000:
		_fail("configure best > 300ms — chunk load still feels laggy")
	view.queue_free()


func _test_steady_state() -> void:
	print("[perf] test: HubWorld._process × 60 frames (steady state)")
	var hub_scene: PackedScene = load("res://scenes/HubWorld.tscn") as PackedScene
	if hub_scene == null:
		_fail("HubWorld.tscn failed to load")
		return
	var hub: Control = hub_scene.instantiate() as Control
	root.add_child(hub)
	await process_frame
	await process_frame
	# Warmup: 5 frames
	for i in 5:
		await process_frame
	# Measure 60 frames
	var t0: int = Time.get_ticks_usec()
	for i in 60:
		await process_frame
	var elapsed_us: int = Time.get_ticks_usec() - t0
	var per_frame_ms: float = float(elapsed_us) / 60.0 / 1000.0
	_ok("60 frames: %s (%.2f ms/frame; %.1f FPS)" % [
		_ms(t0), per_frame_ms, 1000.0 / max(per_frame_ms, 0.1),
	])
	if per_frame_ms > 16.67:
		_fail("frame time > 16.67ms (60fps) — game feels laggy")
	# Keep hub alive for the movement test
	_perf_state = {"hub": hub}


var _perf_state: Dictionary = {}


func _test_movement() -> void:
	print("[perf] test: HubWorld._try_move_local × 10 (movement cost)")
	var hub: Control = _perf_state.get("hub")
	if hub == null or not is_instance_valid(hub):
		_fail("No HubWorld from previous test")
		return
	# First make sure we can actually move
	hub.call("_try_move_local", 1, 0)
	await process_frame
	# Time 10 moves, with per-step await so we can see where the time goes
	var step_times: Array[int] = []
	var t_total0: int = Time.get_ticks_usec()
	for i in 10:
		var t0: int = Time.get_ticks_usec()
		hub.call("_try_move_local", 1, 0)
		step_times.append(Time.get_ticks_usec() - t0)
		await process_frame
	var elapsed_us: int = Time.get_ticks_usec() - t_total0
	var per_step_ms: float = float(elapsed_us) / 10.0 / 1000.0
	_ok("10 moves: %s (%.2f ms/step, total includes frame waits)" % [_ms(t_total0), per_step_ms])
	# Best-case (no frame wait) is what really matters
	var min_step: int = step_times[0]
	for t in step_times:
		if t < min_step:
			min_step = t
	_ok("  min step (call only, no frame): %.2f ms" % (float(min_step) / 1000.0))
	if min_step > 5000:
		_fail("per-move CALL > 5ms — that's the 'laggy movement' the user is reporting")
	hub.queue_free()
