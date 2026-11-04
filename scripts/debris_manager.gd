extends Node
## Scatters the starting debris (instancing the scenes/items prefabs) and washes new pieces in on a tide timer.

const DebrisScript := preload("res://scripts/debris.gd")
const Catalog := preload("res://scripts/catalog.gd")
const CoinScript := preload("res://scripts/loose_change.gd")

var beach: Node  # set by beach.gd before add_child

const INITIAL_COUNT := 340
const TIDE_SECONDS := 90.0
const MAX_ALIVE := 400
const COIN_COUNT := 10  # loose change lying around at the start (not saved; respawns on load)

var _rng := RandomNumberGenerator.new()
var _timer: Timer

func _ready() -> void:
	add_to_group("debris_manager")
	_rng.seed = 2024
	if GameState.loaded_debris is Array:  # restore the saved beach
		for e in GameState.loaded_debris:
			var d: StaticBody3D = DebrisScript.spawn(str(e.get("id", "cap")) if Catalog.ITEMS.has(str(e.get("id", ""))) else "cap", _rng)
			add_child(d)
			d.global_position = Vector3(float(e.x), float(e.y), float(e.z))
		GameState.loaded_debris = null
	else:
		var n := 0
		var tries := 0
		while n < INITIAL_COUNT and tries < 6000:
			tries += 1
			var x := _rng.randf_range(-46.0, 46.0)
			var zs := -1.5 - pow(_rng.randf(), 1.3) * 24.0  # denser near the shore
			if _spawn_at(x, beach.shore_z(x) + zs, false):
				n += 1
		GameState.set_initial_count(n)
	_spawn_bottles()
	for i in COIN_COUNT:
		_spawn_coin(false)
	if OS.get_cmdline_user_args().has("--showcase"):
		_showcase()
	if OS.get_cmdline_user_args().has('--list-debris'):
		for d in get_tree().get_nodes_in_group('debris'):
			print('DEB ', d.id, d.global_position)
	_timer = Timer.new()
	_timer.wait_time = TIDE_SECONDS
	_timer.timeout.connect(tide)
	add_child(_timer)
	_timer.start()

func _spawn_bottles() -> void:
	var spots: Array = preload("res://scripts/notes.gd").SPOTS
	for i in spots.size():
		if GameState.found_notes.has(i):
			continue
		var x: float = spots[i][0]
		var z: float = beach.shore_z(x) - float(spots[i][1])
		var b: StaticBody3D = load(Catalog.BOTTLE_SCENE).instantiate()
		b.setup(i)
		add_child(b)
		b.global_position = Vector3(x, beach.height_at(x, z), z)

## A wave washes a few pieces onto the wet sand; fewer as the beach heals.
func tide() -> void:
	var n := roundi(lerpf(7.0, 2.0, GameState.health()))
	n = mini(n, MAX_ALIVE - get_tree().get_nodes_in_group("debris").size())
	var placed := 0
	var tries := 0
	while placed < n and tries < 200:
		tries += 1
		var x := _rng.randf_range(-44.0, 44.0)
		if _spawn_at(x, beach.shore_z(x) - _rng.randf_range(0.6, 4.0), true):
			placed += 1
	if get_tree().get_nodes_in_group("coin").size() < COIN_COUNT and _rng.randf() < 0.4:
		_spawn_coin(true)  # the sea sometimes brings a coin too

## One coin of loose change on the dry sand.
func _spawn_coin(animate: bool) -> void:
	for i in 40:
		var x := _rng.randf_range(-46.0, 46.0)
		var z: float = beach.shore_z(x) - (_rng.randf_range(0.8, 4.0) if animate else _rng.randf_range(2.0, 26.0))
		var h: float = beach.height_at(x, z)
		var p := Vector3(x, h, z)
		var shack := get_tree().get_first_node_in_group("shack")
		if h < 0.04 or (shack and shack.occupies(p)):
			continue
		var c: StaticBody3D = CoinScript.spawn(Catalog.random_coin(_rng), _rng)
		add_child(c)
		c.global_position = p
		if animate:
			c.scale = Vector3.ONE * 0.01
			c.create_tween().tween_property(c, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return

## Dev (--showcase): one of everything near the default start position (can dead ahead, within reach).
func _showcase() -> void:
	var z0: float = beach.shore_z(0.0) - 9.0
	# [id or cents, x offset (+x = left), z offset ahead]
	var spots := [["cap", 1.7, 1.75], ["straw", 1.1, 1.8], ["flipflop", 0.6, 1.8], ["can", 0.0, 1.85], ["pbottle", -0.65, 1.8],
		["gbottle", -1.5, 1.8], ["bag", 2.4, 3.2], ["bucket", 0.9, 3.3], ["rope", -0.9, 3.3], ["hose", -2.6, 3.2], [25, 0.95, 1.2], [100, -0.9, 1.2]]
	for d in get_tree().get_nodes_in_group("debris"):
		if absf(d.global_position.z - (z0 + 2.4)) < 2.5 and absf(d.global_position.x) < 5.0:
			d.remove_from_group("debris")
			d.queue_free()
	for sp in spots:
		var x: float = sp[1]
		var z: float = z0 + float(sp[2])
		var n: StaticBody3D = DebrisScript.spawn(sp[0], _rng) if sp[0] is String else CoinScript.spawn(sp[0], _rng)
		add_child(n)
		n.global_position = Vector3(x, beach.height_at(x, z), z)

## Cheats: drop n new pieces anywhere on the dry beach.
func scatter(n: int) -> int:
	var placed := 0
	var tries := 0
	n = mini(n, MAX_ALIVE - get_tree().get_nodes_in_group("debris").size())
	while placed < n and tries < 3000:
		tries += 1
		var x := _rng.randf_range(-46.0, 46.0)
		if _spawn_at(x, beach.shore_z(x) - _rng.randf_range(1.5, 25.0), false):
			placed += 1
	return placed

func _spawn_at(x: float, z: float, animate: bool) -> bool:
	var h: float = beach.height_at(x, z)
	if h < 0.04:
		return false  # underwater
	var p := Vector3(x, h, z)
	var shack := get_tree().get_first_node_in_group("shack")
	if shack and shack.occupies(p):
		return false
	for d in get_tree().get_nodes_in_group("debris"):
		if d.global_position.distance_squared_to(p) < 0.8:
			return false
	var d: StaticBody3D = DebrisScript.spawn(Catalog.random_id(_rng), _rng)
	add_child(d)
	d.global_position = p
	if animate:
		d.pop_in()
	return true
