## ResourceVisualManager — Efficient batched rendering for resource nodes
## and floor pickups using MultiMeshInstance2D.
##
## v0.9.1c removed per-node Sprite2D for performance (5714 nodes each
## loading a PNG = ~1.8s). This replaces them with MultiMesh batching:
## one MultiMeshInstance2D per sprite type, all instances in one draw call.
##
## Usage: call setup() after LocalMapView.configure() with the node_layer
## and pickup_layer children. The manager reads each node's node_data or
## item_id to determine the sprite, then builds MultiMesh instances.
class_name ResourceVisualManager
extends Node2D

const CELL_SIZE := 24
const SPRITE_FOLDER := "res://assets/resources/"
const PICKUP_FOLDER := "res://assets/pickups/"

var _node_layer: Node2D = null
var _pickup_layer: Node2D = null

# sprite_id -> MultiMeshInstance2D for resource nodes
var _node_meshes: Dictionary = {}
# cell Vector2i -> (sprite_id, instance_index) for O(1) dim/hide
var _node_index: Dictionary = {}
# cell Vector2i -> (item_id, instance_index) for floor pickups
var _pickup_index: Dictionary = {}
# item_id -> MultiMeshInstance2D for floor pickups
var _pickup_meshes: Dictionary = {}


func setup(node_layer: Node2D, pickup_layer: Node2D) -> void:
	_node_layer = node_layer
	_pickup_layer = pickup_layer
	_build_node_visuals()
	_build_pickup_visuals()


func _build_node_visuals() -> void:
	if not is_instance_valid(_node_layer):
		return
	# Phase 1: collect all nodes grouped by sprite_id.
	var groups: Dictionary = {}  # sprite_id -> Array[{cell, node_data}]
	for child in _node_layer.get_children():
		if not child.has_method("get_node_id"):
			continue
		var nd: Dictionary = child.get("node_data") if "node_data" in child else {}
		if nd.is_empty():
			continue
		var sprite_id: String = str(nd.get("sprite", ""))
		if sprite_id.is_empty():
			continue
		var cell: Vector2i = Vector2(
			int(floor(child.position.x / CELL_SIZE)),
			int(floor(child.position.y / CELL_SIZE)),
		)
		if not groups.has(sprite_id):
			groups[sprite_id] = []
		groups[sprite_id].append({"cell": cell, "node_data": nd, "node": child})
	# Phase 2: create a MultiMeshInstance2D per sprite_id.
	for sprite_id in groups:
		var entries: Array = groups[sprite_id]
		var tex: Texture2D = _load_node_texture(sprite_id)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.instance_count = entries.size()
		var mesh_inst := MultiMeshInstance2D.new()
		mesh_inst.multimesh = mm
		mesh_inst.texture = tex
		mesh_inst.name = "Nodes_%s" % sprite_id
		add_child(mesh_inst)
		_node_meshes[sprite_id] = mesh_inst
		# Phase 3: populate each instance's transform.
		for i in range(entries.size()):
			var entry: Dictionary = entries[i]
			var cell: Vector2i = entry["cell"]
			var nd: Dictionary = entry["node_data"]
			var world_pos: Vector2 = Vector2(
				cell.x * CELL_SIZE + CELL_SIZE * 0.5,
				cell.y * CELL_SIZE + CELL_SIZE * 0.5,
			)
			var scale_val: float = _node_scale(nd)
			var xf := Transform2D(0, world_pos)
			xf.x = Vector2(scale_val, 0)
			xf.y = Vector2(0, scale_val)
			mm.set_instance_transform_2d(i, xf)
			# Tint decorations (pool/toxic) slightly differently.
			if bool(nd.get("passable", false)):
				mm.set_instance_color(i, Color(0.85, 0.85, 0.85, 0.9))
			_node_index[cell] = {"sprite_id": sprite_id, "index": i}


