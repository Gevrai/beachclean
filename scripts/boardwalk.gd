@tool
extends Node3D
## Weathered boardwalk through the dunes with rope-and-post fences (baked to assets/meshes/boardwalk.res).
## Edit `path_points` (x, z world positions, beach end first; the walk follows the terrain) and press "Bake mesh".
## The fence starts where the dense grass starts; the first `swallow_length` m at the beach end are swallowed by
## sand: planks sink, tilt, some are missing, a sand drift mesh (boardwalk_drift.res, sand material) covers them
## and no fence stands there. Fence posts and ropes also bake a collision shape (Fence/Shape) so you cannot walk
## through them. Lives under Beach (needs its height_at). DuneGrass keeps a corridor of `half_width` + margin clear.

const MESH_PATH := "res://assets/meshes/boardwalk.res"
const DRIFT_PATH := "res://assets/meshes/boardwalk_drift.res"
const FENCE_SHAPE_PATH := "res://assets/meshes/boardwalk_fence_shape.res"

@export var path_points := PackedVector2Array(preload("res://scripts/terrain.gd").PATH)
@export var half_width := 0.8
@export var post_spacing := 3.0
@export var seed_value := 3
@export var swallow_length := 4.5  ## m of the beach end buried in sand (planks sink/tilt/vanish, no fence)
@export_tool_button("Bake mesh") var _bake_btn := bake

var _verts := PackedVector3Array()
var _norms := PackedVector3Array()
var _cols := PackedColorArray()
var _idx := PackedInt32Array()
var _cv := PackedVector3Array()  # collision geometry (fence only)
var _ci := PackedInt32Array()

func _sample(dist: float) -> Array:  # -> [position xz, tangent xz] at arc length dist along the polyline, or []
	var acc := 0.0
	for i in path_points.size() - 1:
		var seg := path_points[i + 1] - path_points[i]
		var l := seg.length()
		if dist <= acc + l:
			return [path_points[i] + seg * ((dist - acc) / l), seg / l]
		acc += l
	return []

## True if world point p is on the walk (or within margin of its edge).
func near(p: Vector3, margin := 0.0) -> bool:
	var q := Vector2(p.x, p.z)
	for i in path_points.size() - 1:
		if Geometry2D.get_closest_point_to_segment(q, path_points[i], path_points[i + 1]).distance_to(q) < half_width + margin:
			return true
	return false

func _length() -> float:
	var l := 0.0
	for i in path_points.size() - 1:
		l += path_points[i].distance_to(path_points[i + 1])
	return l

## Weathered grey-brown wood, each piece a little different (brightness range lo..hi).
func _wood(rng: RandomNumberGenerator, lo: float, hi: float) -> Color:
	var warm := Color(0.46, 0.3, 0.15)
	var grey := Color(0.34, 0.29, 0.23)
	return warm.lerp(grey, rng.randf_range(0.1, 0.45)) * rng.randf_range(lo, hi)

func _box(center: Vector3, basis: Basis, size: Vector3, col: Color, collide := false) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT]]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var r: Vector3 = f[2]
		var b := _cv.size() if collide else _verts.size()
		for c in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
			var v: Vector3 = center + basis * ((n + u * c[1] + r * c[0]) * h)
			if collide:
				_cv.append(v)
			else:
				_verts.append(v)
				_norms.append((basis * n).normalized())
				_cols.append(col)
		(_ci if collide else _idx).append_array([b, b + 1, b + 2, b, b + 2, b + 3])

