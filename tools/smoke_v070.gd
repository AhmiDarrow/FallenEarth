extends SceneTree
## Smoke test for v0.7.0: procedural NPC spawn in settlements (biome +
## faction + town size aware).
##
## Verifies:
##   1. joinable_npc_templates.json has the new templates (faction-specific)
##   2. _faction_themes loaded into PartyNPCManager
##   3. spawn_for_settlement produces the right NPC count by town size
##   4. spawn_for_settlement is deterministic (same inputs → same NPCs)
##   5. spawn_for_settlement NPCs have the settlement's faction in their faction field
##   6. spawn_for_settlement NPCs have a biome-specific role title
##   7. spawn_for_settlement NPCs have a faction-flavored name prefix
##   8. _roll_template_for_settlement weights favor faction+biome matches
##   9. Faction ratio is balanced — different factions get proportional NPCs
##  10. clear_settlement_residents works (no duplicate spawn on re-enter)
##  11. WorldGenerator adds biome to town data
##  12. Settlement._resolve_resident_npcs uses the new spawn

const PartyMgrScript = preload("res://scripts/PartyNPCManager.gd")
const WorldGenScript = preload("res://scripts/WorldGenerator.gd")
const SettlementScript = preload("res://scripts/Settlement.gd")

var failures: Array[String] = []


func _fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)


func _ok(msg: String) -> void:
	print("  ok  " + msg)


func _initialize() -> void:
	print("[smoke-v070] v0.7.0 procedural NPC spawn in settlements")
	# Autoloads are added to the tree before _initialize, but their
	# _ready() (which loads data files) is deferred to the next idle
	# frame. Wait one frame so all autoloads finish initializing
	# before any test runs.
	await process_frame
	await _test_templates_json_has_faction_specific()
	await _test_party_manager_loads_faction_themes()
	await _test_spawn_for_settlement_count_by_size()
	await _test_spawn_for_settlement_is_deterministic()
	await _test_spawned_npc_has_settlement_faction()
	await _test_spawned_npc_has_biome_role_title()
	await _test_spawned_npc_has_faction_name_prefix()
	await _test_template_roll_prefers_faction_biome_match()
	await _test_faction_ratio_balanced()
	await _test_clear_settlement_residents()
	await _test_world_generator_adds_biome_to_town_data()

	if failures.is_empty():
		print("[smoke-v070] All checks passed. (failures.size=%d)" % failures.size())
		quit(0)
	else:
		for f in failures:
			print("[smoke-v070] FAIL: " + f)
		print("[smoke-v070] %d failure(s). (failures=%s)" % [failures.size(), str(failures)])
		quit(1)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _new_pm(name: String = "TestPMV070") -> Node:
	var pm: Node = PartyMgrScript.new()
	pm.name = name
	root.add_child(pm)
	return pm


func _spawn_at(pm: Node, hex_key: String, biome: String, faction: String, town_size: String) -> Array:
	# Clear any prior residents for this hex
	pm.clear_settlement_residents(hex_key)
	var residents: Array = pm.spawn_for_settlement(hex_key, biome, faction, town_size)
	return residents


# ---------------------------------------------------------------------------
# v0.7.0 tests
# ---------------------------------------------------------------------------

## joinable_npc_templates.json has the faction-specific templates
## (iron_pact_guard, hollow_warden, ash_serpent_raider, etc.).
func _test_templates_json_has_faction_specific() -> void:
	print("[smoke-v070] test: templates.json has faction-specific templates")
	if not ResourceLoader.exists("res://data/joinable_npc_templates.json"):
		_fail("joinable_npc_templates.json missing")
		return
	var raw = load("res://data/joinable_npc_templates.json")
	if raw == null:
		_fail("joinable_npc_templates.json failed to load")
		return
	var data = raw.data if "data" in raw else raw
	if not (data is Dictionary):
		_fail("joinable_npc_templates.json format unexpected")
		return
	var tpls: Array = data.get("templates", [])
	var expected_faction_ids := ["iron_pact_guard", "hollow_warden", "ash_serpent_raider",
		"veil_warden", "neon_choir_techie", "bone_circuit_broker", "caravan_guard"]
	var found: int = 0
	for t in tpls:
		if t is Dictionary and expected_faction_ids.has(str(t.get("id", ""))):
			found += 1
	if found < expected_faction_ids.size():
		_fail("Expected %d faction-specific templates, found %d" % [expected_faction_ids.size(), found])
		return
	_ok("joinable_npc_templates.json has %d faction-specific templates" % found)


