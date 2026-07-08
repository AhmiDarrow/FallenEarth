## InventoryManager — Player inventory singleton (autoload).
##
## Uses Wyvernbox GridInventory internally while maintaining backward
## compatibility for all existing callers (add_item(), remove_item(),
## get_count(), has_item(), get_snapshot(), etc.).
##
## Grid layout: 10 columns x 3 rows = 30 slots.
## Row 0 (y=0) is synced as the hotbar.
extends Node

const ITEMS_PATH := "res://data/items.json"
const GRID_WIDTH := 10
const GRID_HEIGHT := 3

signal inventory_changed()
signal item_added(item_id: String, qty: int)
signal item_full(item_id: String)

## Wyvernbox grid inventory for the player (10×3 = 30 cells).
var main_inventory: GridInventory
## Separate grid for an open loot container (chest / mob drop).
var loot_inventory: GridInventory
## Separate grid for crafting input.
var crafting_inventory: GridInventory

## Old-style flat capacity (backward compat).
var capacity: int = GRID_WIDTH * GRID_HEIGHT

# --- Backward-compat item registry ---
var _items: Dictionary = {}       # item_id -> metadata dict from items.json
var _item_type_map: Dictionary = {}  # item_id -> ItemType instance
var _item_id_map: Dictionary = {}    # ItemType instance -> item_id

# --- Weight / encumbrance ---
var current_weight: float = 0.0
var max_weight: float = 50.0


func _ready() -> void:
    _load_items()
    _init_inventories()
    print("[InventoryManager] Initialized with wyvernbox GridInventory (%dx%d, %d items registered)." % [GRID_WIDTH, GRID_HEIGHT, _items.size()])


# ---------------------------------------------------------------------------
# Internal setup
# ---------------------------------------------------------------------------

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
            var item_id: String = str(item.get("id", ""))
            _items[item_id] = item
            _make_item_type(item_id, item)


func _make_item_type(item_id: String, meta: Dictionary) -> void:
    var t := ItemType.new()
    t.name = meta.get("name", item_id)
    t.max_stack_count = meta.get("max_stack", 1)
    t.description = meta.get("description", "")
    t.slot_flags = ItemType.SlotFlags.SMALL
    # Store the item_id as metadata (reversible)
    t.set_meta("item_id", item_id)
    _item_type_map[item_id] = t
    _item_id_map[t] = item_id


func _init_inventories() -> void:
    main_inventory = GridInventory.new()
    main_inventory.width = GRID_WIDTH
    main_inventory.height = GRID_HEIGHT
    main_inventory.resource_name = "MainInventory"

    loot_inventory = GridInventory.new()
    loot_inventory.resource_name = "LootInventory"

    crafting_inventory = GridInventory.new()
    crafting_inventory.resource_name = "CraftingInventory"

    # Forward GridInventory signals to backward-compat signals
    main_inventory.item_stack_added.connect(_on_main_inv_mutated)
    main_inventory.item_stack_removed.connect(_on_main_inv_mutated)
    main_inventory.item_stack_changed.connect(_on_main_inv_mutated)


func _on_main_inv_mutated(_stack = null, _delta = 0) -> void:
    _recalc_weight()
    inventory_changed.emit()


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _get_item_id(stack: ItemStack) -> String:
    return _item_id_map.get(stack.item_type, "")


func _get_type(item_id: String) -> ItemType:
    return _item_type_map.get(item_id)


func _recalc_weight() -> void:
    var total: float = 0.0
    for s in main_inventory.items:
        var w: float = float(_items.get(_get_item_id(s), {}).get("weight", 0.1))
        total += w * s.count
    current_weight = total


# ---------------------------------------------------------------------------
# Backward-compatible item metadata API
# ---------------------------------------------------------------------------

func has_item_meta(item_id: String) -> bool:
    return _items.has(item_id)


func get_item_meta(item_id: String) -> Dictionary:
    return _items.get(item_id, {})


func get_item_name(item_id: String) -> String:
    return str(_items.get(item_id, {}).get("name", item_id))

# Backward-compatible method for callers expecting flat array[slot{id,qty}]
func get_inventory() -> Array:
    return get_inventory_snapshot()


# ---------------------------------------------------------------------------
# Backward-compatible inventory ops
# ---------------------------------------------------------------------------

func get_count(item_id: String) -> int:
    var total := 0
    for stack in main_inventory.items:
        if _get_item_id(stack) == item_id:
            total += stack.count
    return total


func has_item(item_id: String, qty: int = 1) -> bool:
    return get_count(item_id) >= qty


func add_item(item_id: String, qty: int) -> int:
    if qty <= 0 or item_id.is_empty():
        return 0
    var typ := _get_type(item_id)
    if typ == null:
        push_warning("[InventoryManager] Unknown item type: %s" % item_id)
        return 0

    var stack := ItemStack.new(typ, qty)
    var added := main_inventory.try_add_item(stack)
    if added > 0:
        item_added.emit(item_id, added)
    if qty > 0 and added == 0:
        item_full.emit(item_id)
    return added


