extends SceneTree
## Quick headless check that WorldGeneration can build the 3D globe without crashing.

func _init() -> void:
	print("[diag-3d] Loading WorldGeneration scene...")
	var scene := load("res://scenes/WorldGeneration.tscn") as PackedScene
	if scene == null:
		print("[diag-3d] FAIL: could not load scene")
		quit(1)
		return

	var root: Control = scene.instantiate()
	if root == null:
		print("[diag-3d] FAIL: no root control")
		quit(1)
		return
	get_root().add_child(root)

	# Trigger generate (uses current _world_size default 12)
	print("[diag-3d] Generating world...")
	if root.has_method("_on_generate_pressed"):
		root._on_generate_pressed()

	# render is synchronous
	var built := false
	var count := 0
	if root.get("_globe_built") != null:
		built = root.get("_globe_built")
		var h3d = root.get("_hex_3d")
		if h3d != null:
			count = h3d.size()
	print("[diag-3d] globe_built=", built, " hex_3d_count=", count)

	if built and count > 10:
		print("[diag-3d] SUCCESS: 3D globe built with tiles.")
		quit(0)
	else:
		print("[diag-3d] FAIL or partial build")
		quit(1)
