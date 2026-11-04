extends StaticBody3D
## One piece of trash (item table: catalog.gd; prefab: scenes/items/<id>.tscn). Group "debris", collision layer 2.
## Debris.spawn(id, rng) then place it; pick_up(cam) / refuse() / set_highlight(on).

const Catalog := preload("res://scripts/catalog.gd")
const WaterWave := preload("res://scripts/water_wave.gd")
const OUTLINE := preload("res://assets/materials/items/outline.tres")
const PUFF := preload("res://scenes/items/sand_puff.tscn")

## Props are drawn slightly bigger than life (one uniform factor, see Catalog.VIS_SCALE).
const VIS_SCALE := Catalog.VIS_SCALE
## Pieces further than this (m) from the camera are not drawn (they are a few pixels there anyway).
const CULL_DIST := 45.0

@export var id: String = "cap"
var value: int = 1      # cents
var space: float = 0.25  # bag space units
var _visual: Node3D
var _meshes: Array[MeshInstance3D] = []
var _busy := false
## Floating in the sea: bobs and tilts with the water's wave motion (see water_wave.gd). Set via set_floating().
var floating := false
var _phase := 0.0
var _acc := 0.0   # time since the last floating update
var _skip := 0    # frames to skip before the next floating update
var _staggered := false
var _sink := 0.0  # how far a floating piece sits below the surface (its centre about at water level)

static func random_id(rng: RandomNumberGenerator) -> String:
	return Catalog.random_id(rng)

## A new piece of trash from its prefab: random colour variant, yaw and a little tilt. Add it to the tree, then place it.
static func spawn(item_id: String, rng: RandomNumberGenerator) -> StaticBody3D:
	var d: StaticBody3D = Catalog.item_scene(item_id).instantiate()
	d.get_node("Visual/Model").randomize_variant(rng)
	d.get_node("Visual").rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, 0.0)
	return d

func _ready() -> void:
	value = int(Catalog.ITEMS[id].value)
	space = float(Catalog.ITEMS[id].space)
	_visual = $Visual
	_visual.scale = Vector3.ONE * VIS_SCALE
	_visual.position.y = float($Visual/Model.rest) * VIS_SCALE
	_collect_meshes(_visual)
	_phase = randf() * TAU
	_sink = float($Visual/Model.rest) * VIS_SCALE * 1.1
	set_process(floating)
	if floating:
		_ride()

## Float on the sea instead of lying on the ground (call after add_child, before/after placing).
func set_floating(on: bool) -> void:
	floating = on
	set_process(on)
	if on and is_inside_tree():
		_ride()

func _process(delta: float) -> void:
	# Hundreds of floaters: update every frame only near the camera, every 3rd/8th frame further out (staggered per piece).
	_acc += delta
	if _skip > 0:
		_skip -= 1
		return
	var cam := get_viewport().get_camera_3d()
	var d2 := 0.0 if cam == null else cam.global_position.distance_squared_to(global_position)
	_skip = 0 if d2 < 400.0 else (2 if d2 < 2500.0 else 7)
	if _skip > 0 and not _staggered:
		_staggered = true
		_skip = randi() % (_skip + 1)
	# lazy drift on top of the bobbing
	var t := WaterWave.time()
	global_position.x += sin(t * 0.17 + _phase) * 0.05 * _acc
	global_position.z += cos(t * 0.13 + _phase * 1.7) * 0.04 * _acc
	_acc = 0.0
	_ride()

## Put the piece on the wave surface and tilt it with the local slope.
func _ride() -> void:
	var t := WaterWave.time()
	var p := global_position
	global_position.y = WaterWave.height(p.x, p.z, t) - _sink
	var s := WaterWave.slope(p.x, p.z, t)
	global_rotation = Vector3(atan(s.y) * 1.5, _phase + t * 0.05, -atan(s.x) * 1.5)

func _collect_meshes(n: Node) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			_meshes.append(c)
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # tiny pieces: no shadow pass (thousands of them)
			c.visibility_range_end = CULL_DIST
		_collect_meshes(c)

## Target interface (player aiming): label_text(), set_highlight(on), pick_up(cam), refuse().
## Hover label: "Soda can · 10¢"
func label_text() -> String:
	return "%s · %s" % [Catalog.ITEMS[id].name, Catalog.price(value)]

func set_highlight(on: bool) -> void:
	for m in _meshes:
		m.material_overlay = OUTLINE if on else null

## Little pop-in (used by the tide).
func pop_in() -> void:
	scale = Vector3.ONE * 0.01
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Bag was full: small shake.
func refuse() -> void:
	if _busy:
		return
	_busy = true
	var base := _visual.position
	var tw := create_tween()
	for i in 3:
		tw.tween_property(_visual, "position:x", 0.04 * (1 if i % 2 == 0 else -1), 0.04)
	tw.tween_property(_visual, "position", base, 0.04)
	tw.finished.connect(func(): _busy = false)

## Pop up, then shrink toward the camera, with a sand puff.
func pick_up(cam: Camera3D) -> void:
	_busy = true
	get_node("/root/Sfx").pickup(id)  # not a bare identifier: keeps --check-only quiet
	collision_layer = 0
	remove_from_group("debris")
	set_highlight(false)
	if not floating:
		_puff(global_position + Vector3(0, 0.05, 0))
	set_process(false)
	global_rotation = Vector3.ZERO
	var start := global_position
	var up := start + Vector3.UP * 0.4
	var tw := create_tween()
	tw.tween_property(self, "global_position", up, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "scale", Vector3.ONE * 1.3, 0.12)
	tw.tween_method(_fly.bind(up, cam), 0.0, 1.0, 0.22)
	tw.finished.connect(queue_free)

func _fly(t: float, from: Vector3, cam: Camera3D) -> void:
	var e := t * t
	var goal := cam.global_position - cam.global_basis.z * 0.4 - cam.global_basis.y * 0.15
	global_position = from.lerp(goal, e)
	scale = Vector3.ONE * lerpf(1.3, 0.08, e)

func _puff(at: Vector3) -> void:
	var p: CPUParticles3D = PUFF.instantiate()
	get_tree().current_scene.add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
