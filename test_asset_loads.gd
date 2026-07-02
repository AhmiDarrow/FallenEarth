# test_asset_loads.gd
# Clean expanded test for assets + wiring
extends SceneTree

func _init():
	print("=== FallenEarth Hand-Drawn + Wiring Test ===")
	var ok = 0
	var fail = 0

	var samples = [
		"res://assets/tilesets/ash_wastes/selected/ash_wastes_debris_001.png",
		"res://assets/tilesets/ash_wastes/selected/ash_wastes_ground_001.png",
		"res://assets/tilesets/neon_bogs/neon_tile_00001_.png",
		"res://assets/tilesets/rust_canyons/rust_canyons_tile_001.png",
		"res://assets/tilesets/ironwood_thicket/selected/tile_ironwood_thicket_ground_00001_.png",
		"res://assets/tilesets/ironwood_thicket/tile_ironwood_thicket_debris_00001_.png",
		"res://assets/tilesets/scorched_plains/tile_scorched_plains_ground_00001_.png",
		"res://assets/tilesets/glass_dunes/tile_glass_dunes_ground_00001_.png",
		"res://assets/tilesets/toxin_marshes/tile_toxin_marshes_ground_00001_.png",
		"res://assets/characters/chthon_male/char_chthon_male_front_idle_00010_.png",
		"res://assets/characters/chthon_male/char_chthon_male_side_idle_00008_.png",
		"res://assets/characters/mutant_female/char_mutant_female_side_idle_final2_00004_.png",
		"res://assets/characters/vesperid_female/char_vesperid_female_side_idle_00014_.png",
		"res://assets/equipment/equip_m2_head0_00001_.png",
		"res://assets/equipment/equip_m2_torso0_00001_.png",
		"res://assets/props_mobs/rest_prop_bush_00001_.png",
		"res://assets/ui/rest_ui_wood_button_00001_.png",
		"res://assets/rifts/rest_rift_single_00001_.png",
		"res://assets/backgrounds/rest_bg_atmo_00001_.png",
	]

	for p in samples:
		var tex = load(p)
		if tex:
			print("  OK(resource) ", p.get_file())
			ok += 1
		elif FileAccess.file_exists(p):
			var img = Image.new()
			if img.load(p) == OK:
				print("  OK(disk) ", p.get_file())
				ok += 1
			else:
				print("  BAD ", p.get_file())
				fail += 1
		else:
			print("  MISS ", p.get_file())
			fail += 1

	print("Core classes...")
	for s in ["TileSetBuilder.gd", "WorldGenerator.gd", "CharacterVisual.gd", "EquipmentManager.gd", "HubWorld.gd"]:
		var sc = load("res://scripts/" + s)
		if sc:
			print("  OK ", s)
			ok += 1
		else:
			print("  FAIL ", s)
			fail += 1

	# Builder integration test for all 10 biomes (playtest ready)
	var bs = load("res://scripts/TileSetBuilder.gd")
	if bs:
		var b = bs.new()
		if b.has_method("get_paths_for_biome"):
			var biomes_test = ["Ash Wastes", "Rust Canyons", "Neon Bogs", "Glass Dunes", "Toxin Marshes", "Scorched Plains", "Corpse Fields", "Stormspire Highlands", "Dead City Outskirts", "Ironwood Thicket"]
			for bm in biomes_test:
				var ps = b.get_paths_for_biome(bm)
				if ps.size() > 0:
					print("  OK builder paths for ", bm, ": ", ps.size())
					ok += 1

	print("RESULT: ", ok, " ok, ", fail, " failed")
	quit()

