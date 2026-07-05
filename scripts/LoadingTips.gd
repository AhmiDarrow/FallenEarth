## LoadingTips — Random gameplay tips for transition screens.
##
## Autoload singleton. Loads tips from data/tips.json.
extends Node

var _tips: Array[String] = []
var _last_index: int = -1


func _ready() -> void:
	_load_tips()


func _load_tips() -> void:
	if not FileAccess.file_exists("res://data/tips.json"):
		push_warning("[LoadingTips] data/tips.json not found")
		return
	var file := FileAccess.open("res://data/tips.json", FileAccess.READ)
	if file == null:
		push_warning("[LoadingTips] Could not open data/tips.json")
		return
	var json := JSON.new()
	var err: Error = json.parse(file.get_as_text())
	if err != OK:
		push_warning("[LoadingTips] JSON parse error: %s" % json.get_error_message())
		return
	var data: Variant = json.data
	if not data is Dictionary:
		push_warning("[LoadingTips] Invalid tips.json format")
		return
	var tip_array: Variant = (data as Dictionary).get("tips", [])
	if tip_array is Array:
		for tip in tip_array:
			if tip is String:
				_tips.append(tip)
	print("[LoadingTips] Loaded %d tips" % _tips.size())


## Return a random tip, avoiding consecutive repeats.
func get_random_tip() -> String:
	if _tips.is_empty():
		return ""
	if _tips.size() == 1:
		return _tips[0]
	var idx: int = randi() % _tips.size()
	while idx == _last_index and _tips.size() > 1:
		idx = randi() % _tips.size()
	_last_index = idx
	return _tips[idx]


func get_tip_count() -> int:
	return _tips.size()
