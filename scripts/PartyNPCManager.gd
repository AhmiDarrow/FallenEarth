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

const INVENTORY_PATH := "/root/InventoryHandler"
const EQUIPMENT_PATH := "/root/EquipmentManager"
const PROGRESSION_PATH := "/root/ProgressionManager"
const FACTION_PATH := "/root/GameState"

signal available_changed
signal party_changed
signal npc_invited(npc_id: String)
signal npc_dismissed(npc_id: String)
# Slots used in the equipment sub-dict
const EQUIP_SLOTS := ["armor", "mainhand", "offhand", "tool", "acc1", "acc2"]


# Loaded in _ready
var _templates: Array = []
var _name_parts: Dictionary = {}
var _classes: Array = []
var _races: Array = []
var _spawn_rules: Dictionary = {}
var _faction_names: Array = []
# v0.7.0: per-biome themes (title, name_prefix, origin_pref) loaded
# from joinable_npc_templates.json's `_biome_themes` section.
var _biome_themes: Dictionary = {}
# v0.7.0: per-faction themes (name_prefix, origin_pref, preferred_race) loaded from
# joinable_npc_templates.json's `_faction_themes` section. Used to flavor
# NPCs spawned in faction-owned settlements.
var _faction_themes: Dictionary = {}
var _rng: RandomNumberGenerator

var available_npcs: Array = []
var party_members: Array = []


func _ready() -> void:
	_rng = RandomNumberGenerator.new()
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
	var dr := get_node_or_null("/root/DataRegistry")
	if dr == null:
		push_error("[PartyNPCManager] DataRegistry not available")
		return
	# Templates
	var templates_data: Variant = dr.get_data("joinable_npc_templates")
	if templates_data is Dictionary:
		_templates = templates_data.get("templates", [])
		_spawn_rules = templates_data.get("_spawn_rules", {})
		# v0.7.0: per-biome + per-faction themes
		_biome_themes = templates_data.get("_biome_themes", {})
		_faction_themes = templates_data.get("_faction_themes", {})
	# Name parts
	var name_data: Variant = dr.get_data("npc_name_parts")
	if name_data is Dictionary:
		_name_parts = name_data
	# Classes
	var classes_data: Variant = dr.get_data("classes")
	if classes_data is Array:
		_classes = classes_data
	# Races
	var races_data: Variant = dr.get_data("races")
	if races_data is Dictionary:
		_races = []
		for origin in ["upworld", "underworld"]:
			for race_name in races_data.get(origin, {}):
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
			"sprite_path": "res://assets/characters/human_female/human_female_S.png",
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
			"sprite_path": "res://assets/characters/human_male/human_male_S.png",
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
			"sprite_path": "res://assets/characters/human_female/human_female_S.png",
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
			npc_invited.emit(npc_id)
			available_changed.emit()
			party_changed.emit()
			print("[PartyNPCManager] Invited %s to party" % npc_id)
			return true
	return false


func dismiss(npc_id: String) -> bool:
	for i in party_members.size():
		if str(party_members[i].get("id", "")) == npc_id:
			var npc: Dictionary = party_members[i]
			party_members.remove_at(i)
			available_npcs.append(npc)
			npc_dismissed.emit(npc_id)
			available_changed.emit()
			party_changed.emit()
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
	available_changed.emit()
	party_changed.emit()


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
	available_changed.emit()
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


