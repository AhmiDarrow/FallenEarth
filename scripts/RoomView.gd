## RoomView — Renders a single settlement interior room.
##
## Draws the grid (walls/floor/exits), NPC character sprites, and manages
## collision queries for movement and interaction.
## Supports biome floor textures and faction-themed wall accents.
class_name RoomView
extends Node2D

const WALL := "#"
const FLOOR := "."
const EXIT := "X"

const CELL_SIZE := 24

const COLOR_WALL    := Color(0.10, 0.10, 0.18)
const COLOR_FLOOR   := Color(0.16, 0.16, 0.24)
const COLOR_EXIT    := Color(0.16, 0.35, 0.24)
const COLOR_NPC_BG  := Color(0.25, 0.25, 0.35)

# Furniture type → color mapping
const FURNITURE_COLORS := {
	"table":   Color(0.45, 0.35, 0.25),  # brown wood
	"barrel":  Color(0.50, 0.40, 0.20),  # dark brown
	"sign":    Color(0.60, 0.50, 0.30),  # light brown
	"bench":   Color(0.40, 0.30, 0.20),  # dark wood
	"shelf":   Color(0.55, 0.45, 0.35),  # medium brown
	"crate":   Color(0.50, 0.45, 0.30),  # tan
	"anvil":   Color(0.30, 0.30, 0.35),  # dark metal
	"forge":   Color(0.60, 0.25, 0.15),  # fiery red
	"rack":    Color(0.35, 0.35, 0.40),  # metal grey
	"podium":  Color(0.40, 0.35, 0.25),  # polished wood
	"dummy":   Color(0.55, 0.50, 0.40),  # straw colored
}

# Faction-themed wall accent colors (top row of room)
const FACTION_WALL_ACCENTS := {
	"":           Color(0.10, 0.10, 0.18),  # default (no faction)
	"iron_accord": Color(0.25, 0.20, 0.15),  # rusty brown
	"hollow_covenant": Color(0.12, 0.08, 0.18),  # deep purple
	"ash_serpents": Color(0.18, 0.12, 0.08),  # scorched orange
	"veilwardens": Color(0.08, 0.12, 0.18),  # void blue
	"neon_choir": Color(0.08, 0.18, 0.18),  # neon teal
	"dust_parliament": Color(0.15, 0.13, 0.10),  # sandy beige
	"bone_circuit": Color(0.18, 0.15, 0.12),  # bone white
	"black_ledger": Color(0.08, 0.08, 0.12),  # ink black
	"last_caravans": Color(0.15, 0.12, 0.08),  # leather brown
	"echo_wardens": Color(0.10, 0.12, 0.15),  # stone grey
}

# NPC race → sprite path mapping (male and female variants)
const RACE_SPRITES := {
	"human": {
		"male":   "res://assets/characters/human_male/human_male_base.png",
		"female": "res://assets/characters/human_female/human_female_base.png",
	},
	"mutant": {
		"male":   "res://assets/characters/mutant_male/mutant_male_base.png",
		"female": "res://assets/characters/mutant_female/mutant_female_base.png",
	},
	"ai": {
		"male":   "res://assets/characters/sentientai_male/sentientai_male_base.png",
		"female": "res://assets/characters/sentientai_female/sentientai_female_base.png",
	},
	"cyborg": {
		"male":   "res://assets/characters/cyborg_male/cyborg_male_base.png",
		"female": "res://assets/characters/cyborg_female/cyborg_female_base.png",
	},
	"chthon": {
		"male":   "res://assets/characters/chthon_male/chthon_male_base.png",
		"female": "res://assets/characters/chthon_female/chthon_female_base.png",
	},
	"vesperid": {
		"male":   "res://assets/characters/vesperid_male/vesperid_male_base.png",
		"female": "res://assets/characters/vesperid_female/vesperid_female_base.png",
	},
	"nullborn": {
		"male":   "res://assets/characters/nullborn_male/nullborn_male_base.png",
		"female": "res://assets/characters/nullborn_female/nullborn_female_base.png",
	},
	"revenant": {
		"male":   "res://assets/characters/revenant_male/revenant_male_base.png",
		"female": "res://assets/characters/revenant_female/revenant_female_base.png",
	},
}

