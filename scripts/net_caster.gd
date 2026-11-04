extends Node3D
## Casting net (shop upgrade "net"): hold right-click to aim a landing circle on the sea, release to cast. The net
## (scenes/net/net.tscn) arcs out, lands, then reels back in ~1 s with the floating litter inside its radius, which
## goes to the bag (as far as there is space; the rest stays floating). Only floating debris is caught.
## Created by Player (`player` var set before add_child); needs GameState.level("net") > 0. Dev: --net-demo (cast and freeze mid-air), --net-aim (show the landing circle).

const WaterWave := preload("res://scripts/water_wave.gd")
const NET := preload("res://scenes/net/net.tscn")
const TARGET := preload("res://scenes/net/net_target.tscn")
const SPLASH := preload("res://scenes/fx/net_splash.tscn")
const MIN_DIST := 2.5
const REEL_TIME := 1.0
const OK_COLOR := Color(1, 1, 1, 1)
const BAD_COLOR := Color(1.0, 0.45, 0.35, 1)

enum { IDLE, AIM, FLY, REEL }

var player: CharacterBody3D
var _state := IDLE
var _target: MeshInstance3D
var _net: Node3D
var _aim_pt := Vector3.ZERO
var _aim_ok := false
var _radius := 2.0
var _t := 0.0
var _fly_time := 0.7
var _from := Vector3.ZERO
var _land := Vector3.ZERO
var _haul: Array = []     # [{node, off: Vector2}]
var _demo := false

func _ready() -> void:
	_target = TARGET.instantiate()
	_target.visible = false
	add_child(_target)
	_net = NET.instantiate()
	_net.visible = false
	add_child(_net)
	if OS.get_cmdline_user_args().has("--net-demo"):
		_demo = true
		GameState.levels["net"] = 2
		GameState.upgrades_changed.emit()
		get_tree().create_timer(0.6).timeout.connect(_demo_cast)
	elif OS.get_cmdline_user_args().has("--net-aim"):  # dev: show the landing circle
		GameState.levels["net"] = 2
		GameState.upgrades_changed.emit()
		_state = AIM

func _demo_cast() -> void:
	_update_aim()
	_cast()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_RIGHT:
		return
	if event.pressed:
		if _state == IDLE and GameState.net_range() > 0.0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_state = AIM
	elif _state == AIM:
		if _aim_ok:
			_cast()
		else:
			_state = IDLE
			_target.visible = false

func _process(delta: float) -> void:
	match _state:
		AIM:
			if GameState.net_range() <= 0.0 or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				_state = IDLE
				_target.visible = false
				return
			_update_aim()
		FLY:
			_fly(delta)
		REEL:
			_reel(delta)

## Where the crosshair meets the sea (clamped to the net's range, or flat out to sea when looking at the horizon).
func _update_aim() -> void:
	var cam: Camera3D = player.cam
	var from := cam.global_position
	var dir := -cam.global_basis.z
	var rng := GameState.net_range()
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	var pt: Vector3
	if dir.y < -0.01:
		pt = from + dir * (from.y / -dir.y)
	else:
		pt = from + flat * rng
	var off := Vector2(pt.x - player.global_position.x, pt.z - player.global_position.z)
	var dist := clampf(off.length(), MIN_DIST, rng)
	var o2 := off.normalized() if off.length() > 0.01 else Vector2(flat.x, flat.z)
	pt = Vector3(player.global_position.x + o2.x * dist, 0.0, player.global_position.z + o2.y * dist)
	_radius = GameState.net_radius()
	_aim_ok = player.beach.height_at(pt.x, pt.z) < -0.25
	pt.y = WaterWave.height(pt.x, pt.z, WaterWave.time())
	_aim_pt = pt
	_target.visible = true
	_target.global_position = pt + Vector3.UP * 0.04
	_target.scale = Vector3(_radius * 2.0, 1.0, _radius * 2.0)
	_target.set_instance_shader_parameter("tint", OK_COLOR if _aim_ok else BAD_COLOR)

