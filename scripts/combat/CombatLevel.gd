class_name CombatLevel
extends Control
## The combat scene entry point. Owns the arena + participants +
## services, and dispatches the turn state machine every frame.
##
## Adapted from ramaureirac/godot-tactical-rpg `TacticsLevel` —
## the same "tick each frame, dispatch by stage" pattern. In
## 2D we use a single Control node (not Node3D) since there's
## no camera panning; the "camera" is just a fixed viewport
## center.
##
## Scene tree (built in _ready or via .tscn):
##   CombatLevel (Control)
##   ├── ArenaLayer (CanvasLayer)
##   │   └── CombatArena (Node2D)
##   ├── HUDLayer (CanvasLayer)
##   │   ├── TurnOrderBar (Control)
##   │   ├── UnitInfoCard (Control)
##   │   ├── SkillBar (Control)
##   │   ├── ActionBar (Control)  <- End Turn + Retreat
##   │   ├── TopPrompt (Control)
##   │   └── TargetingReticle (Control)
##   └── BattleBackgroundLayer (CanvasLayer)
##       └── BattleBackground (Node2D)

const CombatArenaScript = preload("res://scripts/combat/CombatArena.gd")
const TurnServiceScript = preload("res://scripts/combat/services/turn/turn_service.gd")
const PlayerServiceScript = preload("res://scripts/combat/services/player/player_service.gd")
const OpponentServiceScript = preload("res://scripts/combat/services/opponent/opponent_service.gd")
const PathfindingServiceScript = preload("res://scripts/combat/services/pathfinding/pathfinding_service.gd")
const UnitMovementServiceScript = preload("res://scripts/combat/services/unit/unit_movement_service.gd")
const UnitCombatServiceScript = preload("res://scripts/combat/services/unit/unit_combat_service.gd")
const ParticipantResourceScript = preload("res://scripts/combat/models/participant/participant_resource.gd")

## v0.11.0: Scene references
@onready var _arena: CombatArena = $ArenaLayer/CombatArena

## v0.11.0: Service singletons
var _turn_serv: TurnService
var _player_serv: PlayerService
var _opponent_serv: OpponentService
var _path_serv: PathfindingService
var _move_serv: UnitMovementService
var _combat_serv: UnitCombatService

## v0.11.0: Participant resources (drive the state machine)
var _player: ParticipantResource
var _opponent: ParticipantResource

## v0.11.0: Encounter data (passed in by the caller)
var _encounter: Dictionary = {}

## v0.11.0: UI references
@onready var _turn_order_bar: Control = get_node_or_null("HUDLayer/TurnOrderBar")
@onready var _unit_info_card: Control = get_node_or_null("HUDLayer/UnitInfoCard")
@onready var _skill_bar: Control = get_node_or_null("HUDLayer/SkillBar")
@onready var _action_bar: Control = get_node_or_null("HUDLayer/ActionBar")
@onready var _top_prompt: Control = get_node_or_null("HUDLayer/TopPrompt")
@onready var _background: Node2D = get_node_or_null("BattleBackgroundLayer/BattleBackground")


func _ready() -> void:
	# v0.11.0: Build the services.
	_turn_serv = TurnServiceScript.new()
	_player_serv = PlayerServiceScript.new()
	_opponent_serv = OpponentServiceScript.new()
	_path_serv = PathfindingServiceScript.new()
	_move_serv = UnitMovementServiceScript.new()
	_combat_serv = UnitCombatServiceScript.new()

	# v0.11.0: Build the participants.
	_player = ParticipantResource.new()
	_player.side = "player"
	_opponent = ParticipantResource.new()
	_opponent.side = "opponent"
	_arena.res.player_participant = _player
	_arena.res.opponent_participant = _opponent

	# v0.11.0: Configure the arena with biome + grid size from
	# the encounter, then place all units.
	_configure_from_encounter()

	# v0.11.0: Wire the arena's tile clicks back to the input
	# handler.
	if _arena != null:
		for key in _arena._tiles:
			var tile: CombatTile = _arena._tiles[key]
			tile.clicked.connect(_on_tile_clicked)

	# v0.11.0: Wire the action bar (if present).
	if _action_bar != null and _action_bar.has_method("on_end_turn"):
		_action_bar.on_end_turn = _on_end_turn_pressed
		_action_bar.on_retreat = _on_retreat_pressed
	# v0.11.0: Kick off the first turn.
	_start_turn("player")
	# v0.11.0: Show the initial prompt.
	_update_top_prompt()