# Sprite sheet layout: 128x128, 8 directions in 2 rows of 4.
# Each frame is 16x16. South = row 0, col 0.
const SPRITE_FRAME_SIZE := 16
const SPRITE_SHEET_SIZE := 128
const SPRITE_DIR_ROW := 0  # south row
const SPRITE_DIR_COL := 0  # south col

var room_id: String = ""
var room_name: String = ""
var grid_w: int = 12
var grid_h: int = 10
var _grid: Array = []
var _npcs: Array = []
var _exits: Array = []
var _furniture: Array = []
var _settlement_exit: Dictionary = {}
var _npc_visuals: Array = []
var _player_cell: Vector2i = Vector2i(5, 5)
var _biome: String = ""
var _faction: String = ""
var _floor_texture: Texture2D = null


func setup(room_data: Dictionary, start_x: int = 5, start_y: int = 1, biome: String = "", faction: String = "") -> void:
	room_id = str(room_data.get("id", ""))
	room_name = str(room_data.get("name", ""))
	_grid = room_data.get("grid", [])
	_npcs = room_data.get("npcs", [])
	_exits = room_data.get("exits", [])
	_furniture = room_data.get("furniture", [])
	_settlement_exit = room_data.get("settlement_exit", {})
	_player_cell = Vector2i(start_x, start_y)
	_biome = biome
	_faction = faction
	_load_floor_texture()
	_build_visuals()


func _load_floor_texture() -> void:
	if _biome.is_empty():
		return
	var path := "res://assets/tilesets/%s/ground.png" % _biome
	if ResourceLoader.exists(path):
		_floor_texture = load(path)


func _build_visuals() -> void:
	for child in get_children():
		child.queue_free()
	_npc_visuals.clear()

	if _grid.is_empty():
		return

	var wall_accent: Color = FACTION_WALL_ACCENTS.get(_faction, COLOR_WALL)

	# Draw grid cells
	for y in mini(_grid.size(), grid_h):
		var row: String = str(_grid[y])
		for x in mini(row.length(), grid_w):
			var ch: String = row[x]
			match ch:
				WALL:
					var rect := ColorRect.new()
					rect.position = Vector2(x * CELL_SIZE, y * CELL_SIZE)
					rect.size = Vector2(CELL_SIZE, CELL_SIZE)
					rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
					# Top row and bottom row get faction accent
					if y == 0 or y == grid_h - 1:
						rect.color = wall_accent
					else:
						rect.color = COLOR_WALL
					add_child(rect)
				EXIT:
					var rect := ColorRect.new()
					rect.position = Vector2(x * CELL_SIZE, y * CELL_SIZE)
					rect.size = Vector2(CELL_SIZE, CELL_SIZE)
					rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
					rect.color = COLOR_EXIT
					add_child(rect)
				_:
					# Floor cell — use biome texture if available
					if _floor_texture != null:
						var spr := Sprite2D.new()
						spr.position = Vector2(x * CELL_SIZE + CELL_SIZE * 0.5, y * CELL_SIZE + CELL_SIZE * 0.5)
						spr.texture = _floor_texture
						spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
						spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
						add_child(spr)
					else:
						var rect := ColorRect.new()
						rect.position = Vector2(x * CELL_SIZE, y * CELL_SIZE)
						rect.size = Vector2(CELL_SIZE, CELL_SIZE)
						rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
						rect.color = COLOR_FLOOR
						add_child(rect)

	# Draw room name label
	var title := Label.new()
	title.name = "RoomTitle"
	title.text = room_name
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 2)
	title.position = Vector2(4, -16)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	# Draw NPC character sprites
	for npc in _npcs:
		var npc_node := _create_npc_visual(npc)
		add_child(npc_node)
		_npc_visuals.append({"data": npc, "node": npc_node})

	# Draw furniture
	for item in _furniture:
		var furn_node := _create_furniture_visual(item)
		add_child(furn_node)

	# Draw settlement exit label if present
	if not _settlement_exit.is_empty():
		var ex: int = int(_settlement_exit.get("x", 0))
		var ey: int = int(_settlement_exit.get("y", 0))
		var lbl := Label.new()
		lbl.text = "<"
		lbl.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.position = Vector2(ex * CELL_SIZE + 6, ey * CELL_SIZE + 2)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lbl)


