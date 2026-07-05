## QuestTracker — Tracks active missions, objectives, and progress.
##
## Singleton that holds mission state and provides signals for UI updates.
extends Node

signal mission_added(mission: Dictionary)
signal mission_removed(mission_id: String)
signal objective_updated(mission_id: String, objective_index: int, progress: int, target: int)
signal mission_completed(mission_id: String, rewards: Dictionary)

var _active_missions: Dictionary = {}  # mission_id -> mission
var _mission_order: Array[String] = []


func _ready() -> void:
	print("[QuestTracker] Initialized.")


func add_mission(mission: Dictionary) -> void:
	var mid: String = str(mission.get("mission_id", ""))
	if mid.is_empty():
		return
	if _active_missions.has(mid):
		return
	_active_missions[mid] = mission
	_mission_order.append(mid)
	mission_added.emit(mission)
	print("[QuestTracker] Mission added: %s" % str(mission.get("title", mid)))


func remove_mission(mission_id: String) -> void:
	if not _active_missions.has(mission_id):
		return
	_active_missions.erase(mission_id)
	_mission_order.erase(mission_id)
	mission_removed.emit(mission_id)
	print("[QuestTracker] Mission removed: %s" % mission_id)


func update_objective(mission_id: String, objective_index: int, progress: int) -> void:
	if not _active_missions.has(mission_id):
		return
	var mission: Dictionary = _active_missions[mission_id]
	var objectives: Array = mission.get("objectives", [])
	if objective_index < 0 or objective_index >= objectives.size():
		return
	var obj: Dictionary = objectives[objective_index]
	var target: int = int(obj.get("target", 1))
	obj["current"] = progress
	# Check if mission is complete
	var all_done: bool = true
	for o in objectives:
		if int(o.get("current", 0)) < int(o.get("target", 1)):
			all_done = false
			break
	if all_done:
		var rewards: Dictionary = mission.get("rewards", {})
		mission_completed.emit(mission_id, rewards)
		print("[QuestTracker] Mission completed: %s" % mission_id)
	objective_updated.emit(mission_id, objective_index, progress, target)


func get_active_missions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for mid in _mission_order:
		if _active_missions.has(mid):
			out.append(_active_missions[mid])
	return out


func get_mission(mission_id: String) -> Dictionary:
	return _active_missions.get(mission_id, {})


func has_mission(mission_id: String) -> bool:
	return _active_missions.has(mission_id)


func get_mission_count() -> int:
	return _active_missions.size()


func clear_all() -> void:
	_active_missions.clear()
	_mission_order.clear()
