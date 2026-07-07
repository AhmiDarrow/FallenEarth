## PrimitiveMeshLibrary — Reusable factory for procedural 3D primitives.
## Provides cached meshes for body parts, attachments, and effects.
## Uses SurfaceTool-based ArrayMesh construction (no CSG nodes) so it works in
## any Godot 4 build and is cheap to cache.
class_name PrimitiveMeshLibrary
extends RefCounted

static var _mesh_cache: Dictionary = {}


## Box (width, height, depth). All extents centered on origin.
static func get_box(width: float = 1.0, height: float = 1.0, depth: float = 1.0) -> ArrayMesh:
	var key: String = "box_%s_%s_%s" % [width, height, depth]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	var arr_mesh := ArrayMesh.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := width * 0.5
	var hh := height * 0.5
	var hd := depth * 0.5
	var verts := PackedVector3Array([
		Vector3(-hw, -hh, hd), Vector3(hw, -hh, hd), Vector3(hw, hh, hd),
		Vector3(-hw, -hh, hd), Vector3(hw, hh, hd), Vector3(-hw, hh, hd),
		Vector3(hw, -hh, -hd), Vector3(-hw, -hh, -hd), Vector3(-hw, hh, -hd),
		Vector3(hw, -hh, -hd), Vector3(-hw, hh, -hd), Vector3(hw, hh, -hd),
		Vector3(-hw, -hh, -hd), Vector3(-hw, -hh, hd), Vector3(-hw, hh, hd),
		Vector3(-hw, -hh, -hd), Vector3(-hw, hh, hd), Vector3(-hw, hh, -hd),
		Vector3(hw, -hh, hd), Vector3(hw, -hh, -hd), Vector3(hw, hh, -hd),
		Vector3(hw, -hh, hd), Vector3(hw, hh, -hd), Vector3(hw, hh, hd),
		Vector3(-hw, hh, hd), Vector3(hw, hh, hd), Vector3(hw, hh, -hd),
		Vector3(-hw, hh, hd), Vector3(hw, hh, -hd), Vector3(-hw, hh, -hd),
		Vector3(-hw, -hh, -hd), Vector3(hw, -hh, -hd), Vector3(hw, -hh, hd),
		Vector3(-hw, -hh, -hd), Vector3(hw, -hh, hd), Vector3(-hw, -hh, hd),
	])
	for v in verts:
		st.add_vertex(v)
	_finalize(st, arr_mesh, key)
	return arr_mesh


## Capsule (radius, height, radial_segments). Height is the full height.
static func get_capsule(radius: float = 0.5, height: float = 2.0, radial_segments: int = 8) -> ArrayMesh:
	var key: String = "capsule_%s_%s_%d" % [radius, height, radial_segments]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	var arr_mesh := ArrayMesh.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := maxi(2, radial_segments / 2)
	var cyl_h := maxf(0.0001, height - 2.0 * radius)
	var half_cyl := cyl_h * 0.5
	# Side
	for i in range(radial_segments):
		var a1 := float(i) / radial_segments * TAU
		var a2 := float(i + 1) / radial_segments * TAU
		# lower hemisphere
		_add_hemisphere_ring(st, radius, -half_cyl, a1, a2, false, rings)
		# upper hemisphere
		_add_hemisphere_ring(st, radius, half_cyl, a1, a2, true, rings)
	# cylinder wall
	for i in range(radial_segments):
		var a1 := float(i) / radial_segments * TAU
		var a2 := float(i + 1) / radial_segments * TAU
		var b1 := Vector3(cos(a1) * radius, -half_cyl, sin(a1) * radius)
		var b2 := Vector3(cos(a2) * radius, -half_cyl, sin(a2) * radius)
		var t1 := Vector3(cos(a1) * radius, half_cyl, sin(a1) * radius)
		var t2 := Vector3(cos(a2) * radius, half_cyl, sin(a2) * radius)
		st.add_vertex(b1); st.add_vertex(b2); st.add_vertex(t1)
		st.add_vertex(b2); st.add_vertex(t2); st.add_vertex(t1)
	_finalize(st, arr_mesh, key)
	return arr_mesh


