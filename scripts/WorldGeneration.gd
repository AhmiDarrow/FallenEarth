## WorldGeneration — Visual hex-sphere preview with click-to-select starting tile.
extends Control

@onready var seed_edit: LineEdit = $VBox/TopBar/SeedHBox/SeedEdit
@onready var random_btn: Button = $VBox/TopBar/SeedHBox/RandomButton
@onready var small_btn: Button = $VBox/TopBar/SizeHBox/SmallBtn
@onready var medium_btn: Button = $VBox/TopBar/SizeHBox/MediumBtn
@onready var large_btn: Button = $VBox/TopBar/SizeHBox/LargeBtn
@onready var generate_btn: Button = $VBox/TopBar/GenerateBtn
@onready var back_btn: Button = $VBox/TopRow/BackBtn
@onready var continue_btn: Button = $VBox/ContentHBox/SideVBox/ContinueBtn
@onready var hex_grid: Node2D = $VBox/ContentHBox/HexMargin/HexGrid
@onready var hex_margin: MarginContainer = $VBox/ContentHBox/HexMargin
@onready var world_info_label: RichTextLabel = $VBox/ContentHBox/SideVBox/WorldInfoPanel/WorldInfoLabel
@onready var selected_info_label: RichTextLabel = $VBox/ContentHBox/SideVBox/SelectedInfoPanel/SelectedInfoLabel

var world_generator: WorldGenerator = null
var generated_seed: String = ""
var generated_world: Dictionary = {}
var start_tile_key: String = ""
var start_tile_info: Dictionary = {}
var _hex_nodes: Dictionary = {}  # "q,r" -> Polygon2D
var _selected_key: String = ""
var _world_size: int = 12
var _updating_size: bool = false
var _cursor_q: int = 0
var _cursor_r: int = 0
var _preview_focused: bool = false
var _selected_glow: Polygon2D = null

const DEFAULT_SEED := "FallenEarth"
const SIZE_RADII := {"small": 8, "medium": 15, "large": 23}

const BIOME_COLORS := {
	"Ash Wastes": Color(0.75, 0.65, 0.5),
	"Rust Canyons": Color(0.85, 0.45, 0.35),
	"Neon Bogs": Color(0.4, 0.85, 0.55),
	"Scorched Plains": Color(0.9, 0.6, 0.3),
	"Ironwood Thicket": Color(0.35, 0.6, 0.35),
	"Glass Dunes": Color(0.7, 0.8, 0.95),
	"Corpse Fields": Color(0.55, 0.45, 0.5),
	"Stormspire Highlands": Color(0.5, 0.55, 0.75),
	"Toxin Marshes": Color(0.45, 0.7, 0.4),
	"Dead City Outskirts": Color(0.5, 0.5, 0.55),
	"Riftspire": Color(1.0, 0.85, 0.2),
}
const RIFT_COLOR := Color(1.0, 0.85, 0.2)
const SETTLEMENT_COLOR := Color(0.9, 0.9, 0.95)


func _ready() -> void:
	# Background
	var bg_col := get_node_or_null("BG") as ColorRect
	if bg_col != null:
		bg_col.color = Color(0.04, 0.04, 0.07, 0.85)
	# Style buttons
	ButtonStyleHelper.apply_secondary(back_btn)
	ButtonStyleHelper.apply_primary(generate_btn)
	ButtonStyleHelper.apply_primary(continue_btn)
	ButtonStyleHelper.apply_ghost(random_btn)
	ButtonStyleHelper.apply_ghost(small_btn)
	ButtonStyleHelper.apply_primary(medium_btn)
	ButtonStyleHelper.apply_ghost(large_btn)
	# Wire signals
	back_btn.pressed.connect(_on_back_pressed)
	random_btn.pressed.connect(_on_random_seed_pressed)
	generate_btn.pressed.connect(_on_generate_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)

	small_btn.toggled.connect(_on_size_toggled.bind("small"))
	medium_btn.toggled.connect(_on_size_toggled.bind("medium"))
	large_btn.toggled.connect(_on_size_toggled.bind("large"))

	hex_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE

	seed_edit.text = DEFAULT_SEED
	continue_btn.disabled = true
	_update_world_info_label()
	_update_selected_info_label()

	world_generator = WorldGenerator.new()
	add_child(world_generator)
	if not world_generator.initialize():
		world_info_label.text = "[color=red]Failed to load biome data![/color]"
		generate_btn.disabled = true


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


