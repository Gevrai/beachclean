extends Node3D
## Ambient animals that return at health milestones (see GameState.MILESTONES). No AI, no collision:
## simple looping animation driven from _process. Built from primitives. Local +Z is every model's front.

var beach: Node  # set by beach.gd before add_child

static var _mats: Dictionary = {}

var _t := 0.0
var _rng := RandomNumberGenerator.new()
## per-group "appear" factor 0..1 (scale-in); a group with 0 is hidden and not updated
var _ap := {"crabs": 0.0, "gulls": 0.0, "turtle": 0.0, "hatchlings": 0.0}
var _roots := {}

var _crabs: Array[Dictionary] = []
var _gulls: Array[Dictionary] = []
var _turtle: Dictionary = {}
var _hatch: Array[Dictionary] = []
var _nest := Vector2.ZERO

func _ready() -> void:
	_rng.seed = 99
	for id in _ap:
		var r := Node3D.new()
		r.visible = false
		add_child(r)
		_roots[id] = r
	_build_crabs()
	_build_gulls()
	_build_turtle()
	_build_hatchlings()
	# reflect the current health on load (no tween, no toast)
	var h: float = maxf(GameState.health(), float(beach.health))
	for m in GameState.MILESTONES:
		if h >= float(m.at) - 0.0001:
			_set_ap(1.0, m.id)
	GameState.milestone_reached.connect(_on_milestone)