func _cast() -> void:
	var cam: Camera3D = player.cam
	_from = cam.global_position + cam.global_basis.x * 0.25 - cam.global_basis.y * 0.35 - cam.global_basis.z * 0.3
	_land = _aim_pt
	_target.visible = false
	_fly_time = 0.45 + _from.distance_to(_land) * 0.02
	_t = 0.0
	_net.visible = true
	_net.global_position = _from
	_state = FLY

func _fly(delta: float) -> void:
	_t += delta
	var e := clampf(_t / _fly_time, 0.0, 1.0)
	if _demo and e >= 0.65:
		_t = _fly_time * 0.65  # dev: hold the net mid-air for a screenshot
		e = 0.65
	var p := _from.lerp(_land, e)
	var dist := _from.distance_to(_land)
	p.y += sin(PI * e) * (1.2 + 0.07 * dist)
	_net.global_position = p
	var spread := lerpf(0.3, 1.0, smoothstep(0.0, 0.8, e))
	_net.scale = Vector3.ONE * _radius * 2.0 * spread
	_net.rotation = Vector3(0.0, e * 5.0, 0.0)
	if e >= 1.0:
		_land_net()

func _land_net() -> void:
	var sp: CPUParticles3D = SPLASH.instantiate()
	add_child(sp)
	sp.global_position = _land
	sp.emitting = true
	get_tree().create_timer(1.2).timeout.connect(sp.queue_free)
	get_node("/root/Sfx").net_splash()
	_haul.clear()
	var found: Array = []
	for d in get_tree().get_nodes_in_group("debris"):
		if d.floating:
			var dd := Vector2(d.global_position.x - _land.x, d.global_position.z - _land.z).length()
			if dd <= _radius:
				found.append([dd, d])
	found.sort_custom(func(a, b): return a[0] < b[0])
	var skipped := false
	for e in found:
		var d: StaticBody3D = e[1]
		if not GameState.can_add(d.space):
			skipped = true
			continue
		GameState.add_to_bag(d.id)
		GameState.register_clear()
		d.remove_from_group("debris")
		d.collision_layer = 0
		d.set_process(false)
		d.set_highlight(false)
		if player.target == d:
			player.target = null
		_haul.append({"node": d, "off": Vector2(d.global_position.x - _land.x, d.global_position.z - _land.z)})
	if skipped:
		GameState.bag_full.emit()
	_t = 0.0
	_state = REEL

func _reel(delta: float) -> void:
	_t += delta
	var e := clampf(_t / REEL_TIME, 0.0, 1.0)
	var k := e * e * (3.0 - 2.0 * e)
	var cam: Camera3D = player.cam
	var fwd: Vector3 = -cam.global_basis.z * Vector3(1, 0, 1)
	var home: Vector3 = Vector3(player.global_position.x, 0.0, player.global_position.z) + fwd.normalized() * 0.9
	var c := _land.lerp(home, k)
	var tm := WaterWave.time()
	c.y = WaterWave.height(c.x, c.z, tm) + 0.05
	_net.global_position = c
	var closing := 1.0 - 0.8 * k  # the net gathers its catch
	_net.scale = Vector3.ONE * _radius * 2.0 * closing
	_net.rotation = Vector3(0.0, 5.0 + k * 1.5, 0.0)
	for h in _haul:
		var n: Node3D = h.node
		if is_instance_valid(n):
			var o: Vector2 = h.off * closing
			n.global_position = Vector3(c.x + o.x, WaterWave.height(c.x + o.x, c.z + o.y, tm) - 0.02 + 0.05 * k, c.z + o.y)
	if e >= 1.0:
		_finish()

func _finish() -> void:
	_net.visible = false
	var cam: Camera3D = player.cam
	var i := 0
	for h in _haul:
		if is_instance_valid(h.node):
			var n: StaticBody3D = h.node
			get_tree().create_timer(minf(i * 0.04, 0.5)).timeout.connect(func():
				if is_instance_valid(n):
					n.pick_up(cam))
			i += 1
	_haul.clear()
	_state = IDLE
