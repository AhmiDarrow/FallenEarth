## ResourceVisualManager — Batched visuals for resource nodes, pickups, decor.
##
## Shares one Texture2D per sprite_id across many Sprite2D children (load once).
## MultiMeshInstance2D was abandoned: instance transforms/colors were not
## applied reliably in Godot 4.7 here, so minimap showed nodes while the
## world stayed empty.
class_name ResourceVisualManager
extends Node2D

const CELL_SIZE := 32
const SPRITE_FOLDER := "res://assets/sprites/resource_nodes/"
const PICKUP_FOLDER := "res://assets/sprites/items/"
const DECOR_FOLDER := "res://assets/sprites/decor/"

var _node_layer: Node2D = null
var _pickup_layer: Node2D = null
var _decor_layer: Node2D = null

# cell -> Sprite2D
var _node_sprites: Dictionary = {}
var _pickup_sprites: Dictionary = {}
var _decor_sprites: Dictionary = {}

# sprite_id / item_id -> Texture2D (shared)
var _tex_cache: Dictionary = {}


func setup(node_layer: Node2D, pickup_layer: Node2D, decor_layer: Node2D = null) -> void:
	randomize()
	_clear_visuals()
	_node_layer = node_layer
	_pickup_layer = pickup_layer
	_decor_layer = decor_layer
	_build_node_visuals()
	_build_pickup_visuals()
	if _decor_layer != null:
		_build_decor_visuals()
	push_warning("[RVM] sprites nodes=%d pickups=%d decor=%d tex_cache=%d" % [
		_node_sprites.size(), _pickup_sprites.size(), _decor_sprites.size(), _tex_cache.size()
	])


func _clear_visuals() -> void:
	for c in get_children():
		c.queue_free()
	_node_sprites.clear()
	_pickup_sprites.clear()
	_decor_sprites.clear()


func _build_node_visuals() -> void:
	if not is_instance_valid(_node_layer):
		push_warning("[RVM] node_layer invalid")
		return
	var built := 0
	for child in _node_layer.get_children():
		if not child.has_method("get_node_id"):
			continue
		var nd: Dictionary = child.get("node_data") if "node_data" in child else {}
		if nd.is_empty():
			continue
		var sprite_id: String = str(nd.get("sprite", ""))
		if sprite_id.is_empty():
			continue
		var cell := Vector2i(
			int(floor(child.position.x / float(CELL_SIZE))),
			int(floor(child.position.y / float(CELL_SIZE))),
		)
		var spr := _make_sprite(
			_load_node_texture(sprite_id),
			child.position,
			_node_scale(nd),
			Color.WHITE if not bool(nd.get("passable", false)) else Color(0.92, 0.92, 0.92, 0.95),
			"N_%s_%d_%d" % [sprite_id, cell.x, cell.y]
		)
		_node_sprites[cell] = spr
		built += 1
	push_warning("[RVM] _build_node_visuals: %d sprites" % built)


func _build_pickup_visuals() -> void:
	if not is_instance_valid(_pickup_layer):
		return
	for child in _pickup_layer.get_children():
		if not child.has_method("get_item_id"):
			continue
		var raw_id = child.get("item_id")
		var item_id: String = str(raw_id) if raw_id != null else ""
		if item_id.is_empty():
			continue
		var cell := Vector2i(
			int(floor(child.position.x / float(CELL_SIZE))),
			int(floor(child.position.y / float(CELL_SIZE))),
		)
		var spr := _make_sprite(
			_load_pickup_texture(item_id),
			child.position,
			0.7,
			Color.WHITE,
			"P_%s_%d_%d" % [item_id, cell.x, cell.y]
		)
		_pickup_sprites[cell] = spr


func _build_decor_visuals() -> void:
	if not is_instance_valid(_decor_layer):
		push_warning("[RVM] _decor_layer invalid, skipping decor visuals")
		return
	var built := 0
	for child in _decor_layer.get_children():
		var dd: Dictionary = {}
		if child.has_meta("decor_data"):
			dd = child.get_meta("decor_data")
		if dd.is_empty():
			continue
		var sprite_id: String = str(dd.get("sprite", ""))
		if sprite_id.is_empty():
			continue
		var cell := Vector2i(
			int(floor(child.position.x / float(CELL_SIZE))),
			int(floor(child.position.y / float(CELL_SIZE))),
		)
		var spr := _make_sprite(
			_load_decor_texture(sprite_id),
			child.position,
			_decor_scale(dd),
			Color(0.95, 0.95, 0.95, 0.9) if bool(dd.get("passable", false)) else Color.WHITE,
			"D_%s_%d_%d" % [sprite_id, cell.x, cell.y]
		)
		_decor_sprites[cell] = spr
		built += 1
	push_warning("[RVM] _build_decor_visuals: %d sprites" % built)


func _make_sprite(tex: Texture2D, world_pos: Vector2, scale_val: float, modulate: Color, name_str: String) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.name = name_str
	spr.texture = tex
	spr.centered = true
	spr.position = world_pos
	spr.scale = Vector2(scale_val, scale_val)
	spr.modulate = modulate
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Bottom of sprite sits near cell; taller props read as grounded.
	if tex != null:
		var h: float = float(tex.get_height()) * scale_val
		if h > float(CELL_SIZE):
			spr.offset = Vector2(0, -h * 0.15)
	add_child(spr)
	return spr


