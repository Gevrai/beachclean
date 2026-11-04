extends StaticBody3D
## A coin on the sand: instant money on pickup, never enters the bag, no health effect.
## Group "coin", collision layer 2. spawn(cents, rng).

const Catalog := preload("res://scripts/catalog.gd")
const OUTLINE := preload("res://assets/materials/items/outline.tres")

@export var cents := 5
var value := 5  # cents
var _meshes: Array[MeshInstance3D] = []
var _visual: Node3D
var _star: Node3D
var _t := 0.0
var _busy := false

## A new coin from its prefab (scenes/items/coin_<cents>.tscn) with a random lie. Add it to the tree, then place it.
static func spawn(c: int, rng: RandomNumberGenerator) -> StaticBody3D:
	var n: StaticBody3D = Catalog.coin_scene(c).instantiate()
	n.get_node("Visual").rotation = Vector3(rng.randf_range(-0.25, 0.25), rng.randf() * TAU, rng.randf_range(-0.25, 0.25))
	n.set("_t", rng.randf() * 10.0)
	return n

func _ready() -> void:
	value = cents
	_visual = $Visual
	_visual.scale = Vector3.ONE * Catalog.VIS_SCALE
	_star = $Sparkle
	for c in _visual.get_children():
		_meshes.append(c)

func _process(delta: float) -> void:
	_t += delta
	_star.scale = Vector3.ONE * (0.15 + 0.85 * maxf(0.0, sin(_t * 2.2)))

## Hover label: "Loose change · $0.25"
func label_text() -> String:
	return "Loose change · %s" % Catalog.money(value)

func set_highlight(on: bool) -> void:
	var ov = OUTLINE if on else null
	for m in _meshes:
		m.material_overlay = ov

func refuse() -> void:
	pass

## Called by the player after adding the money: pop up, spin, vanish.
func pick_up(_cam: Camera3D) -> void:
	if _busy:
		return
	_busy = true
	set_process(false)
	_star.visible = false
	get_node("/root/Sfx").tick()
	collision_layer = 0
	remove_from_group("coin")
	set_highlight(false)
	var tw := create_tween()
	tw.tween_property(self, "global_position", global_position + Vector3.UP * 0.6, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_visual, "rotation:y", _visual.rotation.y + TAU * 2.0, 0.25)
	tw.parallel().tween_property(self, "scale", Vector3.ONE * 0.05, 0.15).set_delay(0.12)
	tw.finished.connect(queue_free)
