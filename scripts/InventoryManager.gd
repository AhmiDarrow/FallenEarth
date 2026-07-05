## InventoryManager — Player inventory singleton (autoload).
##
## Phase 1 minimal implementation. Tracks the player's stack-based inventory,
## supports add/remove/has/count queries, and provides item metadata
## lookups against data/items.json.
##
## Capacity defaults to 30 slots. Stackable items stack up to their
## `max_stack`; non-stackable items take 1 slot each.
##
## Signals:
##   inventory_changed() — anything in the inventory changed
##   item_added(item_id, qty) — for popup / log feedback
##   item_full(item_id) — when an add was rejected for capacity reasons
##
## The manager does NOT persist to disk; GameState.SaveManager is the
## canonical persistence layer (it will read this manager's `inventory`
## dict at save time in a later phase). For Phase 1 the inventory
## resets when the game is closed; that is acceptable.
extends Node

const ITEMS_PATH := "res://data/items.json"

const DEFAULT_CAPACITY := 30

signal inventory_changed()
signal item_added(item_id: String, qty: int)
signal item_full(item_id: String)

var capacity: int = DEFAULT_CAPACITY

# inventory: Array of slot entries.
#   stackable: {item_id: qty} merged per-item across slots
#   non-stackable: one slot per item
# We model the inventory as a list of slots; each slot is either a stack
# (Dictionary {item_id, qty, max_stack}) or null. Slots are kept compact
# (no leading nulls).
var _slots: Array = []

# Cached item metadata: {item_id: {name, stackable, max_stack, ...}}
var _items: Dictionary = {}


func _ready() -> void:
	_load_items()
	print("[InventoryManager] Initialized (capacity %d, %d items registered)." % [capacity, _items.size()])


func _load_items() -> void:
	if not ResourceLoader.exists(ITEMS_PATH):
		push_error("[InventoryManager] %s not found" % ITEMS_PATH)
		return
	var raw = load(ITEMS_PATH)
	if raw == null:
		return
	var data: Dictionary = {}
	if raw is Dictionary:
		data = raw
	elif "data" in raw:
		var d = raw.data
		if d is Dictionary:
			data = d
	if data.is_empty():
		push_error("[InventoryManager] %s did not parse as Dictionary" % ITEMS_PATH)
		return
	for item in data.get("items", []):
		if item is Dictionary:
			_items[str(item.get("id", ""))] = item


# ---------------------------------------------------------------------------
# Item metadata
# ---------------------------------------------------------------------------

func has_item_meta(item_id: String) -> bool:
	return _items.has(item_id)


func get_item_meta(item_id: String) -> Dictionary:
	return _items.get(item_id, {})


func get_item_name(item_id: String) -> String:
	return str(_items.get(item_id, {}).get("name", item_id))


# ---------------------------------------------------------------------------
# Inventory ops
# ---------------------------------------------------------------------------

func get_count(item_id: String) -> int:
	var total := 0
	for slot in _slots:
		if slot == null:
			continue
		if str(slot.get("item_id", "")) == item_id:
			total += int(slot.get("qty", 0))
	return total


func has_item(item_id: String, qty: int = 1) -> bool:
	return get_count(item_id) >= qty


## Add qty of an item. Stacks with existing slots if stackable; otherwise
## takes a new slot. Returns the qty actually added (0 if full / no room).
func add_item(item_id: String, qty: int) -> int:
	if qty <= 0 or item_id.is_empty():
		return 0
	var meta: Dictionary = get_item_meta(item_id)
	var stackable: bool = bool(meta.get("stackable", false))
	var max_stack: int = int(meta.get("max_stack", 1))
	var remaining := qty
	var actually_added := 0

	if stackable and max_stack > 1:
		# Fill existing stacks first
		for i in _slots.size():
			if remaining <= 0:
				break
			var slot: Dictionary = _slots[i]
			if str(slot.get("item_id", "")) != item_id:
				continue
			var have: int = int(slot.get("qty", 0))
			if have >= max_stack:
				continue
			var can_add: int = mini(max_stack - have, remaining)
			slot["qty"] = have + can_add
			remaining -= can_add
			actually_added += can_add

		# Open a new stack if room and items left
		while remaining > 0 and _slots.size() < capacity:
			var take: int = mini(max_stack, remaining)
			_slots.append({
				"item_id": item_id,
				"qty": take,
				"max_stack": max_stack,
			})
			remaining -= take
			actually_added += take

	elif not stackable:
		# Each unit takes its own slot
		while remaining > 0 and _slots.size() < capacity:
			_slots.append({
				"item_id": item_id,
				"qty": 1,
				"max_stack": 1,
			})
			remaining -= 1
			actually_added += 1
	else:
		# Fallback: treat as stack of 1s
		while remaining > 0 and _slots.size() < capacity:
			_slots.append({
				"item_id": item_id,
				"qty": 1,
				"max_stack": 1,
			})
			remaining -= 1
			actually_added += 1

	if actually_added > 0:
		emit_signal("item_added", item_id, actually_added)
		emit_signal("inventory_changed")
	if remaining > 0 and actually_added == 0:
		emit_signal("item_full", item_id)
	return actually_added


## Remove qty of an item. Returns true if the full qty was removed.
func remove_item(item_id: String, qty: int) -> bool:
	if qty <= 0:
		return true
	if get_count(item_id) < qty:
		return false
	var remaining := qty
	# Walk from the end so we shrink stacks cleanly
	for i in range(_slots.size() - 1, -1, -1):
		if remaining <= 0:
			break
		var slot: Dictionary = _slots[i]
		if str(slot.get("item_id", "")) != item_id:
			continue
		var have: int = int(slot.get("qty", 0))
		var take: int = mini(have, remaining)
		slot["qty"] = have - take
		remaining -= take
		if int(slot.get("qty", 0)) <= 0:
			_slots.remove_at(i)
	emit_signal("inventory_changed")
	return true


func get_inventory_snapshot() -> Array:
	# Returns a deep copy of the slots for save/load or UI display.
	var snap: Array = []
	for slot in _slots:
		if slot == null:
			continue
		snap.append(slot.duplicate(true))
	return snap


func restore_from_snapshot(snap: Array) -> void:
	_slots.clear()
	for s in snap:
		_slots.append((s as Dictionary).duplicate(true))
	emit_signal("inventory_changed")


## Returns the current inventory as a serializable array (used by
## SaveManager.aggregate_snapshot in Phase 8).
func get_snapshot() -> Dictionary:
	return {"slots": get_inventory_snapshot()}


func get_used_slots() -> int:
	return _slots.size()


func get_free_slots() -> int:
	return capacity - _slots.size()
