## RiftDungeonGenerator — Hybrid noise + maze dungeon for rift instances.
## Size scales with biome difficulty_tier (1→31x23, 5→512x512).
## Easy: tight maze tunnels. Max: open wasteland with maze pockets.
class_name RiftDungeonGenerator
extends RefCounted

const TILE_WALL := "wall"
const TILE_FLOOR := "floor"
const TILE_ENCOUNTER := "encounter"
const TILE_BOSS := "boss"
const TILE_CORE := "core"
const TILE_ENTRANCE := "entrance"
const TILE_DECOR := "decor"

## difficulty_tier → {size, maze_density}
const DIFFICULTY_TIERS := {
	1: {"size": Vector2i(31, 23), "maze_density": 0.80},
	2: {"size": Vector2i(41, 31), "maze_density": 0.70},
	3: {"size": Vector2i(64, 64), "maze_density": 0.55},
	4: {"size": Vector2i(128, 128), "maze_density": 0.40},
	5: {"size": Vector2i(512, 512), "maze_density": 0.25},
}

const BIOME_DIFFICULTY := {
	"Scorched Plains": 1,
	"Ash Wastes": 2,
	"Neon Bogs": 3,
	"Ironwood Thicket": 3,
	"Rust Canyons": 4,
	"Glass Dunes": 4,
	"Corpse Fields": 4,
	"Toxin Marshes": 4,
	"Stormspire Highlands": 5,
	"Dead City Outskirts": 5,
}


static func generate(rift_id: String, biome_key: String) -> Dictionary:
	var seed_val: int = abs((rift_id + biome_key).hash())
	seed(seed_val)

	var diff: int = BIOME_DIFFICULTY.get(biome_key, 2)
	var cfg: Dictionary = DIFFICULTY_TIERS.get(diff, DIFFICULTY_TIERS[2])
	var width: int = cfg["size"].x
	var height: int = cfg["size"].y
	var maze_density: float = cfg["maze_density"]

	var tiles: Dictionary = {}

	if width >= 128:
		_generate_noise_terrain(tiles, width, height, seed_val, maze_density)
	else:
		_generate_maze(tiles, width, height)

	_place_entrance(tiles, width, height)
	var boss_pos := _place_boss_and_core(tiles, width, height)
	_scatter_encounters(tiles, width, height, boss_pos)

	return {
		"width": width,
		"height": height,
		"tiles": tiles,
		"player_pos": {"x": 1, "y": 1},
		"entrance": {"x": 1, "y": 1},
		"boss_pos": {"x": boss_pos.x, "y": boss_pos.y},
		"core_pos": _find_core(tiles),
		"boss_defeated": false,
		"rift_cleared": false,
		"seed": seed_val,
		"room_count": 0,
	}


