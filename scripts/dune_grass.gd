@tool
extends MultiMeshInstance3D
## Dune grass: a MultiMesh of 3-blade tufts scattered on the dunes (baked to assets/meshes/dune_grass.res).
## Press "Scatter" in the inspector to regenerate (needs the Terrain sibling). Blade mesh: assets/meshes/grass_blade.res.

const MM_PATH := "res://assets/meshes/dune_grass.res"

@export var terrain_path: NodePath = ^"../Terrain"
@export var blade_mesh: Mesh
@export var count := 3500
@export var seed_value := 7
@export_tool_button("Scatter") var _scatter_btn := scatter

func scatter() -> void:
	var terrain := get_node(terrain_path)
	var noise: FastNoiseLite = terrain.get_noise()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var xforms: Array[Transform3D] = []
	var tries := 0
	while xforms.size() < count and tries < count * 12:
		tries += 1
		var x := rng.randf_range(-60.0, 60.0)
		var z := rng.randf_range(-60.0, -17.0)
		var y: float = terrain.height_at(x, z)
		var dens := 0.5 + 0.5 * noise.get_noise_2d(x * 1.7 + 9.0, z * 1.7)
		if y < 0.9 or rng.randf() > dens * 0.9:
			continue
		var s := rng.randf_range(0.8, 1.8)
		xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(x, y - 0.03, z)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = blade_mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	ResourceSaver.save(mm, MM_PATH)
	mm.take_over_path(MM_PATH)
	multimesh = mm