## v0.7.0: roll a template that's compatible with the given biome
## AND faction. Filters by both:
##   - `preferred_biomes = null` OR includes the biome
##   - `preferred_factions = null` OR includes the faction
##
## Weighting (v0.7.0 balance):
##   - match_both (biome AND faction match): 4x weight
##   - match_faction_only (faction matches, biome doesn't): 3x weight
##   - match_biome_only (biome matches, faction doesn't): 2x weight
##   - specific + no match (has a preference but neither matches): 1x
##   - universal (no preferences at all): 1x
##
## Faction matches get a stronger boost than biome matches because
## "the world needs to balance the weights between settlements to
## faction ratio" — settlements reflect their owning faction.
##
## Returns {} if no template is eligible.
func _roll_template_for_settlement(biome: String, faction: String) -> Dictionary:
	if _templates.is_empty():
		return {}
	var match_both: Array = []
	var match_faction_only: Array = []
	var match_biome_only: Array = []
	var universal: Array = []
	for t in _templates:
		var preferred_b: Variant = t.get("preferred_biomes", null)
		var preferred_f: Variant = t.get("preferred_factions", null)
		var biome_ok: bool = (preferred_b == null) or (preferred_b is Array and (preferred_b as Array).has(biome))
		var faction_ok: bool = (preferred_f == null) or (preferred_f is Array and (preferred_f as Array).has(faction))
		var has_b_pref: bool = (preferred_b != null)
		var has_f_pref: bool = (preferred_f != null)
		if has_b_pref and has_f_pref and biome_ok and faction_ok:
			match_both.append(t)
		elif has_f_pref and faction_ok:
			# faction-specific template, faction matches (biome may or may not)
			match_faction_only.append(t)
		elif has_b_pref and biome_ok:
			# biome-specific template, biome matches (faction may or may not)
			match_biome_only.append(t)
		else:
			# universal (no preferences) OR specific template that doesn't match
			universal.append(t)
	# Build the weighted pool with category-based multipliers.
	# We append each category's entries N times where N is the multiplier.
	var pool: Array = []
	pool.append_array(match_both.duplicate(true))
	pool.append_array(match_both.duplicate(true))
	pool.append_array(match_both.duplicate(true))
	pool.append_array(match_both.duplicate(true))  # 4x
	pool.append_array(match_faction_only.duplicate(true))
	pool.append_array(match_faction_only.duplicate(true))
	pool.append_array(match_faction_only.duplicate(true))  # 3x
	pool.append_array(match_biome_only.duplicate(true))
	pool.append_array(match_biome_only.duplicate(true))  # 2x
	pool.append_array(universal)  # 1x
	if pool.is_empty():
		# Last resort: any template
		pool = _templates.duplicate(true)
	if pool.is_empty():
		return {}
	var total: float = 0.0
	for t in pool:
		total += float(t.get("weight", 1))
	if total <= 0.0:
		return {}
	var pick: float = randf() * total
	for t in pool:
		pick -= float(t.get("weight", 1))
		if pick <= 0.0:
			return t
	return pool.back()


## v0.7.0 backward-compat: roll a template that's compatible with the
## given biome only (no faction filter). Used by the old
## `spawn_for_hex` (hex visit, no settlement context).
func _roll_template_for_biome(biome: String) -> Dictionary:
	return _roll_template_for_settlement(biome, "")


## v0.7.0: generate a deterministic hash from a hex_key. Used to seed
## the settlement spawn RNG so the same settlement always shows the
## same NPCs across runs.
func _hash_hex_key(hex_key: String) -> int:
	# FNV-1a hash (32-bit) — small, fast, no dependencies
	var h: int = 2166136261
	for i in hex_key.length():
		h = (h ^ hex_key.unicode_at(i)) & 0xFFFFFFFF
		h = (h * 16777619) & 0xFFFFFFFF
	return h


## v0.7.0: spawn biome- AND faction-appropriate NPCs for a
## settlement. Called by Settlement._resolve_resident_npcs to generate
## the NPC pool for a given town. The result is deterministic:
## same hex_key + same biome + same faction + same town_size → same NPCs.
## The NPCs are appended to `available_npcs` and their ids returned.
##
## Parameters:
##   hex_key:   the hex coordinates, e.g. "5,7"
##   biome:     the hex's biome name, e.g. "Neon Bogs"
##   faction:   the settlement's faction, e.g. "Iron Accord" (may be
##              empty if the town is unaligned)
##   town_size: "small" / "medium" / "large" (drives NPC count)
##
## Returns the list of spawned NPC dicts.
func spawn_for_settlement(hex_key: String, biome: String, faction: String, town_size: String) -> Array:
	var max_residents: int = 2
	match town_size:
		"small": max_residents = 1
		"medium": max_residents = 2
		"large": max_residents = 3
	# Deterministic seed for the settlement spawn (so the same hex always
	# shows the same NPCs). Uses a local RandomNumberGenerator instance.
	var seed_val: int = _hash_hex_key(hex_key + "|" + biome + "|" + faction)
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_val
	# Read player level for level scaling
	var prog: Node = get_node_or_null(PROGRESSION_PATH)
	var player_level: int = int(prog.level) if prog != null else 1
	# Generate the residents
	var residents: Array = []
	for i in max_residents:
		var tpl: Dictionary = _roll_template_for_settlement(biome, faction)
		if tpl.is_empty():
			continue
		if not _template_eligible(tpl, player_level):
			continue
		var npc: Dictionary = _generate_npc_for_settlement(tpl, player_level, biome, faction, hex_key, i)
		npc["spawn_hex"] = hex_key
		npc["settlement_resident"] = true
		npc["settlement_faction"] = faction
		available_npcs.append(npc)
		residents.append(npc)
	return residents


