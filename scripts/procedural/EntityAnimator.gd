## EntityAnimator — Procedural animation controller for 3D entity hierarchies.
## Drives limb swing, breathing, idle sway, attack strikes, and death collapse
## via _process with sine/cosine oscillators. Attach as child of the entity root.
## Phase 4: Enhanced with rift-specific animations and energy tendrils.
extends Node

enum State { IDLE, WALK, COMBAT, DEAD }

signal state_changed(new_state: State)

@export var current_state: State = State.IDLE
@export var anim_speed: float = 1.0
@export var entity_type: String = "humanoid"
@export var prop_subtype: String = ""

var _time: float = 0.0
var _combat_timer: float = 0.0
var _combat_duration: float = 0.4
var _death_progress: float = 0.0
var _torso_ref: Node3D
var _head_ref: Node3D
var _arm_l_ref: Node3D
var _arm_r_ref: Node3D
var _leg_l_ref: Node3D
var _leg_r_ref: Node3D
var _body_ref: Node3D
var _ring_ref: Node3D
var _core_ref: Node3D
var _tendrils: Array[Node3D] = []
var _energy_particles: Array[MeshInstance3D] = []
var _energy_chains: Array[Node3D] = []
var _orb_ref: Node3D
var _base_ring_ref: Node3D
var _door_panel_ref: Node3D
var _container_lid_ref: Node3D
var _highlight_ref: Node3D

var _initial_arm_l: Transform3D
var _initial_arm_r: Transform3D
var _initial_leg_l: Transform3D
var _initial_leg_r: Transform3D
var _initial_torso: Transform3D
var _initial_head: Transform3D
var _initial_body: Transform3D
var _initial_entity: Transform3D
var _initial_core: Transform3D
var _initial_orb: Transform3D
var _initial_base_ring: Transform3D
var _initial_door_panel: Transform3D
var _initial_container_lid: Transform3D

func _ready() -> void:
	_resolve_references()
	_store_initial_transforms()
	if entity_type == "rift":
		_setup_energy_particles()
		_setup_energy_chains()

func set_state(new_state: State) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	state_changed.emit(new_state)
	if current_state == State.COMBAT:
		_combat_timer = _combat_duration
	elif current_state == State.DEAD:
		_death_progress = 0.0

func set_state_by_name(name: String) -> void:
	match name.to_lower():
		"idle": set_state(State.IDLE)
		"walk": set_state(State.WALK)
		"combat", "attack": set_state(State.COMBAT)
		"dead", "death": set_state(State.DEAD)

func trigger_attack() -> void:
	set_state(State.COMBAT)

func _resolve_references() -> void:
	var parent := get_parent()
	if not parent:
		return
	_torso_ref = parent.get_node_or_null("Torso")
	_head_ref = parent.get_node_or_null("Head")
	_arm_l_ref = parent.get_node_or_null("ArmL")
	_arm_r_ref = parent.get_node_or_null("ArmR")
	_leg_l_ref = parent.get_node_or_null("LegL")
	_leg_r_ref = parent.get_node_or_null("LegR")
	_body_ref = parent.get_node_or_null("Body")
	_ring_ref = parent.get_node_or_null("Ring")
	_core_ref = parent.get_node_or_null("Core")
	_orb_ref = parent.get_node_or_null("Orb")
	_base_ring_ref = parent.get_node_or_null("BaseRing")
	_door_panel_ref = parent.get_node_or_null("DoorPanel")
	_container_lid_ref = parent.get_node_or_null("ContainerLid")
	_highlight_ref = parent.get_node_or_null("Highlight")
	for child in parent.get_children():
		if child.name.begins_with("Tendril"):
			_tendrils.append(child)

func _store_initial_transforms() -> void:
	if _arm_l_ref: _initial_arm_l = _arm_l_ref.transform
	if _arm_r_ref: _initial_arm_r = _arm_r_ref.transform
	if _leg_l_ref: _initial_leg_l = _leg_l_ref.transform
	if _leg_r_ref: _initial_leg_r = _leg_r_ref.transform
	if _torso_ref: _initial_torso = _torso_ref.transform
	if _head_ref: _initial_head = _head_ref.transform
	if _body_ref: _initial_body = _body_ref.transform
	var p := get_parent()
	if p: _initial_entity = p.transform
	if _core_ref: _initial_core = _core_ref.transform
	if _orb_ref: _initial_orb = _orb_ref.transform
	if _base_ring_ref: _initial_base_ring = _base_ring_ref.transform
	if _door_panel_ref: _initial_door_panel = _door_panel_ref.transform
	if _container_lid_ref: _initial_container_lid = _container_lid_ref.transform

func _setup_energy_particles() -> void:
	for i in range(5):
		var particle := MeshInstance3D.new()
		particle.name = "EnergyParticle%d" % i
		var mesh := SphereMesh.new()
		mesh.radius = 0.05
		mesh.height = 0.1
		particle.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.3, 0.9, 0.8)
		mat.emission_enabled = true
		mat.emission = Color(0.7, 0.4, 1.0)
		mat.emission_energy_multiplier = 2.0
		particle.material_override = mat
		particle.visible = false
		add_child(particle)
		_energy_particles.append(particle)