func dim_node(cell: Vector2i, dimmed: bool) -> void:
	var spr: Sprite2D = _node_sprites.get(cell) as Sprite2D
	if spr == null or not is_instance_valid(spr):
		return
	spr.modulate = Color(0.4, 0.4, 0.4, 0.5) if dimmed else Color.WHITE
	spr.visible = not dimmed or spr.modulate.a > 0.01


func hide_pickup(cell: Vector2i) -> void:
	var spr: Sprite2D = _pickup_sprites.get(cell) as Sprite2D
	if spr == null or not is_instance_valid(spr):
		return
	spr.visible = false
	_pickup_sprites.erase(cell)


func hide_decor(cell: Vector2i) -> void:
	var spr: Sprite2D = _decor_sprites.get(cell) as Sprite2D
	if spr == null or not is_instance_valid(spr):
		return
	spr.visible = false
	_decor_sprites.erase(cell)


func _node_scale(nd: Dictionary) -> float:
	var sprite_id: String = str(nd.get("sprite", ""))
	# Textures are 64px; cell is 32px — scale 1.0 = 2 cells tall.
	if sprite_id.begins_with("tree_"):
		return 1.35
	if sprite_id.begins_with("ore_"):
		return 0.95
	if sprite_id.begins_with("crystal_"):
		return 0.95
	if sprite_id.begins_with("formation_"):
		return 1.15
	if sprite_id.begins_with("decor_rock"):
		return 1.0
	if sprite_id.begins_with("decor_"):
		return 0.95
	return 1.1


func _decor_scale(dd: Dictionary) -> float:
	var sprite_id: String = str(dd.get("sprite", ""))
	if sprite_id.find("crater") >= 0 or sprite_id.find("wall") >= 0 or sprite_id.find("ruin") >= 0:
		return 1.2
	if sprite_id.find("mushroom") >= 0 or sprite_id.find("flower") >= 0 or sprite_id.find("grass") >= 0:
		return 0.8
	if sprite_id.find("bone") >= 0 or sprite_id.find("skull") >= 0:
		return 0.95
	if sprite_id.find("tower") >= 0 or sprite_id.find("vent") >= 0:
		return 1.1
	return 1.0


func _cached_or_load(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path] as Texture2D
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	if res is Texture2D:
		_tex_cache[path] = res
		return res as Texture2D
	return null


func _load_variant_texture(folders: Array, sprite_id: String) -> Texture2D:
	var paths: Array[String] = []
	for folder in folders:
		for i in range(16):
			var vpath: String = str(folder) + "%s_%02d.png" % [sprite_id, i]
			if ResourceLoader.exists(vpath):
				paths.append(vpath)
		if paths.size() > 0:
			break
	if paths.is_empty():
		return null
	return _cached_or_load(paths[randi() % paths.size()])


func _load_node_texture(sprite_id: String) -> Texture2D:
	var folders: Array = [SPRITE_FOLDER]
	if sprite_id.begins_with("decor_"):
		folders = [DECOR_FOLDER, SPRITE_FOLDER]
	var tex: Texture2D = _load_variant_texture(folders, sprite_id)
	if tex != null:
		return tex
	push_warning("[RVM] No texture for '%s', using placeholder" % sprite_id)
	return _make_placeholder(sprite_id)


func _load_decor_texture(sprite_id: String) -> Texture2D:
	var tex: Texture2D = _load_variant_texture([DECOR_FOLDER], sprite_id)
	if tex != null:
		return tex
	push_warning("[RVM] No decor texture for '%s', using placeholder" % sprite_id)
	return _make_placeholder(sprite_id)


func _load_pickup_texture(item_id: String) -> Texture2D:
	var path: String = PICKUP_FOLDER + item_id + ".png"
	var tex: Texture2D = _cached_or_load(path)
	if tex != null:
		return tex
	return _make_placeholder(item_id)


func _make_placeholder(id: String) -> Texture2D:
	var cache_key := "placeholder:%s" % id
	if _tex_cache.has(cache_key):
		return _tex_cache[cache_key] as Texture2D
	var img := Image.create(CELL_SIZE, CELL_SIZE, false, Image.FORMAT_RGBA8)
	var col: Color = _placeholder_color(id)
	img.fill(col)
	for x in CELL_SIZE:
		img.set_pixel(x, 0, col.darkened(0.4))
		img.set_pixel(x, CELL_SIZE - 1, col.darkened(0.4))
	for y in CELL_SIZE:
		img.set_pixel(0, y, col.darkened(0.4))
		img.set_pixel(CELL_SIZE - 1, y, col.darkened(0.4))
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[cache_key] = tex
	return tex


func _placeholder_color(id: String) -> Color:
	if id.begins_with("tree_"):
		return Color(0.25, 0.50, 0.20)
	if id.begins_with("ore_"):
		return Color(0.60, 0.40, 0.25)
	if id.begins_with("crystal_"):
		return Color(0.35, 0.55, 0.80)
	if id.begins_with("formation_"):
		return Color(0.50, 0.45, 0.40)
	if id.begins_with("decor_"):
		return Color(0.45, 0.42, 0.38)
	if id == "stick":
		return Color(0.55, 0.40, 0.25)
	if id == "stone":
		return Color(0.55, 0.55, 0.50)
	return Color(0.5, 0.5, 0.5)
