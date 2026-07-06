extends SceneTree
## Quick screenshot of the TacticalCombat scene for visual QA.
## Renders the scene and saves a PNG of the viewport.

func _initialize() -> void:
	print("[screenshot-combat] Booting TacticalCombat...")
	var packed: PackedScene = load("res://scenes/TacticalCombat.tscn") as PackedScene
	if packed == null:
		print("ERROR: TacticalCombat.tscn failed to load")
		quit(1)
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	# Tick frames to let everything wire up
	for i in range(60):
		await process_frame
	# Get the viewport and grab a frame
	var vp: Viewport = root
	var img: Image = vp.get_texture().get_image()
	if img == null:
		print("ERROR: viewport image is null")
		quit(1)
		return
	var path: String = "user://combat_screenshot.png"
	var err: int = img.save_png(path)
	if err != OK:
		print("ERROR: failed to save image to %s (err %d)" % [path, err])
		quit(1)
		return
	print("[screenshot-combat] saved to %s (%dx%d)" % [path, img.get_width(), img.get_height()])
	quit(0)