static func _add_hemisphere_ring(st: SurfaceTool, radius: float, y_offset: float, a1: float, a2: float, top: bool, rings: int) -> void:
	for r in range(rings):
		var t0 := float(r) / rings
		var t1 := float(r + 1) / rings
		# angle from equator (0) to pole (PI/2)
		var phi0 := t0 * (PI * 0.5)
		var phi1 := t1 * (PI * 0.5)
		var rr0 := sin(phi0) * radius
		var rr1 := sin(phi1) * radius
		var y0 := y_offset + (1.0 if top else -1.0) * cos(phi0) * radius
		var y1 := y_offset + (1.0 if top else -1.0) * cos(phi1) * radius
		var p0a := Vector3(cos(a1) * rr0, y0, sin(a1) * rr0)
		var p0b := Vector3(cos(a2) * rr0, y0, sin(a2) * rr0)
		var p1a := Vector3(cos(a1) * rr1, y1, sin(a1) * rr1)
		var p1b := Vector3(cos(a2) * rr1, y1, sin(a2) * rr1)
		if top:
			st.add_vertex(p0a); st.add_vertex(p1a); st.add_vertex(p0b)
			st.add_vertex(p0b); st.add_vertex(p1a); st.add_vertex(p1b)
		else:
			st.add_vertex(p0a); st.add_vertex(p0b); st.add_vertex(p1a)
			st.add_vertex(p0b); st.add_vertex(p1b); st.add_vertex(p1a)


## Cylinder (radius, height, radial_segments).
static func get_cylinder(radius: float = 0.5, height: float = 1.0, radial_segments: int = 8) -> ArrayMesh:
	var key: String = "cylinder_%s_%s_%d" % [radius, height, radial_segments]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	var arr_mesh := ArrayMesh.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hh := height * 0.5
	for i in range(radial_segments):
		var a1 := float(i) / radial_segments * TAU
		var a2 := float(i + 1) / radial_segments * TAU
		var b1 := Vector3(cos(a1) * radius, -hh, sin(a1) * radius)
		var b2 := Vector3(cos(a2) * radius, -hh, sin(a2) * radius)
		var t1 := Vector3(cos(a1) * radius, hh, sin(a1) * radius)
		var t2 := Vector3(cos(a2) * radius, hh, sin(a2) * radius)
		st.add_vertex(b1); st.add_vertex(b2); st.add_vertex(t1)
		st.add_vertex(b2); st.add_vertex(t2); st.add_vertex(t1)
		# caps
		st.add_vertex(Vector3(0, -hh, 0)); st.add_vertex(b2); st.add_vertex(b1)
		st.add_vertex(Vector3(0, hh, 0)); st.add_vertex(t1); st.add_vertex(t2)
	_finalize(st, arr_mesh, key)
	return arr_mesh


## Sphere (radius, rings, radial_segments).
static func get_sphere(radius: float = 0.5, rings: int = 12, radial_segments: int = 12) -> ArrayMesh:
	var key: String = "sphere_%s_%d_%d" % [radius, rings, radial_segments]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	var arr_mesh := ArrayMesh.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in range(rings):
		var phi0 := float(r) / rings * PI
		var phi1 := float(r + 1) / rings * PI
		for i in range(radial_segments):
			var a1 := float(i) / radial_segments * TAU
			var a2 := float(i + 1) / radial_segments * TAU
			var p00 := _sphere_point(radius, phi0, a1)
			var p01 := _sphere_point(radius, phi0, a2)
			var p10 := _sphere_point(radius, phi1, a1)
			var p11 := _sphere_point(radius, phi1, a2)
			st.add_vertex(p00); st.add_vertex(p10); st.add_vertex(p01)
			st.add_vertex(p01); st.add_vertex(p10); st.add_vertex(p11)
	_finalize(st, arr_mesh, key)
	return arr_mesh


