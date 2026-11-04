@tool
extends Node3D
## Weathered boardwalk through the dunes with rope-and-post fences (baked to assets/meshes/boardwalk.res).
## Edit `path_points` (x, z world positions; the walk follows the terrain) and press "Bake mesh". Lives under Beach
## (needs its height_at). DuneGrass keeps a corridor of `half_width` + margin clear along the same polyline.

const MESH_PATH := "res://assets/meshes/boardwalk.res"

@export var path_points := PackedVector2Array([Vector2(-9, -12), Vector2(-11, -21), Vector2(-9.5, -29), Vector2(-10, -37)])
@export var half_width := 0.8
@export var post_spacing := 3.0
@export var seed_value := 3
@export_tool_button("Bake mesh") var _bake_btn := bake

var _verts := PackedVector3Array()
var _norms := PackedVector3Array()
var _cols := PackedColorArray()
var _idx := PackedInt32Array()

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

func _box(center: Vector3, basis: Basis, size: Vector3, col: Color) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT]]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var r: Vector3 = f[2]
		var b := _verts.size()
		for c in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
			_verts.append(center + basis * ((n + u * c[1] + r * c[0]) * h))
			_norms.append((basis * n).normalized())
			_cols.append(col)
		_idx.append_array([b, b + 1, b + 2, b, b + 2, b + 3])

func bake() -> void:
	var beach := get_parent()
	if beach == null or not beach.has_method("height_at") or path_points.size() < 2:
		push_warning("Boardwalk: needs a parent with height_at and >= 2 path points")
		return
	_verts.clear()
	_norms.clear()
	_cols.clear()
	_idx.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var total := _length()
	# planks
	var d := 0.3
	while d < total:
		var sm := _sample(d)
		var pos: Vector2 = sm[0]
		var tan2: Vector2 = sm[1]
		var plen := rng.randf_range(0.36, 0.5)
		var ahead: Vector2 = pos + tan2 * 0.3
		var behind: Vector2 = pos - tan2 * 0.3
		var y: float = beach.height_at(pos.x, pos.y) + 0.035
		var pitch := atan2(beach.height_at(ahead.x, ahead.y) - beach.height_at(behind.x, behind.y), 0.6)
		var yaw := atan2(-tan2.x, -tan2.y) + rng.randf_range(-0.02, 0.02)  # -Z of the plank along the path
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
		var col := _wood(rng, 0.55, 1.05)
		var w := half_width * 2.0 * rng.randf_range(0.97, 1.03)
		_box(Vector3(pos.x, y, pos.y), basis, Vector3(w, 0.05, plen), col)
		d += plen + rng.randf_range(0.03, 0.05)
	# fence posts on both sides, rope between neighbours
	var tops: Array[Array] = [[], []]
	var pd := 1.2
	while pd < total:
		var sm := _sample(pd)
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
			tops[s].append(Vector3(pp.x, gy + ph - 0.12, pp.y))
		pd += post_spacing
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
