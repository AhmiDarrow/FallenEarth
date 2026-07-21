## TamedMobManager — Tracks all tamed mobs (mounts + companions) for the player.
## Autoload singleton. State is persisted via SaveManager snapshot/restore.
extends Node

signal tamed_mob_added(mob: Dictionary)
signal tamed_mob_removed(mob_id: String)
signal mount_changed(mount_id: String)
signal riding_changed(is_riding: bool)


var _tamed_mobs: Array[Dictionary] = []
var _active_mount_id: String = ""
var _is_riding: bool = false

const TameCalc = preload("res://scripts/TameCalculator.gd")


func register_tame(
	mob_template_id: String,
	mob_name: String,
	tamable_type: String,
	mount_bonus: Dictionary,
	tame_difficulty: float,
	player_level: int,
	sprite_id: String = ""
) -> Dictionary:
	var mob_id := _next_id()
	var entry: Dictionary = {
		"id": mob_id,
		"template_id": mob_template_id,
		"name": mob_name,
		"custom_name": mob_name,
		"tamable_type": tamable_type,
		"mount_bonus": mount_bonus.duplicate(),
		"tame_difficulty": tame_difficulty,
		"tamed_at_level": player_level,
		"cooldown_remaining": 0,
		"sprite_id": sprite_id,
	}
	_tamed_mobs.append(entry)
	tamed_mob_added.emit(entry)
	return entry


func release_tamed(mob_id: String) -> void:
	for i in range(_tamed_mobs.size()):
		if _tamed_mobs[i].get("id", "") == mob_id:
			var mob: Dictionary = _tamed_mobs[i]
			_tamed_mobs.remove_at(i)
			if _active_mount_id == mob_id:
				_active_mount_id = ""
				if _is_riding:
					_is_riding = false
					riding_changed.emit(false)
				mount_changed.emit("")
			tamed_mob_removed.emit(mob_id)
			return


func set_custom_name(mob_id: String, new_name: String) -> void:
	for mob in _tamed_mobs:
		if mob.get("id", "") == mob_id:
			mob["custom_name"] = new_name
			return


func get_all_tamed() -> Array[Dictionary]:
	return _tamed_mobs.duplicate()


func get_mounts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for mob in _tamed_mobs:
		if mob.get("tamable_type", "") == "mount":
			out.append(mob.duplicate())
	return out


func get_companions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for mob in _tamed_mobs:
		if mob.get("tamable_type", "") == "companion":
			out.append(mob.duplicate())
	return out


func set_active_mount(mob_id: String) -> bool:
	if mob_id.is_empty():
		_active_mount_id = ""
		if _is_riding:
			_is_riding = false
			riding_changed.emit(false)
		mount_changed.emit("")
		return true
	for mob in _tamed_mobs:
		if mob.get("id", "") == mob_id and mob.get("tamable_type", "") == "mount":
			if _active_mount_id != mob_id and _is_riding:
				_is_riding = false
				riding_changed.emit(false)
			_active_mount_id = mob_id
			mount_changed.emit(mob_id)
			return true
	return false


func get_active_mount() -> Dictionary:
	if _active_mount_id.is_empty():
		return {}
	for mob in _tamed_mobs:
		if mob.get("id", "") == _active_mount_id:
			return mob.duplicate()
	return {}


func set_riding(riding: bool) -> void:
	if _is_riding == riding:
		return
	_is_riding = riding
	riding_changed.emit(riding)


func is_riding() -> bool:
	return _is_riding


func get_active_mount_sprite_id() -> String:
	var mount: Dictionary = get_active_mount()
	if mount.is_empty():
		return ""
	return str(mount.get("sprite_id", ""))


func get_mount_speed_mult() -> float:
	var mount: Dictionary = get_active_mount()
	if mount.is_empty():
		return 1.0
	var bonus: Dictionary = mount.get("mount_bonus", {})
	return float(bonus.get("movement_speed_mult", 1.0))


func advance_turn() -> void:
	for mob in _tamed_mobs:
		var cd: int = mob.get("cooldown_remaining", 0)
		if cd > 0:
			mob["cooldown_remaining"] = cd - 1


func can_tame(player_level: int = 1) -> bool:
	var max_tamed: int = TameCalc.get_max_tamed(player_level)
	return _tamed_mobs.size() < max_tamed


func get_snapshot() -> Dictionary:
	return {
		"tamed_mobs": _tamed_mobs.duplicate(true),
		"active_mount_id": _active_mount_id,
		"is_riding": _is_riding,
	}


func restore_from_snapshot(snap: Dictionary) -> void:
	_tamed_mobs = []
	_active_mount_id = ""
	_is_riding = false
	if snap.has("tamed_mobs") and snap["tamed_mobs"] is Array:
		_tamed_mobs = (snap["tamed_mobs"] as Array).duplicate(true)
	if snap.has("active_mount_id"):
		_active_mount_id = str(snap["active_mount_id"])
	if snap.has("is_riding"):
		_is_riding = bool(snap["is_riding"])


func _next_id() -> String:
	return "tamed_%d_%d" % [Time.get_unix_time_from_system(), randi()]
