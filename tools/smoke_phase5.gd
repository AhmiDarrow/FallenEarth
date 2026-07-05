extends SceneTree
## Smoke test for v0.4.0 Phase 5: procedural NPC spawn + invite conditions.

const PartyMgrScript = preload("res://scripts/PartyNPCManager.gd")
const EquipMgrScript = preload("res://scripts/EquipmentManager.gd")
const ProgMgrScript = preload("res://scripts/ProgressionManager.gd")
const PartyScreenScript = preload("res://scripts/ui/PartyScreen.gd")
const InvMgrScript = preload("res://scripts/InventoryManager.gd")

var failures: Array[String] = []


func _fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)


func _ok(msg: String) -> void:
	print("  ok  " + msg)


func _initialize() -> void:
	print("[smoke-p5] v0.4.0 Phase 5 procedural NPC spawn + invite conditions")
	await _test_party_manager_template_load()
	await _test_party_manager_seed_phase3()
	await _test_party_manager_invite_dismiss_round_trip()
	await _test_party_manager_spawn_for_hex()
	await _test_party_manager_can_invite_level_gate()
	await _test_party_manager_can_invite_faction_gate()
	await _test_party_manager_get_invite_requirements_text()
	await _test_party_screen_instantiate()

	if failures.is_empty():
		print("[smoke-p5] All checks passed. (failures.size=%d)" % failures.size())
		quit(0)
	else:
		for f in failures:
			print("[smoke-p5] FAIL: " + f)
		print("[smoke-p5] %d failure(s). (failures=%s)" % [failures.size(), str(failures)])
		quit(1)


# ---------------------------------------------------------------------------
# Phase 5: PartyNPCManager
# ---------------------------------------------------------------------------

func _test_party_manager_template_load() -> void:
	print("[smoke-p5] test: PartyNPCManager template load")
	var pm: Node = PartyMgrScript.new()
	pm.name = "TestPM"
	root.add_child(pm)
	await process_frame
	if pm._templates.size() != 4:
		_fail("PartyNPCManager: expected 4 templates, got %d" % pm._templates.size())
		return
	if pm._spawn_rules.get("spawn_chance", 0.0) <= 0.0:
		_fail("PartyNPCManager: spawn_rules.spawn_chance should be > 0")
		return
	# Template variety
	var rarities: Dictionary = {}
	for t in pm._templates:
		var r: String = str(t.get("rarity", "?"))
		rarities[r] = int(rarities.get(r, 0)) + 1
	if not rarities.has("common"):
		_fail("PartyNPCManager: expected at least one common template")
		return
	_ok("PartyNPCManager: %d templates loaded, %d rarities" % [pm._templates.size(), rarities.size()])


func _test_party_manager_seed_phase3() -> void:
	print("[smoke-p5] test: PartyNPCManager Phase 3 placeholder NPCs")
	var pm: Node = PartyMgrScript.new()
	pm.name = "TestPM2"
	root.add_child(pm)
	await process_frame
	if pm.available_npcs.size() < 1:
		_fail("PartyNPCManager: should seed Phase 3 test NPCs, got %d" % pm.available_npcs.size())
		return
	# Confirm test NPCs
	var has_scavenger: bool = false
	for n in pm.available_npcs:
		if str(n.get("id", "")) == "npc_test_scavenger":
			has_scavenger = true
			break
	if not has_scavenger:
		_fail("PartyNPCManager: should have seeded npc_test_scavenger")
		return
	_ok("PartyNPCManager: Phase 3 placeholder NPCs present (%d total)" % pm.available_npcs.size())