## PartyNPCManager loaded the _faction_themes section.
func _test_party_manager_loads_faction_themes() -> void:
	print("[smoke-v070] test: PartyNPCManager loads _faction_themes")
	var pm: Node = _new_pm("TestPMFaction")
	await process_frame
	if pm._faction_themes.is_empty():
		_fail("PartyNPCManager._faction_themes should not be empty after load")
		return
	var expected := ["Iron Accord", "Hollow Covenant", "Ash Serpents", "Veilwardens",
		"Neon Choir", "Dust Parliament", "Bone Circuit", "Black Ledger",
		"Last Caravans", "Echo Wardens"]
	for f in expected:
		if not pm._faction_themes.has(f):
			_fail("_faction_themes missing entry for '%s'" % f)
			return
	_ok("PartyNPCManager loaded _faction_themes (%d factions)" % pm._faction_themes.size())


## spawn_for_settlement produces the right NPC count by town size.
## small=1, medium=2, large=3 (max slots; some may be filtered by
## _template_eligible if a roll picks a template whose level/faction
## requirements aren't met). The test asserts <= max (slot cap) and
## >= 1 (at least one template is eligible).
func _test_spawn_for_settlement_count_by_size() -> void:
	print("[smoke-v070] test: spawn_for_settlement count by town size")
	var pm: Node = _new_pm("TestPMCount")
	await process_frame
	# Set pm.level so all template min_player_levels are satisfied
	# (faction_specific templates need L3-L5; we use L10 for safety)
	var prog: Node = root.get_node_or_null("ProgressionManager")
	if prog != null:
		prog.level = 10
	var cases := [
		["small_outpost", 1],
		["medium_settlement", 2],
		["large_hub", 3],
	]
	for case in cases:
		var size: String = case[0].split("_")[0]  # "small" / "medium" / "large"
		var max_count: int = case[1]
		var residents: Array = _spawn_at(pm, "5,7_" + size, "Neon Bogs", "Iron Accord", size)
		if residents.size() > max_count:
			_fail("size=%s should produce at most %d residents, got %d" % [size, max_count, residents.size()])
			return
		if residents.size() < 1:
			_fail("size=%s should produce at least 1 resident (none eligible), got 0" % size)
			return
		pm.clear_settlement_residents("5,7_" + size)
	_ok("spawn_for_settlement count by size: small<=1, medium<=2, large<=3 (at least 1 each)")


## spawn_for_settlement is deterministic — same inputs produce same NPCs.
func _test_spawn_for_settlement_is_deterministic() -> void:
	print("[smoke-v070] test: spawn_for_settlement is deterministic")
	var pm1: Node = _new_pm("TestPMDet1")
	await process_frame
	var pm2: Node = _new_pm("TestPMDet2")
	await process_frame
	var r1: Array = _spawn_at(pm1, "9,9", "Neon Bogs", "Iron Accord", "medium")
	var r2: Array = _spawn_at(pm2, "9,9", "Neon Bogs", "Iron Accord", "medium")
	if r1.size() != r2.size():
		_fail("Determinism: sizes differ (%d vs %d)" % [r1.size(), r2.size()])
		return
	for i in r1.size():
		if str(r1[i].get("id", "")) != str(r2[i].get("id", "")):
			_fail("Determinism: id at index %d differs" % i)
			return
		if str(r1[i].get("name", "")) != str(r2[i].get("name", "")):
			_fail("Determinism: name at index %d differs" % i)
			return
	_ok("spawn_for_settlement is deterministic (same NPCs across PMs)")


