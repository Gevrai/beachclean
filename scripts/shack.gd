extends Node3D
## Recycling shack: stylized wooden hut (primitives) near the dunes, facing the sea (+Z).
## Two interact spots: the four sorting bins (right of the hut) share one SELL zone (E sorts the bag into them, then pays);
## the counter opens the SHOP panel with E.
## Esc / E close the panel. Group "shack". Created by beach.gd with `beach` set.

var PanelScene: PackedScene = load("res://scenes/ui/upgrade_panel.tscn")
const Catalog := preload("res://scripts/catalog.gd")
const ItemMesh := preload("res://scripts/item_mesh.gd")

var beach: Node
var panel: CanvasLayer

const W := 4.2  # x extent
const D := 3.6  # z extent
const WALL_H := 2.8
const DECK := 0.25
const ZONE_R := 2.0  # radius of each spot; the nearer one wins
const SELL_AT := Vector3(4.55, 0, 2.7)   # local: in front of the bins
const BIN_X0 := 3.1      # local x of the first bin; bins are BIN_DX apart
const BIN_DX := 0.95
const FLY_TIME := 0.24   # one item arcing into its bin
const SORT_BUDGET := 1.5 # the whole sorting sequence stays under this (seconds)
const MAX_FLYERS := 24   # beyond this many items, one flyer stands for several
const SHOP_AT := Vector3(0, 0, 2.7)      # local: in front of the counter

var _player: Node3D
var _hud: Node
var _last_prompt := "<none>"
var _mats: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _bins: Dictionary = {}  # bin id -> {root, lid, top (local Vector3)}
var _sorting := false

func _ready() -> void:
	add_to_group("shack")
	_rng.seed = 99
	var x := 14.0
	var z: float = beach.shore_z(x) - 21.0
	var hmax := -100.0
	var hmin := 100.0
	for dx in [-2.4, 0.0, 2.4]:
		for dz in [-2.0, 0.0, 2.0]:
			var h: float = beach.height_at(x + dx, z + dz)
			hmax = maxf(hmax, h)
			hmin = minf(hmin, h)
	position = Vector3(x, hmax, z)
	_build(hmax - hmin)
	panel = PanelScene.instantiate()
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
	m.material = _mat(Color(1.0, 0.82, 0.2), 0.3, 1.5)
	p.mesh = m
	add_child(p)
	p.position = Vector3(SELL_AT.x, 1.3, SELL_AT.z - 0.8)
	p.emitting = true
	get_tree().create_timer(1.6).timeout.connect(p.queue_free)

# ---------------------------------------------------------------- model

func _mat(c: Color, rough := 0.85, glow := 0.0) -> StandardMaterial3D:
	var key := "%s%s%s" % [c.to_html(), rough, glow]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = glow
		_mats[key] = m
	return _mats[key]

