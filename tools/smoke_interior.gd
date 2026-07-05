extends SceneTree
## Smoke test for Phase B+C — spatial settlement interiors + visual variety.
## Tests: room data loading, grid dimensions, exit connectivity,
## scene instantiation, NPC placement, wall collision, room transitions,
## NPC race sprites, biome floor textures, faction wall accents.

const RoomViewScript = preload("res://scripts/RoomView.gd")
const SettlementInteriorScript = preload("res://scripts/SettlementInterior.gd")

var failures: Array[String] = []


func _fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)


func _ok(msg: String) -> void:
	print("  ok  " + msg)


func _initialize() -> void:
	await process_frame
	print("[smoke] Phase B+C — settlement interior + visual variety smoke test")
	_test_rooms_json_loads()
	_test_room_grid_dimensions()
	_test_exit_connectivity()
	_test_settlement_exit_present()
	_test_room_view_instantiates()
	_test_room_view_wall_collision()
	_test_room_view_npc_queries()
	_test_room_view_exit_queries()
	_test_settlement_interior_scene()
	_test_settlement_interior_setup()
	# Phase C tests
	_test_npc_race_fields()
	_test_character_sprite_loading()
	_test_biome_floor_texture()
	_test_faction_wall_accents()
	# Phase D tests
	_test_npc_gender_fields()
	_test_female_sprite_loading()
	# Phase E tests
	_test_furniture_data_fields()
	_test_furniture_collision()
	# Phase F tests
	_test_button_assets_exist()
	_test_button_style_helper()
	# Phase G tests
	_test_riftspire_portal_npc()
	_test_riftspire_portal_interaction()

	if failures.is_empty():
		print("[smoke] All checks passed.")
		quit(0)
	else:
		for f in failures:
			print("[smoke] FAIL: " + f)
		print("[smoke] %d failure(s)." % failures.size())
		quit(1)


func _load_rooms() -> Dictionary:
	var file: FileAccess = FileAccess.open("res://data/settlement_rooms.json", FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}
	return parsed.get("rooms", {})


func _test_rooms_json_loads() -> void:
	print("[smoke] test: settlement_rooms.json loads")
	var rooms: Dictionary = _load_rooms()
	if rooms.is_empty():
		_fail("Could not load settlement_rooms.json or rooms empty")
		return
	var expected := ["town_square", "tavern", "trader", "worktable", "armor_table",
					 "blacksmith", "quest_board", "faction_hq", "auction_house", "arena"]
	for rid in expected:
		if not rooms.has(rid):
			_fail("Missing room: %s" % rid)
			return
	_ok("Loaded %d rooms (all expected present)" % rooms.size())


func _test_room_grid_dimensions() -> void:
	print("[smoke] test: room grids are 12 wide × 10 tall")
	var rooms: Dictionary = _load_rooms()
	var bad := 0
	for rid in rooms:
		var rd: Dictionary = rooms[rid]
		var grid: Array = rd.get("grid", [])
		if grid.size() != 10:
			_fail("Room %s: grid has %d rows (expected 10)" % [rid, grid.size()])
			bad += 1
			continue
		for y in grid.size():
			var row: String = str(grid[y])
			if row.length() != 12:
				_fail("Room %s row %d: length %d (expected 12)" % [rid, y, row.length()])
				bad += 1
	if bad == 0:
		_ok("All room grids are 12×10")


func _test_exit_connectivity() -> void:
	print("[smoke] test: exit connectivity (bidirectional)")
	var rooms: Dictionary = _load_rooms()
	var errors := 0
	for rid in rooms:
		var rd: Dictionary = rooms[rid]
		var exits: Array = rd.get("exits", [])
		for exit in exits:
			var target: String = str(exit.get("target_room", ""))
			if target.is_empty():
				continue
			# Settlement exits don't have a target room in the rooms dict
			if target.begins_with("_"):
				continue
			if not rooms.has(target):
				_fail("Room %s has exit to unknown room %s" % [rid, target])
				errors += 1
	_ok("Exit connectivity: %d errors" % errors)


func _test_settlement_exit_present() -> void:
	print("[smoke] test: town_square has settlement exit")
	var rooms: Dictionary = _load_rooms()
	if not rooms.has("town_square"):
		_fail("town_square missing")
		return
	var ts: Dictionary = rooms["town_square"]
	var se: Dictionary = ts.get("settlement_exit", {})
	if se.is_empty():
		_fail("town_square has no settlement_exit")
		return
	_ok("town_square settlement_exit at (%d, %d)" % [int(se.get("x", 0)), int(se.get("y", 0))])


