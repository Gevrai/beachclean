extends Node3D
## The beach: procedural sand terrain, water, sky, sun, palms/rocks/grass, and the health-driven look.
## Public API: set_health(t), height_at(x, z). Group "beach".

const X_MIN := -70.0
const X_MAX := 70.0
const Z_MIN := -80.0
const Z_MAX := 70.0
const STEP := 1.0

@export_range(0.0, 1.0) var health: float = 0.0

@onready var sun: DirectionalLight3D = $Sun
@onready var world_env: WorldEnvironment = $WorldEnvironment

var _noise := FastNoiseLite.new()
var _env := Environment.new()
var _sky_mat := ShaderMaterial.new()
var _sand_mat := ShaderMaterial.new()
var _water_mat := ShaderMaterial.new()
var _grass_mat := ShaderMaterial.new()
var _leaf_mat := StandardMaterial3D.new()
var _trunk_mat := StandardMaterial3D.new()
var _rock_mat := StandardMaterial3D.new()
var _rng := RandomNumberGenerator.new()
var _time := 0.0

func _ready() -> void:
	add_to_group("beach")
	_rng.seed = 7
	_noise.seed = 11
	_noise.frequency = 0.05
	_setup_materials()
	_setup_environment()
	_build_terrain()
	_build_water()
	_build_grass()
	_build_props()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--health="):
			health = float(a.trim_prefix("--health="))
	health = maxf(health, GameState.health())  # restored save
	set_health(health)
	GameState.health_changed.connect(_on_health_changed)
	_spawn_gameplay()

var _health_tw: Tween

## Eases the visual health to the new value over ~2 s instead of snapping.
func _on_health_changed(v: float) -> void:
	if _health_tw:
		_health_tw.kill()
	_health_tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_health_tw.tween_method(set_health, health, v, 2.0)

func _process(delta: float) -> void:
	_time += delta
	# keep the sand's wet line in sync with the water swell
	var swell := sin(_time * 0.55) * 0.6 + sin(_time * 0.31 + 1.7) * 0.4
	_sand_mat.set_shader_parameter("swell", swell * 0.12)

# ---------------------------------------------------------------- gameplay

func _spawn_gameplay() -> void:
	var shack := Node3D.new()
	shack.set_script(preload("res://scripts/shack.gd"))
	shack.set("beach", self)
	add_child(shack)
	var mgr := Node.new()
	mgr.set_script(preload("res://scripts/debris_manager.gd"))
	mgr.set("beach", self)
	add_child(mgr)
	var player := CharacterBody3D.new()
	player.set_script(preload("res://scripts/player.gd"))
	player.set("beach", self)
	add_child(player)
	add_child(load("res://scenes/ui/hud.tscn").instantiate())  # load: scene scripts use autoloads
	add_child(load("res://scenes/ui/pause_menu.tscn").instantiate())  # load: scene scripts use autoloads
	add_child(load("res://scenes/ui/cheats.tscn").instantiate())  # load: scene scripts use autoloads
	var wild := Node3D.new()
	wild.set_script(preload("res://scripts/wildlife.gd"))
	wild.set("beach", self)
	add_child(wild)

# ---------------------------------------------------------------- terrain

## World z of the shoreline at x.
func shore_z(x: float) -> float:
	return 2.5 * sin(x * 0.07) + 1.5 * sin(x * 0.19 + 1.0)

func height_at(x: float, z: float) -> float:
	var zs := z - shore_z(x)
	var land := -zs * 0.045
	var sea := -zs * 0.14
	var h := lerpf(land, sea, smoothstep(-2.0, 2.0, zs))
	h = maxf(h, -5.0 + 0.5 * h) if zs > 0.0 else h
	var n := _noise.get_noise_2d(x, z)
	# soft sand undulation on dry land
	h += n * 0.1 * smoothstep(4.0, -4.0, zs)
	# dunes at the back
	var d := smoothstep(-15.0, -32.0, zs)
	h += d * (1.0 + 1.6 * (0.5 + 0.5 * _noise.get_noise_2d(x * 0.6 + 50.0, z * 0.6)) + 1.2 * n)
	# headlands at both ends close the bay
	var e := smoothstep(40.0, 66.0, absf(x))
	h += e * (3.0 + 2.0 * n) * smoothstep(14.0, -6.0, zs)
	# fade the far back to flat so the map has an edge
	h -= smoothstep(-55.0, -78.0, z) * 3.5
	return h

