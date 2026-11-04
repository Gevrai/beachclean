extends SceneTree
## Headless re-bake of the dune grass meshes + scatter and the boardwalk mesh: tools/bake_dunes
const BW_DRIFT := "res://assets/meshes/boardwalk_drift.res"
const BW_SHAPE := "res://assets/meshes/boardwalk_fence_shape.res"
const DG := preload("res://scripts/dune_grass.gd")

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DG.MM_DIR)
	for k in DG.VARIANTS:  # placeholders so beach.tscn loads on the very first bake
		var path: String = DG.MM_DIR + k + ".res"
		if not ResourceLoader.exists(path):
			ResourceSaver.save(MultiMesh.new(), path)
	if not ResourceLoader.exists(BW_DRIFT):
		ResourceSaver.save(ArrayMesh.new(), BW_DRIFT)
	if not ResourceLoader.exists(BW_SHAPE):
		ResourceSaver.save(ConcavePolygonShape3D.new(), BW_SHAPE)
	var beach: Node = load("res://scenes/beach.tscn").instantiate()
	root.add_child(beach)
	await process_frame
	beach.get_node("Terrain").bake()
	beach.get_node("Boardwalk").bake()
	var dg: Node = beach.get_node("DuneGrass")
	dg.bake_meshes()
	dg.scatter()
	quit()