## v0.7.0: variant of _generate_npc_from_template that uses both biome
## AND faction themes. Faction theme takes priority (faction identity
## is stronger than biome identity for naming/race).
func _generate_npc_for_settlement(tpl: Dictionary, player_level: int, biome: String, faction: String, hex_key: String, idx: int) -> Dictionary:
	# All rand* calls below use the local _rng instance set by the caller.
	var biome_theme: Dictionary = _biome_themes.get(biome, {})
	var faction_theme: Dictionary = _faction_themes.get(faction, {})
	# Faction theme takes priority for name_prefix + origin_pref.
	# Biome theme contributes the role title.
	var role_title: String = str(biome_theme.get("title", tpl.get("title", "wanderer")))
	var name_prefix: String = str(faction_theme.get("name_prefix", biome_theme.get("name_prefix", "")))
	var origin_pref: String = str(faction_theme.get("origin_pref", faction_theme.get("race_pref", biome_theme.get("race_pref", ""))))
	var preferred_race: String = str(faction_theme.get("preferred_race", ""))
	var id: String = "npc_settle_%s_%s_%d" % [hex_key.replace(",", "_"), str(tpl.get("id", "npc")).replace(" ", "_"), idx]
	# Origin: use origin_pref if set, otherwise 70/30 upworld/underworld
	var origin: String = origin_pref if origin_pref != "" else ("Upworld" if randf() < 0.7 else "Underworld")
	var class_data: Dictionary = _pick_class()
	var race_data: Dictionary = _pick_race(origin)
	var gender: String = "male" if randf() < 0.5 else "female"
	var level_lo: int = int(_spawn_rules.get("level_range", [-10, 10])[0])
	var level_hi: int = int(_spawn_rules.get("level_range", [-10, 10])[1])
	var npc_level: int = clampi(player_level + _rng.randi_range(level_lo, level_hi), 1, 256)
	# Build a flavor-aware name: prefix + random first + random last
	var bucket: String = "upworld" if origin == "Upworld" else "underworld"
	var parts: Dictionary = _name_parts.get(bucket, _name_parts.get("neutral", {}))
	var first: Array = parts.get("first", ["Kira"])
	var last: Array = parts.get("last", ["Morrow"])
	var f: String = str(first[randi() % first.size()])
	var l: String = str(last[randi() % last.size()])
	var npc_name: String = ("%s " % name_prefix if name_prefix != "" else "") + "%s %s" % [f, l]
	var tier: int = int(tpl.get("tier", 0))
	var equipment: Dictionary = _empty_equipment()
	if EquipmentManager_has() and class_data.has("name"):
		var em: Node = get_node_or_null(EQUIPMENT_PATH)
		if em != null:
			var w: Dictionary = em.get_weapon(str(class_data.get("name", "")), tier)
			if not w.is_empty():
				equipment["mainhand"] = str(w.get("id", ""))
			var armor_type: String = em.get_starting_armor_type(str(class_data.get("name", "")))
			var a: Dictionary = em.get_armor(armor_type, tier)
			if not a.is_empty():
				equipment["armor"] = str(a.get("id", ""))
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
		"role": role_title,
		"sprite_path": _race_sprite(race_data, gender),
		"faction_rep_requirements": fr,
		"quest_unlock": tpl.get("requires_quest", null),
		"template_id": str(tpl.get("id", "")),
		"equipment": equipment,
		"rarity": str(tpl.get("rarity", "common")),
		"tier": tier,
		"biome": biome,
		"faction": faction,
	}
	return npc


## v0.7.0: clear all settlement-resident NPCs (those flagged with
## `settlement_resident: true`). Called by Settlement._resolve_resident_npcs
## at the start of a refresh so a re-enter doesn't accumulate duplicates.
## Pass an empty hex_key to clear ALL settlement residents across all hexes.
func clear_settlement_residents(hex_key: String = "") -> void:
	var keep: Array = []
	for n in available_npcs:
		var is_resident: bool = bool(n.get("settlement_resident", false))
		var same_hex: bool = (hex_key == "" or str(n.get("spawn_hex", "")) == hex_key)
		if is_resident and same_hex:
			continue
		keep.append(n)
	available_npcs = keep


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
	var npc_level: int = clampi(player_level + _rng.randi_range(level_lo, level_hi), 1, 256)
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
			# Equip the class's armor suit at the chosen tier
			var armor_type: String = em.get_starting_armor_type(str(class_data.get("name", "")))
			var a: Dictionary = em.get_armor(armor_type, tier)
			if not a.is_empty():
				equipment["armor"] = str(a.get("id", ""))
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
	return "res://assets/characters/%s_%s/%s_%s_S.png" % [vis, g, vis, g]


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