func _build_terrain() -> void:
	var nx := int((X_MAX - X_MIN) / STEP) + 1
	var nz := int((Z_MAX - Z_MIN) / STEP) + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	verts.resize(nx * nz)
	norms.resize(nx * nz)
	uvs.resize(nx * nz)
	var e := 0.5
	for j in nz:
		for i in nx:
			var x := X_MIN + i * STEP
			var z := Z_MIN + j * STEP
			var k := j * nx + i
			verts[k] = Vector3(x, height_at(x, z), z)
			norms[k] = Vector3(height_at(x - e, z) - height_at(x + e, z), 2.0 * e,
				height_at(x, z - e) - height_at(x, z + e)).normalized()
			uvs[k] = Vector2(x, z) * 0.1
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			var b := a + 1
			var c := a + nx
			var dd := c + 1
			idx.append_array([a, b, c, b, dd, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _sand_mat)
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	add_child(mi)
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	add_child(body)

func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(320.0, 420.0)
	plane.subdivide_width = 160
	plane.subdivide_depth = 210
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = plane
	mi.material_override = _water_mat
	mi.position = Vector3(0.0, 0.0, 210.0 - 8.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

# ---------------------------------------------------------------- materials / env

func _noise_tex(seed_: int, freq: float, normal: bool, bump: float = 3.0, size: int = 512) -> NoiseTexture2D:
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

func _setup_materials() -> void:
	_sand_mat.shader = load("res://assets/shaders/sand.gdshader")
	_sand_mat.set_shader_parameter("grain", _noise_tex(3, 0.02, true, 4.0))
	_sand_mat.set_shader_parameter("patches", _noise_tex(5, 0.01, false))
	_water_mat.shader = load("res://assets/shaders/water.gdshader")
	_water_mat.set_shader_parameter("normal_a", _noise_tex(8, 0.012, true, 6.0))
	_water_mat.set_shader_parameter("normal_b", _noise_tex(9, 0.02, true, 5.0))
	_grass_mat.shader = load("res://assets/shaders/grass.gdshader")
	_sky_mat.shader = load("res://assets/shaders/sky.gdshader")
	_sky_mat.set_shader_parameter("cloud_noise", _noise_tex(21, 0.01, false, 1.0, 512))
	_leaf_mat.vertex_color_use_as_albedo = true
	_leaf_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_leaf_mat.roughness = 0.55
	_leaf_mat.backlight_enabled = true
	_leaf_mat.backlight = Color(0.35, 0.45, 0.1)
	_trunk_mat.vertex_color_use_as_albedo = true
	_trunk_mat.roughness = 0.9
	_rock_mat.vertex_color_use_as_albedo = true
	_rock_mat.roughness = 0.95
	_rock_mat.metallic_specular = 0.1

func _setup_environment() -> void:
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.tonemap_exposure = 0.75
	_env.glow_enabled = true
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	_env.glow_hdr_threshold = 1.3
	_env.glow_bloom = 0.02
	_env.ssao_enabled = true
	_env.ssao_radius = 1.2
	_env.ssao_intensity = 2.0
	_env.fog_enabled = true
	_env.fog_sun_scatter = 0.1
	_env.fog_sky_affect = 0.5
	_env.volumetric_fog_enabled = true
	_env.volumetric_fog_length = 120.0
	_env.volumetric_fog_anisotropy = 0.7
	_env.volumetric_fog_ambient_inject = 0.3
	_env.adjustment_enabled = true
	world_env.environment = _env
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 90.0
	sun.light_angular_distance = 1.2
	sun.shadow_blur = 1.6
	sun.shadow_bias = 0.03
	sun.light_volumetric_fog_energy = 1.0

## t: 0 = polluted (grey, cool, murky) .. 1 = healed (vibrant, golden sun).
func set_health(t: float) -> void:
	health = clampf(t, 0.0, 1.0)
	var k := pow(health, 0.8)  # slight ease so low health is still pleasant
	# sun
	var sunset := smoothstep(0.85, 1.0, health)  # golden-hour boost near 100%
	var elev := deg_to_rad(lerpf(38.0, 17.0, k) - 6.0 * sunset)
	var az := deg_to_rad(15.0)
	var to_sun := Vector3(sin(az) * cos(elev), sin(elev), cos(az) * cos(elev))
	sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
	sun.light_color = Color(0.85, 0.9, 1.0).lerp(Color(1.0, 0.68, 0.36), k).lerp(Color(1.0, 0.52, 0.2), sunset * 0.6)
	sun.light_energy = lerpf(0.8, 1.35, k) + 0.15 * sunset
	# sky
	_sky_mat.set_shader_parameter("zenith", Color(0.42, 0.5, 0.57).lerp(Color(0.08, 0.33, 0.75), k))
	_sky_mat.set_shader_parameter("mid", Color(0.6, 0.65, 0.68).lerp(Color(0.2, 0.72, 0.88), k))
	_sky_mat.set_shader_parameter("horizon", Color(0.72, 0.74, 0.73).lerp(Color(1.0, 0.68, 0.38), k).lerp(Color(1.0, 0.5, 0.25), sunset * 0.7))
	_sky_mat.set_shader_parameter("ground", Color(0.5, 0.52, 0.5).lerp(Color(0.85, 0.6, 0.45), k))
	_sky_mat.set_shader_parameter("sun_color", Color(0.9, 0.92, 1.0).lerp(Color(1.0, 0.7, 0.4), k))
	_sky_mat.set_shader_parameter("cloud_cover", lerpf(0.85, 0.42, k))
	_sky_mat.set_shader_parameter("cloud_lit", Color(0.7, 0.72, 0.74).lerp(Color(1.0, 0.9, 0.82), k))
	_sky_mat.set_shader_parameter("cloud_shade", Color(0.56, 0.58, 0.62).lerp(Color(0.62, 0.55, 0.78), k))
	# fog / env
	var fog_col := Color(0.66, 0.69, 0.7).lerp(Color(1.0, 0.78, 0.6), k).lerp(Color(1.0, 0.65, 0.42), sunset * 0.5)
	_env.fog_light_color = fog_col
	_env.fog_density = lerpf(0.004, 0.0012, k)
	_env.volumetric_fog_density = lerpf(0.005, 0.0018, k)
	_env.volumetric_fog_albedo = Color(0.75, 0.78, 0.8).lerp(Color(1.0, 0.82, 0.62), k)
	_env.ambient_light_energy = lerpf(0.6, 0.65, k)
	_env.adjustment_saturation = lerpf(0.5, 1.3, k)
	_env.adjustment_contrast = lerpf(0.95, 1.08, k)
	_env.glow_intensity = lerpf(0.3, 0.6, k)
	# water
	_water_mat.set_shader_parameter("shallow_color", Color(0.45, 0.55, 0.47).lerp(Color(0.22, 0.95, 0.82), k))
	_water_mat.set_shader_parameter("deep_color", Color(0.17, 0.27, 0.3).lerp(Color(0.0, 0.4, 0.5), k))
	_water_mat.set_shader_parameter("foam_color", Color(0.72, 0.74, 0.68).lerp(Color(1.0, 1.0, 1.0), k))
	_water_mat.set_shader_parameter("absorb", lerpf(1.8, 0.85, k))
	# sand / grass / palms
	_sand_mat.set_shader_parameter("sand_dry", Color(0.46, 0.41, 0.33).lerp(Color(0.78, 0.52, 0.22), k))
	_sand_mat.set_shader_parameter("sand_light", Color(0.52, 0.47, 0.39).lerp(Color(0.88, 0.66, 0.34), k))
	_sand_mat.set_shader_parameter("grass_tint", Color(0.55, 0.5, 0.32).lerp(Color(0.55, 0.68, 0.25), k))
	_grass_mat.set_shader_parameter("root_color", Color(0.38, 0.35, 0.18).lerp(Color(0.2, 0.45, 0.15), k))
	_grass_mat.set_shader_parameter("tip_color", Color(0.62, 0.58, 0.32).lerp(Color(0.72, 0.88, 0.28), k))
	_leaf_mat.albedo_color = Color(0.65, 0.65, 0.5).lerp(Color(1.0, 1.0, 1.0), k)
	_leaf_mat.backlight = Color(0.2, 0.22, 0.12).lerp(Color(0.4, 0.5, 0.08), k)

# ---------------------------------------------------------------- props

func _build_grass() -> void:
	var blade := ArrayMesh.new()
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var norms := PackedVector3Array()
	for b in 3:
		var ang := b * TAU / 3.0 + 0.4
		var dir := Vector3(cos(ang), 0, sin(ang))
		var side := Vector3(-dir.z, 0, dir.x) * 0.045
		var tip := dir * 0.12 + Vector3(0, 0.75 + 0.1 * b, 0)
		verts.append_array([-side, side, tip])
		uvs.append_array([Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 1)])
		for q in 3:
			norms.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	blade.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	blade.surface_set_material(0, _grass_mat)
	var xforms: Array[Transform3D] = []
	var tries := 0
	while xforms.size() < 3500 and tries < 40000:
		tries += 1
		var x := _rng.randf_range(-60.0, 60.0)
		var z := _rng.randf_range(-60.0, -17.0)
		var y := height_at(x, z)
		var dens := 0.5 + 0.5 * _noise.get_noise_2d(x * 1.7 + 9.0, z * 1.7)
		if y < 0.9 or _rng.randf() > dens * 0.9:
			continue
		var s := _rng.randf_range(0.8, 1.8)
		var tr := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(x, y - 0.03, z))
		xforms.append(tr)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = blade
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "DuneGrass"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

