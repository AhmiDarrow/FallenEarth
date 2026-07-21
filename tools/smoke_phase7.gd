extends SceneTree
## Smoke test for v0.4.0 Phase 7: base shops.

const BaseShopMgrScript = preload("res://scripts/BaseShopManager.gd")
const ProgMgrScript = preload("res://scripts/ProgressionManager.gd")
const InvMgrScript = preload("res://scripts/InventoryHandler.gd")
const PartyMgrScript = preload("res://scripts/PartyNPCManager.gd")
const BaseShopUIScript = preload("res://scripts/ui/BaseShopUI.gd")
const BaseShopScene = preload("res://scenes/BaseShopUI.tscn")

var failures: Array[String] = []


func _fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)


func _ok(msg: String) -> void:
	print("  ok  " + msg)


func _initialize() -> void:
	print("[smoke-p7] v0.4.0 Phase 7 base shops")
	await _test_base_shop_manager_config_load()
	await _test_base_shop_manager_can_afford_offer()
	await _test_base_shop_manager_open_shop()
	await _test_base_shop_manager_is_shop_open()
	await _test_base_shop_manager_get_shop_stock()
	await _test_base_shop_ui_instantiate()
	await _test_base_shop_manager_offer_for_archetype()

	if failures.is_empty():
		print("[smoke-p7] All checks passed. (failures.size=%d)" % failures.size())
		quit(0)
	else:
		for f in failures:
			print("[smoke-p7] FAIL: " + f)
		print("[smoke-p7] %d failure(s). (failures=%s)" % [failures.size(), str(failures)])
		quit(1)


# ---------------------------------------------------------------------------
# Phase 7: BaseShopManager
# ---------------------------------------------------------------------------

func _test_base_shop_manager_config_load() -> void:
	print("[smoke-p7] test: BaseShopManager config load")
	var bsm: Node = BaseShopMgrScript.new()
	bsm.name = "TestBSM"
	root.add_child(bsm)
	await process_frame
	if bsm._shop_types.size() < 5:
		_fail("BaseShopManager: expected at least 5 shop types, got %d" % bsm._shop_types.size())
		return
	if bsm._npc_offerings.size() < 5:
		_fail("BaseShopManager: expected at least 5 NPC offerings, got %d" % bsm._npc_offerings.size())
		return
	_ok("BaseShopManager: %d shop types, %d NPC offerings" % [bsm._shop_types.size(), bsm._npc_offerings.size()])


func _test_base_shop_manager_can_afford_offer() -> void:
	print("[smoke-p7] test: BaseShopManager.can_afford_offer")
	var prog: Node = root.get_node_or_null("ProgressionManager")
	if prog == null:
		_fail("ProgressionManager autoload not available")
		return
	prog.level = 10
	prog.ec = 100
	var inv: Node = root.get_node_or_null("InventoryHandler")
	if inv == null:
		_fail("InventoryHandler autoload not available")
		return
	# Clear withered_branch
	while inv.has_item("withered_branch", 1):
		inv.remove_item("withered_branch", 1)
	var bsm: Node = BaseShopMgrScript.new()
	bsm.name = "TestBSM2"
	root.add_child(bsm)
	await process_frame
	# Scavenger offer: 200 EC + 5 withered_branch
	# Player has 100 EC, 0 withered_branch -> can't afford
	var check: Dictionary = bsm.can_afford_offer("scavenger")
	if bool(check.get("ok", false)):
		_fail("BaseShopManager: should not afford scavenger offer with 100 EC, 0 items")
		return
	# Give 200 EC
	prog.ec = 200
	# Still no items
	check = bsm.can_afford_offer("scavenger")
	if bool(check.get("ok", false)):
		_fail("BaseShopManager: should not afford scavenger offer without items")
		return
	# Add items
	inv.add_item("withered_branch", 5)
	check = bsm.can_afford_offer("scavenger")
	if not bool(check.get("ok", false)):
		_fail("BaseShopManager: should afford scavenger offer with 200 EC + 5 withered_branch; check=%s" % check)
		return
	# Unknown archetype
	check = bsm.can_afford_offer("not_a_real_archetype")
	if bool(check.get("ok", false)):
		_fail("BaseShopManager: unknown archetype should return no_offer")
		return
	_ok("BaseShopManager: can_afford_offer correctly gates on EC + items")


