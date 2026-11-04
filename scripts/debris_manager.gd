extends Node
## Scatters the starting debris (instancing the scenes/items prefabs) and washes new pieces in on a tide timer.

const DebrisScript := preload("res://scripts/debris.gd")
const Catalog := preload("res://scripts/catalog.gd")
const CoinScript := preload("res://scripts/loose_change.gd")

var beach: Node  # set by beach.gd before add_child

const INITIAL_COUNT := 4400       # target total at the start (beach + floating); the real count is whatever got placed
const FLOAT_NEAR := 200           # floating pieces within waist-deep reach (shoreline .. ~6.5 m out)
const FLOAT_FAR := 320           # floating pieces further out (need the casting net)
const FLOAT_MAX_DIST := 25.0      # m from the shoreline
const WRACK_COUNT := 1250         # dense band along the high-tide mark
const CLUSTER_COUNT := 260        # small clusters (3-12 pieces) on the open sand
const DUNE_FOOT_CLUSTERS := 55   # piles where the sand meets the dune grass
const LONER_COUNT := 300
const TIDE_SECONDS := 90.0
const TIDE_MAX := 36.0            # pieces washed in per tide at health 0, falling to TIDE_MIN at health 1
const TIDE_MIN := 12.0
const MAX_ALIVE := 4600
const COIN_COUNT := 10  # loose change lying around at the start (not saved; respawns on load)
const GAP := 0.3        # min distance between two pieces (m)

## Spawn odds per place (ids from Catalog.ITEMS). Wrack line: small stuff and ropes/nets the sea left behind.
const WRACK_WEIGHTS := {"cap": 22.0, "straw": 20.0, "bag": 18.0, "can": 8.0, "pbottle": 8.0, "flipflop": 6.0, "gbottle": 3.0, "bucket": 1.0, "rope": 2.0, "hose": 3.0}
## Light things that float (the sea band): no cans, no hose.
const FLOAT_WEIGHTS := {"cap": 14.0, "straw": 8.0, "bag": 22.0, "pbottle": 18.0, "flipflop": 12.0, "gbottle": 8.0, "bucket": 8.0, "rope": 10.0}

var _rng := RandomNumberGenerator.new()
var _timer: Timer
var _grid: Dictionary = {}       # Vector2i cell -> Array[Vector2] of placed pieces (rebuilt per placement run)
var _blockers: Array[Vector3] = []  # x, z, radius: rocks and palm trunks

func _ready() -> void:
	add_to_group("debris_manager")
	_rng.seed = 2024
	_find_blockers()
	if GameState.loaded_debris is Array:  # restore the saved beach
		for e in GameState.loaded_debris:
			var d: StaticBody3D = DebrisScript.spawn(str(e.get("id", "cap")) if Catalog.ITEMS.has(str(e.get("id", ""))) else "cap", _rng)
			add_child(d)
			d.global_position = Vector3(float(e.x), float(e.y), float(e.z))
			if beach.height_at(d.global_position.x, d.global_position.z) < -0.1:
				d.set_floating(true)
		GameState.loaded_debris = null
	else:
		GameState.set_initial_count(_scatter_initial())
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

# ---------------------------------------------------------------- natural placement

func _find_blockers() -> void:
	_blockers.clear()
	var props := beach.get_node_or_null("Props")
	if props == null:
		return
	for c in props.get_children():
		if c is Node3D and (c.name.begins_with("Rocks") or c.name.begins_with("LighthouseRocks")):
			_blockers.append(Vector3(c.position.x, c.position.z, 2.4))
		elif c is Node3D and c.name.begins_with("Palm"):
			_blockers.append(Vector3(c.position.x, c.position.z, 0.9))

func _scatter_initial() -> int:
	_grid_build()
	var n := 0
	n += _wrack_line(WRACK_COUNT, false)
	for i in CLUSTER_COUNT:
		var x := _rng.randf_range(-46.0, 46.0)
		var zs := -(2.0 + pow(_rng.randf(), 1.15) * 13.0)  # between the wrack line and the dune foot, more near the sea
		n += _cluster(Vector2(x, beach.shore_z(x) + zs), 3 + int(pow(_rng.randf(), 1.5) * 13.0), false)
	for i in DUNE_FOOT_CLUSTERS:  # the sand meets the dune grass about 13-16.5 m behind the shoreline
		var x := _rng.randf_range(-46.0, 46.0)
		n += _cluster(Vector2(x, beach.shore_z(x) - _rng.randf_range(13.0, 16.2)), 5 + int(_rng.randf() * 9.0), false)
	n += _rock_piles()
	n += _loners(LONER_COUNT)
	n += _floating_all()
	return n

