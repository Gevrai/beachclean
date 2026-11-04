@tool
extends Node3D
## The beach scene root. Terrain, water, sky, sun, props and player are nodes in scenes/beach.tscn; this script
## owns the health-driven look (set_health blends the BeachLook resources in assets/env/) and builds the gameplay nodes.
## Public API: set_health(t), height_at(x, z), shore_z(x). Group "beach".
## @tool: with Beach selected in the editor, the `health` slider previews the look (edit a look .tres to see it live).

@export_range(0.0, 1.0) var health: float = 0.0:
	set(v):
		health = clampf(v, 0.0, 1.0)
		if Engine.is_editor_hint() and is_node_ready():
			_apply_look()

@export_group("Looks")
@export var look_polluted: BeachLook:
	set(v):
		look_polluted = _watch(look_polluted, v)
@export var look_restored: BeachLook:
	set(v):
		look_restored = _watch(look_restored, v)
## Golden-hour overlay, blended in over the last 15% of health (smoothstep 0.85..1).
@export var look_golden: BeachLook:
	set(v):
		look_golden = _watch(look_golden, v)

@export_group("Materials driven by the look")
@export var sand_mat: ShaderMaterial
@export var water_mat: ShaderMaterial
@export var grass_mat: ShaderMaterial
@export var leaf_mat: StandardMaterial3D

@onready var sun: DirectionalLight3D = $Sun
@onready var world_env: WorldEnvironment = $WorldEnvironment

var _terrain: Node
var _time := 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		_apply_look()
		return
	add_to_group("beach")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--health="):
			health = float(a.trim_prefix("--health="))
	health = maxf(health, GameState.health())  # restored save
	set_health(health)
	GameState.health_changed.connect(_on_health_changed)
	_spawn_gameplay()

var _health_tw: Tween

## Eases the visual health to the new value over ~2 s instead of snapping.
func _on_health_changed(v: float) -> void:
	if _health_tw:
		_health_tw.kill()
	_health_tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_health_tw.tween_method(set_health, health, v, 2.0)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	# keep the sand's wet line in sync with the water swell
	var swell := sin(_time * 0.55) * 0.6 + sin(_time * 0.31 + 1.7) * 0.4
	sand_mat.set_shader_parameter("swell", swell * 0.12)

# ---------------------------------------------------------------- gameplay

func _spawn_gameplay() -> void:
	var shack: Node3D = preload("res://scenes/shack/shack.tscn").instantiate()
	shack.set("beach", self)
	add_child(shack)
	var mgr := Node.new()
	mgr.set_script(preload("res://scripts/debris_manager.gd"))
	mgr.set("beach", self)
	add_child(mgr)
	add_child(load("res://scenes/ui/hud.tscn").instantiate())  # load: scene scripts use autoloads
	add_child(load("res://scenes/ui/pause_menu.tscn").instantiate())  # load: scene scripts use autoloads
	add_child(load("res://scenes/ui/cheats.tscn").instantiate())  # load: scene scripts use autoloads
	var wild: Node3D = load("res://scenes/wildlife/wildlife.tscn").instantiate()  # load: tools/check parses beach.gd without autoloads
	wild.set("beach", self)
	add_child(wild)

# ---------------------------------------------------------------- terrain (lives in the Terrain node)

func _tr() -> Node:
	if _terrain == null:
		_terrain = get_node("Terrain")
	return _terrain

## World z of the shoreline at x.
func shore_z(x: float) -> float:
	return _tr().shore_z(x)

func height_at(x: float, z: float) -> float:
	return _tr().height_at(x, z)

# ---------------------------------------------------------------- look

func _watch(old: BeachLook, new: BeachLook) -> BeachLook:
	if Engine.is_editor_hint():
		if old and old.changed.is_connected(_on_look_changed):
			old.changed.disconnect(_on_look_changed)
		if new:
			new.changed.connect(_on_look_changed)
	return new

func _on_look_changed() -> void:
	if is_node_ready():
		_apply_look()

