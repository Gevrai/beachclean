extends SceneTree
## One-off: removes the closed tailgate triangles from the Quaternius pickup truck and saves the body mesh to
## assets/meshes/pickup_truck_open.res (used by scenes/props/pickup_truck.tscn). Run:
##   godot --headless --path . -s res://tools/open_tailgate.gd

func _initialize() -> void:
	var s: Node = load("res://assets/models/vehicles/pickup_truck.glb").instantiate()
	var mi: MeshInstance3D = s.find_child("Pickup", true, false)
	var xf := Transform3D.IDENTITY
	var n: Node = mi
	while n != null and n != s.get_parent():
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	var m := mi.mesh
	var out := ArrayMesh.new()
	var removed := 0
	for si in m.get_surface_count():
		var arr := m.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var keep := PackedInt32Array()
		for t in idx.size() / 3:
			var drop := si == 0
			for k in 3:
				var w: Vector3 = xf * v[idx[t * 3 + k]]
				if w.z > -2.24 or w.z < -2.46 or w.y < 0.7 or w.y > 1.31 or absf(w.x) > 0.92:
					drop = false
			if drop:
				removed += 1
			else:
				keep.append_array([idx[t * 3], idx[t * 3 + 1], idx[t * 3 + 2]])
		arr[Mesh.ARRAY_INDEX] = keep
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(si, m.surface_get_material(si))
	ResourceSaver.save(out, "res://assets/meshes/pickup_truck_open.res")
	print("open_tailgate: removed %d triangles" % removed)
	quit()
