## PartyNPCManager — Tracks joinable NPCs and the active party.
##
## Phase 5: procedural spawn. When the player walks into a new local
## hubworld map, the manager rolls a spawn: 30% chance of spawning
## 0..1 NPC. The NPC is generated from a template (rarity-based) + a
## random race/class/gender from data/races.json and
## data/character_classes.json. Stats are scaled to be within
## `player_level ± 10` (configurable in joinable_npc_templates.json).
## Equipment: T1 weapon and T1 armor appropriate for the NPC's class
## (a Phase 4 EquipmentManager.get_weapon/get_armor call).
##
## Phase 3 placeholder behavior is still available: if `available_npcs`
## was seeded by a save (or by Phase 3's test), the procedural spawn
## is skipped.
##
## Invite conditions:
##   - min_player_level: absolute minimum level
##   - min_faction_rep: per-faction minimum reputation (null = any)
##   - faction_required: "any_specific" / "any_top_faction" / null
##   - requires_quest: optional mission id that must be active
## All conditions must be met (AND logic). can_invite returns true/false.
## get_invite_requirements_text returns a human-readable string.
##
## Signals (unchanged from Phase 3):
##   - available_changed, party_changed, npc_invited, npc_dismissed
##
## Persistence: like the rest of Phase 5, this is non-persistent for
## now. GameState.SaveManager is the canonical layer (Phase 8).
extends Node

const INVENTORY_PATH := "/root/InventoryManager"
const EQUIPMENT_PATH := "/root/EquipmentManager"
const PROGRESSION_PATH := "/root/ProgressionManager"
const FACTION_PATH := "/root/GameState"
const TEMPLATES_PATH := "res://data/joinable_npc_templates.json"
const NAME_PARTS_PATH := "res://data/npc_name_parts.json"
const CLASSES_PATH := "res://data/character_classes.json"
const RACES_PATH := "res://data/races.json"

signal available_changed
signal party_changed
signal npc_invited(npc_id: String)
signal npc_dismissed(npc_id: String)

# Slots used in the equipment sub-dict
const EQUIP_SLOTS := ["head", "chest", "legs", "boots", "mainhand", "offhand", "tool", "acc1", "acc2"]

# Loaded in _ready
var _templates: Array = []
var _name_parts: Dictionary = {}
var _classes: Array = []
var _races: Array = []
var _spawn_rules: Dictionary = {}
var _faction_names: Array = []

var available_npcs: Array = []
var party_members: Array = []


func _ready() -> void:
	_load_data()
	_load_faction_names()
	_seed_phase3_test_npcs()  # Phase 3 placeholder; if a save is loaded
	# this is replaced by restore_from_snapshot. The procedural spawn
	# runs lazily via spawn_for_hex when HubWorld enters a new map.
	print("[PartyNPCManager] Initialized (templates=%d, factions=%d)." % [
		_templates.size(), _faction_names.size()
	])


# ---------------------------------------------------------------------------
# Data loaders
# ---------------------------------------------------------------------------

func _load_data() -> void:
	# Templates
	if ResourceLoader.exists(TEMPLATES_PATH):
		var raw = load(TEMPLATES_PATH)
		var data = raw.data if "data" in raw else raw
		if data is Dictionary:
			_templates = data.get("templates", [])
			_spawn_rules = data.get("_spawn_rules", {})
	# Name parts
	if ResourceLoader.exists(NAME_PARTS_PATH):
		var raw2 = load(NAME_PARTS_PATH)
		var data2 = raw2.data if "data" in raw2 else raw2
		if data2 is Dictionary:
			_name_parts = data2
	# Classes
	if ResourceLoader.exists(CLASSES_PATH):
		var raw3 = load(CLASSES_PATH)
		var data3 = raw3
		if data3 is Array:
			_classes = data3
	# Races
	if ResourceLoader.exists(RACES_PATH):
		var raw4 = load(RACES_PATH)
		var data4 = raw4.data if "data" in raw4 else raw4
		if data4 is Dictionary:
			_races = []
			for origin in ["upworld", "underworld"]:
				for race_name in data4.get(origin, {}):
					_races.append({
						"name": race_name,
						"origin": origin.capitalize(),
					})


