extends SceneTree
## Headless clutter distribution report for all biomes.
## Usage: godot --headless --path . -s tools/diag_clutter_distribution.gd

func _init() -> void:
	print("=== clutter distribution diag ===")
	var biomes_raw = load("res://data/biomes.json")
	var biomes: Array = []
	if biomes_raw is Array:
		biomes = biomes_raw
	elif biomes_raw != null and "data" in biomes_raw:
		biomes = biomes_raw.data

	var world_seed := "diag_clutter_v2"
	var ok := true
	for entry in biomes:
		if entry == null or not (entry is Dictionary):
			continue
		var name: String = str(entry.get("name", ""))
		if name.is_empty():
			continue
		var tier: int = int(entry.get("difficulty_tier", 1))
		var tile := {
			"name": name,
			"elevation": float(entry.get("elevation", 0.5)),
			"rainfall": float(entry.get("rainfall", 0.5)),
			"difficulty_tier": tier,
		}
		var t0 := Time.get_ticks_msec()
		var map: Dictionary = LocalMapGenerator.generate(world_seed, tier, tier * 3, tile)
		var ms := Time.get_ticks_msec() - t0
		var terrain: PackedByteArray = map.get("terrain", PackedByteArray())
		var nodes: Array = map.get("resource_nodes", [])
		var decor: Array = map.get("decor", [])
		var veg := 0
		var ground := 0
		var total := terrain.size()
		for i in total:
			var t := int(terrain[i])
			if t == LocalMapGenerator.TERRAIN_VEGETATION:
				veg += 1
			elif t == LocalMapGenerator.TERRAIN_GROUND:
				ground += 1
		var by_cat: Dictionary = {}
		var by_yield: Dictionary = {}
		var tier_violations := 0
		for n in nodes:
			if n == null or not (n is Dictionary):
				continue
			var cat: String = str(n.get("category", "?"))
			by_cat[cat] = int(by_cat.get(cat, 0)) + 1
			var yid: String = ""
			var y = n.get("yield", {})
			if y is Dictionary:
				yid = str(y.get("item_id", ""))
			if not yid.is_empty():
				by_yield[yid] = int(by_yield.get(yid, 0)) + 1
			var mt: int = int(n.get("min_biome_tier", 0))
			if mt > tier:
				tier_violations += 1
		var trees: int = int(by_cat.get("trees", 0))
		var ore: int = int(by_cat.get("ore", 0))
		var rocks: int = int(by_cat.get("rocks", 0))
		var crystals: int = int(by_cat.get("crystals", 0))
		var formations: int = int(by_cat.get("formations", 0))
		var veg_pct: float = 100.0 * float(veg) / float(maxi(total, 1))
		print("--- %s (tier %d) %dms ---" % [name, tier, ms])
		print("  terrain veg=%.1f%% ground=%d nodes=%d decor=%d" % [veg_pct, ground, nodes.size(), decor.size()])
		print("  cats trees=%d rocks=%d ore=%d form=%d crystal=%d" % [trees, rocks, ore, formations, crystals])
		print("  yields %s" % str(by_yield))
		if tier_violations > 0:
			print("  FAIL tier_violations=%d" % tier_violations)
			ok = false
		# Soft expectations
		if name == "Ironwood Thicket" and trees < 2500:
			print("  WARN ironwood trees low (%d)" % trees)
		if name == "Scorched Plains":
			if by_yield.has("iron_ore") or by_yield.has("copper_ore") or by_yield.has("starmetal_ore"):
				print("  FAIL starter has high ore %s" % str(by_yield))
				ok = false
			if by_yield.has("void_shard") or by_yield.has("teal_crystal"):
				print("  FAIL starter has crystals")
				ok = false
		if name == "Neon Bogs" and by_yield.has("void_shard"):
			print("  FAIL neon bogs has void_shard")
			ok = false
		if veg_pct < 0.5 and name in ["Ironwood Thicket", "Neon Bogs", "Ash Wastes"]:
			print("  WARN veg cover very low")

	if ok:
		print("PASS clutter distribution")
		quit(0)
	else:
		print("FAIL clutter distribution")
		quit(1)
