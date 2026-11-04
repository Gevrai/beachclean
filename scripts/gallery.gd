extends Node3D
## Showcase of every collectible at the size it has in the game, on sand, with name / real size / value.
## Open scenes/gallery.tscn and press F6 (Run Current Scene). Items turn slowly; the camera sways gently.
## Items are drawn Catalog.VIS_SCALE x life size (labels give the real size); the figure is life size.

const Catalog := preload("res://scripts/catalog.gd")
const SPACING := 0.9
const FRONT_Z := 1.0

var _spin: Array[Node3D] = []
var _cam: Camera3D
var _t := 0.0
var _focus := 1.5
var _dist := 2.0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_build_environment()
	_build_ground()
	# back row: the ten debris types; front row: coins (under the small items) + message bottle
	var ids: Array = Catalog.ITEMS.keys()
	for i in ids.size():
		var d := StaticBody3D.new()
		d.set_script(preload("res://scripts/debris.gd"))
		d.setup(ids[i], rng)
		add_child(d)
		d.position = Vector3(i * SPACING, 0, 0)
		_spin.append(d)
		var it: Dictionary = Catalog.ITEMS[ids[i]]
		_label(d.position + Vector3(0, 0, float(it.cm) * 0.0045), "%s\n%d cm · %s" % [it.name, int(it.cm), Catalog.price(int(it.value))])
	var front: Array = [5, 10, 25, 100]
	for i in front.size():
		var c := StaticBody3D.new()
		c.set_script(preload("res://scripts/loose_change.gd"))
		c.setup(front[i], rng)
		add_child(c)
		c.position = Vector3(i * SPACING * 0.75, 0, FRONT_Z)
		_spin.append(c)
		_label(c.position, "Coin %s\n%.1f cm" % [Catalog.price(front[i]), 200.0 * Catalog.coin_radius(front[i])])
	var b := StaticBody3D.new()
	b.set_script(preload("res://scripts/bottle.gd"))
	b.setup(2)
	add_child(b)
	b.position = Vector3(5 * SPACING, 0, FRONT_Z)
	_spin.append(b)
	_label(b.position, "Message in a bottle\n~30 cm")
	_ruler(Vector3(-0.6, 0, FRONT_Z))
	_figure(Vector3(-2.2, 0, -1.2))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--focus="):
			_focus = float(a.trim_prefix("--focus="))
	_cam = Camera3D.new()
	_cam.fov = 50.0
	add_child(_cam)
	_cam.current = true
	_place_cam()

## Camera orbits nothing: it slides along the row (A/D, arrows or mouse drag) and zooms (wheel, W/S).
func _place_cam() -> void:
	_focus = clampf(_focus, -1.0, 9 * SPACING + 1.0)
	_dist = clampf(_dist, 0.8, 7.0)
	_cam.position = Vector3(_focus + sin(_t * 0.3) * 0.15, _dist * 0.75, _dist * 0.7 + FRONT_Z * 0.5)
	_cam.look_at(Vector3(_focus, 0.05, FRONT_Z * 0.4))

func _input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_focus -= e.relative.x * 0.004 * _dist
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist *= 0.9
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist *= 1.1

func _process(delta: float) -> void:
	_t += delta
	for n in _spin:
		n.rotation.y += delta * 0.5
	_focus += (Input.get_axis("ui_left", "ui_right")) * delta * _dist * 0.6
	_focus += (float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))) * delta * _dist * 0.6
	_dist += (float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))) * delta * _dist
	_place_cam()

## 30 cm ruler lying on the sand.
func _ruler(at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.3, 0.006, 0.035)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.85, 0.2)
	mi.material_override = m
	mi.position = at + Vector3(0, 0.003, 0)
	add_child(mi)
	for i in 7:
		var t := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.003, 0.007, 0.02 if i % 2 == 0 else 0.012)
		t.mesh = tm
		var dm := StandardMaterial3D.new()
		dm.albedo_color = Color(0.15, 0.1, 0.05)
		t.material_override = dm
		t.position = at + Vector3(-0.15 + i * 0.05, 0.004, 0.0)
		add_child(t)
	_label(at, "30 cm ruler")

func _label(at: Vector3, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 36
	l.pixel_size = 0.0017
	l.outline_size = 12
	l.outline_modulate = Color(0.25, 0.15, 0.05, 0.9)
	l.modulate = Color(1, 0.97, 0.88)
	l.rotation.x = -PI / 2.0
	l.position = Vector3(at.x, 0.01, at.z + 0.2)
	add_child(l)

## 1.75 m reference figure (life size, ignoring VIS_SCALE).
func _figure(at: Vector3) -> void:
	var root := Node3D.new()
	root.position = at
	add_child(root)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.35, 0.45, 0.6)
	m.roughness = 0.7
	var body := CapsuleMesh.new()
	body.radius = 0.2
	body.height = 1.5
	var bi := MeshInstance3D.new()
	bi.mesh = body
	bi.material_override = m
	bi.position.y = 0.75
	root.add_child(bi)
	var head := SphereMesh.new()
	head.radius = 0.125
	head.height = 0.25
	var hi := MeshInstance3D.new()
	hi.mesh = head
	hi.material_override = m
	hi.position.y = 1.625
	root.add_child(hi)
	var l := Label3D.new()
	l.text = "1.75 m"
	l.font_size = 48
	l.pixel_size = 0.004
	l.outline_size = 10
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.position = Vector3(0, 1.95, 0)
	root.add_child(l)

func _noise_tex(seed_: int, freq: float, normal: bool, bump: float, size: int) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = seed_
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	var t := NoiseTexture2D.new()
	t.noise = n
	t.width = size
	t.height = size
	t.seamless = true
	t.as_normal_map = normal
	t.bump_strength = bump
	return t

func _build_ground() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.5, 0.34)
	mat.roughness = 1.0
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 40)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	add_child(mi)

## Same look as the healed beach (sky shader, ACES, glow, SSAO), with a high friendly sun.
func _build_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://assets/shaders/sky.gdshader")
	sky_mat.set_shader_parameter("cloud_noise", _noise_tex(21, 0.01, false, 1.0, 512))
	sky_mat.set_shader_parameter("zenith", Color(0.08, 0.33, 0.75))
	sky_mat.set_shader_parameter("mid", Color(0.2, 0.72, 0.88))
	sky_mat.set_shader_parameter("horizon", Color(0.95, 0.78, 0.6))
	sky_mat.set_shader_parameter("ground", Color(0.7, 0.66, 0.6))
	sky_mat.set_shader_parameter("sun_color", Color(1.0, 0.7, 0.4))
	sky_mat.set_shader_parameter("cloud_cover", 0.42)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.78, 0.86)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.75
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.3
	env.glow_bloom = 0.02
	env.glow_intensity = 0.6
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	env.adjustment_contrast = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.9, 0.76)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6
	sun.shadow_bias = 0.03
	add_child(sun)
	sun.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(-30.0), 0)