static func _sphere_point(radius: float, phi: float, theta: float) -> Vector3:
	return Vector3(
		sin(phi) * cos(theta) * radius,
		cos(phi) * radius,
		sin(phi) * sin(theta) * radius
	)


## Cone (radius, height, radial_segments).
static func get_cone(radius: float = 0.5, height: float = 1.0, radial_segments: int = 8) -> ArrayMesh:
	var key: String = "cone_%s_%s_%d" % [radius, height, radial_segments]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	var arr_mesh := ArrayMesh.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hh := height * 0.5
	for i in range(radial_segments):
		var a1 := float(i) / radial_segments * TAU
		var a2 := float(i + 1) / radial_segments * TAU
		var b1 := Vector3(cos(a1) * radius, -hh, sin(a1) * radius)
		var b2 := Vector3(cos(a2) * radius, -hh, sin(a2) * radius)
		var tip := Vector3(0, hh, 0)
		st.add_vertex(b1); st.add_vertex(b2); st.add_vertex(tip)
		st.add_vertex(Vector3(0, -hh, 0)); st.add_vertex(b2); st.add_vertex(b1)
	_finalize(st, arr_mesh, key)
	return arr_mesh


## Torus (inner_radius, outer_radius, tube_rings, radial_segments).
static func get_torus(inner_radius: float = 0.25, outer_radius: float = 0.5, tube_rings: int = 8, radial_segments: int = 16) -> ArrayMesh:
	var key: String = "torus_%s_%s_%d_%d" % [inner_radius, outer_radius, tube_rings, radial_segments]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	var arr_mesh := ArrayMesh.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring_radius := (inner_radius + outer_radius) * 0.5
	var tube_radius := (outer_radius - inner_radius) * 0.5
	for i in range(radial_segments):
		var a1 := float(i) / radial_segments * TAU
		var a2 := float(i + 1) / radial_segments * TAU
		for j in range(tube_rings):
			var t1 := float(j) / tube_rings * TAU
			var t2 := float(j + 1) / tube_rings * TAU
			var p00 := _torus_point(ring_radius, tube_radius, a1, t1)
			var p01 := _torus_point(ring_radius, tube_radius, a1, t2)
			var p10 := _torus_point(ring_radius, tube_radius, a2, t1)
			var p11 := _torus_point(ring_radius, tube_radius, a2, t2)
			st.add_vertex(p00); st.add_vertex(p10); st.add_vertex(p01)
			st.add_vertex(p01); st.add_vertex(p10); st.add_vertex(p11)
	_finalize(st, arr_mesh, key)
	return arr_mesh


static func _torus_point(ring_r: float, tube_r: float, a: float, t: float) -> Vector3:
	var cx := cos(a) * ring_r
	var cz := sin(a) * ring_r
	return Vector3(
		cx + cos(t) * tube_r * cos(a),
		sin(t) * tube_r,
		cz + cos(t) * tube_r * sin(a)
	)


