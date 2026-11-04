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

var _noise: FastNoiseLite

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

## World z of the shoreline at x.
func shore_z(x: float) -> float:
	return 2.5 * sin(x * 0.07) + 1.5 * sin(x * 0.19 + 1.0)

func height_at(x: float, z: float) -> float:
	var zs := z - shore_z(x)
	var land := -zs * 0.045
	var sea := -zs * 0.14
	var h := lerpf(land, sea, smoothstep(-2.0, 2.0, zs))
	h = maxf(h, -5.0 + 0.5 * h) if zs > 0.0 else h
	var n := get_noise().get_noise_2d(x, z)
	# soft sand undulation on dry land
	h += n * 0.1 * smoothstep(4.0, -4.0, zs)
	# dunes at the back
	var d := smoothstep(-15.0, -32.0, zs)
	h += d * (1.0 + 1.6 * (0.5 + 0.5 * get_noise().get_noise_2d(x * 0.6 + 50.0, z * 0.6)) + 1.2 * n)
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
