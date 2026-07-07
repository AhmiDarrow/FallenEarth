class_name UnitCombatService
extends RefCounted
## Attack resolution for a single unit.
##
## Classic RPG damage formula:
##   base_damage = (attacker.attack + attacker.level) × facing_mult
##   reduction    = defender.level × 0.5 + defender.defense × 0.4
##   final_damage = max(1, base_damage − reduction)
##
## Hit chance:
##   hit% = clamp(80 + attacker.level − defender.level − defender.defense × 1.5, 50, 95)

const BACK_ATTACK_MULT: float = 1.5
const SIDE_ATTACK_MULT: float = 1.2
const BASE_HIT_CHANCE: float = 80.0
const MIN_HIT_CHANCE: float = 50.0
const MAX_HIT_CHANCE: float = 95.0
const LEVEL_HIT_WEIGHT: float = 1.0
const ARMOR_MISS_WEIGHT: float = 1.5
const DEFENSE_FACTOR: float = 0.4
const LEVEL_REDUCTION_FACTOR: float = 0.5

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func in_range(attacker_pos: Vector2i, target_pos: Vector2i, attack_range: int) -> bool:
	var dx: int = abs(attacker_pos.x - target_pos.x)
	var dy: int = abs(attacker_pos.y - target_pos.y)
	var dist: int = maxi(dx, dy)
	return dist > 0 and dist <= attack_range


func facing_multiplier(target_facing: int, attacker_pos: Vector2i, target_pos: Vector2i) -> float:
	var delta: Vector2i = attacker_pos - target_pos
	var back_dir: Vector2i
	match target_facing:
		0: back_dir = Vector2i(0, 1)
		1: back_dir = Vector2i(-1, 0)
		2: back_dir = Vector2i(0, -1)
		3: back_dir = Vector2i(1, 0)
		_: back_dir = Vector2i.ZERO
	if delta == back_dir:
		return BACK_ATTACK_MULT
	var side_dir: Vector2i = Vector2i(-back_dir.y, back_dir.x)
	if delta == side_dir or delta == Vector2i(-side_dir.x, -side_dir.y):
		return SIDE_ATTACK_MULT
	return 1.0


## Calculate hit chance % based on attacker and defender stats.
func hit_chance(atk_res: UnitResource, tgt_res: UnitResource) -> float:
	var chance: float = BASE_HIT_CHANCE
	chance += float(atk_res.level) * LEVEL_HIT_WEIGHT
	chance -= float(tgt_res.level) * LEVEL_HIT_WEIGHT
	chance -= float(tgt_res.defense) * ARMOR_MISS_WEIGHT
	return clampf(chance, MIN_HIT_CHANCE, MAX_HIT_CHANCE)


## Calculate damage after defense reduction.
func calc_damage(atk_res: UnitResource, tgt_res: UnitResource, mult: float) -> int:
	var base: float = (float(atk_res.attack) + float(atk_res.level)) * mult
	var reduction: float = float(tgt_res.level) * LEVEL_REDUCTION_FACTOR + float(tgt_res.defense) * DEFENSE_FACTOR
	return maxi(1, int(round(base - reduction)))


## Resolve an attack. Returns damage dealt (0 if miss).
func resolve_attack(attacker, target, arena: ArenaResource) -> int:
	if attacker == null or target == null or arena == null:
		return 0
	var atk_res: UnitResource = attacker.res
	var tgt_res: UnitResource = target.res
	if atk_res == null or tgt_res == null:
		return 0
	if not in_range(atk_res.grid_pos, tgt_res.grid_pos, atk_res.attack_range):
		return 0
	# Hit check
	var hit: float = hit_chance(atk_res, tgt_res)
	if _rng.randf() * 100.0 > hit:
		arena.unit_attacked.emit(atk_res.unit_id, tgt_res.unit_id, 0)
		return 0
	# Damage calculation
	var mult: float = facing_multiplier(tgt_res.facing, atk_res.grid_pos, tgt_res.grid_pos)
	var damage: int = calc_damage(atk_res, tgt_res, mult)
	tgt_res.apply_damage(damage)
	arena.unit_attacked.emit(atk_res.unit_id, tgt_res.unit_id, damage)
	return damage
