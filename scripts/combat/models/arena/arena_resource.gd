class_name ArenaResource
extends Resource
## Resource holding the overall state of the combat arena (grid +
## participants + signals).
##
## The CombatArena (module) owns one of these and the grid's
## TileResource instances. Services read & mutate it.
##
## Adapted from ramaureirac/godot-tactical-rpg
## `TacticsArenaResource` — same signal-based "called_X" pattern.

## v0.11.0: Signals — the arena broadcasts actions to all
## listeners (UI overlays, AI brain, HUD) so they can react.
signal tile_highlights_changed      ## Emitted when reachable/attackable set changes
signal unit_moved(unit_id: String, from: Vector2i, to: Vector2i)
signal unit_attacked(attacker_id: String, target_id: String, damage: int)
signal turn_started(side: String)    ## side = "player" | "opponent"
signal turn_ended(side: String)
signal encounter_ended(victory: bool) ## true = player won, false = player lost

## v0.11.0: Grid config
const CELL_SIZE: int = 60
const DEFAULT_GRID_SIZE: int = 20
var grid_size: int = DEFAULT_GRID_SIZE
var biome: String = "Ash Wastes"

## v0.11.0: Flat list of all TileResource instances. Keyed by
## "x,y" for O(1) lookup. Populated by the TileService on
## arena configure; reset/cleared on arena teardown.
var tiles: Dictionary = {}

## v0.11.0: All units on the map, indexed by unit_id. The
## UnitService adds on spawn, removes on death/retreat.
var units: Dictionary = {}

## v0.11.0: Participant resources (one per side). The
## CombatPlayer owns the player one; CombatOpponent owns the
## opponent one. They drive the turn state machine.
var player_participant: ParticipantResource = null
var opponent_participant: ParticipantResource = null

## v0.11.0: Whose turn is it right now?
var current_side: String = "player"

## v0.11.0: Is the encounter in the "ended" state? When true, the
## CombatLevel stops dispatching stage transitions and shows the
## result panel.
var is_ended: bool = false
var victory: bool = false


## v0.11.0: Helper to get a tile by grid coordinates.
## Returns TileResource (2D) or CombatTile3D (3D).
func get_tile(x: int, y: int):
	return tiles.get("%d,%d" % [x, y], null)


## v0.11.0: Helper to get a unit by id.
func get_unit(unit_id: String) -> Object:
	return units.get(unit_id, null)


## v0.11.0: Helper to find which unit is standing on (x, y).
## Returns the unit's node (CombatUnit) or null.
func get_unit_at(x: int, y: int) -> Object:
	for unit_id in units:
		var u: Object = units[unit_id]
		if u == null or not is_instance_valid(u):
			continue
		var u_grid: Vector2i = Vector2i.ZERO
		if "res" in u and u.res != null and "grid_pos" in u.res:
			u_grid = u.res.grid_pos
		elif "grid_pos" in u:
			u_grid = u.grid_pos
		if u_grid == Vector2i(x, y):
			return u
	return null


## v0.11.0: All units on the player side, sorted by descending
## speed. The TurnService uses this to pick the next player pawn.
func get_player_units_by_speed() -> Array:
	var out: Array = []
	for unit_id in units:
		var u: Object = units[unit_id]
		if u != null and is_instance_valid(u):
			var res: UnitResource = u.res
			if res.team == "player" and res.is_alive():
				out.append(u)
	out.sort_custom(func(a, b): return a.res.speed > b.res.speed)
	return out


## v0.11.0: All units on the opponent side, sorted by speed.
func get_opponent_units_by_speed() -> Array:
	var out: Array = []
	for unit_id in units:
		var u: Object = units[unit_id]
		if u != null and is_instance_valid(u):
			var res: UnitResource = u.res
			if (res.team == "enemy" or res.team == "ally") and res.is_alive():
				out.append(u)
	out.sort_custom(func(a, b): return a.res.speed > b.res.speed)
	return out


## v0.11.0: Replace the unit registry entirely (used by the
## encounter builder on arena setup).
func set_units(new_units: Dictionary) -> void:
	units = new_units
