## EquipmentManager — Player + party equipment, stat mods, equip/unequip.
##
## Phase 4 autoload. Owns:
##   - the equipment data (weapons, armor, accessories) loaded from
##     data/weapons.json, data/armor.json, data/accessories.json
##   - the per-NPC equipment dicts (8 slots + a tools slot)
##   - the MainHand item (the currently active tool or weapon)
##
## Slot layout (matches PartyNPCManager.EQUIP_SLOTS):
##   - head, chest, legs, boots       (armor)
##   - mainhand, offhand              (weapons or tools; tools share
##     mainhand with weapons and swap via the hotbar in Phase 2+)
##   - tool                           (Phase 1 tools; same as mainhand
##     in Phase 4 — mainhand can hold either)
##   - acc1, acc2                     (accessories)
##
## Weapons and armor are template-based: `get_weapon(class_id, tier)`
## and `get_armor(class_id, slot, tier)` lazily expand the tier_curve
## to a full entry dict (id, name, sprite, color, level_required,
## damage / armor, range, stat_mods). Per-tier visual differentiation
## is a simple color shift (see tier_color_shift in the JSON).
##
## Persistence: like other Phase 4 autoloads, the per-NPC equipment
## is non-persistent for now. GameState.SaveManager is the canonical
## layer (Phase 8 will include the equipment dict).
extends Node

const WEAPONS_PATH := "res://data/weapons.json"
const ARMOR_PATH := "res://data/armor.json"
const ACCESSORIES_PATH := "res://data/accessories.json"

signal equipment_changed(npc_id: String, slot: String)
signal main_hand_changed(npc_id: String, item_id: String)

const EQUIP_SLOTS := ["head", "chest", "legs", "boots", "mainhand", "offhand", "tool", "acc1", "acc2"]
const ARMOR_SLOTS := ["head", "chest", "legs", "boots"]

# weapons: {class_id: {base_weapon_name, sprite, base_color, ...}}
var _weapons_data: Dictionary = {}
# armor: {class_id: {base_armor_name, sprite, ...}}
# Per-slot base color lives in the armor.json slots dict (loaded here).
var _armor_data: Dictionary = {}
var _armor_slots_data: Dictionary = {}
# accessories: {id: accessory_dict}
var _accessories: Dictionary = {}

# Shared tier curves (loaded from each file)
var _weapon_curve: Dictionary = {}
var _armor_curve: Dictionary = {}
var _weapon_tier_color: Dictionary = {}
var _armor_tier_color: Dictionary = {}
# weapon_suffixes, armor_suffixes arrays for per-tier sprite names
var _weapon_tier_color_data: Dictionary = {}

# equipment_state: {npc_id: {slot: item_id}}
# The player's id is "player"; party members use their PartyNPCManager id.
var _equipment_state: Dictionary = {}


func _ready() -> void:
	_load_weapons()
	_load_armor()
	_load_accessories()
	print("[EquipmentManager] Initialized (%d weapons, %d armor, %d accessories)." % [
		_weapons_data.size(), _armor_data.size(), _accessories.size()
	])


# ---------------------------------------------------------------------------
# Loaders
# ---------------------------------------------------------------------------

func _load_json(path: String) -> Variant:
	if not ResourceLoader.exists(path):
		push_error("[EquipmentManager] %s missing" % path)
		return null
	var raw = load(path)
	if raw == null:
		return null
	var data = raw.data if "data" in raw else raw
	return data


func _load_weapons() -> void:
	var data = _load_json(WEAPONS_PATH)
	if data == null or not (data is Dictionary):
		return
	_weapon_curve = data.get("tier_curve", {})
	_weapon_tier_color = data.get("tier_color_shift", {})
	_weapon_tier_color_data = data.get("sprite_tier_suffix", {})
	_weapons_data = data.get("classes", {})


func _load_armor() -> void:
	var data = _load_json(ARMOR_PATH)
	if data == null or not (data is Dictionary):
		return
	_armor_curve = data.get("tier_curve", {})
	_armor_tier_color = data.get("tier_color_shift", {})
	_armor_slots_data = data.get("slots", {})
	_armor_data = data.get("classes", {})


func _load_accessories() -> void:
	var data = _load_json(ACCESSORIES_PATH)
	if data == null or not (data is Dictionary):
		return
	_accessories = {}
	for a in data.get("accessories", []):
		if a is Dictionary:
			_accessories[str(a.get("id", ""))] = a