## A wavy, gappy band of small mixed debris along the high-tide mark (~3.4 m behind the shoreline), n pieces or fewer.
func _wrack_line(n: int, animate: bool) -> int:
	var placed := 0
	var tries := 0
	while placed < n and tries < n * 12:
		tries += 1
		var x := _rng.randf_range(-46.0, 46.0)
		var a := sin(x * 0.23 + 1.3) * 0.6 + sin(x * 0.071 + 0.4) * 0.6 + sin(x * 0.61) * 0.2
		if _rng.randf() > smoothstep(-0.5, 0.35, a):
			continue  # a gap in the line
		var line_z: float = beach.shore_z(x) - (3.4 + 1.0 * sin(x * 0.19 + 0.5) + 0.6 * sin(x * 0.47 + 2.0))
		placed += _cluster(Vector2(x, line_z + _gauss() * 0.45), 1 + int(_rng.randf() * 3.0), animate, WRACK_WEIGHTS, 0.3)
	return placed

## Piles of litter around the rocks standing on dry sand.
func _rock_piles() -> int:
	var placed := 0
	var props := beach.get_node_or_null("Props")
	if props == null:
		return 0
	for c in props.get_children():
		if c is Node3D and c.name.begins_with("Rocks") and beach.height_at(c.position.x, c.position.z) > 0.0 and c.position.z > beach.shore_z(c.position.x) - 17.0:
			for k in 6:  # a few heaps around each rock
				var ang := _rng.randf() * TAU
				var r := 2.3 + _rng.randf() * 0.8
				placed += _cluster(Vector2(c.position.x, c.position.z) + Vector2(cos(ang), sin(ang)) * r, 3 + int(_rng.randf() * 4.0), false, WRACK_WEIGHTS, 0.5)
	return placed

func _loners(n: int) -> int:
	var placed := 0
	var tries := 0
	while placed < n and tries < n * 30:
		tries += 1
		var x := _rng.randf_range(-46.0, 46.0)
		var zs := -1.5 - pow(_rng.randf(), 1.3) * 24.0
		if _spawn_at(x, beach.shore_z(x) + zs, false, Catalog.random_id(_rng)):
			placed += 1
	return placed

## Floating pieces in drifting groups: FLOAT_NEAR within waist-deep reach, FLOAT_FAR out to FLOAT_MAX_DIST.
func _floating_all() -> int:
	var placed := 0
	var near := 0
	var tries := 0
	while near < FLOAT_NEAR and tries < 1200:
		tries += 1
		var x := _rng.randf_range(-44.0, 44.0)
		near += _float_cluster(x, _rng.randf_range(1.0, 6.0), 1 + int(_rng.randf() * 4.0), false)
	var far := 0
	tries = 0
	while far < FLOAT_FAR and tries < 1800:
		tries += 1
		var x := _rng.randf_range(-44.0, 44.0)
		far += _float_cluster(x, 7.5 + pow(_rng.randf(), 0.8) * (FLOAT_MAX_DIST - 7.5), 1 + int(_rng.randf() * 7.0), false)
	return placed + near + far

## A group of `n` floating pieces around `dist` metres out from the shoreline at x.
func _float_cluster(x: float, dist: float, n: int, animate: bool) -> int:
	var c := Vector2(x, beach.shore_z(x) + dist)
	var placed := 0
	var sigma := 0.4 + n * 0.15
	for i in n * 3:
		if placed >= n:
			break
		var p := c + Vector2(_gauss(), _gauss()) * sigma
		if absf(p.x) > 48.0 or p.y - beach.shore_z(p.x) > FLOAT_MAX_DIST + 1.0:
			continue
		if beach.height_at(p.x, p.y) > -0.15 or _blocked(p) or not _free(p):
			continue
		var d: StaticBody3D = DebrisScript.spawn(_weighted(FLOAT_WEIGHTS), _rng)
		add_child(d)
		d.global_position = Vector3(p.x, 0.0, p.y)
		d.set_floating(true)
		if animate:
			d.pop_in()
		_grid_add(p)
		placed += 1
	return placed

