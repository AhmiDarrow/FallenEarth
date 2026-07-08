## OverworldMobPool — Reusable MobInstance pool.
## Prevents queue_free/create churn on marker refreshes.
## Borrow/return cycle: borrow() -> use -> return_instance().
class_name OverworldMobPool
extends Node

var _pool: Array[MobInstance] = []
var _active: Array[MobInstance] = []


## Get an instance from the pool (or create one if empty).
func borrow() -> MobInstance:
	var inst: MobInstance
	if _pool.is_empty():
		inst = MobInstance.new()
		add_child(inst)
	else:
		inst = _pool.pop_back()
	inst.visible = true
	_active.append(inst)
	return inst


## Return an instance to the pool (hides and resets).
func return_instance(inst: MobInstance) -> void:
	if inst == null or not is_instance_valid(inst):
		return
	inst.visible = false
	inst.reset()
	_active.erase(inst)
	_pool.append(inst)


## Return ALL active instances to the pool at once.
func return_all() -> void:
	for inst in _active:
		if is_instance_valid(inst):
			inst.visible = false
			inst.reset()
			_pool.append(inst)
	_active.clear()


## Pre-warm the pool with `count` instances.
func warm(count: int) -> void:
	while _pool.size() < count:
		var inst := MobInstance.new()
		inst.visible = false
		add_child(inst)
		_pool.append(inst)
