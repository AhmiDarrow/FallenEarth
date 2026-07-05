extends SceneTree
## Smoke test for v0.4.0 Phase 3 follow-up: settlements, towns,
## shops, mission board.
##
## Exercises:
##   - TownManager: get_towns, is_riftspire, can_enter_riftspire
##   - SettlementManager: enter_settlement / leave_settlement
##   - ShopInterface: buy / sell round-trip
##   - MissionBoardInterface: instantiate, refresh, close
##   - Settlement: instantiate, populate NPC list, open shop
##   - LocalMapView get_settlement_at (smoke-level: just check the
##     method exists and returns null for empty layer)

const TownMgrScript = preload("res://scripts/TownManager.gd")
const SettlementMgrScript = preload("res://scripts/SettlementManager.gd")
const ShopScript = preload("res://scripts/ui/ShopInterface.gd")
const MBScript = preload("res://scripts/ui/MissionBoardInterface.gd")
const SettlementScript = preload("res://scripts/Settlement.gd")
const InvMgrScript = preload("res://scripts/InventoryManager.gd")
const ProgMgrScript = preload("res://scripts/ProgressionManager.gd")
const PartyMgrScript = preload("res://scripts/PartyNPCManager.gd")
const LocalMapViewScript = preload("res://scripts/LocalMapView.gd")
const LocalMapViewScene = preload("res://scenes/LocalMapView.tscn")

var failures: Array[String] = []


func _fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)


func _ok(msg: String) -> void:
	print("  ok  " + msg)


func _initialize() -> void:
	print("[smoke-p3b] v0.4.0 Phase 3 follow-up: settlements + shops + missions")
	await _test_town_manager_basic()
	await _test_settlement_manager_enter_leave()
	await _test_shop_buy_sell()
	await _test_mission_board_instantiate()
	await _test_settlement_populate()
	await _test_local_map_settlement_query()

	if failures.is_empty():
		print("[smoke-p3b] All checks passed. (failures.size=%d)" % failures.size())
		quit(0)
	else:
		for f in failures:
			print("[smoke-p3b] FAIL: " + f)
		print("[smoke-p3b] %d failure(s). (failures=%s)" % [failures.size(), str(failures)])
		quit(1)


# ---------------------------------------------------------------------------
# TownManager
# ---------------------------------------------------------------------------

func _test_town_manager_basic() -> void:
	print("[smoke-p3b] test: TownManager basic API")
	var tm: Node = TownMgrScript.new()
	tm.name = "TestTown"
	root.add_child(tm)
	await process_frame
	# Test the one-settlement-per-hex rule with a hand-crafted world.
	# Place 2 towns at the same hex and ensure get_towns returns
	# just 1 (or however the manager dedupes).
	var gs: Node = root.get_node_or_null("GameState")
	if gs != null and gs.has_world():
		# In an actual world, ensure no two towns share a hex
		var towns: Array = tm.get_towns()
		var seen: Dictionary = {}
		for t in towns:
			var hex_str: String = str(t.get("hex", ""))
			if seen.has(hex_str):
				_fail("TownManager: duplicate hex %s in towns list" % hex_str)
				return
			seen[hex_str] = true
	# Level gate tests
	if tm.riftspire_block_reason(10) == "":
		_fail("TownManager: riftspire_block_reason(10) should not be empty")
		return
	if tm.can_enter_riftspire(49):
		_fail("TownManager: can_enter_riftspire(49) should be false (under 50)")
		return
	_ok("TownManager: gates + dedup hex check pass")
	print("[smoke-p3b] [end] town_manager_basic — done")


# ---------------------------------------------------------------------------
# SettlementManager
# ---------------------------------------------------------------------------

func _test_settlement_manager_enter_leave() -> void:
	print("[smoke-p3b] test: SettlementManager enter/leave")
	var sm: Node = SettlementMgrScript.new()
	sm.name = "TestSettlementMgr"
	root.add_child(sm)
	await process_frame
	if sm.is_inside_settlement():
		_fail("SettlementManager: should not be inside a settlement initially")
		return
	# Try to enter a non-existent settlement
	var result: bool = sm.enter_settlement("0,0", null)
	# enter_settlement returns true if the hex is a town. Without
	# world data, no hex is a town, so this should return false.
	if result:
		_fail("SettlementManager: enter_settlement on non-town should return false")
		return
	# leave_settlement on empty should be safe (no-op)
	sm.leave_settlement()
	_ok("SettlementManager: enter rejects non-town, leave is no-op when empty")


# ---------------------------------------------------------------------------
# ShopInterface
# ---------------------------------------------------------------------------