func _build_props() -> void:
	var props := Node3D.new()
	props.name = "Props"
	add_child(props)
	var palms := [Vector2(-34, -24), Vector2(-17, -27), Vector2(-5, -21), Vector2(9, -26), Vector2(23, -22),
		Vector2(36, -29), Vector2(-48, -30), Vector2(49, -24), Vector2(2, -38), Vector2(-26, -40)]
	for p: Vector2 in palms:
		props.add_child(_make_palm(p))
	var rocks := [Vector3(-44, 0, 8), Vector3(-47, 0, 3), Vector3(-41, 0, 14), Vector3(46, 0, 6), Vector3(43, 0, 12),
		Vector3(49, 0, 1), Vector3(-30, 0, -3), Vector3(15, 0, 12), Vector3(28, 0, -1), Vector3(-8, 0, 30)]
	for r: Vector3 in rocks:
		props.add_child(_make_rock(r))

## A cluster of 3-5 flat-shaded, warm-grey boulders (one main + smaller ones, partly sunk).
func _make_rock(at: Vector3) -> Node3D:
	var cluster := Node3D.new()
	cluster.rotation.y = _rng.randf() * TAU
	var base := _rng.randf_range(1.0, 2.1)
	var n := _rng.randi_range(3, 5)
	for i in n:
		var s := base * (1.0 if i == 0 else _rng.randf_range(0.35, 0.7))
		var mi := MeshInstance3D.new()
		mi.mesh = _rock_mesh()
		mi.material_override = _rock_mat
		mi.scale = Vector3(s * _rng.randf_range(0.9, 1.4), s * _rng.randf_range(0.6, 0.95), s * _rng.randf_range(0.9, 1.2))
		mi.rotation.y = _rng.randf() * TAU
		var off := Vector3.ZERO if i == 0 else Vector3.RIGHT.rotated(Vector3.UP, _rng.randf() * TAU) * base * _rng.randf_range(0.9, 1.5)
		mi.position = off + Vector3(0, 0.12 * s, 0)
		cluster.add_child(mi)
	cluster.position = Vector3(at.x, height_at(at.x, at.z) - 0.05, at.z)
	return cluster

