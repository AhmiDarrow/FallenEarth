extends SceneTree

func _init() -> void:
	var wg := WorldGenerator.new()
	root.add_child(wg)
	if not wg.initialize():
		print("FAIL init")
		quit(1)
		return
	var sizes := {"small": 8, "medium": 12, "large": 18}
	var ok := true
	for name in sizes:
		var R: int = sizes[name]
		var freq: int = WorldGenerator.size_to_hex_frequency(R)
		var expected: int = WorldGenerator.hexasphere_tile_count(freq)
		var world: Dictionary = wg.generate("FallenEarth", 1.0, R)
		var layout: Dictionary = WorldGenerator.build_hex_sphere_layout(world, R, 4.0)
		var count: int = int(layout.get("tile_count", 0))
		var min_nn: float = float(layout.get("min_neighbor", 0.0))
		var avg_nn: float = float(layout.get("avg_neighbor", 0.0))
		var max_nn: float = float(layout.get("max_neighbor", 0.0))
		var hex_size: float = float(layout.get("hex_size", 0.0))
		var nn_ratio: float = float(layout.get("nn_ratio", 999.0))
		var pack_ratio: float = float(layout.get("pack_ratio", 999.0))
		var biome_counts: Dictionary = {}
		var playable: int = 0
		for k in world:
			var t: Dictionary = world[k]
			if t.get("is_riftspire", false):
				continue
			var bn: String = str(t.get("name", "?"))
			biome_counts[bn] = int(biome_counts.get(bn, 0)) + 1
			playable += 1
		var biome_n: int = biome_counts.size()
		var max_share: float = 0.0
		var min_share: float = 1.0
		var share_parts: PackedStringArray = PackedStringArray()
		for bn in biome_counts:
			var c: int = int(biome_counts[bn])
			var sh: float = float(c) / float(maxi(playable, 1))
			max_share = maxf(max_share, sh)
			min_share = minf(min_share, sh)
			share_parts.append("%s:%d" % [bn, c])
		share_parts.sort()
		print("%s R=%d F=%d tiles=%d (expect %d) biomes=%d min_nn=%.4f avg_nn=%.4f max_nn=%.4f nn_ratio=%.3f hex_size=%.4f pack_ratio=%.3f max_share=%.2f min_share=%.2f" % [
			name, R, freq, count, expected, biome_n, min_nn, avg_nn, max_nn, nn_ratio, hex_size, pack_ratio, max_share, min_share
		])
		print("  biomes: %s" % ", ".join(share_parts))
		if count != expected:
			print("  FAIL tile count")
			ok = false
		if min_nn < 0.05:
			print("  FAIL collapsed neighbors")
			ok = false
		if nn_ratio > 1.40:
			print("  FAIL spacing uneven nn_ratio > 1.40")
			ok = false
		if pack_ratio > 0.99 or pack_ratio < 0.90:
			print("  FAIL pack_ratio out of [0.90, 0.99]")
			ok = false
		if biome_n < 8:
			print("  FAIL low biome diversity")
			ok = false
		if max_share > 0.22:
			print("  FAIL biome monopoly max_share > 0.22")
			ok = false
		if min_share < 0.03 and biome_n >= 8:
			print("  FAIL biome starved min_share < 0.03")
			ok = false
		# Coverage: tiles should exist in all 8 octants roughly
		var oct: Dictionary = {}
		for k in world:
			var t2: Dictionary = world[k]
			if not t2.has("unit_pos"):
				continue
			var u: Vector3 = WorldGenerator.unit_pos_vec(t2)
			var ox: int = 1 if u.x >= 0.0 else 0
			var oy: int = 1 if u.y >= 0.0 else 0
			var oz: int = 1 if u.z >= 0.0 else 0
			var ok_key: String = "%d%d%d" % [ox, oy, oz]
			oct[ok_key] = int(oct.get(ok_key, 0)) + 1
		if oct.size() < 8:
			print("  FAIL incomplete sphere coverage octants=%d" % oct.size())
			ok = false
		else:
			print("  coverage: all 8 octants ok")
	print("RESULT: %s" % ("OK" if ok else "FAIL"))
	quit(0 if ok else 1)
