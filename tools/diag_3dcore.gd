extends SceneTree

func _init() -> void:
	print("[diag-3dcore] Testing WorldGenerator 3D helpers + simulated globe build...")
	var wg: WorldGenerator = WorldGenerator.new()
	get_root().add_child(wg)
	if not wg.initialize():
		print("[diag-3dcore] FAIL: WorldGenerator init (biomes)")
		quit(1)
		return

	var world: Dictionary = wg.generate("TestGlobe42", 1.0, 8)
	print("[diag-3dcore] generated tiles: ", world.size())

	# Simulate the 3D build without UI nodes
	var root: Node3D = Node3D.new()
	get_root().add_child(root)

	var base: MeshInstance3D = MeshInstance3D.new()
	base.mesh = SphereMesh.new()
	root.add_child(base)

	var hex_mesh: ArrayMesh = WorldGenerator.create_hex_prism_mesh(0.21, 0.11)
	var sphere_r: float = 4.0
	var hex_r: int = 8
	var count: int = 0
	for key in world.keys():
		var parts: PackedStringArray = key.split(",")
		if parts.size() < 2: continue
		var q: int = int(parts[0])
		var r: int = int(parts[1])
		var pos: Vector3 = WorldGenerator.get_hex_spherical_pos(q, r, hex_r, sphere_r)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = hex_mesh
		mi.position = pos
		var radial: Vector3 = pos.normalized()
		var arb: Vector3 = Vector3(0,1,0)
		if abs(radial.dot(arb)) > 0.9: arb = Vector3(1,0,0)
		var xx: Vector3 = arb.cross(radial).normalized()
		var yy: Vector3 = radial.cross(xx).normalized()
		mi.transform.basis = Basis(xx, yy, radial)
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.6, 0.4)
		mi.material_override = mat
		root.add_child(mi)
		count += 1

	print("[diag-3dcore] built ", count, " hex meshes on sphere")

	if count > 50:
		print("[diag-3dcore] SUCCESS: 3D hex sphere construction works.")
		quit(0)
	else:
		print("[diag-3dcore] FAIL: too few tiles built")
		quit(1)