func bake() -> void:
	var beach := get_parent()
	if beach == null or not beach.has_method("height_at") or path_points.size() < 2:
		push_warning("Boardwalk: needs a parent with height_at and >= 2 path points")
		return
	_verts.clear()
	_norms.clear()
	_cols.clear()
	_idx.clear()
	_cv.clear()
	_ci.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var total := _length()
	# planks (the beach-end ones are being swallowed by the sand)
	var d := 0.3
	while d < total:
		var sm := _sample(d)
		var pos: Vector2 = sm[0]
		var tan2: Vector2 = sm[1]
		var plen := rng.randf_range(0.36, 0.5)
		var bury := clampf(1.0 - d / swallow_length, 0.0, 1.0)  # 1 at the very end, 0 where the fence starts
		bury = bury * bury * (3.0 - 2.0 * bury)
		var ahead: Vector2 = pos + tan2 * 0.3
		var behind: Vector2 = pos - tan2 * 0.3
		var pitch := atan2(beach.height_at(ahead.x, ahead.y) - beach.height_at(behind.x, behind.y), 0.6)
		var yaw := atan2(-tan2.x, -tan2.y) + rng.randf_range(-0.02, 0.02)  # -Z of the plank along the path
		var skip := d > 0.5 and rng.randf() < 0.4 * bury  # a few planks are gone
		var sink := 0.0
		var roll := 0.0
		var w := half_width * 2.0 * rng.randf_range(0.97, 1.03)
		var shift := Vector2.ZERO
		if bury > 0.0:
			sink = bury * rng.randf_range(0.02, 0.07) + (0.05 if d < 1.2 else 0.0)
			roll = rng.randf_range(-1.0, 1.0) * 0.12 * bury
			pitch += rng.randf_range(-1.0, 1.0) * 0.1 * bury
			yaw += rng.randf_range(-1.0, 1.0) * 0.12 * bury
			shift = Vector2(-tan2.y, tan2.x) * rng.randf_range(-0.12, 0.12) * bury
			if rng.randf() < 0.3 * bury:
				w *= rng.randf_range(0.6, 0.9)  # broken plank
		if not skip:
			var y: float = beach.height_at(pos.x, pos.y) + 0.035 - sink
			var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, roll)
			_box(Vector3(pos.x + shift.x, y, pos.y + shift.y), basis, Vector3(w, 0.05, plen), _wood(rng, 0.55, 1.05).lerp(Color(0.62, 0.55, 0.4), bury * 0.5))
		d += plen + rng.randf_range(0.03, 0.05)
	# fence posts on both sides (from where the dense grass starts), rope between neighbours
	var tops: Array[Array] = [[], []]
	var post_d: Array[float] = []
	var pd := swallow_length + 0.4
	while pd < total - 0.3:
		post_d.append(pd)
		pd += post_spacing
	post_d.append(total - 0.15)  # a post at the inland end
	for pdist in post_d:
		var sm := _sample(pdist)
		var pos: Vector2 = sm[0]
		var tan2: Vector2 = sm[1]
		var nrm := Vector2(-tan2.y, tan2.x)
		for s in 2:
			var side := 1.0 if s == 1 else -1.0
			var pp := pos + nrm * side * (half_width + 0.45) + Vector2(rng.randf_range(-0.1, 0.1), rng.randf_range(-0.1, 0.1))
			var gy: float = beach.height_at(pp.x, pp.y)
			var ph := rng.randf_range(0.8, 1.0)
			var lean := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.06, 0.06))
			_box(Vector3(pp.x, gy + ph * 0.5 - 0.1, pp.y), lean, Vector3(0.11, ph + 0.2, 0.11), _wood(rng, 0.9, 1.45))
			_box(Vector3(pp.x, gy + ph * 0.5 + 0.1, pp.y), Basis(), Vector3(0.2, ph + 0.4, 0.2), Color.WHITE, true)
			tops[s].append(Vector3(pp.x, gy + ph - 0.12, pp.y))
	var rope := Color(0.62, 0.52, 0.34)
	for s in 2:
		for i in tops[s].size() - 1:
			var a: Vector3 = tops[s][i]
			var b: Vector3 = tops[s][i + 1]
			var prev := a
			for k in 1 + 4:
				var t := float(k) / 4.0
				var p := a.lerp(b, t) + Vector3.DOWN * sin(t * PI) * 0.18
				var dir := p - prev
				var z := dir.normalized()
				var x := z.cross(Vector3.UP).normalized()
				var basis := Basis(x, z.cross(x).normalized(), z)
				_box((prev + p) * 0.5, basis, Vector3(0.025, 0.025, dir.length()), rope)
				_box((prev + p) * 0.5, basis, Vector3(0.1, 0.1, dir.length()), rope, true)  # low thin rope collider
				prev = p
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _verts
	arr[Mesh.ARRAY_NORMAL] = _norms
	arr[Mesh.ARRAY_COLOR] = _cols
	arr[Mesh.ARRAY_INDEX] = _idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	ResourceSaver.save(mesh, MESH_PATH)
	mesh.take_over_path(MESH_PATH)
	var mi := get_node_or_null("Mesh") as MeshInstance3D
	if mi:
		mi.mesh = mesh
	# fence collider
	var carr := []
	carr.resize(Mesh.ARRAY_MAX)
	carr[Mesh.ARRAY_VERTEX] = _cv
	carr[Mesh.ARRAY_INDEX] = _ci
	var cmesh := ArrayMesh.new()
	cmesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, carr)
	var shape := cmesh.create_trimesh_shape()
	ResourceSaver.save(shape, FENCE_SHAPE_PATH)
	shape.take_over_path(FENCE_SHAPE_PATH)
	var cs := get_node_or_null("Fence/Shape") as CollisionShape3D
	if cs:
		cs.shape = shape
	_bake_drift(beach)

