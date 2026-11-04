extends StaticBody3D
## A message in a bottle: glass bottle, rolled paper, faint sparkle. Group "bottle", layer 2.
## Picking it up (player) opens the note; it never uses bag space.

const OUTLINE := preload("res://assets/materials/items/outline.tres")

var note_id := 0
var _meshes: Array[MeshInstance3D] = []
var _visual: Node3D
var _busy := false

## Which note this bottle holds (also turns it on the sand). Call before or after add_child.
func setup(id: int) -> void:
	note_id = id
	$Visual.rotation.y = id * 1.7

func _ready() -> void:
	_visual = $Visual
	_visual.scale = Vector3.ONE * 0.67 * preload("res://scripts/catalog.gd").VIS_SCALE  # ~30 cm real bottle
	for c in _visual.get_children():
		if not c.name.begins_with("Sparkle"):
			_meshes.append(c)
	# sparkle: two tiny emissive stars that twinkle
	for i in 2:
		var mi: Node3D = _visual.get_node("Sparkle%d" % i)
		var tw := create_tween().set_loops()
		tw.tween_interval(0.7 * i)
		tw.tween_property(mi, "scale", Vector3.ONE * 1.4, 0.7).from(Vector3.ONE * 0.1)
		tw.tween_property(mi, "scale", Vector3.ONE * 0.1, 0.7)
		tw.tween_interval(0.8)

## Target interface (see debris.gd): hover label.
func label_text() -> String:
	return "Message in a bottle"

func set_highlight(on: bool) -> void:
	var ov = OUTLINE if on else null
	for m in _meshes:
		m.material_overlay = ov

func refuse() -> void:
	pass

## Called by the player: pop up and vanish, then the note opens.
func pick_up(cam: Camera3D) -> void:
	if _busy:
		return
	_busy = true
	collision_layer = 0
	remove_from_group("bottle")
	set_highlight(false)
	var tw := create_tween()
	tw.tween_property(self, "global_position", global_position + Vector3.UP * 0.5, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "scale", Vector3.ONE * 0.05, 0.2).set_delay(0.05)
	tw.finished.connect(queue_free)
