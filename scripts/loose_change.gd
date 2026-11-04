extends StaticBody3D
## A coin on the sand: instant money on pickup, never enters the bag, no health effect.
## Group "coin", collision layer 2. setup(cents, rng).

const Catalog := preload("res://scripts/catalog.gd")

var value := 5  # cents
var _meshes: Array[MeshInstance3D] = []
var _visual: Node3D
var _star: Node3D
var _t := 0.0
var _busy := false

func setup(cents: int, rng: RandomNumberGenerator) -> void:
	value = cents
	add_to_group("coin")
	collision_layer = 2
	collision_mask = 0
	_t = rng.randf() * 10.0
	_visual = Node3D.new()
	add_child(_visual)
	var gold := cents >= 100
	var col := Color(1.0, 0.8, 0.2) if gold else (Color(0.85, 0.88, 0.95) if cents >= 10 else Color(0.9, 0.6, 0.4))
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = 0.7
	m.roughness = 0.25
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 0.6
	var r := Catalog.coin_radius(cents)
	var disc := CylinderMesh.new()
	disc.top_radius = r
	disc.bottom_radius = r
	disc.height = 0.002
	disc.radial_segments = 20
	disc.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = disc
	mi.material_override = m
	_visual.add_child(mi)
	_meshes.append(mi)
	var rim := CylinderMesh.new()
	rim.top_radius = r * 0.62
	rim.bottom_radius = r * 0.62
	rim.height = 0.0026
	rim.radial_segments = 20
	rim.rings = 1
	var m2 := StandardMaterial3D.new()
	m2.albedo_color = col.darkened(0.2)
	m2.metallic = 0.6
	m2.roughness = 0.35
	var mi2 := MeshInstance3D.new()
	mi2.mesh = rim
	mi2.material_override = m2
	_visual.add_child(mi2)
	_meshes.append(mi2)
	_visual.rotation = Vector3(rng.randf_range(-0.25, 0.25), rng.randf() * TAU, rng.randf_range(-0.25, 0.25))
	_visual.scale = Vector3.ONE * Catalog.VIS_SCALE
	_visual.position.y = 0.006 * Catalog.VIS_SCALE
	# tiny sparkle: a 4-point star that twinkles
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.albedo_texture = preload("res://scripts/bottle.gd")._star_tex()
	var q := QuadMesh.new()
	q.size = Vector2(0.1, 0.1)
	var sp := MeshInstance3D.new()
	sp.mesh = q
	sp.material_override = sm
	sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sp.position = Vector3(0.02, 0.07, 0)
	add_child(sp)
	_star = sp
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.2
	cs.shape = sh
	cs.position.y = 0.04
	add_child(cs)

func _process(delta: float) -> void:
	_t += delta
	_star.scale = Vector3.ONE * (0.15 + 0.85 * maxf(0.0, sin(_t * 2.2)))

## Hover label: "Loose change · $0.25"
func label_text() -> String:
	return "Loose change · %s" % Catalog.money(value)

func set_highlight(on: bool) -> void:
	var ov = preload("res://scripts/debris.gd")._outline_mat() if on else null
	for m in _meshes:
		m.material_overlay = ov

func refuse() -> void:
	pass

## Called by the player after adding the money: pop up, spin, vanish.
func pick_up(_cam: Camera3D) -> void:
	if _busy:
		return
	_busy = true
	set_process(false)
	_star.visible = false
	get_node("/root/Sfx").tick()
	collision_layer = 0
	remove_from_group("coin")
	set_highlight(false)
	var tw := create_tween()
	tw.tween_property(self, "global_position", global_position + Vector3.UP * 0.6, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_visual, "rotation:y", _visual.rotation.y + TAU * 2.0, 0.25)
	tw.parallel().tween_property(self, "scale", Vector3.ONE * 0.05, 0.15).set_delay(0.12)
	tw.finished.connect(queue_free)