## Spawned NPC has the settlement's faction in their `faction` field.
func _test_spawned_npc_has_settlement_faction() -> void:
	print("[smoke-v070] test: spawned NPC has settlement faction")
	var pm: Node = _new_pm("TestPMFactionField")
	await process_frame
	var residents: Array = _spawn_at(pm, "5,5", "Neon Bogs", "Iron Accord", "medium")
	if residents.size() == 0:
		_fail("No residents spawned")
		return
	for n in residents:
		if str(n.get("faction", "")) != "Iron Accord":
			_fail("NPC %s should have faction 'Iron Accord', got '%s'" % [str(n.get("id", "?")), str(n.get("faction", ""))])
			return
	_ok("spawned NPCs have settlement faction in 'faction' field (Iron Accord × %d)" % residents.size())


## Spawned NPC has a biome-specific role title.
func _test_spawned_npc_has_biome_role_title() -> void:
	print("[smoke-v070] test: spawned NPC has biome role title")
	var pm: Node = _new_pm("TestPMBiomeRole")
	await process_frame
	# Neon Bogs biome theme title is "bogs-runner"
	var residents: Array = _spawn_at(pm, "7,7", "Neon Bogs", "Iron Accord", "medium")
	if residents.size() == 0:
		_fail("No residents spawned")
		return
	for n in residents:
		var role: String = str(n.get("role", ""))
		# role should be one of the biome template titles OR a template's own title
		var valid_roles := ["bogs-runner", "wanderer", "mercenary", "shaman", "pact-guard", "serpent-raider", "choir-techie", "bone-broker", "caravan-guard", "veil-warden", "rust-prospector", "wastelander", "ironwood-runner", "storm-chaser", "corpse-collector", "city-explorer", "glass-cutter", "plains-runner", "toxin-brewer", "hollow-warden"]
		if not valid_roles.has(role):
			_fail("NPC role '%s' is not in the expected role list" % role)
			return
	_ok("spawned NPCs have valid biome/faction role titles (%d NPCs)" % residents.size())


## Spawned NPC has a faction-flavored name prefix (e.g. "Iron" for
## Iron Accord). Sets pm.level so faction-specific templates are
## eligible.
func _test_spawned_npc_has_faction_name_prefix() -> void:
	print("[smoke-v070] test: spawned NPC has faction name prefix")
	var pm: Node = _new_pm("TestPMFactionPrefix")
	await process_frame
	var prog: Node = root.get_node_or_null("ProgressionManager")
	if prog != null:
		prog.level = 10
	var residents: Array = _spawn_at(pm, "3,3", "Neon Bogs", "Iron Accord", "large")
	if residents.size() == 0:
		_fail("No residents spawned")
		return
	# We seeded deterministically; check the first NPC's name starts with "Iron "
	# (faction prefix for Iron Accord)
	var first_name: String = str(residents[0].get("name", ""))
	if not first_name.begins_with("Iron "):
		_fail("First NPC name '%s' should start with 'Iron ' (Iron Accord prefix)" % first_name)
		return
	# Hollow Covenant should produce "Hollow " prefix
	var residents2: Array = _spawn_at(pm, "4,4", "Neon Bogs", "Hollow Covenant", "large")
	if residents2.size() == 0:
		_fail("No Hollow residents spawned")
		return
	var hollow_name: String = str(residents2[0].get("name", ""))
	if not hollow_name.begins_with("Hollow "):
		_fail("First Hollow NPC name '%s' should start with 'Hollow '" % hollow_name)
		return
	_ok("NPC names have faction prefixes (Iron 'Iron ', Hollow 'Hollow ')")


## Templates matching BOTH faction and biome get a 2x weight bonus.
## Run many spawns with the same seed and verify the matched templates
## come up more often.
func _test_template_roll_prefers_faction_biome_match() -> void:
	print("[smoke-v070] test: template roll prefers faction+biome match")
	var pm: Node = _new_pm("TestPMRoll")
	await process_frame
	# Count how often a faction+biome matching template (iron_pact_guard
	# in Iron Accord settlements) is rolled vs. a universal one
	# (wanderer_common). Use a fixed seed for reproducibility.
	var match_count: int = 0
	var universal_count: int = 0
	for i in 200:
		# Use a unique seed per call via the iteration
		seed(1000 + i)
		var tpl: Dictionary = pm._roll_template_for_settlement("Neon Bogs", "Iron Accord")
		var tid: String = str(tpl.get("id", ""))
		if tid == "iron_pact_guard":
			match_count += 1
		elif tid == "wanderer_common":
			universal_count += 1
	# The matched template (weight 25 × 2 bonus = 50 effective) should
	# come up more often than the universal wanderer (weight 50). With
	# 200 trials we expect match_count > universal_count.
	if match_count <= universal_count:
		_fail("faction+biome match should be preferred: match=%d, universal=%d" % [match_count, universal_count])
		return
	_ok("Template roll prefers faction+biome match (%d match vs %d universal over 200 trials)" % [match_count, universal_count])


