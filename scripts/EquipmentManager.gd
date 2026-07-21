## EquipmentManager — Player + party equipment, stat mods, equip/unequip.
##
## Phase 4 autoload. Owns:
##   - the equipment data (weapons, armor, accessories) loaded from
##     data/weapons.json, data/armor.json, data/accessories.json
##   - the per-NPC equipment dicts (8 slots + a tools slot)
##   - the MainHand item (the currently active tool or weapon)
##
## Slot layout (matches PartyNPCManager.EQUIP_SLOTS):
##   - armor                         (single armor slot — visuals are
##     baked into the PixelLab character sprite and tinted per tier
##     via character.modulate; see tier_color_shift in data/armor.json)
##   - mainhand, offhand              (weapons or tools; tools share
##     mainhand with weapons and swap via the hotbar in Phase 2+)
##   - tool                           (Phase 1 tools; same as mainhand
##     in Phase 4 — mainhand can hold either)
##   - acc1, acc2                     (accessories)
##
## Weapons are template-based: `get_weapon(class_id, tier)` expands
## the tier_curve to a full entry dict. Armor is also template-based:
## `get_armor(class_id, tier)` (single slot) does the same and the
## resulting tier color is what CharacterVisual applies as modulate.
## `get_armor_color(npc_id)` returns the equipped armor's tier color
## (or white if no armor). Per-tier differentiation is a simple
## color shift (see tier_color_shift in the JSON).
##
## Persistence: like other Phase 4 autoloads, the per-NPC equipment
## is non-persistent for now. GameState.SaveManager is the canonical
## layer (Phase 8 will include the equipment dict).
extends Node

signal equipment_changed(npc_id: String, slot: String)
signal main_hand_changed(npc_id: String, item_id: String)
const EQUIP_SLOTS := ["armor", "mainhand", "offhand", "tool", "acc1", "acc2"]
const ARMOR_SLOTS := ["armor"]


# weapons: {class_id: {base_weapon_name, sprite, base_color, ...}}
var _weapons_data: Dictionary = {}
# armor: {type: {display_name, sprite_base, base_color, stat_mods, armor_mult}}
var _armor_data: Dictionary = {}
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
	var dr := get_node_or_null("/root/DataRegistry")
	if dr == null:
		push_error("[EquipmentManager] DataRegistry not available")
		return
	var data: Variant = dr.get_data("weapons")
	if data == null or not (data is Dictionary):
		return
	_weapon_curve = data.get("tier_curve", {})
	_weapon_tier_color = data.get("tier_color_shift", {})
	_weapon_tier_color_data = data.get("sprite_tier_suffix", {})
	_weapons_data = data.get("classes", {})


func _load_armor() -> void:
	var dr := get_node_or_null("/root/DataRegistry")
	if dr == null:
		push_error("[EquipmentManager] DataRegistry not available")
		return
	var data: Variant = dr.get_data("armor")
	if data == null or not (data is Dictionary):
		return
	_armor_curve = data.get("tier_curve", {})
	_armor_tier_color = data.get("tier_color_shift", {})
	_armor_data = data.get("types", {})


func _load_accessories() -> void:
	var dr := get_node_or_null("/root/DataRegistry")
	if dr == null:
		push_error("[EquipmentManager] DataRegistry not available")
		return
	var data: Variant = dr.get_data("accessories")
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
	if tier < 0 or tier >= _weapon_curve.get("levels", []).size():
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
	# Map 26 data tiers → 3 visual sprites: T1 (tiers 1-9), T2 (10-18), T3 (19-26)
	var vis_idx: int = 0
	if tier >= 18:
		vis_idx = 2
	elif tier >= 9:
		vis_idx = 1
	var sprite_suffix: String = ""
	if vis_idx < weapon_suffixes.size():
		sprite_suffix = str(weapon_suffixes[vis_idx])
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


