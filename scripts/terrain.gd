@tool
extends MeshInstance3D
## Beach terrain: the height function (owns `shore_z` / `height_at`; Beach delegates to it), the baked sand mesh
## (assets/meshes/terrain.res) and, at run time, its trimesh collision.
## Change the height function, then press "Bake mesh" in the inspector (and "Scatter" on DuneGrass).

const X_MIN := -70.0
const X_MAX := 70.0
const Z_MIN := -80.0
const Z_MAX := 70.0
const STEP := 1.0
const MESH_PATH := "res://assets/meshes/terrain.res"

@export_tool_button("Bake mesh") var _bake_btn := bake

## Boardwalk centre line (x, z), beach end first. Boardwalk.path_points defaults to this; the dune channel follows it.
const PATH: Array[Vector2] = [Vector2(-10.2, -18.0), Vector2(-11.0, -21.0), Vector2(-9.5, -29.0), Vector2(-10.0, -34.5)]
const CHANNEL_TAIL := Vector2(-10.0, -52.0)  # the channel runs on behind the walk's end (the truck is parked there)
const CHANNEL_IN := 3.5   # within this distance of PATH the dunes are flattened
const CHANNEL_OUT := 13.0  # beyond this the dunes are full height
## Flat pad kept free of dunes around the shack (x, z; stretched 1.3x along x).
const SHACK_PAD := Vector2(15.0, -19.7)
const SHACK_PAD_R := 7.5
## Truck parking spot (x, z) and its ground height; stretched 2.2x along z.
const PARK := Vector2(-10.0, -38.3)
const PARK_Y := 1.35

var _noise: FastNoiseLite
var _dnoise: FastNoiseLite

func _ready() -> void:
	if not Engine.is_editor_hint() and mesh:
		var body := StaticBody3D.new()
		body.name = "TerrainBody"
		var cs := CollisionShape3D.new()
		cs.shape = mesh.create_trimesh_shape()
		body.add_child(cs)
		add_child(body)

func get_noise() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 11
		_noise.frequency = 0.05
	return _noise

func _dune_noise() -> FastNoiseLite:
	if _dnoise == null:
		_dnoise = FastNoiseLite.new()
		_dnoise.seed = 29
		_dnoise.frequency = 0.035
		_dnoise.fractal_octaves = 3
	return _dnoise

## World z of the shoreline at x.
func shore_z(x: float) -> float:
	return 2.5 * sin(x * 0.07) + 1.5 * sin(x * 0.19 + 1.0)

## Distance (m) from (x, z) to the walk-through-the-dunes centre line (PATH).
func path_dist(x: float, z: float) -> float:
	var q := Vector2(x, z)
	var best := 1e9
	for i in PATH.size() - 1:
		best = minf(best, Geometry2D.get_closest_point_to_segment(q, PATH[i], PATH[i + 1]).distance_to(q))
	return minf(best, Geometry2D.get_closest_point_to_segment(q, PATH[PATH.size() - 1], CHANNEL_TAIL).distance_to(q))

func height_at(x: float, z: float) -> float:
	var zs := z - shore_z(x)
	var land := -zs * 0.045
	var sea := -zs * 0.14
	var h := lerpf(land, sea, smoothstep(-2.0, 2.0, zs))
	h = maxf(h, -5.0 + 0.5 * h) if zs > 0.0 else h
	var n := get_noise().get_noise_2d(x, z)
	# soft sand undulation on dry land
	h += n * 0.1 * smoothstep(4.0, -4.0, zs)
	# rolling dune ridges at the back: crests run roughly along the shore (meandering), a few m high, with steep
	# flanks; the path channel, the shack pad and the parking spot behind the start stay low
	var dn := _dune_noise()
	var ramp := smoothstep(-15.0, -28.0, zs)
	var wave := 0.5 + 0.5 * sin(zs * 0.23 + x * 0.04 + 3.0 * dn.get_noise_2d(x * 0.8, z * 0.8))
	var ridge := pow(wave, 1.5)
	var dunes := ramp * (1.3 + 3.3 * ridge + 1.0 * dn.get_noise_2d(x * 1.3 + 50.0, z * 1.3) + 0.6 * n)
	var keep_low := smoothstep(SHACK_PAD_R + 8.0, SHACK_PAD_R, Vector2((x - SHACK_PAD.x) / 1.3, z - SHACK_PAD.y).length())
	var channel := smoothstep(CHANNEL_OUT, CHANNEL_IN, path_dist(x, z)) * smoothstep(-60.0, -49.0, z)
	h += dunes * (1.0 - keep_low) * (1.0 - 0.9 * channel)
	# flat parking spot for the pickup truck behind the start
	h = lerpf(h, PARK_Y, smoothstep(7.0, 3.6, Vector2((x - PARK.x), (z - PARK.y) / 2.2).length()))
	# headlands at both ends close the bay
	var e := smoothstep(40.0, 66.0, absf(x))
	h += e * (3.0 + 2.0 * n) * smoothstep(14.0, -6.0, zs)
	# fade the far back to flat so the map has an edge
	h -= smoothstep(-55.0, -78.0, z) * 3.5
	return h

## Builds the 1 m grid mesh from height_at, saves it to MESH_PATH and assigns it.
func bake() -> void:
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
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	ResourceSaver.save(m, MESH_PATH)
	m.take_over_path(MESH_PATH)
	mesh = m
