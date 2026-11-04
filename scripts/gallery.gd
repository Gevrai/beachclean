extends Node3D
## Showcase of every collectible at the size it has in the game, on sand, with name / real size / value.
## Everything is placed in scenes/gallery.tscn (item prefab instances, labels, ruler, figure, environment) so the
## editor shows it as is. Open it and press F6 (Run Current Scene). Items turn slowly; the camera sways gently.
## Items are drawn Catalog.VIS_SCALE x life size (labels give the real size); the figure is life size.

const SPACING := 0.9
const FRONT_Z := 1.0

var _spin: Array[Node3D] = []
var _t := 0.0
var _focus := 1.5
var _dist := 2.0
@onready var _cam: Camera3D = $Camera3D

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for n in $Items.get_children():
		_spin.append(n)
		var model := n.get_node_or_null("Visual/Model")
		if model:  # the editor shows colour variant 0; running shows a random mix
			model.randomize_variant(rng)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--focus="):
			_focus = float(a.trim_prefix("--focus="))
	_place_cam()

## Camera orbits nothing: it slides along the row (A/D, arrows or mouse drag) and zooms (wheel, W/S).
func _place_cam() -> void:
	_focus = clampf(_focus, -1.0, 9 * SPACING + 1.0)
	_dist = clampf(_dist, 0.8, 7.0)
	_cam.position = Vector3(_focus + sin(_t * 0.3) * 0.15, _dist * 0.75, _dist * 0.7 + FRONT_Z * 0.5)
	_cam.look_at(Vector3(_focus, 0.05, FRONT_Z * 0.4))

func _input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_focus -= e.relative.x * 0.004 * _dist
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist *= 0.9
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist *= 1.1

func _process(delta: float) -> void:
	_t += delta
	for n in _spin:
		n.rotation.y += delta * 0.5
	_focus += (Input.get_axis("ui_left", "ui_right")) * delta * _dist * 0.6
	_focus += (float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))) * delta * _dist * 0.6
	_dist += (float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))) * delta * _dist
	_place_cam()