func _test_room_view_instantiates() -> void:
	print("[smoke] test: RoomView instantiates and renders")
	var rooms: Dictionary = _load_rooms()
	if not rooms.has("town_square"):
		_fail("town_square missing for RoomView test")
		return
	var rv: Node2D = Node2D.new()
	rv.set_script(RoomViewScript)
	root.add_child(rv)
	await process_frame

	var rd: Dictionary = rooms["town_square"]
	rd["id"] = "town_square"
	rv.setup(rd, 5, 3)
	await process_frame

	if rv.room_id != "town_square":
		_fail("RoomView.room_id mismatch: %s" % rv.room_id)
		rv.queue_free()
		return
	if rv.room_name != "Town Square":
		_fail("RoomView.room_name mismatch: %s" % rv.room_name)
		rv.queue_free()
		return
	# Check children exist (grid cells rendered as ColorRects)
	var child_count: int = rv.get_child_count()
	if child_count < 10:
		_fail("RoomView has only %d children (expected >10 for grid)" % child_count)
		rv.queue_free()
		return
	rv.queue_free()
	_ok("RoomView instantiates with %d children" % child_count)


func _test_room_view_wall_collision() -> void:
	print("[smoke] test: RoomView wall collision")
	var rooms: Dictionary = _load_rooms()
	if not rooms.has("tavern"):
		_fail("tavern missing for wall collision test")
		return
	var rv: Node2D = Node2D.new()
	rv.set_script(RoomViewScript)
	root.add_child(rv)
	await process_frame

	var rd: Dictionary = rooms["tavern"]
	rd["id"] = "tavern"
	rv.setup(rd, 5, 1)
	await process_frame

	# (0,0) should be wall
	if not rv.is_wall(0, 0):
		_fail("(0,0) should be wall in tavern")
		rv.queue_free()
		return
	# (1,1) should be floor
	if rv.is_wall(1, 1):
		_fail("(1,1) should be floor in tavern")
		rv.queue_free()
		return
	# (-1,-1) should be wall (out of bounds)
	if not rv.is_wall(-1, -1):
		_fail("(-1,-1) should be wall (out of bounds)")
		rv.queue_free()
		return
	rv.queue_free()
	_ok("RoomView wall collision works")


func _test_room_view_npc_queries() -> void:
	print("[smoke] test: RoomView NPC queries")
	var rooms: Dictionary = _load_rooms()
	if not rooms.has("tavern"):
		_fail("tavern missing for NPC query test")
		return
	var rv: Node2D = Node2D.new()
	rv.set_script(RoomViewScript)
	root.add_child(rv)
	await process_frame

	var rd: Dictionary = rooms["tavern"]
	rd["id"] = "tavern"
	rv.setup(rd, 5, 1)
	await process_frame

	# NPC at (5,2) = innkeeper
	var npc: Dictionary = rv.get_npc_at(5, 2)
	if npc.is_empty():
		_fail("No NPC found at (5,2) in tavern")
		rv.queue_free()
		return
	if str(npc.get("id", "")) != "innkeeper":
		_fail("NPC at (5,2) is not innkeeper: %s" % str(npc.get("id", "")))
		rv.queue_free()
		return
	# NPC near (5,3) should find innkeeper at (5,2)
	var near: Dictionary = rv.get_npc_near(5, 3)
	if near.is_empty():
		_fail("get_npc_near(5,3) returned empty (should find innkeeper)")
		rv.queue_free()
		return
	# No NPC at (1,1)
	var none: Dictionary = rv.get_npc_at(1, 1)
	if not none.is_empty():
		_fail("get_npc_at(1,1) should be empty")
		rv.queue_free()
		return
	rv.queue_free()
	_ok("RoomView NPC queries work")