func _test_party_manager_invite_dismiss_round_trip() -> void:
	print("[smoke-p5] test: PartyNPCManager invite + dismiss")
	var pm: Node = PartyMgrScript.new()
	pm.name = "TestPM3"
	root.add_child(pm)
	await process_frame
	# Pick the first available NPC and invite
	var first_id: String = str(pm.available_npcs[0].get("id", ""))
	var invited: bool = pm.invite(first_id)
	if not invited:
		_fail("PartyNPCManager: invite(%s) should succeed" % first_id)
		return
	if pm.party_members.size() != 1:
		_fail("PartyNPCManager: after invite, party should have 1, got %d" % pm.party_members.size())
		return
	if pm.available_npcs.size() != 2:
		_fail("PartyNPCManager: after invite, available should have 2, got %d" % pm.available_npcs.size())
		return
	# Dismiss
	var dismissed: bool = pm.dismiss(first_id)
	if not dismissed:
		_fail("PartyNPCManager: dismiss should succeed")
		return
	if pm.party_members.size() != 0:
		_fail("PartyNPCManager: after dismiss, party should be empty")
		return
	_ok("PartyNPCManager: invite + dismiss round-trip works")


func _test_party_manager_spawn_for_hex() -> void:
	print("[smoke-p5] test: PartyNPCManager.spawn_for_hex")
	# Setup a minimal world (ProgressionManager for level)
	var prog: Node = ProgMgrScript.new()
	prog.name = "TestProg5"
	root.add_child(prog)
	await process_frame
	prog.level = 20  # high enough for any template
	var pm: Node = PartyMgrScript.new()
	pm.name = "TestPM4"
	root.add_child(pm)
	await process_frame
	# spawn_for_hex returns the spawned NPC (or empty list)
	# Multiple calls — at least one should produce a non-empty result
	# (we have 30% chance, so 10 calls give ~95% chance).
	var any_spawn: bool = false
	var spawned_id: String = ""
	for i in 10:
		var result: Array = pm.spawn_for_hex("5,7", "Neon Bogs")
		if not result.is_empty():
			any_spawn = true
			spawned_id = str(result[0].get("id", ""))
			break
	if not any_spawn:
		_fail("PartyNPCManager: 10 spawn_for_hex calls produced no NPC (RNG or template eligibility issue)")
		return
	# Verify the spawned NPC has the right shape
	var npc: Dictionary = pm.get_npc(spawned_id)
	if npc.is_empty():
		_fail("PartyNPCManager: spawned NPC not findable via get_npc()")
		return
	if str(npc.get("spawn_hex", "")) != "5,7":
		_fail("PartyNPCManager: spawned NPC spawn_hex should be 5,7, got %s" % npc.get("spawn_hex", ""))
		return
	if not npc.has("template_id"):
		_fail("PartyNPCManager: spawned NPC missing template_id")
		return
	if not npc.has("level"):
		_fail("PartyNPCManager: spawned NPC missing level")
		return
	_ok("PartyNPCManager: spawn_for_hex produced NPC %s (template=%s, level=%d)" % [npc.get("name", "?"), npc.get("template_id", "?"), int(npc.get("level", 0))])


func _test_party_manager_can_invite_level_gate() -> void:
	print("[smoke-p5] test: PartyNPCManager.can_invite level gate")
	var prog: Node = ProgMgrScript.new()
	prog.name = "TestProg6"
	root.add_child(prog)
	await process_frame
	prog.level = 1
	var pm: Node = PartyMgrScript.new()
	pm.name = "TestPM5"
	root.add_child(pm)
	await process_frame
	# Find a Phase 3 placeholder NPC. can_invite on placeholder just
	# checks npc.get("level") > player_level + 10.
	var first: Dictionary = pm.available_npcs[0]
	var npc_id: String = str(first.get("id", ""))
	# Player level 1, NPC level 3: should be allowed
	if not pm.can_invite(npc_id):
		_fail("PartyNPCManager: can_invite(placeholder) at L1 should be true for an L3 NPC")
		return
	# Force player level very high, NPC level unchanged
	prog.level = 50
	# NPC level 3 + 10 = 13, so 50 > 13 -> invite should still succeed
	# (placeholder check is npc.level > player_level + 10, not >=)
	if not pm.can_invite(npc_id):
		_fail("PartyNPCManager: can_invite at L50 should be true for an L3 NPC (placeholder)")
		return
	_ok("PartyNPCManager: can_invite level gate works for placeholders")


