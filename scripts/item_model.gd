extends Node3D
## Visual model of one catalog item: the "Model" node of scenes/items/<id>.tscn (mesh parts under "Pose").
## Colour variants are material .tres lists: pick one per instance with randomize_variant(rng).
## The prefab shows variant 0 in the editor. `rest` = height of the model origin above the ground at real size.

@export var rest := 0.03
## Pose node: lying pose baked in. Items with can_stand are turned upright (bin icons) via stand_up().
@export var pose: NodePath = ^"Pose"
@export var can_stand := false
@export var stand_rotation_x := 0.0
## variants[i] goes to every node in variant_parts; accents[i] (optional, same length) to accent_parts.
@export var variants: Array[Material] = []
@export var variant_parts: Array[NodePath] = []
@export var accents: Array[Material] = []
@export var accent_parts: Array[NodePath] = []

func randomize_variant(rng: RandomNumberGenerator) -> void:
	if not variants.is_empty():
		apply_variant(rng.randi() % variants.size())

func apply_variant(i: int) -> void:
	for p in variant_parts:
		(get_node(p) as MeshInstance3D).material_override = variants[i]
	if i < accents.size():
		for p in accent_parts:
			(get_node(p) as MeshInstance3D).material_override = accents[i]

func stand_up() -> void:
	if can_stand:
		get_node(pose).rotation.x = stand_rotation_x
