extends CharacterBody3D
## First-person player. WASD + mouse look, bob, pickup raycast. Created by beach.gd.
## Upgradeable stats: reach, move_speed (bag_capacity lives in GameState).

var beach: Node  # set by beach.gd before add_child

var reach: float = 2.5
var move_speed: float = 5.0
var speed_mult := 1.0  # cheats: fast walk
var mouse_sens: float = 0.0022

const GRAVITY := 20.0
const X_LIMIT := 50.0
const EYE_HEIGHT := 1.6

var head: Node3D
var cam: Camera3D
var target: Node = null  # debris under the crosshair within reach
var _pitch := 0.0
var _bob_t := 0.0
var _hud: Node
var _grab_t := 0.0

const GRAB_CONE_DEG := 15.0

func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 1
	floor_snap_length = 0.6
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	head = Node3D.new()
	head.position.y = EYE_HEIGHT
	add_child(head)
	cam = Camera3D.new()
	cam.fov = 75.0
	cam.far = 600.0
	head.add_child(cam)
	cam.make_current()
	var x := 0.0
	var z: float = beach.shore_z(0.0) - 9.0
	var yaw := PI  # face the sea (+Z)
	# dev: --pos=x,z,yaw_deg,pitch_deg
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pos="):
			var f := a.trim_prefix("--pos=").split_floats(",")
			x = f[0]
			z = f[1]
			yaw = deg_to_rad(f[2])
			if f.size() > 3:
				_pitch = deg_to_rad(f[3])
		elif a.begins_with("--pitch="):  # dev: look up/down in degrees, default spot
			_pitch = deg_to_rad(float(a.trim_prefix("--pitch=")))
	position = Vector3(x, beach.height_at(x, z) + 0.2, z)
	rotation.y = yaw
	head.rotation.x = _pitch
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameState.upgrades_changed.connect(apply_upgrades)
	apply_upgrades()

## Pull reach / speed from GameState (grabber and rake are read live).
func apply_upgrades() -> void:
	reach = GameState.reach()
	move_speed = GameState.move_speed() * speed_mult

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sens)
		_pitch = clampf(_pitch - event.relative.y * mouse_sens, deg_to_rad(-85.0), deg_to_rad(85.0))
		head.rotation.x = _pitch
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			_try_pickup()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().call_group("menu", "open_pause")

func _physics_process(delta: float) -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var dir := Vector2.ZERO
	if captured:
		dir.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
		dir.y = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
		dir = dir.normalized()
	var wish := (transform.basis * Vector3(dir.x, 0.0, dir.y)) * move_speed
	var k := 1.0 - exp(-12.0 * delta)
	velocity.x = lerpf(velocity.x, wish.x, k)
	velocity.z = lerpf(velocity.z, wish.z, k)
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	# keep inside the beach: between the dunes and the shoreline
	var sz: float = beach.shore_z(position.x)
	position.x = clampf(position.x, -X_LIMIT, X_LIMIT)
	position.z = clampf(position.z, sz - 33.0, sz + 1.2)
	# head bob
	var speed := Vector2(velocity.x, velocity.z).length()
	var amt := clampf(speed / 5.0, 0.0, 1.0)
	var step_before := int(floor(_bob_t / PI))
	_bob_t += speed * delta * 1.7
	if speed > 1.5 and int(floor(_bob_t / PI)) != step_before:  # one footstep per bob dip
		get_node("/root/Sfx").step()
	head.position.y = lerpf(head.position.y, EYE_HEIGHT + sin(_bob_t * 2.0) * 0.035 * amt, 1.0 - exp(-20.0 * delta))
	head.position.x = lerpf(head.position.x, cos(_bob_t) * 0.02 * amt, 1.0 - exp(-20.0 * delta))
	_update_target()
	if captured and GameState.grab_rate() > 0.0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_grab_t -= delta
		if _grab_t <= 0.0:
			_grab_t = 1.0 / GameState.grab_rate()
			grab_tick()
	else:
		_grab_t = 0.0

func _update_target() -> void:
	var from := cam.global_position
	var to := from - cam.global_basis.z * reach
	var q := PhysicsRayQueryParameters3D.create(from, to, 3)  # terrain (1) + debris (2)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var found: Node = hit.collider if hit and (hit.collider.is_in_group("debris") or hit.collider.is_in_group("bottle") or hit.collider.is_in_group("coin")) else null
	if found != target:
		if is_instance_valid(target):
			target.set_highlight(false)
		target = found
		if target:
			target.set_highlight(true)
		if _hud == null:
			_hud = get_tree().get_first_node_in_group("hud")
		if _hud:
			_hud.set_aiming(target != null, target.label_text() if target else "")

func _try_pickup() -> void:
	if not is_instance_valid(target):
		return
	var d := target
	if d.is_in_group("bottle"):
		target = null
		if _hud:
			_hud.set_aiming(false)
		d.pick_up(cam)
		get_tree().call_group("menu", "show_note", d.note_id)
		return
	if d.is_in_group("coin"):  # loose change: straight to the wallet
		target = null
		if _hud:
			_hud.set_aiming(false)
		GameState.add_money(d.value)
		d.pick_up(cam)
		return
	if not _collect(d):
		d.refuse()  # add_to_bag already emitted bag_full for the HUD
		return
	target = null
	if _hud:
		_hud.set_aiming(false)

## Grabber: vacuum the piece closest to the view centre inside a cone. Respects bag capacity.
func grab_tick() -> void:
	var fwd := -cam.global_basis.z
	var best: Node = null
	var best_ang := deg_to_rad(GRAB_CONE_DEG)
	for d in get_tree().get_nodes_in_group("debris"):
		var to: Vector3 = d.global_position + Vector3.UP * 0.1 - cam.global_position
		if to.length() > reach:
			continue
		var ang := fwd.angle_to(to)
		if ang < best_ang:
			best_ang = ang
			best = d
	if best == null:
		return
	if best == target:
		target = null
	if not _collect(best):
		best.refuse()

## Put a piece in the bag (emits bag_full if it doesn't fit). On success the Beach rake also grabs
## neighbours within its radius, as long as they fit.
func _collect(d: Node) -> bool:
	if not GameState.add_to_bag(d.id):
		return false
	GameState.register_clear()
	d.pick_up(cam)
	var r := GameState.rake_radius()
	if r > 0.0:
		for o in get_tree().get_nodes_in_group("debris"):  # d already left the group
			if o.global_position.distance_to(d.global_position) <= r and GameState.can_add(o.space):
				GameState.add_to_bag(o.id)
				GameState.register_clear()
				o.pick_up(cam)
	return true
