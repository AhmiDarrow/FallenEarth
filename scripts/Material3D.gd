@tool
extends Resource
class_name Material3D

static var global_materials: Dictionary = {}

var mesh: Mesh3DData
var data: String

func _preload():
	data = ""