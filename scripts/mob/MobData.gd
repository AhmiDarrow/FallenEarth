## MobData — Data-only resource for a single overworld mob instance.
## Carries everything needed to spawn, render, and fight the mob.
## No scene tree references — purely data for serialisation & pooling.
class_name MobData
extends RefCounted

var mob_id: String = ""
var sprite_id: String = ""
var display_name: String = ""
var archetype: String = ""
var level: int = 1
var hp: int = 30
var max_hp: int = 30
var attack_damage: int = 6
var armor: int = 0
var aggro_range: int = 5
var mob_type: String = "aggressive"
var threat_mult: float = 1.0
var grid_x: int = 0
var grid_y: int = 0

var extra: Dictionary = {}

static func from_enemy_dict(enemy: Dictionary, local_x: int, local_y: int) -> MobData:
	var d := MobData.new()
	d.mob_id = str(enemy.get("id", "mob_%d_%d" % [local_x, local_y]))
	d.sprite_id = str(enemy.get("sprite_id", ""))
	d.display_name = str(enemy.get("name", "Mob"))
	d.archetype = str(enemy.get("archetype", ""))
	d.level = int(enemy.get("level", 1))
	d.hp = int(enemy.get("hp", 30))
	d.max_hp = int(enemy.get("max_hp", d.hp))
	d.attack_damage = int(enemy.get("attack_damage", 6))
	d.armor = int(enemy.get("armor", 0))
	d.aggro_range = int(enemy.get("aggro_range", 5))
	d.mob_type = str(enemy.get("mob_type", enemy.get("ai_archetype", "aggressive")))
	d.threat_mult = float(enemy.get("threat_mult", 1.0))
	d.grid_x = local_x
	d.grid_y = local_y
	d.extra = enemy.duplicate(true)
	return d

func to_enemy_dict() -> Dictionary:
	var out := extra.duplicate(true)
	out["id"] = mob_id
	out["sprite_id"] = sprite_id
	out["name"] = display_name
	out["archetype"] = archetype
	out["level"] = level
	out["hp"] = hp
	out["max_hp"] = max_hp
	out["attack_damage"] = attack_damage
	out["armor"] = armor
	out["aggro_range"] = aggro_range
	out["mob_type"] = mob_type
	out["threat_mult"] = threat_mult
	out["local_x"] = grid_x
	out["local_y"] = grid_y
	return out

func sprite_path() -> String:
	return "res://assets/mobs/%s.png" % sprite_id.replace("-", "_")
