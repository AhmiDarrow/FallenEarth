## Compile-check harness — run with:
##   godot --headless --path . res://tools/check_scripts.tscn
## Recursively loads every .gd under ROOTS with autoloads present and
## reports compile status. Exits with the failure count as exit code.
extends Node

const ROOTS: Array[String] = [
	"res://scripts",
	"res://assets",
	"res://scenes",
	"res://tools",
	"res://user",
]


func _ready() -> void:
	var paths: Array[String] = []
	for root in ROOTS:
		_collect(root, paths)
	var failures: int = 0
	for path in paths:
		var res: Resource = ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_REPLACE)
		var scr: GDScript = res as GDScript
		if scr == null or not scr.can_instantiate():
			failures += 1
			print("CHECK FAIL: %s" % path)
	print("CHECK DONE: %d failure(s) out of %d script(s)" % [failures, paths.size()])
	get_tree().quit(failures)


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path + "/" + entry
		if dir.current_is_dir():
			if entry != "." and entry != "..":
				_collect(full, out)
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