# ---------------------------------------------------------------------------
# Entry expansion (template → per-tier dict)
# ---------------------------------------------------------------------------

## Returns the weapon entry for (class_id, tier). Lazily built and
## cached. Returns {} if class_id is unknown.
func get_weapon(class_id: String, tier: int) -> Dictionary:
	if not _weapons_data.has(class_id):
		return {}
	if tier < 0 or tier >= 26:
		return {}
	# Cache key
	var key: String = "%s_%d" % [class_id, tier]
	if _weapon_cache.has(key):
		return _weapon_cache[key]
	var c: Dictionary = _weapons_data[class_id]
	var t: Dictionary = _weapon_curve
	var name_suffix: String = str(t.get("name_suffix", ["?"])[tier])
	var level: int = int(t.get("levels", [1])[tier])
	var damage: int = int(t.get("damage_base", [0])[tier])
	var range_v: int = int(t.get("range_base", [1])[tier])
	var base_color: Dictionary = c.get("base_color", {"h": 0.0, "s": 0.0, "v": 0.5})
	var tier_color: Color = _tier_color_for(_weapon_tier_color, tier, base_color)
	var sprite_base: String = str(c.get("sprite_base", ""))
	var weapon_suffixes: Array = _weapon_tier_color_data.get("weapon_suffixes", [])
	var sprite_suffix: String = ""
	if tier < weapon_suffixes.size():
		sprite_suffix = str(weapon_suffixes[tier])
	var sprite_name: String = sprite_base + sprite_suffix
	var entry := {
		"id": "weapon_%s_t%d" % [class_id.to_lower().replace(" ", "_"), tier + 1],
		"name": "%s %s" % [c.get("base_weapon_name", "?"), name_suffix],
		"class_id": class_id,
		"slot": "mainhand",
		"tier": tier + 1,
		"level_required": level,
		"damage": damage,
		"range": range_v,
		"weapon_kind": c.get("weapon_kind", "blade"),
		"sprite": sprite_name,
		"color": tier_color,
		"stat_mods": c.get("stat_mods", {}),
		"sell_value_ec": 5 + tier * 5,
		"category": "weapon",
		"stackable": false,
	}
	_weapon_cache[key] = entry
	return entry


var _weapon_cache: Dictionary = {}


## Returns the armor entry for (class_id, slot, tier). Lazily built and
## cached. Returns {} if (class_id, slot) is unknown or tier is OOB.
func get_armor(class_id: String, slot: String, tier: int) -> Dictionary:
	if not _armor_data.has(class_id) or not _armor_slots_data.has(slot):
		return {}
	if tier < 0 or tier >= 13:
		return {}
	var key: String = "%s_%s_%d" % [class_id, slot, tier]
	if _armor_cache.has(key):
		return _armor_cache[key]
	var c: Dictionary = _armor_data[class_id]
	var s: Dictionary = _armor_slots_data[slot]
	var t: Dictionary = _armor_curve
	var name_suffix: String = str(t.get("name_suffix", ["?"])[tier])
	var level: int = int(t.get("levels", [1])[tier])
	var armor: int = int(t.get("armor_base", [0])[tier])
	var base_color: Dictionary = s.get("base_color", {"h": 0.0, "s": 0.0, "v": 0.5})
	var tier_color: Color = _tier_color_for(_armor_tier_color, tier, base_color)
	var sprite_base: String = str(c.get("sprite_base", ""))
	var armor_suffixes: Array = _weapon_tier_color_data.get("armor_suffixes", [])
	var sprite_suffix: String = ""
	if tier < armor_suffixes.size():
		sprite_suffix = str(armor_suffixes[tier])
	var sprite_name: String = "%s_%s%s" % [sprite_base, slot, sprite_suffix]
	var entry := {
		"id": "armor_%s_%s_t%d" % [class_id.to_lower().replace(" ", "_"), slot, tier + 1],
		"name": "%s %s %s" % [c.get("base_armor_name", "?"), s.get("name_prefix", slot), name_suffix],
		"class_id": class_id,
		"slot": slot,
		"tier": tier + 1,
		"level_required": level,
		"armor": armor,
		"sprite": sprite_name,
		"color": tier_color,
		"stat_mods": c.get("stat_mods", {}),
		"sell_value_ec": 3 + tier * 3,
		"category": "armor",
		"stackable": false,
	}
	_armor_cache[key] = entry
	return entry