func _configure_from_encounter() -> void:
	var biome: String = str(_encounter.get("biome_key", _encounter.get("biome", "Ash Wastes")))
	var grid_size: int = int(_encounter.get("grid_size", 7))
	var height_seed: int = int(_encounter.get("height_seed", 0))
	_arena.configure(biome, grid_size, height_seed)
	# Try the new format first.
	if _encounter.has("units") and (_encounter["units"] as Array).size() > 0:
		for unit_data in _encounter["units"]:
			_arena.add_unit(unit_data)
		return
	# Fall back to the legacy format.
	var char_data: Dictionary = _encounter.get("character_data", {}) as Dictionary
	var player_start: Vector2i = _encounter.get("player_start", Vector2i(grid_size / 2, grid_size - 1))
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


## v0.11.0: Convert a character_data dict to a unit dict.
func _character_to_unit(char_data: Dictionary, pos: Vector2i) -> Dictionary:
	return {
		"id": "player",
		"name": str(char_data.get("name", char_data.get("display_name", "Hero"))),
		"team": "player",
		"class": str(char_data.get("class", char_data.get("class_id", "recruit"))),
		"race": str(char_data.get("race", "human")),
		"gender": str(char_data.get("gender", "male")),
		"is_boss": false,
		"pos": pos,
		"hp": int(char_data.get("hp", char_data.get("current_hp", 100))),
		"max_hp": int(char_data.get("max_hp", 100)),
		"mp": int(char_data.get("mp", char_data.get("current_mp", 0))),
		"mp_max": int(char_data.get("mp_max", 0)),
		"attack": int(char_data.get("attack", 5)) + int(char_data.get("attack_bonus", 0)),
		"defense": int(char_data.get("defense", 0)) + int(char_data.get("armor_bonus", 0)),
		"speed": int(char_data.get("speed", 10)),
		"move": int(char_data.get("move", 6)),
		"jump": int(char_data.get("jump", 1)),
		"attack_range": int(char_data.get("attack_range", 1)),
		"sprite_id": str(char_data.get("sprite_id", "recruit")),
		"facing": int(char_data.get("facing", 2)),
	}


## v0.11.0: Convert an enemy template dict to a unit dict.
func _template_to_unit(t: Dictionary, pos: Vector2i, is_boss: bool, idx: int) -> Dictionary:
	return {
		"id": "enemy_%d" % idx,
		"name": str(t.get("name", t.get("display_name", "Enemy"))),
		"team": "enemy",
		"class": str(t.get("class", t.get("class_id", ""))),
		"race": str(t.get("race", "human")),
		"gender": str(t.get("gender", "none")),
		"is_boss": is_boss,
		"pos": pos,
		"hp": int(t.get("hp", t.get("current_hp", 30))),
		"max_hp": int(t.get("max_hp", 30)),
		"mp": int(t.get("mp", 0)),
		"mp_max": int(t.get("mp_max", 0)),
		"attack": int(t.get("attack", 5)) + int(t.get("attack_bonus", 0)),
		"defense": int(t.get("defense", 0)) + int(t.get("armor_bonus", 0)),
		"speed": int(t.get("speed", 8)),
		"move": int(t.get("move", 4)),
		"jump": int(t.get("jump", 1)),
		"attack_range": int(t.get("attack_range", 1)),
		"sprite_id": str(t.get("sprite_id", t.get("id", "blight_toad"))),
		"facing": int(t.get("facing", 0)),
	}


## v0.11.0: Find a random open tile at least `min_dist` away
## from `origin` (typically the player's spawn). Used by the
## legacy encounter format to scatter enemies across the map.
func _random_open_tile(used: Array[Vector2i], origin: Vector2i, min_dist: int) -> Vector2i:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("v0.11.0_random_open_tile") ^ used.size()
	for attempt in range(100):
		var x: int = rng.randi_range(0, _arena.res.grid_size - 1)
		var y: int = rng.randi_range(0, _arena.res.grid_size - 1)
		var pos: Vector2i = Vector2i(x, y)
		if pos in used:
			continue
		if abs(pos.x - origin.x) + abs(pos.y - origin.y) < min_dist:
			continue
		var tile: TileResource = _arena.res.get_tile(x, y)
		if tile == null or tile.blocked:
			continue
		return pos
	return Vector2i(-1, -1)