func _on_random_seed_pressed() -> void:
	seed_edit.text = "SEED_" + str(randi() % 100000)


func _on_size_toggled(pressed: bool, size_name: String) -> void:
	if not pressed or _updating_size:
		return
	_updating_size = true
	_world_size = SIZE_RADII[size_name]
	small_btn.button_pressed = (size_name == "small")
	medium_btn.button_pressed = (size_name == "medium")
	large_btn.button_pressed = (size_name == "large")
	_updating_size = false


func _on_generate_pressed() -> void:
	var chosen_seed: String = seed_edit.text.strip_edges()
	if chosen_seed.is_empty():
		chosen_seed = DEFAULT_SEED
		seed_edit.text = chosen_seed

	world_info_label.text = "[i]Generating hexagonal sphere world for seed: " + chosen_seed + "...[/i]"

	if not world_generator.initialize():
		world_info_label.text = "[color=red]World generator not ready. Check biomes.json.[/color]"
		return

	generated_world = world_generator.generate(chosen_seed, 1.0, _world_size)
	generated_seed = chosen_seed

	# Auto-pick best start candidate
	var cands = world_generator.get_starting_candidates(5)
	if cands.size() > 0:
		start_tile_key = cands[0]["key"]
		start_tile_info = cands[0]["tile"]

	_render_hex_preview()
	_update_world_info_label()

	if start_tile_key != "":
		var parts: PackedStringArray = start_tile_key.split(",")
		if parts.size() >= 2:
			_cursor_q = int(parts[0])
			_cursor_r = int(parts[1])
		select_hex(start_tile_key)
		_update_cursor_highlight()
		_preview_focused = true

	continue_btn.disabled = false
	print("[WorldGeneration] Hex sphere generated with seed: ", chosen_seed)


func _render_hex_preview() -> void:
	# Clear old hexes
	for c in hex_grid.get_children():
		if c is Camera2D:
			continue
		c.queue_free()
	_hex_nodes.clear()
	_selected_glow = null

	if generated_world.is_empty():
		return

	# Determine hex render size based on world radius so sphere fits in preview
	var hex_size: float = 168.0 / max(1, _world_size)
	var shape: PackedVector2Array = WorldGenerator.hex_shape(hex_size)

	# Compute bounding box to center the grid
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	var hex_centers: Dictionary = {}  # key -> Vector2

	for key in generated_world.keys():
		var parts: PackedStringArray = key.split(",")
		if parts.size() < 2:
			continue
		var q := int(parts[0])
		var r := int(parts[1])
		var pos := WorldGenerator.axial_to_pixel(q, r, hex_size)
		hex_centers[key] = pos
		min_pos.x = minf(min_pos.x, pos.x)
		min_pos.y = minf(min_pos.y, pos.y)
		max_pos.x = maxf(max_pos.x, pos.x)
		max_pos.y = maxf(max_pos.y, pos.y)

	var center_offset := (min_pos + max_pos) * 0.5

	# Render each hex
	for key in generated_world.keys():
		var tile: Dictionary = generated_world[key]
		var pos: Vector2 = hex_centers[key]

		var poly := Polygon2D.new()
		poly.polygon = shape
		poly.position = pos - center_offset
		poly.color = _biome_color(str(tile.get("name", "")))

		if tile.get("is_start_candidate", false):
			poly.modulate = Color(1, 1, 1, 1)
		else:
			poly.modulate = Color(0.85, 0.85, 0.85, 0.85)

		poly.set_meta("q", tile.get("q", 0))
		poly.set_meta("r", tile.get("r", 0))
		poly.set_meta("key", key)
		hex_grid.add_child(poly)
		_hex_nodes[key] = poly

		# Riftspire marker — bright diamond
		if tile.get("is_riftspire", false):
			var marker := Polygon2D.new()
			var ms := hex_size * 0.35
			marker.polygon = PackedVector2Array([
				Vector2(0, -ms), Vector2(ms, 0), Vector2(0, ms), Vector2(-ms, 0)
			])
			marker.position = pos - center_offset
			marker.color = RIFT_COLOR
			hex_grid.add_child(marker)
			hex_grid.move_child(marker, hex_grid.get_child_count() - 1)

		# Settlement marker — small white square
		elif tile.get("is_town", false):
			var marker := Polygon2D.new()
			var ms := hex_size * 0.2
			marker.polygon = PackedVector2Array([
				Vector2(-ms, -ms), Vector2(ms, -ms), Vector2(ms, ms), Vector2(-ms, ms)
			])
			marker.position = pos - center_offset
			marker.color = SETTLEMENT_COLOR
			hex_grid.add_child(marker)
			hex_grid.move_child(marker, hex_grid.get_child_count() - 1)

	# Position the grid at center of its parent container
	var parent_ctrl := hex_grid.get_parent() as Control
	if is_instance_valid(parent_ctrl) and parent_ctrl.size.length_squared() > 0.0:
		hex_grid.position = parent_ctrl.size * 0.5

	print("[WorldGeneration] Rendered %d hexes (radius=%d, size=%.1f)" % [generated_world.size(), _world_size, hex_size])