func _create_npc_visual(npc: Dictionary) -> Node2D:
	var holder := Node2D.new()
	var nx: int = int(npc.get("x", 0))
	var ny: int = int(npc.get("y", 0))
	holder.position = Vector2(nx * CELL_SIZE + CELL_SIZE * 0.5, ny * CELL_SIZE + CELL_SIZE * 0.5)

	# Try to load character sprite from race + gender
	var race: String = str(npc.get("race", ""))
	var gender: String = str(npc.get("gender", "male"))
	var race_sprites: Dictionary = RACE_SPRITES.get(race, {})
	var sprite_path: String = race_sprites.get(gender, race_sprites.get("male", ""))
	var has_sprite: bool = false

	if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
		var sheet: Texture2D = load(sprite_path)
		if sheet != null:
			# Extract south-facing frame (row 0, col 0) from 128x128 sheet
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(
				SPRITE_DIR_COL * SPRITE_FRAME_SIZE,
				SPRITE_DIR_ROW * SPRITE_FRAME_SIZE,
				SPRITE_FRAME_SIZE,
				SPRITE_FRAME_SIZE
			)
			var spr := Sprite2D.new()
			spr.name = "Sprite"
			spr.texture = atlas
			# Scale 16px frame to fit nicely in 24px cell (~1.375x)
			spr.scale = Vector2(1.4, 1.4)
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(spr)
			has_sprite = true

	if not has_sprite:
		# Fallback: colored dot (same as before)
		var bg := ColorRect.new()
		bg.name = "BG"
		bg.color = COLOR_NPC_BG
		bg.size = Vector2(16, 16)
		bg.position = Vector2(-8, -8)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(bg)

		var r: float = float(npc.get("color", [0.7, 0.7, 0.7])[0])
		var g: float = float(npc.get("color", [0.7, 0.7, 0.7])[1])
		var b: float = float(npc.get("color", [0.7, 0.7, 0.7])[2])
		var dot := ColorRect.new()
		dot.name = "Dot"
		dot.color = Color(r, g, b)
		dot.size = Vector2(10, 10)
		dot.position = Vector2(-5, -5)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(dot)

	# Name label (always shown)
	var lbl := Label.new()
	lbl.name = "Name"
	lbl.text = str(npc.get("name", "?"))
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 1)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-24, 10)
	lbl.size = Vector2(48, 12)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(lbl)

	return holder


func _create_furniture_visual(item: Dictionary) -> Node2D:
	var holder := Node2D.new()
	var fx: int = int(item.get("x", 0))
	var fy: int = int(item.get("y", 0))
	holder.position = Vector2(fx * CELL_SIZE + CELL_SIZE * 0.5, fy * CELL_SIZE + CELL_SIZE * 0.5)

	var ftype: String = str(item.get("type", ""))
	var color: Color = FURNITURE_COLORS.get(ftype, Color(0.4, 0.4, 0.4))

	# Draw furniture as colored rectangle
	var rect := ColorRect.new()
	rect.name = "Furniture"
	rect.color = color
	rect.size = Vector2(CELL_SIZE * 0.8, CELL_SIZE * 0.8)
	rect.position = Vector2(-CELL_SIZE * 0.4, -CELL_SIZE * 0.4)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(rect)

	# Add label for sign type
	if ftype == "sign" or ftype == "podium":
		var lbl := Label.new()
		lbl.name = "Label"
		lbl.text = str(item.get("label", ftype.left(3).to_upper()))
		lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		lbl.add_theme_font_size_override("font_size", 7)
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		lbl.add_theme_constant_override("outline_size", 1)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.position = Vector2(-20, -6)
		lbl.size = Vector2(40, 12)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(lbl)

	return holder


# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

func is_wall(x: int, y: int) -> bool:
	if y < 0 or y >= _grid.size():
		return true
	var row: String = str(_grid[y])
	if x < 0 or x >= row.length():
		return true
	if row[x] == WALL:
		return true
	# Also treat furniture as walls for collision
	for item in _furniture:
		if int(item.get("x", -1)) == x and int(item.get("y", -1)) == y:
			return true
	return false


