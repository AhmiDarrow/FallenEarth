// _material3d.gd
// Pre-compiled material3d resources for primitive meshes

@tool
extends Resource

class_name _Material3dResources

var material3d_mesh_plane: Material3D
var material3d_mesh_cube: Material3D
var material3d_mesh_sphere: Material3D
var material3d_mesh_cylinder: Material3D
var material3d_mesh_cone: Material3D
var material3d_mesh_torus: Material3D
var material3d_mesh_torus_knot: Material3D
var material3d_mesh_capsule: Material3D

# Pre-compiled RIDs for faster drawing
var rid_mesh_plane: RID
var rid_mesh_cube: RID
var rid_mesh_sphere: RID
var rid_mesh_cylinder: RID
var rid_mesh_cone: RID
var rid_mesh_torus: RID
var rid_mesh_torus_knot: RID
var rid_mesh_capsule: RID

func _init():
	# Pre-compile all meshes and assign materials
	_compiled_meshes()
	_preload_materials()

func _compiled_meshes():
	# Pre-compile all meshes and assign materials
	var plane = MeshPrimitives3D.create_plane()
	plane.material = material3d_mesh_plane
	material3d_mesh_plane = plane.material

	var cube = MeshPrimitives3D.create_box()
	cube.material = material3d_mesh_cube
	material3d_mesh_cube = cube.material

	var sphere = MeshPrimitives3D.create_sphere()
	sphere.material = material3d_mesh_sphere
	material3d_mesh_sphere = sphere.material

	var cylinder = MeshPrimitives3D.create_cylinder()
	cylinder.material = material3d_mesh_cylinder
	material3d_mesh_cylinder = cylinder.material

	var cone = MeshPrimitives3D.create_cone()
	cone.material = material3d_mesh_cone
	material3d_mesh_cone = cone.material

	var torus = MeshPrimitives3D.create_torus()
	torus.material = material3d_mesh_torus
	material3d_mesh_torus = torus.material

	var torus_knot = MeshPrimitives3D.create_torus_knot()
	torus_knot.material = material3d_mesh_torus_knot
	material3d_mesh_torus_knot = torus_knot.material

	var capsule = MeshPrimitives3D.create_capsule()
	capsule.material = material3d_mesh_capsule
	material3d_mesh_capsule = capsule.material

	# Store compiled meshes
	_compiled_rids(plane, material3d_mesh_plane)
	_compiled_rids(cube, material3d_mesh_cube)
	_compiled_rids(sphere, material3d_mesh_sphere)
	_compiled_rids(cylinder, material3d_mesh_cylinder)
	_compiled_rids(cone, material3d_mesh_cone)
	_compiled_rids(torus, material3d_mesh_torus)
	_compiled_rids(torus_knot, material3d_mesh_torus_knot)
	_compiled_rids(capsule, material3d_mesh_capsule)

func _compiled_rids(mesh: Mesh3D, material: Material3D):
	# Store the compiled mesh and RID
	mesh.resource_name = "_material3d_" + "_" + mesh.mesh_type
	var rid = mesh.compile()

	# Store in material
	mesh.material = material
	material.mesh = mesh

	# Store RID in resource
	resource.data += "" + str(rid) + "\n"

	# Store in global
	Material3D.global_materials["_material3d_" + "_" + mesh.mesh_type] = material
	Material3D.global_materials["_material3d_" + "_" + mesh.mesh_type]_rid = rid

func _preload_materials():
	# Preload material resources to avoid caching
	var materials = [
		"material3d_mesh_plane",
		"material3d_mesh_cube",
		"material3d_mesh_sphere",
		"material3d_mesh_cylinder",
		"material3d_mesh_cone",
		"material3d_mesh_torus",
		"material3d_mesh_torus_knot",
		"material3d_mesh_capsule",
	]

	for material_name in materials:
		var material = preload("res://data/materials/" + material_name + ".tres")
		if material:
			# Preload the material to avoid caching
			var material2 = Material3D.new()
			material2.resource_name = material.resource_name
			material2._preload()
			# Update global
			Material3D.global_materials[material.resource_name] = material2

# Pre-created global RIDs for faster drawing
const rid_mesh_plane: RID = -1
const rid_mesh_cube: RID = -1
const rid_mesh_sphere: RID = -1
const rid_mesh_cylinder: RID = -1
const rid_mesh_cone: RID = -1
const rid_mesh_torus: RID = -1
const rid_mesh_torus_knot: RID = -1
const rid_mesh_capsule: RID = -1
}