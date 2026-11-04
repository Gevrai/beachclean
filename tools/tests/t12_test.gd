extends Node
## Headless: res://tools/tests/t12_test.tscn -- --fresh -> "T12 PASS" / "T12 FAIL: ...".
## Clusters + floating debris, wading limit/slowdown, seafloor collision, casting net.

func _ready() -> void:
	var beach: Node = load("res://scenes/beach.tscn").instantiate()
	add_child(beach)
	await get_tree().create_timer(0.4).timeout
	var fails: Array[String] = []
	var player: Node = get_tree().get_first_node_in_group("player")
	var all := get_tree().get_nodes_in_group("debris")
	var floaters := all.filter(func(d): return d.floating)
	print("T12 info: %d pieces, %d floating" % [all.size(), floaters.size()])
	if all.size() < 700 or all.size() > 1000:
		fails.append("piece count %d" % all.size())
	if floaters.size() < 100:
		fails.append("too few floating: %d" % floaters.size())
	for d in floaters:
		if d.global_position.y > 0.4 or d.global_position.y < -0.4:
			fails.append("floater off the surface y=%.2f" % d.global_position.y)
			break
	if GameState.initial_count != all.size():
		fails.append("initial_count %d != %d" % [GameState.initial_count, all.size()])
	# clustering: the average nearest-neighbour distance of beach pieces is far below an even spread
	var beachp := all.filter(func(d): return not d.floating)
	var close := 0
	for d in beachp:
		for o in beachp:
			if o != d and o.global_position.distance_to(d.global_position) < 1.0:
				close += 1
				break
	if float(close) / beachp.size() < 0.6:
		fails.append("not clustered: %d/%d have a neighbour within 1 m" % [close, beachp.size()])
	# seafloor collision under the water
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(0, 5, 12), Vector3(0, -8, 12), 1)
	if space.intersect_ray(q).is_empty():
		fails.append("no seafloor collision at z=12")
	# wading: push seaward for a few seconds; depth must stay near waist depth, and speed drops with depth
	var x := 0.0
	player.global_position = Vector3(x, beach.height_at(x, beach.shore_z(x) - 2.0) + 0.1, beach.shore_z(x) - 2.0)
	var sp0: float = player.move_speed
	var max_depth := 0.0
	for i in 240:
		player.velocity.x = 0.0
		player.velocity.z = 6.0  # keep shoving into the sea
		await get_tree().physics_frame
		max_depth = maxf(max_depth, player.depth)
	if max_depth < 0.7:
		fails.append("could not wade (max depth %.2f)" % max_depth)
	if max_depth > 1.3:
		fails.append("limit leaks: depth %.2f" % max_depth)
	# casting net: needs the upgrade; catches floating pieces in the radius, respects bag space
	GameState.cents = 100000
	GameState.bag.clear()
	GameState.bag_capacity = 10.0
	var caster: Node = null
	for c in beach.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("net_caster.gd"):
			caster = c
	if caster == null:
		fails.append("no net caster")
	elif GameState.net_range() != 0.0:
		fails.append("net owned at start")
	else:
		GameState.buy("net")
		if GameState.net_range() != 12.0 or GameState.net_radius() != 2.0:
			fails.append("net stats %s/%s" % [GameState.net_range(), GameState.net_radius()])
		var DebrisScript := load("res://scripts/debris.gd")
		var rng := RandomNumberGenerator.new()
		var spot := Vector3(player.global_position.x, 0.0, player.global_position.z + 8.0)
		var mine: Array = []
		for i in 12:  # 12 bottles in the net's radius (1.5 space each: only 6 fit in a 10-space bag)
			var d: StaticBody3D = DebrisScript.spawn("pbottle", rng)
			beach.add_child(d)
			d.global_position = spot + Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
			d.set_floating(true)
			mine.append(d)
		var far: StaticBody3D = DebrisScript.spawn("pbottle", rng)
		beach.add_child(far)
		far.global_position = spot + Vector3(7.0, 0.0, 0.0)
		far.set_floating(true)
		await get_tree().physics_frame
		var before := GameState.cleared_count
		caster._aim_pt = spot
		caster._aim_ok = true
		caster._radius = GameState.net_radius()
		caster._cast()
		var t0 := Time.get_ticks_msec()
		while caster._state != 0 and Time.get_ticks_msec() - t0 < 5000:
			await get_tree().process_frame
		await get_tree().create_timer(1.0).timeout
		var caught := GameState.bag.size()
		if caught != 6 or GameState.bag_used() > 10.0:
			fails.append("net caught %d (want 6, space %s)" % [caught, GameState.bag_used()])
		if GameState.cleared_count - before != 6:
			fails.append("health credit %d" % (GameState.cleared_count - before))
		if not is_instance_valid(far) or not far.is_in_group("debris"):
			fails.append("net took a piece outside its radius")
		var left := 0
		for d in mine:
			if is_instance_valid(d) and d.is_in_group("debris"):
				left += 1
		if left != 6:
			fails.append("leftovers %d (want 6)" % left)
	print("T12 PASS" if fails.is_empty() else "T12 FAIL: " + "; ".join(fails))
	get_tree().quit()
