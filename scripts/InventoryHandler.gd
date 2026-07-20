## InventoryHandler — Autoload singleton. Manages grid inventory, item
## registry, and all inventory operations. No item duplication guaranteed.
## Grid: 2D array — grid[y][x] = {"id": "item_id", "count": N} or null.
extends Node

const GRID_W := 10
const GRID_H := 3

signal inventory_changed()

var main_grid: Array  # Array of Array of Dictionary (null means empty)
var _items: Dictionary = {}  # item_id -> metadata dict

var current_weight: float = 0.0
var max_weight: float = 50.0

var _count_cache: Dictionary = {}


func _ready() -> void:
	_load_items()
	_init_grid()
	_rebuild_count_cache()


# ---------------------------------------------------------------------------
# Item registry
# ---------------------------------------------------------------------------

func _load_items() -> void:
	var dr := get_node_or_null("/root/DataRegistry")
	if dr == null:
		push_error("[InventoryHandler] DataRegistry not available")
		return
	# 1. Items registry (canonical items: materials, consumables, ores, etc.)
	var data: Variant = dr.get_data("items")
	if data == null or not (data is Dictionary):
		push_error("[InventoryHandler] items.json missing or invalid")
	else:
		for item in data.get("items", []):
			if item is Dictionary:
				var item_id: String = str(item.get("id", ""))
				_items[item_id] = item
	# 2. Tools registry (axe_stone, pickaxe_stone, ...). Tools are stored in
	# the same _items dict so they can be stacked in inventory cells and
	# the Hotbar can resolve them by id (Hotbar.set_slot(i, "axe_stone")
	# was failing before this fix because InventoryHandler didn't know
	# about axe_stone). The `icon` field is synthesised from the sprite
	# field — see _synthesize_tool_item().
	var tools_data: Variant = dr.get_data("tools")
	if tools_data == null or not (tools_data is Dictionary):
		push_warning("[InventoryHandler] tools.json missing or invalid — Hotbar will skip tool slots")
	else:
		for tool in tools_data.get("tools", []):
			if tool is Dictionary:
				var tool_id: String = str(tool.get("id", ""))
				if not tool_id.is_empty():
					_items[tool_id] = _synthesize_tool_item(tool)


## Convert a tools.json entry into an InventoryHandler-compatible item
## dict. The Hotbar reads from main_grid's first row, so any tool that's
## treasure-pileable needs a stable item_id entry here. We synthesise
## `category = "tool"`, `icon = "item_<sprite_id_without_tool_prefix>"`,
## and stackable=false (tools are unique per character).
func _synthesize_tool_item(tool: Dictionary) -> Dictionary:
	var tool_id: String = str(tool.get("id", ""))
	var sprite: String = str(tool.get("sprite", ""))
	var out: Dictionary = {
		"id": tool_id,
		"name": str(tool.get("name", tool_id)),
		"category": "tool",
		"stackable": false,
		"max_stack": 1,
		"sell_value_ec": int(tool.get("sell_value_ec", 0)),
		"weight": 1.0,
		"icon": "item_" + sprite.replace("tool_", ""),
		"description": "%s (T%d — level %d req). Harvests: %s" % [
			str(tool.get("name", tool_id)),
			int(tool.get("tier", 0)),
			int(tool.get("level_required", 1)),
			str(tool.get("harvests", [])),
		],
		"type": str(tool.get("type", "axe_or_pick")),
		"speed_mult": float(tool.get("speed_mult", 1.0)),
		"harvests": tool.get("harvests", []),
	}
	return out


func get_item_data(item_id: String) -> Dictionary:
	return _items.get(item_id, {})

func get_item_name(item_id: String) -> String:
	return str(_items.get(item_id, {}).get("name", item_id))

func has_item_meta(item_id: String) -> bool:
	return _items.has(item_id)


# ---------------------------------------------------------------------------
# Grid management
# ---------------------------------------------------------------------------

func _init_grid() -> void:
	main_grid = []
	for y in GRID_H:
		var row: Array = []
		row.resize(GRID_W)
		main_grid.append(row)


func get_slot(x: int, y: int) -> Dictionary:
	if x < 0 or x >= GRID_W or y < 0 or y >= GRID_H:
		return {}
	var cell = main_grid[y][x]
	if cell == null:
		return {}
	return cell as Dictionary


