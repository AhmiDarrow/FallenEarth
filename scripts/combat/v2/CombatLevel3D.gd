class_name CombatLevel3D
extends Node3D
## 3D combat scene entry point. Owns the arena, participants,
## services, and dispatches the turn state machine every frame.
##
## Adapted from ramaureirac/godot-tactical-rpg `TacticsLevel`.

const TurnServiceScript = preload("res://scripts/combat/services/turn/turn_service.gd")
const PlayerServiceScript = preload("res://scripts/combat/services/player/player_service.gd")
const OpponentServiceScript = preload("res://scripts/combat/services/opponent/opponent_service.gd")
const PathfindingServiceScript = preload("res://scripts/combat/services/pathfinding/pathfinding_service.gd")
const ParticipantResourceScript = preload("res://scripts/combat/models/participant/participant_resource.gd")
const CombatArena3DScript = preload("res://scripts/combat/v2/CombatArena3D.gd")
const CombatPawn3DScript = preload("res://scripts/combat/v2/CombatPawn3D.gd")
const CombatTile3DScript = preload("res://scripts/combat/v2/CombatTile3D.gd")
const TacticsCamera3DScript = preload("res://scripts/combat/v2/TacticsCamera3D.gd")
const TacticsInput3DScript = preload("res://scripts/combat/v2/TacticsInput3D.gd")
const UnitMovementService3DScript = preload("res://scripts/combat/v2/UnitMovementService3D.gd")

## Scene references
@onready var _arena: CombatArena3D = $Arena
@onready var _camera: TacticsCamera3D = $TacticsCamera
@onready var _input: TacticsInput3D = $TacticsInput
@onready var _light: DirectionalLight3D = $DirectionalLight3D

## Service instances
var _turn_serv: TurnService
var _player_serv: PlayerService
var _opponent_serv: OpponentService
var _path_serv: PathfindingService
var _move_serv: UnitMovementService3D

## Participants
var _player: ParticipantResource
var _opponent: ParticipantResource

## Encounter data
var _encounter: Dictionary = {}

## UI references
@onready var _top_prompt: Control = get_node_or_null("HUDLayer/TopPrompt")
@onready var _action_bar: Control = get_node_or_null("HUDLayer/ActionBar")


func _ready() -> void:
	# Pull encounter from GameState if not set via set_encounter()
	if _encounter.is_empty():
		var gs: GameState = get_node_or_null("/root/GameState") as GameState
		if is_instance_valid(gs):
			_encounter = gs.get_pending_combat()
	if _encounter.is_empty():
		_encounter = _fallback_encounter()

	# Audio
	var mm: Node = get_node_or_null("/root/MusicManager")
	if mm != null and mm.has_method("play_track"):
		mm.call("play_track", "combat")
	var aa: Node = get_node_or_null("/root/AmbientAudio")
	if aa != null and aa.has_method("stop_all"):
		aa.call("stop_all", 0.4)

	# Build services
	_turn_serv = TurnServiceScript.new()
	_player_serv = PlayerServiceScript.new()
	_opponent_serv = OpponentServiceScript.new()
	_path_serv = PathfindingServiceScript.new()
	_move_serv = UnitMovementService3D.new()

	# Wire input
	_input.setup(_camera)
	_input.tile_clicked.connect(_on_tile_clicked)
	_input.pawn_clicked.connect(_on_pawn_clicked)

	# Build participants
	_player = ParticipantResource.new()
	_player.side = "player"
	_opponent = ParticipantResource.new()
	_opponent.side = "opponent"
	_arena.res.player_participant = _player
	_arena.res.opponent_participant = _opponent

	# Wire encounter ended
	_arena.res.encounter_ended.connect(_on_encounter_ended)
	# Wire attack damage to update HP visuals
	_arena.res.unit_attacked.connect(_on_unit_attacked)

	# Wire action bar buttons
	if _action_bar != null and _action_bar.has_method("show_move_button"):
		_action_bar.on_move = _on_action_move
		_action_bar.on_attack = _on_action_attack
		_action_bar.on_end_turn = _on_end_turn_pressed
		_action_bar.on_retreat = _on_retreat_pressed

	# Configure arena
	_configure_from_encounter()

	# Center camera on arena (offset toward back to keep pawns in frame)
	var grid_size: int = _arena.res.grid_size
	var arena_center: Vector3 = _arena.global_position + Vector3(grid_size * 0.5, 0.0, grid_size * 0.35)
	_camera.set_target(arena_center)
	_camera._snap_next_frame = true

	# Kick off first turn
	_start_turn("player")
	_update_top_prompt()