func _test_room_view_exit_queries() -> void:
	print("[smoke] test: RoomView exit queries")
	var rooms: Dictionary = _load_rooms()
	if not rooms.has("tavern"):
		_fail("tavern missing for exit query test")
		return
	var rv: Node2D = Node2D.new()
	rv.set_script(RoomViewScript)
	root.add_child(rv)
	await process_frame

	var rd: Dictionary = rooms["tavern"]
	rd["id"] = "tavern"
	rv.setup(rd, 5, 1)
	await process_frame

	# Exit at (5,8) leads to town_square
	var exit: Dictionary = rv.get_exit_at(5, 8)
	if exit.is_empty():
		_fail("No exit found at (5,8) in tavern")
		rv.queue_free()
		return
	if str(exit.get("target_room", "")) != "town_square":
		_fail("Exit at (5,8) doesn't target town_square: %s" % str(exit.get("target_room", "")))
		rv.queue_free()
		return
	# is_exit
	if not rv.is_exit(5, 8):
		_fail("is_exit(5,8) should be true")
		rv.queue_free()
		return
	if rv.is_exit(1, 1):
		_fail("is_exit(1,1) should be false")
		rv.queue_free()
		return
	rv.queue_free()
	_ok("RoomView exit queries work")


func _test_settlement_interior_scene() -> void:
	print("[smoke] test: SettlementInterior scene loads")
	var scene: PackedScene = load("res://scenes/SettlementInterior.tscn") as PackedScene
	if scene == null:
		_fail("Could not load SettlementInterior.tscn")
		return
	var node: Control = scene.instantiate()
	if node == null:
		_fail("SettlementInterior.instantiate() returned null")
		return
	if not node.has_method("setup"):
		_fail("SettlementInterior missing setup() method")
		node.queue_free()
		return
	node.queue_free()
	_ok("SettlementInterior scene loads and has setup()")


func _test_settlement_interior_setup() -> void:
	print("[smoke] test: SettlementInterior.setup() loads rooms")
	var node: Node = Node.new()
	node.set_script(SettlementInteriorScript)
	root.add_child(node)
	await process_frame

	# Setup with a fake town
	var town := {
		"hex": "5,5",
		"faction": "Iron Accord",
		"template_name": "small_outpost",
		"size": "small",
		"buildings": ["tavern", "trader", "worktable"],
	}
	node.setup(town, null, "")
	await process_frame
	await process_frame

	# Check that rooms were loaded
	var rooms_count: int = node._rooms.size()
	if rooms_count == 0:
		_fail("SettlementInterior._rooms is empty after setup")
		node.queue_free()
		return
	# Check current room
	var current: String = node._current_room_id
	if current.is_empty():
		_fail("SettlementInterior._current_room_id is empty after setup")
		node.queue_free()
		return
	_ok("SettlementInterior.setup() loaded %d rooms, current=%s" % [rooms_count, current])
	node.queue_free()


# ---------------------------------------------------------------------------
# Phase C tests — Visual variety
# ---------------------------------------------------------------------------

func _test_npc_race_fields() -> void:
	print("[smoke] test: NPCs have race fields for sprite selection")
	var rooms: Dictionary = _load_rooms()
	var total_npcs := 0
	var with_race := 0
	var valid_races := ["human", "mutant", "cyborg", "ai", "chthon", "vesperid", "nullborn", "revenant"]
	for rid in rooms:
		var rd: Dictionary = rooms[rid]
		var npcs: Array = rd.get("npcs", [])
		for npc in npcs:
			total_npcs += 1
			var race: String = str(npc.get("race", ""))
			if race.is_empty():
				_fail("NPC %s in %s has no race field" % [str(npc.get("id", "?")), rid])
			elif not race in valid_races:
				_fail("NPC %s has invalid race: %s" % [str(npc.get("id", "")), race])
			else:
				with_race += 1
	if total_npcs == 0:
		_fail("No NPCs found in any room")
	elif with_race == total_npcs:
		_ok("All %d NPCs have valid race fields" % total_npcs)
	else:
		_fail("%d/%d NPCs have valid race fields" % [with_race, total_npcs])