func _input(event: InputEvent) -> void:
	if generated_world.is_empty():
		return

	# Mouse click: hit-test hexes in the preview panel
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos: Vector2 = hex_grid.get_local_mouse_position()
		for key in _hex_nodes:
			var poly: Polygon2D = _hex_nodes[key]
			var rel := click_pos - poly.position
			if Geometry2D.is_point_in_polygon(rel, poly.polygon):
				_cursor_q = poly.get_meta("q", 0)
				_cursor_r = poly.get_meta("r", 0)
				select_hex(key)
				_update_cursor_highlight()
				_preview_focused = true
				get_viewport().gui_release_focus()
				return

	# Click anywhere else loses preview focus
	_preview_focused = false

	# Keyboard navigation: only when no text field has focus
	if event is InputEventKey and event.pressed and not event.echo:
		if not _preview_focused:
			return
		var dir: Vector2i
		match event.keycode:
			KEY_W, KEY_UP:
				dir = Vector2i(0, -1)
			KEY_S, KEY_DOWN:
				dir = Vector2i(0, 1)
			KEY_A, KEY_LEFT:
				dir = Vector2i(-1, 0)
			KEY_D, KEY_RIGHT:
				dir = Vector2i(1, 0)
			KEY_ENTER, KEY_SPACE:
				_maybe_select_cursor()
				get_viewport().gui_release_focus()
			_:
				return
		_try_move_cursor(dir.x, dir.y)


func _try_move_cursor(dq: int, dr: int) -> void:
	var nq := _cursor_q + dq
	var nr := _cursor_r + dr
	var key := "%d,%d" % [nq, nr]
	if _hex_nodes.has(key):
		_cursor_q = nq
		_cursor_r = nr
		_update_cursor_highlight()


func _maybe_select_cursor() -> void:
	var key := "%d,%d" % [_cursor_q, _cursor_r]
	if _hex_nodes.has(key):
		select_hex(key)


func _update_cursor_highlight() -> void:
	for key in _hex_nodes:
		var poly: Polygon2D = _hex_nodes[key]
		if key == _selected_key:
			continue
		var is_cursor := (int(poly.get_meta("q", 0)) == _cursor_q and int(poly.get_meta("r", 0)) == _cursor_r)
		if is_cursor:
			poly.modulate = Color(1, 1, 1, 1)
		else:
			var tile: Dictionary = generated_world.get(key, {})
			if tile.get("is_start_candidate", false):
				poly.modulate = Color(1, 1, 1, 1)
			else:
				poly.modulate = Color(0.85, 0.85, 0.85, 0.85)


func select_hex(key: String) -> void:
	_selected_key = key
	start_tile_key = key
	start_tile_info = generated_world.get(key, {})

	# Highlight selected hex
	for k in _hex_nodes:
		var poly: Polygon2D = _hex_nodes[k]
		if k == key:
			poly.color = Color(1.0, 0.85, 0.4)
			poly.modulate = Color(1, 1, 1, 1)
		else:
			var tile: Dictionary = generated_world.get(k, {})
			poly.color = _biome_color(str(tile.get("name", "")))
			if tile.get("is_start_candidate", false):
				poly.modulate = Color(1, 1, 1, 1)
			else:
				poly.modulate = Color(0.85, 0.85, 0.85, 0.85)

	# Move selected to top
	if _hex_nodes.has(key):
		hex_grid.move_child(_hex_nodes[key], hex_grid.get_child_count() - 1)

	# Draw golden glow ring around selected
	_draw_selection_glow(_hex_nodes.get(key))

	_update_selected_info_label()
	print("[WorldGeneration] Selected hex: %s" % key)