func _process(delta: float) -> void:
	if _arena.res.is_ended:
		return

	# Animate current pawn's movement
	var current_unit: CombatPawn3D = _get_active_unit()
	if current_unit != null and current_unit.is_moving:
		_move_serv.step(current_unit, delta)
		return

	# Tick the current participant's state machine
	var p: ParticipantResource = _player if _arena.res.current_side == "player" else _opponent
	var old_stage: int = p.stage
	var new_stage: int = _turn_serv.tick(p, self)
	if new_stage >= 0:
		p.advance_to(new_stage)

	if p.stage != old_stage:
		_update_top_prompt()

	if p.stage >= TurnServiceScript.STAGE_END_TURN or p.turn_completed:
		var next_side: String = "opponent" if _arena.res.current_side == "player" else "player"
		_arena.res.turn_ended.emit(_arena.res.current_side)
		_start_turn(next_side)
		_check_encounter_end()


# ─── Encounter Setup ───────────────────────────────────────

func _fallback_encounter() -> Dictionary:
	return {
		"biome_key": "Ash Wastes",
		"grid_size": 7,
		"height_seed": 0,
		"character_data": {
			"class": "recruit", "race": "human", "gender": "male",
			"hp": 100, "max_hp": 100, "move": 3, "speed": 10,
			"attack": 5, "defense": 0, "attack_range": 1, "facing": 2,
			"name": "Hero"
		},
		"player_start": Vector2i(3, 5),
		"enemy_templates": [],
	}


func _configure_from_encounter() -> void:
	var biome: String = str(_encounter.get("biome_key", _encounter.get("biome", "Ash Wastes")))
	var grid_size: int = int(_encounter.get("grid_size", 7))
	var height_seed: int = int(_encounter.get("height_seed", 0))
	_arena.configure(biome, grid_size, height_seed)

	# New format: units array
	if _encounter.has("units") and (_encounter["units"] as Array).size() > 0:
		for unit_data in _encounter["units"]:
			_arena.add_unit(unit_data)
		return

	# Legacy format
	var char_data: Dictionary = _encounter.get("character_data", {}) as Dictionary
	var player_start: Vector2i = _encounter.get("player_start", Vector2i(int(grid_size / 2.0), grid_size - 1))
	if not char_data.is_empty():
		var player_data: Dictionary = _character_to_unit(char_data, player_start)
		_arena.add_unit(player_data)

	var templates: Array = _encounter.get("enemy_templates", []) as Array
	var used: Array[Vector2i] = [player_start]
	for i in range(templates.size()):
		var t: Dictionary = templates[i]
		if not t is Dictionary:
			continue
		var pos: Vector2i = _random_open_tile(used, player_start, 2)
		if pos.x < 0:
			continue
		used.append(pos)
		var unit_data: Dictionary = _template_to_unit(t, pos, bool(t.get("is_boss", false)), i)
		_arena.add_unit(unit_data)