var _armor_cache: Dictionary = {}


## Returns the accessory entry for the given id, or {}.
func get_accessory(item_id: String) -> Dictionary:
	return _accessories.get(item_id, {})


## Returns the tool entry for the given id (delegates to data/tools.json
## via the InventoryManager's lookup; we just forward the tool dict).
## Kept here so the EquipmentManager is the single entry point for
## "what's in this slot".
func get_tool_entry(item_id: String) -> Dictionary:
	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv == null or not inv.has_method("get_item_meta"):
		return {}
	return inv.get_item_meta(item_id)


## Returns the per-tier color (HSV-shifted base color) for the given
## tier curve and tier index.
func _tier_color_for(tier_color_shift: Dictionary, tier: int, base_color: Dictionary) -> Color:
	var h: float = float(base_color.get("h", 0.0))
	var s: float = float(base_color.get("s", 0.0))
	var v: float = float(base_color.get("v", 0.5))
	if tier_color_shift.is_empty():
		return Color.from_hsv(h, s, v)
	var hue_off: float = float(tier_color_shift.get("hue_offset", [0.0])[tier])
	var sat_off: float = float(tier_color_shift.get("sat_offset", [0.0])[tier])
	var val_off: float = float(tier_color_shift.get("value_offset", [0.0])[tier])
	var new_h: float = fposmod(h + hue_off, 1.0)
	var new_s: float = clamp(s + sat_off, 0.0, 1.0)
	var new_v: float = clamp(v + val_off, 0.0, 1.0)
	return Color.from_hsv(new_h, new_s, new_v)


# ---------------------------------------------------------------------------
# Equipment state (player + party members)
# ---------------------------------------------------------------------------

## Returns the equipment dict for the given npc_id (creates a fresh
## empty dict if the npc has never been equipped). The player uses
## "player" as npc_id.
func get_equipment(npc_id: String) -> Dictionary:
	if not _equipment_state.has(npc_id):
		_equipment_state[npc_id] = _empty_equipment()
	return _equipment_state[npc_id]


func _empty_equipment() -> Dictionary:
	var out: Dictionary = {}
	for slot in EQUIP_SLOTS:
		out[slot] = ""
	return out


## Equips item_id into the given slot for npc_id. Returns true on
## success, false if the slot is invalid or the item is unknown.
## Caller is responsible for the swap logic (Phase 4 supports
## direct equip only; drag-to-equip from inventory comes in
## CharacterMenu's EquipmentScreen).
func equip(npc_id: String, item_id: String, slot: String) -> bool:
	if not slot in EQUIP_SLOTS:
		return false
	if item_id.is_empty():
		# Unequip
		return _set_slot(npc_id, slot, "")
	# Validate the item exists somewhere (inventory / tool / weapon / etc.)
	if not _item_is_known(item_id):
		return false
	return _set_slot(npc_id, slot, item_id)


## Unequip the given slot. Returns true on success.
func unequip(npc_id: String, slot: String) -> bool:
	if not slot in EQUIP_SLOTS:
		return false
	return _set_slot(npc_id, slot, "")


func _set_slot(npc_id: String, slot: String, item_id: String) -> bool:
	var eq: Dictionary = get_equipment(npc_id)
	eq[slot] = item_id
	emit_signal("equipment_changed", npc_id, slot)
	# MainHand slot drives the main_hand signal
	if slot == "mainhand" or slot == "tool":
		emit_signal("main_hand_changed", npc_id, item_id)
	return true


func _item_is_known(item_id: String) -> bool:
	# Search weapons, armor, accessories, and tools
	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv != null and inv.has_method("has_item_meta") and inv.has_item_meta(item_id):
		return true
	if _accessories.has(item_id):
		return true
	# Check weapons: id pattern is weapon_<class>_t<num>
	if item_id.begins_with("weapon_"):
		return true
	# Check armor: id pattern is armor_<class>_<slot>_t<num>
	if item_id.begins_with("armor_"):
		return true
	return false


## Returns the main-hand item id (the active weapon or tool) for the
## given npc_id, or "" if no main hand.
func get_main_hand_item(npc_id: String) -> String:
	var eq: Dictionary = get_equipment(npc_id)
	var mainhand: String = str(eq.get("mainhand", ""))
	if not mainhand.is_empty():
		return mainhand
	# Fall back to the tool slot
	return str(eq.get("tool", ""))


