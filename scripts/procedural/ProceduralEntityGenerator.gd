## ProceduralEntityGenerator — Reads entity data (JSON) and builds Node3D visuals.
## Main entry point: create_visual(data: Dictionary) -> Node3D
## Supports presets: humanoid, beast, mechanical, rift, item
## Applies seed-based variations (scale, offset, color hue).
class_name ProceduralEntityGenerator
extends RefCounted

const RACE_DATA_PATH := "res://data/races.json"
const APPEARANCE_PATH := "res://data/appearance.json"
const MOBS_PATH := "res://data/mobs.json"

static func resolve_visual_data(data: Dictionary) -> Dictionary:
	if data.has("visual") and not data.get("visual", {}).is_empty():
		return data["visual"]
	var preset_name: String = str(data.get("visual_preset", ""))
	if not preset_name.is_empty():
		return _load_preset(preset_name)
	var mtype: String = str(data.get("type", ""))
	if not mtype.is_empty():
		var mob_vis := load_mob_visual(mtype)
		if not mob_vis.is_empty():
			return mob_vis
	var race: String = str(data.get("race", ""))
	if not race.is_empty():
		var race_vis := load_race_visual(race)
		if not race_vis.is_empty():
			return race_vis
	var archetype: String = str(data.get("archetype", ""))
	if not archetype.is_empty():
		return _visual_for_archetype(archetype)
	return {}

