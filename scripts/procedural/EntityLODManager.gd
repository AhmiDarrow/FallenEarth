## EntityLODManager — Distance-based LOD system for procedural 3D entities.
## Manages 3 LOD levels per entity: full detail, simplified, billboard/cull.
## Attach as child of Entity3DViewport to manage all entities automatically.
extends Node

signal lod_changed(entity_id: String, new_lod: int)

enum LOD { FULL = 0, SIMPLIFIED = 1, CULLED = 2 }

@export var lod_distances: Array[float] = [8.0, 16.0, 24.0]
@export var check_interval: float = 0.25
@export var enabled: bool = true

var _entities: Dictionary = {}
var _check_timer: float = 0.0
var _viewport_ref # Entity3DViewport (untyped to avoid circular dependency)

func setup(viewport) -> void:
	_viewport_ref = viewport

func register_entity(entity_id: String, entity_root: Node3D, animator) -> void:
	_entities[entity_id] = {
		"root": entity_root,
		"animator": animator,
		"lod": LOD.FULL,
		"original_scale": entity_root.scale,
		"meshes": _collect_meshes(entity_root),
	}

func unregister_entity(entity_id: String) -> void:
	_entities.erase(entity_id)

func _process(delta: float) -> void:
	if not enabled or not _viewport_ref:
		return
	_check_timer += delta
	if _check_timer >= check_interval:
		_check_timer = 0.0
		_update_all_lods()

func _update_all_lods() -> void:
	var cam = _viewport_ref.camera if _viewport_ref else null
	if not cam:
		return
	var cam_pos: Vector3 = cam.global_position
	for entity_id in _entities:
		var data: Dictionary = _entities[entity_id]
		var root: Node3D = data["root"]
		if not is_instance_valid(root):
			continue
		var dist: float = cam_pos.distance_to(root.global_position)
		var new_lod := _dist_to_lod(dist)
		if new_lod != data["lod"]:
			_apply_lod(entity_id, data, new_lod)

func _dist_to_lod(dist: float) -> int:
	if dist < lod_distances[0]:
		return LOD.FULL
	elif dist < lod_distances[1]:
		return LOD.SIMPLIFIED
	return LOD.CULLED

func _apply_lod(entity_id: String, data: Dictionary, new_lod: int) -> void:
	var old_lod: int = data["lod"]
	data["lod"] = new_lod
	var root: Node3D = data["root"]
	var animator = data["animator"]
	var orig_scale: Vector3 = data["original_scale"]

	match new_lod:
		LOD.FULL:
			root.visible = true
			root.scale = orig_scale
			if animator:
				animator.set_process(true)
			_set_meshes_visible(data["meshes"], true)
		LOD.SIMPLIFIED:
			root.visible = true
			root.scale = orig_scale * 0.8
			if animator:
				animator.set_process(false)
			_set_meshes_visible(data["meshes"], true)
			_hide_attachments(root)
		LOD.CULLED:
			root.visible = false
			if animator:
				animator.set_process(false)

	lod_changed.emit(entity_id, new_lod)

func _collect_meshes(root: Node3D) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for child in root.get_children():
		if child is MeshInstance3D:
			meshes.append(child)
		elif child is Node3D:
			for sub in child.get_children():
				if sub is MeshInstance3D:
					meshes.append(sub)
	return meshes

func _set_meshes_visible(meshes: Array[MeshInstance3D], vis: bool) -> void:
	for mi in meshes:
		if is_instance_valid(mi):
			mi.visible = vis

func _hide_attachments(root: Node3D) -> void:
	for child in root.get_children():
		if child.name in ["Horns", "Wings", "ArmorPlate", "Equip_head", "Equip_torso", "Equip_back"]:
			child.visible = false

func get_entity_lod(entity_id: String) -> int:
	if _entities.has(entity_id):
		return _entities[entity_id]["lod"]
	return LOD.FULL

func get_entity_count() -> int:
	return _entities.size()

func get_visible_count() -> int:
	var count := 0
	for entity_id in _entities:
		var data: Dictionary = _entities[entity_id]
		if data["lod"] != LOD.CULLED:
			count += 1
	return count

func set_lod_distance(index: int, distance: float) -> void:
	if index >= 0 and index < lod_distances.size():
		lod_distances[index] = distance

func force_lod(entity_id: String, lod: int) -> void:
	if _entities.has(entity_id):
		_apply_lod(entity_id, _entities[entity_id], lod)