func _character_to_unit(char_data: Dictionary, pos: Vector2i) -> Dictionary:
	return {
		"id": "player",
		"name": str(char_data.get("name", char_data.get("display_name", "Hero"))),
		"team": "player",
		"class": str(char_data.get("class", char_data.get("class_id", "recruit"))),
		"race": str(char_data.get("race", "human")),
		"gender": str(char_data.get("gender", "male")),
		"is_boss": false,
		"level": int(char_data.get("level", 1)),
		"pos": pos,
		"hp": int(char_data.get("hp", char_data.get("current_hp", 100))),
		"max_hp": int(char_data.get("max_hp", 100)),
		"mp": int(char_data.get("mp", char_data.get("current_mp", 0))),
		"mp_max": int(char_data.get("mp_max", 0)),
		"attack": int(char_data.get("attack", 5)) + int(char_data.get("attack_bonus", 0)),
		"defense": int(char_data.get("defense", 0)) + int(char_data.get("armor_bonus", 0)),
		"speed": int(char_data.get("speed", 10)),
		"move": int(char_data.get("move", 3)),
		"jump": int(char_data.get("jump", 1)),
		"attack_range": int(char_data.get("attack_range", 1)),
		"sprite_id": str(char_data.get("sprite_id", "recruit")),
		"facing": int(char_data.get("facing", 2)),
	}


func _template_to_unit(t: Dictionary, pos: Vector2i, is_boss: bool, idx: int) -> Dictionary:
	return {
		"id": "enemy_%d" % idx,
		"name": str(t.get("name", t.get("display_name", "Enemy"))),
		"team": "enemy",
		"class": str(t.get("class", t.get("class_id", ""))),
		"race": str(t.get("race", "human")),
		"gender": str(t.get("gender", "none")),
		"is_boss": is_boss,
		"level": int(t.get("level", 1)),
		"pos": pos,
		"hp": int(t.get("hp", t.get("current_hp", 30))),
		"max_hp": int(t.get("max_hp", 30)),
		"mp": int(t.get("mp", 0)),
		"mp_max": int(t.get("mp_max", 0)),
		"attack": int(t.get("attack", 5)) + int(t.get("attack_bonus", 0)),
		"defense": int(t.get("defense", 0)) + int(t.get("armor_bonus", 0)),
		"speed": int(t.get("speed", 8)),
		"move": int(t.get("move", 2)),
		"jump": int(t.get("jump", 1)),
		"attack_range": int(t.get("attack_range", 1)),
		"sprite_id": str(t.get("sprite_id", t.get("id", "blight_toad"))),
		"facing": int(t.get("facing", 0)),
	}


func _random_open_tile(used: Array[Vector2i], origin: Vector2i, min_dist: int) -> Vector2i:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("v2_random_open_tile") ^ used.size()
	for attempt in range(100):
		var x: int = rng.randi_range(0, _arena.res.grid_size - 1)
		var y: int = rng.randi_range(0, _arena.res.grid_size - 1)
		var pos: Vector2i = Vector2i(x, y)
		if pos in used:
			continue
		if abs(pos.x - origin.x) + abs(pos.y - origin.y) < min_dist:
			continue
		var tile: CombatTile3D = _arena.get_tile(x, y)
		if tile == null or tile.blocked:
			continue
		return pos
	return Vector2i(-1, -1)


# ─── Turn Management ───────────────────────────────────────

func _start_turn(side: String) -> void:
	if _arena.res.is_ended:
		return
	_arena.res.current_side = side
	var p: ParticipantResource = _player if side == "player" else _opponent
	p.reset_turn()
	# Reset per-turn flags on all units so select_pawn can find them
	for uid in _arena.res.units:
		var u: UnitResource = _arena.res.units[uid].res
		if u != null:
			u.reset_turn()
	_arena.res.turn_started.emit(side)
	_arena.reset_all_tile_markers()
	# Center camera on grid, offset slightly toward back to keep pawns in frame
	var grid_size: int = _arena.res.grid_size
	var arena_center: Vector3 = _arena.global_position + Vector3(grid_size * 0.5, 0.0, grid_size * 0.35)
	_camera.set_target(arena_center)


func _get_active_unit() -> CombatPawn3D:
	if _arena == null or _arena.res == null:
		return null
	var p: ParticipantResource = _player if _arena.res.current_side == "player" else _opponent
	if p == null or p.current_pawn == null:
		return null
	if not is_instance_valid(p.current_pawn):
		return null
	return p.current_pawn as CombatPawn3D


