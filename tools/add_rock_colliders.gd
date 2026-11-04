extends SceneTree
## One-off: adds a StaticBody3D with one simplified convex hull per boulder to scenes/props/rock_cluster_*.tscn.
## The hull points are baked in cluster space (the boulder's transform applied). Re-run after changing a cluster:
##   godot --headless --path . -s res://tools/add_rock_colliders.gd

func _initialize() -> void:
	for k in ["a", "b", "c"]:
		var path := "res://scenes/props/rock_cluster_%s.tscn" % k
		var root: Node3D = load(path).instantiate()
		var old := root.get_node_or_null("Body")
		if old:
			root.remove_child(old)
			old.free()
		var body := StaticBody3D.new()
		body.name = "Body"
		root.add_child(body)
		body.owner = root
		var n := 0
		for c in root.get_children():
			if c is MeshInstance3D:
				var hull: ConvexPolygonShape3D = (c as MeshInstance3D).mesh.create_convex_shape(true, true)
				var pts := hull.points
				for i in pts.size():
					pts[i] = (c as MeshInstance3D).transform * pts[i]
				hull.points = pts
				var cs := CollisionShape3D.new()
				cs.name = "Hull%d" % (n + 1)
				cs.shape = hull
				body.add_child(cs)
				cs.owner = root
				n += 1
		var ps := PackedScene.new()
		ps.pack(root)
		ResourceSaver.save(ps, path)
		print("rock cluster %s: %d hulls" % [k, n])
	quit()
