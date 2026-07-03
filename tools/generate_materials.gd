# generate_materials.gd
extends SceneTree

func _init():
	generate_materials()
	quit()

func generate_materials():
	var source_dir = "res://data/sources/materials/"
	var target_dir = "res://data/materials/"
	
	if not DirAccess.dir_exists_absolute(target_dir):
		DirAccess.make_dir_recursive_absolute(target_dir)
	
	var names = [
		"material3d_mesh_capsule",
		"material3d_mesh_cone",
		"material3d_mesh_cube",
		"material3d_mesh_cylinder",
		"material3d_mesh_plane",
		"material3d_mesh_sphere",
		"material3d_mesh_torus",
		"material3d_mesh_torus_knot"
	]
	
	for name in names:
		process_material(name, source_dir, target_dir)

func process_material(material_name, source_dir, target_dir):
	var file_name = material_name + ".tres.gd"
	var source_path = source_dir + file_name
	var target_path = target_dir + material_name + ".tres"
	
	print("Generating: " + target_path)
	
	var script = ResourceLoader.load(source_path)
	if not script:
		print("ERROR: Failed to load script: " + source_path)
		return
	
	var material = script.new()
	if not material:
		print("ERROR: Failed to instantiate: " + material_name)
		return
	
	material.resource_name = material_name
	
	var error = ResourceSaver.save(material, target_path)
	if error != 0:
		print("ERROR: Failed to save " + target_path + ": " + str(error))
	else:
		print("SUCCESS: Generated " + target_path)