func _build_pickup_visuals() -> void:
	if not is_instance_valid(_pickup_layer):
		return
	# Collect floor pickups grouped by item_id.
	var groups: Dictionary = {}
	for child in _pickup_layer.get_children():
		if not child.has_method("get_item_id"):
			continue
		var raw_id = child.get("item_id")
		var item_id: String = str(raw_id) if raw_id != null else ""
		if item_id.is_empty():
			continue
		var cell: Vector2i = Vector2(
			int(floor(child.position.x / CELL_SIZE)),
			int(floor(child.position.y / CELL_SIZE)),
		)
		if not groups.has(item_id):
			groups[item_id] = []
		groups[item_id].append({"cell": cell, "node": child})
	for item_id in groups:
		var entries: Array = groups[item_id]
		var tex: Texture2D = _load_pickup_texture(item_id)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.instance_count = entries.size()
		var mesh_inst := MultiMeshInstance2D.new()
		mesh_inst.multimesh = mm
		mesh_inst.texture = tex
		mesh_inst.name = "Pickups_%s" % item_id
		add_child(mesh_inst)
		_pickup_meshes[item_id] = mesh_inst
		for i in range(entries.size()):
			var entry: Dictionary = entries[i]
			var cell: Vector2i = entry["cell"]
			var world_pos: Vector2 = Vector2(
				cell.x * CELL_SIZE + CELL_SIZE * 0.5,
				cell.y * CELL_SIZE + CELL_SIZE * 0.5,
			)
			var xf := Transform2D(0, world_pos)
			mm.set_instance_transform_2d(i, xf)
			_pickup_index[cell] = {"item_id": item_id, "index": i}


## Dim or restore a resource node at the given cell.
func dim_node(cell: Vector2i, dimmed: bool) -> void:
	var entry: Dictionary = _node_index.get(cell, {})
	if entry.is_empty():
		return
	var sprite_id: String = str(entry.get("sprite_id", ""))
	var idx: int = int(entry.get("index", -1))
	var mesh_inst: MultiMeshInstance2D = _node_meshes.get(sprite_id, null)
	if mesh_inst == null or mesh_inst.multimesh == null:
		return
	if idx < 0 or idx >= mesh_inst.multimesh.instance_count:
		return
	if dimmed:
		mesh_inst.multimesh.set_instance_color(idx, Color(0.4, 0.4, 0.4, 0.5))
	else:
		mesh_inst.multimesh.set_instance_color(idx, Color.WHITE)


## Hide a floor pickup at the given cell (after collection).
func hide_pickup(cell: Vector2i) -> void:
	var entry: Dictionary = _pickup_index.get(cell, {})
	if entry.is_empty():
		return
	var item_id: String = str(entry.get("item_id", ""))
	var idx: int = int(entry.get("index", -1))
	var mesh_inst: MultiMeshInstance2D = _pickup_meshes.get(item_id, null)
	if mesh_inst == null or mesh_inst.multimesh == null:
		return
	if idx < 0 or idx >= mesh_inst.multimesh.instance_count:
		return
	# Move off-screen to hide.
	var offscreen := Transform2D(0, Vector2(-9999, -9999))
	mesh_inst.multimesh.set_instance_transform_2d(idx, offscreen)
	_pickup_index.erase(cell)


func _node_scale(nd: Dictionary) -> float:
	var sprite_id: String = str(nd.get("sprite", ""))
	if sprite_id.begins_with("tree_"):
		return 1.2
	if sprite_id.begins_with("ore_"):
		return 0.9
	if sprite_id.begins_with("crystal_"):
		return 0.8
	if sprite_id.begins_with("formation_"):
		return 1.0
	return 1.0


func _load_node_texture(sprite_id: String) -> Texture2D:
	var path: String = SPRITE_FOLDER + sprite_id + ".png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return _make_placeholder(sprite_id)


func _load_pickup_texture(item_id: String) -> Texture2D:
	var path: String = PICKUP_FOLDER + item_id + ".png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return _make_placeholder(item_id)


func _make_placeholder(id: String) -> Texture2D:
	var img := Image.create(CELL_SIZE, CELL_SIZE, false, Image.FORMAT_RGBA8)
	var col: Color = _placeholder_color(id)
	img.fill(col)
	# Dark border
	for x in CELL_SIZE:
		img.set_pixel(x, 0, col.darkened(0.4))
		img.set_pixel(x, CELL_SIZE - 1, col.darkened(0.4))
	for y in CELL_SIZE:
		img.set_pixel(0, y, col.darkened(0.4))
		img.set_pixel(CELL_SIZE - 1, y, col.darkened(0.4))
	return ImageTexture.create_from_image(img)


func _placeholder_color(id: String) -> Color:
	if id.begins_with("tree_"):
		return Color(0.25, 0.50, 0.20)
	if id.begins_with("ore_"):
		return Color(0.60, 0.40, 0.25)
	if id.begins_with("crystal_"):
		return Color(0.35, 0.55, 0.80)
	if id.begins_with("formation_"):
		return Color(0.50, 0.45, 0.40)
	if id == "stick":
		return Color(0.55, 0.40, 0.25)
	if id == "stone":
		return Color(0.55, 0.55, 0.50)
	return Color(0.5, 0.5, 0.5)
