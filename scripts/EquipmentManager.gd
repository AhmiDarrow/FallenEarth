## EquipmentManager — Manages inventory, equipment slots, and procedural item generation

class_name EquipmentManager extends Node


signal inventory_changed()
signal item_equipped(slot: String, item_id: String)
signal item_removed(item_id: String)


const EQUIPMENT_SLOTS := ["head", "torso", "body", "arms", "legs", "weapon", "back", "accessory"]

# Visual slot mapping for CharacterVisual (torso/body, back/accessory)
const VISUAL_SLOT_MAP := {
	"body": "torso",
	"accessory": "back",
	"torso": "torso",
	"back": "back"
}

@export var inventory: Array[Dictionary] = []

var equipped_items: Dictionary = {
	"head": null,
	"body": null,
	"arms": null,
	"legs": null,
	"weapon": null,
	"accessory": null
}


func _ready() -> void:
	print("[EquipmentManager] Initialized (v0.2.0). %d slots." % equipped_items.size())


# ===================================================================
# -- Visuals --
# ===================================================================

func get_equipment_visuals(item_id: String) -> Dictionary:
	"""Return visual layer ordering for the given item."""
	return {"layer_order": 0, "animation": "idle", "offset": Vector2i.ZERO}


# ===================================================================
# -- Item generation --
# ===================================================================

## Generate equipment stats based on tier (1–5). Higher tiers = better bonuses.
func generate_procedural_stats(tier: int) -> Dictionary:
	var stats := {"durability": randi_range(10, 10 * tier)}
	
	for i in range(maxi(tier - 2, 0)):
		var slot = str(i + 1)
		stats["stat_mod_%s" % slot] = {
			"strength": clampf(randf() * (tier - i), 0.0, 5.0),
			"defense": clampf(randf() * (tier - i) / 2.0, 0.0, 3.0),
			"speed": clampf(randf() * (tier - i) / 4.0, 0.0, 2.0)
		}
	
	stats["quality_bonus"] = tier * 10
	return stats


## Generate a procedural equipment item
func generate_procedural_item(tier: int = 3, rarity: String = "common", slot_hint: String = "") -> Dictionary:
	if rarity not in ["common", "uncommon", "rare", "epic", "legendary"]:
		rarity = "common"
	
	var name := "Procedural %s" % (rarity.capitalize() if rarity != "common" else "")
	var item_type := slot_hint if slot_hint != "" else ("weapon" if tier >= 2 else "armor")
	
	return {
		"id": str(randi_range(1000, 9999)),
		"name": "%s %s" % [name, item_type],
		"type": item_type,
		"slot": slot_hint if slot_hint != "" else ("weapon" if tier >= 2 else "body"),
		"tier": clampi(tier, 1, 5),
		"rarity": rarity,
		"stats": generate_procedural_stats(clampi(tier, 1, 5))
	}


# ===================================================================
# -- Inventory management --

func add_to_inventory(item: Dictionary) -> bool:
	if item == null or not (item is Dictionary):
		push_error("[EquipmentManager] Invalid item to add.")
		return false
	
	inventory.append(item.duplicate(true))
	inventory_changed.emit()
	print("[EquipmentManager] Item added: %s (%d total)" % [item.get("name", "Unknown"), inventory.size()])
	return true


func remove_from_inventory(item_id: String) -> bool:
	for i in range(inventory.size() - 1, -1, -1):
		if inventory[i].get("id") == item_id:
			inventory.remove_at(i)
			item_removed.emit(item_id)
			print("[EquipmentManager] Removed %s." % item_id)
			return true
	return false


# ===================================================================
# -- Equipment slot management --

## Equip an item (by id or by data dict) to a specific slot.
func equip_item(slot: String, item_data: Variant) -> bool:
	if not slot in equipped_items:
		push_error("[EquipmentManager] Invalid slot: %s" % slot)
		return false
	
	# Support both full Dictionary item or plain id String (legacy)
	var item_id: String = ""
	if item_data is Dictionary:
		item_id = str(item_data.get("id", ""))
	elif item_data is String:
		item_id = item_data
	else:
		item_id = str(item_data)
	
	if item_id == "":
		push_error("[EquipmentManager] Cannot equip empty item data.")
		return false
	
	equipped_items[slot] = item_id
	item_equipped.emit(slot, item_id)
	print("[EquipmentManager] Equipped %s to slot '%s'." % [item_id, slot])
	
	# Move from inventory to equipped (don't delete — it may be re-equippable)
	for i in range(inventory.size() - 1, -1, -1):
		if inventory[i].get("id") == item_id:
			inventory.remove_at(i)
			print("[EquipmentManager] Item removed from inventory after equipping.")
			break
	
	return true


## Unequip an item from a slot (puts it back into inventory)
func unequip_item(slot: String) -> Dictionary:
	if not equipped_items.has(slot):
		push_error("[EquipmentManager] Slot %s does not exist." % slot)
		return {}
	
	if equipped_items[slot] == null:
		return {}
	
	var item_id: Variant = equipped_items[slot]
	equipped_items[slot] = null
	
	item_removed.emit(str(item_id))
	print("[EquipmentManager] Unequipped from slot '%s'." % slot)
	return {"id": item_id}


## Save equipment state for the given slot (legacy compat — supports id string or dict)
func save_equipmentslot(slot: String, item_data: Variant) -> void:
	if item_data is String:
		equip_item(slot, {"id": item_data})
	else:
		equip_item(slot, item_data)


# Get all equipment slots (returns a frozen copy)
func get_equipment_slots() -> Dictionary:
	return equipped_items.duplicate(true)


## Check if any slot has a specific item equipped
func is_item_equipped(item_id: String) -> bool:
	for slot_key in equipped_items:
		if equipped_items[slot_key] == item_id:
			return true
	return false

## Get equipment visuals dict ready for CharacterVisual (maps internal slots to visual slots + filenames)
func get_visual_equipment() -> Dictionary:
	var vis := {}
	for slot in equipped_items:
		var id = equipped_items[slot]
		if id == null or id == "":
			continue
		var vslot = VISUAL_SLOT_MAP.get(slot, slot)
		vis[vslot] = str(id)  # filename fragment; CharacterVisual will resolve actual asset
	return vis