## One faceted boulder: low-poly sphere, jittered, flattened bottom, per-face warm-grey tint (lighter on top).
func _rock_mesh() -> ArrayMesh:
	var sm := SphereMesh.new()
	sm.radial_segments = 8
	sm.rings = 5
	var arr := sm.get_mesh_arrays()
	var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ii: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var jitter := {}
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var warm := Color(0.7, 0.62, 0.46)
	var cool := Color(0.46, 0.4, 0.3)
	for t in range(0, ii.size(), 3):
		var face_tint := _rng.randf_range(0.0, 1.0)
		var pts: Array[Vector3] = []
		for k in 3:
			var p := vv[ii[t + k]]
			var key := Vector3i((p * 100.0).round())
			if not jitter.has(key):
				jitter[key] = 1.0 + _rng.randf_range(-0.22, 0.22)
			p *= float(jitter[key])
			p.y = maxf(p.y, -0.25)
			pts.append(p)
		var cy := (pts[0].y + pts[1].y + pts[2].y) / 3.0
		var c := cool.lerp(warm, clampf(0.5 + cy * 1.1, 0.0, 1.0)).lerp(Color(0.6, 0.53, 0.4), face_tint * 0.35)
		for p in pts:
			st.set_color(c)
			st.add_vertex(p)
	st.generate_normals()
	return st.commit()

