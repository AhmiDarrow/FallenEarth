## EntityPool — Object pool for recycling procedural entity Node3D hierarchies.
## Avoids constant create/free cycles by keeping unused entities in a pool.
## Attach as child of Entity3DViewport or use as standalone utility.
extends Node

@export var max_pool_size: int = 100
@export var prewarm_count: int = 10

var _pool: Dictionary = {}
var _active: Dictionary = {}

func _ready() -> void:
	_prewarm()

func _prewarm() -> void:
	for i in prewarm_count:
		var root := Node3D.new()
		root.name = "PooledEntity_%d" % i
		root.visible = false
		add_child(root)
		var key := "generic"
		if not _pool.has(key):
			_pool[key] = []
		_pool[key].append(root)

func acquire(entity_type: String = "generic", visual_data: Dictionary = {}) -> Node3D:
	var key := entity_type
	if _pool.has(key) and _pool[key].size() > 0:
		var entity: Node3D = _pool[key].pop_back()
		entity.visible = true
		entity.name = "Entity_%s_%d" % [entity_type, randi()]
		_active[entity.name] = entity
		return entity

	var entity_root: Node3D
	if not visual_data.is_empty():
		var gen_script = preload("res://scripts/procedural/ProceduralEntityGenerator.gd")
		entity_root = gen_script.create_visual(visual_data)
	else:
		entity_root = Node3D.new()
		entity_root.name = "Entity_%s_%d" % [entity_type, randi()]

	add_child(entity_root)
	_active[entity_root.name] = entity_root
	return entity_root

func release(entity: Node3D) -> void:
	if not entity:
		return
	var entity_name: String = entity.name
	_active.erase(entity_name)
	entity.visible = false
	entity.position = Vector3.ZERO
	entity.rotation = Vector3.ZERO
	entity.scale = Vector3.ONE

	for child in entity.get_children():
		if child.get_script() and child.get_script().get_global_name() == "EntityAnimator":
			child.queue_free()
		elif child.name.begins_with("Equip_"):
			child.queue_free()
		elif child.name == "Highlight":
			child.queue_free()

	var key := "generic"
	if not _pool.has(key):
		_pool[key] = []
	if _pool[key].size() < max_pool_size:
		_pool[key].append(entity)
	else:
		entity.queue_free()

func release_all() -> void:
	var to_release: Array[Node3D] = []
	for entity_name in _active:
		to_release.append(_active[entity_name])
	for entity in to_release:
		release(entity)

func get_active_count() -> int:
	return _active.size()

func get_pool_count() -> int:
	var total := 0
	for key in _pool:
		total += _pool[key].size()
	return total

func get_total_count() -> int:
	return get_active_count() + get_pool_count()

func clear() -> void:
	for key in _pool:
		for entity in _pool[key]:
			if is_instance_valid(entity):
				entity.queue_free()
	_pool.clear()
	_active.clear()
