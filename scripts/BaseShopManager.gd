## BaseShopManager — Tracks shops opened at the player's base (Phase 7).
##
## Per the user's design, "Some joinable characters when at the base
## can ask for money or items to open shops or services at this base
## location." When a dismissed NPC is at the base, the player can pay
## the offer's cost (EC + items) to open a permanent shop. The shop
## then sells items related to the NPC's specialty.
##
## State:
##   - open_shops: Array of {shop_type, npc_id, archetype, opened_at}
##
## Signals:
##   - shop_opened(shop_type, npc_id)
##   - shop_closed(shop_type, npc_id)
##
## Persistence: Phase 7 ships non-persistent state; Phase 8 will
## include the open_shops list in save/load.
extends Node

signal shop_opened(shop_type: String, npc_id: String)
signal shop_closed(shop_type: String, npc_id: String)

# Loaded in _ready
var _shop_types: Dictionary = {}  # shop_type_id -> {name, specialty}
var _npc_offerings: Array = []     # [{npc_archetype, shop_type, cost_ec, cost_items, description}]

# open_shops: Array of {shop_type, npc_id, archetype, opened_at}
var open_shops: Array = []


func _ready() -> void:
	_load_data()
	print("[BaseShopManager] Initialized (%d shop types, %d offerings)." % [
		_shop_types.size(), _npc_offerings.size()
	])


func _load_data() -> void:
	var dr := get_node_or_null("/root/DataRegistry")
	if dr == null:
		push_error("[BaseShopManager] DataRegistry not available")
		return
	var data: Variant = dr.get_data("base_shops")
	if data == null or not (data is Dictionary):
		push_error("[BaseShopManager] base_shops.json missing or invalid")
		return
	_shop_types = {}
	for s in data.get("shop_types", []):
		if s is Dictionary:
			_shop_types[str(s.get("id", ""))] = s
	_npc_offerings = data.get("npc_offerings", [])


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns the offer for a given NPC archetype, or {} if none. An NPC
## has only one offer. Used by the Base interior's "Open Shop" button.
func get_offer(archetype: String) -> Dictionary:
	for o in _npc_offerings:
		if str(o.get("npc_archetype", "")) == archetype:
			return o
	return {}


## Returns the list of shop types for an open shop instance. Currently
## hardcoded; Phase 7 ships a small stock that scales with the base
## level. Real stock ties to the player's inventory and the NPC's
## archetype's specialty.
func get_open_shops() -> Array:
	return open_shops.duplicate()


## Returns true if the shop_type is open.
func is_shop_open(shop_type: String) -> bool:
	for s in open_shops:
		if str(s.get("shop_type", "")) == shop_type:
			return true
	return false


## Returns the per-shop stock for an open shop. Phase 7 ships a
## placeholder stock that includes the items the offer required as
## ingredients plus a few extras. Phase 8 wires real economy-driven
## stock.
func get_shop_stock(shop_type: String) -> Array:
	if not is_shop_open(shop_type):
		return []
	# Default stock per shop type
	match shop_type:
		"weapon_shop":     return _stock_weapons()
		"armor_shop":      return _stock_armor()
		"consumable_shop":  return _stock_consumables()
		"ammo_shop":        return _stock_ammo()
		"tool_shop":        return _stock_tools()
		"rare_shop":        return _stock_rare()
		"scavenger_shop":   return _stock_scavenger()
		"faction_shop":     return _stock_faction()
		"tavern":           return _stock_tavern()
		"skill_trainer":    return _stock_trainer()
		_: return []


## Returns true if the player can afford the offer for the given NPC
## archetype. Checks EC + materials.
func can_afford_offer(archetype: String) -> Dictionary:
	var offer: Dictionary = get_offer(archetype)
	if offer.is_empty():
		return {"ok": false, "reason": "no_offer"}
	var prog: Node = get_node_or_null("/root/ProgressionManager")
	if prog == null:
		return {"ok": false, "reason": "no_progression_manager"}
	if int(prog.ec) < int(offer.get("cost_ec", 0)):
		return {"ok": false, "reason": "Not enough EC (need %d)" % int(offer.get("cost_ec", 0))}
	var inv: Node = get_node_or_null("/root/InventoryHandler")
	if inv == null:
		return {"ok": false, "reason": "no_inventory_manager"}
	for ing in offer.get("cost_items", []):
		if not (ing is Dictionary):
			continue
		if int(inv.get_count(str(ing.get("item_id", "")))) < int(ing.get("count", 1)):
			return {"ok": false, "reason": "Missing %dx %s" % [int(ing.get("count", 1)), str(ing.get("item_id", ""))]}
	return {"ok": true, "reason": ""}


