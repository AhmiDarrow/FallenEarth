## PrimitiveMeshLibrary — Factory for runtime procedural 3D meshes.
## Uses Godot's built-in PrimitiveMesh types to compose entity visuals
## without external model assets. All methods return MeshInstance3D ready
## for adding to a scene tree.
class_name PrimitiveMeshLibrary
extends RefCounted

static var _mesh_cache: Dictionary = {}

static func _cache_key(mesh_type: String, params: Dictionary) -> String:
	return mesh_type + "_" + var_to_str(params).md5_text()

static func _cached_or_create(key: String, factory: Callable) -> Mesh:
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var mesh: Mesh = factory.call()
	_mesh_cache[key] = mesh
	return mesh

static func body_capsule(height: float = 1.8, radius: float = 0.45) -> MeshInstance3D:
	var key := _cache_key("capsule", {"h": height, "r": radius})
	var mesh: Mesh = _cached_or_create(key, func():
		var m := CapsuleMesh.new()
		m.height = height
		m.radius = radius
		m.material = _default_material()
		return m
	)
	return MeshInstance3D.new()

static func body_box(size: Vector3 = Vector3(0.6, 1.8, 0.4)) -> MeshInstance3D:
	var key := _cache_key("box", {"s": [size.x, size.y, size.z]})
	var mesh: Mesh = _cached_or_create(key, func():
		var m := BoxMesh.new()
		m.size = size
		m.material = _default_material()
		return m
	)
	return MeshInstance3D.new()

static func body_sphere(radius: float = 0.35) -> MeshInstance3D:
	var key := _cache_key("sphere", {"r": radius})
	var mesh: Mesh = _cached_or_create(key, func():
		var m := SphereMesh.new()
		m.radius = radius
		m.height = radius * 2.0
		m.material = _default_material()
		return m
	)
	return MeshInstance3D.new()

static func body_cylinder(height: float = 1.0, radius: float = 0.3) -> MeshInstance3D:
	var key := _cache_key("cylinder", {"h": height, "r": radius})
	var mesh: Mesh = _cached_or_create(key, func():
		var m := CylinderMesh.new()
		m.top_radius = radius
		m.bottom_radius = radius
		m.height = height
		m.material = _default_material()
		return m
	)
	return MeshInstance3D.new()

static func body_cone(height: float = 0.8, radius: float = 0.4) -> MeshInstance3D:
	var key := _cache_key("cone", {"h": height, "r": radius})
	var mesh: Mesh = _cached_or_create(key, func():
		var m := ConeMesh.new()
		m.top_radius = 0.0
		m.bottom_radius = radius
		m.height = height
		m.material = _default_material()
		return m
	)
	return MeshInstance3D.new()

static func body_torus(inner_radius: float = 0.2, outer_radius: float = 0.5) -> MeshInstance3D:
	var key := _cache_key("torus", {"ir": inner_radius, "or": outer_radius})
	var mesh: Mesh = _cached_or_create(key, func():
		var m := TorusMesh.new()
		m.inner_radius = inner_radius
		m.outer_radius = outer_radius
		m.material = _default_material()
		return m
	)
	return MeshInstance3D.new()

static func body_prism(size: Vector3 = Vector3(0.5, 0.8, 0.5)) -> MeshInstance3D:
	var key := _cache_key("prism", {"s": [size.x, size.y, size.z]})
	var mesh: Mesh = _cached_or_create(key, func():
		var m := BoxMesh.new()
		m.size = size
		m.material = _default_material()
		return m
	)
	return MeshInstance3D.new()

static func attachment_horn(length: float = 0.4, base_radius: float = 0.08) -> MeshInstance3D:
	var mi := body_cone(length, base_radius)
	mi.name = "Horn"
	return mi

static func attachment_wing(span: float = 0.8) -> MeshInstance3D:
	var mi := body_box(Vector3(span, 0.05, 0.3))
	mi.name = "Wing"
	return mi

static func attachment_tail(length: float = 0.6, thickness: float = 0.1) -> MeshInstance3D:
	var mi := body_cylinder(length, thickness)
	mi.name = "Tail"
	return mi

static func attachment_armor_plate(width: float = 0.3, height: float = 0.4) -> MeshInstance3D:
	var mi := body_box(Vector3(width, height, 0.1))
	mi.name = "ArmorPlate"
	return mi

