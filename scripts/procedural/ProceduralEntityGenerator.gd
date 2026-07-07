## ProceduralEntityGenerator — Composes runtime 3D entities from data.
##
## Entry point: create_visual(data: Dictionary) -> Node3D
##   data is the visual descriptor from appearance.json presets (or a mob/
##   npc/archetype visual block). Builds a hierarchy:
##     Root Node3D
##       -> Torso mesh
##          -> Head mesh (+ attachments: horns, etc.)
##       -> Limb meshes (arms/legs)
##       -> Attachment meshes (wings, tail, armor, weapon)
##
## Deterministic: pass a variation_seed (or reuses data["variation_seed"]) so
## the same entity looks identical across sessions/saves.
##
## Output is a pure Node3D subtree (MeshInstance3D + optional CollisionShape3D)
## intended to live inside a SubViewport 3D world; EntityVisualComponent wires
## it to a 2D body via a ViewportTexture.
class_name ProceduralEntityGenerator
extends RefCounted

const PrimitiveMeshLibrary := preload("res://scripts/procedural/PrimitiveMeshLibrary.gd")
const MaterialLibrary := preload("res://scripts/procedural/MaterialLibrary.gd")

static var _seed_rng: RandomNumberGenerator = null


## Main factory. Returns a Node3D (root) with all parts parented.
static func create_visual(data: Dictionary) -> Node3D:
	var root := Node3D.new()
	var base_type: String = str(data.get("base_type", "humanoid")).to_lower()

	# Deterministic per-entity variation.
	var seed_val: int = int(data.get("variation_seed", 0))
	if seed_val == 0:
		seed_val = data.hash()
	_seed_rng = RandomNumberGenerator.new()
	_seed_rng.seed = seed_val

	# Global scale range.
	var scale_range: Array = data.get("scale_range", [0.9, 1.1])
	var s := _randf_range(scale_range[0], scale_range[1])
	root.scale = Vector3(s, s, s)

	match base_type:
		"humanoid": _build_humanoid(root, data)
		"beast": _build_beast(root, data)
		"mechanical": _build_mechanical(root, data)
		"rift": _build_rift(root, data)
		"item": _build_item(root, data)
		"prop": _build_prop(root, data)
		"resource": _build_resource(root, data)
		_: _build_humanoid(root, data)

	root.set_meta("base_type", base_type)
	root.set_meta("visual_data", data)
	return root


## ---- Humanoid / mechanical biped ----------------------------------------

static func _build_humanoid(root: Node3D, data: Dictionary) -> void:
	var mat_data: Dictionary = data.get("material", {"type": "organic", "roughness": 0.8})
	var torso_d: Dictionary = data.get("torso", {})
	var head_d: Dictionary = data.get("head", {})
	var limbs_d: Dictionary = data.get("limbs", {"count": 4, "leg_height": 0.6, "arm_height": 0.5})

	var height: float = float(torso_d.get("height", 1.0))
	var radius: float = float(torso_d.get("radius", 0.35))
	# Torso slightly tapered capsule.
	var torso_mesh := PrimitiveMeshLibrary.get_capsule(radius, height, 8)
	var torso := _mesh_instance(torso_mesh, MaterialLibrary.make_material(mat_data))
	torso.position = Vector3(0, height * 0.5 + float(limbs_d.get("leg_height", 0.6)), 0)
	root.add_child(torso)

	# Head.
	var head_scale: float = float(head_d.get("scale", 0.22)) / 0.22
	var head := _mesh_instance(PrimitiveMeshLibrary.get_sphere(radius * 1.1, 10, 10), MaterialLibrary.make_material(mat_data))
	head.scale = Vector3(head_scale, head_scale, head_scale)
	head.position = Vector3(0, torso.position.y + height * 0.5 + radius * 0.6 * head_scale, 0)
	torso.add_child(head)

	# Head attachments (horns, etc).
	for att in head_d.get("attachments", []):
		_attach_to_head(head, att, mat_data)

	# Limbs: count 4 -> 2 arms + 2 legs.
	var limb_count: int = int(limbs_d.get("count", 4))
	var leg_h: float = float(limbs_d.get("leg_height", 0.6))
	var arm_h: float = float(limbs_d.get("arm_height", 0.5))
	var leg_mesh := PrimitiveMeshLibrary.get_limb_segment(radius * 0.5, radius * 0.6, leg_h, 6)
	var arm_mesh := PrimitiveMeshLibrary.get_limb_segment(radius * 0.35, radius * 0.45, arm_h, 6)
	var leg_mat := MaterialLibrary.make_material(mat_data)
	var arm_mat := MaterialLibrary.make_material(mat_data)

	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var leg := _mesh_instance(leg_mesh, leg_mat)
		leg.position = Vector3(side * radius * 0.5, leg_h * 0.5, 0)
		root.add_child(leg)
		var arm := _mesh_instance(arm_mesh, arm_mat)
		arm.position = Vector3(side * (radius + radius * 0.4), torso.position.y + height * 0.3, 0)
		arm.rotation.z = side * 0.15
		root.add_child(arm)

	# Body attachments (wings, tail, armor, weapon).
	for att in data.get("attachments", []):
		_attach_generic(root, torso, att, mat_data)


