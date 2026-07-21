extends SceneTree
## Debug probe: confirm resource nodes, floor pickups, decor, and visuals are
## actually rendered at runtime. Reports counts at every layer of the chain.

const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")
const LocalMapViewScene = preload("res://scenes/LocalMapView.tscn")

func _initialize() -> void:
	print("[probe-rv] v11 visual spawn probe")

	var biome_tile := {
		"name": "Ash Wastes",
		"elevation": 0.5,
		"rainfall": 0.3,
		"rift_chance": 0.25,
	}
	var map_data: Dictionary = LocalMapGen.generate("probe_seed", 0, 0, biome_tile)

	print("[probe-rv] Generator output:")
	print("  resource_nodes = %d" % (map_data.get("resource_nodes", []) as Array).size())
	print("  floor_pickups =  %d" % (map_data.get("floor_pickups", []) as Array).size())
	print("  decor =          %d" % (map_data.get("decor", []) as Array).size())
	print("  cooking_tables = %d" % (map_data.get("cooking_tables", []) as Array).size())

	# Categorize resource_nodes by category and sprite.
	var by_cat: Dictionary = {}
	var by_sprite: Dictionary = {}
	for n in map_data.get("resource_nodes", []):
		var cat: String = str(n.get("category", "?"))
		by_cat[cat] = int(by_cat.get(cat, 0)) + 1
		var sp: String = str(n.get("sprite", "?"))
		by_sprite[sp] = int(by_sprite.get(sp, 0)) + 1
	print("  resource_nodes by category: %s" % JSON.stringify(by_cat))
	print("  resource_nodes by sprite (top 10):")
	var items: Array = []
	for k in by_sprite:
		items.append([k, int(by_sprite[k])])
	items.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
	for i in range(min(10, items.size())):
		print("    %s = %d" % [items[i][0], items[i][1]])

	# Now do the visual phase.
	var view: Node2D = LocalMapViewScene.instantiate()
	root.add_child(view)
	await process_frame
	view.configure(map_data)

	var nl: Node = view.get_node_or_null("NodeLayer")
	var pl: Node = view.get_node_or_null("PickupLayer")
	var dl: Node = view.get_node_or_null("DecorLayer")
	print("[probe-rv] After configure(map_data):")
	print("  NodeLayer children = %d" % (nl.get_child_count() if nl != null else -1))
	print("  PickupLayer children = %d" % (pl.get_child_count() if pl != null else -1))
	print("  DecorLayer children = %d" % (dl.get_child_count() if dl != null else -1))

	# ResourceVisualManager is a child of the LocalMapView.
	var rvm_count: int = 0
	var spr_total: int = 0
	var spr_with_tex: int = 0
	var sample_pos: Array = []
	for child in view.get_children():
		if child.name == "ResourceVisualManager":
			rvm_count += 1
			print("  ResourceVisualManager present, children = %d z=%d" % [child.get_child_count(), child.z_index])
			for sub in child.get_children():
				if sub is Sprite2D:
					spr_total += 1
					var s: Sprite2D = sub as Sprite2D
					if s.texture != null:
						spr_with_tex += 1
					if sample_pos.size() < 5:
						sample_pos.append("%s @ %s sc=%s" % [s.name, str(s.position), str(s.scale)])
	print("[probe-rv] Sprite2D total = %d with_tex = %d" % [spr_total, spr_with_tex])
	for s in sample_pos:
		print("    sample %s" % s)

	# Verify the texture folder coverage
	print("[probe-rv] ResourceNodes sprite coverage from generated map_data:")
	var rn_path := "res://assets/sprites/resource_nodes/"
	var present: Dictionary = {}
	var missing: Array = []
	for sp in by_sprite:
		# Sample one variant per sprite to verify folder existence.
		var sample_path: String = "%s%s_00.png" % [rn_path, sp]
		if ResourceLoader.exists(sample_path):
			present[sp] = true
		else:
			present[sp] = false
			missing.append(sp)
	if missing.is_empty():
		print("  ALL sprites present.")
	else:
		print("  MISSING sprites (will show placeholder): %s" % str(missing))

	print("[probe-rv] done")
	quit(0)
