## CraftingManager — Recipe resolution + crafting.
##
## Phase 3 autoload. Loads `data/recipes.json` (already created in
## Phase 1 with the stone-axe and bandage recipes). `unlocked_recipes`
## is derived from the player's level (recipes whose `level_required`
## is <= current level). The CharacterMenu's Crafting tab uses
## `can_craft` / `craft` to show and execute recipes.
##
## Stations (Worktable, ArmorTable, Blacksmith) are separate flows:
## they're triggered by E-press near a station, not via the menu.
## Their UIs (WorktableUI, ArmorTableUI, BlacksmithUI) are added as
## separate scripts in this phase.
##
## Persistence: like InventoryManager, this is non-persistent in
## Phase 3. GameState.SaveManager is the canonical layer; will be
## extended in Phase 8 to include the unlocked-recipe list.
extends Node

signal recipe_unlocked(recipe_id: String)
signal recipe_crafted(recipe_id: String)
signal recipe_craft_failed(recipe_id: String, reason: String)

# recipes: {recipe_id: recipe_dict}
var _recipes: Dictionary = {}
# recipes indexed by category
var _by_category: Dictionary = {}
# Unlocked recipe IDs (derived from player level, refreshed via
## `refresh_unlocked(level)`)
var _unlocked_recipes: Array = []


func _ready() -> void:
	_load_recipes()
	refresh_unlocked(1)
	print("[CraftingManager] Initialized (%d recipes)." % _recipes.size())


func _load_recipes() -> void:
	var dr := get_node_or_null("/root/DataRegistry")
	if dr == null:
		push_error("[CraftingManager] DataRegistry not available")
		return
	var data: Variant = dr.get_data("recipes")
	if data == null or not (data is Dictionary):
		push_error("[CraftingManager] recipes.json missing or invalid")
		return
	for r in data.get("recipes", []):
		if not (r is Dictionary):
			continue
		var rid: String = str(r.get("id", ""))
		if rid.is_empty():
			continue
		_recipes[rid] = r
		# Index by category
		var cat: String = str(r.get("category", ""))
		if not _by_category.has(cat):
			_by_category[cat] = []
		_by_category[cat].append(rid)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns the recipe dict, or {}.
func get_recipe(recipe_id: String) -> Dictionary:
	return _recipes.get(recipe_id, {})


## Returns the list of recipe IDs the player can currently see (unlocked
## by level + filter for `station == "none"` so the inventory tab
## only shows always-available recipes; station-specific recipes show
## up in their station UI).
func unlocked_recipes() -> Array:
	return _unlocked_recipes.duplicate()


## Recompute the unlocked-recipes list from the given player level.
## Phase 3 keeps this as a manual call (caller passes the level). In
## Phase 4 we wire it to ProgressionManager.level_up signal.
func refresh_unlocked(player_level: int) -> void:
	var prev: Array = _unlocked_recipes
	_unlocked_recipes = []
	for rid in _recipes.keys():
		var r: Dictionary = _recipes[rid]
		# Inventory tab only shows recipes with station "none" (always-
		# available). Station-specific recipes are shown in their
		# station UI, not here.
		if str(r.get("station", "none")) != "none":
			continue
		if int(r.get("level_required", 1)) <= player_level:
			_unlocked_recipes.append(rid)
	# Emit for newly unlocked
	for rid in _unlocked_recipes:
		if not prev.has(rid):
			recipe_unlocked.emit(rid)


## Returns true if the player can craft this recipe (has all
## ingredients + meets level). Doesn't check station — the station UI
## does that. Optional `inv` parameter lets the caller pass a specific
## InventoryManager (for tests or for non-autoload inventories).
## Defaults to the autoload.
func can_craft(recipe_id: String, inv: Node = null) -> bool:
	var r: Dictionary = _recipes.get(recipe_id, {})
	if r.is_empty():
		return false
	if inv == null:
		inv = get_node_or_null("/root/InventoryManager")
	if inv == null:
		return false
	for ing in r.get("ingredients", []):
		if not (ing is Dictionary):
			return false
		if not inv.has_item(str(ing.get("item", "")), int(ing.get("qty", 1))):
			return false
	return true


## Spend ingredients and add the result to InventoryManager. Returns
## true on success. Optional `inv` parameter (same as can_craft).
func craft(recipe_id: String, inv: Node = null) -> bool:
	var r: Dictionary = _recipes.get(recipe_id, {})
	if r.is_empty():
		recipe_craft_failed.emit(recipe_id, "unknown_recipe")
		return false
	if inv == null:
		inv = get_node_or_null("/root/InventoryManager")
	if inv == null:
		recipe_craft_failed.emit(recipe_id, "no_inventory")
		return false
	if not can_craft(recipe_id, inv):
		recipe_craft_failed.emit(recipe_id, "missing_ingredients")
		return false
	# Consume ingredients
	for ing in r.get("ingredients", []):
		inv.remove_item(str(ing.get("item", "")), int(ing.get("qty", 1)))
	# Add result
	var result: Dictionary = r.get("result", {})
	var result_item: String = str(result.get("item", ""))
	var result_qty: int = int(result.get("qty", 1))
	if not result_item.is_empty() and result_qty > 0:
		inv.add_item(result_item, result_qty)
	recipe_crafted.emit(recipe_id)
	return true


## Returns the list of recipe IDs that require the given station.
## Used by WorktableUI / ArmorTableUI / BlacksmithUI to populate
## their lists.
func recipes_for_station(station: String) -> Array:
	var out: Array = []
	for rid in _recipes.keys():
		if str(_recipes[rid].get("station", "")) == station:
			out.append(rid)
	return out