func _load_faction_names() -> void:
	_faction_names = []
	var gs: Node = get_node_or_null(FACTION_PATH)
	if gs != null and gs.has_method("get_faction_rep"):
		var rep: Dictionary = gs.get_faction_rep()
		for k in rep.keys():
			_faction_names.append(str(k))


# ---------------------------------------------------------------------------
# Phase 3 placeholder (test NPCs). Replaced by restore_from_snapshot in
## save/load (Phase 8), and by spawn_for_hex in Phase 5+ when the
## player enters a hex.
# ---------------------------------------------------------------------------

func _seed_phase3_test_npcs() -> void:
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
			"template_id": "phase3_test",
			"equipment": _empty_equipment(),
			"origin": "Upworld",
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
			"faction_rep_requirements": {"Iron Accord": 5},
			"quest_unlock": null,
			"template_id": "phase3_test",
			"equipment": _empty_equipment(),
			"origin": "Upworld",
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
			"faction_rep_requirements": {"Iron Accord": 20},
			"quest_unlock": null,
			"template_id": "phase3_test",
			"equipment": _empty_equipment(),
			"origin": "Upworld",
		},
	]


# ---------------------------------------------------------------------------
# Public API (from Phase 3)
# ---------------------------------------------------------------------------

func get_npc(npc_id: String) -> Dictionary:
	for n in party_members:
		if str(n.get("id", "")) == npc_id:
			return n
	for n in available_npcs:
		if str(n.get("id", "")) == npc_id:
			return n
	return {}


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


func get_snapshot() -> Dictionary:
	return {
		"available_npcs": available_npcs.duplicate(true),
		"party_members": party_members.duplicate(true),
	}


func restore_from_snapshot(snap: Dictionary) -> void:
	available_npcs.clear()
	party_members.clear()
	for n in snap.get("available_npcs", []):
		available_npcs.append(n)
	for n in snap.get("party_members", []):
		party_members.append(n)
	emit_signal("available_changed")
	emit_signal("party_changed")


func get_town_npcs(hex_key: String) -> Array:
	return []


# ---------------------------------------------------------------------------
# Phase 5: Procedural spawn + invite conditions
# ---------------------------------------------------------------------------

## Roll 0 or 1 NPCs for the given hex + player level. Called by
## HubWorld when the player enters a new local hubworld map. Returns
## the list of NPCs to add to available_npcs (empty list if no spawn).
## Player level comes from ProgressionManager.
func spawn_for_hex(hex_key: String, biome: String = "") -> Array:
	# Read player level
	var prog: Node = get_node_or_null(PROGRESSION_PATH)
	var player_level: int = int(prog.level) if prog != null else 1
	# Roll the spawn chance
	var spawn_chance: float = float(_spawn_rules.get("spawn_chance", 0.30))
	if randf() > spawn_chance:
		return []
	var max_per_hex: int = int(_spawn_rules.get("max_per_hex", 1))
	# Pick a template (weighted)
	var tpl: Dictionary = _roll_template()
	if tpl.is_empty():
		return []
	# Check the template against the player (level + faction + quest)
	if not _template_eligible(tpl, player_level):
		return []
	# Generate the NPC dict
	var npc: Dictionary = _generate_npc_from_template(tpl, player_level, biome)
	npc["spawn_hex"] = hex_key
	available_npcs.append(npc)
	emit_signal("available_changed")
	print("[PartyNPCManager] Spawned %s in %s (template=%s)" % [npc.get("name", "?"), hex_key, tpl.get("id", "?")])
	return [npc]


# Roll a template by weight. Returns {} if no templates loaded.
func _roll_template() -> Dictionary:
	if _templates.is_empty():
		return {}
	var total: float = 0.0
	for t in _templates:
		total += float(t.get("weight", 1))
	if total <= 0.0:
		return {}
	var pick: float = randf() * total
	for t in _templates:
		pick -= float(t.get("weight", 1))
		if pick <= 0.0:
			return t
	return _templates.back()


