extends Node
## Headless: godot --headless --path . res://tools/tests/t7_test.tscn -> "T7 PASS" / "T7 FAIL: ..."

func _ready() -> void:
	var G := GameState
	G.save_path = "user://t7_test.json"
	G.no_save = false
	var rng := RandomNumberGenerator.new()
	for i in 3:
		var d := StaticBody3D.new()
		d.set_script(preload("res://scripts/debris.gd"))
		d.setup(["cap", "can", "rope"][i], rng)
		add_child(d)
		d.global_position = Vector3(i * 2.0, 0.5, -3.0 - i)
	G.cents = 77
	G.bag.clear()
	G.add_to_bag("can")
	G.add_to_bag("hose")
	G.levels["bag"] = 2
	G.levels["rake"] = 1
	G.cleared_count = 12
	G.initial_count = 40
	G.reached.assign(["crabs"])
	G.found_notes.assign([1, 4])
	G.save_game()
	var before := JSON.stringify(G.to_dict())
	G.cents = 0
	G.bag.clear()
	G.levels["bag"] = 0
	G.levels["rake"] = 0
	G.cleared_count = 0
	G.reached.clear()
	G.found_notes.clear()
	var ok := G.load_game()
	var deb: Array = G.loaded_debris
	var after_d := G.to_dict()
	var fails: Array[String] = []
	if not ok: fails.append("load failed")
	if G.bag_capacity != 20.0: fails.append("capacity %s" % G.bag_capacity)
	if G.bag.size() != 2 or G.bag_used() != 4.0 or G.cents != 77: fails.append("bag/cents restore")
	if deb == null or deb.size() != 3: fails.append("debris restore")
	after_d["debris"] = deb
	var b: Dictionary = JSON.parse_string(before)
	b["debris"] = deb
	if JSON.stringify(JSON.parse_string(JSON.stringify(after_d))) != JSON.stringify(JSON.parse_string(JSON.stringify(b))):
		fails.append("state differs")
	# corrupt file -> fresh
	FileAccess.open(G.save_path, FileAccess.WRITE).store_string("{nope")
	if G.load_game(): fails.append("corrupt accepted")
	DirAccess.remove_absolute(G.save_path)
	print("T7 PASS" if fails.is_empty() else "T7 FAIL: " + ", ".join(fails))
	get_tree().quit()
