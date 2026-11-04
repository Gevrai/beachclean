extends Node
## Headless: godot --headless --path . res://tools/tests/t6_test.tscn  -> prints "T6 PASS" or "T6 FAIL: ..."

func _ready() -> void:
	var beach: Node = load("res://scenes/beach.tscn").instantiate()
	add_child(beach)
	await get_tree().create_timer(0.3).timeout
	var fails: Array[String] = []
	var got: Array[String] = []
	GameState.milestone_reached.connect(func(id): got.append(id))
	GameState.initial_count = 8
	GameState.cleared_count = 0
	GameState.reached.clear()
	for i in 8:
		GameState.register_clear()
	if got != ["crabs", "gulls", "turtle", "hatchlings"]:
		fails.append("milestones got %s" % [got])
	await get_tree().create_timer(2.6).timeout
	if absf(beach.health - 1.0) > 0.01:
		fails.append("health tween ended at %f" % beach.health)
	var w: Node = beach.get_children().filter(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("wildlife.gd"))[0]
	for id in ["crabs", "gulls", "turtle", "hatchlings"]:
		if not w._roots[id].visible:
			fails.append("%s not visible" % id)
	print("T6 PASS" if fails.is_empty() else "T6 FAIL: " + ", ".join(fails))
	get_tree().quit()