func _template_eligible(tpl: Dictionary, player_level: int) -> bool:
	if player_level < int(tpl.get("min_player_level", 0)):
		return false
	# Faction rep requirement
	var min_rep: Variant = tpl.get("min_faction_rep", null)
	if min_rep != null:
		var have: int = _faction_rep_for(tpl.get("faction_required", null))
		if have < int(min_rep):
			return false
	# Quest requirement (Phase 5 placeholder: any active mission counts)
	var quest_req: Variant = tpl.get("requires_quest", null)
	if quest_req != null:
		var mm: Node = get_node_or_null("/root/MissionManager")
		if mm != null and mm.has_method("get_active_missions"):
			var active: Array = mm.get_active_missions()
			if active.is_empty():
				return false
	return true


func _faction_rep_for(faction_id: Variant) -> int:
	# If faction_required is "any_specific" or "any_top_faction",
	# use the highest faction rep the player has. Otherwise use 0
	# (template without a specific faction check).
	var gs: Node = get_node_or_null(FACTION_PATH)
	if gs == null:
		return 0
	var rep: Dictionary = gs.get_faction_rep()
	var max_rep: int = 0
	for k in rep:
		var v: int = int(rep[k])
		if v > max_rep:
			max_rep = v
	return max_rep


# Generates a full NPC dict from a template + the player level. The
# NPC is unique (random id, random name, random race, random class,
# random gender, random role title). Stats are within
# `player_level ± 10` (configurable). Equipment is T1 weapon + T1
# armor appropriate for the class.
func _generate_npc_from_template(tpl: Dictionary, player_level: int, biome: String) -> Dictionary:
	var id: String = "npc_%s_%d" % [str(tpl.get("id", "npc")).replace(" ", "_"), randi() % 1000000]
	var origin: String = "Upworld" if randf() < 0.7 else "Underworld"
	var class_data: Dictionary = _pick_class()
	var race_data: Dictionary = _pick_race(origin)
	var gender: String = "male" if randf() < 0.5 else "female"
	var level_lo: int = int(_spawn_rules.get("level_range", [-10, 10])[0])
	var level_hi: int = int(_spawn_rules.get("level_range", [-10, 10])[1])
	var npc_level: int = clampi(player_level + randi_range(level_lo, level_hi), 1, 256)
	var npc_name: String = _generate_name(origin, class_data.get("name", "wanderer"), gender)
	var tier: int = int(tpl.get("tier", 0))
	# Equipment: T{tier} weapon + T{tier} armor (best-effort)
	var equipment: Dictionary = _empty_equipment()
	if EquipmentManager_has() and class_data.has("name"):
		var em: Node = get_node_or_null(EQUIPMENT_PATH)
		if em != null:
			var w: Dictionary = em.get_weapon(str(class_data.get("name", "")), tier)
			if not w.is_empty():
				equipment["mainhand"] = str(w.get("id", ""))
			# Equip one armor piece (head)
			for slot in ["head", "chest", "legs", "boots"]:
				var a: Dictionary = em.get_armor(str(class_data.get("name", "")), slot, tier)
				if not a.is_empty():
					equipment[slot] = str(a.get("id", ""))
					break
	# Invite requirements: copied from the template
	var fr: Dictionary = {}
	if tpl.get("min_faction_rep", null) != null:
		fr["any_faction"] = int(tpl.get("min_faction_rep"))
	var npc := {
		"id": id,
		"name": npc_name,
		"race": str(race_data.get("name", "Human")),
		"origin": origin,
		"class": str(class_data.get("name", "Wanderer")),
		"gender": gender,
		"level": npc_level,
		"role": str(tpl.get("title", "wanderer")),
		"sprite_path": _race_sprite(race_data, gender),
		"faction_rep_requirements": fr,
		"quest_unlock": tpl.get("requires_quest", null),
		"template_id": str(tpl.get("id", "")),
		"equipment": equipment,
		"rarity": str(tpl.get("rarity", "common")),
		"tier": tier,
	}
	return npc


# Small helper that respects the autoload (not registered yet at
# script parse time).
func EquipmentManager_has() -> bool:
	return get_node_or_null(EQUIPMENT_PATH) != null


func _pick_class() -> Dictionary:
	if _classes.is_empty():
		return {"name": "Wanderer"}
	return _classes[randi() % _classes.size()]


func _pick_race(origin: String) -> Dictionary:
	var pool: Array = []
	for r in _races:
		if r.get("origin", "") == origin:
			pool.append(r)
	if pool.is_empty():
		return {"name": "Human"}
	return pool[randi() % pool.size()]


