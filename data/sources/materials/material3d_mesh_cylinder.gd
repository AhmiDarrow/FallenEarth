# material3d_mesh_cylinder.tres

@tool
extends Material3D

class_name material3d_mesh_cylinder

func _init():
	# Preload material to avoid caching
	_preload()

func _preload():
	# Preload the material
	var material3d = Material3D.new()
	material3d.resource_name = "material3d_mesh_cylinder"
	material3d._preload()
	return material3d