## t: 0 = polluted (grey, cool, murky) .. 1 = healed (vibrant, golden sun).
func set_health(t: float) -> void:
	health = t
	_apply_look()

# Editor preview must never change what gets saved: the first preview snapshots every object the look writes
# (sun, environment, sky/water/sand/grass/leaf materials); the snapshot is put back right before the scene is
# saved (then the preview is re-applied) and when the scene closes.
var _pristine: Dictionary = {}  # Object -> {property: value}

func _preview_targets() -> Array:
	var env := world_env.environment
	return [sun, env, env.sky.sky_material, water_mat, sand_mat, grass_mat, leaf_mat]

func _snapshot() -> void:
	for o in _preview_targets():
		var d := {}
		for p in o.get_property_list():
			if p.usage & PROPERTY_USAGE_STORAGE and p.name != "script":
				d[p.name] = o.get(p.name)
		_pristine[o] = d

func _restore_pristine() -> void:
	for o in _pristine:
		for k in _pristine[o]:
			o.set(k, _pristine[o][k])

func _notification(what: int) -> void:
	if not Engine.is_editor_hint() or _pristine.is_empty():
		return
	if what == NOTIFICATION_EDITOR_PRE_SAVE or what == NOTIFICATION_EXIT_TREE:
		_restore_pristine()
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_apply_look()

func _apply_look() -> void:
	if look_polluted == null or look_restored == null or sun == null:
		return
	if Engine.is_editor_hint() and _pristine.is_empty():
		_snapshot()
	var k := pow(health, 0.8)  # slight ease so low health is still pleasant
	var l := look_polluted.mix(look_restored, k)
	if look_golden:
		l = l.mix(look_golden, smoothstep(0.85, 1.0, health))  # golden-hour boost near 100%
	# sun
	var elev := deg_to_rad(l.sun_elevation_deg)
	var az := deg_to_rad(l.sun_azimuth_deg)
	var to_sun := Vector3(sin(az) * cos(elev), sin(elev), cos(az) * cos(elev))
	sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
	sun.light_color = l.sun_color
	sun.light_energy = l.sun_energy
	# sky
	var env := world_env.environment
	var sky_mat := env.sky.sky_material as ShaderMaterial
	sky_mat.set_shader_parameter("zenith", l.sky_zenith)
	sky_mat.set_shader_parameter("mid", l.sky_mid)
	sky_mat.set_shader_parameter("horizon", l.sky_horizon)
	sky_mat.set_shader_parameter("ground", l.sky_ground)
	sky_mat.set_shader_parameter("sun_color", l.sky_sun_color)
	sky_mat.set_shader_parameter("cloud_cover", l.cloud_cover)
	sky_mat.set_shader_parameter("cloud_lit", l.cloud_lit)
	sky_mat.set_shader_parameter("cloud_shade", l.cloud_shade)
	# fog / env
	env.fog_light_color = l.fog_color
	env.fog_density = l.fog_density
	env.volumetric_fog_density = l.volumetric_fog_density
	env.volumetric_fog_albedo = l.volumetric_fog_albedo
	env.ambient_light_energy = l.ambient_energy
	env.adjustment_saturation = l.saturation
	env.adjustment_contrast = l.contrast
	env.glow_intensity = l.glow_intensity
	# water
	water_mat.set_shader_parameter("shallow_color", l.water_shallow)
	water_mat.set_shader_parameter("deep_color", l.water_deep)
	water_mat.set_shader_parameter("foam_color", l.water_foam)
	water_mat.set_shader_parameter("absorb", l.water_absorb)
	# sand / grass / palms
	sand_mat.set_shader_parameter("sand_dry", l.sand_dry)
	sand_mat.set_shader_parameter("sand_light", l.sand_light)
	sand_mat.set_shader_parameter("grass_tint", l.sand_grass_tint)
	grass_mat.set_shader_parameter("root_color", l.grass_root)
	grass_mat.set_shader_parameter("tip_color", l.grass_tip)
	leaf_mat.albedo_color = l.leaf_albedo
	leaf_mat.backlight = l.leaf_backlight
