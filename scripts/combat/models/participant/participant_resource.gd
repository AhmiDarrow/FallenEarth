class_name ParticipantResource
extends Resource
## Resource holding the turn-state machine for a combat participant
## (player or opponent).
##
## Adapted from ramaureirac/godot-tactical-rpg
## `TacticsParticipantResource` — same stage-based state machine,
## same "current pawn" tracking, simplified to 2D.
##
## The state machine is the *core* of the combat system. Every
## other service (movement, combat, AI) drives the transition by
## setting `stage` to the next value; the TurnService reads it
## and dispatches to the right handler.

## v0.11.0: Turn stages. The CombatLevel._process loop calls the
## TurnService.handle_participant() each frame, which dispatches
## to the right method based on this stage.
##
## SELECT_PAWN -> SHOW_ACTIONS -> SHOW_MOVEMENTS ->
##   SELECT_LOCATION -> MOVE_UNIT ->
##   DISPLAY_TARGETS -> SELECT_ATTACK_TARGET -> ATTACK ->
##   END_TURN
const STAGE_SELECT_PAWN: int = 0
const STAGE_SHOW_ACTIONS: int = 1
const STAGE_SHOW_MOVEMENTS: int = 2
const STAGE_SELECT_LOCATION: int = 3
const STAGE_MOVE_UNIT: int = 4
const STAGE_DISPLAY_TARGETS: int = 5
const STAGE_SELECT_ATTACK_TARGET: int = 6
const STAGE_ATTACK: int = 7
const STAGE_END_TURN: int = 8
const STAGE_DONE: int = 9

## v0.11.0: Current stage. Set by services; read by TurnService.
var stage: int = STAGE_SELECT_PAWN

## v0.11.0: "player" or "opponent" — which side is acting.
var side: String = "player"

## v0.11.0: The pawn currently selected to act. The TurnService
## picks the next pawn at STAGE_SELECT_PAWN; the other stages
## operate on this pawn.
var current_pawn: Object = null  ## A CombatUnit (Node)

## v0.11.0: Optional target pawn (set by SELECT_ATTACK_TARGET).
var target_pawn: Object = null

## v0.11.0: Pathfinding stack (tile positions) for the current
## pawn's move. Populated by the PathfindingService; consumed
## by the UnitMovementService.
var move_path: Array[Vector2i] = []

## v0.11.0: Flag to indicate the participant has finished its turn
## (set after STAGE_END_TURN completes).
var turn_completed: bool = false


## v0.11.0: Reset the participant for a new turn.
func reset_turn() -> void:
	stage = STAGE_SELECT_PAWN
	current_pawn = null
	target_pawn = null
	move_path = []
	turn_completed = false


## v0.11.0: Advance to the next stage. Helper used by all
## services instead of `stage = X` (centralizes the transition).
func advance_to(next_stage: int) -> void:
	stage = next_stage