## Gaussian cluster of `n` pieces around `c` (x, z) on dry sand. Mixed items. Returns how many were placed.
func _cluster(c: Vector2, n: int, animate: bool, weights: Dictionary = {}, sigma_scale := 1.0) -> int:
	var sigma := (0.45 + n * 0.07) * sigma_scale
	var placed := 0
	for i in n * 4:
		if placed >= n:
			break
		var p := c + Vector2(_gauss(), _gauss()) * sigma
		var id := _weighted(weights) if not weights.is_empty() else Catalog.random_id(_rng)  # mixed: mostly small stuff, the odd big item
		if _spawn_at(p.x, p.y, animate, id):
			placed += 1
	return placed

func _gauss() -> float:
	return (_rng.randf() + _rng.randf() + _rng.randf() + _rng.randf() - 2.0) * 1.2  # approx. N(0, ~0.8) clamped to +-2.4

func _weighted(w: Dictionary) -> String:
	var total := 0.0
	for k in w:
		total += float(w[k])
	var r := _rng.randf() * total
	for k in w:
		r -= float(w[k])
		if r < 0.0:
			return k
	return "cap"

func _blocked(p: Vector2) -> bool:
	for b in _blockers:
		if Vector2(b.x, b.y).distance_squared_to(p) < b.z * b.z:
			return true
	return false

func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / 1.0), floori(p.y / 1.0))

func _grid_build() -> void:
	_grid.clear()
	for d in get_tree().get_nodes_in_group("debris"):
		_grid_add(Vector2(d.global_position.x, d.global_position.z))

func _grid_add(p: Vector2) -> void:
	var k := _cell(p)
	if not _grid.has(k):
		_grid[k] = []
	_grid[k].append(p)

func _free(p: Vector2) -> bool:
	var c := _cell(p)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var l = _grid.get(Vector2i(c.x + dx, c.y + dz))
			if l:
				for q in l:
					if q.distance_squared_to(p) < GAP * GAP:
						return false
	return true

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

## A wave washes a few pieces onto the wet sand (as clusters) and nudges some into the shallows; fewer as the beach heals.
func tide() -> void:
	_grid_build()
	var room := MAX_ALIVE - get_tree().get_nodes_in_group("debris").size()
	var n := mini(roundi(lerpf(TIDE_MAX, TIDE_MIN, GameState.health())), room)
	var placed := 0
	var tries := 0
	while placed < n and tries < 90:
		tries += 1
		var x := _rng.randf_range(-44.0, 44.0)
		var k := mini(2 + _rng.randi() % 4, n - placed)
		placed += _cluster(Vector2(x, beach.shore_z(x) - _rng.randf_range(0.8, 3.5)), k, true, WRACK_WEIGHTS, 0.6)
	if room - placed > 2:
		var x := _rng.randf_range(-44.0, 44.0)
		_float_cluster(x, _rng.randf_range(1.5, 6.0), 2, true)  # drifted in with the tide
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
		if h < 0.04 or (shack and shack.occupies(p)) or _in_grass(p):
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

## Cheats: drop n new pieces on the dry beach, in little clusters.
func scatter(n: int) -> int:
	_grid_build()
	n = mini(n, MAX_ALIVE - get_tree().get_nodes_in_group("debris").size())
	var placed := 0
	var tries := 0
	while placed < n and tries < 400:
		tries += 1
		var x := _rng.randf_range(-46.0, 46.0)
		placed += _cluster(Vector2(x, beach.shore_z(x) - _rng.randf_range(1.5, 15.0)), mini(2 + _rng.randi() % 5, n - placed), false)
	return placed

## True on the boardwalk or in the dense dune grass (more than 17 m behind the shoreline), where debris would be hard to see.
func _in_grass(p: Vector3) -> bool:
	if p.z < beach.shore_z(p.x) - 17.0:
		return true
	var bw := beach.get_node_or_null("Boardwalk")
	return bw != null and bw.near(p, 0.5)

func _spawn_at(x: float, z: float, animate: bool, id: String) -> bool:
	if absf(x) > 48.0:
		return false
	var h: float = beach.height_at(x, z)
	if h < 0.04:
		return false  # underwater
	var p := Vector3(x, h, z)
	var shack := get_tree().get_first_node_in_group("shack")
	if (shack and shack.occupies(p)) or _in_grass(p) or _blocked(Vector2(x, z)) or not _free(Vector2(x, z)):
		return false
	var d: StaticBody3D = DebrisScript.spawn(id, _rng)
	add_child(d)
	d.global_position = p
	_grid_add(Vector2(x, z))
	if animate:
		d.pop_in()
	return true
