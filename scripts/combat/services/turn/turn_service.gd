class_name TurnService
extends RefCounted
## Stage-based turn dispatcher for the combat system.
##
## Adapted from ramaureirac/godot-tactical-rpg
## `TacticsParticipantTurnService` — the same `match stage`
## dispatcher, with 2D-friendly methods.
##
## The CombatLevel calls `tick(delta, combat_level)` every frame.
## It looks at the current participant's stage and calls the
## right handler method. The handlers mutate state and bump the
## stage when done, which causes the next tick to call the next
## handler. This makes the turn flow explicit and easy to debug
## (you can log "stage advanced to SHOW_MOVEMENTS" and see
## exactly what happened).


## v0.11.0: The four cardinal stage handlers. Each is a method
## the dispatcher calls based on the current participant's stage.
## The exact implementation depends on the combat level / services,
## so we pass a CombatLevel reference and let it dispatch.

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


## v0.11.0: One frame of the participant state machine. Reads
## the participant's current stage and calls the matching method
## on the combat level. The combat level returns the new stage
## (or -1 to indicate the participant is done).
func tick(participant: ParticipantResource, combat_level) -> int:
	if participant == null or combat_level == null:
		return STAGE_DONE
	match participant.stage:
		STAGE_SELECT_PAWN:
			return combat_level.on_select_pawn(participant)
		STAGE_SHOW_ACTIONS:
			return combat_level.on_show_actions(participant)
		STAGE_SHOW_MOVEMENTS:
			return combat_level.on_show_movements(participant)
		STAGE_SELECT_LOCATION:
			return combat_level.on_select_location(participant)
		STAGE_MOVE_UNIT:
			return combat_level.on_move_unit(participant)
		STAGE_DISPLAY_TARGETS:
			return combat_level.on_display_targets(participant)
		STAGE_SELECT_ATTACK_TARGET:
			return combat_level.on_select_attack_target(participant)
		STAGE_ATTACK:
			return combat_level.on_attack(participant)
		STAGE_END_TURN:
			return combat_level.on_end_turn(participant)
		_:
			return STAGE_DONE
