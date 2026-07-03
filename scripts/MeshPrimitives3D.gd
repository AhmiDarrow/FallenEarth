@tool
extends Resource
class_name MeshPrimitives3D

static func create_plane() -> Mesh3D:
	var m = Mesh3D.new()
	m.mesh_type = "plane"
	return m

static func create_box() -> Mesh3D:
	var m = Mesh3D.new()
	m.mesh_type = "box"
	return m

static func create_sphere() -> Mesh3D:
	var m = Mesh3D.new()
	m.mesh_type = "sphere"
	return m

static func create_cylinder() -> Mesh3D:
	var m = Mesh3D.new()
	m.mesh_type = "cylinder"
	return m

static func create_cone() -> Mesh3D:
	var m = Mesh3D.new()
	m.mesh_type = "cone"
	return m

static func create_torus() -> Mesh3D:
	var m = Mesh3D.new()
	m.mesh_type = "torus"
	return m

static func create_torus_knot() -> Mesh3D:
	var m = Mesh3D.new()
	m.mesh_type = "torus_knot"
	return m

static func create_capsule() -> Mesh3D:
	var m = Mesh3D.new()
	m.mesh_type = "capsule"
	return m