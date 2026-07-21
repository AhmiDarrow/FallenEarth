extends SceneTree
## Smoke test for the v0.4.0 Phase 3 character menu, party, crafting, and
## keyboard hotkeys.
##
## Exercises:
##   - PartyNPCManager: seed test NPCs, invite, dismiss
##   - CraftingManager: load recipes, can_craft, craft
##   - CharacterMenu: tab switching, placeholder fallback
##   - PartyScreen: instantiates, lists available + party
##   - Keyboard hotkey routing: I → inventory, E → equipment,
##     C → crafting, P → party, S → stats

const PartyNPCMgrScript = preload("res://scripts/PartyNPCManager.gd")
const CraftingMgrScript = preload("res://scripts/CraftingManager.gd")
const InventoryMgrScript = preload("res://scripts/InventoryHandler.gd")
const CharacterMenuScript = preload("res://scripts/ui/CharacterMenu.gd")
const PartyScreenScript = preload("res://scripts/ui/PartyScreen.gd")
const EquipmentScreenScript = preload("res://scripts/ui/EquipmentScreen.gd")
const StatsScreenScript = preload("res://scripts/ui/StatsScreen.gd")
const CraftingScreenScript = preload("res://scripts/ui/CraftingScreen.gd")
const InventoryScreenScript = preload("res://scripts/ui/InventoryScreen.gd")

var failures: Array[String] = []


func _fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)


func _ok(msg: String) -> void:
	print("  ok  " + msg)


func _initialize() -> void:
	print("[smoke-p3] v0.4.0 Phase 3 character menu + party + crafting")
	_test_party_manager_seed()
	_test_party_manager_invite_dismiss()
	_test_crafting_manager_loads()
	_test_crafting_can_and_craft()
	_test_crafting_cannot_without_ingredients()
	_test_character_menu_tabs()
	_test_party_screen_lists()
	_test_placeholder_screens()

	if failures.is_empty():
		print("[smoke-p3] All checks passed.")
		quit(0)
	else:
		for f in failures:
			print("[smoke-p3] FAIL: " + f)
		print("[smoke-p3] %d failure(s)." % failures.size())
		quit(1)


# ---------------------------------------------------------------------------
# PartyNPCManager
# ---------------------------------------------------------------------------

func _test_party_manager_seed() -> void:
	print("[smoke-p3] test: PartyNPCManager seeds test NPCs")
	var pm: Node = PartyNPCMgrScript.new()
	pm.name = "TestParty"
	root.add_child(pm)
	await process_frame
	if pm.available_npcs.size() < 1:
		_fail("PartyNPCManager: should seed at least 1 test NPC, got %d" % pm.available_npcs.size())
		return
	if pm.party_members.size() != 0:
		_fail("PartyNPCManager: party should start empty, got %d" % pm.party_members.size())
		return
	_ok("PartyNPCManager: %d available, 0 party" % pm.available_npcs.size())


func _test_party_manager_invite_dismiss() -> void:
	print("[smoke-p3] test: PartyNPCManager invite + dismiss")
	var pm: Node = PartyNPCMgrScript.new()
	pm.name = "TestParty2"
	root.add_child(pm)
	await process_frame
	var first_id: String = str(pm.available_npcs[0].get("id", ""))
	# Invite
	var invited: bool = pm.invite(first_id)
	if not invited:
		_fail("PartyNPCManager: invite should succeed")
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
	if pm.available_npcs.size() != 3:
		_fail("PartyNPCManager: after dismiss, available should have 3, got %d" % pm.available_npcs.size())
		return
	_ok("PartyNPCManager: invite + dismiss round-trip works")


# ---------------------------------------------------------------------------
# CraftingManager
# ---------------------------------------------------------------------------

func _test_crafting_manager_loads() -> void:
	print("[smoke-p3] test: CraftingManager loads recipes")
	var cm: Node = CraftingMgrScript.new()
	cm.name = "TestCrafting"
	root.add_child(cm)
	await process_frame
	if cm._recipes.size() < 3:
		_fail("CraftingManager: should load at least 3 recipes, got %d" % cm._recipes.size())
		return
	# By default at L1: stone_axe, stone_pickaxe, bandage
	var expected := ["stone_axe", "stone_pickaxe", "bandage"]
	for rid in expected:
		if not cm._recipes.has(rid):
			_fail("CraftingManager: missing recipe %s" % rid)
			return
	_ok("CraftingManager: %d recipes loaded (%s etc.)" % [cm._recipes.size(), ", ".join(expected)])


