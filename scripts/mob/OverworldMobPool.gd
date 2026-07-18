## OverworldMobPool — Reusable MobInstance pool.
## Prevents queue_free/create churn on marker refreshes.
## Borrow/return cycle: borrow() -> use -> return_instance().
class_name OverworldMobPool
extends Node
const MobInstanceRef = preload("res://scripts/mob/MobInstance.gd")

var _pool: Array[MobInstanceRef] = []
var _active: Array[MobInstanceRef] = []


## Get an instance from the pool (or create one if empty).
func borrow() -> MobInstanceRef:
	var inst: MobInstanceRef
	if _pool.is_empty():
		inst = MobInstanceRef.new()
		add_child(inst)
	else:
		inst = _pool.pop_back()
	inst.visible = true
	_active.append(inst)
	return inst


## Return an instance to the pool (hides and resets).
func return_instance(inst: MobInstanceRef) -> void:
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
		var inst := MobInstanceRef.new()
		inst.visible = false
		add_child(inst)
		_pool.append(inst)