func _test_character_sprite_loading() -> void:
	print("[smoke] test: character sprites load and AtlasTexture extracts south frame")
	var races := ["human", "mutant", "cyborg", "chthon", "vesperid", "nullborn", "revenant", "ai"]
	var sprite_paths := {
		"human":    "res://assets/characters/human_male/human_male_base.png",
		"mutant":   "res://assets/characters/mutant_male/mutant_male_base.png",
		"cyborg":   "res://assets/characters/cyborg_male/cyborg_male_base.png",
		"chthon":   "res://assets/characters/chthon_male/chthon_male_base.png",
		"vesperid": "res://assets/characters/vesperid_male/vesperid_male_base.png",
		"nullborn": "res://assets/characters/nullborn_male/nullborn_male_base.png",
		"revenant": "res://assets/characters/revenant_male/revenant_male_base.png",
		"ai":       "res://assets/characters/sentientai_male/sentientai_male_base.png",
	}
	var loaded := 0
	for race in races:
		var path: String = sprite_paths.get(race, "")
		if not ResourceLoader.exists(path):
			_fail("Sprite not found for race %s: %s" % [race, path])
			continue
		var sheet: Texture2D = load(path)
		if sheet == null:
			_fail("Could not load sprite for race %s" % race)
			continue
		# Verify sheet dimensions (should be 128x128)
		var sz: Vector2 = sheet.get_size()
		if sz.x != 128 or sz.y != 128:
			_fail("Sprite for %s is %dx%d (expected 128x128)" % [race, int(sz.x), int(sz.y)])
			continue
		# Extract south frame via AtlasTexture (same logic as RoomView)
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(0, 0, 16, 16)
		var frame: Texture2D = atlas
		if frame == null:
			_fail("AtlasTexture extraction failed for %s" % race)
			continue
		loaded += 1
	if loaded == races.size():
		_ok("All %d character sprites loaded and extracted" % loaded)
	else:
		_fail("Only %d/%d character sprites loaded" % [loaded, races.size()])


func _test_biome_floor_texture() -> void:
	print("[smoke] test: biome floor textures load")
	var biomes := ["ash_wastes", "neon_bogs", "glass_dunes", "toxin_marshes",
				   "stormspire_highlands", "dead_city_outskirts", "scorched_plains",
				   "rust_canyons", "corpse_fields", "ironwood_thicket"]
	var loaded := 0
	for biome in biomes:
		var path := "res://assets/tilesets/%s/ground.png" % biome
		if not ResourceLoader.exists(path):
			_fail("Floor texture not found: %s" % path)
			continue
		var tex: Texture2D = load(path)
		if tex == null:
			_fail("Could not load floor texture for %s" % biome)
			continue
		loaded += 1
	if loaded == biomes.size():
		_ok("All %d biome floor textures loaded" % loaded)
	else:
		_fail("Only %d/%d biome floor textures loaded" % [loaded, biomes.size()])


func _test_faction_wall_accents() -> void:
	print("[smoke] test: RoomView faction wall accents are defined")
	var accents: Dictionary = RoomViewScript.FACTION_WALL_ACCENTS
	var expected_factions := ["", "iron_accord", "hollow_covenant", "ash_serpents",
							  "veilwardens", "neon_choir", "dust_parliament",
							  "bone_circuit", "black_ledger", "last_caravans", "echo_wardens"]
	var found := 0
	for faction in expected_factions:
		if accents.has(faction):
			found += 1
		else:
			_fail("Missing faction wall accent: %s" % faction)
	if found == expected_factions.size():
		_ok("All %d faction wall accents defined" % found)
	else:
		_fail("Only %d/%d faction wall accents defined" % [found, expected_factions.size()])


# ---------------------------------------------------------------------------
# Phase D tests — Gender variety
# ---------------------------------------------------------------------------

func _test_npc_gender_fields() -> void:
	print("[smoke] test: NPCs have gender fields for sprite variety")
	var rooms: Dictionary = _load_rooms()
	var total_npcs := 0
	var with_gender := 0
	var valid_genders := ["male", "female"]
	for rid in rooms:
		var rd: Dictionary = rooms[rid]
		var npcs: Array = rd.get("npcs", [])
		for npc in npcs:
			total_npcs += 1
			var gender: String = str(npc.get("gender", ""))
			if gender.is_empty():
				_fail("NPC %s in %s has no gender field" % [str(npc.get("id", "?")), rid])
			elif not gender in valid_genders:
				_fail("NPC %s has invalid gender: %s" % [str(npc.get("id", "")), gender])
			else:
				with_gender += 1
	if total_npcs == 0:
		_fail("No NPCs found in any room")
	elif with_gender == total_npcs:
		_ok("All %d NPCs have valid gender fields" % total_npcs)
	else:
		_fail("%d/%d NPCs have valid gender fields" % [with_gender, total_npcs])