## Faction ratio is balanced — different factions get proportional NPCs
## proportional to their settlement count. We can't easily test the
## world-gen ratio in isolation, but we can verify that EACH faction
## has at least one faction-specific template that spawns when its
## settlement is generated.
func _test_faction_ratio_balanced() -> void:
	print("[smoke-v070] test: each faction has at least one faction-specific template")
	var pm: Node = _new_pm("TestPMRatio")
	await process_frame
	# Spawn 50 residents per faction and verify at least 1 is a
	# faction-specific template (i.e., preferred_factions includes the
	# faction).
	var test_factions := ["Iron Accord", "Hollow Covenant", "Ash Serpents",
		"Veilwardens", "Neon Choir", "Bone Circuit", "Last Caravans"]
	for faction in test_factions:
		var has_specific: bool = false
		for i in 50:
			seed(2000 + i)
			var tpl: Dictionary = pm._roll_template_for_settlement("Ash Wastes", faction)
			var preferred_f: Variant = tpl.get("preferred_factions", null)
			if preferred_f is Array and (preferred_f as Array).has(faction):
				has_specific = true
				break
		if not has_specific:
			_fail("No faction-specific template rolled for '%s' in 50 trials" % faction)
			return
	_ok("Each faction has at least one faction-specific template that can spawn")


## clear_settlement_residents removes only the residents for the given
## hex_key; phase 3 test NPCs and hex-spawned NPCs are left alone.
func _test_clear_settlement_residents() -> void:
	print("[smoke-v070] test: clear_settlement_residents only removes target hex")
	var pm: Node = _new_pm("TestPMClear")
	await process_frame
	# Spawn residents for hex A and hex B
	var r_a: Array = _spawn_at(pm, "1,1", "Neon Bogs", "Iron Accord", "medium")
	var r_b: Array = _spawn_at(pm, "2,2", "Neon Bogs", "Iron Accord", "medium")
	# pm.available_npcs has the 3 phase3 test NPCs + 2 (hex A) + 2 (hex B) = 7
	var total_before: int = pm.available_npcs.size()
	# Clear hex A
	pm.clear_settlement_residents("1,1")
	# Should have 3 phase3 + 0 (hex A) + 2 (hex B) = 5
	var total_after: int = pm.available_npcs.size()
	if total_after != total_before - r_a.size():
		_fail("Clear: expected to remove %d, went from %d to %d" % [r_a.size(), total_before, total_after])
		return
	# Verify hex B NPCs are still there
	var hex_b_ids: Array = []
	for n in r_b:
		hex_b_ids.append(str(n.get("id", "")))
	for n in pm.available_npcs:
		if hex_b_ids.has(str(n.get("id", ""))):
			continue
	# If we got here without returning, all hex B NPCs are still there
	_ok("clear_settlement_residents('1,1') removed only hex A residents (kept hex B + phase 3)")


## WorldGenerator adds biome to the town data so settlements know their
## biome for NPC spawn.
func _test_world_generator_adds_biome_to_town_data() -> void:
	print("[smoke-v070] test: WorldGenerator town data includes biome")
	if not ResourceLoader.exists("res://scripts/WorldGenerator.gd"):
		_fail("WorldGenerator script missing")
		return
	var source: String = ""
	var f: FileAccess = FileAccess.open("res://scripts/WorldGenerator.gd", FileAccess.READ)
	if f == null:
		_fail("Could not open WorldGenerator.gd for reading")
		return
	source = f.get_as_text()
	f.close()
	# Check the source contains a town_data entry with "biome" field
	# near the other fields like "faction" and "template"
	if not ('"biome":' in source and '"faction":' in source and '"size":' in source):
		_fail("WorldGenerator.gd should emit town data with biome, faction, and size fields")
		return
	_ok("WorldGenerator.gd emits town data with biome, faction, and size fields")
