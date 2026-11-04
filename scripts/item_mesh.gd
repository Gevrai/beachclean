extends RefCounted
## Item models as plain nodes, built from the prefab scenes (scenes/items/<id>.tscn, see catalog.gd).
## build(id, rng) -> Node3D at real size, lying pose baked in, origin = centre of the item;
## meta "rest" = height of the centre above the ground. upright=true stands lying things up (bin icons).
## Used for the shack's flying copies and bin icons; debris.gd uses the whole prefab instead.

const Catalog := preload("res://scripts/catalog.gd")

static func build(id: String, rng: RandomNumberGenerator, upright := false) -> Node3D:
	var item: Node = Catalog.item_scene(id).instantiate()
	var model: Node3D = item.get_node("Visual/Model")
	model.get_parent().remove_child(model)
	model.owner = null
	item.free()
	model.randomize_variant(rng)
	if upright:
		model.stand_up()
	var outer := Node3D.new()
	outer.add_child(model)
	outer.set_meta("rest", model.rest)
	return outer