func _draw_selection_glow(poly: Polygon2D) -> void:
	if not is_instance_valid(poly):
		return
	# Remove old glow immediately
	if is_instance_valid(_selected_glow):
		_selected_glow.queue_free()
		_selected_glow = null

	var glow := Polygon2D.new()
	glow.name = "SelectionGlow"
	glow.polygon = poly.polygon
	glow.position = poly.position
	glow.color = Color(1.0, 0.85, 0.4, 0.5)
	glow.scale = Vector2(1.12, 1.12)
	hex_grid.add_child(glow)
	hex_grid.move_child(glow, hex_grid.get_child_count() - 2)
	_selected_glow = glow


func _on_continue_pressed() -> void:
	if generated_world.is_empty() or start_tile_key.is_empty():
		return

	var gs := get_node_or_null("/root/GameState")
	if is_instance_valid(gs) and gs.has_method("set_world_data"):
		gs.call("set_world_data", generated_seed, generated_world)
		if gs.has_method("set_start_tile"):
			gs.call("set_start_tile", start_tile_key, start_tile_info)

	var nm := get_node_or_null("/root/NPCManager")
	if is_instance_valid(nm) and nm.has_method("generate_for_world"):
		var roster: Variant = nm.call("generate_for_world", generated_seed, generated_world, start_tile_key)
		var npc_count: int = roster.size() if roster is Dictionary else 0
		print("[WorldGeneration] Procedural NPC roster: %d unique recruits." % npc_count)

	print("[WorldGeneration] World ready. Start tile: ", start_tile_key)
	var gm := get_node_or_null("/root/GameManager")
	if is_instance_valid(gm) and gm.has_method("go_to_character_select"):
		gm.call_deferred("go_to_character_select")


func _update_world_info_label() -> void:
	if generated_world.is_empty():
		world_info_label.text = "[i]Enter a seed and generate the world. Then click a hex to select your starting location.[/i]"
		return

	var size_name := "Medium"
	if _world_size == 8: size_name = "Small"
	elif _world_size == 23: size_name = "Large"

	# Biome distribution
	var biome_counts: Dictionary = {}
	for key in generated_world:
		var b: String = str(generated_world[key].get("name", "?"))
		biome_counts[b] = biome_counts.get(b, 0) + 1

	var biome_lines: PackedStringArray = []
	for b in biome_counts:
		biome_lines.append("%s: %d" % [b, biome_counts[b]])

	world_info_label.text = (
		"[b]WORLD INFO[/b]\n" +
		"Seed: %s | %s (r=%d)\n" % [generated_seed, size_name, _world_size] +
		"Tiles: %d | Biomes: %d\n" % [generated_world.size(), biome_counts.size()] +
		"%s" % ", ".join(biome_lines)
	)


func _update_selected_info_label() -> void:
	if _selected_key.is_empty() or start_tile_info.is_empty():
		selected_info_label.text = "[i]Click a hex to see tile info.[/i]"
		return

	var t: Dictionary = start_tile_info
	var biome: String = str(t.get("name", "?"))
	var temp: float = float(t.get("temperature", 0)) * 100.0
	var rain: float = float(t.get("rainfall", 0)) * 100.0
	var elev: float = float(t.get("elevation", 0))
	var rift: float = float(t.get("rift_chance", 0)) * 100.0
	var danger: String = str(t.get("danger_level", "unknown"))
	var tier: int = int(t.get("difficulty_tier", 0))
	var lr: Dictionary = t.get("level_range", {})
	var features: Array = t.get("features", [])
	var risks: Array = t.get("survival_risks", [])

	var tier_colors: Dictionary = {1: "#66bb6a", 2: "#aed581", 3: "#fff176", 4: "#ffab91", 5: "#ef5350"}
	var tier_color: String = str(tier_colors.get(tier, "#ffffff"))

	var lines: PackedStringArray = [
		"[b]SELECTED HEX[/b]",
		"[color=#c8e6c9]%s[/color] (%s)" % [biome, _selected_key],
		"Temp: %.0f%% | Rain: %.0f%%" % [temp, rain],
		"Elev: %.2f | Rift: %.0f%%" % [elev, rift],
		"[color=%s]Tier %d[/color] | Lv %d-%d" % [tier_color, tier, int(lr.get("min_level", 1)), int(lr.get("max_level", 1))],
		"Danger: %s" % danger.capitalize(),
	]
	if features.size() > 0:
		lines.append("Features: %s" % ", ".join(features))
	if risks.size() > 0:
		lines.append("[color=#ffab91]Risks: %s[/color]" % ", ".join(risks))

	selected_info_label.text = "\n".join(lines)


static func _biome_color(biome: String) -> Color:
	return BIOME_COLORS.get(biome, Color(0.35, 0.35, 0.4))