## ---- Beast (quadruped / floater) ----------------------------------------

static func _build_beast(root: Node3D, data: Dictionary) -> void:
	var mat_data: Dictionary = data.get("material", {"type": "organic", "roughness": 0.85})
	var torso_d: Dictionary = data.get("torso", {})
	var length: float = float(torso_d.get("length", 1.2))
	var body_h: float = float(torso_d.get("height", 0.6))
	var head_d: Dictionary = data.get("head", {})

	var torso := _mesh_instance(PrimitiveMeshLibrary.get_capsule(body_h * 0.5, length * 0.6, 8), MaterialLibrary.make_material(mat_data))
	torso.rotation.z = PI * 0.5
	torso.position = Vector3(0, body_h * 0.9, 0)
	root.add_child(torso)

	var head_scale: float = float(head_d.get("scale", 0.18)) / 0.18
	var head := _mesh_instance(PrimitiveMeshLibrary.get_sphere(body_h * 0.5, 8, 8), MaterialLibrary.make_material(mat_data))
	head.scale = Vector3(head_scale, head_scale, head_scale)
	head.position = Vector3(length * 0.5, body_h * 0.9 + body_h * 0.3 * head_scale, 0)
	root.add_child(head)

	# Legs (4).
	var leg_mesh := PrimitiveMeshLibrary.get_limb_segment(body_h * 0.2, body_h * 0.25, body_h * 0.8, 6)
	var leg_mat := MaterialLibrary.make_material(mat_data)
	for ix in range(2):
		for iz in range(2):
			var side := -1.0 if ix == 0 else 1.0
			var fwd := -1.0 if iz == 0 else 1.0
			var leg := _mesh_instance(leg_mesh, leg_mat)
			leg.position = Vector3(side * body_h * 0.45, body_h * 0.4, fwd * length * 0.35)
			root.add_child(leg)

	for att in data.get("attachments", []):
		_attach_generic(root, torso, att, mat_data)


## ---- Mechanical (blocky humanoid) ---------------------------------------