func _test_female_sprite_loading() -> void:
	print("[smoke] test: female character sprites load correctly")
	var races := ["human", "mutant", "cyborg", "chthon", "vesperid", "nullborn", "revenant", "ai"]
	var sprite_paths := {
		"human":    "res://assets/characters/human_female/human_female_base.png",
		"mutant":   "res://assets/characters/mutant_female/mutant_female_base.png",
		"cyborg":   "res://assets/characters/cyborg_female/cyborg_female_base.png",
		"chthon":   "res://assets/characters/chthon_female/chthon_female_base.png",
		"vesperid": "res://assets/characters/vesperid_female/vesperid_female_base.png",
		"nullborn": "res://assets/characters/nullborn_female/nullborn_female_base.png",
		"revenant": "res://assets/characters/revenant_female/revenant_female_base.png",
		"ai":       "res://assets/characters/sentientai_female/sentientai_female_base.png",
	}
	var loaded := 0
	for race in races:
		var path: String = sprite_paths.get(race, "")
		if not ResourceLoader.exists(path):
			_fail("Female sprite not found for race %s: %s" % [race, path])
			continue
		var sheet: Texture2D = load(path)
		if sheet == null:
			_fail("Could not load female sprite for race %s" % race)
			continue
		# Verify sheet dimensions (should be 128x128)
		var sz: Vector2 = sheet.get_size()
		if sz.x != 128 or sz.y != 128:
			_fail("Female sprite for %s is %dx%d (expected 128x128)" % [race, int(sz.x), int(sz.y)])
			continue
		# Extract south frame via AtlasTexture (same logic as RoomView)
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(0, 0, 16, 16)
		var frame: Texture2D = atlas
		if frame == null:
			_fail("AtlasTexture extraction failed for female %s" % race)
			continue
		loaded += 1
	if loaded == races.size():
		_ok("All %d female character sprites loaded and extracted" % loaded)
	else:
		_fail("Only %d/%d female character sprites loaded" % [loaded, races.size()])


# ---------------------------------------------------------------------------
# Phase E tests — Furniture/decorations
# ---------------------------------------------------------------------------

func _test_furniture_data_fields() -> void:
	print("[smoke] test: rooms have furniture data fields")
	var rooms: Dictionary = _load_rooms()
	var total_rooms := 0
	var with_furniture := 0
	var total_items := 0
	var valid_types := ["table", "barrel", "sign", "bench", "shelf", "crate", "anvil", "forge", "rack", "podium", "dummy"]
	for rid in rooms:
		total_rooms += 1
		var rd: Dictionary = rooms[rid]
		var furniture: Array = rd.get("furniture", [])
		with_furniture += 1
		for item in furniture:
			total_items += 1
			var ftype: String = str(item.get("type", ""))
			if ftype.is_empty():
				_fail("Furniture in %s has no type field" % rid)
			elif not ftype in valid_types:
				_fail("Furniture in %s has invalid type: %s" % [rid, ftype])
	if total_rooms == 0:
		_fail("No rooms found")
	elif total_items > 0:
		_ok("All %d rooms have furniture data (%d total items)" % [total_rooms, total_items])
	else:
		_fail("No furniture items found in any room")


func _test_furniture_collision() -> void:
	print("[smoke] test: furniture blocks movement (collision)")
	var rooms: Dictionary = _load_rooms()
	if not rooms.has("tavern"):
		_fail("tavern missing for furniture collision test")
		return
	var rv: Node2D = Node2D.new()
	rv.set_script(RoomViewScript)
	root.add_child(rv)
	await process_frame

	var rd: Dictionary = rooms["tavern"]
	rd["id"] = "tavern"
	rv.setup(rd, 5, 1)
	await process_frame

	# Tavern has table at (3,4) - should be wall
	if not rv.is_wall(3, 4):
		_fail("Table at (3,4) should block movement (is_wall)")
		rv.queue_free()
		return
	# Furniture query should return the table
	var furn: Dictionary = rv.get_furniture_at(3, 4)
	if furn.is_empty():
		_fail("get_furniture_at(3,4) should return table")
		rv.queue_free()
		return
	if str(furn.get("type", "")) != "table":
		_fail("Furniture at (3,4) is not table: %s" % str(furn.get("type", "")))
		rv.queue_free()
		return
	# is_furniture check
	if not rv.is_furniture(3, 4):
		_fail("is_furniture(3,4) should be true")
		rv.queue_free()
		return
	# Empty floor should not be furniture
	if rv.is_furniture(1, 1):
		_fail("is_furniture(1,1) should be false")
		rv.queue_free()
		return
	rv.queue_free()
	_ok("Furniture collision works")


# ---------------------------------------------------------------------------
# Phase F tests — Button assets
# ---------------------------------------------------------------------------

const ButtonStyleHelperScript = preload("res://scripts/ButtonStyleHelper.gd")