func _test_party_manager_can_invite_faction_gate() -> void:
	print("[smoke-p5] test: PartyNPCManager.can_invite faction gate")
	var prog: Node = ProgMgrScript.new()
	prog.name = "TestProg7"
	root.add_child(prog)
	await process_frame
	prog.level = 100  # level always passes
	# Set up a GS with some faction rep
	var gs: Node = _get_or_make_gamestate()
	# Clear then set rep
	gs._faction_rep = {"Iron Accord": 5, "Stormcrows": 50}
	gs.faction_rep_changed = Callable()
	var pm: Node = PartyMgrScript.new()
	pm.name = "TestPM6"
	root.add_child(pm)
	await process_frame
	# Inject a template-based NPC. Bypass spawn_for_hex so we control
	# the template. Manually create an NPC entry with a template_id.
	pm.available_npcs.append({
		"id": "npc_test_legendary",
		"name": "Test Legendary",
		"class": "Scavenger",
		"gender": "male",
		"level": 100,
		"role": "wanderer",
		"race": "Human",
		"origin": "Upworld",
		"equipment": {},
		"template_id": "legendary_loner",
	})
	# Faction rep is 5, legendary_loner requires 50. Should fail.
	if pm.can_invite("npc_test_legendary"):
		_fail("PartyNPCManager: can_invite should fail when faction rep is below the requirement (5 < 50)")
		return
	# Bump rep
	gs._faction_rep = {"Iron Accord": 100, "Stormcrows": 100}
	if not pm.can_invite("npc_test_legendary"):
		_fail("PartyNPCManager: can_invite should succeed when faction rep meets the requirement (100 >= 50)")
		return
	_ok("PartyNPCManager: faction rep gate works (5 fail, 100 pass)")


func _test_party_manager_get_invite_requirements_text() -> void:
	print("[smoke-p5] test: PartyNPCManager.get_invite_requirements_text")
	var prog: Node = ProgMgrScript.new()
	prog.name = "TestProg8"
	root.add_child(prog)
	await process_frame
	prog.level = 1
	var gs: Node = _get_or_make_gamestate()
	gs._faction_rep = {}
	var pm: Node = PartyMgrScript.new()
	pm.name = "TestPM7"
	root.add_child(pm)
	await process_frame
	pm.available_npcs.append({
		"id": "npc_test_legendary",
		"name": "Test Legendary",
		"class": "Scavenger",
		"gender": "male",
		"level": 100,
		"role": "wanderer",
		"race": "Human",
		"origin": "Upworld",
		"equipment": {},
		"template_id": "legendary_loner",  # requires L25, rep 50
	})
	# L1 < L25, rep 0 < 50, no quest
	var txt: String = pm.get_invite_requirements_text("npc_test_legendary")
	if txt.find("level") < 0:
		_fail("PartyNPCManager: get_invite_requirements_text should mention level, got: %s" % txt)
		return
	if txt.find("faction rep") < 0:
		_fail("PartyNPCManager: get_invite_requirements_text should mention faction rep, got: %s" % txt)
		return
	if txt.find("quest") < 0:
		_fail("PartyNPCManager: get_invite_requirements_text should mention quest, got: %s" % txt)
		return
	_ok("PartyNPCManager: get_invite_requirements_text mentions level + faction + quest")


func _test_party_screen_instantiate() -> void:
	print("[smoke-p5] test: PartyScreen instantiate")
	var pm: Node = PartyMgrScript.new()
	pm.name = "TestPM8"
	root.add_child(pm)
	await process_frame
	var screen: Control = PartyScreenScript.new()
	screen.name = "TestPartyScreen5"
	root.add_child(screen)
	await process_frame
	if screen.get_child_count() == 0:
		_fail("PartyScreen: should have child UI nodes after _ready")
		return
	_ok("PartyScreen: instantiates with %d child nodes" % screen.get_child_count())


# Test helper: get or create the autoload GameState
func _get_or_make_gamestate() -> Node:
	var gs: Node = root.get_node_or_null("GameState")
	if gs != null:
		return gs
	gs = preload("res://scripts/GameState.gd").new()
	gs.name = "GameState"
	root.add_child(gs)
	return gs
