@tool
extends Node3D
## Dune (marram) grass. Children (ClumpA..D, TuftE/F) are MultiMeshInstance3D, one per baked blade-clump mesh
## (assets/meshes/grass_*.res); their multimeshes (assets/meshes/grass_mm/*.res) hold the scattered instances.
## Inspector buttons: "Bake clumps" regenerates the meshes (many thin curved blades each), "Scatter" re-places
## every instance (needs the Terrain sibling; skips the shack, the Boardwalk corridor and the debris field).
## Headless: tools/bake_dunes. Look/wind: assets/shaders/grass.gdshader + assets/materials/grass.tres.

const MESH_DIR := "res://assets/meshes/"
const MM_DIR := "res://assets/meshes/grass_mm/"

## key -> clump shape. blades, radius of the root spread, blade length range (m), lean/curl (rad), blade width (m),
## weight = share of the scattered tall clumps, "tuft" = short sparse tuft for the transition to the open sand.
const VARIANTS := {
	"a": {"node": "ClumpA", "blades": 80, "r": 0.45, "lmin": 0.6, "lmax": 1.5, "lean": 0.16, "curl": 0.9, "w": 0.014, "weight": 0.3},
	"b": {"node": "ClumpB", "blades": 66, "r": 0.55, "lmin": 0.45, "lmax": 1.15, "lean": 0.3, "curl": 1.3, "w": 0.013, "weight": 0.3},
	"c": {"node": "ClumpC", "blades": 70, "r": 0.36, "lmin": 0.8, "lmax": 1.45, "lean": 0.1, "curl": 0.5, "w": 0.015, "weight": 0.2},
	"d": {"node": "ClumpD", "blades": 90, "r": 0.65, "lmin": 0.5, "lmax": 1.3, "lean": 0.4, "curl": 1.6, "w": 0.013, "weight": 0.2},
	"e": {"node": "TuftE", "blades": 20, "r": 0.18, "lmin": 0.2, "lmax": 0.5, "lean": 0.35, "curl": 1.0, "w": 0.012, "tuft": true},
	"f": {"node": "TuftF", "blades": 14, "r": 0.14, "lmin": 0.18, "lmax": 0.38, "lean": 0.5, "curl": 1.3, "w": 0.011, "tuft": true},
}
const SEGMENTS := 4

@export var terrain_path: NodePath = ^"../Terrain"
@export var boardwalk_path: NodePath = ^"../Boardwalk"
@export var clump_count := 6000
@export var tuft_count := 1300
@export var seed_value := 7
@export_tool_button("Bake clumps") var _bake_btn := bake_meshes
@export_tool_button("Scatter") var _scatter_btn := scatter

static func mesh_path(key: String) -> String:
	return MESH_DIR + "grass_%s_%s.res" % ["tuft" if VARIANTS[key].get("tuft", false) else "clump", key]

# ---------------------------------------------------------------- clump meshes

func bake_meshes() -> void:
	for key in VARIANTS:
		var mesh := _build_clump(VARIANTS[key], hash(key))
		var path: String = mesh_path(key)
		ResourceSaver.save(mesh, path)
		mesh.take_over_path(path)