## Recursive-backtracker maze for smaller rifts (width < 128).
## Occasionally carves wider corridors (2-3 cells) and dead-end chambers for variety.
static func _generate_maze(tiles: Dictionary, width: int, height: int) -> void:
	for y in range(height):
		for x in range(width):
			tiles[_key(x, y)] = {"type": TILE_WALL, "cleared": true}

	var stack: Array[Vector2i] = []
	var start := Vector2i(2, 2)
	tiles[_key(start.x, start.y)] = {"type": TILE_FLOOR, "cleared": true}
	stack.append(start)

	var rng := RandomNumberGenerator.new()
	rng.seed = randi()

	while stack.size() > 0:
		var cur: Vector2i = stack[-1]
		var neighbors: Array[Vector2i] = []
		for d_vec in [Vector2i(0, -2), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(2, 0)]:
			var n: Vector2i = cur + d_vec
			if n.x > 0 and n.x < width - 1 and n.y > 0 and n.y < height - 1:
				if str(tiles.get(_key(n.x, n.y), {}).get("type", TILE_WALL)) == TILE_WALL:
					neighbors.append(n)
		if neighbors.size() > 0:
			var chosen := neighbors[rng.randi() % neighbors.size()]
			var mid := (cur + chosen) / 2
			tiles[_key(mid.x, mid.y)] = {"type": TILE_FLOOR, "cleared": true}
			tiles[_key(chosen.x, chosen.y)] = {"type": TILE_FLOOR, "cleared": true}
			# 25% chance: carve a wider corridor (2 cells wide perpendicular to direction)
			if rng.randf() < 0.25:
				var perp: Vector2i = Vector2i(abs(chosen.y - cur.y) / 2, abs(chosen.x - cur.x) / 2)
				for offset in [-1, 1]:
					var wpx: int = chosen.x + perp.x * offset
					var wpy: int = chosen.y + perp.y * offset
					if wpx > 0 and wpx < width - 1 and wpy > 0 and wpy < height - 1:
						if str(tiles.get(_key(wpx, wpy), {}).get("type", TILE_WALL)) == TILE_WALL:
							tiles[_key(wpx, wpy)] = {"type": TILE_FLOOR, "cleared": true}
					# Also widen the mid cell's perpendicular
					wpx = mid.x + perp.x * offset
					wpy = mid.y + perp.y * offset
					if wpx > 0 and wpx < width - 1 and wpy > 0 and wpy < height - 1:
						if str(tiles.get(_key(wpx, wpy), {}).get("type", TILE_WALL)) == TILE_WALL:
							tiles[_key(wpx, wpy)] = {"type": TILE_FLOOR, "cleared": true}
			# 10% chance: carve a 3×3 dead-end chamber at the new cell
			if rng.randf() < 0.10:
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var cx := chosen.x + dx
						var cy := chosen.y + dy
						if cx > 0 and cx < width - 1 and cy > 0 and cy < height - 1:
							if str(tiles.get(_key(cx, cy), {}).get("type", TILE_WALL)) == TILE_WALL:
								tiles[_key(cx, cy)] = {"type": TILE_FLOOR, "cleared": true}
			stack.append(chosen)
		else:
			stack.pop_back()


