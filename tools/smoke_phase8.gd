extends SceneTree
## Smoke test for v0.4.0 Phase 8: save/load integration.

const SaveMgrScript = preload("res://scripts/SaveManager.gd")
const InvMgrScript = preload("res://scripts/InventoryHandler.gd")
const ProgMgrScript = preload("res://scripts/ProgressionManager.gd")
const EquipMgrScript = preload("res://scripts/EquipmentManager.gd")
const PartyMgrScript = preload("res://scripts/PartyNPCManager.gd")
const BaseMgrScript = preload("res://scripts/BaseManager.gd")
const BaseShopMgrScript = preload("res://scripts/BaseShopManager.gd")

var failures: Array[String] = []


func _fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)


func _ok(msg: String) -> void:
	print("  ok  " + msg)


func _initialize() -> void:
	print("[smoke-p8] v0.4.0 Phase 8 save/load integration")
	await _test_save_manager_aggregate_snapshot()
	await _test_save_manager_restore_all()
	await _test_save_manager_round_trip()
	await _test_save_manager_populate_and_apply_payload()
	await _test_base_manager_round_trip()

	if failures.is_empty():
		print("[smoke-p8] All checks passed. (failures.size=%d)" % failures.size())
		quit(0)
	else:
		for f in failures:
			print("[smoke-p8] FAIL: " + f)
		print("[smoke-p8] %d failure(s). (failures=%s)" % [failures.size(), str(failures)])
		quit(1)


func _test_save_manager_aggregate_snapshot() -> void:
	print("[smoke-p8] test: SaveManager.aggregate_snapshot")
	var save: Node = SaveMgrScript.new()
	save.name = "TestSave"
	root.add_child(save)
	await process_frame
	var snaps: Dictionary = save.aggregate_snapshot()
	# Should have entries for all 6 managers (all autoloads are alive)
	if snaps.size() < 6:
		_fail("SaveManager.aggregate_snapshot: expected at least 6 manager snapshots, got %d" % snaps.size())
		return
	for key in ["inventory", "progression", "party", "equipment", "base", "base_shops"]:
		if not snaps.has(key):
			_fail("SaveManager.aggregate_snapshot: missing %s snapshot" % key)
			return
	_ok("SaveManager.aggregate_snapshot: %d manager snapshots collected" % snaps.size())


func _test_save_manager_restore_all() -> void:
	print("[smoke-p8] test: SaveManager.restore_all")
	var save: Node = SaveMgrScript.new()
	save.name = "TestSave2"
	root.add_child(save)
	await process_frame
	# Mutate a manager, save snapshot, restore
	var inv: Node = root.get_node_or_null("/root/InventoryHandler")
	inv.add_item("stick", 5)
	var snap: Dictionary = inv.get_snapshot()
	# Mutate again
	inv.add_item("stick", 3)
	if int(inv.get_count("stick")) != 8:
		_fail("Setup: expected 8 sticks, got %d" % int(inv.get_count("stick")))
		return
	# Restore
	save.restore_all({"inventory": snap})
	if int(inv.get_count("stick")) != 5:
		_fail("SaveManager.restore_all: inventory should be 5 sticks after restore, got %d" % int(inv.get_count("stick")))
		return
	_ok("SaveManager.restore_all: inventory restored to snapshot state")


func _test_save_manager_round_trip() -> void:
	print("[smoke-p8] test: SaveManager round-trip (Inventory + Progression)")
	var inv: Node = root.get_node_or_null("/root/InventoryHandler")
	var prog: Node = root.get_node_or_null("/root/ProgressionManager")
	if inv == null or prog == null:
		_fail("InventoryHandler or ProgressionManager autoload not available")
		return
	# Clear
	while inv.has_item("stick", 1):
		inv.remove_item("stick", 1)
	prog.level = 1
	prog.ec = 0
	prog.xp = 0
	# Add state
	inv.add_item("stick", 10)
	inv.add_item("stone", 5)
	prog.level = 7
	prog.ec = 250
	prog.xp = 42
	# Snapshot
	var save: Node = SaveMgrScript.new()
	save.name = "TestSave3"
	root.add_child(save)
	await process_frame
	var snap: Dictionary = save.aggregate_snapshot()
	# Clear
	while inv.has_item("stick", 1):
		inv.remove_item("stick", 1)
	while inv.has_item("stone", 1):
		inv.remove_item("stone", 1)
	prog.level = 1
	prog.ec = 0
	prog.xp = 0
	# Restore
	save.restore_all(snap)
	if int(inv.get_count("stick")) != 10:
		_fail("SaveManager round-trip: sticks should be 10, got %d" % int(inv.get_count("stick")))
		return
	if int(inv.get_count("stone")) != 5:
		_fail("SaveManager round-trip: stones should be 5, got %d" % int(inv.get_count("stone")))
		return
	if int(prog.level) != 7:
		_fail("SaveManager round-trip: level should be 7, got %d" % int(prog.level))
		return
	if int(prog.ec) != 250:
		_fail("SaveManager round-trip: ec should be 250, got %d" % int(prog.ec))
		return
	if int(prog.xp) != 42:
		_fail("SaveManager round-trip: xp should be 42, got %d" % int(prog.xp))
		return
	_ok("SaveManager round-trip: inventory + progression preserved exactly")


