## CombatAI — Base class for FFT-style mob AI.
##
## Every archetype implements `decide(state) -> AIAction`. The state
## is built by CombatAIEngine.build_state() and contains everything
## the AI needs to score candidate actions.
##
## AIAction shape:
##   {
##     "type": "move" | "attack" | "skill" | "wait" | "defend",
##     "target": Vector2i (for move/attack/skill),
##     "skill_id": String (for skill),
##     "score": float (higher = better; used for tie-breaking),
##   }
class_name CombatAI
extends RefCounted

const INF_DISTANCE := 1000


## Override in archetypes.
func decide(state: Dictionary) -> Dictionary:
	return {"type": "wait", "score": 0.0}


## Helper: Manhattan distance between two grid positions.
static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Helper: Chebyshev distance (king-move). Better for "in range" checks.
static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## Helper: facing direction from a to b. Returns CombatManager.Facing value.
static func facing_toward(from_pos: Vector2i, to_pos: Vector2i) -> int:
	var dx: int = to_pos.x - from_pos.x
	var dy: int = to_pos.y - from_pos.y
	if absi(dx) > absi(dy):
		if dx > 0:
			return 1  # EAST
		return 3  # WEST
	if dy > 0:
		return 2  # SOUTH
	return 0  # NORTH


## Helper: bonus multiplier for attacking from a given direction relative
## to the target's facing. Matches CombatManager constants.
static func facing_bonus(attacker_pos: Vector2i, target_pos: Vector2i, target_facing: int) -> float:
	var dx: int = attacker_pos.x - target_pos.x
	var dy: int = attacker_pos.y - target_pos.y
	# The target's "back" is opposite to its facing direction.
	var back_dx: int = 0
	var back_dy: int = 0
	match target_facing:
		0:  # target facing NORTH → back is SOUTH
			back_dx = 0
			back_dy = 1
		1:  # target facing EAST → back is WEST
			back_dx = -1
			back_dy = 0
		2:  # target facing SOUTH → back is NORTH
			back_dx = 0
			back_dy = -1
		3:  # target facing WEST → back is EAST
			back_dx = 1
			back_dy = 0
	# Sign of dx/dy aligns with back_dx/back_dy?
	var sign_dx: int = 0 if dx == 0 else (1 if dx > 0 else -1)
	var sign_dy: int = 0 if dy == 0 else (1 if dy > 0 else -1)
	if sign_dx == back_dx and sign_dy == back_dy and (sign_dx != 0 or sign_dy != 0):
		return 1.5  # BACK_ATTACK_MULT
	# Side: orthogonal to facing
	if (sign_dx != 0 and sign_dy == 0 and back_dx == 0) or (sign_dy != 0 and sign_dx == 0 and back_dy == 0):
		return 1.25  # SIDE_ATTACK_MULT
	return 1.0


## Score a candidate attack on a target from the attacker's current
## position. Higher = better target. Considers HP, flanking, height.
static func score_attack(attacker_pos: Vector2i, target: Dictionary, height_map: Dictionary) -> float:
	if int(target.get("hp", 0)) <= 0:
		return -1.0
	var t_pos: Vector2i = target.get("pos", Vector2i.ZERO)
	var t_facing: int = int(target.get("facing", 2))
	var bonus: float = facing_bonus(attacker_pos, t_pos, t_facing)
	var t_hp: int = int(target.get("hp", 0))
	var t_max: int = int(target.get("max_hp", t_hp))
	var t_ratio: float = float(t_hp) / float(maxi(1, t_max))
	# Prefer low-HP targets (execute!) and back/side attacks.
	var score: float = 100.0 * bonus * (1.5 - t_ratio)
	# Height advantage bonus.
	var atk_h: int = int(height_map.get("%d,%d" % [attacker_pos.x, attacker_pos.y], 0))
	var tgt_h: int = int(height_map.get("%d,%d" % [t_pos.x, t_pos.y], 0))
	if atk_h > tgt_h:
		score *= 1.0 + float(atk_h - tgt_h) * 0.1
	# Bosses are worth a lot.
	if bool(target.get("is_boss", false)):
		score *= 0.5  # but we still want to focus fire, not "skip" them
	return score