static func _build_mechanical(root: Node3D, data: Dictionary) -> void:
	# Reuse humanoid layout but with boxy parts.
	var mat_data: Dictionary = data.get("material", {"type": "metallic", "roughness": 0.3})
	var torso_d: Dictionary = data.get("torso", {})
	var radius: float = float(torso_d.get("radius", 0.35))
	var height: float = float(torso_d.get("height", 1.0))
	var limbs_d: Dictionary = data.get("limbs", {"count": 4, "leg_height": 0.6, "arm_height": 0.5})

	var torso_mesh := PrimitiveMeshLibrary.get_box(radius * 1.6, height, radius * 0.9)
	var torso := _mesh_instance(torso_mesh, MaterialLibrary.make_material(mat_data))
	torso.position = Vector3(0, height * 0.5 + float(limbs_d.get("leg_height", 0.6)), 0)
	root.add_child(torso)

	var head := _mesh_instance(PrimitiveMeshLibrary.get_box(radius * 1.1, radius * 1.1, radius * 1.1), MaterialLibrary.make_material(mat_data))
	head.position = Vector3(0, torso.position.y + height * 0.5 + radius * 0.6, 0)
	torso.add_child(head)

	var leg_mesh := PrimitiveMeshLibrary.get_box(radius * 0.5, float(limbs_d.get("leg_height", 0.6)), radius * 0.5)
	var arm_mesh := PrimitiveMeshLibrary.get_box(radius * 0.4, float(limbs_d.get("arm_height", 0.5)), radius * 0.4)
	var leg_mat := MaterialLibrary.make_material(mat_data)
	var arm_mat := MaterialLibrary.make_material(mat_data)
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var leg := _mesh_instance(leg_mesh, leg_mat)
		leg.position = Vector3(side * radius * 0.5, float(limbs_d.get("leg_height", 0.6)) * 0.5, 0)
		root.add_child(leg)
		var arm := _mesh_instance(arm_mesh, arm_mat)
		arm.position = Vector3(side * (radius + radius * 0.4), torso.position.y + height * 0.3, 0)
		root.add_child(arm)

	for att in data.get("attachments", []):
		_attach_generic(root, torso, att, mat_data)


## ---- Rift entity (procedural large geometry + glow) ---------------------

static func _build_rift(root: Node3D, data: Dictionary) -> void:
	var radius: float = float(data.get("radius", 1.5))
	var rift_type: int = int(data.get("rift_type", 0))
	var mat_data: Dictionary = data.get("material", {"type": "glow", "roughness": 0.1})
	# Core torus + pulsing orb; rift_type tints color.
	var colors := [Color(0.5, 0.2, 0.8), Color(0.2, 0.8, 0.4), Color(0.9, 0.7, 0.2)]
	var col: Color = colors[rift_type % colors.size()]
	var ring_mat := MaterialLibrary.make_material({"type": "glow", "glow": 0.8, "color": [col.r, col.g, col.b]})
	var ring := _mesh_instance(PrimitiveMeshLibrary.get_torus(radius * 0.4, radius, 8, 16), ring_mat)
	ring.rotation.x = PI * 0.5
	root.add_child(ring)
	var orb := _mesh_instance(PrimitiveMeshLibrary.get_sphere(radius * 0.55, 16, 16), ring_mat)
	root.add_child(orb)
	root.set_meta("rift_orbs", [ring, orb])
	root.set_meta("rift_type", rift_type)


## ---- Item (floating orb + optional base/weapon) -------------------------

static func _build_item(root: Node3D, data: Dictionary) -> void:
	var radius: float = float(data.get("radius", 0.2))
	var style: String = str(data.get("style", "")).to_lower()
	var mat_data: Dictionary = data.get("material", {"type": "glow", "roughness": 0.3})
	var color: Color = MaterialLibrary.resolve_color(data)

	if style == "weapon":
		var length: float = float(data.get("length", 0.6))
		var width: float = float(data.get("width", 0.06))
		var blade := _mesh_instance(PrimitiveMeshLibrary.get_box(width, length, width), MaterialLibrary.make_material(mat_data))
		blade.position.y = length * 0.5
		root.add_child(blade)
	elif style == "armor":
		var armor := _mesh_instance(PrimitiveMeshLibrary.get_box(radius * 2.0, radius * 2.4, radius * 1.2), MaterialLibrary.make_material(mat_data))
		root.add_child(armor)
	else:
		var orb := _mesh_instance(PrimitiveMeshLibrary.get_sphere(radius, 12, 12), MaterialLibrary.make_material(mat_data))
		orb.position.y = radius * 1.5
		root.add_child(orb)
		root.set_meta("float_orb", orb)


## ---- Prop (door/container/vehicle/structure) ----------------------------