## v0.11.0: Advance the arena's `current_side` to the next side
## whose participants can act. If neither can, end the encounter.
func _start_turn(side: String) -> void:
	if _arena.res.is_ended:
		return
	_arena.res.current_side = side
	var p: ParticipantResource = _player if side == "player" else _opponent
	p.reset_turn()
	_arena.res.turn_started.emit(side)
	# Reset all tile highlights.
	for key in _arena._tiles:
		_arena._tiles[key].res.reachable = false
		_arena._tiles[key].res.attackable = false
		_arena._tiles[key].res.hover = false


## v0.11.0: Main update loop. Tick the current participant's
## state machine, then advance to the next side if done.
func _process(delta: float) -> void:
	if _arena.res.is_ended:
		return
	# Animate the current pawn's movement along its path.
	var current_unit: CombatUnit = _get_active_unit()
	if current_unit != null and current_unit.is_moving:
		_move_serv.step(current_unit, delta)
		return
	# Tick the current participant's state machine.
	var p: ParticipantResource = _player if _arena.res.current_side == "player" else _opponent
	var new_stage: int = _turn_serv.tick(p, self)
	if new_stage >= 0:
		p.advance_to(new_stage)
	if p.stage >= TurnServiceScript.STAGE_END_TURN or p.turn_completed:
		# Switch sides.
		var next_side: String = "opponent" if _arena.res.current_side == "player" else "player"
		_arena.res.turn_ended.emit(_arena.res.current_side)
		_start_turn(next_side)
		# Check for encounter end (all enemies dead = victory).
		_check_encounter_end()


## v0.11.0: Get the current participant's active unit.
func _get_active_unit() -> CombatUnit:
	if _arena == null or _arena.res == null:
		return null
	var p: ParticipantResource = _player if _arena.res.current_side == "player" else _opponent
	if p == null or p.current_pawn == null:
		return null
	if not is_instance_valid(p.current_pawn):
		return null
	return p.current_pawn as CombatUnit


#region --- Stage handlers (called by TurnService) ---
# v0.11.0: Each handler corresponds to one ParticipantResource
# stage. They return the next stage to advance to, or the same
# stage to "stay here" (e.g. waiting for player input). Stage
# numbers match TurnService.STAGE_* constants.

func on_select_pawn(participant: ParticipantResource) -> int:
	# v0.11.0: Pick the next pawn that can act.
	var arena: ArenaResource = _arena.res
	var pawn: Object
	if participant.side == "player":
		pawn = _player_serv.select_pawn(arena)
	else:
		pawn = _opponent_serv.select_pawn(arena)
	if pawn == null:
		# No one can act on this side; end the turn.
		participant.turn_completed = true
		return TurnServiceScript.STAGE_END_TURN
	participant.current_pawn = pawn
	participant.advance_to(TurnServiceScript.STAGE_SHOW_ACTIONS)
	return TurnServiceScript.STAGE_SHOW_ACTIONS


func on_show_actions(participant: ParticipantResource) -> int:
	# v0.11.0: The unit is selected. For now, we always go to
	# SHOW_MOVEMENTS (the player can always move first). The
	# attack-first / skill-first path can be added by checking
	# the unit's abilities.
	return TurnServiceScript.STAGE_SHOW_MOVEMENTS


func on_show_movements(participant: ParticipantResource) -> int:
	# v0.11.0: Mark the reachable tiles for the current pawn.
	var pawn: CombatUnit = participant.current_pawn as CombatUnit
	if pawn == null or pawn.res == null:
		return TurnServiceScript.STAGE_END_TURN
	var arena: ArenaResource = _arena.res
	var enemies: Array = []
	if participant.side == "player":
		# For player: enemies are opponent units.
		for uid in arena.units:
			var u: Object = arena.units[uid]
			if u != null and is_instance_valid(u) and (u.res.team == "enemy" or u.res.team == "ally"):
				enemies.append(u)
	else:
		# For opponent: enemies are player units.
		for uid in arena.units:
			var u: Object = arena.units[uid]
			if u != null and is_instance_valid(u) and u.res.team == "player":
				enemies.append(u)
	_player_serv.mark_tiles(arena, pawn, enemies)
	return TurnServiceScript.STAGE_SELECT_LOCATION


