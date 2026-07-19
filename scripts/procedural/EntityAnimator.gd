## EntityAnimator — Procedural animation states for a composed 3D entity.
##
## Drives a root Node3D (from ProceduralEntityGenerator) with cheap, non-skeletal
## procedural motion. States: IDLE, WALK, COMBAT, DEAD.
##   - IDLE: gentle breathing scale + sway.
##   - WALK: vertical bob + subtle rotation oscillation.
##   - COMBAT: tense idle + faster sway.
##   - DEAD: fall over (rotate + drop) then settle.
## Also supports flash_damage() (brief white flash via shader overlay strength).
##
## Designed to be added as a child of the same parent as the 3D root, or bound
## via bind(root). Operates in _process using a local time accumulator so it
## works inside a SubViewport regardless of tree pause state.
class_name EntityAnimator
extends Node

enum State { IDLE, WALK, COMBAT, DEAD }

var _root: Node3D = null
var _state: int = State.IDLE
var _t: float = 0.0
var _flash: float = 0.0
var _flash_color: Color = Color(1.0, 0.2, 0.2)
var _dead_progress: float = 0.0
var _base_y: float = 0.0
var _base_scale: Vector3 = Vector3.ONE
## Per-mesh flash overlay materials, built once per bound root and reused
## across flashes (uniform updates only — no per-frame material creation).
var _flash_mats: Dictionary = {}


func bind(root: Node3D) -> void:
	_root = root
	_flash_mats.clear()
	if _root != null:
		_base_y = _root.position.y
		_base_scale = _root.scale


func set_state(s: int) -> void:
	if s == _state:
		return
	_state = s
	if s == State.DEAD:
		_dead_progress = 0.0


func flash_damage(color: Color = Color(1.0, 0.2, 0.2)) -> void:
	_flash = 1.0
	_flash_color = color
	_prepare_flash_materials()
	_apply_flash()


func _process(delta: float) -> void:
	if _root == null:
		return
	_t += delta

	match _state:
		State.IDLE: _anim_idle(delta)
		State.WALK: _anim_walk(delta)
		State.COMBAT: _anim_combat(delta)
		State.DEAD: _anim_dead(delta)

	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 3.0)
		_apply_flash()


func _anim_idle(_delta: float) -> void:
	var breath := sin(_t * 2.0) * 0.02
	_root.scale = _base_scale * (1.0 + breath)
	_root.rotation.z = sin(_t * 0.8) * 0.01
	_root.position.y = _base_y + sin(_t * 1.5) * 0.01


func _anim_walk(_delta: float) -> void:
	var bob: float = abs(sin(_t * 8.0)) * 0.05
	_root.position.y = _base_y + bob
	_root.rotation.z = sin(_t * 8.0) * 0.04
	_root.scale = _base_scale


func _anim_combat(_delta: float) -> void:
	var sway := sin(_t * 4.0) * 0.03
	_root.rotation.z = sway
	_root.position.y = _base_y + sin(_t * 3.0) * 0.015
	var tense := 1.0 + sin(_t * 6.0) * 0.01
	_root.scale = _base_scale * tense


func _anim_dead(_delta: float) -> void:
	_dead_progress = minf(1.0, _dead_progress + _delta * 2.0)
	var k := _dead_progress
	_root.rotation.x = lerp(0.0, PI * 0.5, k)
	_root.position.y = lerp(_base_y, _base_y * 0.3, k)


func _prepare_flash_materials() -> void:
	if _root == null or not _flash_mats.is_empty():
		return
	for mi in _iter_meshes(_root):
		var base: Material = mi.material_override
		if base is StandardMaterial3D:
			var sm: ShaderMaterial = MaterialLibrary.make_shader_variant(
				base, MaterialLibrary.ShaderVariant.DAMAGE_FLASH, {"flash_color": _flash_color}
			)
			# Unique instance per mesh so per-entity strength animation
			# doesn't mutate the globally cached variant.
			_flash_mats[mi] = sm.duplicate()


func _apply_flash() -> void:
	var clearing: bool = _flash <= 0.001
	for mi in _flash_mats:
		if not is_instance_valid(mi):
			continue
		if clearing:
			mi.material_overlay = null
			continue
		var sm: ShaderMaterial = _flash_mats[mi]
		sm.set_shader_parameter("flash_strength", _flash)
		sm.set_shader_parameter("flash_color", _flash_color)
		if mi.material_overlay != sm:
			mi.material_overlay = sm


static func _iter_meshes(root: Node) -> Array:
	var out: Array = []
	for c in root.get_children():
		if c is MeshInstance3D:
			out.append(c)
		out.append_array(_iter_meshes(c))
	return out


# Local reference to MaterialLibrary to avoid cluttering the header import.
const MaterialLibrary := preload("res://scripts/procedural/MaterialLibrary.gd")
