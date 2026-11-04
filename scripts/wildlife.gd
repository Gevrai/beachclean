extends Node3D
## Ambient animals that return at health milestones (see GameState.MILESTONES). No AI, no collision:
## simple looping animation driven from _process. Each animal is a prefab in scenes/wildlife/ (this script is the root of
## wildlife.tscn, whose Crabs/Gulls/Turtle/Hatchlings nodes are the group roots). Local +Z is every model's front.

var beach: Node  # set by beach.gd before add_child

const CRAB := preload("res://scenes/wildlife/crab.tscn")
const GULL := preload("res://scenes/wildlife/gull.tscn")
const TURTLE := preload("res://scenes/wildlife/turtle.tscn")
const HATCHLING := preload("res://scenes/wildlife/hatchling.tscn")
const NEST := preload("res://scenes/wildlife/nest.tscn")

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
		var r: Node3D = get_node(id.capitalize())
		r.visible = false
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

func _ground(x: float, z: float) -> float:
	return beach.height_at(x, z)

# ---------------------------------------------------------------- crabs (25%)

func _build_crabs() -> void:
	for i in 5:
		var root: Node3D = CRAB.instantiate()
		root.scale = Vector3.ONE * 0.0
		_roots["crabs"].add_child(root)
		var s := _rng.randf_range(1.0, 1.3)
		var legs: Array[Node3D] = []
		var claws: Array[Node3D] = []
		for k in 6:
			legs.append(root.get_node("Leg%d" % k))
		for k in 2:
			claws.append(root.get_node("Claw%d" % k))
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
	for i in 4:
		var root: Node3D = GULL.instantiate()
		root.scale = Vector3.ZERO
		_roots["gulls"].add_child(root)
		var wings: Array[Node3D] = [root.get_node("Wing0"), root.get_node("Wing1")]
		var outs: Array[Node3D] = [root.get_node("Wing0/WingTip"), root.get_node("Wing1/WingTip")]
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

## Returns {node, head, flippers:[fl, fr, bl, br]} for an instanced turtle/hatchling prefab.
func _rig_turtle(root: Node3D) -> Dictionary:
	var fl: Array[Node3D] = []
	for k in 4:
		fl.append(root.get_node("Flipper%d" % k))
	return {"node": root, "head": root.get_node("Head"), "fl": fl}

func _build_turtle() -> void:
	var x := 3.5
	var tn: Node3D = TURTLE.instantiate()
	_roots["turtle"].add_child(tn)
	_turtle = _rig_turtle(tn)
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
	var nest: Node3D = NEST.instantiate()
	nest.position = Vector3(_nest.x, _ground(_nest.x, _nest.y), _nest.y)
	_roots["hatchlings"].add_child(nest)
	for i in 8:
		var holder := Node3D.new()
		_roots["hatchlings"].add_child(holder)
		var hn: Node3D = HATCHLING.instantiate()
		holder.add_child(hn)
		var t := _rig_turtle(hn)
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