func _generate_name(origin: String, npc_class: String, gender: String) -> String:
	# Origin -> bucket name
	var bucket: String = "upworld" if origin == "Upworld" else "underworld"
	var parts: Dictionary = _name_parts.get(bucket, _name_parts.get("neutral", {}))
	var first: Array = parts.get("first", ["Kira"])
	var last: Array = parts.get("last", ["Morrow"])
	var titles: Dictionary = _name_parts.get("titles", {})
	var role_titles: Array = titles.get(npc_class.to_lower(), parts.get("nick", []))
	var f: String = str(first[randi() % first.size()])
	var l: String = str(last[randi() % last.size()])
	var t: String = ""
	if role_titles.size() > 0 and randf() < 0.5:
		t = " " + str(role_titles[randi() % role_titles.size()])
	return "%s %s%s" % [f, l, t]


func _race_sprite(race_data: Dictionary, gender: String) -> String:
	# Map the race's visual_tag + gender to a sprite path
	var vis: String = str(race_data.get("visual_tag", "human"))
	var g: String = "male" if gender == "male" else "female"
	return "res://assets/characters/%s_%s/%s_%s_base.png" % [vis, g, vis, g]


func _empty_equipment() -> Dictionary:
	var out: Dictionary = {}
	for slot in EQUIP_SLOTS:
		out[slot] = ""
	return out


# ---------------------------------------------------------------------------
# Invite conditions check
# ---------------------------------------------------------------------------

## Returns true if the player meets the invite conditions for the NPC.
## Used by HubWorld (and the settlement's invite dialog) to enable the
## Invite button.
func can_invite(npc_id: String) -> bool:
	var npc: Dictionary = get_npc(npc_id)
	if npc.is_empty():
		return false
	var prog: Node = get_node_or_null(PROGRESSION_PATH)
	var player_level: int = int(prog.level) if prog != null else 1
	# Find the template by id
	var tpl_id: String = str(npc.get("template_id", ""))
	var tpl: Dictionary = {}
	for t in _templates:
		if str(t.get("id", "")) == tpl_id:
			tpl = t
			break
	if tpl.is_empty():
		# No template (e.g. Phase 3 placeholder) — fall back to
		# legacy: just check the level
		if int(npc.get("level", 1)) > player_level + 10:
			return false
		return true
	# Player must be at least at the template's level
	if player_level < int(tpl.get("min_player_level", 0)):
		return false
	# Faction rep
	var min_rep: Variant = tpl.get("min_faction_rep", null)
	if min_rep != null:
		if _faction_rep_for(tpl.get("faction_required", null)) < int(min_rep):
			return false
	# Quest
	var quest_req: Variant = tpl.get("requires_quest", null)
	if quest_req != null:
		var mm: Node = get_node_or_null("/root/MissionManager")
		if mm != null and mm.has_method("get_active_missions"):
			if mm.get_active_missions().is_empty():
				return false
	return true


## Returns a human-readable string of unmet invite requirements. Empty
## string if all conditions are met.
func get_invite_requirements_text(npc_id: String) -> String:
	var npc: Dictionary = get_npc(npc_id)
	if npc.is_empty():
		return ""
	var tpl_id: String = str(npc.get("template_id", ""))
	var tpl: Dictionary = {}
	for t in _templates:
		if str(t.get("id", "")) == tpl_id:
			tpl = t
			break
	if tpl.is_empty():
		return ""
	var lines: Array = []
	var prog: Node = get_node_or_null(PROGRESSION_PATH)
	var player_level: int = int(prog.level) if prog != null else 1
	var min_lvl: int = int(tpl.get("min_player_level", 0))
	if min_lvl > 0 and player_level < min_lvl:
		lines.append("Requires level %d (you are %d)" % [min_lvl, player_level])
	var min_rep: Variant = tpl.get("min_faction_rep", null)
	if min_rep != null:
		var have: int = _faction_rep_for(tpl.get("faction_required", null))
		lines.append("Requires faction rep %d (you have %d)" % [int(min_rep), have])
	var quest_req: Variant = tpl.get("requires_quest", null)
	if quest_req != null:
		lines.append("Requires an active quest")
	return "\n".join(lines)


func get_templates() -> Array:
	return _templates.duplicate()


func get_spawn_rules() -> Dictionary:
	return _spawn_rules.duplicate()