func _setup_energy_chains() -> void:
	for i in range(3):
		var chain_root := Node3D.new()
		chain_root.name = "EnergyChain%d" % i
		chain_root.position = Vector3(cos(float(i) / 3.0 * TAU) * 0.5, 0.0, sin(float(i) / 3.0 * TAU) * 0.5)

		var segment_count := 5
		for j in range(segment_count):
			var cylinder := MeshInstance3D.new()
			cylinder.name = "Segment%d" % j
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.02
			mesh.bottom_radius = 0.03
			mesh.height = 0.15
			cylinder.mesh = mesh

			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.4, 0.2, 0.8, 0.7)
			mat.emission_enabled = true
			mat.emission = Color(0.6, 0.3, 1.0)
			mat.emission_energy_multiplier = 1.5
			cylinder.material_override = mat
			cylinder.position.y = -float(j) * 0.15

			chain_root.add_child(cylinder)

			if j == segment_count - 1:
				var sphere := MeshInstance3D.new()
				sphere.name = "Tip"
				var tip_mesh := SphereMesh.new()
				tip_mesh.radius = 0.04
				tip_mesh.height = 0.08
				sphere.mesh = tip_mesh
				sphere.position.y = -float(segment_count) * 0.15

				var tip_mat := StandardMaterial3D.new()
				tip_mat.albedo_color = Color(0.6, 0.4, 1.0, 0.9)
				tip_mat.emission_enabled = true
				tip_mat.emission = Color(0.8, 0.5, 1.0)
				tip_mat.emission_energy_multiplier = 3.0
				sphere.material_override = tip_mat
				chain_root.add_child(sphere)

		add_child(chain_root)
		_energy_chains.append(chain_root)

func _process(delta: float) -> void:
	_time += delta * anim_speed
	match entity_type:
		"item":
			_process_item(delta)
			return
		"prop":
			_process_prop(delta)
			return
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.WALK:
			_process_walk(delta)
		State.COMBAT:
			_process_combat(delta)
		State.DEAD:
			_process_dead(delta)

func _process_idle(_delta: float) -> void:
	var t := _time
	var breathe := sin(t * 2.0) * 0.008
	var sway := sin(t * 0.8) * 0.02

	if _torso_ref:
		_torso_ref.transform = _initial_torso
		_torso_ref.scale = Vector3.ONE + Vector3(breathe, breathe, breathe) * 0.5

	if _head_ref:
		_head_ref.transform = _initial_head
		_head_ref.rotation.y = sin(t * 0.6) * 0.05

	if _arm_l_ref:
		_arm_l_ref.transform = _initial_arm_l

	if _arm_r_ref:
		_arm_r_ref.transform = _initial_arm_r

	if _body_ref:
		_body_ref.transform = _initial_body
		_body_ref.scale = Vector3.ONE + Vector3(breathe, breathe, breathe)

	if _ring_ref:
		_ring_ref.rotation.y = t * 0.3

	if _core_ref:
		var pulse := 1.0 + sin(t * 2.5) * 0.08
		_core_ref.scale = Vector3(pulse, pulse, pulse)

	for i in _tendrils.size():
		var tendril := _tendrils[i]
		var angle := sin(t * 1.5 + float(i) * 1.2) * 0.15
		tendril.rotation.x = angle

func _process_walk(_delta: float) -> void:
	var t := _time
	var step_cycle := sin(t * 6.0)
	var arm_cycle := sin(t * 6.0 + PI)
	var bob: float = abs(sin(t * 6.0)) * 0.04

	if _torso_ref:
		_torso_ref.transform = _initial_torso
		_torso_ref.position.y += bob

	if _head_ref:
		_head_ref.transform = _initial_head
		_head_ref.position.y += bob * 0.5

	if _arm_l_ref:
		_arm_l_ref.transform = _initial_arm_l
		_arm_l_ref.rotation.z = arm_cycle * 0.3

	if _arm_r_ref:
		_arm_r_ref.transform = _initial_arm_r
		_arm_r_ref.rotation.z = step_cycle * 0.3

	if _leg_l_ref:
		_leg_l_ref.transform = _initial_leg_l
		_leg_l_ref.rotation.z = step_cycle * 0.25

	if _leg_r_ref:
		_leg_r_ref.transform = _initial_leg_r
		_leg_r_ref.rotation.z = arm_cycle * 0.25

	if _body_ref:
		_body_ref.transform = _initial_body
		_body_ref.position.y += bob

