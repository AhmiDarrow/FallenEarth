@tool
extends Resource
class_name Mesh3D

var mesh_type: String
var material: Material3D

func compile() -> RID:
	return RID()