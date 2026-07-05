## NPCWanderer — Simple state machine for NPC ambient wandering.
##
## Manages NPC movement between connected rooms on a timer.
## States: IDLE → WANDER → RETURN.
class_name NPCWanderer
extends RefCounted

enum State { IDLE, WANDER, RETURN }

var npc_id: String = ""
var npc_name: String = ""
var role: String = ""
var current_room: String = ""
var home_x: int = 0
var home_y: int = 0
var current_x: int = 0
var current_y: int = 0
var wander_paths: Array = []
var wander_frequency: float = 60.0
var state: int = State.IDLE
var _timer: float = 0.0
var _target_room: String = ""
var _target_x: int = 0
var _target_y: int = 0
var _return_path: Array = []


func _init(npc_data: Dictionary, room_id: String) -> void:
	npc_id = str(npc_data.get("id", ""))
	npc_name = str(npc_data.get("name", "?"))
	role = str(npc_data.get("role", ""))
	current_room = room_id
	home_x = int(npc_data.get("x", 0))
	home_y = int(npc_data.get("y", 0))
	current_x = home_x
	current_y = home_y
	wander_paths = npc_data.get("wander_paths", [])
	wander_frequency = float(npc_data.get("wander_frequency", 60.0))
	_timer = randf_range(0.0, wander_frequency)


func tick(delta: float, player_cell: Vector2i, rooms: Dictionary) -> Dictionary:
	_timer -= delta

	match state:
		State.IDLE:
			return _tick_idle(delta, player_cell, rooms)
		State.WANDER:
			return _tick_wander(delta, player_cell, rooms)
		State.RETURN:
			return _tick_return(delta, player_cell, rooms)

	return {}


func _tick_idle(_delta: float, _player_cell: Vector2i, _rooms: Dictionary) -> Dictionary:
	if _timer <= 0.0:
		# Decide whether to wander
		if not wander_paths.is_empty():
			_target_room = wander_paths[randi() % wander_paths.size()]
			if _target_room != current_room:
				state = State.WANDER
				return {"action": "move_to_room", "room": _target_room}
			else:
				# Same room — just pick a random floor cell
				_timer = wander_frequency
		else:
			_timer = wander_frequency
	return {}


func _tick_wander(_delta: float, _player_cell: Vector2i, rooms: Dictionary) -> Dictionary:
	# When we arrive at the target room, set a timer and return
	state = State.RETURN
	_timer = randf_range(10.0, 30.0)
	return {"action": "arrived", "room": _target_room}


func _tick_return(_delta: float, _player_cell: Vector2i, rooms: Dictionary) -> Dictionary:
	if _timer <= 0.0:
		# Return home
		state = State.IDLE
		_timer = wander_frequency
		if _target_room != current_room:
			return {"action": "move_to_room", "room": current_room}
	return {}


func get_display_mood(player_nearby: bool, faction_rep: int) -> String:
	if player_nearby:
		if faction_rep >= 10:
			return "happy"
		elif faction_rep >= 0:
			return "neutral"
		else:
			return "angry"
	return ""


func get_mood_emoji(mood: String) -> String:
	match mood:
		"happy":
			return "😊"
		"neutral":
			return "😐"
		"angry":
			return "😠"
		_:
			return ""
