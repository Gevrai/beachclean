extends Node3D
## Recycling shack (scenes/shack/shack.tscn: hut, props, SellSpot/ShopSpot markers, 4 Bin instances); this script is behaviour only.
## Two interact spots: the four sorting bins (right of the hut) share one SELL zone (E sorts the bag into them, then pays);
## the counter opens the SHOP panel with E.
## Esc / E close the panel. Group "shack". Instanced by beach.gd with `beach` set before add_child.

const PanelScript := preload("res://scripts/upgrade_panel.gd")
const Catalog := preload("res://scripts/catalog.gd")
const ItemMesh := preload("res://scripts/item_mesh.gd")
const COIN_MAT := preload("res://assets/materials/shack/coin.tres")

var beach: Node
var panel: CanvasLayer

const ZONE_R := 2.0  # radius of each spot; the nearer one wins
const FLY_TIME := 0.24   # one item arcing into its bin
const SORT_BUDGET := 1.5 # the whole sorting sequence stays under this (seconds)
const MAX_FLYERS := 24   # beyond this many items, one flyer stands for several

var _player: Node3D
var _hud: Node
var _last_prompt := "<none>"
var _rng := RandomNumberGenerator.new()
var _bins: Dictionary = {}  # bin id -> {root, lid, top (local Vector3)}
var _sorting := false
var SELL_AT: Vector3  # local: in front of the bins (SellSpot marker)
var SHOP_AT: Vector3  # local: in front of the counter (ShopSpot marker)

func _ready() -> void:
	add_to_group("shack")
	_rng.seed = 99
	var x := 14.0
	var z: float = beach.shore_z(x) - 21.0
	var hmax := -100.0
	for dx in [-2.4, 0.0, 2.4]:
		for dz in [-2.0, 0.0, 2.0]:
			hmax = maxf(hmax, beach.height_at(x + dx, z + dz))
	position = Vector3(x, hmax, z)
	SELL_AT = $SellSpot.position
	SHOP_AT = $ShopSpot.position
	# crate and bins stand on the sand, whatever its slope
	$Crate.position.y = _ground_y($Crate.position)
	for bin in $Bins.get_children():
		bin.position.y = _ground_y(bin.position)
		_bins[bin.bin_id] = {"root": bin, "lid": bin.lid, "top": bin.position + Vector3(0, bin.MOUTH_Y, 0)}
	panel = CanvasLayer.new()
	panel.set_script(PanelScript)
	add_child(panel)
	for a in OS.get_cmdline_user_args():
		if a == "--open-panel":
			get_tree().create_timer(0.5).timeout.connect(_open_panel)
		elif a == "--sort-demo":  # dev: sort whatever is in the bag ~0.4 s before the shot is taken
			get_tree().create_timer(1.55).timeout.connect(sell)

## True if world point p is on / next to the shack (debris keeps out).
func occupies(p: Vector3) -> bool:
	var l := p - global_position
	return l.x > -3.2 and l.x < 6.9 and l.z > -2.6 and l.z < 3.2

# ---------------------------------------------------------------- interaction

func _process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		_hud = get_tree().get_first_node_in_group("hud")
		return
	if _hud == null:
		_hud = get_tree().get_first_node_in_group("hud")
		return
	var prompt := ""
	if not panel.is_open and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		match _zone():
			"sell":
				if GameState.bag_used() > 0:
					prompt = "E — Recycle bag (+%s)" % Catalog.money(GameState.bag_value())
				else:
					prompt = "Bag empty"
			"shop":
				prompt = "E — Upgrades"
	if prompt != _last_prompt:
		_last_prompt = prompt
		_hud.set_prompt(prompt)

## "sell", "shop" or "": the interact spot the player stands in (nearest wins if both).
func _zone() -> String:
	var p := _player.global_position - global_position
	var ds := Vector2(p.x - SELL_AT.x, p.z - SELL_AT.z).length()
	var dh := Vector2(p.x - SHOP_AT.x, p.z - SHOP_AT.z).length()
	if minf(ds, dh) > ZONE_R:
		return ""
	return "sell" if ds < dh else "shop"

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: int = event.keycode
	if panel.is_open:
		if k == KEY_E or k == KEY_ESCAPE:
			_close_panel()
			get_viewport().set_input_as_handled()
		return
	if k != KEY_E or _player == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	match _zone():
		"sell":
			sell()
			get_viewport().set_input_as_handled()
		"shop":
			_open_panel()
			get_viewport().set_input_as_handled()