## Noise-based terrain for large rifts (width >= 128).
## Carves open wasteland with maze pockets.
static func _generate_noise_terrain(tiles: Dictionary, width: int, height: int, seed_val: int, maze_density: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val + 999

	var noise := FastNoiseLite.new()
	noise.seed = seed_val + 100
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.04
	noise.fractal_octaves = 4

	for y in range(height):
		for x in range(width):
			# FastNoiseLite returns [-1, 1], remap to [0, 1] for natural-looking caves
			var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var threshold := maze_density * 0.5 + 0.15
			if x <= 1 or y <= 1 or x >= width - 2 or y >= height - 2:
				tiles[_key(x, y)] = {"type": TILE_WALL, "cleared": true}
			elif n > threshold:
				tiles[_key(x, y)] = {"type": TILE_WALL, "cleared": true}
			else:
				var deco := rng.randf() < 0.1
				tiles[_key(x, y)] = {"type": TILE_DECOR if deco else TILE_FLOOR, "cleared": true}

	# Carve a few explicit rooms for variety before connectivity pass
	_carve_rooms(tiles, width, height, seed_val + 200)
	_ensure_connectivity(tiles, width, height)


## Carve a handful of rectangular rooms into noise terrain for variety.
static func _carve_rooms(tiles: Dictionary, width: int, height: int, seed_val: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var room_count := clampi(int(sqrt(float(width * height)) * 0.003), 2, 8)
	for _i in room_count:
		var rw := 3 + rng.randi() % 4
		var rh := 3 + rng.randi() % 4
		var rx := 3 + rng.randi() % maxi(1, width - rw - 4)
		var ry := 3 + rng.randi() % maxi(1, height - rh - 4)
		for dy in range(-1, rh + 1):
			for dx in range(-1, rw + 1):
				var cx := rx + dx
				var cy := ry + dy
				if cx < 0 or cx >= width or cy < 0 or cy >= height:
					continue
				var k := _key(cx, cy)
				var cur := str(tiles.get(k, {}).get("type", TILE_WALL))
				if cur == TILE_WALL:
					tiles[k] = {"type": TILE_FLOOR, "cleared": true}


## Carve corridors to connect regions in noise terrain.
static func _ensure_connectivity(tiles: Dictionary, width: int, height: int) -> void:
	var regions: Array[Dictionary] = []
	var visited: Dictionary = {}
	for y in range(1, height - 1, 2):
		for x in range(1, width - 1, 2):
			var key := _key(x, y)
			if visited.has(key):
				continue
			if str(tiles.get(key, {}).get("type", TILE_WALL)) == TILE_WALL:
				continue
			var region := _flood_fill(tiles, width, height, x, y, visited)
			if region.size() > 0:
				regions.append({"cells": region, "center": region[region.size() / 2]})

	for i in range(1, regions.size()):
		var a := regions[i - 1]
		var b := regions[i]
		_carve_tunnel(tiles, a["center"], b["center"])


static func _flood_fill(tiles: Dictionary, width: int, height: int, sx: int, sy: int, visited: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var stack: Array[Vector2i] = [Vector2i(sx, sy)]
	while stack.size() > 0:
		var c: Vector2i = stack.pop_back()
		var k := _key(c.x, c.y)
		if visited.has(k):
			continue
		if str(tiles.get(k, {}).get("type", TILE_WALL)) == TILE_WALL:
			continue
		if c.x < 0 or c.y < 0 or c.x >= width or c.y >= height:
			continue
		visited[k] = true
		cells.append(c)
		for d_vec in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			stack.append(c + d_vec)
	return cells


static func _carve_tunnel(tiles: Dictionary, a: Vector2i, b: Vector2i) -> void:
	var x := a.x
	var y := a.y
	while x != b.x:
		var k := _key(x, y)
		var cur := str(tiles.get(k, {}).get("type", TILE_WALL))
		if cur == TILE_WALL:
			tiles[k] = {"type": TILE_FLOOR, "cleared": true}
		x += 1 if b.x > x else -1
	while y != b.y:
		var k := _key(x, y)
		var cur := str(tiles.get(k, {}).get("type", TILE_WALL))
		if cur == TILE_WALL:
			tiles[k] = {"type": TILE_FLOOR, "cleared": true}
		y += 1 if b.y > y else -1


static func _place_entrance(tiles: Dictionary, width: int, height: int) -> void:
	var ex := 1
	var ey := 1
	tiles[_key(ex, ey)] = {"type": TILE_ENTRANCE, "cleared": true}
	tiles[_key(ex + 1, ey)] = {"type": TILE_FLOOR, "cleared": true}
	tiles[_key(ex, ey + 1)] = {"type": TILE_FLOOR, "cleared": true}
	## Carve a short path from entrance toward center
	for i in range(2, 5):
		tiles[_key(i, 1)] = {"type": TILE_FLOOR, "cleared": true}
		tiles[_key(1, i)] = {"type": TILE_FLOOR, "cleared": true}


static func _place_boss_and_core(tiles: Dictionary, width: int, height: int) -> Vector2i:
	var bx := width - 2
	var by := height - 2

	for _attempt in 100:
		var tx := 1 + randi() % maxi(1, width - 2)
		var ty := 1 + randi() % maxi(1, height - 2)
		var cur := str(tiles.get(_key(tx, ty), {}).get("type", TILE_WALL))
		if cur == TILE_WALL:
			continue
		if tx < width / 3 or ty < height / 3:
			continue
		if abs(tx - 1) + abs(ty - 1) < maxi(width, height) / 3:
			continue
		bx = tx
		by = ty
		break

	tiles[_key(bx, by)] = {"type": TILE_BOSS, "cleared": false}

	var core_placed := false
	for d_vec in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var cx: int = bx + d_vec.x
		var cy: int = by + d_vec.y
		if cx >= 0 and cx < width and cy >= 0 and cy < height:
			var cur := str(tiles.get(_key(cx, cy), {}).get("type", TILE_WALL))
			if cur != TILE_BOSS:
				tiles[_key(cx, cy)] = {"type": TILE_CORE, "cleared": false, "locked": true}
				core_placed = true
				break
	if not core_placed:
		tiles[_key(bx, by - 1)] = {"type": TILE_CORE, "cleared": false, "locked": true}

	return Vector2i(bx, by)


static func _scatter_encounters(tiles: Dictionary, width: int, height: int, boss_pos: Vector2i) -> void:
	var total := clampi(int(sqrt(float(width * height)) * 0.06), 2, 40)
	var placed := 0
	var tries := 0
	var entrance := Vector2i(1, 1)
	while placed < total and tries < total * 15:
		tries += 1
		var x := 1 + randi() % maxi(1, width - 2)
		var y := 1 + randi() % maxi(1, height - 2)
		var key := _key(x, y)
		var cell_data: Dictionary = tiles.get(key, {})
		var t := str(cell_data.get("type", TILE_WALL))
		if t != TILE_FLOOR and t != TILE_DECOR:
			continue
		var cell := Vector2i(x, y)
		if cell.distance_to(entrance) < 4.0:
			continue
		if cell.distance_to(boss_pos) < 3.0:
			continue
		tiles[key] = {"type": TILE_ENCOUNTER, "cleared": false}
		placed += 1


static func tile_at(dungeon: Dictionary, x: int, y: int) -> Dictionary:
	var tiles: Dictionary = dungeon.get("tiles", {})
	return (tiles.get(_key(x, y), {"type": TILE_WALL}) as Dictionary).duplicate(true)


static func is_walkable(dungeon: Dictionary, x: int, y: int) -> bool:
	var t: String = str(tile_at(dungeon, x, y).get("type", TILE_WALL))
	return t != TILE_WALL


static func mark_encounter_cleared(dungeon: Dictionary, x: int, y: int) -> Dictionary:
	var d: Dictionary = dungeon.duplicate(true)
	var tiles: Dictionary = d.get("tiles", {}).duplicate(true)
	var key := _key(x, y)
	if tiles.has(key):
		var cell: Dictionary = tiles[key].duplicate(true)
		cell["cleared"] = true
		cell["type"] = TILE_FLOOR
		tiles[key] = cell
	d["tiles"] = tiles
	return d


static func mark_boss_defeated(dungeon: Dictionary) -> Dictionary:
	var d: Dictionary = dungeon.duplicate(true)
	d["boss_defeated"] = true
	var tiles: Dictionary = d.get("tiles", {}).duplicate(true)
	var core := d.get("core_pos", {}) as Dictionary
	var ck := _key(int(core.get("x", 0)), int(core.get("y", 0)))
	if tiles.has(ck):
		var cell: Dictionary = tiles[ck].duplicate(true)
		cell["locked"] = false
		tiles[ck] = cell
	var boss := d.get("boss_pos", {}) as Dictionary
	var bk := _key(int(boss.get("x", 0)), int(boss.get("y", 0)))
	if tiles.has(bk):
		var bcell: Dictionary = tiles[bk].duplicate(true)
		bcell["cleared"] = true
		bcell["type"] = TILE_FLOOR
		tiles[bk] = bcell
	d["tiles"] = tiles
	return d


static func _find_core(tiles: Dictionary) -> Dictionary:
	for key_str in tiles:
		var t: String = str(tiles[key_str].get("type", ""))
		if t == TILE_CORE:
			var parts: PackedStringArray = String(key_str).split(",")
			if parts.size() == 2:
				return {"x": int(parts[0]), "y": int(parts[1])}
	return {"x": -1, "y": -1}


static func _key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]