func _on_milestone(id: String) -> void:
	create_tween().tween_method(_set_ap.bind(id), 0.0, 1.0, 1.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _set_ap(v: float, id: String) -> void:
	_ap[id] = v
	_roots[id].visible = v > 0.001

# ---------------------------------------------------------------- helpers

static func _mat(c: Color, rough := 0.55) -> StandardMaterial3D:
	var key := "%s%s" % [c.to_html(), rough]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		_mats[key] = m
	return _mats[key]

func _blob(parent: Node, c: Color, pos: Vector3, size: Vector3, rough := 0.55) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 16
	s.rings = 8
	mi.mesh = s
	mi.material_override = _mat(c, rough)
	mi.position = pos
	mi.scale = size
	parent.add_child(mi)
	return mi

## Cone pointing along local +Z.
func _cone(parent: Node, c: Color, pos: Vector3, radius: float, length: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = radius
	cm.height = length
	cm.radial_segments = 8
	mi.mesh = cm
	mi.material_override = _mat(c)
	mi.rotation.x = PI / 2.0
	mi.position = pos
	parent.add_child(mi)
	return mi

func _limb(parent: Node, c: Color, pos: Vector3, len: float, thick: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = thick
	cm.height = len
	cm.radial_segments = 8
	cm.rings = 2
	mi.mesh = cm
	mi.material_override = _mat(c)
	mi.rotation.z = PI / 2.0
	mi.position.x = signf(pos.x) * len * 0.5
	pivot.add_child(mi)
	return pivot

func _eye(parent: Node, pos: Vector3, r: float) -> void:
	_blob(parent, Color(0.06, 0.05, 0.05), pos, Vector3.ONE * r, 0.2)
	_blob(parent, Color.WHITE, pos + Vector3(r * 0.2, r * 0.25, r * 0.38), Vector3.ONE * r * 0.35, 0.2)

func _ground(x: float, z: float) -> float:
	return beach.height_at(x, z)

# ---------------------------------------------------------------- crabs (25%)

func _build_crabs() -> void:
	var red := Color(0.95, 0.32, 0.14)
	var dark := Color(0.78, 0.2, 0.1)
	for i in 5:
		var root := Node3D.new()
		root.scale = Vector3.ONE * 0.0
		_roots["crabs"].add_child(root)
		var s := _rng.randf_range(1.0, 1.3)
		_blob(root, red, Vector3(0, 0.13, 0), Vector3(0.42, 0.22, 0.32))
		_blob(root, Color(1.0, 0.6, 0.4), Vector3(0, 0.1, 0.02), Vector3(0.34, 0.12, 0.28))
		var legs: Array[Node3D] = []
		for side in [-1.0, 1.0]:
			for j in 3:
				legs.append(_limb(root, dark, Vector3(side * 0.17, 0.08, -0.08 + j * 0.08), 0.18, 0.018))
		var claws: Array[Node3D] = []
		for side in [-1.0, 1.0]:
			var arm := Node3D.new()
			arm.position = Vector3(side * 0.2, 0.15, 0.12)
			root.add_child(arm)
			_blob(arm, dark, Vector3(side * 0.06, 0.0, 0.07), Vector3(0.07, 0.07, 0.16))
			_blob(arm, red, Vector3(side * 0.1, 0.03, 0.17), Vector3(0.17, 0.12, 0.15))
			_blob(arm, dark, Vector3(side * 0.07, 0.04, 0.26), Vector3(0.07, 0.07, 0.09))
			claws.append(arm)
		for side in [-1.0, 1.0]:
			var stalk := Node3D.new()
			stalk.position = Vector3(side * 0.07, 0.22, 0.1)
			root.add_child(stalk)
			_blob(stalk, dark, Vector3(0, 0.02, 0), Vector3(0.025, 0.07, 0.025))
			_eye(stalk, Vector3(0, 0.07, 0.015), 0.085)
		_crabs.append({
			"node": root, "legs": legs, "claws": claws, "s": s,
			"cx": _rng.randf_range(-20.0, 20.0), "amp": _rng.randf_range(1.2, 3.0),
			"w": _rng.randf_range(0.35, 0.6), "ph": _rng.randf_range(0.0, TAU),
			"off": _rng.randf_range(0.5, 2.2), "px": 0.0, "lp": 0.0,
		})

func _update_crabs(delta: float) -> void:
	var ap: float = _ap.crabs
	for c in _crabs:
		var x: float = c.cx + c.amp * clampf(1.5 * sin(_t * c.w + c.ph), -1.0, 1.0)
		var v: float = (x - c.px) / maxf(delta, 0.0001)
		c.px = x
		var sp := clampf(absf(v) / 1.6, 0.0, 1.0)
		c.lp += delta * (6.0 + 22.0 * sp)
		var z: float = beach.shore_z(x) - c.off
		var n: Node3D = c.node
		n.position = Vector3(x, _ground(x, z) - 0.02, z)
		n.scale = Vector3.ONE * c.s * ap
		var i := 0
		for leg: Node3D in c.legs:
			var side := -1.0 if i < 3 else 1.0
			var ph: float = c.lp + i * 1.3
			leg.rotation.z = side * (0.35 + 0.35 * sp * sin(ph))
			leg.rotation.y = 0.4 * sp * cos(ph) * side
			i += 1
		# claws wave when idle, tuck in while running
		var k := 0
		for arm: Node3D in c.claws:
			arm.rotation.x = -0.2 * sp + (1.0 - sp) * 0.25 * sin(_t * 2.5 + c.ph + k * 1.7)
			arm.rotation.y = (1.0 - sp) * 0.15 * sin(_t * 1.7 + k)
			k += 1

# ---------------------------------------------------------------- gulls (50%)

func _build_gulls() -> void:
	var white := Color(0.98, 0.98, 0.96)
	var grey := Color(0.62, 0.66, 0.7)
	var tip := Color(0.16, 0.17, 0.2)
	for i in 4:
		var root := Node3D.new()
		root.scale = Vector3.ZERO
		_roots["gulls"].add_child(root)
		_blob(root, white, Vector3(0, 0, 0), Vector3(0.36, 0.32, 0.85))
		_blob(root, white, Vector3(0, 0.1, 0.42), Vector3(0.24, 0.24, 0.27))
		_cone(root, Color(1.0, 0.72, 0.15), Vector3(0, 0.07, 0.6), 0.04, 0.2)
		_blob(root, white, Vector3(0, 0.03, -0.5), Vector3(0.2, 0.05, 0.4))
		for side in [-1.0, 1.0]:
			_eye(root, Vector3(side * 0.09, 0.15, 0.5), 0.07)
		var wings: Array[Node3D] = []
		var outs: Array[Node3D] = []
		for side in [-1.0, 1.0]:
			var w := Node3D.new()
			w.position = Vector3(side * 0.15, 0.07, 0.05)
			root.add_child(w)
			_blob(w, white, Vector3(side * 0.4, 0, 0), Vector3(0.85, 0.07, 0.42))
			var o := Node3D.new()
			o.position = Vector3(side * 0.8, 0, 0)
			w.add_child(o)
			_blob(o, grey, Vector3(side * 0.33, 0, -0.04), Vector3(0.7, 0.055, 0.3))
			_blob(o, tip, Vector3(side * 0.62, 0, -0.07), Vector3(0.22, 0.05, 0.2))
			wings.append(w)
			outs.append(o)
		_gulls.append({
			"node": root, "wings": wings, "outs": outs,
			"cx": _rng.randf_range(-12.0, 12.0), "cz": _rng.randf_range(20.0, 28.0),
			"r": _rng.randf_range(9.0, 20.0), "h": _rng.randf_range(8.0, 14.0),
			"w": _rng.randf_range(0.14, 0.24) * (1.0 if i % 2 == 0 else -1.0),
			"th": _rng.randf_range(0.0, TAU), "ph": _rng.randf_range(0.0, TAU),
		})

func _update_gulls() -> void:
	var ap: float = _ap.gulls
	for g in _gulls:
		var th: float = g.th + _t * g.w
		var dir := signf(g.w)
		var cz: float = beach.shore_z(g.cx) + g.cz
		var p := Vector3(g.cx + cos(th) * g.r, g.h + sin(_t * 0.7 + g.ph) * 0.8, cz + sin(th) * g.r * 0.8)
		var vel := Vector3(-sin(th), 0.0, cos(th) * 0.8) * dir
		var n: Node3D = g.node
		n.position = p
		n.rotation = Vector3(0.0, atan2(vel.x, vel.z), 0.3 * dir)
		n.scale = Vector3.ONE * 2.6 * ap
		# mostly gliding, now and then a few flaps
		var flap := smoothstep(0.1, 0.7, sin(_t * 0.5 + g.ph * 2.0))
		var a := 0.12 + 0.5 * flap
		var f := sin(_t * (5.0 + 2.0 * flap) + g.ph)
		g.wings[0].rotation.z = -a * f - 0.05
		g.wings[1].rotation.z = a * f + 0.05
		g.outs[0].rotation.z = -a * 0.7 * sin(_t * (5.0 + 2.0 * flap) + g.ph - 0.8)
		g.outs[1].rotation.z = a * 0.7 * sin(_t * (5.0 + 2.0 * flap) + g.ph - 0.8)

# ---------------------------------------------------------------- turtles (75% / 100%)

## Returns {node, head, flippers:[fl, fr, bl, br]}. `cute` = chunkier head, brighter colours (hatchlings).
func _make_turtle(parent: Node, cute: bool) -> Dictionary:
	var shell := Color(0.4, 0.5, 0.2) if not cute else Color(0.42, 0.45, 0.28)
	var plate := Color(0.58, 0.68, 0.28) if not cute else Color(0.55, 0.55, 0.36)
	var skin := Color(0.72, 0.78, 0.38) if not cute else Color(0.55, 0.62, 0.4)
	var belly := Color(0.95, 0.85, 0.6)
	var root := Node3D.new()
	parent.add_child(root)
	_blob(root, shell, Vector3(0, 0.3, 0), Vector3(0.95, 0.48, 1.15), 0.4)
	_blob(root, belly, Vector3(0, 0.12, 0), Vector3(0.9, 0.18, 1.1))
	# shell plates
	_blob(root, plate, Vector3(0, 0.52, 0.0), Vector3(0.36, 0.1, 0.42), 0.35)
	for j in 4:
		var a := j * PI / 2.0 + PI / 4.0
		_blob(root, plate, Vector3(sin(a) * 0.3, 0.45, cos(a) * 0.36), Vector3(0.24, 0.09, 0.28), 0.35)
	# head on a short neck
	var head := Node3D.new()
	head.position = Vector3(0, 0.26, 0.58)
	root.add_child(head)
	var hs := 1.25 if cute else 1.0
	_blob(head, skin, Vector3(0, 0.05, 0.1), Vector3(0.3, 0.27, 0.36) * hs)
	for side in [-1.0, 1.0]:
		_eye(head, Vector3(side * 0.1 * hs, 0.11 * hs, 0.22 * hs), 0.075 * hs)
		_blob(head, Color(1.0, 0.65, 0.6, 1.0), Vector3(side * 0.13 * hs, 0.0, 0.2 * hs), Vector3(0.05, 0.03, 0.04) * hs, 0.9)
	var fl: Array[Node3D] = []
	for spec in [[-1.0, 0.36, 0.36, 0.55, 0.28], [1.0, 0.36, 0.36, 0.55, 0.28], [-1.0, 0.3, -0.4, 0.38, 0.22], [1.0, 0.3, -0.4, 0.38, 0.22]]:
		var piv := Node3D.new()
		piv.position = Vector3(spec[0] * 0.38, 0.17, spec[2])
		root.add_child(piv)
		_blob(piv, skin, Vector3(spec[0] * spec[3] * 0.5, 0, 0.0), Vector3(spec[3], 0.08, spec[4]))
		fl.append(piv)
	return {"node": root, "head": head, "fl": fl}

func _build_turtle() -> void:
	var x := 3.5
	_turtle = _make_turtle(_roots["turtle"], false)
	_turtle["base"] = Vector2(x, beach.shore_z(x) - 2.6)

func _update_turtle() -> void:
	var ap: float = _ap.turtle
	var b: Vector2 = _turtle.base
	var n: Node3D = _turtle.node
	n.position = Vector3(b.x, _ground(b.x, b.y) - 0.06, b.y)
	n.rotation.y = 0.15  # roughly facing the sea
	n.rotation.x = -0.04
	n.scale = Vector3.ONE * 1.1 * ap
	var head: Node3D = _turtle.head
	head.position = Vector3(0.0, 0.26 + 0.035 * sin(_t * 1.1), 0.58 + 0.05 * sin(_t * 1.1 + 0.6))
	head.rotation.y = 0.25 * sin(_t * 0.35)
	var fl: Array = _turtle.fl
	fl[0].rotation = Vector3(0.0, 0.2 * sin(_t * 1.6), 0.35 + 0.25 * sin(_t * 1.6))
	fl[1].rotation = Vector3(0.0, -0.2 * sin(_t * 1.6 + 1.0), -0.35 - 0.25 * sin(_t * 1.6 + 1.0))
	fl[2].rotation = Vector3(0.0, 0.0, 0.15 * sin(_t * 1.2 + 2.0))
	fl[3].rotation = Vector3(0.0, 0.0, -0.15 * sin(_t * 1.2 + 3.0))

# ---------------------------------------------------------------- hatchlings (100%)

func _build_hatchlings() -> void:
	var nx := -3.0
	_nest = Vector2(nx, beach.shore_z(nx) - 6.5)
	# sandy nest mound with a few empty egg shells
	var nest := Node3D.new()
	nest.position = Vector3(_nest.x, _ground(_nest.x, _nest.y), _nest.y)
	_roots["hatchlings"].add_child(nest)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.35
	tm.outer_radius = 0.6
	tm.rings = 16
	tm.ring_segments = 8
	ring.mesh = tm
	ring.material_override = _mat(Color(0.88, 0.66, 0.4), 0.95)
	ring.scale = Vector3(1.0, 0.45, 1.0)
	ring.position.y = 0.03
	nest.add_child(ring)
	_blob(nest, Color(0.68, 0.46, 0.27), Vector3(0, -0.02, 0), Vector3(0.8, 0.1, 0.8), 0.95)
	for j in 4:
		var a := j * 1.7
		var e := _blob(nest, Color(0.97, 0.95, 0.88), Vector3(sin(a) * 0.2, 0.08, cos(a) * 0.2), Vector3(0.15, 0.1, 0.15), 0.8)
		e.rotation = Vector3(0.6 * sin(a * 2.0), a, 0.5)
	for i in 8:
		var holder := Node3D.new()
		_roots["hatchlings"].add_child(holder)
		var t := _make_turtle(holder, true)
		var lane := (i - 3.5) * 0.45
		var sp := _rng.randf_range(0.55, 0.8)
		var tx := _nest.x + lane * 1.6
		var ez: float = beach.shore_z(tx) + 0.4
		var d := Vector2(tx - (_nest.x + lane * 0.3), ez - _nest.y)
		_hatch.append({
			"node": holder, "t": t, "from": Vector2(_nest.x + lane * 0.3, _nest.y), "to": Vector2(tx, ez),
			"travel": d.length() / sp, "ph": float(i) * 1.7 + _rng.randf_range(0.0, 0.5),
			"wob": _rng.randf_range(0.0, TAU), "yaw": atan2(d.x, d.y),
		})

func _update_hatchlings() -> void:
	var ap: float = _ap.hatchlings
	for h in _hatch:
		var travel: float = h.travel
		var cycle := travel + 1.2
		var s := fmod(_t + h.ph, cycle)
		var n: Node3D = h.node
		if s > travel:
			n.scale = Vector3.ZERO
			continue
		var u := s / travel
		var p: Vector2 = h.from.lerp(h.to, u)
		p.x += 0.25 * sin(s * 0.9 + h.wob)  # a little meander
		var grow := minf(s / 0.5, 1.0)
		var dive := clampf((1.0 - u) / 0.07, 0.0, 1.0)  # shrinks into the surf at the end
		n.position = Vector3(p.x, _ground(p.x, p.y) - 0.02 + 0.1 * (1.0 - dive), p.y)
		n.rotation.y = h.yaw + 0.25 * cos(s * 0.9 + h.wob)
		var wd := sin(s * 9.0 + h.wob)
		n.rotation.z = 0.0
		n.scale = Vector3.ONE * 0.3 * ap * grow * dive
		var t: Dictionary = h.t
		t.node.rotation.z = 0.18 * wd
		var fl: Array = t.fl
		fl[0].rotation = Vector3(0.0, 0.5 * wd, 0.3 + 0.5 * wd)
		fl[1].rotation = Vector3(0.0, 0.5 * wd, -0.3 + 0.5 * wd)
		fl[2].rotation = Vector3(0.0, 0.0, 0.3 * wd)
		fl[3].rotation = Vector3(0.0, 0.0, -0.3 * wd)
		t.head.rotation.x = -0.12 + 0.1 * sin(s * 9.0 + 1.0)

func _process(delta: float) -> void:
	_t += delta
	if _ap.crabs > 0.001:
		_update_crabs(delta)
	if _ap.gulls > 0.001:
		_update_gulls()
	if _ap.turtle > 0.001:
		_update_turtle()
	if _ap.hatchlings > 0.001:
		_update_hatchlings()
