extends StaticBody3D
## One piece of trash (see catalog.gd for the item table, item_mesh.gd for the models). Group "debris", collision layer 2.
## setup(id, rng) then place it; pick_up(cam) / refuse() / set_highlight(on).

const Catalog := preload("res://scripts/catalog.gd")
const ItemMesh := preload("res://scripts/item_mesh.gd")

## Props are drawn slightly bigger than life (one uniform factor, see Catalog.VIS_SCALE).
const VIS_SCALE := Catalog.VIS_SCALE

static var _outline: ShaderMaterial

var id: String = "cap"
var value: int = 1      # cents
var space: float = 0.25  # bag space units
var _visual: Node3D
var _meshes: Array[MeshInstance3D] = []
var _busy := false

static func random_id(rng: RandomNumberGenerator) -> String:
	return Catalog.random_id(rng)

static func _outline_mat() -> ShaderMaterial:
	if _outline == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode cull_front, unshaded;
void vertex() { VERTEX += NORMAL * 0.02; }
void fragment() { ALBEDO = vec3(1.0, 0.8, 0.15) * (1.3 + 0.4 * sin(TIME * 8.0)); }
"""
		_outline = ShaderMaterial.new()
		_outline.shader = sh
	return _outline

func setup(item_id: String, rng: RandomNumberGenerator) -> void:
	id = item_id
	value = int(Catalog.ITEMS[id].value)
	space = float(Catalog.ITEMS[id].space)
	add_to_group("debris")
	collision_layer = 2
	collision_mask = 0
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var body := ItemMesh.build(id, rng)
	_visual.add_child(body)
	_collect_meshes(body)
	_visual.basis = Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2))
	_visual.scale = Vector3.ONE * VIS_SCALE
	_visual.position.y = float(body.get_meta("rest")) * VIS_SCALE
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = maxf(Catalog.MIN_PICK_RADIUS, float(Catalog.ITEMS[id].cm) * 0.01 * VIS_SCALE * 0.5 + 0.04)
	cs.shape = sp
	cs.position.y = 0.08
	add_child(cs)

func _collect_meshes(n: Node) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			_meshes.append(c)
		_collect_meshes(c)

## Target interface (player aiming): label_text(), set_highlight(on), pick_up(cam), refuse().
## Hover label: "Soda can · 10¢"
func label_text() -> String:
	return "%s · %s" % [Catalog.ITEMS[id].name, Catalog.price(value)]

func set_highlight(on: bool) -> void:
	for m in _meshes:
		m.material_overlay = _outline_mat() if on else null

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
	_puff(global_position + Vector3(0, 0.05, 0))
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
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = 12
	p.lifetime = 0.55
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.8
	p.gravity = Vector3(0, -3.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.07
	sm.radial_segments = 8
	sm.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material = mat
	p.mesh = sm
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.92, 0.7, 0.95))
	g.set_color(1, Color(1.0, 0.92, 0.7, 0.0))
	p.color_ramp = g
	get_tree().current_scene.add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
