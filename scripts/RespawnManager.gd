## RespawnManager — Handles player death penalty and respawn orchestration.
## Autoload singleton. Reads/writes respawn point via GameState.
##
## On death: deducts 10% XP and 10% EC (cannot go below 0),
## fully heals the player, then transitions to HubWorld at the
## saved respawn point.
extends Node

signal player_respawning(respawn_data: Dictionary)

const DEFAULT_SPAWN := {"type": "default", "local_x": 256, "local_y": 256}


func get_respawn_point() -> Dictionary:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs):
		return DEFAULT_SPAWN.duplicate()
	return gs.get_respawn_point()


func set_respawn_point(type: String, local_x: int, local_y: int) -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs):
		return
	gs.set_respawn_point(type, local_x, local_y)
	print("[RespawnManager] Respawn point set to %s at (%d, %d)" % [type, local_x, local_y])


func reset_to_default() -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs):
		return
	var pos: Vector2i = gs.get_local_position()
	gs.set_respawn_point("default", 256, 256)
	print("[RespawnManager] Respawn reset to default (256, 256)")


func on_player_death() -> void:
	print("[RespawnManager] Player death triggered")
	var prog: ProgressionManager = get_node_or_null("/root/ProgressionManager") as ProgressionManager
	if is_instance_valid(prog):
		var xp_lost: int = prog.remove_xp_pct(0.10)
		var ec_lost: int = prog.spend_ec_pct(0.10)
		print("[RespawnManager] Penalty: lost %d XP and %d EC" % [xp_lost, ec_lost])

	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if is_instance_valid(gs):
		var char_data: Dictionary = gs.get_character_data()
		var max_hp: int = int(char_data.get("max_health", char_data.get("health", 100)))
		gs.set_character_health(max_hp)
		# Move player to respawn point
		var rp: Dictionary = get_respawn_point()
		gs.set_local_position(rp.get("local_x", 256), rp.get("local_y", 256))

	var respawn_data: Dictionary = get_respawn_point()
	respawn_data["health_restored"] = true
	player_respawning.emit(respawn_data)

	var gm: GameManager = get_node_or_null("/root/GameManager") as GameManager
	if is_instance_valid(gm):
		gm.go_to_hub(gs.get_character_data() if is_instance_valid(gs) else {})