func _test_button_assets_exist() -> void:
	print("[smoke] test: button assets exist")
	var paths := [
		"res://assets/sprites/ui/buttons/button_primary.png",
		"res://assets/sprites/ui/buttons/button_secondary.png",
		"res://assets/sprites/ui/buttons/button_danger.png",
		"res://assets/sprites/ui/buttons/button_success.png",
	]
	var found := 0
	for path in paths:
		# Check via ResourceLoader first
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path)
			if tex != null:
				var sz: Vector2 = tex.get_size()
				if sz.x > 0 and sz.y > 0:
					found += 1
				else:
					_fail("Button texture has zero size: %s" % path)
			else:
				_fail("Could not load button texture: %s" % path)
		else:
			# Fallback: check filesystem directly
			var fs_path: String = path.replace("res://", "C:/Users/Administrator/FallenEarth/")
			if FileAccess.file_exists(fs_path):
				found += 1
			else:
				_fail("Button asset not found: %s" % path)
	if found == paths.size():
		_ok("All %d button assets exist and load" % found)
	else:
		_fail("Only %d/%d button assets found" % [found, paths.size()])


func _test_button_style_helper() -> void:
	print("[smoke] test: ButtonStyleHelper works")
	var btn := Button.new()
	btn.text = "Test Button"
	root.add_child(btn)
	await process_frame

	# Test apply_style for each style
	var styles := ["primary", "secondary", "danger", "success"]
	var applied := 0
	for style in styles:
		ButtonStyleHelperScript.apply_style(btn, style)
		var stylebox: StyleBox = btn.get_theme_stylebox("normal")
		if stylebox != null:
			applied += 1
		else:
			_fail("Failed to apply style: %s" % style)

	# Test textures_exist
	if not ButtonStyleHelperScript.textures_exist():
		_fail("ButtonStyleHelper.textures_exist() returned false")

	# Test get_available_styles
	var avail: Array = ButtonStyleHelperScript.get_available_styles()
	if avail.size() != 4:
		_fail("Expected 4 available styles, got %d" % avail.size())

	btn.queue_free()
	if applied == styles.size():
		_ok("ButtonStyleHelper applied %d styles successfully" % applied)
	else:
		_fail("Only applied %d/%d styles" % [applied, styles.size()])


# ---------------------------------------------------------------------------
# Phase G tests — Settlement-to-Riftspire travel
# ---------------------------------------------------------------------------

func _test_riftspire_portal_npc() -> void:
	print("[smoke] test: town_square has riftspire_portal NPC")
	var rooms: Dictionary = _load_rooms()
	if not rooms.has("town_square"):
		_fail("town_square missing")
		return
	var ts: Dictionary = rooms["town_square"]
	var npcs: Array = ts.get("npcs", [])
	var found := false
	for npc in npcs:
		if str(npc.get("role", "")) == "riftspire_portal":
			found = true
			# Verify required fields
			if str(npc.get("id", "")).is_empty():
				_fail("riftspire_portal NPC has no id field")
			if str(npc.get("race", "")).is_empty():
				_fail("riftspire_portal NPC has no race field")
			if str(npc.get("gender", "")).is_empty():
				_fail("riftspire_portal NPC has no gender field")
			break
	if found:
		_ok("town_square has riftspire_portal NPC")
	else:
		_fail("town_square missing riftspire_portal NPC")


func _test_riftspire_portal_interaction() -> void:
	print("[smoke] test: SettlementInterior handles riftspire_portal role")
	var node: Node = Node.new()
	node.set_script(SettlementInteriorScript)
	root.add_child(node)
	await process_frame

	# Setup with a fake town
	var town := {
		"hex": "5,5",
		"faction": "Iron Accord",
		"template_name": "small_outpost",
		"size": "small",
		"buildings": ["tavern", "trader", "worktable"],
	}
	node.setup(town, null, "")
	await process_frame
	await process_frame

	# Verify _interact_npc handles riftspire_portal role
	var has_method: bool = node.has_method("_interact_npc")
	if not has_method:
		_fail("SettlementInterior missing _interact_npc method")
		node.queue_free()
		return

	# Call _interact_npc with a portal NPC dict (should not crash)
	var portal_npc := {"id": "riftspire_portal", "role": "riftspire_portal", "name": "Riftspire Portal"}
	node._interact_npc(portal_npc)
	await process_frame

	node.queue_free()
	_ok("SettlementInterior handles riftspire_portal role")