## Returns the armor entry for (armor_type, tier). Lazily built and
## cached. Returns {} if armor_type is unknown or tier is OOB.
## armor_type: "rugged", "heavy", or "massive"
## Visual is baked into the character sprite with per-tier color modulation,
## so the entry's `color` field is what CharacterVisual applies.
func get_armor(armor_type: String, tier: int) -> Dictionary:
	var type_key: String = armor_type.to_lower().strip_edges()
	if not _armor_data.has(type_key):
		return {}
	if tier < 0 or tier >= _armor_curve.get("levels", []).size():
		return {}
	var key: String = "%s_%d" % [type_key, tier]
	if _armor_cache.has(key):
		return _armor_cache[key]
	var c: Dictionary = _armor_data[type_key]
	var t: Dictionary = _armor_curve
	var name_suffix: String = str(t.get("name_suffix", ["?"])[tier])
	var level: int = int(t.get("levels", [1])[tier])
	var base_armor: int = int(t.get("armor_base", [0])[tier])
	var armor_mult: float = float(c.get("armor_mult", 1.0))
	var armor: int = int(base_armor * armor_mult)
	var base_color: Dictionary = c.get("base_color", {"h": 0.0, "s": 0.0, "v": 0.5})
	var tier_color: Color = _tier_color_for(_armor_tier_color, tier, base_color)
	var sprite_base: String = str(c.get("sprite_base", ""))
	var armor_suffixes: Array = _weapon_tier_color_data.get("armor_suffixes", [])
	var sprite_suffix: String = ""
	if tier < armor_suffixes.size():
		sprite_suffix = str(armor_suffixes[tier])
	var sprite_name: String = "%s%s" % [sprite_base, sprite_suffix]
	var entry := {
		"id": "armor_%s_t%d" % [type_key, tier + 1],
		"name": "%s %s %s" % [c.get("display_name", "?"), "Suit", name_suffix],
		"armor_type": type_key,
		"slot": "armor",
		"tier": tier + 1,
		"level_required": level,
		"armor": armor,
		"sprite": sprite_name,
		"color": tier_color,
		"stat_mods": c.get("stat_mods", {}),
		"sell_value_ec": 3 + tier * 8,
		"category": "armor",
		"stackable": false,
	}
	_armor_cache[key] = entry
	return entry


## Returns the tier color (Color) of the armor currently equipped by
## the given npc_id, or Color(1,1,1) if no armor is equipped. Use this
## to drive CharacterVisual's modulate on equip.
func get_armor_color(npc_id: String) -> Color:
	var eq: Dictionary = get_equipment(npc_id)
	var item_id: String = str(eq.get("armor", ""))
	if item_id.is_empty():
		return Color(1.0, 1.0, 1.0)
	var entry: Dictionary = _resolve_item(item_id)
	if entry.is_empty():
		return Color(1.0, 1.0, 1.0)
	return entry.get("color", Color(1.0, 1.0, 1.0))


## Map class_id to starting armor type.
const CLASS_ARMOR_MAP: Dictionary = {
	"Scavenger": "rugged",
	"Technician": "heavy",
	"Survivor": "rugged",
	"Striker": "massive",
	"Riftbinder": "heavy",
	"Warden": "massive",
}

## Returns the starting armor type for a given class_id.
func get_starting_armor_type(class_id: String) -> String:
	return CLASS_ARMOR_MAP.get(class_id, "rugged")


var _armor_cache: Dictionary = {}


## Returns the accessory entry for the given id, or {}.
func get_accessory(item_id: String) -> Dictionary:
	return _accessories.get(item_id, {})


## Returns the tool entry for the given id (delegates to data/tools.json
## via the InventoryHandler's lookup; we just forward the tool dict).
## Kept here so the EquipmentManager is the single entry point for
## "what's in this slot".
func get_tool_entry(item_id: String) -> Dictionary:
	var inv: Node = get_node_or_null("/root/InventoryHandler")
	if inv == null or not inv.has_method("get_item_data"):
		return {}
	return inv.get_item_data(item_id)


## Returns the per-tier color (HSV-shifted base color) for the given
## tier curve and tier index.
func _tier_color_for(tier_color_shift: Dictionary, tier: int, base_color: Dictionary) -> Color:
	var h: float = float(base_color.get("h", 0.0))
	var s: float = float(base_color.get("s", 0.0))
	var v: float = float(base_color.get("v", 0.5))
	if tier_color_shift.is_empty():
		return Color.from_hsv(h, s, v)
	var hue_arr: Array = tier_color_shift.get("hue_offset", [0.0])
	var sat_arr: Array = tier_color_shift.get("sat_offset", [0.0])
	var val_arr: Array = tier_color_shift.get("value_offset", [0.0])
	if hue_arr.is_empty() or sat_arr.is_empty() or val_arr.is_empty():
		return Color.from_hsv(h, s, v)
	var hue_off: float = float(hue_arr[min(tier, hue_arr.size() - 1)])
	var sat_off: float = float(sat_arr[min(tier, sat_arr.size() - 1)])
	var val_off: float = float(val_arr[min(tier, val_arr.size() - 1)])
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
	equipment_changed.emit(npc_id, slot)
	# MainHand slot drives the main_hand signal
	if slot == "mainhand" or slot == "tool":
		main_hand_changed.emit(npc_id, item_id)
	return true