func _make_palm(at: Vector2) -> Node3D:
	var palm := Node3D.new()
	palm.position = Vector3(at.x, height_at(at.x, at.y) - 0.1, at.y)
	palm.rotation.y = _rng.randf() * TAU
	var height := _rng.randf_range(5.0, 7.5)
	var lean := _rng.randf_range(0.8, 2.2)
	# trunk: a banded, tapered, curved tube
	var rings := 25
	var sides := 8
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centers: Array[Vector3] = []
	for r in rings:
		var t := float(r) / (rings - 1)
		centers.append(Vector3(lean * t * t, height * t, 0.0))
	for r in rings - 1:
		for s in sides:
			var a0 := TAU * s / sides
			var a1 := TAU * (s + 1) / sides
			# ring bands: every other ring bulges slightly and is lighter tan
			var r0 := lerpf(0.32, 0.17, float(r) / (rings - 1)) * (1.0 + 0.09 * float(r % 2))
			var r1 := lerpf(0.32, 0.17, float(r + 1) / (rings - 1)) * (1.0 + 0.09 * float((r + 1) % 2))
			var c := Color(0.5, 0.52, 0.46) if r % 2 == 0 else Color(0.27, 0.28, 0.26)
			c = c.lightened(0.04 * sin(float(s) * 2.7 + float(r)))
			var p00 := centers[r] + Vector3(cos(a0), 0, sin(a0)) * r0
			var p01 := centers[r] + Vector3(cos(a1), 0, sin(a1)) * r0
			var p10 := centers[r + 1] + Vector3(cos(a0), 0, sin(a0)) * r1
			var p11 := centers[r + 1] + Vector3(cos(a1), 0, sin(a1)) * r1
			for v: Vector3 in [p00, p10, p01, p01, p10, p11]:
				st.set_color(c)
				st.add_vertex(v)
	st.generate_normals()
	var trunk := MeshInstance3D.new()
	trunk.mesh = st.commit()
	trunk.material_override = _trunk_mat
	palm.add_child(trunk)
	# crown of curved fronds
	var leaf := _leaf_mesh()
	var crown := centers[rings - 1] + Vector3(0, 0.1, 0)
	var n := 10
	for i in n:
		var mi := MeshInstance3D.new()
		mi.mesh = leaf
		mi.material_override = _leaf_mat
		mi.position = crown
		var sc := _rng.randf_range(0.85, 1.2)
		mi.scale = Vector3(sc, sc, sc)
		mi.rotation = Vector3(0, TAU * i / n + _rng.randf_range(-0.2, 0.2), 0)
		mi.rotate_object_local(Vector3.FORWARD, 0.0)
		# tilt the frond up/down around its local z
		mi.rotate_object_local(Vector3(0, 0, 1), _rng.randf_range(-0.45, 0.3))
		palm.add_child(mi)
	return palm

var _leaf_cache: ArrayMesh

func _leaf_mesh() -> ArrayMesh:
	if _leaf_cache:
		return _leaf_cache
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 9
	var length := 3.6
	var pts_l: Array[Vector3] = []
	var pts_m: Array[Vector3] = []
	var pts_r: Array[Vector3] = []
	var cols: Array[Color] = []
	for i in segs + 1:
		var t := float(i) / segs
		var x := t * length
		var y := 1.1 * t - 1.7 * t * t  # arcs up then droops
		var w := 0.55 * sin(PI * pow(t, 0.75)) + 0.03
		pts_m.append(Vector3(x, y + 0.06, 0))
		pts_l.append(Vector3(x - 0.1 * t, y - 0.1 * w, -w))
		pts_r.append(Vector3(x - 0.1 * t, y - 0.1 * w, w))
		cols.append(Color(0.12, 0.38, 0.12).lerp(Color(0.45, 0.8, 0.22), t))
	for i in segs:
		for side in 2:
			var edge: Array[Vector3] = pts_l if side == 0 else pts_r
			var q := [pts_m[i], edge[i], pts_m[i + 1], pts_m[i + 1], edge[i], edge[i + 1]]
			if side == 1:
				q = [pts_m[i], pts_m[i + 1], edge[i], pts_m[i + 1], edge[i + 1], edge[i]]
			var cc := [cols[i], cols[i], cols[i + 1], cols[i + 1], cols[i], cols[i + 1]]
			if side == 1:
				cc = [cols[i], cols[i + 1], cols[i], cols[i + 1], cols[i + 1], cols[i]]
			for v in 6:
				st.set_color(cc[v])
				st.add_vertex(q[v])
	st.generate_normals()
	_leaf_cache = st.commit()
	return _leaf_cache