# ─── Stage Handlers (called by TurnService) ────────────────

func on_select_pawn(participant: ParticipantResource) -> int:
	var arena: ArenaResource = _arena.res
	var pawn: Object
	if participant.side == "player":
		pawn = _player_serv.select_pawn(arena)
	else:
		pawn = _opponent_serv.select_pawn(arena)
	if pawn == null:
		participant.turn_completed = true
		return TurnServiceScript.STAGE_END_TURN
	participant.current_pawn = pawn
	participant.advance_to(TurnServiceScript.STAGE_SHOW_ACTIONS)
	return TurnServiceScript.STAGE_SHOW_ACTIONS


func on_show_actions(participant: ParticipantResource) -> int:
	if participant.side == "player":
		# Stay at SHOW_ACTIONS — wait for player to click Move or Attack
		return TurnServiceScript.STAGE_SHOW_ACTIONS
	# Opponent (AI) auto-advances to movements
	return TurnServiceScript.STAGE_SHOW_MOVEMENTS


func on_show_movements(participant: ParticipantResource) -> int:
	var pawn: CombatPawn3D = participant.current_pawn as CombatPawn3D
	if pawn == null or pawn.res == null:
		participant.advance_to(TurnServiceScript.STAGE_END_TURN)
		return TurnServiceScript.STAGE_END_TURN
	var arena: ArenaResource = _arena.res
	var enemies: Array = []
	if participant.side == "player":
		for uid in arena.units:
			var u: Object = arena.units[uid]
			if u != null and is_instance_valid(u) and (u.res.team == "enemy" or u.res.team == "ally"):
				enemies.append(u)
	else:
		for uid in arena.units:
			var u: Object = arena.units[uid]
			if u != null and is_instance_valid(u) and u.res.team == "player":
				enemies.append(u)
	# Process surrounding tiles using arena
	var root_tile: CombatTile3D = pawn.get_tile()
	if root_tile == null:
		# Can't find tile — skip movement, go to attack phase
		participant.advance_to(TurnServiceScript.STAGE_DISPLAY_TARGETS)
		return TurnServiceScript.STAGE_DISPLAY_TARGETS
	_arena.process_surrounding_tiles(root_tile, pawn.res.move, enemies)
	_arena.mark_reachable_tiles(root_tile, pawn.res.move)
	return TurnServiceScript.STAGE_SELECT_LOCATION


func on_select_location(participant: ParticipantResource) -> int:
	if participant.side == "opponent":
		var pawn: CombatPawn3D = participant.current_pawn as CombatPawn3D
		var target_pos: Vector2i = _opponent_serv.pick_move_target(_arena.res, pawn)
		if target_pos.x < 0:
			participant.advance_to(TurnServiceScript.STAGE_DISPLAY_TARGETS)
			return TurnServiceScript.STAGE_DISPLAY_TARGETS
		var tile: CombatTile3D = _arena.get_tile(target_pos.x, target_pos.y)
		if tile == null:
			participant.advance_to(TurnServiceScript.STAGE_DISPLAY_TARGETS)
			return TurnServiceScript.STAGE_DISPLAY_TARGETS
		# Build path from tilestack
		var path: Array = _arena.get_pathfinding_tilestack(tile)
		_move_serv.start_move(pawn, path)
		participant.advance_to(TurnServiceScript.STAGE_MOVE_UNIT)
		return TurnServiceScript.STAGE_MOVE_UNIT
	return TurnServiceScript.STAGE_SELECT_LOCATION


func on_move_unit(participant: ParticipantResource) -> int:
	var pawn: CombatPawn3D = participant.current_pawn as CombatPawn3D
	if pawn == null or pawn.is_moving:
		return TurnServiceScript.STAGE_MOVE_UNIT
	# Move complete — clear highlights and update grid_pos
	_arena.reset_all_tile_markers()
	if pawn.res and pawn.arena_node:
		var old_pos: Vector2i = pawn.res.grid_pos
		var tile: CombatTile3D = _arena.get_tile(old_pos.x, old_pos.y)
		if tile:
			tile.occupier = null
		# Update to new position from tile raycast
		var current_tile: CombatTile3D = pawn.get_tile()
		if current_tile:
			pawn.res.grid_pos = Vector2i(current_tile.grid_x, current_tile.grid_y)
			current_tile.occupier = pawn
	participant.advance_to(TurnServiceScript.STAGE_DISPLAY_TARGETS)
	return TurnServiceScript.STAGE_DISPLAY_TARGETS


