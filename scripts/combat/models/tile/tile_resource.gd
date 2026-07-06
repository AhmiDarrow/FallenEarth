class_name TileResource
extends Resource
## Resource holding the state of one tile in the combat grid.
##
## Pure data + signals. No scene tree, no visuals. The CombatTile
## (module) owns one of these and updates its fields when state
## changes; the visual reads `reachable` / `attackable` / `hover`
## each frame to decide what to draw.
##
## Adapted from ramaureirac/godot-tactical-rpg `TacticsTile` —
## we keep the same flag pattern but make state explicit (Resource)
## so the visual and the pathfinder can share it.

## v0.11.0: Visual state flags. The CombatTile reads these each
## frame in `_process` to decide which color/material to draw.
var reachable: bool = false
var attackable: bool = false
var hover: bool = false
var blocked: bool = false

## v0.11.0: Pathfinding metadata. The PathfindingService writes
## these during BFS; the TileService reads them to build the
## movement path for a unit.
var pf_root: Object = null   ## Object (TileResource/Node) of the tile we came from
var pf_distance: int = 0    ## BFS distance from the root tile

## v0.11.0: Terrain kind (0=ground, 1=vegetation, 2=debris, 3=blocked,
## 4=height). The CombatTile reads this to pick the terrain sprite.
var terrain_kind: int = 0

## v0.11.0: Grid coordinates. Set once when the tile is created.
var grid_x: int = 0
var grid_y: int = 0

## v0.11.0: Which unit (if any) is standing on this tile. Set by
## the UnitService when a unit moves; read by the TileService to
## test `is_taken()`. Stored as a node reference for flexibility
## (the unit script can be either CombatUnit or a custom pawn).
var occupier: Object = null


## v0.11.0: True if a unit is on this tile (occupying it). The
## pathfinder treats occupied tiles as impassable unless the
## occupier is an enemy (which can still be attacked).
func is_taken() -> bool:
	return occupier != null


## v0.11.0: Reset pathfinding + visual state. Called by the
## ArenaService between turns to clear stale highlights.
func reset_markers() -> void:
	reachable = false
	attackable = false
	hover = false
	pf_root = null
	pf_distance = 0