static func _load_preset(preset_name: String) -> Dictionary:
	var file := FileAccess.open(APPEARANCE_PATH, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.parse_string(file.get_as_text())
	file.close()
	if json is Dictionary:
		var presets: Dictionary = json.get("visual_presets", {})
		if presets.has(preset_name):
			var preset: Dictionary = presets[preset_name].duplicate(true)
			return preset
	return {}

static func _visual_for_archetype(archetype: String) -> Dictionary:
	match archetype:
		"quadruped": return _load_preset("beast_quadruped")
		"insectoid": return _load_preset("beast_insectoid")
		"behemoth": return _load_preset("beast_behemoth")
		"aberrant": return _load_preset("beast_insectoid")
		"raider", "smuggler", "spy", "cultist", "tech_cultist", "mercenary":
			return _load_preset("humanoid_default")
		_: return _load_preset("humanoid_default")

static func create_visual(data: Dictionary) -> Node3D:
	var visual: Dictionary = resolve_visual_data(data)
	if visual.is_empty():
		visual = data.get("visual", {})
	var preset: String = visual.get("base_type", "humanoid")
	var rng := RandomNumberGenerator.new()
	rng.seed = visual.get("variation_seed", randi())
	data["visual"] = visual

	var root: Node3D
	match preset:
		"humanoid":
			root = _build_humanoid(data, rng)
		"beast":
			root = _build_beast(data, rng)
		"mechanical":
			root = _build_mechanical(data, rng)
		"rift":
			root = _build_rift(data, rng)
		"item":
			root = _build_item(data, rng)
		"prop":
			root = _build_prop(data, rng)
		_:
			root = _build_humanoid(data, rng)

	var scale_range: Array = data.get("visual", {}).get("scale_range", [0.9, 1.1])
	_apply_variations(root, rng, scale_range)
	return root

static func _build_humanoid(data: Dictionary, rng: RandomNumberGenerator) -> Node3D:
	var vis: Dictionary = data.get("visual", {})
	var torso_data: Dictionary = vis.get("torso", {})
	var head_data: Dictionary = vis.get("head", {})
	var limbs_data: Dictionary = vis.get("limbs", {})

	var root := PrimitiveMeshLibrary.compose_humanoid(
		torso_data.get("height", 1.0),
		head_data.get("scale", 0.2),
		limbs_data.get("leg_height", 0.6),
		limbs_data.get("arm_height", 0.5)
	)
	root.name = data.get("entity_id", "Humanoid")

	var mat: Material = _resolve_material(data)
	_apply_material_to_children(root, mat)

	var attachments: Array = head_data.get("attachments", [])
	for att in attachments:
		var att_node: Node3D = _create_attachment(att, rng)
		if att_node:
			att_node.position.y = torso_data.get("height", 1.0) * 0.5 + 0.3
			root.add_child(att_node)

	return root

static func _build_beast(data: Dictionary, rng: RandomNumberGenerator) -> Node3D:
	var vis: Dictionary = data.get("visual", {})
	var body_data: Dictionary = vis.get("torso", vis.get("body", {}))
	var head_data: Dictionary = vis.get("head", {})

	var root := PrimitiveMeshLibrary.compose_beast(
		body_data.get("length", 1.2),
		body_data.get("height", 0.6),
		head_data.get("scale", 0.18),
		body_data.get("leg_height", 0.4)
	)
	root.name = data.get("entity_id", "Beast")

	var mat: Material = _resolve_material(data)
	_apply_material_to_children(root, mat)
	return root

static func _build_mechanical(data: Dictionary, rng: RandomNumberGenerator) -> Node3D:
	var vis: Dictionary = data.get("visual", {})
	var root := PrimitiveMeshLibrary.compose_humanoid(
		vis.get("torso", {}).get("height", 1.0),
		vis.get("head", {}).get("scale", 0.2),
		vis.get("limbs", {}).get("leg_height", 0.6),
		vis.get("limbs", {}).get("arm_height", 0.5)
	)
	root.name = data.get("entity_id", "Mechanical")

	var mat: Material = MaterialLibrary.create_metallic_material(
		Color(0.5, 0.5, 0.55),
		vis.get("material", {}).get("roughness", 0.3)
	)
	_apply_material_to_children(root, mat)

	var glow_node := PrimitiveMeshLibrary.body_sphere(0.1)
	glow_node.name = "CoreGlow"
	glow_node.position.y = 0.5
	glow_node.set_surface_override_material(0,
		MaterialLibrary.create_glow_material(Color(0.3, 0.6, 1.0)))
	root.add_child(glow_node)

	return root

static func _build_rift(data: Dictionary, rng: RandomNumberGenerator) -> Node3D:
	var root := PrimitiveMeshLibrary.compose_rift(
		data.get("visual", {}).get("radius", 1.5)
	)
	root.name = data.get("entity_id", "Rift")

	var rift_color: Color = _rift_type_color(data.get("rift_type", 0))
	var portal_mat := MaterialLibrary.create_portal_material(rift_color, 1.2)
	_apply_material_to_children(root, portal_mat)

	var ring_mat := MaterialLibrary.create_glow_material(
		rift_color.lightened(0.3), 0.8)
	var ring := root.get_node_or_null("Ring")
	if ring:
		ring.set_surface_override_material(0, ring_mat)

	var core := root.get_node_or_null("Core")
	if core:
		core.set_surface_override_material(0,
			MaterialLibrary.create_glow_material(rift_color.lightened(0.5), 2.0))

	return root

static func _build_item(data: Dictionary, rng: RandomNumberGenerator) -> Node3D:
	var vis: Dictionary = data.get("visual", {})
	var item_style: String = vis.get("style", "orb")
	var root: Node3D

	match item_style:
		"weapon":
			var length: float = vis.get("length", 0.6)
			var width: float = vis.get("width", 0.06)
			root = PrimitiveMeshLibrary.compose_item_weapon(length, width)
			var color_arr: Array = vis.get("color", [0.6, 0.6, 0.65])
			var color := Color(color_arr[0], color_arr[1], color_arr[2])
			_apply_material_to_children(root, MaterialLibrary.create_metallic_material(color, 0.2))
		"armor":
			var radius: float = vis.get("radius", 0.25)
			root = PrimitiveMeshLibrary.compose_item_armor(radius)
			var color_arr: Array = vis.get("color", [0.5, 0.5, 0.55])
			var color := Color(color_arr[0], color_arr[1], color_arr[2])
			_apply_material_to_children(root, MaterialLibrary.create_metallic_material(color, 0.3))
		"consumable":
			var radius: float = vis.get("radius", 0.12)
			root = PrimitiveMeshLibrary.compose_item_consumable(radius)
			var color_arr: Array = vis.get("color", [0.3, 0.7, 0.4])
			var color := Color(color_arr[0], color_arr[1], color_arr[2])
			_apply_material_to_children(root, MaterialLibrary.create_glow_material(color, 0.8))
		_:
			var radius: float = vis.get("radius", 0.2)
			root = PrimitiveMeshLibrary.compose_item_orb(radius)
			var color_arr: Array = vis.get("color", [0.4, 0.7, 1.0])
			var color := Color(color_arr[0], color_arr[1], color_arr[2])
			var mat := MaterialLibrary.create_glow_material(color, 0.6)
			_apply_material_to_children(root, mat)
			var orb := root.get_node_or_null("Orb")
			if orb:
				orb.set_surface_override_material(0,
					MaterialLibrary.create_glow_material(color.lightened(0.3), 1.0))

	root.name = data.get("entity_id", "Item")
	return root

static func _build_prop(data: Dictionary, rng: RandomNumberGenerator) -> Node3D:
	var vis: Dictionary = data.get("visual", {})
	var prop_type: String = vis.get("prop_type", "structure")
	var root: Node3D

	match prop_type:
		"door":
			var width: float = vis.get("width", 1.2)
			var height: float = vis.get("height", 2.4)
			root = PrimitiveMeshLibrary.compose_door(width, height)
			var color_arr: Array = vis.get("color", [0.4, 0.3, 0.25])
			var color := Color(color_arr[0], color_arr[1], color_arr[2])
			_apply_material_to_children(root, MaterialLibrary.create_organic_material(color, 0.9))
			var highlight := _create_interaction_highlight(Vector3(width * 0.6, height * 0.5, 0.3))
			highlight.position = Vector3(0.0, height * 0.5, 0.2)
			root.add_child(highlight)
		"container":
			var width: float = vis.get("width", 0.8)
			var height: float = vis.get("height", 0.6)
			var depth: float = vis.get("depth", 0.6)
			root = PrimitiveMeshLibrary.compose_container(width, height, depth)
			var color_arr: Array = vis.get("color", [0.45, 0.35, 0.3])
			var color := Color(color_arr[0], color_arr[1], color_arr[2])
			_apply_material_to_children(root, MaterialLibrary.create_metallic_material(color, 0.5))
			var highlight := _create_interaction_highlight(Vector3(width * 0.5, height * 0.5, depth * 0.5))
			highlight.position = Vector3(0.0, height * 0.5, 0.0)
			root.add_child(highlight)
		"vehicle":
			var length: float = vis.get("length", 2.0)
			var width: float = vis.get("width", 1.0)
			var height: float = vis.get("height", 0.8)
			root = PrimitiveMeshLibrary.compose_vehicle(length, width, height)
			var color_arr: Array = vis.get("color", [0.4, 0.4, 0.45])
			var color := Color(color_arr[0], color_arr[1], color_arr[2])
			_apply_material_to_children(root, MaterialLibrary.create_metallic_material(color, 0.4))
		_:
			var width: float = vis.get("width", 1.5)
			var height: float = vis.get("height", 2.0)
			var depth: float = vis.get("depth", 1.5)
			root = PrimitiveMeshLibrary.compose_structure(width, height, depth)
			var color_arr: Array = vis.get("color", [0.5, 0.45, 0.4])
			var color := Color(color_arr[0], color_arr[1], color_arr[2])
			_apply_material_to_children(root, MaterialLibrary.create_organic_material(color, 0.85))

	root.name = data.get("entity_id", "Prop")
	return root

static func _create_interaction_highlight(extents: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Highlight"
	var box := BoxMesh.new()
	box.size = extents
	mi.mesh = box
	var mat := MaterialLibrary.create_outline_material(Color(0.4, 0.8, 1.0))
	mi.set_surface_override_material(0, mat)
	return mi

static func _apply_variations(root: Node3D, rng: RandomNumberGenerator, scale_range: Array) -> void:
	var scale_min: float = scale_range[0] if scale_range.size() > 0 else 0.9
	var scale_max: float = scale_range[1] if scale_range.size() > 1 else 1.1
	var uniform_scale: float = rng.randf_range(scale_min, scale_max)
	root.scale = Vector3(uniform_scale, uniform_scale, uniform_scale)

	for child in root.get_children():
		if child is MeshInstance3D:
			var hue_shift: float = rng.randf_range(-0.05, 0.05)
			var pos_offset := Vector3(
				rng.randf_range(-0.02, 0.02),
				rng.randf_range(-0.02, 0.02),
				rng.randf_range(-0.02, 0.02)
			)
			child.position += pos_offset
			if child.get_surface_override_material(0) == null:
				var orig := child.material_override if child.material_override else null
				if orig and orig is StandardMaterial3D:
					var c := orig.albedo_color
					var h: float
					var s: float
					var v: float
					c.to_hsv()
					h = c.h + hue_shift
					if h < 0.0: h += 1.0
					elif h > 1.0: h -= 1.0
					var new_mat := MaterialLibrary.create_palette_material(
						Color.from_hsv(h, c.s, c.v),
						{"roughness": orig.roughness, "metallic": orig.metallic}
					)
					child.material_override = new_mat

static func _resolve_material(data: Dictionary) -> Material:
	var vis: Dictionary = data.get("visual", {})
	var mat_data: Dictionary = vis.get("material", vis)
	if mat_data.is_empty():
		return MaterialLibrary.create_organic_material(Color(0.5, 0.5, 0.5))
	return MaterialLibrary.material_from_visual_data(vis)

static func _apply_material_to_children(root: Node3D, mat: Material) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			child.material_override = mat

static func _create_attachment(att_name: String, rng: RandomNumberGenerator) -> Node3D:
	match att_name.to_lower():
		"horns":
			var horn_l := PrimitiveMeshLibrary.attachment_horn()
			horn_l.rotation.z = deg_to_rad(15.0)
			horn_l.position = Vector3(-0.12, 0.0, 0.0)
			var horn_r := PrimitiveMeshLibrary.attachment_horn()
			horn_r.rotation.z = deg_to_rad(-15.0)
			horn_r.position = Vector3(0.12, 0.0, 0.0)
			var group := Node3D.new()
			group.name = "Horns"
			group.add_child(horn_l)
			group.add_child(horn_r)
			return group
		"wings":
			var wing_l := PrimitiveMeshLibrary.attachment_wing()
			wing_l.position = Vector3(-0.15, 0.1, 0.0)
			wing_l.rotation.y = deg_to_rad(20.0)
			var wing_r := PrimitiveMeshLibrary.attachment_wing()
			wing_r.position = Vector3(0.15, 0.1, 0.0)
			wing_r.rotation.y = deg_to_rad(-20.0)
			var group := Node3D.new()
			group.name = "Wings"
			group.add_child(wing_l)
			group.add_child(wing_r)
			return group
		"tail":
			return PrimitiveMeshLibrary.attachment_tail()
		"armor_plate":
			return PrimitiveMeshLibrary.attachment_armor_plate()
		"weapon":
			return PrimitiveMeshLibrary.attachment_weapon()
		"shield":
			return PrimitiveMeshLibrary.attachment_shield()
	return null

static func _rift_type_color(rift_type: int) -> Color:
	match rift_type:
		0: return Color(0.3, 0.25, 0.45)
		1: return Color(0.2, 0.55, 0.35)
		2: return Color(0.45, 0.35, 0.9)
		_: return Color(0.3, 0.3, 0.5)

static func load_race_visual(race_key: String) -> Dictionary:
	var file := FileAccess.open(RACE_DATA_PATH, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.parse_string(file.get_as_text())
	file.close()
	if json is Dictionary:
		for origin in json.values():
			if origin is Dictionary and origin.has(race_key):
				var entry: Dictionary = origin[race_key]
				var tag: String = str(entry.get("visual_tag", ""))
				if not tag.is_empty():
					return _visual_for_tag(tag)
	return {}

static func load_mob_visual(mob_type: String) -> Dictionary:
	var file := FileAccess.open(MOBS_PATH, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.parse_string(file.get_as_text())
	file.close()
	if json is Dictionary:
		var overworld: Dictionary = json.get("overworld", {})
		for category in overworld.values():
			if category is Array:
				for mob in category:
					if mob is Dictionary and str(mob.get("type", "")) == mob_type:
						return _infer_visual_from_mob(mob)
	return {}

static func _infer_visual_from_mob(mob: Dictionary) -> Dictionary:
	var mtype: String = str(mob.get("type", ""))
	var name: String = str(mob.get("name", ""))
	var preset: String = "beast"
	if "insect" in mtype or "scuttler" in mtype or "swarm" in mtype:
		preset = "beast"
	elif "behemoth" in mtype or "hulk" in mtype:
		preset = "beast"
	elif "float" in mtype or "jelly" in mtype:
		preset = "beast"
	elif "humanoid" in mtype or "raider" in mtype or "cultist" in mtype:
		preset = "humanoid"

	var threat: int = mob.get("threat_range", 5)
	var size_scale: float = 0.8 + float(threat) * 0.04

	return {
		"base_type": preset,
		"scale_range": [size_scale * 0.9, size_scale * 1.1],
		"torso": {"color": [0.4, 0.35, 0.3]},
		"material": {"type": "organic", "roughness": 0.8},
		"variation_seed": abs(name.hash()),
	}

static func _visual_for_tag(tag: String) -> Dictionary:
	match tag:
		"human":
			return {
				"base_type": "humanoid",
				"torso": {"height": 1.0, "radius": 0.35, "color": [0.8, 0.7, 0.6]},
				"head": {"scale": 0.2, "attachments": []},
				"limbs": {"count": 4, "style": "thin_cylinder", "leg_height": 0.6, "arm_height": 0.5},
				"material": {"type": "organic", "roughness": 0.8},
			}
		"mutant":
			return {
				"base_type": "humanoid",
				"torso": {"height": 1.2, "radius": 0.4, "color": [0.35, 0.7, 0.3]},
				"head": {"scale": 0.25, "attachments": ["horns"]},
				"limbs": {"count": 4, "style": "thick_cylinder", "leg_height": 0.65, "arm_height": 0.55},
				"material": {"type": "organic", "roughness": 0.85, "glow": 0.15},
			}
		"vesperid":
			return {
				"base_type": "humanoid",
				"torso": {"height": 1.1, "radius": 0.32, "color": [0.55, 0.45, 0.35]},
				"head": {"scale": 0.22, "attachments": ["horns"]},
				"limbs": {"count": 6, "style": "thin_cylinder", "leg_height": 0.7, "arm_height": 0.5},
				"material": {"type": "organic", "roughness": 0.7, "metallic": 0.2},
			}
		"ai", "cyborg":
			return {
				"base_type": "mechanical",
				"torso": {"height": 1.0, "radius": 0.35, "color": [0.5, 0.5, 0.55]},
				"head": {"scale": 0.2, "attachments": []},
				"limbs": {"count": 4, "style": "cylinder", "leg_height": 0.6, "arm_height": 0.5},
				"material": {"type": "metallic", "roughness": 0.3},
			}
		_:
			return {
				"base_type": "humanoid",
				"torso": {"height": 1.0, "radius": 0.35, "color": [0.5, 0.5, 0.5]},
				"head": {"scale": 0.2},
				"limbs": {"count": 4},
				"material": {"type": "organic"},
			}