func _process_combat(_delta: float) -> void:
	_combat_timer -= _delta
	var progress: float = 1.0 - (_combat_timer / _combat_duration)
	progress = clampf(progress, 0.0, 1.0)

	var strike := sin(progress * PI)
	var recover := 1.0 - strike

	if _arm_r_ref:
		_arm_r_ref.transform = _initial_arm_r
		_arm_r_ref.rotation.x = -strike * 0.8
		_arm_r_ref.position.x += strike * 0.1

	if _torso_ref:
		_torso_ref.transform = _initial_torso
		_torso_ref.rotation.z = strike * 0.05

	if _combat_timer <= 0.0 and current_state == State.COMBAT:
		set_state(State.IDLE)

func _process_dead(_delta: float) -> void:
	var p := get_parent()
	if not p:
		return
	_death_progress += _delta * 0.5
	_death_progress = minf(_death_progress, 1.0)
	var eased := 1.0 - pow(1.0 - _death_progress, 3.0)

	p.rotation.x = eased * deg_to_rad(90.0)
	p.position.y = -eased * 0.5

	if _torso_ref:
		_torso_ref.transform = _initial_torso

	if _head_ref:
		_head_ref.transform = _initial_head

	var fade_target := 1.0 - eased * 0.7
	for child in p.get_children():
		if child is MeshInstance3D:
			var mat = child.material_override
			if not mat:
				mat = child.get_surface_override_material(0)
			if mat:
				var c: Color
				if mat is StandardMaterial3D:
					c = mat.albedo_color
					c.a = fade_target
					mat.albedo_color = c
				elif mat is ShaderMaterial:
					if mat.has_method("set_shader_parameter"):
						mat.set_shader_parameter("flash_amount", eased * 0.5)

func get_animation_progress() -> float:
	match current_state:
		State.COMBAT:
			return 1.0 - (_combat_timer / _combat_duration)
		State.DEAD:
			return _death_progress
		_:
			return 0.0

func is_playing() -> bool:
	return current_state != State.IDLE

func set_entity_type(new_type: String) -> void:
	entity_type = new_type
	if entity_type == "rift" and _energy_particles.is_empty():
		_setup_energy_particles()
		_setup_energy_chains()

func get_entity_type() -> String:
	return entity_type

func _process_item(_delta: float) -> void:
	var t := _time
	var float_bob := sin(t * 1.5) * 0.08
	var slow_rot := t * 0.5

	var p := get_parent()
	if p:
		p.position.y = float_bob

	if _orb_ref:
		_orb_ref.transform = _initial_orb
		var pulse := 1.0 + sin(t * 2.0) * 0.05
		_orb_ref.scale = Vector3(pulse, pulse, pulse)

	if _base_ring_ref:
		_base_ring_ref.transform = _initial_base_ring
		_base_ring_ref.rotation.y = slow_rot

	for child in get_parent().get_children() if get_parent() else []:
		if child is MeshInstance3D and child != _orb_ref and child != _base_ring_ref:
			child.rotation.y = slow_rot * 0.3

func _process_prop(_delta: float) -> void:
	var t := _time
	match prop_subtype:
		"door":
			_animate_door(t)
		"container":
			_animate_container(t)
		"vehicle":
			_animate_vehicle(t)
		"structure":
			_animate_structure(t)
		_:
			_animate_prop_idle(t)

func _animate_door(t: float) -> void:
	if not _door_panel_ref:
		return
	_door_panel_ref.transform = _initial_door_panel
	var glow_pulse := 0.5 + sin(t * 1.2) * 0.3
	if _highlight_ref and _highlight_ref is MeshInstance3D:
		var mat = _highlight_ref.get_surface_override_material(0)
		if mat is StandardMaterial3D:
			mat.emission_energy_multiplier = glow_pulse * 2.0

func _animate_container(t: float) -> void:
	if _container_lid_ref:
		_container_lid_ref.transform = _initial_container_lid
		var wobble := sin(t * 0.8) * 0.02
		_container_lid_ref.rotation.x = wobble
	if _highlight_ref and _highlight_ref is MeshInstance3D:
		var mat = _highlight_ref.get_surface_override_material(0)
		if mat is StandardMaterial3D:
			var pulse := 0.6 + sin(t * 1.5) * 0.4
			mat.emission_energy_multiplier = pulse * 2.0

func _animate_vehicle(t: float) -> void:
	var bob := sin(t * 1.0) * 0.015
	var p := get_parent()
	if p:
		p.position.y = bob
	for child in p.get_children() if p else []:
		if child.name.begins_with("Wheel"):
			child.rotation.x = t * 2.0

func _animate_structure(t: float) -> void:
	if _highlight_ref and _highlight_ref is MeshInstance3D:
		var mat = _highlight_ref.get_surface_override_material(0)
		if mat is StandardMaterial3D:
			var pulse := 0.4 + sin(t * 0.8) * 0.3
			mat.emission_energy_multiplier = pulse * 1.5

func _animate_prop_idle(t: float) -> void:
	var sway := sin(t * 0.5) * 0.01
	var p := get_parent()
	if p:
		p.rotation.y = sway
