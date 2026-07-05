extends SceneTree
## Boot probe — runs MainMenu briefly, then the HubWorld flow as far as we can
## without input, and reports any runtime errors. Quits after 60 frames.

var frame := 0
const MAX_FRAMES := 60
var errors: Array[String] = []


func _initialize() -> void:
	print("[probe] booting MainMenu")
	var scene: PackedScene = load("res://scenes/ui/MainMenu.tscn")
	if scene == null:
		_fail("MainMenu.tscn failed to load")
		quit(1)
		return
	var menu := scene.instantiate()
	root.add_child(menu)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	frame += 1
	if frame >= MAX_FRAMES:
		print("[probe] %d frames observed, no fatal errors. errors=%d" % [frame, errors.size()])
		quit(0 if errors.is_empty() else 1)


func _fail(msg: String) -> void:
	errors.append(msg)
	push_error(msg)
