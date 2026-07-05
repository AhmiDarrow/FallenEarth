extends SceneTree
## Smoke test for v0.4.0 Phase 6: base building (placement, upgrades, residents).

const BaseMgrScript = preload("res://scripts/BaseManager.gd")
const ProgMgrScript = preload("res://scripts/ProgressionManager.gd")
const InvMgrScript = preload("res://scripts/InventoryManager.gd")
const PartyMgrScript = preload("res://scripts/PartyNPCManager.gd")

var failures: Array[String] = []


func _fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)


func _ok(msg: String) -> void:
	print("  ok  " + msg)


func _initialize() -> void:
	print("[smoke-p6] v0.4.0 Phase 6 base building")
	await _test_base_manager_config_load()
	await _test_base_manager_unlock_at_l10()
	await _test_base_manager_placement_validation()
	await _test_base_manager_place_and_capacity()
	await _test_base_manager_upgrade_flow()
	await _test_base_manager_residents()
	await _test_base_manager_settlement_naming()

	if failures.is_empty():
		print("[smoke-p6] All checks passed. (failures.size=%d)" % failures.size())
		quit(0)
	else:
		for f in failures:
			print("[smoke-p6] FAIL: " + f)
		print("[smoke-p6] %d failure(s). (failures=%s)" % [failures.size(), str(failures)])
		quit(1)


func _test_base_manager_config_load() -> void:
	print("[smoke-p6] test: BaseManager config load")
	var bm: Node = BaseMgrScript.new()
	bm.name = "TestBM"
	root.add_child(bm)
	await process_frame
	if bm._upgrades.size() != 10:
		_fail("BaseManager: expected 10 upgrades, got %d" % bm._upgrades.size())
		return
	if int(bm._config.get("spawn_level_required", 0)) != 10:
		_fail("BaseManager: spawn_level_required should be 10, got %s" % bm._config.get("spawn_level_required"))
		return
	if int(bm._config.get("placement_buffer_tiles", 0)) != 50:
		_fail("BaseManager: placement_buffer_tiles should be 50, got %s" % bm._config.get("placement_buffer_tiles"))
		return
	_ok("BaseManager: 10 upgrades loaded, L10 unlock, 50-tile buffer")


func _test_base_manager_unlock_at_l10() -> void:
	print("[smoke-p6] test: BaseManager unlock at L10")
	# Use the autoload ProgressionManager so BaseManager reads our
	# changes. (If we make a fresh one, BaseManager ignores it.)
	var prog: Node = root.get_node_or_null("ProgressionManager")
	if prog == null:
		_fail("ProgressionManager autoload not available")
		return
	prog.level = 5
	var bm: Node = BaseMgrScript.new()
	bm.name = "TestBM2"
	root.add_child(bm)
	await process_frame
	if bm.can_unlock():
		_fail("BaseManager: can_unlock should be false at L5")
		return
	prog.level = 10
	if not bm.can_unlock():
		_fail("BaseManager: can_unlock should be true at L10 (got level=%d)" % prog.level)
		return
	_ok("BaseManager: can_unlock flips false at L5, true at L10")


func _test_base_manager_placement_validation() -> void:
	print("[smoke-p6] test: BaseManager placement cell validation")
	var bm: Node = BaseMgrScript.new()
	bm.name = "TestBM3"
	root.add_child(bm)
	await process_frame
	# Buffer is 50 from edges, so cells <50 or >462 are invalid
	if bm.is_valid_placement_cell(Vector2i(0, 0)):
		_fail("BaseManager: (0,0) should be invalid (edge)")
		return
	if bm.is_valid_placement_cell(Vector2i(49, 49)):
		_fail("BaseManager: (49,49) should be invalid (inside buffer)")
		return
	if not bm.is_valid_placement_cell(Vector2i(50, 50)):
		_fail("BaseManager: (50,50) should be valid (at buffer edge)")
		return
	if not bm.is_valid_placement_cell(Vector2i(256, 256)):
		_fail("BaseManager: (256,256) should be valid (center)")
		return
	if bm.is_valid_placement_cell(Vector2i(512, 256)):
		_fail("BaseManager: (512,256) should be invalid (outside map)")
		return
	_ok("BaseManager: placement validation respects 50-tile buffer")


func _test_base_manager_place_and_capacity() -> void:
	print("[smoke-p6] test: BaseManager.place + capacity")
	var prog: Node = root.get_node_or_null("ProgressionManager")
	if prog == null:
		_fail("ProgressionManager autoload not available")
		return
	prog.level = 10
	var bm: Node = BaseMgrScript.new()
	bm.name = "TestBM4"
	root.add_child(bm)
	await process_frame
	# Place
	if not bm.place("0,0", 256, 256):
		_fail("BaseManager: place(0,0, 256, 256) should succeed")
		return
	if bm.level != 1:
		_fail("BaseManager: level should be 1 after place, got %d" % bm.level)
		return
	if bm.get_capacity() != 5:
		_fail("BaseManager: capacity at L1 should be 5, got %d" % bm.get_capacity())
		return
	# Re-place should fail
	if bm.place("1,1", 300, 300):
		_fail("BaseManager: re-place should fail")
		return
	_ok("BaseManager: place + capacity work (L1, 5 residents)")