## Prism (sides, radius, height) - for horns, spikes.
static func get_prism(sides: int = 3, radius: float = 0.3, height: float = 1.0) -> ArrayMesh:
	var key: String = "prism_%d_%s_%s" % [sides, radius, height]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	var arr_mesh := ArrayMesh.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var angle_step := TAU / sides
	var bottom_center := Vector3(0, -height * 0.5, 0)
	var top_center := Vector3(0, height * 0.5, 0)
	for i in range(sides):
		var a1 := i * angle_step
		var a2 := (i + 1) * angle_step
		var v1_bottom := Vector3(cos(a1) * radius, -height * 0.5, sin(a1) * radius)
		var v2_bottom := Vector3(cos(a2) * radius, -height * 0.5, sin(a2) * radius)
		var v1_top := Vector3(cos(a1) * radius, height * 0.5, sin(a1) * radius)
		var v2_top := Vector3(cos(a2) * radius, height * 0.5, sin(a2) * radius)
		st.add_vertex(v1_bottom); st.add_vertex(v2_bottom); st.add_vertex(v1_top)
		st.add_vertex(v2_bottom); st.add_vertex(v2_top); st.add_vertex(v1_top)
		st.add_vertex(bottom_center); st.add_vertex(v2_bottom); st.add_vertex(v1_bottom)
		st.add_vertex(top_center); st.add_vertex(v1_top); st.add_vertex(v2_top)
	_finalize(st, arr_mesh, key)
	return arr_mesh


## Plane (width, depth, subdiv_x, subdiv_z). Lies in XZ plane (y = 0).
static func get_plane(width: float = 1.0, depth: float = 1.0, subdiv_x: int = 1, subdiv_z: int = 1) -> ArrayMesh:
	var key: String = "plane_%s_%s_%d_%d" % [width, depth, subdiv_x, subdiv_z]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	var arr_mesh := ArrayMesh.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := width * 0.5
	var hd := depth * 0.5
	for z in range(subdiv_z):
		for x in range(subdiv_x):
			var x0 := -hw + (float(x) / subdiv_x) * width
			var x1 := -hw + (float(x + 1) / subdiv_x) * width
			var z0 := -hd + (float(z) / subdiv_z) * depth
			var z1 := -hd + (float(z + 1) / subdiv_z) * depth
			st.add_vertex(Vector3(x0, 0, z0)); st.add_vertex(Vector3(x1, 0, z0)); st.add_vertex(Vector3(x1, 0, z1))
			st.add_vertex(Vector3(x0, 0, z0)); st.add_vertex(Vector3(x1, 0, z1)); st.add_vertex(Vector3(x0, 0, z1))
	_finalize(st, arr_mesh, key)
	return arr_mesh


## Tapered limb segment (radius_top, radius_bottom, height).
static func get_limb_segment(radius_top: float, radius_bottom: float, height: float, radial_segments: int = 6) -> ArrayMesh:
	var key: String = "limb_%s_%s_%s_%d" % [radius_top, radius_bottom, height, radial_segments]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	var arr_mesh := ArrayMesh.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(radial_segments):
		var a1 := float(i) / radial_segments * TAU
		var a2 := float(i + 1) / radial_segments * TAU
		var b1 := Vector3(cos(a1) * radius_bottom, -height * 0.5, sin(a1) * radius_bottom)
		var b2 := Vector3(cos(a2) * radius_bottom, -height * 0.5, sin(a2) * radius_bottom)
		var t1 := Vector3(cos(a1) * radius_top, height * 0.5, sin(a1) * radius_top)
		var t2 := Vector3(cos(a2) * radius_top, height * 0.5, sin(a2) * radius_top)
		st.add_vertex(b1); st.add_vertex(b2); st.add_vertex(t1)
		st.add_vertex(b2); st.add_vertex(t2); st.add_vertex(t1)
		st.add_vertex(Vector3(0, -height * 0.5, 0)); st.add_vertex(b2); st.add_vertex(b1)
		st.add_vertex(Vector3(0, height * 0.5, 0)); st.add_vertex(t1); st.add_vertex(t2)
	_finalize(st, arr_mesh, key)
	return arr_mesh


static func _finalize(st: SurfaceTool, arr_mesh: ArrayMesh, key: String) -> void:
	st.generate_normals()
	st.index()
	st.commit(arr_mesh)
	_mesh_cache[key] = arr_mesh


static func clear_cache() -> void:
	_mesh_cache.clear()


static func get_cache_stats() -> Dictionary:
	return {"count": _mesh_cache.size(), "keys": _mesh_cache.keys()}