static func _build_prop(root: Node3D, data: Dictionary) -> void:
	var mat_data: Dictionary = data.get("material", {"type": "organic", "roughness": 0.9})
	match str(data.get("prop_type", "")).to_lower():
		"door":
			var w: float = float(data.get("width", 1.2))
			var h: float = float(data.get("height", 2.4))
			var door := _mesh_instance(PrimitiveMeshLibrary.get_box(w, h, 0.15), MaterialLibrary.make_material(mat_data))
			door.position.y = h * 0.5
			root.add_child(door)
		"container":
			var w: float = float(data.get("width", 0.8))
			var h: float = float(data.get("height", 0.6))
			var d: float = float(data.get("depth", 0.6))
			var box := _mesh_instance(PrimitiveMeshLibrary.get_box(w, h, d), MaterialLibrary.make_material(mat_data))
			box.position.y = h * 0.5
			root.add_child(box)
		"vehicle":
			var l: float = float(data.get("length", 2.0))
			var w: float = float(data.get("width", 1.0))
			var h: float = float(data.get("height", 0.8))
			var body := _mesh_instance(PrimitiveMeshLibrary.get_box(w, h, l), MaterialLibrary.make_material(mat_data))
			body.position.y = h * 0.5
			root.add_child(body)
		"structure", _:
			var w: float = float(data.get("width", 1.5))
			var h: float = float(data.get("height", 2.0))
			var d: float = float(data.get("depth", 1.5))
			var body := _mesh_instance(PrimitiveMeshLibrary.get_box(w, h, d), MaterialLibrary.make_material(mat_data))
			body.position.y = h * 0.5
			root.add_child(body)


## ---- Attachments ---------------------------------------------------------

static func _attach_to_head(head: MeshInstance3D, att: String, mat_data: Dictionary) -> void:
	match att.to_lower():
		"horns":
			for side in [-1.0, 1.0]:
				var horn := _mesh_instance(PrimitiveMeshLibrary.get_prism(3, 0.06, 0.3), MaterialLibrary.make_material({"type": "chitin", "roughness": 0.5}))
				horn.position = Vector3(side * 0.08, 0.12, 0)
				horn.rotation.z = side * -0.4
				head.add_child(horn)
		"helmet", "hooded", "circuit_mask":
			var cap := _mesh_instance(PrimitiveMeshLibrary.get_sphere(0.12, 8, 8), MaterialLibrary.make_material({"type": "metallic", "roughness": 0.4}))
			cap.scale = Vector3(1.05, 0.7, 1.05)
			cap.position.y = 0.06
			head.add_child(cap)


static func _attach_generic(root: Node3D, torso: MeshInstance3D, att: String, mat_data: Dictionary) -> void:
	match att.to_lower():
		"wings":
			for side in [-1.0, 1.0]:
				var wing := _mesh_instance(PrimitiveMeshLibrary.get_plane(0.8, 0.5), MaterialLibrary.make_material({"type": "metallic", "roughness": 0.6, "transparent": true}))
				wing.position = Vector3(side * 0.3, torso.position.y, 0)
				wing.rotation.y = side * 0.6
				root.add_child(wing)
		"tail":
			var tail := _mesh_instance(PrimitiveMeshLibrary.get_limb_segment(0.05, 0.12, 0.7, 5), MaterialLibrary.make_material(mat_data))
			tail.position = Vector3(0, 0.3, -0.4)
			tail.rotation.x = 0.8
			root.add_child(tail)
		"armor":
			var plate := _mesh_instance(PrimitiveMeshLibrary.get_box(0.9, 0.6, 0.6), MaterialLibrary.make_material({"type": "metallic", "roughness": 0.4}))
			plate.position = torso.position + Vector3(0, 0.1, 0)
			root.add_child(plate)
		"weapon":
			var wpn := _mesh_instance(PrimitiveMeshLibrary.get_box(0.08, 0.6, 0.08), MaterialLibrary.make_material({"type": "metallic", "roughness": 0.3}))
			wpn.position = Vector3(0.45, torso.position.y + 0.2, 0.1)
			root.add_child(wpn)