func on_display_targets(participant: ParticipantResource) -> int:
	var pawn: CombatPawn3D = participant.current_pawn as CombatPawn3D
	if pawn == null or pawn.res == null:
		participant.advance_to(TurnServiceScript.STAGE_END_TURN)
		return TurnServiceScript.STAGE_END_TURN
	var root_tile: CombatTile3D = pawn.get_tile()
	if root_tile == null:
		participant.advance_to(TurnServiceScript.STAGE_END_TURN)
		return TurnServiceScript.STAGE_END_TURN
	# Process surrounding for attack range
	_arena.process_surrounding_tiles(root_tile, pawn.res.attack_range)
	_arena.mark_attackable_tiles(root_tile, pawn.res.attack_range)
	participant.advance_to(TurnServiceScript.STAGE_SELECT_ATTACK_TARGET)
	return TurnServiceScript.STAGE_SELECT_ATTACK_TARGET


func on_select_attack_target(participant: ParticipantResource) -> int:
	if participant.side == "opponent":
		var pawn: CombatPawn3D = participant.current_pawn as CombatPawn3D
		var arena: ArenaResource = _arena.res
		var target: CombatPawn3D = null
		var best_dist: int = 999999
		for dx in range(-pawn.res.attack_range, pawn.res.attack_range + 1):
			for dy in range(-pawn.res.attack_range, pawn.res.attack_range + 1):
				if dx == 0 and dy == 0:
					continue
				var u: Object = arena.get_unit_at(pawn.res.grid_pos.x + dx, pawn.res.grid_pos.y + dy)
				if u == null or not is_instance_valid(u):
					continue
				var u_res: UnitResource = u.res
				if not u_res.is_alive():
					continue
				var enemy_team: bool = (participant.side == "player" and (u_res.team == "enemy" or u_res.team == "ally")) or (participant.side == "opponent" and u_res.team == "player")
				if not enemy_team:
					continue
				var d: int = abs(dx) + abs(dy)
				if d < best_dist:
					best_dist = d
					target = u
		participant.target_pawn = target
		if target != null:
			participant.advance_to(TurnServiceScript.STAGE_ATTACK)
			return TurnServiceScript.STAGE_ATTACK
		else:
			participant.advance_to(TurnServiceScript.STAGE_END_TURN)
			return TurnServiceScript.STAGE_END_TURN
	return TurnServiceScript.STAGE_SELECT_ATTACK_TARGET


func on_attack(participant: ParticipantResource) -> int:
	var attacker: CombatPawn3D = participant.current_pawn as CombatPawn3D
	var target: CombatPawn3D = participant.target_pawn as CombatPawn3D
	if attacker == null or target == null:
		participant.advance_to(TurnServiceScript.STAGE_END_TURN)
		return TurnServiceScript.STAGE_END_TURN
	# Resolve attack using existing combat service
	var combat_serv := UnitCombatService.new()
	combat_serv.resolve_attack(attacker, target, _arena.res)
	# Clear highlights
	_arena.reset_all_tile_markers()
	participant.advance_to(TurnServiceScript.STAGE_END_TURN)
	return TurnServiceScript.STAGE_END_TURN


func on_end_turn(participant: ParticipantResource) -> int:
	var pawn: CombatPawn3D = participant.current_pawn as CombatPawn3D
	if pawn != null and pawn.res != null:
		pawn.res.end_action()
	participant.turn_completed = true
	return TurnServiceScript.STAGE_DONE


# ─── Input Handlers ────────────────────────────────────────