func _test_save_manager_populate_and_apply_payload() -> void:
	print("[smoke-p8] test: SaveManager populate + apply payload")
	var inv: Node = root.get_node_or_null("/root/InventoryHandler")
	var prog: Node = root.get_node_or_null("/root/ProgressionManager")
	# Clear and set
	while inv.has_item("withered_branch", 1):
		inv.remove_item("withered_branch", 1)
	prog.level = 5
	prog.ec = 100
	# Build a payload as if it came from disk
	var save: Node = SaveMgrScript.new()
	save.name = "TestSave4"
	root.add_child(save)
	await process_frame
	var payload: Dictionary = {
		"version": "0.4.0",
		"slot": 0,
		"character": {},
	}
	save.populate_payload_with_managers(payload)
	# Now the payload has the manager snapshots
	if not payload.has("inventory"):
		_fail("SaveManager.populate_payload_with_managers: payload should have 'inventory'")
		return
	# Mutate
	while inv.has_item("foo", 1):
		inv.remove_item("foo", 1)
	inv.add_item("foo", 99)
	prog.level = 99
	prog.ec = 0
	# Apply back
	save.apply_managers_from_payload(payload)
	if int(inv.get_count("foo")) != 0:
		_fail("SaveManager.apply_managers_from_payload: 'foo' should be 0 after restore, got %d" % int(inv.get_count("foo")))
		return
	if int(prog.level) != 5:
		_fail("SaveManager.apply_managers_from_payload: level should be 5, got %d" % int(prog.level))
		return
	_ok("SaveManager.populate + apply round-trip works")


func _test_base_manager_round_trip() -> void:
	print("[smoke-p8] test: BaseManager + BaseShopManager round-trip")
	var bm: Node = root.get_node_or_null("/root/BaseManager")
	var bsm: Node = root.get_node_or_null("/root/BaseShopManager")
	if bm == null or bsm == null:
		_fail("BaseManager or BaseShopManager autoload not available")
		return
	# Clear state
	bm.placement = {}
	bm.level = 0
	bm.residents = []
	bm.settlement_name = ""
	bsm.open_shops = []
	# Set state
	bm.place("0,0", 256, 256)
	bm.level = 3
	bm.residents = ["npc_a", "npc_b"]
	bm.settlement_name = "TestFort"
	bsm.open_shops = [{"shop_type": "weapon_shop", "npc_id": "npc_a", "archetype": "scavenger", "opened_at": 12345}]
	# Snapshot
	var save: Node = SaveMgrScript.new()
	save.name = "TestSave5"
	root.add_child(save)
	await process_frame
	var snap: Dictionary = save.aggregate_snapshot()
	# Clear
	bm.placement = {}
	bm.level = 0
	bm.residents = []
	bm.settlement_name = ""
	bsm.open_shops = []
	# Restore
	save.restore_all(snap)
	# Verify
	if bm.level != 3:
		_fail("BaseManager round-trip: level should be 3, got %d" % bm.level)
		return
	if bm.residents.size() != 2:
		_fail("BaseManager round-trip: residents should be 2, got %d" % bm.residents.size())
		return
	if bm.settlement_name != "TestFort":
		_fail("BaseManager round-trip: settlement_name should be 'TestFort', got '%s'" % bm.settlement_name)
		return
	if bsm.open_shops.size() != 1:
		_fail("BaseShopManager round-trip: open_shops should be 1, got %d" % bsm.open_shops.size())
		return
	if str(bsm.open_shops[0].get("shop_type", "")) != "weapon_shop":
		_fail("BaseShopManager round-trip: shop_type should be 'weapon_shop'")
		return
	_ok("BaseManager + BaseShopManager round-trip preserved")