func _item_is_known(item_id: String) -> bool:
	var inv: Node = get_node_or_null("/root/InventoryHandler")
	if inv != null and inv.has_method("has_item_meta") and inv.has_item_meta(item_id):
		return true
	if _accessories.has(item_id):
		return true
	if item_id.begins_with("weapon_"):
		return true
	if item_id.begins_with("armor_"):
		var rest: String = item_id.substr("armor_".length())
		var parts: PackedStringArray = rest.split("_t")
		if parts.size() == 2:
			var armor_type: String = parts[0].to_lower().strip_edges()
			return _armor_data.has(armor_type)
		return false
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
		var rest: String = item_id.substr("weapon_".length())
		var parts: PackedStringArray = rest.split("_t")
		if parts.size() == 2:
			var class_id: String = parts[0].to_pascal_case()
			var tier: int = int(parts[1]) - 1
			return get_weapon(class_id, tier)
	if item_id.begins_with("armor_"):
		var rest: String = item_id.substr("armor_".length())
		var parts: PackedStringArray = rest.split("_t")
		if parts.size() == 2:
			var armor_type: String = parts[0].to_lower().strip_edges()
			var tier: int = int(parts[1]) - 1
			return get_armor(armor_type, tier)
	return get_accessory(item_id)


## Returns the max HP / MP / etc. derived from class + level + stat_mods.
## Phase 4: simple curve + stat_mods contribution. The full system
## grows in later phases.
func get_max_hp(level: int, stat_mods: Dictionary) -> int:
	var base: int = 50 + level * 8
	return base + int(stat_mods.get("con", 0)) * 4 + int(stat_mods.get("hp_max_add", 0))


func get_max_mp(level: int, stat_mods: Dictionary) -> int:
	var base: int = 20 + level * 3
	return base + int(stat_mods.get("int", 0)) * 3


## Returns the weapon range (in tiles) for the currently equipped weapon.
## Melee weapons (blade, heavy_blade, shield_hammer) always return 1.
## Ranged weapons (pistol, rifle, focus) scale with visual tier:
##   T1 (data tiers 1-9) = 2, T2 (10-18) = 4, T3 (19-26) = 6.
func get_weapon_range(npc_id: String) -> int:
	var mainhand: String = get_main_hand_item(npc_id)
	if mainhand.is_empty():
		return 1
	var entry: Dictionary = _resolve_item(mainhand)
	if entry.is_empty():
		return 1
	var weapon_kind: String = str(entry.get("weapon_kind", "blade"))
	var tier: int = int(entry.get("tier", 1))
	# Melee weapons always have range 1
	if weapon_kind in ["blade", "heavy_blade", "shield_hammer"]:
		return 1
	# Ranged weapons scale by visual tier
	if tier <= 9:
		return 2
	elif tier <= 18:
		return 4
	else:
		return 6


## Returns the attack power (weapon damage + stat mods from all equipment).
## v0.6.0: each class's weapon scales with its own stats (not just str).
## Scavenger blade → str, Technician pistol → int, Survivor rifle → con,
## Striker heavy blade → str, Riftbinder focus → int (+ wis secondary),
## Warden shield+hammer → str (+ con secondary). The weapon's
## `stat_mods` (set from the class config) is summed for the bonus.
## All other equipment (armor, accessories) also contribute their
## stat_mods, so an iron_grip (+2 str) in acc1 adds +2 attack.
func get_attack(npc_id: String) -> int:
	var mainhand: String = get_main_hand_item(npc_id)
	var weapon_damage: int = 0
	if not mainhand.is_empty():
		var entry: Dictionary = _resolve_item(mainhand)
		weapon_damage = int(entry.get("damage", 0))
	# Sum stat mods from ALL equipment (mainhand weapon + armor + accessories).
	# Different classes' weapons have different stat_mods (Scavenger str,
	# Technician int, Survivor con, Striker str, Riftbinder int+wis,
	# Warden str+con), so each class benefits from its own primary stats.
	# The weapon's own stat_mods determine the class's "innate" attack
	# bonus, while armor and accessory stat_mods add additional bonuses.
	var mods: Dictionary = get_stat_mods(npc_id)
	var mod_bonus: int = 0
	for k in mods:
		mod_bonus += int(mods[k])
	return weapon_damage + mod_bonus


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


## Returns combined combat stats (attack + defense) from equipment for
## the given npc_id. Used by EncounterBuilder to wire real equipment
## into combat encounters.
func get_combat_stats(npc_id: String) -> Dictionary:
	return {
		"attack": get_attack(npc_id),
		"defense": get_defense(npc_id),
		"attack_range": get_weapon_range(npc_id),
	}


# ---------------------------------------------------------------------------
# Snapshot / restore (save/load in Phase 8)
# ---------------------------------------------------------------------------

func get_snapshot() -> Dictionary:
	return {"equipment_state": _equipment_state.duplicate(true)}


func restore_from_snapshot(snap: Dictionary) -> void:
	_equipment_state.clear()
	for k in snap.get("equipment_state", {}):
		_equipment_state[k] = (snap.equipment_state[k] as Dictionary).duplicate(true)