func _box(size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

func _cyl(r_top: float, r_bot: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = 16
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi

func _wood() -> StandardMaterial3D:
	var c := Color(0.86, 0.62, 0.38).lerp(Color(0.95, 0.78, 0.52), _rng.randf())
	return _mat(c)

## Vertical boards (0.4 pitch) filling a rectangle of a wall.
## axis "x": wall runs along x at depth z0 (normal ±z); axis "z": runs along z at x0 (normal ±x).
func _boards(axis: String, a0: float, a1: float, y0: float, y1: float, fixed: float) -> void:
	var n := maxi(1, roundi((a1 - a0) / 0.4))
	var pitch := (a1 - a0) / n
	for i in n:
		var c := a0 + pitch * (i + 0.5)
		var sz := Vector3(pitch * 0.92, y1 - y0, 0.1)
		var pos := Vector3(c, (y0 + y1) * 0.5, fixed)
		if axis == "z":
			sz = Vector3(0.1, y1 - y0, pitch * 0.92)
			pos = Vector3(fixed, (y0 + y1) * 0.5, c)
		_box(sz, pos, _wood())

func _build(slope: float) -> void:
	var hw := W * 0.5
	var hd := D * 0.5
	var dark := _mat(Color(0.42, 0.26, 0.16))
	var found := _mat(Color(0.6, 0.4, 0.25))
	var white := _mat(Color(0.97, 0.94, 0.88), 0.7)
	var teal := _mat(Color(0.14, 0.58, 0.6), 0.6)
	var coral := _mat(Color(0.9, 0.3, 0.26), 0.6)
	var cream := _mat(Color(0.95, 0.9, 0.78), 0.7)
	# foundation (goes down into the sand so it never floats on a slope)
	var fh := slope + 0.9 + DECK
	_box(Vector3(W + 0.4, fh, D + 0.4), Vector3(0, DECK - fh * 0.5, 0), found)
	_box(Vector3(W + 0.6, 0.12, D + 0.6), Vector3(0, DECK - 0.06, 0), _mat(Color(0.7, 0.48, 0.3)))
	# core + boards
	_box(Vector3(W - 0.1, WALL_H - DECK, D - 0.1), Vector3(0, (WALL_H + DECK) * 0.5, 0), dark)
	_boards("x", -hw, hw, DECK, 1.2, hd)          # front: lower
	_boards("x", -hw, -1.2, 1.2, 2.0, hd)         # front: beside the window
	_boards("x", 1.2, hw, 1.2, 2.0, hd)
	_boards("x", -hw, hw, 2.0, WALL_H, hd)        # front: sign band
	_boards("x", -hw, hw, DECK, WALL_H, -hd)      # back
	_boards("z", -hd, hd, DECK, WALL_H, -hw)      # sides
	_boards("z", -hd, hd, DECK, WALL_H, hw)
	# corner posts
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(Vector3(0.18, WALL_H - DECK + 0.05, 0.18), Vector3(sx * (hw + 0.02), (WALL_H + DECK) * 0.5, sz * (hd + 0.02)), white)
	# window: glowing interior, frame, shutters
	_box(Vector3(2.4, 0.8, 0.02), Vector3(0, 1.6, hd - 0.04), _mat(Color(1.0, 0.7, 0.38), 0.6, 0.7))
	_box(Vector3(2.64, 0.12, 0.16), Vector3(0, 2.02, hd + 0.02), white)
	_box(Vector3(2.64, 0.12, 0.16), Vector3(0, 1.2, hd + 0.02), white)
	for sx in [-1, 1]:
		_box(Vector3(0.12, 0.92, 0.16), Vector3(sx * 1.26, 1.6, hd + 0.02), white)
		_box(Vector3(0.5, 0.9, 0.06), Vector3(sx * 1.57, 1.6, hd + 0.08), teal)  # shutters
	# counter
	_box(Vector3(2.9, 0.1, 0.75), Vector3(0, 1.22, hd + 0.35), _mat(Color(0.95, 0.78, 0.5), 0.6))
	for sx in [-1, 1]:
		_box(Vector3(0.1, 0.35, 0.1), Vector3(sx * 1.3, 1.0, hd + 0.62), dark)
	# awning (striped)
	for i in 8:
		var sx := -1.4 + 0.4 * (i + 0.5)
		var m := coral if i % 2 == 0 else cream
		var aw := _box(Vector3(0.4, 0.06, 1.0), Vector3(sx, 2.0, hd + 0.5), m, Vector3(deg_to_rad(18.0), 0, 0))
		aw.position.y = 2.0 - 0.15
		aw.position.z = hd + 0.52
	# sign
	_box(Vector3(3.3, 0.56, 0.1), Vector3(0, 2.46, hd + 0.1), teal)
	_box(Vector3(3.4, 0.66, 0.06), Vector3(0, 2.46, hd + 0.07), white)
	var lb := Label3D.new()
	lb.text = "RECYCLING"
	lb.font_size = 120
	lb.pixel_size = 0.0042
	lb.outline_size = 0
	lb.modulate = Color(1, 0.98, 0.9)
	lb.shaded = false
	lb.position = Vector3(0, 2.46, hd + 0.16)
	add_child(lb)
	# gable roof (ridge along x): two slabs + gable ends
	var eave := 2.2
	var rise := 1.3
	var len := sqrt(eave * eave + rise * rise)
	var ang := atan2(rise, eave)
	for s in [-1, 1]:
		_box(Vector3(W + 0.9, 0.14, len + 0.1), Vector3(0, WALL_H + rise * 0.5 + 0.07, s * eave * 0.5), teal, Vector3(s * ang, 0, 0))
	_box(Vector3(W + 1.0, 0.16, 0.22), Vector3(0, WALL_H + rise + 0.1, 0), white)  # ridge cap
	for s in [-1, 1]:
		var pm := MeshInstance3D.new()
		var pr := PrismMesh.new()
		pr.size = Vector3(eave * 2.0, rise, 0.12)
		pm.mesh = pr
		pm.material_override = _wood()
		pm.rotation.y = PI * 0.5
		pm.position = Vector3(s * (hw + 0.02), WALL_H + rise * 0.5, 0)
		add_child(pm)
	# four sorting bins in a row right of the hut
	for i in Catalog.BIN_ORDER.size():
		_bin(Catalog.BIN_ORDER[i], Vector3(BIN_X0 + i * BIN_DX, 0, hd - 0.1))
	# crate with bottles + surfboard leaning on the left wall
	var cp := Vector3(-hw - 1.0, 0, hd - 0.2)
	var cy := _ground_y(cp)
	_box(Vector3(0.9, 0.55, 0.7), Vector3(cp.x, cy + 0.27, cp.z), _mat(Color(0.8, 0.58, 0.34)))
	for j in 3:
		var b := _cyl(0.07, 0.07, 0.34, Vector3(cp.x - 0.25 + j * 0.25, cy + 0.72, cp.z), _mat([Color(0.3, 0.8, 0.5), Color(0.5, 0.8, 0.95), Color(0.95, 0.6, 0.3)][j], 0.25, 0.3))
		b.rotation.z = (j - 1) * 0.12
	var sb := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.26
	cap.height = 2.1
	sb.mesh = cap
	sb.material_override = _mat(Color(0.98, 0.9, 0.5), 0.4)
	sb.scale = Vector3(1.0, 1.0, 0.18)
	sb.position = Vector3(-hw - 0.12, DECK + 1.0, -0.4)
	sb.rotation = Vector3(0, 0, deg_to_rad(-8))
	add_child(sb)
	var stripe := _box(Vector3(0.1, 1.5, 0.05), Vector3(-hw - 0.13, DECK + 1.02, -0.4), coral)
	stripe.rotation.z = deg_to_rad(-8)
	# warm light from the window
	var ol := OmniLight3D.new()
	ol.light_color = Color(1.0, 0.75, 0.45)
	ol.light_energy = 0.7
	ol.omni_range = 6.0
	ol.position = Vector3(0, 1.7, hd + 1.0)
	add_child(ol)
	# collision (shack body only)
	var sbody := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(W + 0.6, 3.5, D + 0.6)
	cs.shape = bs
	sbody.position = Vector3(0, 1.0, 0)
	sbody.add_child(cs)
	add_child(sbody)

func _ground_y(local: Vector3) -> float:
	return beach.height_at(global_position.x + local.x, global_position.z + local.z) - global_position.y

## One sorting bin: coloured box with a swinging lid, dark mouth, and a cream plate with an icon + name.
func _bin(id: String, at: Vector3) -> void:
	var def: Dictionary = Catalog.BINS[id]
	var col: Color = def.color
	var gy := _ground_y(at)
	const BW := 0.74
	const BD := 0.7
	const BH := 0.95
	var root := Node3D.new()
	root.position = Vector3(at.x, gy, at.z)
	add_child(root)
	_box(Vector3(BW, BH + 0.05, BD), Vector3(0, BH * 0.5 - 0.025, 0), _mat(col, 0.45, 0.1), Vector3.ZERO, root)
	_box(Vector3(BW + 0.04, 0.08, BD + 0.04), Vector3(0, 0.04, 0), _mat(col.darkened(0.3), 0.5), Vector3.ZERO, root)
	_box(Vector3(BW - 0.12, 0.012, BD - 0.14), Vector3(0, BH + 0.003, 0), _mat(Color(0.1, 0.08, 0.08), 0.9), Vector3.ZERO, root)  # mouth
	var plate := _box(Vector3(0.58, 0.5, 0.02), Vector3(0, 0.5, BD * 0.5 + 0.005), _mat(Color(0.98, 0.95, 0.86), 0.7), Vector3.ZERO, root)
	plate.name = "Plate"
	var icon := ItemMesh.build(def.icon, _rng, true)
	icon.position = Vector3(0, 0.6, BD * 0.5 + 0.09)
	icon.scale = Vector3.ONE * float(def.icon_scale)
	root.add_child(icon)
	var lb := Label3D.new()
	lb.text = def.name
	lb.font_size = 30
	lb.pixel_size = 0.0042
	lb.outline_size = 0
	lb.modulate = col.darkened(0.45)
	lb.shaded = false
	lb.position = Vector3(0, 0.31, BD * 0.5 + 0.025)
	root.add_child(lb)
	# lid: pivot on the back top edge, swings up and back
	var lid := Node3D.new()
	lid.position = Vector3(0, BH + 0.01, -BD * 0.5 - 0.02)
	root.add_child(lid)
	_box(Vector3(BW + 0.08, 0.08, BD + 0.1), Vector3(0, 0.04, (BD + 0.06) * 0.5), _mat(col.darkened(0.2), 0.45), Vector3.ZERO, lid)
	_box(Vector3(0.22, 0.05, 0.05), Vector3(0, 0.1, BD + 0.04), _mat(col.lightened(0.25), 0.4), Vector3.ZERO, lid)
	_bins[id] = {"root": root, "lid": lid, "top": Vector3(at.x, gy + BH + 0.02, at.z)}
