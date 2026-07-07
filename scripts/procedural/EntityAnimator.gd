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


func bind(root: Node3D) -> void:
	_root = root
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


func _apply_flash() -> void:
	if _root == null:
		return
	for mi in _iter_meshes(_root):
		var base: Material = mi.material_override
		if base is StandardMaterial3D:
			mi.material_overlay = MaterialLibrary_flash(base, _flash_color, _flash)


static func _iter_meshes(root: Node) -> Array:
	var out: Array = []
	for c in root.get_children():
		if c is MeshInstance3D:
			out.append(c)
		out.append_array(_iter_meshes(c))
	return out


# Local reference to MaterialLibrary to avoid cluttering the header import.
const MaterialLibrary := preload("res://scripts/procedural/MaterialLibrary.gd")

static func MaterialLibrary_flash(base: StandardMaterial3D, color: Color, strength: float):
	if strength <= 0.001:
		return null
	return MaterialLibrary.make_shader_variant(base, MaterialLibrary.ShaderVariant.DAMAGE_FLASH, {"flash_color": color})