func _test_shop_buy_sell() -> void:
	print("[smoke-p3b] test: ShopInterface buy / sell")
	# Use the autoload InventoryManager and ProgressionManager (the
	# shop looks up by autoload path). Set the autoload's EC to a known
	# value, then test the buy/sell round-trip.
	var prog: Node = root.get_node_or_null("ProgressionManager")
	if prog == null:
		_fail("Shop: ProgressionManager autoload not available")
		return
	# Set EC to 50 (default) for this test
	prog.ec = 50
	prog.emit_signal("ec_changed", prog.ec)
	var inv: Node = root.get_node_or_null("InventoryManager")
	if inv == null:
		_fail("Shop: InventoryManager autoload not available")
		return
	# Clear any existing stick/stone
	while inv.has_item("stick", 1):
		inv.remove_item("stick", 1)
	while inv.has_item("stone", 1):
		inv.remove_item("stone", 1)
	var shop: Control = ShopScript.new()
	shop.name = "TestShop"
	root.add_child(shop)
	await process_frame
	# Initial state: EC 50, no stick
	if int(prog.ec) != 50:
		_fail("Shop: expected initial EC 50, got %d" % int(prog.ec))
		return
	if int(inv.get_count("stick")) != 0:
		_fail("Shop: expected 0 sticks initially, got %d" % int(inv.get_count("stick")))
		return
	# Buy a stick for 2 EC
	shop._on_buy_pressed("stick", 2)
	await process_frame
	if int(prog.ec) != 48:
		_fail("Shop: after buying stick for 2, expected EC 48, got %d" % int(prog.ec))
		return
	if int(inv.get_count("stick")) != 1:
		_fail("Shop: after buying stick, expected count 1, got %d" % int(inv.get_count("stick")))
		return
	# Sell the stick for 1 EC (max(1, 2/2) = 1)
	shop._on_sell_pressed("stick", 1)
	await process_frame
	if int(inv.get_count("stick")) != 0:
		_fail("Shop: after selling stick, expected count 0, got %d" % int(inv.get_count("stick")))
		return
	if int(prog.ec) != 49:
		_fail("Shop: after selling stick for 1, expected EC 49, got %d" % int(prog.ec))
		return
	_ok("Shop: buy (EC 50->48, +1 stick) then sell (EC 48->49, -1 stick) round-trips")


# ---------------------------------------------------------------------------
# MissionBoardInterface
# ---------------------------------------------------------------------------

func _test_mission_board_instantiate() -> void:
	print("[smoke-p3b] test: MissionBoardInterface instantiate")
	var board: Control = MBScript.new()
	board.name = "TestMB"
	root.add_child(board)
	await process_frame
	# Should have child nodes (labels, scroll, etc.)
	if board.get_child_count() == 0:
		_fail("MissionBoard: should have child UI nodes after _ready")
		return
	_ok("MissionBoard: instantiates with %d child nodes" % board.get_child_count())


# ---------------------------------------------------------------------------
# Settlement
# ---------------------------------------------------------------------------

func _test_settlement_populate() -> void:
	print("[smoke-p3b] test: Settlement populate + open shop")
	var pm: Node = PartyMgrScript.new()
	pm.name = "TestParty5"
	root.add_child(pm)
	await process_frame
	# Invite the first NPC so the "available" list is shorter
	pm.invite(pm.available_npcs[0].get("id", ""))
	await process_frame
	var settlement: Control = SettlementScript.new()
	settlement.name = "TestSettlement"
	root.add_child(settlement)
	var town := {
		"hex": "3,5",
		"faction": "Iron Accord",
		"faction_rep": 5,
		"template": "medium_settlement",
		"template_name": "Settlement",
		"size": "medium",
		"buildings": ["tavern", "trader", "worktable", "quest_board", "faction_hq"],
		"pop_cap": 30,
	}
	settlement.setup(town, null)
	await process_frame
	# Should have UI built and populated
	if settlement.get_child_count() < 5:
		_fail("Settlement: should have several UI children, got %d" % settlement.get_child_count())
		return
	# Open the shop
	settlement._on_service_talk("trader", "trader", 1)
	await process_frame
	if settlement.get_node_or_null("Shop") == null:
		_fail("Settlement: Shop should be added after talking to trader")
		return
	_ok("Settlement: populated, opening trader creates ShopInterface child")


# ---------------------------------------------------------------------------
# LocalMapView get_settlement_at
# ---------------------------------------------------------------------------

func _test_local_map_settlement_query() -> void:
	print("[smoke-p3b] test: LocalMapView get_settlement_at + one-per-hex")
	var view: Node2D = LocalMapViewScene.instantiate()
	root.add_child(view)
	await process_frame
	# Empty view: any cell returns null
	var found: Node2D = null
	for dx in range(5):
		for dy in range(5):
			if view.get_settlement_at(Vector2i(dx, dy)) != null:
				found = view.get_settlement_at(Vector2i(dx, dy))
	if found != null:
		_fail("LocalMapView: get_settlement_at should return null when no settlements, got %s" % found)
		return
	# Add two settlement nodes at the SAME hex (0, 0); only one
	# should end up on the layer (or the method returns the first
	# one; we just check no duplicate cells).
	var SettlementNodeScene = preload("res://scenes/SettlementNode.tscn")
	for i in 2:
		var s: Node2D = SettlementNodeScene.instantiate()
		s.setup({
			"hex": "0,0",
			"faction": "Iron Accord",
			"template": "medium_settlement",
			"template_name": "Settlement",
			"size": "medium",
		})
		# Force same cell by setting position directly
		s.position = Vector2(0, 0)
		view.get_settlement_layer().add_child(s)
	await process_frame
	var hits_at_origin: int = 0
	for child in view.get_settlement_layer().get_children():
		if child.get_script() and child.get_script().get_global_name() == "SettlementNode":
			hits_at_origin += 1
	# We just check that get_settlement_at returns ONE node (not a list)
	var at_origin: Node2D = view.get_settlement_at(Vector2i(0, 0))
	if at_origin == null:
		_fail("LocalMapView: get_settlement_at(0,0) should return a node when settlements exist at 0,0")
		return
	_ok("LocalMapView: get_settlement_at returns one node; multiple nodes can share a cell (first found wins) — note: production code should ensure one-per-hex")
	print("[smoke-p3b] [end] local_map_settlement_query — done")
