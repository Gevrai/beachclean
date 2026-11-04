extends RefCounted
## Primitive-mesh models of the catalog items (cute, colourful). build(id, rng) -> Node3D at real size,
## lying pose baked in, origin = centre of the item; meta "rest" = height of the centre above the ground.
## upright=true stands lying things up (used for icons on the bins).

static var _mats: Dictionary = {}

static func _mat(c: Color, rough := 0.35, metal := 0.0, glow := 0.3) -> StandardMaterial3D:
	var key := "%s%s%s%s" % [c.to_html(), rough, metal, glow]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		m.metallic = metal
		m.emission_enabled = glow > 0.0
		m.emission = c
		m.emission_energy_multiplier = glow
		_mats[key] = m
	return _mats[key]

static func _part(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi

static func _cyl(r_top: float, r_bot: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = 14
	c.rings = 1
	return c

static func _ball() -> SphereMesh:
	var s := SphereMesh.new()  # diameter 1: scale = full size
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 16
	s.rings = 8
	return s

static func _torus(ring_r: float, tube_r: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = ring_r - tube_r
	t.outer_radius = ring_r + tube_r
	t.rings = 16
	t.ring_segments = 8
	return t

static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

static func _pick(rng: RandomNumberGenerator, cols: Array) -> Color:
	return cols[rng.randi() % cols.size()]

## Uniform per-item factor from the raw (cartoon-sized) primitives to real size; see Catalog "cm".
const K := {"cap": 0.17, "bag": 0.6, "can": 0.5, "pbottle": 0.72, "flipflop": 0.55, "gbottle": 0.54, "bucket": 0.65, "rope": 0.9}

## Cylinder between two points (local space), r = radius.
static func _link(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material, r_b := -1.0) -> MeshInstance3D:
	var d := b - a
	var mi := _part(parent, _cyl(r, r if r_b < 0.0 else r_b, d.length()), mat, (a + b) * 0.5)
	mi.basis = Basis(Quaternion(Vector3.UP, d.normalized()))
	return mi

static func build(id: String, rng: RandomNumberGenerator, upright := false) -> Node3D:
	var inner := _raw(id, rng, upright)
	var k: float = K.get(id, 1.0)
	inner.scale = Vector3.ONE * k
	var outer := Node3D.new()
	outer.add_child(inner)
	outer.set_meta("rest", float(inner.get_meta("rest")) * k)
	return outer

static func _raw(id: String, rng: RandomNumberGenerator, upright: bool) -> Node3D:
	var root := Node3D.new()
	var rest := 0.03
	var lay := Node3D.new()  # pivot that lays bottle-like things on their side
	root.add_child(lay)
	lay.rotation.x = 0.0 if upright else PI / 2.0
	match id:
		"cap":
			var c := _pick(rng, [Color(0.95, 0.15, 0.2), Color(0.1, 0.45, 1.0), Color(1.0, 0.8, 0.05), Color(0.1, 0.85, 0.4)])
			_part(root, _cyl(0.085, 0.09, 0.035), _mat(c))
			_part(root, _cyl(0.07, 0.07, 0.01), _mat(c.lightened(0.35)), Vector3(0, 0.02, 0))
			rest = 0.012
			if upright:
				root.rotation.x = PI / 2.0
		"straw":  # 20 cm x 6 mm, real size (K = 1)
			var c := _pick(rng, [Color(1.0, 0.3, 0.55), Color(0.1, 0.8, 0.85), Color(1.0, 0.8, 0.1)])
			for i in 4:
				_part(root, _cyl(0.003, 0.003, 0.04), _mat(c if i % 2 == 0 else Color(1, 1, 1)), Vector3(-0.1 + i * 0.04 + 0.02, 0, 0), Vector3(0, 0, PI / 2.0))
			_link(root, Vector3(0.06, 0, 0), Vector3(0.1, 0, 0.03), 0.003, _mat(c))
			rest = 0.004
		"bag":
			var c := _pick(rng, [Color(0.85, 0.95, 1.0), Color(1.0, 0.92, 0.6), Color(1.0, 0.8, 0.88)])
			_part(root, _ball(), _mat(c, 0.2, 0.0, 0.3), Vector3.ZERO, Vector3.ZERO, Vector3(0.3, 0.07, 0.22))
			_part(root, _ball(), _mat(c, 0.2, 0.0, 0.3), Vector3(-0.05, 0.02, 0.05), Vector3(0, 0.6, 0), Vector3(0.16, 0.08, 0.14))
			_part(root, _box(Vector3(0.1, 0.004, 0.17)), _mat(Color(1.0, 0.35, 0.4)), Vector3(0.02, 0.034, 0), Vector3(0, 0.15, 0))
			for s in [-1, 1]:  # handles
				_part(root, _torus(0.035, 0.007), _mat(c, 0.2), Vector3(0.14, 0.03, s * 0.045), Vector3(0.4 * s, 0, PI / 2.0 - 0.6))
			rest = 0.02
		"can":
			var c := _pick(rng, [Color(0.95, 0.12, 0.18), Color(0.12, 0.55, 1.0), Color(0.15, 0.85, 0.35)])
			_part(lay, _cyl(0.06, 0.06, 0.2), _mat(c, 0.25, 0.4, 0.3))
			_part(lay, _cyl(0.052, 0.06, 0.02), _mat(Color(0.85, 0.88, 0.92), 0.2, 0.8, 0.3), Vector3(0, 0.105, 0))
			_part(lay, _cyl(0.06, 0.052, 0.02), _mat(Color(0.85, 0.88, 0.92), 0.2, 0.8, 0.3), Vector3(0, -0.105, 0))
			_part(lay, _cyl(0.062, 0.062, 0.05), _mat(Color(1, 1, 1)))
			rest = 0.035
		"pbottle":
			var c := _pick(rng, [Color(0.1, 0.85, 1.0), Color(0.55, 0.95, 0.35), Color(1.0, 0.45, 0.85)])
			var m := _mat(c, 0.15, 0.0, 0.35)
			_part(lay, _cyl(0.062, 0.062, 0.18), m, Vector3(0, -0.04, 0))
			_part(lay, _cyl(0.025, 0.062, 0.07), m, Vector3(0, 0.085, 0))
			_part(lay, _cyl(0.025, 0.025, 0.05), m, Vector3(0, 0.145, 0))
			_part(lay, _cyl(0.03, 0.03, 0.03), _mat(Color(1.0, 0.95, 0.9)), Vector3(0, 0.185, 0))
			_part(lay, _cyl(0.064, 0.064, 0.06), _mat(Color(1, 1, 1)), Vector3(0, -0.04, 0))
			rest = 0.04
		"flipflop":
			var c := _pick(rng, [Color(1.0, 0.35, 0.6), Color(1.0, 0.8, 0.15), Color(0.2, 0.85, 0.9)])
			_part(root, _ball(), _mat(c.darkened(0.15), 0.6), Vector3.ZERO, Vector3.ZERO, Vector3(0.2, 0.035, 0.46))
			_part(root, _ball(), _mat(c.lightened(0.3), 0.6), Vector3(0, 0.014, 0), Vector3.ZERO, Vector3(0.17, 0.03, 0.42))
			var strap := _mat(Color(1, 1, 1), 0.5)
			var toe := Vector3(0, 0.04, -0.1)
			for s in [-1, 1]:
				var to := Vector3(s * 0.07, 0.04, 0.02)
				var d := to - toe
				_part(root, _box(Vector3(0.016, 0.016, d.length())), strap, (toe + to) * 0.5, Vector3(0, atan2(d.x, d.z), 0))
			rest = 0.02
			if upright:
				root.rotation.x = PI / 2.0
		"gbottle":
			var m := _mat(Color(0.8, 0.42, 0.08), 0.12, 0.0, 0.25)
			lay.scale = Vector3.ONE * 1.25
			_part(lay, _cyl(0.055, 0.055, 0.2), m, Vector3(0, -0.05, 0))
			_part(lay, _cyl(0.024, 0.055, 0.07), m, Vector3(0, 0.085, 0))
			_part(lay, _cyl(0.024, 0.024, 0.08), m, Vector3(0, 0.16, 0))
			_part(lay, _cyl(0.03, 0.03, 0.02), _mat(Color(0.95, 0.8, 0.2), 0.3, 0.6), Vector3(0, 0.21, 0))
			_part(lay, _cyl(0.057, 0.057, 0.08), _mat(Color(1.0, 0.95, 0.8)), Vector3(0, -0.05, 0))
			rest = 0.065
		"bucket":
			var c := _pick(rng, [Color(1.0, 0.25, 0.3), Color(1.0, 0.8, 0.1), Color(0.2, 0.7, 1.0)])
			var tilt := Node3D.new()
			root.add_child(tilt)
			tilt.rotation.x = 0.25
			_part(tilt, _cyl(0.125, 0.09, 0.16), _mat(c, 0.4, 0.0, 0.3))
			_part(tilt, _cyl(0.113, 0.1, 0.04), _mat(Color(1, 1, 1)), Vector3(0, -0.01, 0))
			_part(tilt, _torus(0.128, 0.012), _mat(c.lightened(0.2)), Vector3(0, 0.08, 0))
			_part(tilt, _cyl(0.108, 0.108, 0.004), _mat(Color(0.5, 0.38, 0.24), 0.9, 0.0, 0.0), Vector3(0, 0.079, 0))
			_part(tilt, _torus(0.11, 0.007), _mat(Color(0.95, 0.95, 0.95)), Vector3(0, 0.08, 0), Vector3(0, 0, PI / 2.0))
			rest = 0.07
		"rope":
			var orange := _mat(Color(1.0, 0.4, 0.3), 0.6, 0.0, 0.35)
			var pink := _mat(Color(1.0, 0.2, 0.55), 0.6, 0.0, 0.35)
			for i in 5:
				var t := TorusMesh.new()
				t.inner_radius = 0.17 + rng.randf() * 0.08
				t.outer_radius = t.inner_radius + 0.035
				t.rings = 14
				t.ring_segments = 6
				_part(root, t, orange if i % 2 == 0 else pink, Vector3(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.01, 0.04), rng.randf_range(-0.12, 0.12)),
					Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3)))
			_part(root, _cyl(0.02, 0.02, 0.5), pink, Vector3(0.05, -0.04, 0.0), Vector3(0.0, 0.0, PI / 2.0 + 0.3))
			_part(root, _cyl(0.025, 0.025, 0.4), _mat(Color(0.2, 0.85, 0.5)), Vector3(-0.05, -0.04, 0.1), Vector3(PI / 2.0, 0.5, 0.0))
			_part(root, _cyl(0.045, 0.045, 0.06), _mat(Color(1.0, 0.9, 0.1)), Vector3(0.15, -0.03, -0.1), Vector3(PI / 2.0, 0.9, 0.0))
			rest = 0.08
		"hose":  # ~30 cm coil + tail with brass fitting and orange nozzle, real size (K = 1)
			var g := _mat(Color(0.15, 0.78, 0.3), 0.4, 0.0, 0.3)
			_part(root, _torus(0.13, 0.02), g, Vector3(0, 0.0, 0))
			_part(root, _torus(0.12, 0.02), g, Vector3(0, 0.036, 0))
			var p0 := Vector3(0.13, 0.0, 0.0)
			var p1 := Vector3(0.21, 0.0, 0.05)
			var dir := (p1 - p0).normalized()
			_link(root, p0, p1, 0.02, g)
			_link(root, p1, p1 + dir * 0.05, 0.026, _mat(Color(1.0, 0.8, 0.1), 0.3, 0.5))
			_link(root, p1 + dir * 0.05, p1 + dir * 0.1, 0.03, _mat(Color(1.0, 0.45, 0.15)), 0.014)
			rest = 0.02
	root.set_meta("rest", rest)
	return root