func _on_tile_clicked(tile: CombatTile3D) -> void:
	var p: ParticipantResource = _player if _arena.res.current_side == "player" else _opponent
	if p == null or p.current_pawn == null:
		return
	match p.stage:
		TurnServiceScript.STAGE_SELECT_LOCATION:
			if not tile.reachable:
				return
			var path: Array = _arena.get_pathfinding_tilestack(tile)
			if path.is_empty():
				return
			var pawn: CombatPawn3D = p.current_pawn as CombatPawn3D
			_move_serv.start_move(pawn, path)
			p.advance_to(TurnServiceScript.STAGE_MOVE_UNIT)
		TurnServiceScript.STAGE_SELECT_ATTACK_TARGET:
			if not tile.attackable:
				return
			var target: Object = _arena.res.get_unit_at(tile.grid_x, tile.grid_y)
			if target == null:
				return
			p.target_pawn = target
			p.advance_to(TurnServiceScript.STAGE_ATTACK)


func _on_pawn_clicked(pawn: CombatPawn3D) -> void:
	# If it's an enemy and we're in attack target stage, select it
	var p: ParticipantResource = _player if _arena.res.current_side == "player" else _opponent
	if p == null:
		return
	if p.stage == TurnServiceScript.STAGE_SELECT_ATTACK_TARGET:
		if pawn.res and (pawn.res.team == "enemy" or pawn.res.team == "ally"):
			p.target_pawn = pawn
			p.advance_to(TurnServiceScript.STAGE_ATTACK)


# ─── Encounter End ─────────────────────────────────────────

func _check_encounter_end() -> void:
	var any_player_alive: bool = false
	var any_enemy_alive: bool = false
	for uid in _arena.res.units:
		var u: Object = _arena.res.units[uid]
		if u == null or not is_instance_valid(u):
			continue
		var u_res: UnitResource = u.res
		if not u_res.is_alive():
			continue
		if u_res.team == "player":
			any_player_alive = true
		elif u_res.team == "enemy" or u_res.team == "ally":
			any_enemy_alive = true
	if not any_player_alive or not any_enemy_alive:
		_arena.res.is_ended = true
		_arena.res.victory = any_enemy_alive == false
		_arena.res.encounter_ended.emit(_arena.res.victory)


func _on_unit_attacked(attacker_id: String, target_id: String, damage: int) -> void:
	var target_pawn: CombatPawn3D = _arena.get_pawn(target_id)
	if target_pawn != null:
		target_pawn.update_hp(target_pawn.res.current_hp)


func _on_encounter_ended(victory: bool) -> void:
	_sync_player_health()
	_return_from_battle(victory)


func _sync_player_health() -> void:
	if _arena == null:
		return
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs):
		return
	for uid in _arena.res.units:
		var u: Object = _arena.res.units[uid]
		if u != null and is_instance_valid(u) and u.res.team == "player":
			gs.set_character_health(int(u.res.current_hp))
			break


func _return_from_battle(victory: bool) -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs):
		return
	var ctx: Dictionary = _encounter.get("return_context", {}) as Dictionary
	if victory:
		var mm: MissionManager = get_node_or_null("/root/MissionManager") as MissionManager
		if is_instance_valid(mm) and mm.has_method("report_combat_victory"):
			mm.report_combat_victory(_encounter)
	if victory and bool(ctx.get("remove_mob_on_victory", false)):
		gs.remove_overworld_mob(str(ctx.get("tile_key", "")))
	gs.clear_pending_combat()
	var return_scene: String = str(_encounter.get("return_scene", "res://scenes/HubWorld.tscn"))
	var gm: GameManager = get_node_or_null("/root/GameManager") as GameManager
	if is_instance_valid(gm):
		if return_scene.ends_with("HubWorld.tscn"):
			gm.go_to_hub(gs.get_character_data())
		elif return_scene.ends_with("RiftInstance.tscn"):
			gm.go_to_rift(
				str(ctx.get("rift_id", "rift_001")),
				str(ctx.get("biome_key", "Ash Wastes")),
				{}
			)
		else:
			get_tree().change_scene_to_file(return_scene)
	else:
		get_tree().change_scene_to_file(return_scene)