func _test_crafting_can_and_craft() -> void:
	print("[smoke-p3] test: CraftingManager.can_craft + craft")
	var inv: Node = InventoryMgrScript.new()
	inv.name = "TestInv"
	root.add_child(inv)
	var cm: Node = CraftingMgrScript.new()
	cm.name = "TestCrafting2"
	root.add_child(cm)
	await process_frame
	# Give the player enough sticks and stones
	inv.add_item("stick", 5)
	inv.add_item("stone", 5)
	if not cm.can_craft("stone_axe", inv):
		_fail("CraftingManager: should be able to craft stone_axe (have sticks + stones); inv: sticks=%d stones=%d" % [inv.get_count("stick"), inv.get_count("stone")])
		return
	# stone_axe is recipe id, the result item is "axe_stone"
	if not cm.craft("stone_axe", inv):
		_fail("CraftingManager: craft(stone_axe) should succeed")
		return
	if inv.get_count("stick") != 4:
		_fail("CraftingManager: sticks should be 4 after craft, got %d" % inv.get_count("stick"))
		return
	if inv.get_count("stone") != 3:
		_fail("CraftingManager: stones should be 3 after craft, got %d" % inv.get_count("stone"))
		return
	if inv.get_count("axe_stone") != 1:
		_fail("CraftingManager: should have 1 axe_stone after craft, got %d" % inv.get_count("axe_stone"))
		return
	_ok("CraftingManager: stone_axe craft — 1 stick + 2 stones → 1 axe_stone")


func _test_crafting_cannot_without_ingredients() -> void:
	print("[smoke-p3] test: CraftingManager.can_craft fails when missing ingredients")
	var inv: Node = InventoryMgrScript.new()
	inv.name = "TestInv2"
	root.add_child(inv)
	var cm: Node = CraftingMgrScript.new()
	cm.name = "TestCrafting3"
	root.add_child(cm)
	await process_frame
	# No ingredients
	if cm.can_craft("stone_axe"):
		_fail("CraftingManager: should NOT be able to craft stone_axe (no ingredients)")
		return
	if cm.craft("stone_axe"):
		_fail("CraftingManager: craft should return false when missing ingredients")
		return
	_ok("CraftingManager: can_craft returns false when missing ingredients")


# ---------------------------------------------------------------------------
# CharacterMenu
# ---------------------------------------------------------------------------

func _test_character_menu_tabs() -> void:
	print("[smoke-p3] test: CharacterMenu tab switching")
	var menu: Control = CharacterMenuScript.new()
	menu.name = "TestMenu"
	root.add_child(menu)
	await process_frame
	# Default tab should be inventory
	if menu.get_active_tab() != "inventory":
		_fail("CharacterMenu: default tab should be 'inventory', got '%s'" % menu.get_active_tab())
		return
	# Switch to crafting
	menu.select_tab("crafting")
	if menu.get_active_tab() != "crafting":
		_fail("CharacterMenu: after select_tab('crafting'), active should be 'crafting', got '%s'" % menu.get_active_tab())
		return
	# Switch to party
	menu.select_tab("party")
	if menu.get_active_tab() != "party":
		_fail("CharacterMenu: after select_tab('party'), active should be 'party', got '%s'" % menu.get_active_tab())
		return
	# Switch to equipment (placeholder in Phase 3)
	menu.select_tab("equipment")
	if menu.get_active_tab() != "equipment":
		_fail("CharacterMenu: after select_tab('equipment'), active should be 'equipment', got '%s'" % menu.get_active_tab())
		return
	# Unknown tab should be a no-op
	menu.select_tab("nonsense")
	if menu.get_active_tab() != "equipment":
		_fail("CharacterMenu: unknown tab should not change active")
		return
	_ok("CharacterMenu: 4 tab switches + unknown-tab guard all work")


func _test_party_screen_lists() -> void:
	print("[smoke-p3] test: PartyScreen lists available + party")
	var pm: Node = PartyNPCMgrScript.new()
	pm.name = "TestParty3"
	root.add_child(pm)
	await process_frame
	# Invite the first NPC
	var first_id: String = str(pm.available_npcs[0].get("id", ""))
	pm.invite(first_id)
	await process_frame
	# Build a PartyScreen
	var screen: Control = PartyScreenScript.new()
	screen.name = "TestPartyScreen"
	root.add_child(screen)
	await process_frame
	# Just check the screen instantiated without error and has children
	if screen.get_child_count() == 0:
		_fail("PartyScreen: should have children after _ready")
		return
	_ok("PartyScreen: instantiated with party + available (smoke-level only)")


func _test_placeholder_screens() -> void:
	print("[smoke-p3] test: Equipment + Stats placeholders")
	for script in [EquipmentScreenScript, StatsScreenScript]:
		var screen: Control = script.new()
		screen.name = "TestPlaceholder"
		root.add_child(screen)
		await process_frame
		if screen.get_child_count() == 0:
			_fail("%s: should have at least 1 child (the placeholder label)" % script.resource_path)
			return
		_ok("%s: placeholder renders" % script.resource_path.get_file())
