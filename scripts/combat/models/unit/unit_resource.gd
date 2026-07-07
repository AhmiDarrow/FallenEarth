class_name UnitResource
extends Resource
## Resource holding the state of one combat unit (a pawn).
##
## Pure data + signals. The CombatUnit (module) owns one of these
## and updates it; the services (movement, combat, AI) read and
## mutate it. The Resource can be saved/loaded as a .tres for
## class templates (e.g. recruit, archer, skeleton).
##
## Adapted from ramaureirac/godot-tactical-rpg `TacticsPawnResource`.

## v0.11.0: Identity & display
var unit_id: String = ""                       ## Unique ID for save/load + signaling
var display_name: String = ""                  ## Shown on the name plate / unit card
var team: String = "enemy"                     ## "player" | "ally" | "enemy"
var class_id: String = ""                      ## Class template (e.g. "recruit", "skeleton")
var race: String = "human"                     ## Race (human, mutant, chthon, etc.)
var gender: String = "male"                    ## male | female | none
var is_boss: bool = false

## v0.11.0: Position on the grid. (0,0) is top-left.
var grid_pos: Vector2i = Vector2i.ZERO

## v0.11.0: Stats — HP / MP / core attributes.
var max_hp: int = 1
var current_hp: int = 1
var max_mp: int = 0
var current_mp: int = 0
var level: int = 1                             ## Unit level (for damage/hit calc)
var attack: int = 0                            ## Physical attack power
var defense: int = 0                           ## Physical defense (armor)
var speed: int = 0                             ## Affects turn order (CT)
var move: int = 0                              ## Tiles per turn (movement)
var jump: int = 0                              ## Height the unit can climb
var attack_range: int = 1                      ## Tiles the unit can attack into
var sight: int = 5                             ## Vision range (future use)

## v0.11.0: Per-turn state. Resets at the start of each turn.
var has_moved: bool = false
var has_acted: bool = false
var move_path: Array[Vector2i] = []
var can_move: bool:
	get: return not has_moved and current_hp > 0
var can_act: bool:
	get: return not has_acted and current_hp > 0

## v0.11.0: Facing (used for back/side attack bonuses).
## 0=N, 1=E, 2=S, 3=W
var facing: int = 2

## v0.11.0: Sprite path (resolved by CombatUnit on setup).
var sprite_id: String = ""


## v0.11.0: Reset the per-turn state (called at the start of the
## unit's turn by the TurnService).
func reset_turn() -> void:
	has_moved = false
	has_acted = false
	move_path = []


## v0.11.0: Mark the unit as having used its move. Subsequent
## pathfinding calls treat it as stationary.
func end_move() -> void:
	has_moved = true


## v0.11.0: Mark the unit as having used its action (attack/skill).
func end_action() -> void:
	has_acted = true


## v0.11.0: Is this unit alive?
func is_alive() -> bool:
	return current_hp > 0


## v0.11.0: HP delta. Returns the new HP (clamped to [0, max_hp]).
func apply_damage(amount: int) -> int:
	current_hp = clampi(current_hp - amount, 0, max_hp)
	return current_hp


## v0.11.0: Heal. Returns the new HP.
func apply_heal(amount: int) -> int:
	current_hp = clampi(current_hp + amount, 0, max_hp)
	return current_hp


## v0.11.0: Spend MP. Returns true if the unit had enough.
func spend_mp(amount: int) -> bool:
	if current_mp < amount:
		return false
	current_mp -= amount
	return true