## Returns the merged stat_mods of all equipped items for the given
## npc_id. Walks every slot, looks up the item's stat_mods, and sums
## the values. Special fields (loot_bonus_pct, gather_speed_pct, etc.)
## are NOT included — they require separate aggregation (TODO Phase 4+).
func get_stat_mods(npc_id: String) -> Dictionary:
	var eq: Dictionary = get_equipment(npc_id)
	var out: Dictionary = {}
	for slot in EQUIP_SLOTS:
		var item_id: String = str(eq.get(slot, ""))
		if item_id.is_empty():
			continue
		var entry: Dictionary = _resolve_item(item_id)
		if entry.is_empty():
			continue
		var mods: Dictionary = entry.get("stat_mods", {})
		for stat in mods:
			out[stat] = int(out.get(stat, 0)) + int(mods[stat])
	return out


## Looks up an item by id across all the data sources (weapons, armor,
## accessories, tools). Returns the entry dict or {}.
func _resolve_item(item_id: String) -> Dictionary:
	if item_id.begins_with("weapon_"):
		# Format: weapon_<class>_t<num>; class from name, tier from num-1
		var rest: String = item_id.substr("weapon_".length())
		var parts: PackedStringArray = rest.split("_t")
		if parts.size() == 2:
			var class_id: String = parts[0].to_pascal_case()
			var tier: int = int(parts[1]) - 1
			return get_weapon(class_id, tier)
	if item_id.begins_with("armor_"):
		var rest2: String = item_id.substr("armor_".length())
		# format: armor_<class>_<slot>_t<num>
		var parts2: PackedStringArray = rest2.split("_t")
		if parts2.size() == 2:
			var class_slot: PackedStringArray = parts2[0].split("_")
			if class_slot.size() == 2:
				var class_id2: String = class_slot[0].to_pascal_case()
				var slot2: String = class_slot[1]
				var tier2: int = int(parts2[1]) - 1
				return get_armor(class_id2, slot2, tier2)
	return get_accessory(item_id)


## Returns the max HP / MP / etc. derived from class + level + stat_mods.
## Phase 4: simple curve + stat_mods contribution. The full system
## grows in later phases.
func get_max_hp(class_id: String, level: int, stat_mods: Dictionary) -> int:
	var base: int = 50 + level * 8
	return base + int(stat_mods.get("con", 0)) * 4 + int(stat_mods.get("hp_max_add", 0))


func get_max_mp(class_id: String, level: int, stat_mods: Dictionary) -> int:
	var base: int = 20 + level * 3
	return base + int(stat_mods.get("int", 0)) * 3


## Returns the attack power (weapon damage + str contribution).
func get_attack(npc_id: String) -> int:
	var mainhand: String = get_main_hand_item(npc_id)
	var weapon_damage: int = 0
	if not mainhand.is_empty():
		var entry: Dictionary = _resolve_item(mainhand)
		weapon_damage = int(entry.get("damage", 0))
	var eq: Dictionary = get_equipment(npc_id)
	var mods: Dictionary = get_stat_mods(npc_id)
	# Str contributes to melee damage
	var str_bonus: int = int(mods.get("str", 0))
	return weapon_damage + str_bonus


## Returns the defense (armor + con contribution).
func get_defense(npc_id: String) -> int:
	var eq: Dictionary = get_equipment(npc_id)
	var total_armor: int = 0
	for slot in ARMOR_SLOTS:
		var item_id: String = str(eq.get(slot, ""))
		if item_id.is_empty():
			continue
		var entry: Dictionary = _resolve_item(item_id)
		total_armor += int(entry.get("armor", 0))
	var mods: Dictionary = get_stat_mods(npc_id)
	return total_armor + int(mods.get("con", 0))


# ---------------------------------------------------------------------------
# Snapshot / restore (save/load in Phase 8)
# ---------------------------------------------------------------------------

func get_snapshot() -> Dictionary:
	return {"equipment_state": _equipment_state.duplicate(true)}


func restore_from_snapshot(snap: Dictionary) -> void:
	_equipment_state.clear()
	for k in snap.get("equipment_state", {}):
		_equipment_state[k] = (snap.equipment_state[k] as Dictionary).duplicate(true)
