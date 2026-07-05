## LootRoller — Roll drops + XP/EC for a defeated mob.
##
## Phase 2. Called by HubWorld on combat victory (or by EncounterBuilder
## during the post-combat hook). Reads:
##   - data/loot_tables.json (per-biome item pools)
##   - data/mobs.json (per-mob drop table — `drops: [{item_id, chance, qty}]`)
## Writes the results to:
##   - InventoryManager (items)
##   - ProgressionManager (XP + EC)
##
## If the mob has an explicit `drops` list, that takes priority over
## the biome loot table (placeholder behavior until per-mob drops are
## fully populated in data/mobs.json during Phase 2 follow-ups).
class_name LootRoller
extends RefCounted

const MOB_DROP_WEIGHT_DEFAULT := 1.0
const LOOT_TABLE_WEIGHT_DEFAULT := 1.0

const XP_PER_LEVEL := 5
const XP_PER_LEVEL_BONUS := 5
const EC_PER_LEVEL := 2
const EC_PER_LEVEL_BONUS_MIN := 1
const EC_PER_LEVEL_BONUS_MAX := 5


## Roll drops + XP + EC for a defeated mob. Returns a result dictionary:
##   {item_drops: [{item_id, qty}, ...], xp: int, ec: int}
## Applies the results to InventoryManager + ProgressionManager as a
## side effect. Pass null for inv / prog to skip the side effect (e.g.
## in a smoke test).
static func roll_and_apply(
		mob_data: Dictionary,
		biome_key: String,
		inv: Node = null,
		prog: Node = null
	) -> Dictionary:
	var result := roll(mob_data, biome_key)
	if inv != null and result.item_drops.size() > 0:
		for drop in result.item_drops:
			inv.add_item(drop.item_id, drop.qty)
	if prog != null:
		if result.xp > 0:
			prog.add_xp(result.xp)
		if result.ec > 0:
			prog.add_ec(result.ec)
	return result


## Roll drops + XP + EC without applying. Useful for tests / previews.
static func roll(mob_data: Dictionary, biome_key: String) -> Dictionary:
	var item_drops: Array = []
	# 1. Per-mob explicit drops (if present)
	if mob_data.has("drops"):
		for drop in mob_data.get("drops", []):
			if not (drop is Dictionary):
				continue
			var chance: float = float(drop.get("chance", 1.0))
			if randf() <= chance:
				var qty: int = int(drop.get("qty", 1))
				if qty > 0:
					item_drops.append({
						"item_id": str(drop.get("item_id", "")),
						"qty": qty,
					})

	# 2. Biome loot table fallback (if no per-mob drops landed)
	if item_drops.is_empty():
		item_drops = roll_biome_table(biome_key, 1)

	# 3. XP and EC, scaled by mob level
	var mob_level: int = int(mob_data.get("level", 1))
	var xp: int = mob_level * XP_PER_LEVEL + XP_PER_LEVEL_BONUS
	var ec: int = mob_level * EC_PER_LEVEL + randi_range(EC_PER_LEVEL_BONUS_MIN, EC_PER_LEVEL_BONUS_MAX)

	return {
		"item_drops": item_drops,
		"xp": xp,
		"ec": ec,
	}


## Roll a single item from the biome loot table.
static func roll_biome_table(biome_key: String, count: int = 1) -> Array:
	var path := "res://data/loot_tables.json"
	if not ResourceLoader.exists(path):
		return []
	var raw = load(path)
	if raw == null:
		return []
	var data = raw.data if "data" in raw else raw
	if not (data is Dictionary):
		return []
	var items: Array = data.get(biome_key, [])
	if not (items is Array) or items.is_empty():
		return []
	# Weighted random pick
	var total_weight := 0.0
	for entry in items:
		total_weight += float(entry.get("drop_weight", LOOT_TABLE_WEIGHT_DEFAULT))
	if total_weight <= 0.0:
		return []
	var pick: float = randf() * total_weight
	for entry in items:
		pick -= float(entry.get("drop_weight", LOOT_TABLE_WEIGHT_DEFAULT))
		if pick <= 0.0:
			var qty_range: Array = [1, 1]
			if entry.has("name"):
				# Conventional loot_tables.json uses a name + drop_weight; we
				# treat it as item_id by lowercasing+snake_casing the name.
				var name_str: String = str(entry.get("name", ""))
				var item_id := name_str.to_snake_case().replace(" ", "_")
				return [{
					"item_id": item_id,
					"qty": 1,
				}]
			# Fallback: explicit item_id if present
			if entry.has("item_id"):
				return [{
					"item_id": str(entry.get("item_id", "")),
					"qty": 1,
				}]
			return []
	return []