func _test_base_shop_manager_open_shop() -> void:
	print("[smoke-p7] test: BaseShopManager.open_shop_for_npc")
	var prog: Node = root.get_node_or_null("ProgressionManager")
	var inv: Node = root.get_node_or_null("InventoryHandler")
	if prog == null or inv == null:
		_fail("autoloads not available")
		return
	prog.level = 10
	prog.ec = 1000
	# Clear items
	while inv.has_item("withered_branch", 1):
		inv.remove_item("withered_branch", 1)
	while inv.has_item("kelp_fibre", 1):
		inv.remove_item("kelp_fibre", 1)
	while inv.has_item("iron_ore", 1):
		inv.remove_item("iron_ore", 1)
	var bsm: Node = BaseShopMgrScript.new()
	bsm.name = "TestBSM3"
	root.add_child(bsm)
	await process_frame
	# Open scavenger shop
	inv.add_item("withered_branch", 5)
	var initial_ec: int = int(prog.ec)
	if not bsm.open_shop_for_npc("npc_test_001", "scavenger"):
		_fail("BaseShopManager: open_shop_for_npc(scavenger) should succeed")
		return
	if int(prog.ec) != initial_ec - 200:
		_fail("BaseShopManager: EC should decrease by 200 (offer cost), got %d (expected %d)" % [int(prog.ec), initial_ec - 200])
		return
	if not bsm.is_shop_open("scavenger_shop"):
		_fail("BaseShopManager: scavenger_shop should be open after open_shop_for_npc")
		return
	if not bsm.open_shops.has(bmsm_get(bsm, 0)):
		_fail("BaseShopManager: open_shops should contain the new shop entry")
		return
	# Open again (idempotent? No - should fail because already open)
	if bsm.open_shop_for_npc("npc_test_002", "scavenger"):
		_fail("BaseShopManager: open_shop_for_npc(scavenger) twice should fail (already open)")
		return
	# Verify items consumed
	if inv.has_item("withered_branch", 1):
		_fail("BaseShopManager: 5 withered_branch should have been consumed")
		return
	_ok("BaseShopManager: open_shop_for_npc works (deducts EC + items, idempotent on second)")


func bmsm_get(bsm: Node, idx: int) -> Dictionary:
	return bsm.open_shops[idx]


func _test_base_shop_manager_is_shop_open() -> void:
	print("[smoke-p7] test: BaseShopManager.is_shop_open")
	var bsm: Node = BaseShopMgrScript.new()
	bsm.name = "TestBSM4"
	root.add_child(bsm)
	await process_frame
	if bsm.is_shop_open("scavenger_shop"):
		_fail("BaseShopManager: shop should not be open initially")
		return
	# Open
	bsm.open_shops.append({"shop_type": "scavenger_shop", "npc_id": "x", "archetype": "scavenger", "opened_at": 0})
	if not bsm.is_shop_open("scavenger_shop"):
		_fail("BaseShopManager: shop should be open after manual append")
		return
	_ok("BaseShopManager: is_shop_open works")


func _test_base_shop_manager_get_shop_stock() -> void:
	print("[smoke-p7] test: BaseShopManager.get_shop_stock")
	var bsm: Node = BaseShopMgrScript.new()
	bsm.name = "TestBSM5"
	root.add_child(bsm)
	await process_frame
	# Closed shop -> empty stock
	if not bsm.get_shop_stock("scavenger_shop").is_empty():
		_fail("BaseShopManager: closed shop should have empty stock")
		return
	# Open
	bsm.open_shops.append({"shop_type": "scavenger_shop", "npc_id": "x", "archetype": "scavenger", "opened_at": 0})
	var stock: Array = bsm.get_shop_stock("scavenger_shop")
	if stock.is_empty():
		_fail("BaseShopManager: open scavenger shop should have stock")
		return
	# Unknown shop_type
	if not bsm.get_shop_stock("not_a_shop").is_empty():
		_fail("BaseShopManager: unknown shop type should have empty stock")
		return
	_ok("BaseShopManager: get_shop_stock returns items for open shops, empty otherwise")


func _test_base_shop_ui_instantiate() -> void:
	print("[smoke-p7] test: BaseShopUI instantiate")
	var screen: Control = BaseShopScene.instantiate()
	screen.name = "TestBaseShop"
	root.add_child(screen)
	await process_frame
	if screen.get_child_count() == 0:
		_fail("BaseShopUI: should have child UI nodes after _ready")
		return
	_ok("BaseShopUI: instantiates with %d child nodes" % screen.get_child_count())


func _test_base_shop_manager_offer_for_archetype() -> void:
	print("[smoke-p7] test: BaseShopManager offer for archetype")
	var bsm: Node = BaseShopMgrScript.new()
	bsm.name = "TestBSM6"
	root.add_child(bsm)
	await process_frame
	# Existing archetypes
	for archetype in ["scavenger", "medic", "warden", "wanderer", "trainer"]:
		if bsm.get_offer(archetype).is_empty():
			_fail("BaseShopManager: no offer for %s" % archetype)
			return
	# Unknown archetype
	if not bsm.get_offer("not_real").is_empty():
		_fail("BaseShopManager: unknown archetype should give empty offer")
		return
	# Shop types
	if bsm.get_shop_type_for("scavenger") != "scavenger_shop":
		_fail("BaseShopManager: scavenger should map to scavenger_shop")
		return
	_ok("BaseShopManager: offer-for-archetype mapping correct (scavenger -> scavenger_shop)")
