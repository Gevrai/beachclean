extends Node
## Headless: res://tools/tests/t11_test.tscn -- --fresh -> "T11 PASS" / "T11 FAIL: ...".
## Every aimable kind (each debris id, coin, message bottle) must implement the target interface and
## show a hover label when the player aims at it.

const IFACE := ["label_text", "set_highlight", "pick_up", "refuse"]

func _ready() -> void:
	var beach: Node = load("res://scenes/beach.tscn").instantiate()
	add_child(beach)
	await get_tree().create_timer(0.5).timeout
	var fails: Array[String] = []
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		for n in beach.get_children():
			if n.get("cam") != null and n.has_method("_update_target"):
				player = n
	if player == null:
		print("T11 FAIL: no player")
		get_tree().quit()
		return
	var Catalog := preload("res://scripts/catalog.gd")
	var rng := RandomNumberGenerator.new()
	var made: Array = []
	for id in Catalog.ITEMS:
		var d: StaticBody3D = preload("res://scripts/debris.gd").spawn(id, rng)
		made.append([id, d])
	var c: StaticBody3D = preload("res://scripts/loose_change.gd").spawn(25, rng)
	made.append(["coin", c])
	var b: StaticBody3D = load(Catalog.BOTTLE_SCENE).instantiate()
	b.setup(0)
	made.append(["bottle", b])
	var cam: Camera3D = player.cam
	for e in made:
		var n: Node3D = e[1]
		for m in IFACE:
			if not n.has_method(m):
				fails.append("%s lacks %s" % [e[0], m])
		add_child(n)
		n.global_position = cam.global_position - cam.global_basis.z * 1.2 + Vector3.DOWN * 0.08
		await get_tree().physics_frame
		await get_tree().physics_frame
		player._update_target()
		if player.target != n:
			fails.append("aim missed %s" % e[0])
		elif str(n.label_text()).is_empty():
			fails.append("%s empty label" % e[0])
		player.target = null
		n.set_highlight(false)
		n.queue_free()
	print("T11 PASS" if fails.is_empty() else "T11 FAIL: " + ", ".join(fails))
	get_tree().quit()
