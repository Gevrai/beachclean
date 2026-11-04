@tool
extends Node3D
## One sorting bin (scenes/shack/bin.tscn). Tint, label and icon are set per instance in shack.tscn.
## The icon is a runtime copy of the item mesh (items system) and is skipped in the editor.

const ItemMesh := preload("res://scripts/item_mesh.gd")
const MOUTH_Y := 0.97  # local height of the opening (items land here)

@export var bin_id := ""
@export var bin_color := Color(0.5, 0.5, 0.5):
	set(v):
		bin_color = v
		_apply()
@export var label_text := "BIN":
	set(v):
		label_text = v
		_apply()
@export var icon_id := ""
@export var icon_scale := 1.0

@onready var lid: Node3D = $Lid

func _ready() -> void:
	# per-instance tinted copies of the shared (white) materials
	_tint("Body", bin_color)
	_tint("Base", bin_color.darkened(0.3))
	_tint("Lid/LidTop", bin_color.darkened(0.2))
	_tint("Lid/Handle", bin_color.lightened(0.25))
	_apply()
	if Engine.is_editor_hint() or icon_id == "":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var icon := ItemMesh.build(icon_id, rng, true)
	icon.scale = Vector3.ONE * icon_scale
	$Icon.add_child(icon)

func _tint(path: String, c: Color) -> void:
	var mi := get_node_or_null(path) as MeshInstance3D
	if mi == null:
		return
	var m := mi.get_surface_override_material(0).duplicate() as StandardMaterial3D
	m.albedo_color = c
	if m.emission_enabled:
		m.emission = c
	mi.set_surface_override_material(0, m)

func _apply() -> void:
	if not is_node_ready():
		return
	var l := $Label as Label3D
	l.text = label_text
	l.modulate = bin_color.darkened(0.45)