func set_slot(x: int, y: int, item_id: String, count: int) -> void:
	if x < 0 or x >= GRID_W or y < 0 or y >= GRID_H:
		return
	if item_id == "" or count <= 0:
		main_grid[y][x] = null
	else:
		main_grid[y][x] = {"id": item_id, "count": count}


func is_empty(x: int, y: int) -> bool:
	return get_slot(x, y).is_empty()


# ---------------------------------------------------------------------------
# Core operations — no duplication
# ---------------------------------------------------------------------------

## Add items to the grid. Returns quantity actually added (0 = full/fail).
func add_item(item_id: String, qty: int) -> int:
	if qty <= 0 or item_id == "":
		return 0
	if not _items.has(item_id):
		push_warning("[InventoryHandler] Unknown item: %s" % item_id)
		return 0

	var max_stack: int = _items[item_id].get("max_stack", 99)
	var remaining: int = qty

	# 1. Stack onto existing stacks
	for y in GRID_H:
		for x in GRID_W:
			if remaining <= 0:
				break
			var cell = main_grid[y][x]
			if cell == null or cell.get("id") != item_id:
				continue
			var stack_count: int = cell.get("count", 0)
			var space: int = max_stack - stack_count
			if space <= 0:
				continue
			var add: int = mini(remaining, space)
			cell["count"] = stack_count + add
			remaining -= add
		if remaining <= 0:
			break

	# 2. Fill empty slots
	for y in GRID_H:
		for x in GRID_W:
			if remaining <= 0:
				break
			if main_grid[y][x] != null:
				continue
			var add: int = mini(remaining, max_stack)
			main_grid[y][x] = {"id": item_id, "count": add}
			remaining -= add
		if remaining <= 0:
			break

	if remaining < qty:
		_recalc_weight()
		_rebuild_count_cache()
		inventory_changed.emit()
	return qty - remaining


## Remove items from grid. Returns true if all qty was removed.
func remove_item(item_id: String, qty: int) -> bool:
	if qty <= 0:
		return true
	if get_count(item_id) < qty:
		return false
	var remaining: int = qty
	for y in GRID_H:
		for x in GRID_W:
			if remaining <= 0:
				break
			var cell = main_grid[y][x]
			if cell == null or cell.get("id") != item_id:
				continue
			var stack_count: int = cell.get("count", 0)
			var take: int = mini(remaining, stack_count)
			cell["count"] = stack_count - take
			remaining -= take
			if cell["count"] <= 0:
				main_grid[y][x] = null
		if remaining <= 0:
			break
	_recalc_weight()
	_rebuild_count_cache()
	inventory_changed.emit()
	return true


## Move a quantity from (sx, sy) to (dx, dy) within main_grid.
## If target has a different item, swaps them. Returns true on success.
func move_item(sx: int, sy: int, dx: int, dy: int) -> bool:
	var src := get_slot(sx, sy)
	if src.is_empty():
		return false
	var dst := get_slot(dx, dy)

	if dst.is_empty():
		# Simple move
		main_grid[dy][dx] = src
		main_grid[sy][sx] = null
	else:
		# Swap
		main_grid[sy][sx] = dst
		main_grid[dy][dx] = src

	_recalc_weight()
	_rebuild_count_cache()
	inventory_changed.emit()
	return true


## Split a stack: take half from (x, y) and place at (dx, dy).
func split_stack(x: int, y: int, dx: int, dy: int) -> bool:
	var src := get_slot(x, y)
	if src.is_empty():
		return false
	var count: int = src.get("count", 0)
	if count < 2:
		return false
	var half: int = count / 2
	src["count"] = count - half
	main_grid[y][x] = src
	main_grid[dy][dx] = {"id": src["id"], "count": half}
	_recalc_weight()
	_rebuild_count_cache()
	inventory_changed.emit()
	return true


## Transfer a single item from (sx, sy) to another grid array.
## Used by loot/crafting. Returns true on success.
func transfer_to(target_grid: Array, tx: int, ty: int, sx: int, sy: int, target_w: int, target_h: int) -> bool:
	var src := get_slot(sx, sy)
	if src.is_empty():
		return false
	if tx < 0 or tx >= target_w or ty < 0 or ty >= target_h:
		return false
	if target_grid[ty][tx] != null:
		return false
	target_grid[ty][tx] = {"id": src["id"], "count": src["count"]}
	main_grid[sy][sx] = null
	_recalc_weight()
	_rebuild_count_cache()
	inventory_changed.emit()
	return true


