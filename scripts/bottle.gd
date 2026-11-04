extends StaticBody3D
## A message in a bottle: glass bottle, rolled paper, faint sparkle. Group "bottle", layer 2.
## Picking it up (player) opens the note; it never uses bag space.

var note_id := 0
var _meshes: Array[MeshInstance3D] = []
var _visual: Node3D
var _busy := false

func setup(id: int) -> void:
	note_id = id
	add_to_group("bottle")
	collision_layer = 2
	collision_mask = 0
	_visual = Node3D.new()
	add_child(_visual)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.7, 0.95, 0.9, 0.38)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 1.0
	glass.emission_enabled = true
	glass.emission = Color(0.5, 0.9, 0.85)
	glass.emission_energy_multiplier = 0.25
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(1.0, 0.93, 0.74)
	paper.emission_enabled = true
	paper.emission = Color(1.0, 0.9, 0.6)
	paper.emission_energy_multiplier = 0.5
	var cork := StandardMaterial3D.new()
	cork.albedo_color = Color(0.72, 0.5, 0.3)
	_part(_cyl(0.07, 0.07, 0.24), glass, Vector3(0, -0.02, 0))
	_part(_cyl(0.028, 0.07, 0.09), glass, Vector3(0, 0.145, 0))
	_part(_cyl(0.028, 0.028, 0.08), glass, Vector3(0, 0.23, 0))
	_part(_cyl(0.032, 0.026, 0.045), cork, Vector3(0, 0.285, 0))
	var roll := _part(_cyl(0.028, 0.028, 0.17), paper, Vector3(0.01, -0.03, 0), Vector3(0, 0, 0.12))
	roll.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# sparkle: two tiny emissive stars that twinkle
	var star := QuadMesh.new()
	star.size = Vector2(0.16, 0.16)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.albedo_texture = _star_tex()
	for i in 2:
		var mi := MeshInstance3D.new()
		mi.mesh = star
		mi.material_override = sm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(0.1 - 0.2 * i, 0.12 + 0.12 * i, 0.05)
		_visual.add_child(mi)
		var tw := create_tween().set_loops()
		tw.tween_interval(0.7 * i)
		tw.tween_property(mi, "scale", Vector3.ONE * 1.4, 0.7).from(Vector3.ONE * 0.1)
		tw.tween_property(mi, "scale", Vector3.ONE * 0.1, 0.7)
		tw.tween_interval(0.8)
	_visual.rotation = Vector3(0, id * 1.7, PI / 2.0 - 0.25)
	_visual.scale = Vector3.ONE * 0.67 * preload("res://scripts/catalog.gd").VIS_SCALE  # ~30 cm real bottle
	_visual.position.y = 0.08
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.3
	cs.shape = sp
	cs.position.y = 0.1
	add_child(cs)

static func _star_tex() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 0.9, 0.9))
	g.set_color(1, Color(1, 1, 0.9, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t

func _cyl(rt: float, rb: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = 14
	c.rings = 1
	return c

func _part(mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	_visual.add_child(mi)
	_meshes.append(mi)
	return mi

## Target interface (see debris.gd): hover label.
func label_text() -> String:
	return "Message in a bottle"

func set_highlight(on: bool) -> void:
	var ov = preload("res://scripts/debris.gd")._outline_mat() if on else null
	for m in _meshes:
		m.material_overlay = ov

func refuse() -> void:
	pass

## Called by the player: pop up and vanish, then the note opens.
func pick_up(cam: Camera3D) -> void:
	if _busy:
		return
	_busy = true
	collision_layer = 0
	remove_from_group("bottle")
	set_highlight(false)
	var tw := create_tween()
	tw.tween_property(self, "global_position", global_position + Vector3.UP * 0.5, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "scale", Vector3.ONE * 0.05, 0.2).set_delay(0.05)
	tw.finished.connect(queue_free)
