## RiftDungeonGenerator — Procedural explorable rift dungeon with rooms, encounters, boss, core.
class_name RiftDungeonGenerator
extends RefCounted

const TILE_WALL := "wall"
const TILE_FLOOR := "floor"
const TILE_ENCOUNTER := "encounter"
const TILE_BOSS := "boss"
const TILE_CORE := "core"
const TILE_ENTRANCE := "entrance"

const DEFAULT_W := 15
const DEFAULT_H := 11
const ROOM_COUNT := 5


static func generate(rift_id: String, biome_key: String) -> Dictionary:
	var seed_val: int = abs((rift_id + biome_key).hash())
	seed(seed_val)

	var width: int = DEFAULT_W
	var height: int = DEFAULT_H
	var tiles: Dictionary = {}

	for y in range(height):
		for x in range(width):
			tiles[_key(x, y)] = {"type": TILE_WALL, "cleared": false}

	var rooms: Array[Dictionary] = _place_rooms(width, height, ROOM_COUNT)
	for i in range(rooms.size()):
		_carve_room(tiles, rooms[i])

	for i in range(rooms.size() - 1):
		_connect_rooms(tiles, rooms[i], rooms[i + 1])

	var entrance_room: Dictionary = rooms[0]
	var boss_room: Dictionary = rooms[rooms.size() - 1]
	var entrance: Vector2i = Vector2i(
		int(entrance_room["cx"]),
		int(entrance_room["y1"]) + int(entrance_room["h"]) - 2
	)
	tiles[_key(entrance.x, entrance.y)] = {"type": TILE_ENTRANCE, "cleared": true}

	var boss_pos: Vector2i = Vector2i(int(boss_room["cx"]), int(boss_room["cy"]))
	tiles[_key(boss_pos.x, boss_pos.y)] = {"type": TILE_BOSS, "cleared": false}

	var core_pos: Vector2i = Vector2i(int(boss_room["cx"]), int(boss_room["y1"]) + 1)
	tiles[_key(core_pos.x, core_pos.y)] = {"type": TILE_CORE, "cleared": false, "locked": true}

	for i in range(1, rooms.size() - 1):
		_scatter_encounters(tiles, rooms[i], 1 + randi() % 2)

	return {
		"width": width,
		"height": height,
		"tiles": tiles,
		"player_pos": {"x": entrance.x, "y": entrance.y},
		"entrance": {"x": entrance.x, "y": entrance.y},
		"boss_pos": {"x": boss_pos.x, "y": boss_pos.y},
		"core_pos": {"x": core_pos.x, "y": core_pos.y},
		"boss_defeated": false,
		"rift_cleared": false,
		"seed": seed_val,
		"room_count": rooms.size(),
	}


static func tile_at(dungeon: Dictionary, x: int, y: int) -> Dictionary:
	var tiles: Dictionary = dungeon.get("tiles", {}) as Dictionary
	return (tiles.get(_key(x, y), {"type": TILE_WALL}) as Dictionary).duplicate(true)


static func is_walkable(dungeon: Dictionary, x: int, y: int) -> bool:
	var t: String = str(tile_at(dungeon, x, y).get("type", TILE_WALL))
	return t != TILE_WALL


static func mark_encounter_cleared(dungeon: Dictionary, x: int, y: int) -> Dictionary:
	var d: Dictionary = dungeon.duplicate(true)
	var tiles: Dictionary = (d.get("tiles", {}) as Dictionary).duplicate(true)
	var key: String = _key(x, y)
	if tiles.has(key):
		var cell: Dictionary = (tiles[key] as Dictionary).duplicate(true)
		cell["cleared"] = true
		cell["type"] = TILE_FLOOR
		tiles[key] = cell
	d["tiles"] = tiles
	return d


static func mark_boss_defeated(dungeon: Dictionary) -> Dictionary:
	var d: Dictionary = dungeon.duplicate(true)
	d["boss_defeated"] = true
	var tiles: Dictionary = (d.get("tiles", {}) as Dictionary).duplicate(true)
	var core: Dictionary = d.get("core_pos", {}) as Dictionary
	var ck: String = _key(int(core.get("x", 0)), int(core.get("y", 0)))
	if tiles.has(ck):
		var cell: Dictionary = (tiles[ck] as Dictionary).duplicate(true)
		cell["locked"] = false
		tiles[ck] = cell
	var bk: String = _key(int((d.get("boss_pos", {}) as Dictionary).get("x", 0)), int((d.get("boss_pos", {}) as Dictionary).get("y", 0)))
	if tiles.has(bk):
		var bcell: Dictionary = (tiles[bk] as Dictionary).duplicate(true)
		bcell["cleared"] = true
		bcell["type"] = TILE_FLOOR
		tiles[bk] = bcell
	d["tiles"] = tiles
	return d


static func _place_rooms(width: int, height: int, count: int) -> Array[Dictionary]:
	var rooms: Array[Dictionary] = []
	var attempts: int = 0
	while rooms.size() < count and attempts < 80:
		attempts += 1
		var rw: int = randi_range(3, 5)
		var rh: int = randi_range(3, 4)
		var x1: int = randi_range(1, width - rw - 2)
		var y1: int = randi_range(1, height - rh - 2)
		var candidate := {
			"x1": x1, "y1": y1, "w": rw, "h": rh,
			"x2": x1 + rw - 1, "y2": y1 + rh - 1,
			"cx": x1 + int(rw / 2.0), "cy": y1 + int(rh / 2.0),
		}
		var overlap: bool = false
		for r in rooms:
			if _rooms_overlap(candidate, r):
				overlap = true
				break
		if not overlap:
			rooms.append(candidate)
	return rooms


static func _rooms_overlap(a: Dictionary, b: Dictionary) -> bool:
	return not (int(a["x2"]) < int(b["x1"]) - 1 or int(a["x1"]) > int(b["x2"]) + 1
		or int(a["y2"]) < int(b["y1"]) - 1 or int(a["y1"]) > int(b["y2"]) + 1)


static func _carve_room(tiles: Dictionary, room: Dictionary) -> void:
	for y in range(int(room["y1"]), int(room["y2"]) + 1):
		for x in range(int(room["x1"]), int(room["x2"]) + 1):
			tiles[_key(x, y)] = {"type": TILE_FLOOR, "cleared": true}


static func _connect_rooms(tiles: Dictionary, a: Dictionary, b: Dictionary) -> void:
	var ax: int = int(a["cx"])
	var ay: int = int(a["cy"])
	var bx: int = int(b["cx"])
	var by: int = int(b["cy"])
	var x: int = ax
	while x != bx:
		tiles[_key(x, ay)] = {"type": TILE_FLOOR, "cleared": true}
		x += 1 if bx > x else -1
	var y: int = ay
	while y != by:
		tiles[_key(bx, y)] = {"type": TILE_FLOOR, "cleared": true}
		y += 1 if by > y else -1
	tiles[_key(bx, by)] = {"type": TILE_FLOOR, "cleared": true}


static func _scatter_encounters(tiles: Dictionary, room: Dictionary, count: int) -> void:
	var placed: int = 0
	var tries: int = 0
	while placed < count and tries < 30:
		tries += 1
		var x: int = randi_range(int(room["x1"]) + 1, int(room["x2"]) - 1)
		var y: int = randi_range(int(room["y1"]) + 1, int(room["y2"]) - 1)
		var key: String = _key(x, y)
		var cell: Dictionary = tiles.get(key, {}) as Dictionary
		if str(cell.get("type", "")) == TILE_FLOOR:
			tiles[key] = {"type": TILE_ENCOUNTER, "cleared": false}
			placed += 1


static func _key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]