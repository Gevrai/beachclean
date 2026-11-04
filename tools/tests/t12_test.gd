extends Node
## Headless: res://tools/tests/t12_test.tscn -- --fresh -> "T12 PASS" / "T12 FAIL: ...".
## Collisions (fence, palm, rock, truck, shack, lighthouse block the player; grass does not) and props sit on the ground.

var _beach: Node
var _player: CharacterBody3D
var _fails: Array[String] = []

func _ready() -> void:
	_beach = load("res://scenes/beach.tscn").instantiate()
	add_child(_beach)
	await get_tree().create_timer(0.5).timeout
	_player = get_tree().get_first_node_in_group("player")
	_player.set_physics_process(false)  # we drive it ourselves (no clamp, no keys)
	var bw: Node = _beach.get_node("Boardwalk")
	# fence: from the walk centre sideways, between posts (rope) and at a post
	for d in [9.4, 7.9, 12.0]:
		var sm: Array = bw._sample(d)
		var c: Vector2 = sm[0]
		var nrm := Vector2(-sm[1].y, sm[1].x)
		for s in [-1.0, 1.0]:
			var end: Vector3 = await _walk(Vector3(c.x, 0, c.y), Vector3(nrm.x * s, 0, nrm.y * s), 150)
			var off := (Vector2(end.x, end.z) - c).length()
			if off > 1.5:
				_fails.append("fence d=%.1f side %d walked through (offset %.2f)" % [d, s, off])
	# no fence in the swallowed part: free to step aside
	var sm0: Array = bw._sample(2.0)
	var c0: Vector2 = sm0[0]
	var end0: Vector3 = await _walk(Vector3(c0.x, 0, c0.y), Vector3(-sm0[1].y, 0, sm0[1].x), 100)
	if (Vector2(end0.x, end0.z) - c0).length() < 3.0:
		_fails.append("swallowed end is fenced")
	# along the walk is free
	var a: Vector2 = bw.path_points[1]
	var b: Vector2 = bw.path_points[2]
	var endw: Vector3 = await _walk(Vector3(a.x, 0, a.y), Vector3((b - a).x, 0, (b - a).y), 90)
	if (Vector2(endw.x, endw.z) - a).length() < 5.0:
		_fails.append("walk along the boardwalk is blocked")
	# palms and rocks and lighthouse and truck and shack
	for n in _beach.get_node("Props").get_children():
		var nm := String(n.name)
		if nm.begins_with("Palm"):
			var p: Vector3 = n.global_position
			if absf(p.y - (_beach.height_at(p.x, p.z) - 0.1)) > 0.05:
				_fails.append("%s not on the ground" % nm)
	await _blocked("Palm3", _beach.get_node("Props/Palm3").global_position, Vector3(0, 0, 3), 0.4)
	await _blocked("Palm9", _beach.get_node("Props/Palm9").global_position, Vector3(-3, 0, -2), 0.4)
	await _blocked("Rocks9", _beach.get_node("Props/Rocks9").global_position, Vector3(0, 0, 3), 0.5)
	await _blocked("Rocks7", _beach.get_node("Props/Rocks7").global_position, Vector3(2.5, 0, 0), 0.5)
	await _blocked("Lighthouse", _beach.get_node("Props/Lighthouse").global_position, Vector3(4.5, 0, 0), 1.8)
	var truck: Node3D = _beach.get_node("Props/PickupTruck")
	await _blocked("Truck tailgate", truck.global_position, Vector3(0, 0, 5), 1.9)  # tailgate is at +2.5 from the origin
	await _blocked("Truck side", truck.global_position, Vector3(4, 0, 0), 1.2)
	var shack: Node3D = get_tree().get_first_node_in_group("shack")
	await _blocked("Shack", shack.global_position, Vector3(0, 0, -5), 1.2)
	# grass is walk-through: 4 m across a dense stretch
	var g0 := Vector3(-30, 0, -24)
	var gend: Vector3 = await _walk(g0, Vector3.RIGHT, 50)
	if gend.x - g0.x < 3.0:
		_fails.append("grass blocks the player (%.1f m)" % (gend.x - g0.x))
	print("T12 PASS" if _fails.is_empty() else "T12 FAIL: " + ", ".join(_fails))
	get_tree().quit()

## Walk from `from` (xz, y snapped to the ground) along `dir` at 5 m/s for `frames` physics frames; returns the end point.
func _walk(from: Vector3, dir: Vector3, frames: int) -> Vector3:
	_player.global_position = Vector3(from.x, _beach.height_at(from.x, from.z) + 0.2, from.z)
	_player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	var d := dir.normalized()
	for i in frames:
		_player.velocity = Vector3(d.x * 5.0, -3.0, d.z * 5.0)
		_player.move_and_slide()
		await get_tree().physics_frame
	return _player.global_position

## Start `offset` away from `target` and walk straight at it; must stop at least `min_dist` (xz) away.
func _blocked(label: String, target: Vector3, offset: Vector3, min_dist: float) -> void:
	var end: Vector3 = await _walk(target + offset, -offset, 120)
	var dist := Vector2(end.x - target.x, end.z - target.z).length()
	if dist < min_dist:
		_fails.append("%s: walked through (stopped %.2f m from centre, wanted >= %.1f)" % [label, dist, min_dist])