## Open the shop for the given NPC. Deducts the cost and adds to
## open_shops. Returns true on success. Idempotent: if the same shop
## type is already open, returns false.
func open_shop_for_npc(npc_id: String, archetype: String) -> bool:
	var offer: Dictionary = get_offer(archetype)
	if offer.is_empty():
		return false
	var shop_type: String = str(offer.get("shop_type", ""))
	if shop_type.is_empty():
		return false
	if is_shop_open(shop_type):
		return false
	# Verify player can afford
	var check: Dictionary = can_afford_offer(archetype)
	if not bool(check.get("ok", false)):
		return false
	# Deduct cost
	var prog: Node = get_node_or_null("/root/ProgressionManager")
	var inv: Node = get_node_or_null("/root/InventoryHandler")
	if prog != null and int(offer.get("cost_ec", 0)) > 0:
		prog.spend_ec(int(offer.get("cost_ec", 0)))
	for ing in offer.get("cost_items", []):
		if not (ing is Dictionary):
			continue
		if inv != null:
			inv.remove_item(str(ing.get("item_id", "")), int(ing.get("count", 1)))
	open_shops.append({
		"shop_type": shop_type,
		"npc_id": npc_id,
		"archetype": archetype,
		"opened_at": Time.get_unix_time_from_system(),
	})
	shop_opened.emit(shop_type, npc_id)
	print("[BaseShopManager] Opened shop %s for NPC %s" % [shop_type, npc_id])
	return true


## Returns the shop_type for a given archetype (e.g. "scavenger" →
## "scavenger_shop"), or "" if no offer.
func get_shop_type_for(archetype: String) -> String:
	var offer: Dictionary = get_offer(archetype)
	return str(offer.get("shop_type", ""))


## Returns the description for the offer.
func get_offer_description(archetype: String) -> String:
	var offer: Dictionary = get_offer(archetype)
	return str(offer.get("description", ""))


# ---------------------------------------------------------------------------
# Snapshot / restore
# ---------------------------------------------------------------------------

func get_snapshot() -> Dictionary:
	return {"open_shops": open_shops.duplicate(true)}


func restore_from_snapshot(snap: Dictionary) -> void:
	open_shops.clear()
	for s in snap.get("open_shops", []):
		open_shops.append(s)


# ---------------------------------------------------------------------------
# Default stock per shop type
# ---------------------------------------------------------------------------

func _stock_weapons() -> Array:
	return [
		{"item_id": "withered_branch", "count": 10, "buy_price": 4},
		{"item_id": "iron_ore", "count": 8,  "buy_price": 8},
		{"item_id": "copper_ore", "count": 4,  "buy_price": 16},
	]


func _stock_armor() -> Array:
	return [
		{"item_id": "withered_branch", "count": 10, "buy_price": 4},
		{"item_id": "iron_ore", "count": 8,  "buy_price": 8},
		{"item_id": "ironwood_bark", "count": 5,  "buy_price": 12},
	]


func _stock_consumables() -> Array:
	return [
		{"item_id": "bandage", "count": 5,  "buy_price": 8},
		{"item_id": "kelp_fibre", "count": 6,  "buy_price": 4},
	]


func _stock_ammo() -> Array:
	return [
		{"item_id": "withered_branch", "count": 20, "buy_price": 3},
		{"item_id": "iron_ore", "count": 10, "buy_price": 7},
	]


func _stock_tools() -> Array:
	return [
		{"item_id": "withered_branch", "count": 15, "buy_price": 3},
		{"item_id": "stone", "count": 20, "buy_price": 2},
	]


func _stock_rare() -> Array:
	return [
		{"item_id": "teal_crystal", "count": 2,  "buy_price": 50},
		{"item_id": "void_shard", "count": 1,  "buy_price": 100},
		{"item_id": "ember_crystal", "count": 2,  "buy_price": 80},
	]


func _stock_scavenger() -> Array:
	return [
		{"item_id": "withered_branch", "count": 30, "buy_price": 2},
		{"item_id": "stone", "count": 30, "buy_price": 1},
		{"item_id": "rusted_scrap", "count": 5,  "buy_price": 8},
	]


func _stock_faction() -> Array:
	return [
		{"item_id": "iron_ore", "count": 10, "buy_price": 6},
		{"item_id": "copper_ore", "count": 5,  "buy_price": 12},
		{"item_id": "starmetal_ore", "count": 2,  "buy_price": 50},
	]


func _stock_tavern() -> Array:
	return [
		{"item_id": "bandage", "count": 10, "buy_price": 5},
		{"item_id": "kelp_fibre", "count": 8,  "buy_price": 3},
	]


func _stock_trainer() -> Array:
	return [
		{"item_id": "teal_crystal", "count": 3,  "buy_price": 30},
	]
