class_name UnitCombatService
extends RefCounted
## Attack resolution for a single unit.
##
## Adapted from ramaureirac/godot-tactical-rpg
## `TacticsPawnCombatService.attack_target_pawn` — but for 2D
## and with the same back/side attack multipliers.

## v0.11.0: Back attack damage multiplier (1.5x). Side attack
## multiplier (1.2x). These mirror the FFT convention.
const BACK_ATTACK_MULT: float = 1.5
const SIDE_ATTACK_MULT: float = 1.2

## v0.11.0: Attack range check. Returns true if `from` (the
## attacker's grid pos) is within `attack_range` tiles of
## `target` (the target's grid pos). 4-neighbour distance.
func in_range(attacker_pos: Vector2i, target_pos: Vector2i, attack_range: int) -> bool:
	var dx: int = abs(attacker_pos.x - target_pos.x)
	var dy: int = abs(attacker_pos.y - target_pos.y)
	# Chebyshev distance (4-neighbour): max(dx, dy).
	var dist: int = maxi(dx, dy)
	return dist > 0 and dist <= attack_range


## v0.11.0: Compute the facing multiplier for an attack. If the
## attacker is behind or to the side of the target (relative to
## the target's facing), the damage is multiplied.
##
## `target_facing` is 0=N, 1=E, 2=S, 3=W.
## `attacker_pos` and `target_pos` are the grid positions.
func facing_multiplier(target_facing: int, attacker_pos: Vector2i, target_pos: Vector2i) -> float:
	var delta: Vector2i = attacker_pos - target_pos
	# The "back" direction is the opposite of the target's facing.
	# N=back, S=back, etc.
	# Facing: 0=N (up, -y), 1=E (right, +x), 2=S (down, +y), 3=W (left, -x)
	var back_dir: Vector2i
	match target_facing:
		0: back_dir = Vector2i(0, 1)   # N-facing: back is south
		1: back_dir = Vector2i(-1, 0)  # E-facing: back is west
		2: back_dir = Vector2i(0, -1)  # S-facing: back is north
		3: back_dir = Vector2i(1, 0)   # W-facing: back is east
		_: back_dir = Vector2i.ZERO
	if delta == back_dir:
		return BACK_ATTACK_MULT
	# Side is perpendicular: rotate back_dir 90deg.
	var side_dir: Vector2i = Vector2i(-back_dir.y, back_dir.x)
	if delta == side_dir or delta == Vector2i(-side_dir.x, -side_dir.y):
		return SIDE_ATTACK_MULT
	return 1.0


## v0.11.0: Resolve an attack. Returns the damage dealt (after
## multipliers). Applies the damage to the target's resource
## and emits the arena's unit_attacked signal.
func resolve_attack(attacker, target, arena: ArenaResource) -> int:
	if attacker == null or target == null or arena == null:
		return 0
	var atk_res: UnitResource = attacker.res
	var tgt_res: UnitResource = target.res
	if atk_res == null or tgt_res == null:
		return 0
	if not in_range(atk_res.grid_pos, tgt_res.grid_pos, atk_res.attack_range):
		return 0
	var mult: float = facing_multiplier(tgt_res.facing, atk_res.grid_pos, tgt_res.grid_pos)
	# Percentage-based defense: defense reduces damage by a percentage
	# instead of flat subtraction. At 0 defense = 0% reduction,
	# at 10 defense = ~33% reduction, at 20 defense = ~50% reduction.
	var raw: float = float(atk_res.attack) * mult
	var reduction: float = float(tgt_res.defense) / (float(tgt_res.defense) + 20.0)
	var damage: int = maxi(1, int(round(raw * (1.0 - reduction))))
	tgt_res.apply_damage(damage)
	arena.unit_attacked.emit(atk_res.unit_id, tgt_res.unit_id, damage)
	return damage