func _build_clump(p: Dictionary, seed_v: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for b in int(p.blades):
		var ang := rng.randf() * TAU
		var rad: float = p.r * pow(rng.randf(), 0.8)
		var root := Vector3(cos(ang), 0.0, sin(ang)) * rad
		var inner: float = 1.0 - rad / p.r  # blades near the middle are taller and more upright
		var length: float = lerpf(p.lmin, p.lmax, clampf(rng.randf() * 0.55 + inner * 0.55, 0.0, 1.0)) * rng.randf_range(0.8, 1.0)
		var head := ang + rng.randf_range(-0.9, 0.9)  # direction the blade leans towards
		var hd := Vector3(cos(head), 0.0, sin(head))
		var theta0: float = p.lean * (0.3 + 1.2 * (1.0 - inner)) * rng.randf_range(0.4, 1.4)
		var curl: float = p.curl * rng.randf_range(-0.3, 1.0)
		var tw := head + PI * 0.5 + rng.randf_range(-0.7, 0.7)  # ribbon facing
		var side := Vector3(cos(tw), 0.0, sin(tw))
		var dry := rng.randf()
		var phase := rng.randf()
		var stiff := clampf(length / 1.3 + rng.randf_range(-0.2, 0.2), 0.0, 1.0)
		var pos := root
		var base := verts.size()
		var seg := length / SEGMENTS
		for j in SEGMENTS + 1:
			var t := float(j) / SEGMENTS
			var half: float = p.w * 0.5 * (1.0 - pow(t, 1.4)) + (0.0015 if j < SEGMENTS else 0.0)
			var th := theta0 + curl * t * t
			var tang := hd * sin(th) + Vector3.UP * cos(th)
			var n := side.cross(tang).normalized()
			for s in 2:
				verts.append(pos + side * half * (1.0 if s == 1 else -1.0))
				norms.append(n)
				uvs.append(Vector2(float(s), t))
				cols.append(Color(dry, phase, stiff, 1.0))
			var th_next := theta0 + curl * pow(t + 1.0 / SEGMENTS, 2.0)
			var th_mid := 0.5 * (th + th_next)
			pos += (hd * sin(th_mid) + Vector3.UP * cos(th_mid)) * seg
		for j in SEGMENTS:
			var k := base + j * 2
			idx.append_array([k, k + 1, k + 2, k + 1, k + 3, k + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

# ---------------------------------------------------------------- scatter

## Rough rectangle around the shack (scripts/shack.gd: x=14, 21 m behind the shore, footprint -3.2..6.9 / -2.6..3.2).
func _near_shack(x: float, z: float, terrain: Node) -> bool:
	var zc: float = terrain.shore_z(14.0) - 21.0
	return x > 14.0 - 6.0 and x < 14.0 + 10.0 and z > zc - 6.0 and z < zc + 7.0

## Rough rectangle around the parked pickup truck behind the start (scenes/props/pickup_truck.tscn at x -10, z -38).
func _near_truck(x: float, z: float) -> bool:
	return x > -12.4 and x < -7.6 and z > -41.8 and z < -35.4

## Distance from (x, z) to the Boardwalk centre line (large when there is none).
func _path_dist(x: float, z: float, pts: PackedVector2Array) -> float:
	var best := 1e9
	for i in pts.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(Vector2(x, z), pts[i], pts[i + 1])
		best = minf(best, q.distance_to(Vector2(x, z)))
	return best

## [position xz, tangent xz] at arc length `dist` along the polyline, or [].
func _along(pts: PackedVector2Array, dist: float) -> Array:
	var acc := 0.0
	for i in pts.size() - 1:
		var seg := pts[i + 1] - pts[i]
		var l := seg.length()
		if dist <= acc + l:
			return [pts[i] + seg * ((dist - acc) / l), seg / l]
		acc += l
	return []

func scatter() -> void:
	var terrain := get_node(terrain_path)
	var pts := PackedVector2Array()
	var clear_w := 0.0
	if has_node(boardwalk_path):
		pts = get_node(boardwalk_path).path_points
		clear_w = get_node(boardwalk_path).half_width
	var patch_noise := FastNoiseLite.new()
	patch_noise.seed = 21
	patch_noise.frequency = 0.09
	var dry_noise := FastNoiseLite.new()
	dry_noise.seed = 5
	dry_noise.frequency = 0.04
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var keys: Array = VARIANTS.keys()
	var clump_keys: Array = keys.filter(func(k): return not VARIANTS[k].get("tuft", false))
	var tuft_keys: Array = keys.filter(func(k): return VARIANTS[k].get("tuft", false))
	var items := {}  # key -> Array of [Transform3D, Color]
	for k in keys:
		items[k] = []
	# tall dense mounds on both sides of the boardwalk (the first view is framed by them); the walk itself stays clear
	var n_mound := 0
	var walk_len := 0.0
	for i in pts.size() - 1:
		walk_len += pts[i].distance_to(pts[i + 1])
	var arc := 0.0
	while arc < walk_len and pts.size() > 1:
		arc += rng.randf_range(1.2, 2.0)
		var at := _along(pts, arc)
		if at.is_empty():
			break
		var tang: Vector2 = at[1]
		var nrm := Vector2(-tang.y, tang.x)
		for side in [-1.0, 1.0]:
			var c: Vector2 = at[0] + nrm * side * rng.randf_range(2.6, 5.5)
			if c.y - terrain.shore_z(c.x) > -17.0 or _near_shack(c.x, c.y, terrain):
				continue
			for m in rng.randi_range(14, 22):
				var q := c + Vector2(rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0))
				var zs_q: float = q.y - terrain.shore_z(q.x)
				var yq: float = terrain.height_at(q.x, q.y)
				if zs_q > -17.0 or yq < 0.6 or _near_truck(q.x, q.y) or _path_dist(q.x, q.y, pts) < clear_w + 1.0:
					continue
				var sq := rng.randf_range(0.95, 1.4) * lerpf(0.8, 1.1, smoothstep(-17.0, -26.0, zs_q))
				var bq := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.12, 0.12))
				bq = bq.scaled(Vector3(sq, sq * rng.randf_range(0.9, 1.15), sq))
				var kq: String = ["a", "a", "c", "b", "d"][rng.randi() % 5]
				var dq := clampf(0.45 + dry_noise.get_noise_2d(q.x, q.y) * 0.9 + rng.randf_range(-0.25, 0.25), 0.0, 1.0)
				items[kq].append([Transform3D(bq, Vector3(q.x, yq - 0.04, q.y)), Color(dq, rng.randf(), 0.0, 1.0)])
				n_mound += 1
	var n_clump := 0
	var n_tuft := 0
	var tries := 0
	while (n_clump < clump_count or n_tuft < tuft_count) and tries < (clump_count + tuft_count) * 40:
		tries += 1
		var x := rng.randf_range(-62.0, 62.0)
		var z := rng.randf_range(-74.0, -8.0)
		var zs: float = z - terrain.shore_z(x)
		var y: float = terrain.height_at(x, z)
		if y < 0.6 or _near_shack(x, z, terrain) or _near_truck(x, z):
			continue
		var d := _path_dist(x, z, pts)
		var patch := 0.5 + 0.5 * patch_noise.get_noise_2d(x, z)
		# dense on the dunes (debris never lies behind zs -26), bare patches between, thinning towards the beach
		var dune := smoothstep(-21.0, -29.0, zs)
		var is_tuft := rng.randf() < float(tuft_count) / (clump_count + tuft_count)
		var key: String
		var prob: float
		var s: float
		if is_tuft:
			if n_tuft >= tuft_count or d < clear_w + 0.3:
				continue
			# sparse scattered tufts on the upper sand and in the gaps between clumps
			prob = smoothstep(-11.0, -17.0, zs) * smoothstep(-32.0, -20.0, zs) * 0.5 + dune * 0.35
			prob *= 0.4 + patch
			key = tuft_keys[rng.randi() % tuft_keys.size()]
			s = rng.randf_range(0.8, 1.3)
		else:
			if n_clump >= clump_count or d < clear_w + 0.9:
				continue
			prob = dune * smoothstep(0.05, 0.3, patch)
			# a few early clumps on the upper sand next to the tufts
			prob += smoothstep(-24.0, -17.0, zs) * smoothstep(-8.0, -17.0, zs) * 0.05 * patch
			var roll := rng.randf()
			key = clump_keys[0]
			for ck in clump_keys:
				roll -= VARIANTS[ck].weight
				if roll <= 0.0:
					key = ck
					break
			s = rng.randf_range(0.8, 1.45) * lerpf(0.85, 1.2, dune)
		if rng.randf() > prob:
			continue
		var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.12, 0.12))
		basis = basis.scaled(Vector3(s, s * rng.randf_range(0.85, 1.2), s))
		var dryness := clampf(0.5 + dry_noise.get_noise_2d(x, z) * 0.9 + rng.randf_range(-0.25, 0.25) - patch * 0.1, 0.0, 1.0)
		items[key].append([Transform3D(basis, Vector3(x, y - 0.04, z)), Color(dryness, rng.randf(), 0.0, 1.0)])
		if is_tuft:
			n_tuft += 1
		else:
			n_clump += 1
	DirAccess.make_dir_recursive_absolute(MM_DIR)
	for k in keys:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = load(mesh_path(k))
		var list: Array = items[k]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i][0])
			mm.set_instance_custom_data(i, list[i][1])
		var path: String = MM_DIR + str(k) + ".res"
		ResourceSaver.save(mm, path)
		mm.take_over_path(path)
		var node := get_node_or_null(VARIANTS[k].node) as MultiMeshInstance3D
		if node:
			node.multimesh = mm
	print("dune grass: %d clumps (+%d boardwalk mounds), %d tufts" % [n_clump, n_mound, n_tuft])