## Transfer from another grid into main_grid.
func transfer_from(other: Array, ox: int, oy: int, tx: int, ty: int, other_w: int, other_h: int) -> bool:
	if ox < 0 or ox >= other_w or oy < 0 or oy >= other_h:
		return false
	var cell = other[oy][ox]
	if cell == null:
		return false
	var slot := cell as Dictionary
	if slot.is_empty():
		return false
	if not is_empty(tx, ty):
		return false
	main_grid[ty][tx] = {"id": slot["id"], "count": slot["count"]}
	other[oy][ox] = null
	_recalc_weight()
	_rebuild_count_cache()
	inventory_changed.emit()
	return true


## Take all items from a source grid into main (loot-all / collect-crafting).
func collect_from(other: Array, other_w: int, other_h: int) -> int:
	var moved := 0
	for y in other_h:
		for x in other_w:
			var cell = other[y][x]
			if cell == null:
				continue
			var slot := cell as Dictionary
			if slot.is_empty():
				continue
			var added: int = add_item(slot.get("id", ""), slot.get("count", 0))
			if added > 0:
				other[y][x] = null
				moved += added
	return moved


# ---------------------------------------------------------------------------
# Query
# ---------------------------------------------------------------------------

func get_count(item_id: String) -> int:
	return _count_cache.get(item_id, 0)

func has_item(item_id: String, qty: int = 1) -> bool:
	return get_count(item_id) >= qty

func get_used_slots() -> int:
	var count := 0
	for y in GRID_H:
		for x in GRID_W:
			if main_grid[y][x] != null:
				count += 1
	return count

func get_free_slots() -> int:
	return GRID_W * GRID_H - get_used_slots()

func get_grid_snapshot() -> Array:
	var snap: Array = []
	for y in GRID_H:
		for x in GRID_W:
			var cell = main_grid[y][x]
			if cell == null:
				snap.append({})
			else:
				snap.append({"id": cell.get("id", ""), "count": cell.get("count", 0)})
	return snap


# ---------------------------------------------------------------------------
# Hotbar — first row (y=0)
# ---------------------------------------------------------------------------

func get_hotbar_item(slot: int) -> Dictionary:
	return get_slot(slot, 0)


# ---------------------------------------------------------------------------
# Weight
# ---------------------------------------------------------------------------

func _recalc_weight() -> void:
	var total: float = 0.0
	for y in GRID_H:
		for x in GRID_W:
			var cell = main_grid[y][x]
			if cell == null:
				continue
			var w: float = float(_items.get(cell.get("id", ""), {}).get("weight", 0.1))
			total += w * cell.get("count", 0)
	current_weight = total

func _rebuild_count_cache() -> void:
	_count_cache.clear()
	for y in GRID_H:
		for x in GRID_W:
			var cell = main_grid[y][x]
			if cell == null:
				continue
			var item_id: String = cell.get("id", "")
			if item_id != "":
				_count_cache[item_id] = _count_cache.get(item_id, 0) + cell.get("count", 0)


# ---------------------------------------------------------------------------
# Snapshot for save/load
# ---------------------------------------------------------------------------

func get_snapshot() -> Dictionary:
	return {"grid": get_grid_snapshot(), "weight": current_weight}

func restore(snap: Dictionary) -> void:
	restore_from_snapshot(snap)

func restore_from_snapshot(snap: Variant) -> void:
	if snap is Array:
		_slots_from_array(snap)
	elif snap is Dictionary:
		if snap.has("grid"):
			_slots_from_array(snap["grid"] as Array)
		if snap.has("weight"):
			current_weight = float(snap["weight"])
	else:
		push_error("[InventoryHandler] restore_from_snapshot: unexpected type %s" % typeof(snap))


func _slots_from_array(arr: Array) -> void:
	_init_grid()
	var idx := 0
	for y in GRID_H:
		for x in GRID_W:
			if idx < arr.size():
				var entry: Dictionary = arr[idx]
				var item_id: String = str(entry.get("id", ""))
				var qty: int = int(entry.get("count", 0))
				if item_id != "" and qty > 0:
					main_grid[y][x] = {"id": item_id, "count": qty}
			idx += 1
	_recalc_weight()
	_rebuild_count_cache()
	inventory_changed.emit()