## Sand drifted over the swallowed end: a low strip (sand material, world-space shader) lying on the terrain with
## soft wind-blown bumps, highest at the very end and fading out where the fence starts.
func _bake_drift(beach: Node) -> void:
	var half_w := half_width + 1.6
	var len_d := swallow_length + 1.4
	var step := 0.25
	var ns := int(ceil((len_d + 2.0) / step)) + 1
	var nt := int(ceil(half_w * 2.0 / step)) + 1
	var noise := FastNoiseLite.new()
	noise.seed = seed_value + 5
	noise.frequency = 0.9
	var start: Vector2 = path_points[0]
	var tan0: Vector2 = (path_points[1] - path_points[0]).normalized()
	var nrm0 := Vector2(-tan0.y, tan0.x)
	var verts := PackedVector3Array()
	verts.resize(ns * nt)
	for i in ns:
		var dd := -2.0 + i * step  # arc distance from the beach end (negative = beyond the end, on open sand)
		var sm := _sample(dd) if dd >= 0.0 else []
		var c: Vector2 = start + tan0 * dd if sm.is_empty() else sm[0]
		var tg: Vector2 = tan0 if sm.is_empty() else sm[1]
		var nr := Vector2(-tg.y, tg.x)
		for j in nt:
			var t := -half_w + j * step
			var q := c + nr * t
			var env_s := smoothstep(len_d, 0.5, dd) * smoothstep(-2.0, -0.2, dd)
			var env_t := smoothstep(half_w, half_w * 0.3, absf(t))
			var bump := 0.1 * env_s * env_t * (0.55 + 0.45 * noise.get_noise_2d(q.x, q.y) * 2.0)
			verts[i * nt + j] = Vector3(q.x, beach.height_at(q.x, q.y) + 0.012 + maxf(bump, 0.0), q.y)
	var norms := PackedVector3Array()
	norms.resize(ns * nt)
	var idx := PackedInt32Array()
	for i in ns:
		for j in nt:
			var a := verts[maxi(i - 1, 0) * nt + j]
			var b := verts[mini(i + 1, ns - 1) * nt + j]
			var l := verts[i * nt + maxi(j - 1, 0)]
			var r := verts[i * nt + mini(j + 1, nt - 1)]
			norms[i * nt + j] = (r - l).cross(b - a).normalized()
	for i in ns - 1:
		for j in nt - 1:
			var k := i * nt + j
			idx.append_array([k, k + nt, k + 1, k + 1, k + nt, k + nt + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	ResourceSaver.save(m, DRIFT_PATH)
	m.take_over_path(DRIFT_PATH)
	var di := get_node_or_null("Drift") as MeshInstance3D
	if di:
		di.mesh = m
