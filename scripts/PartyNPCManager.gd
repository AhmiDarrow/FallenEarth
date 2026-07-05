## PartyNPCManager — Tracks joinable NPCs and the active party.
##
## Phase 3 ships a placeholder: `available_npcs` is a hard-coded list of
## 2-3 test NPCs so the Party screen is testable. Real procedural
## generation (per-biome spawns, invite conditions, race/class/gender
## combinations) lands in Phase 5 per the plan.
##
## State:
##   - `available_npcs: Array[Dictionary]` — NPCs in the world, not in party
##   - `party_members: Array[Dictionary]` — NPCs currently in the party
##
## Each NPC dict has:
##   { id, name, race, class, gender, level, role, sprite_path, equipment,
##     faction_rep_requirements, quest_unlock }
##
## Equipment is a 9-slot dict (head, chest, legs, boots, mainhand,
## offhand, tool, acc1, acc2). For Phase 3 the equipment is all empty;
## Phase 4's EquipmentManager will populate it. The Party screen reads
## this dict to show what the member has equipped.
##
## Signals:
##   - available_changed() — list of available NPCs changed
##   - party_changed() — list of party members changed
##   - npc_invited(npc_id) — an NPC moved from available to party
##   - npc_dismissed(npc_id) — an NPC moved from party to available
##
## Persistence: like InventoryManager, this is non-persistent in
## Phase 3. GameState.SaveManager will be extended in Phase 8.
extends Node

signal available_changed
signal party_changed
signal npc_invited(npc_id: String)
signal npc_dismissed(npc_id: String)

# Slots used in the equipment sub-dict (matches EquipmentManager from Phase 4)
const EQUIP_SLOTS := ["head", "chest", "legs", "boots", "mainhand", "offhand", "tool", "acc1", "acc2"]

var available_npcs: Array = []
var party_members: Array = []


func _ready() -> void:
	_seed_test_npcs()
	print("[PartyNPCManager] Initialized (%d available, %d party)." % [available_npcs.size(), party_members.size()])


## Phase 3: seed a small set of test NPCs so the Party screen has
## something to show. Phase 5 replaces this with procedural generation.
func _seed_test_npcs() -> void:
	available_npcs = [
		{
			"id": "npc_test_scavenger",
			"name": "Mira the Scavenger",
			"race": "human",
			"class": "Scavenger",
			"gender": "female",
			"level": 3,
			"role": "scavenger",
			"sprite_path": "res://assets/characters/human_female/human_female_base.png",
			"faction_rep_requirements": {},
			"quest_unlock": null,
			"equipment": _empty_equipment(),
		},
		{
			"id": "npc_test_medic",
			"name": "Jak the Medic",
			"race": "human",
			"class": "Survivor",
			"gender": "male",
			"level": 5,
			"role": "medic",
			"sprite_path": "res://assets/characters/human_male/human_male_base.png",
			"faction_rep_requirements": {"Iron Pact": 5},
			"quest_unlock": null,
			"equipment": _empty_equipment(),
		},
		{
			"id": "npc_test_warden",
			"name": "Sira the Warden",
			"race": "human",
			"class": "Warden",
			"gender": "female",
			"level": 8,
			"role": "warden",
			"sprite_path": "res://assets/characters/human_female/human_female_base.png",
			"faction_rep_requirements": {"Iron Pact": 20},
			"quest_unlock": null,
			"equipment": _empty_equipment(),
		},
	]


func _empty_equipment() -> Dictionary:
	var out: Dictionary = {}
	for slot in EQUIP_SLOTS:
		out[slot] = ""  # "" = empty
	return out


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns the NPC dict with the given id from either list, or {}.
func get_npc(npc_id: String) -> Dictionary:
	for n in party_members:
		if str(n.get("id", "")) == npc_id:
			return n
	for n in available_npcs:
		if str(n.get("id", "")) == npc_id:
			return n
	return {}


## Invite an available NPC to the party. Returns true on success.
## If the NPC is not in `available_npcs`, returns false.
func invite(npc_id: String) -> bool:
	for i in available_npcs.size():
		if str(available_npcs[i].get("id", "")) == npc_id:
			var npc: Dictionary = available_npcs[i]
			available_npcs.remove_at(i)
			party_members.append(npc)
			emit_signal("npc_invited", npc_id)
			emit_signal("available_changed")
			emit_signal("party_changed")
			print("[PartyNPCManager] Invited %s to party" % npc_id)
			return true
	return false


## Dismiss a party member back to the available list. The NPC goes
## back into `available_npcs` (in Phase 6 they would return to the
## base instead). Returns true on success.
func dismiss(npc_id: String) -> bool:
	for i in party_members.size():
		if str(party_members[i].get("id", "")) == npc_id:
			var npc: Dictionary = party_members[i]
			party_members.remove_at(i)
			available_npcs.append(npc)
			emit_signal("npc_dismissed", npc_id)
			emit_signal("available_changed")
			emit_signal("party_changed")
			print("[PartyNPCManager] Dismissed %s" % npc_id)
			return true
	return false


## Restore the available/party state from a snapshot dict (used by
## SaveManager in Phase 8).
func restore_from_snapshot(snap: Dictionary) -> void:
	available_npcs.clear()
	party_members.clear()
	for n in snap.get("available_npcs", []):
		available_npcs.append(n)
	for n in snap.get("party_members", []):
		party_members.append(n)
	emit_signal("available_changed")
	emit_signal("party_changed")


## Snapshot the state for save/load.
func get_snapshot() -> Dictionary:
	return {
		"available_npcs": available_npcs.duplicate(true),
		"party_members": party_members.duplicate(true),
	}