func remove_item(item_id: String, qty: int) -> bool:
    if qty <= 0:
        return true
    if get_count(item_id) < qty:
        return false
    var remaining := qty
    for stack in main_inventory.items.duplicate():
        if remaining <= 0:
            break
        if _get_item_id(stack) != item_id:
            continue
        var take := mini(stack.count, remaining)
        remaining -= take
        main_inventory.add_items_to_stack(stack, -take)
    return true


func get_inventory_snapshot() -> Array:
    var snap: Array = []
    for stack in main_inventory.items:
        var item_id := _get_item_id(stack)
        if item_id == "": continue
        snap.append({
            "item_id": item_id,
            "qty": stack.count,
        })
    return snap


func restore_from_snapshot(snap: Array) -> void:
    main_inventory.clear()
    for s in snap:
        var item_id := str(s.get("item_id", ""))
        var qty := int(s.get("qty", 0))
        if item_id == "" or qty <= 0:
            continue
        var typ := _get_type(item_id)
        if typ == null:
            push_warning("[InventoryManager] Restore skipping unknown item: %s" % item_id)
            continue
        var stack := ItemStack.new(typ, qty)
        main_inventory.try_add_item(stack)
    _recalc_weight()
    inventory_changed.emit()


func get_snapshot() -> Dictionary:
    return {"slots": get_inventory_snapshot()}


func get_used_slots() -> int:
    return main_inventory.items.size()


func get_free_slots() -> int:
    return capacity - get_used_slots()


# ---------------------------------------------------------------------------
# Hotbar — first row (y=0, slots 0-9) of the grid inventory
# ---------------------------------------------------------------------------

## Returns the ItemStack in hotbar slot 0-9, or null.
func get_hotbar_stack(slot: int) -> ItemStack:
    if slot < 0 or slot >= GRID_WIDTH:
        return null
    return main_inventory.get_item_at_position(slot, 0)


func get_hotbar_item(slot: int) -> Dictionary:
    var stack := get_hotbar_stack(slot)
    if stack == null:
        return {}
    return {"item_id": _get_item_id(stack), "qty": stack.count}


# ---------------------------------------------------------------------------
# Loot container
# ---------------------------------------------------------------------------

func open_loot_inventory(width: int = 5, height: int = 4) -> GridInventory:
    if loot_inventory == null:
        loot_inventory = GridInventory.new()
    loot_inventory.clear()
    loot_inventory.width = width
    loot_inventory.height = height
    loot_inventory.resource_name = "LootInventory"
    return loot_inventory


func close_loot_inventory() -> void:
    if loot_inventory != null:
        loot_inventory.clear()


func transfer_loot_to_main() -> int:
    var moved := 0
    for stack in loot_inventory.items.duplicate():
        var remaining := stack.count
        var copy := stack.duplicate_with_count(remaining)
        var deposited := main_inventory.try_add_item(copy)
        if deposited > 0:
            stack.count -= deposited
            moved += deposited
            if stack.count <= 0:
                loot_inventory.remove_item(stack)
    return moved


# ---------------------------------------------------------------------------
# Crafting
# ---------------------------------------------------------------------------

func open_crafting_grid(width: int = 3, height: int = 3) -> GridInventory:
    if crafting_inventory == null:
        crafting_inventory = GridInventory.new()
    crafting_inventory.clear()
    crafting_inventory.width = width
    crafting_inventory.height = height
    crafting_inventory.resource_name = "CraftingInventory"
    return crafting_inventory


func clear_crafting_grid() -> void:
    if crafting_inventory != null:
        crafting_inventory.clear()


# ---------------------------------------------------------------------------
# Item condition helpers (stored in extra_properties)
# ---------------------------------------------------------------------------

func get_condition(stack: ItemStack) -> float:
    return stack.extra_properties.get("condition", 1.0)


func get_max_condition(stack: ItemStack) -> float:
    return stack.extra_properties.get("max_condition", stack.item_type.max_stack_count)


func set_condition(stack: ItemStack, value: float) -> void:
    stack.extra_properties["condition"] = value
    stack.emit_changed()


func damage_item(stack: ItemStack, amount: float = 1.0) -> void:
    var cur := get_condition(stack)
    cur -= amount
    if cur <= 0.0:
        if stack.inventory == main_inventory:
            main_inventory.remove_item(stack)
        elif stack.inventory == loot_inventory:
            loot_inventory.remove_item(stack)
        elif stack.inventory == crafting_inventory:
            crafting_inventory.remove_item(stack)
        else:
            stack.inventory.remove_item(stack)
    else:
        set_condition(stack, cur)


# ---------------------------------------------------------------------------
# Wyvernbox convenience — get the GridInventory node for UI binding
# ---------------------------------------------------------------------------

## Returns a new GridInventory resource. The UI's InventoryView assigns this
## to its `inventory` property.
func get_main_grid() -> GridInventory:
    return main_inventory