func is_furniture(x: int, y: int) -> bool:
	for item in _furniture:
		if int(item.get("x", -1)) == x and int(item.get("y", -1)) == y:
			return true
	return false


func get_furniture_at(x: int, y: int) -> Dictionary:
	for item in _furniture:
		if int(item.get("x", -1)) == x and int(item.get("y", -1)) == y:
			return item
	return {}


func is_exit(x: int, y: int) -> bool:
	for exit in _exits:
		if int(exit.get("x", -1)) == x and int(exit.get("y", -1)) == y:
			return true
	return false


func is_settlement_exit(x: int, y: int) -> bool:
	if _settlement_exit.is_empty():
		return false
	return int(_settlement_exit.get("x", -1)) == x and int(_settlement_exit.get("y", -1)) == y


func get_exit_at(x: int, y: int) -> Dictionary:
	for exit in _exits:
		if int(exit.get("x", -1)) == x and int(exit.get("y", -1)) == y:
			return exit
	return {}


func get_npc_at(x: int, y: int) -> Dictionary:
	for entry in _npc_visuals:
		var npc: Dictionary = entry.get("data", {})
		if int(npc.get("x", -1)) == x and int(npc.get("y", -1)) == y:
			return npc
	return {}


func get_npc_near(x: int, y: int) -> Dictionary:
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var npc: Dictionary = get_npc_at(x + dx, y + dy)
			if not npc.is_empty():
				return npc
	return {}


func get_exit_near(x: int, y: int) -> Dictionary:
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var exit: Dictionary = get_exit_at(x + dx, y + dy)
			if not exit.is_empty():
				return exit
	return {}


func is_settlement_exit_near(x: int, y: int) -> bool:
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if is_settlement_exit(x + dx, y + dy):
				return true
	return false


func set_player_cell(x: int, y: int) -> void:
	_player_cell = Vector2i(x, y)


func get_player_cell() -> Vector2i:
	return _player_cell


func get_room_size() -> Vector2i:
	return Vector2i(grid_w, grid_h)


func get_pixel_size() -> Vector2:
	return Vector2(grid_w * CELL_SIZE, grid_h * CELL_SIZE)


# ---------------------------------------------------------------------------
# Ambient behavior support
# ---------------------------------------------------------------------------

func update_npc_position(npc_id: String, new_x: int, new_y: int) -> void:
	for entry in _npc_visuals:
		var npc: Dictionary = entry.get("data", {})
		if str(npc.get("id", "")) == npc_id:
			var node: Node2D = entry.get("node", null)
			if node != null and is_instance_valid(node):
				# Update position with interpolation
				var target_pos := Vector2(new_x * CELL_SIZE + CELL_SIZE * 0.5, new_y * CELL_SIZE + CELL_SIZE * 0.5)
				var tween := create_tween()
				tween.tween_property(node, "position", target_pos, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
			npc["x"] = new_x
			npc["y"] = new_y
			break


func show_mood_emoji(npc_id: String, emoji: String) -> void:
	for entry in _npc_visuals:
		var npc: Dictionary = entry.get("data", {})
		if str(npc.get("id", "")) == npc_id:
			var node: Node2D = entry.get("node", null)
			if node != null and is_instance_valid(node):
				# Remove existing mood emoji
				var old_emoji: Label = node.get_node_or_null("MoodEmoji") as Label
				if old_emoji != null:
					old_emoji.queue_free()
				# Add new emoji if not empty
				if not emoji.is_empty():
					var emoji_label := Label.new()
					emoji_label.name = "MoodEmoji"
					emoji_label.text = emoji
					emoji_label.add_theme_font_size_override("font_size", 10)
					emoji_label.position = Vector2(-6, -18)
					emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
					node.add_child(emoji_label)
			break


func is_player_nearby(npc_x: int, npc_y: int, radius: int = 3) -> bool:
	var dx: int = abs(_player_cell.x - npc_x)
	var dy: int = abs(_player_cell.y - npc_y)
	return dx <= radius and dy <= radius


func get_npc_visual_node(npc_id: String) -> Node2D:
	for entry in _npc_visuals:
		var npc: Dictionary = entry.get("data", {})
		if str(npc.get("id", "")) == npc_id:
			return entry.get("node", null) as Node2D
	return null
