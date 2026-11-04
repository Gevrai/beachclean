extends Node
## Headless: godot --headless --path . res://tools/tests/t5_test.tscn  -> prints "T5 PASS" or "T5 FAIL: ..."

func _ready() -> void:
	var beach: Node = load("res://scenes/beach.tscn").instantiate()
	add_child(beach)
	await get_tree().create_timer(0.3).timeout
	var fails: Array[String] = []
	var player: Node = get_tree().get_first_node_in_group("player")
	var shack: Node = get_tree().get_first_node_in_group("shack")
	# sell
	GameState.cents = 0
	GameState.bag.clear()
	GameState.add_to_bag("can")
	GameState.add_to_bag("rope")
	GameState.add_to_bag("cap")
	var sold := GameState.sell_bag()
	if sold != 61 or GameState.cents != 61 or GameState.bag_used() != 0:
		fails.append("sell: sold=%d cents=%d" % [sold, GameState.cents])
	# catalog: space refusal
	GameState.bag.clear()
	GameState.bag_capacity = 10.0
	for i in 3:
		GameState.add_to_bag("hose")  # 9 used
	if GameState.add_to_bag("gbottle") or not GameState.add_to_bag("can") or GameState.bag_used() != 10.0:
		fails.append("space check, used=%s" % GameState.bag_used())
	GameState.bag.clear()
	# buy
	if GameState.cost("bag") != 200 or GameState.cost("arms") != 300:
		fails.append("base cost")
	if GameState.buy("bag"):
		fails.append("bought while unaffordable")
	GameState.cents = 0
	GameState.add_money(1000)
	if not GameState.buy("bag") or GameState.bag_capacity != 15 or GameState.cents != 800:
		fails.append("buy bag: cap=%s cents=%d" % [GameState.bag_capacity, GameState.cents])
	if GameState.cost("bag") != 300:
		fails.append("cost growth %d" % GameState.cost("bag"))
	GameState.buy("arms")
	GameState.buy("sandals")
	if not is_equal_approx(player.reach, 3.25) or not is_equal_approx(player.move_speed, 5.5):
		fails.append("player stats reach=%s speed=%s" % [player.reach, player.move_speed])
	# casting net: 1200 base, three levels (range / radius), not owned at the start
	if GameState.net_range() != 0.0 or GameState.cost("net") != 1200:
		fails.append("net base: range=%s cost=%d" % [GameState.net_range(), GameState.cost("net")])
	GameState.cents = 5000
	GameState.buy("net")
	if GameState.net_range() != 12.0 or GameState.net_radius() != 2.0 or GameState.cents != 3800:
		fails.append("net L1: %s/%s cents=%d" % [GameState.net_range(), GameState.net_radius(), GameState.cents])
	GameState.add_money(5000)
	GameState.buy("net")
	GameState.buy("net")
	if GameState.net_range() != 22.0 or GameState.net_radius() != 4.0 or not GameState.is_maxed("net") or GameState.can_buy("net"):
		fails.append("net L3: %s/%s" % [GameState.net_range(), GameState.net_radius()])
	if GameState.effect_text("net") == "":
		fails.append("net effect text")
	GameState.levels["net"] = 0
	GameState.upgrades_changed.emit()
	# grabber + rake respect capacity
	GameState.add_money(10000)
	GameState.buy("grabber")
	GameState.buy("rake")
	GameState.buy("rake")  # radius 1.2
	GameState.bag.clear()
	GameState.bag_capacity = 10.0
	var cam: Camera3D = player.cam
	var fwd := -cam.global_basis.z
	var base: Vector3 = cam.global_position + fwd * 2.0
	for d in get_tree().get_nodes_in_group("debris"):
		d.remove_from_group("debris")
	var DebrisScript := load("res://scripts/debris.gd")
	var rng := RandomNumberGenerator.new()
	var spawned: Array = []
	for i in 14:  # 14 cans clustered in front of the player
		var d: StaticBody3D = DebrisScript.spawn("can", rng)
		beach.add_child(d)
		d.global_position = base + Vector3(rng.randf_range(-0.3, 0.3), -0.1, rng.randf_range(-0.3, 0.3))
		spawned.append(d)
	var before := get_tree().get_nodes_in_group("debris").size()
	player.grab_tick()
	var left := get_tree().get_nodes_in_group("debris").size()
	if before - left < 2:
		fails.append("rake did not grab neighbours (%d -> %d)" % [before, left])
	if GameState.bag_used() > GameState.bag_capacity:
		fails.append("over capacity %d" % GameState.bag_used())
	for i in 6:
		player.grab_tick()
	if GameState.bag_used() > GameState.bag_capacity:
		fails.append("over capacity after more grabs %d" % GameState.bag_used())
	if GameState.bag_used() != 10.0:
		fails.append("bag should be full (10), is %s" % GameState.bag_used())
	# shack interact: sorts the bag, pays at the end (<= 2 s), opens panel
	GameState.cents = 0
	var want := GameState.bag_value()
	var n: int = shack.sell()
	if n != want or n <= 0 or GameState.cents != 0 or not GameState.bag.is_empty() or shack.panel.is_open:
		fails.append("sell start n=%d want=%d cents=%d open=%s" % [n, want, GameState.cents, shack.panel.is_open])
	await get_tree().create_timer(2.0).timeout
	if GameState.cents != want:
		fails.append("sell paid %d, want %d" % [GameState.cents, want])
	shack._open_panel()
	if not shack.panel.is_open:
		fails.append("shop did not open")
	shack.panel.close()
	player.global_position = shack.global_position + shack.SELL_AT
	shack._player = player
	if shack._zone() != "sell":
		fails.append("zone at bins = " + shack._zone())
	player.global_position = shack.global_position + shack.SHOP_AT
	if shack._zone() != "shop":
		fails.append("zone at counter = " + shack._zone())
	# worst case: a huge bag with all four bins in use still finishes within 2 s
	GameState.bag_capacity = 50.0
	GameState.bag.clear()
	for id in ["can", "pbottle", "gbottle", "cap"]:
		for i in 12:
			GameState.add_to_bag(id)
	GameState.cents = 0
	var t0 := Time.get_ticks_msec()
	var big_n: int = shack.sell()
	while GameState.cents == 0 and Time.get_ticks_msec() - t0 < 4000:
		await get_tree().process_frame
	var took := (Time.get_ticks_msec() - t0) / 1000.0
	if GameState.cents != big_n or took > 2.0:
		fails.append("big sort paid %d/%d in %.2fs" % [GameState.cents, big_n, took])
	print("T5 PASS" if fails.is_empty() else "T5 FAIL: " + "; ".join(fails))
	get_tree().quit()
