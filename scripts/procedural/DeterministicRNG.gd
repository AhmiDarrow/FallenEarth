## DeterministicRNG — Seeded RNG for cross-session visual consistency.
## Wraps RandomNumberGenerator with a stable seed derived from world seed +
## entity-specific salt, ensuring the same entity always looks the same.
class_name DeterministicRNG
extends RefCounted

var _rng: RandomNumberGenerator
var _base_seed: int

func _init(seed_value: int = 0) -> void:
	_base_seed = seed_value
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value

func reseed(new_seed: int) -> void:
	_base_seed = new_seed
	_rng.seed = new_seed

func for_entity(entity_id: String, extra_salt: int = 0) -> RandomNumberGenerator:
	var entity_seed := _base_seed ^ entity_id.hash() ^ extra_salt
	var child_rng := RandomNumberGenerator.new()
	child_rng.seed = entity_seed
	return child_rng

func for_visual(visual_data: Dictionary) -> RandomNumberGenerator:
	var seed_val: int = visual_data.get("variation_seed", 0)
	if seed_val == 0:
		seed_val = _base_seed ^ visual_data.hash()
	return for_entity(str(seed_val))

static func world_seed_from_string(seed_str: String) -> int:
	return seed_str.hash()

static func combine_seeds(a: int, b: int) -> int:
	return a ^ (b * 0x45d9f3b) ^ ((b >> 16) * 0x45d9f3b)

func randf_range_seed(min_val: float, max_val: float, salt: int = 0) -> float:
	var child := RandomNumberGenerator.new()
	child.seed = _base_seed ^ salt
	return child.randf_range(min_val, max_val)

func randi_range_seed(min_val: int, max_val: int, salt: int = 0) -> int:
	var child := RandomNumberGenerator.new()
	child.seed = _base_seed ^ salt
	return child.randi_range(min_val, max_val)