func on_select_location(participant: ParticipantResource) -> int:
	# v0.11.0: Wait for the player to click a tile (handled in
	# _on_tile_clicked). For opponent, the AI picks immediately.
	if participant.side == "opponent":
		var pawn: CombatUnit = participant.current_pawn as CombatUnit
		var target_pos: Vector2i = _opponent_serv.pick_move_target(_arena.res, pawn)
		if target_pos.x < 0:
			# No reachable target — go straight to attack/finish.
			participant.advance_to(TurnServiceScript.STAGE_DISPLAY_TARGETS)
			return TurnServiceScript.STAGE_DISPLAY_TARGETS
		var path: Array[Vector2i] = _path_serv.get_path(_arena.res, target_pos.x, target_pos.y)
		_move_serv.start_move(pawn, path)
		participant.move_path = path
		participant.advance_to(TurnServiceScript.STAGE_MOVE_UNIT)
		return TurnServiceScript.STAGE_MOVE_UNIT
	# Player: stay here until _on_tile_clicked sets the path.
	return TurnServiceScript.STAGE_SELECT_LOCATION


func on_move_unit(participant: ParticipantResource) -> int:
	# v0.11.0: Wait for the move animation to finish.
	var pawn: CombatUnit = participant.current_pawn as CombatUnit
	if pawn == null or pawn.is_moving or not pawn.res.move_path.is_empty():
		# Still moving — stay on this stage.
		return TurnServiceScript.STAGE_MOVE_UNIT
	# Move complete — clear highlights and advance to attack.
	for key in _arena._tiles:
		var t: CombatTile = _arena._tiles[key]
		t.res.reachable = false
		t.res.attackable = false
		t.res.hover = false
	# Update tile occupancy from the move.
	var old_pos: Vector2i = pawn.res.grid_pos
	_arena.res.get_tile(old_pos.x, old_pos.y).occupier = null
	# (The UnitMovementService already updated the new tile's occupier in step().)
	participant.advance_to(TurnServiceScript.STAGE_DISPLAY_TARGETS)
	return TurnServiceScript.STAGE_DISPLAY_TARGETS


func on_display_targets(participant: ParticipantResource) -> int:
	# v0.11.0: Mark attack-range tiles (in red) around the
	# current pawn.
	var pawn: CombatUnit = participant.current_pawn as CombatUnit
	if pawn == null or pawn.res == null:
		participant.advance_to(TurnServiceScript.STAGE_END_TURN)
		return TurnServiceScript.STAGE_END_TURN
	# Compute attack range: the pawn's neighbors within attack_range.
	var ppos: Vector2i = pawn.res.grid_pos
	var arange: int = pawn.res.attack_range
	var arena: ArenaResource = _arena.res
	var enemy_teams: Array
	if participant.side == "player":
		enemy_teams = ["enemy", "ally"]
	else:
		enemy_teams = ["player"]
	for dx in range(-arange, arange + 1):
		for dy in range(-arange, arange + 1):
			if dx == 0 and dy == 0:
				continue
			var tx: int = ppos.x + dx
			var ty: int = ppos.y + dy
			if tx < 0 or ty < 0 or tx >= arena.grid_size or ty >= arena.grid_size:
				continue
			var tile: TileResource = arena.get_tile(tx, ty)
			if tile == null:
				continue
			tile.attackable = true
	participant.advance_to(TurnServiceScript.STAGE_SELECT_ATTACK_TARGET)
	return TurnServiceScript.STAGE_SELECT_ATTACK_TARGET


func on_select_attack_target(participant: ParticipantResource) -> int:
	# v0.11.0: Wait for the player to click an enemy on a
	# red-highlighted tile (handled in _on_tile_clicked). For
	# opponent, the AI picks immediately.
	if participant.side == "opponent":
		var pawn: CombatUnit = participant.current_pawn as CombatUnit
		var arena: ArenaResource = _arena.res
		# Find the closest enemy in attack range.
		var target: CombatUnit = null
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
			# No target — end turn.
			participant.advance_to(TurnServiceScript.STAGE_END_TURN)
			return TurnServiceScript.STAGE_END_TURN
	# Player: stay here until _on_tile_clicked picks a target.
	return TurnServiceScript.STAGE_SELECT_ATTACK_TARGET


func on_attack(participant: ParticipantResource) -> int:
	# v0.11.0: Resolve the attack via UnitCombatService.
	var attacker: CombatUnit = participant.current_pawn as CombatUnit
	var target: CombatUnit = participant.target_pawn as CombatUnit
	if attacker == null or target == null:
		participant.advance_to(TurnServiceScript.STAGE_END_TURN)
		return TurnServiceScript.STAGE_END_TURN
	_combat_serv.resolve_attack(attacker, target, _arena.res)
	# Clear highlights.
	for key in _arena._tiles:
		var t: CombatTile = _arena._tiles[key]
		t.res.attackable = false
		t.res.hover = false
	# Update HUD (HP bar).
	_refresh_hud()
	participant.advance_to(TurnServiceScript.STAGE_END_TURN)
	return TurnServiceScript.STAGE_END_TURN