## Recycle the bag at the bins: sort it into the four bins (animated), then pay. Returns the cents it will pay.
func sell() -> int:
	if _sorting or GameState.bag.is_empty():
		return 0
	var items := GameState.take_bag()
	var total := 0
	var groups: Dictionary = {}  # bin id -> Array of item ids
	for it in items:
		total += int(it.value)
		var b: String = Catalog.ITEMS[it.id].bin
		if not groups.has(b):
			groups[b] = []
		groups[b].append(it.id)
	_sorting = true
	# where the items leave the bag (fixed at the moment of E, so walking away doesn't matter)
	var start := Vector3(SELL_AT.x, 1.0, SELL_AT.z + 0.5)
	if _player:
		var cam: Camera3D = _player.get("cam")
		if cam:
			start = to_local(cam.global_position - cam.global_basis.z * 0.9 - cam.global_basis.y * 0.7)
	# plan the timeline: bins in order, items stream out one after another (interval shrinks with many items)
	var order: Array = []
	for b in Catalog.BIN_ORDER:
		if groups.has(b):
			order.append(b)
	var scale_down := minf(1.0, float(MAX_FLYERS) / float(items.size()))
	var flyers: Dictionary = {}
	var total_fly := 0
	for b in order:
		flyers[b] = maxi(1, roundi(groups[b].size() * scale_down))
		total_fly += flyers[b]
	var u := clampf((SORT_BUDGET - 0.15 * order.size() - 0.5) / float(total_fly), 0.012, 0.09)
	var t := 0.0
	var snd := 0
	var snd_every := maxi(1, ceili(total_fly / 14.0))  # at most ~14 bloobs
	var k := 0
	for b in order:
		_at(t, _lid.bind(b, true))
		var ids: Array = groups[b]
		var n: int = flyers[b]
		var last := t + 0.05
		for j in n:
			var lt := t + 0.05 + j * u
			last = lt
			var has_snd := k % snd_every == 0
			_at(lt, _launch.bind(ids[j * ids.size() / n], b, start, snd if has_snd else -1))
			if has_snd:
				snd += 1
			k += 1
		_at(last + FLY_TIME + 0.02, _lid.bind(b, false))
		t = last + 0.1
	_at(t + FLY_TIME + 0.12, _finish_sort.bind(total))
	return total

func _at(delay: float, cb: Callable) -> void:
	get_tree().create_timer(delay).timeout.connect(cb)

func _finish_sort(total: int) -> void:
	_sorting = false
	GameState.pay(total)
	_coin_burst()

func _lid(b: String, open: bool) -> void:
	var lid: Node3D = _bins[b].lid
	var tw := create_tween()
	tw.tween_property(lid, "rotation:x", deg_to_rad(-112.0) if open else 0.0, 0.1 if open else 0.12) \
		.set_trans(Tween.TRANS_BACK if open else Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## One small flying copy of the item's mesh: arcs from the bag into the bin, shrinking; lands with a bloob (step >= 0).
func _launch(id: String, b: String, from: Vector3, snd: int) -> void:
	var f := ItemMesh.build(id, _rng)
	add_child(f)
	f.position = from
	var to: Vector3 = _bins[b].top
	var spin := Vector3(_rng.randf_range(-4.0, 4.0), _rng.randf_range(-6.0, 6.0), _rng.randf_range(-3.0, 3.0))
	var tw := create_tween()
	tw.tween_method(_fly.bind(f, from, to, spin), 0.0, 1.0, FLY_TIME)
	tw.tween_callback(_land.bind(f, b, snd))

func _fly(p: float, f: Node3D, from: Vector3, to: Vector3, spin: Vector3) -> void:
	f.position = from.lerp(to, p) + Vector3.UP * sin(PI * p) * 0.55
	f.scale = Vector3.ONE * lerpf(2.2, 0.3, p * p)
	f.rotation = spin * p

func _land(f: Node3D, b: String, snd: int) -> void:
	f.queue_free()
	_bump(b)
	if snd >= 0:
		get_node("/root/Sfx").bloob(snd)

func _bump(b: String) -> void:
	var r: Node3D = _bins[b].root
	var tw := create_tween()
	tw.tween_property(r, "scale:y", 0.95, 0.04)
	tw.tween_property(r, "scale:y", 1.0, 0.08)

func _open_panel() -> void:
	panel.open()

func _close_panel() -> void:
	panel.close()

func _coin_burst() -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 16
	p.lifetime = 0.9
	p.direction = Vector3(0, 1, 0.3)
	p.spread = 35.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -10, 0)
	var m := SphereMesh.new()
	m.radius = 0.06
	m.height = 0.12
	m.radial_segments = 8
	m.rings = 4
	m.material = COIN_MAT
	p.mesh = m
	add_child(p)
	p.position = SELL_AT + Vector3(0, 1.3, -0.8)
	p.emitting = true
	get_tree().create_timer(1.6).timeout.connect(p.queue_free)

func _ground_y(local: Vector3) -> float:
	return beach.height_at(global_position.x + local.x, global_position.z + local.z) - global_position.y