static func attachment_weapon(length: float = 0.6, width: float = 0.06) -> MeshInstance3D:
	var mi := body_box(Vector3(width, length, width))
	mi.name = "Weapon"
	return mi

static func attachment_shield(radius: float = 0.3) -> MeshInstance3D:
	var mi := body_cylinder(0.1, radius)
	mi.name = "Shield"
	return mi

static func compose_humanoid(torso_height: float = 1.0, head_radius: float = 0.2,
		leg_height: float = 0.6, arm_height: float = 0.5) -> Node3D:
	var root := Node3D.new()
	root.name = "Humanoid"

	var torso := body_capsule(torso_height, 0.35)
	torso.name = "Torso"
	root.add_child(torso)

	var head := body_sphere(head_radius)
	head.name = "Head"
	head.position.y = torso_height * 0.5 + head_radius * 0.5
	root.add_child(head)

	var leg_l := body_cylinder(leg_height, 0.12)
	leg_l.name = "LegL"
	leg_l.position = Vector3(-0.15, -torso_height * 0.5 - leg_height * 0.5, 0.0)
	root.add_child(leg_l)

	var leg_r := body_cylinder(leg_height, 0.12)
	leg_r.name = "LegR"
	leg_r.position = Vector3(0.15, -torso_height * 0.5 - leg_height * 0.5, 0.0)
	root.add_child(leg_r)

	var arm_l := body_cylinder(arm_height, 0.08)
	arm_l.name = "ArmL"
	arm_l.position = Vector3(-0.45, torso_height * 0.2 - arm_height * 0.5, 0.0)
	root.add_child(arm_l)

	var arm_r := body_cylinder(arm_height, 0.08)
	arm_r.name = "ArmR"
	arm_r.position = Vector3(0.45, torso_height * 0.2 - arm_height * 0.5, 0.0)
	root.add_child(arm_r)

	return root

static func compose_beast(body_length: float = 1.2, body_height: float = 0.6,
		head_radius: float = 0.18, leg_height: float = 0.4) -> Node3D:
	var root := Node3D.new()
	root.name = "Beast"

	var body := body_capsule(body_length, body_height * 0.5)
	body.name = "Body"
	body.rotation.x = deg_to_rad(90.0)
	root.add_child(body)

	var head := body_sphere(head_radius)
	head.name = "Head"
	head.position = Vector3(0.0, body_height * 0.3, body_length * 0.5 + head_radius)
	root.add_child(head)

	for i in 4:
		var leg := body_cylinder(leg_height, 0.08)
		leg.name = "Leg%d" % i
		var side := -1.0 if i % 2 == 0 else 1.0
		var fore_aft := -1.0 if i < 2 else 1.0
		leg.position = Vector3(side * 0.2, -body_height * 0.5 - leg_height * 0.5, fore_aft * body_length * 0.35)
		root.add_child(leg)

	return root

static func compose_rift(radius: float = 1.5) -> Node3D:
	var root := Node3D.new()
	root.name = "RiftEntity"

	var ring := body_torus(radius * 0.7, radius)
	ring.name = "Ring"
	ring.rotation.x = deg_to_rad(90.0)
	root.add_child(ring)

	var glow := body_sphere(radius * 0.5)
	glow.name = "Core"
	root.add_child(glow)

	for i in 3:
		var tendril := body_cylinder(radius * 0.8, 0.04)
		tendril.name = "Tendril%d" % i
		var angle := float(i) / 3.0 * TAU
		tendril.position = Vector3(cos(angle) * radius * 0.4, 0.0, sin(angle) * radius * 0.4)
		tendril.rotation.z = angle
		root.add_child(tendril)

	return root

static func compose_item_orb(radius: float = 0.2) -> Node3D:
	var root := Node3D.new()
	root.name = "Item"

	var orb := body_sphere(radius)
	orb.name = "Orb"
	root.add_child(orb)

	var base_ring := body_torus(radius * 0.5, radius * 0.8)
	base_ring.name = "BaseRing"
	base_ring.rotation.x = deg_to_rad(90.0)
	base_ring.position.y = -radius * 1.2
	root.add_child(base_ring)

	return root

static func _default_material() -> Material:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	return mat