func on_end_turn(participant: ParticipantResource) -> int:
	# v0.11.0: Mark the unit as having used its action.
	var pawn: CombatUnit = participant.current_pawn as CombatUnit
	if pawn != null and pawn.res != null:
		pawn.res.end_action()
	participant.turn_completed = true
	return TurnServiceScript.STAGE_DONE
#endregion --- Stage handlers ---


## v0.11.0: Handle a tile click. The action depends on the
## current participant's stage:
##   - SELECT_LOCATION: clicked tile must be reachable; start moving.
##   - SELECT_ATTACK_TARGET: clicked tile must contain an enemy; start attack.
func _on_tile_clicked(x: int, y: int) -> void:
	var p: ParticipantResource = _player if _arena.res.current_side == "player" else _opponent
	if p == null or p.current_pawn == null:
		return
	var tile: CombatTile = _arena.get_tile(x, y)
	if tile == null:
		return
	match p.stage:
		TurnServiceScript.STAGE_SELECT_LOCATION:
			if not tile.res.reachable:
				return
			var path: Array[Vector2i] = _path_serv.get_path(_arena.res, x, y)
			if path.is_empty():
				return
			var pawn: CombatUnit = p.current_pawn as CombatUnit
			_move_serv.start_move(pawn, path)
			p.move_path = path
			p.advance_to(TurnServiceScript.STAGE_MOVE_UNIT)
		TurnServiceScript.STAGE_SELECT_ATTACK_TARGET:
			if not tile.res.attackable:
				return
			var target: Object = _arena.res.get_unit_at(x, y)
			if target == null:
				return
			p.target_pawn = target
			p.advance_to(TurnServiceScript.STAGE_ATTACK)
		_:
			pass


## v0.11.0: End the encounter (called when all enemies are
## dead or all player units are dead).
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


## v0.11.0: Refresh the HUD elements (turn order, unit info,
## skill bar). Called after every action.
func _refresh_hud() -> void:
	if _turn_order_bar != null and _turn_order_bar.has_method("refresh"):
		_turn_order_bar.call("refresh", _arena.res)
	if _unit_info_card != null and _unit_info_card.has_method("refresh"):
		_unit_info_card.call("refresh", _arena.res)
	if _skill_bar != null and _skill_bar.has_method("refresh"):
		_skill_bar.call("refresh", _arena.res)
	_update_top_prompt()


## v0.11.0: Update the top prompt to reflect the current
## participant's stage. Mirrors the v0.10.1 _update_instructions()
## logic.
func _update_top_prompt() -> void:
	if _top_prompt == null or not _top_prompt.has_method("show_prompt"):
		return
	if _arena.res.is_ended:
		_top_prompt.show_prompt("Battle ended", "")
		return
	if _arena.res.current_side == "opponent":
		_top_prompt.show_prompt("Enemy acting…", "Wait for your turn", 0.0)
		return
	match _player.stage:
		ParticipantResourceScript.STAGE_SHOW_MOVEMENTS:
			_top_prompt.show_prompt("Select a white tile to move", "Then choose an action", 0.0)
		ParticipantResourceScript.STAGE_SELECT_ATTACK_TARGET:
			_top_prompt.show_prompt("Select a target", "Red tiles = attack range", 0.0)
		_:
			_top_prompt.show_prompt("Your turn", "Choose an action", 0.0)


## v0.11.0: Handler for the End Turn button. Force-completes
## the current player's turn.
func _on_end_turn_pressed() -> void:
	if _arena.res.is_ended:
		return
	if _arena.res.current_side != "player":
		return
	# Clear highlights + advance the participant to END_TURN.
	for key in _arena._tiles:
		var t: CombatTile = _arena._tiles[key]
		t.res.reachable = false
		t.res.attackable = false
		t.res.hover = false
	_player.advance_to(ParticipantResourceScript.STAGE_END_TURN)


## v0.11.0: Handler for the Retreat button. Ends the encounter
## as a loss and emits the encounter_ended signal.
func _on_retreat_pressed() -> void:
	if _arena.res.is_ended:
		return
	_arena.res.is_ended = true
	_arena.res.victory = false
	_arena.res.encounter_ended.emit(false)


## v0.11.0: Public API used by TacticalCombat.tscn to pass
## the encounter in before _ready.
func set_encounter(encounter: Dictionary) -> void:
	_encounter = encounter