# ─── HUD ───────────────────────────────────────────────────

func _update_top_prompt() -> void:
	if _top_prompt == null or not _top_prompt.has_method("show_prompt"):
		return
	# Update action bar button visibility
	var is_player_turn: bool = _arena.res.current_side == "player" and not _arena.res.is_ended
	if _action_bar != null and _action_bar.has_method("show_move_button"):
		_action_bar.show_move_button(is_player_turn)
		_action_bar.show_attack_button(is_player_turn)
		_action_bar.show_end_turn(is_player_turn)
		_action_bar.show_retreat(is_player_turn)

	if _arena.res.is_ended:
		_top_prompt.show_prompt("Battle ended", "")
		if _action_bar != null and _action_bar.has_method("show_move_button"):
			_action_bar.show_move_button(false)
			_action_bar.show_attack_button(false)
			_action_bar.show_end_turn(false)
			_action_bar.show_retreat(false)
		return
	if _arena.res.current_side == "opponent":
		_top_prompt.show_prompt("Enemy acting...", "Wait for your turn")
		if _action_bar != null and _action_bar.has_method("show_move_button"):
			_action_bar.show_move_button(false)
			_action_bar.show_attack_button(false)
			_action_bar.show_end_turn(false)
			_action_bar.show_retreat(false)
		return
	match _player.stage:
		ParticipantResourceScript.STAGE_SHOW_MOVEMENTS:
			_top_prompt.show_prompt("Select a tile to move", "Click a highlighted tile")
			if _action_bar != null and _action_bar.has_method("show_move_button"):
				_action_bar.show_move_button(false)
				_action_bar.show_attack_button(false)
		ParticipantResourceScript.STAGE_SELECT_ATTACK_TARGET:
			_top_prompt.show_prompt("Select a target", "Click a highlighted enemy")
			if _action_bar != null and _action_bar.has_method("show_move_button"):
				_action_bar.show_move_button(false)
				_action_bar.show_attack_button(false)
		ParticipantResourceScript.STAGE_SHOW_ACTIONS:
			_top_prompt.show_prompt("Choose an action", "Move or Attack")
			if _action_bar != null and _action_bar.has_method("show_move_button"):
				_action_bar.show_move_button(true)
				_action_bar.show_attack_button(true)
		_:
			_top_prompt.show_prompt("Your turn", "Choose an action")
			if _action_bar != null and _action_bar.has_method("show_move_button"):
				_action_bar.show_move_button(true)
				_action_bar.show_attack_button(true)


func set_encounter(encounter: Dictionary) -> void:
	_encounter = encounter


# ─── End Turn / Retreat ────────────────────────────────────

func _on_end_turn_pressed() -> void:
	if _arena.res.is_ended:
		return
	if _arena.res.current_side != "player":
		return
	_arena.reset_all_tile_markers()
	_player.advance_to(ParticipantResourceScript.STAGE_END_TURN)


func _on_action_move() -> void:
	if _arena.res.is_ended:
		return
	if _arena.res.current_side != "player":
		return
	var p: ParticipantResource = _player
	if p.current_pawn == null:
		return
	# Trigger movement stage
	p.advance_to(TurnServiceScript.STAGE_SHOW_MOVEMENTS)
	_update_top_prompt()


func _on_action_attack() -> void:
	if _arena.res.is_ended:
		return
	if _arena.res.current_side != "player":
		return
	var p: ParticipantResource = _player
	if p.current_pawn == null:
		return
	# Skip to attack target selection
	p.advance_to(TurnServiceScript.STAGE_DISPLAY_TARGETS)
	_update_top_prompt()


func _on_retreat_pressed() -> void:
	if _arena.res.is_ended:
		return
	_arena.res.is_ended = true
	_arena.res.victory = false
	_arena.res.encounter_ended.emit(false)
	_return_from_battle(false)