func _test_base_manager_upgrade_flow() -> void:
	print("[smoke-p6] test: BaseManager.upgrade")
	var prog: Node = root.get_node_or_null("ProgressionManager")
	var inv: Node = root.get_node_or_null("InventoryManager")
	if prog == null or inv == null:
		_fail("ProgressionManager or InventoryManager autoload not available")
		return
	prog.level = 10
	prog.ec = 100000
	# Clear any existing withered_branch
	while inv.has_item("withered_branch", 1):
		inv.remove_item("withered_branch", 1)
	var bm: Node = BaseMgrScript.new()
	bm.name = "TestBM5"
	root.add_child(bm)
	await process_frame
	bm.place("0,0", 256, 256)
	# Can upgrade from L1 -> L2 needs L20 (the user spec says 10 levels
	# ending at L200 with non-linear curve). At L10 we can't upgrade.
	var check: Dictionary = bm.can_upgrade()
	if bool(check.get("ok", false)):
		_fail("BaseManager: can_upgrade at L10 should be false (L2 needs L20); check=%s" % check)
		return
	# Bump level
	prog.level = 20
	# Now L2 needs L20 — should pass
	# Cost: 200 EC + 10 withered_branch. EC fine. Materials: none in inv.
	# Add 10 withered_branch
	inv.add_item("withered_branch", 10)
	if not bm.can_upgrade():
		_fail("BaseManager: can_upgrade at L20 with materials should be true; check=%s" % check)
		return
	# Apply
	if not bm.upgrade():
		_fail("BaseManager: upgrade should succeed")
		return
	if bm.level != 2:
		_fail("BaseManager: level after upgrade should be 2, got %d" % bm.level)
		return
	if bm.get_capacity() != 10:
		_fail("BaseManager: capacity at L2 should be 10, got %d" % bm.get_capacity())
		return
	_ok("BaseManager: upgrade L1->L2 succeeds, capacity 5->10")


func _test_base_manager_residents() -> void:
	print("[smoke-p6] test: BaseManager residents + settlement naming")
	var prog: Node = root.get_node_or_null("ProgressionManager")
	if prog == null:
		_fail("ProgressionManager autoload not available")
		return
	prog.level = 10
	var pm: Node = PartyMgrScript.new()
	pm.name = "TestPMP6"
	root.add_child(pm)
	await process_frame
	var bm: Node = BaseMgrScript.new()
	bm.name = "TestBM6"
	root.add_child(bm)
	await process_frame
	bm.place("0,0", 256, 256)
	# Add 5 residents (L1 capacity)
	for i in 5:
		bm.add_resident("npc_%d" % i)
	if bm.residents.size() != 5:
		_fail("BaseManager: residents should be 5, got %d" % bm.residents.size())
		return
	# Below 20: naming should fail
	if bm.set_settlement_name("TestFort"):
		_fail("BaseManager: set_settlement_name should fail with 5 residents (need 20)")
		return
	# Directly expand to 20 to test the naming threshold (bypassing capacity
	# — capacity is a separate gameplay check from naming).
	for i in range(5, 20):
		bm.residents.append("npc_%d" % i)
	if not bm.set_settlement_name("TestFort"):
		_fail("BaseManager: set_settlement_name should succeed with 20 residents (residents=%d)" % bm.residents.size())
		return
	if bm.get_settlement_name() != "TestFort":
		_fail("BaseManager: settlement name should be 'TestFort', got '%s'" % bm.get_settlement_name())
		return
	_ok("BaseManager: residents + 20-threshold naming work")


func _test_base_manager_settlement_naming() -> void:
	print("[smoke-p6] test: BaseManager.set_settlement_name")
	var prog: Node = root.get_node_or_null("ProgressionManager")
	if prog == null:
		_fail("ProgressionManager autoload not available")
		return
	prog.level = 10
	var bm: Node = BaseMgrScript.new()
	bm.name = "TestBM7"
	root.add_child(bm)
	await process_frame
	bm.place("0,0", 256, 256)
	# Add 5 residents (L1 capacity)
	for i in 5:
		bm.add_resident("npc_%d" % i)
	# Below 20: naming should fail
	if bm.set_settlement_name("My Outpost"):
		_fail("BaseManager: naming should fail with 5 residents (need 20)")
		return
	# Directly expand to 20 to test the naming threshold
	for i in range(5, 20):
		bm.residents.append("npc_%d" % i)
	# Now naming should succeed
	if not bm.set_settlement_name("My Outpost"):
		_fail("BaseManager: valid name should succeed with 20 residents (residents=%d)" % bm.residents.size())
		return
	if bm.get_settlement_name() != "My Outpost":
		_fail("BaseManager: settlement name should be 'My Outpost', got '%s'" % bm.get_settlement_name())
		return
	_ok("BaseManager: settlement naming works (20 residents, name set)")