## ---- Resource nodes (trees, crystals, ore, plants) ----------------------

static func _build_resource(root: Node3D, data: Dictionary) -> void:
	var mat_data: Dictionary = data.get("material", {"type": "organic", "roughness": 0.9})
	var rtype: String = str(data.get("resource_type", "tree")).to_lower()
	match rtype:
		"tree", "forest":
			var trunk_h: float = float(data.get("trunk_height", 0.8))
			var trunk := _mesh_instance(PrimitiveMeshLibrary.get_cylinder(0.12, trunk_h, 6), MaterialLibrary.make_material({"type": "organic", "roughness": 0.95, "color": [0.4, 0.3, 0.2]}))
			trunk.position.y = trunk_h * 0.5
			root.add_child(trunk)
			var canopy_r: float = float(data.get("canopy_radius", 0.7))
			var canopy := _mesh_instance(PrimitiveMeshLibrary.get_sphere(canopy_r, 10, 10), MaterialLibrary.make_material(mat_data))
			canopy.position.y = trunk_h + canopy_r * 0.6
			canopy.scale = Vector3(1.0, 0.8, 1.0)
			root.add_child(canopy)
		"crystal", "crystal_formation":
			var count: int = int(data.get("cluster", 4))
			var h: float = float(data.get("height", 1.2))
			for i in range(count):
				var ang: float = float(i) / count * TAU
				var rad: float = 0.15 + (i % 2) * 0.1
				var shard := _mesh_instance(PrimitiveMeshLibrary.get_prism(4, rad, h * (0.7 + (i % 3) * 0.15)), MaterialLibrary.make_material(mat_data))
				shard.position = Vector3(cos(ang) * 0.2, h * 0.4, sin(ang) * 0.2)
				shard.rotation.y = ang
				root.add_child(shard)
		"ore", "rock", "mineral":
			var rad: float = float(data.get("radius", 0.6))
			var rock := _mesh_instance(PrimitiveMeshLibrary.get_sphere(rad, 8, 8), MaterialLibrary.make_material(mat_data))
			rock.position.y = rad * 0.5
			rock.scale = Vector3(1.0, 0.7, 1.0)
			root.add_child(rock)
			# a couple of smaller chunks
			for i in range(2):
				var chunk := _mesh_instance(PrimitiveMeshLibrary.get_sphere(rad * 0.4, 6, 6), MaterialLibrary.make_material(mat_data))
				chunk.position = Vector3((i * 2 - 1) * rad * 0.6, rad * 0.2, (i - 0.5) * rad * 0.4)
				root.add_child(chunk)
		"plant", "bush", "fungus":
			var h: float = float(data.get("height", 0.5))
			var stem := _mesh_instance(PrimitiveMeshLibrary.get_cylinder(0.04, h, 5), MaterialLibrary.make_material({"type": "organic", "roughness": 0.9, "color": [0.3, 0.5, 0.2]}))
			stem.position.y = h * 0.5
			root.add_child(stem)
			var bloom := _mesh_instance(PrimitiveMeshLibrary.get_sphere(h * 0.5, 8, 8), MaterialLibrary.make_material(mat_data))
			bloom.position.y = h
			root.add_child(bloom)
		true:
			# Unknown resource type: fall back to a simple plant/bush blob.
			var blob := _mesh_instance(PrimitiveMeshLibrary.get_sphere(0.4, 8, 8), MaterialLibrary.make_material(mat_data))
			blob.position.y = 0.3
			root.add_child(blob)


## ---- Helpers -------------------------------------------------------------

static func _mesh_instance(mesh: Mesh, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if material != null:
		mi.material_override = material
	return mi


static func _randf_range(a: float, b: float) -> float:
	if _seed_rng == null:
		_seed_rng = RandomNumberGenerator.new()
		_seed_rng.seed = 1
	return _seed_rng.randf_range(a, b)
