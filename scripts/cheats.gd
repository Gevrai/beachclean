extends CanvasLayer
const Catalog := preload("res://scripts/catalog.gd")

## Debug cheat panel, toggled with F1 (prototype: available in every build). Frees the mouse while open.
## Health cheats really add/remove debris so milestones, animals and toasts fire. Dev args: --cheats, --fill.

var is_open := false
var _fast := false
var _reset_armed := false
@onready var _root: Control = %Root
@onready var _fast_btn: Button = %Fast
@onready var _reset_btn: Button = %Reset

func _ready() -> void:
	%Add1.pressed.connect(func(): GameState.add_money(100))
	%Add10.pressed.connect(func(): GameState.add_money(1000))
	%MaxUpgrades.pressed.connect(_max_upgrades)
	%FillBag.pressed.connect(_fill_bag)
	%Clear10.pressed.connect(func(): _set_cleared(GameState.cleared_count + ceili(0.1 * GameState.initial_count)))
	%Tide.pressed.connect(func(): _mgr_call("tide"))
	for b in %Health.get_children():
		if b is Button:
			var pct := int(String(b.name).trim_prefix("H"))
			b.pressed.connect(func(): _set_cleared(roundi(pct / 100.0 * GameState.initial_count)))
	%Reveal.pressed.connect(_reveal_notes)
	_fast_btn.pressed.connect(_toggle_fast)
	_reset_btn.pressed.connect(_reset)
	for a in OS.get_cmdline_user_args():
		if a == "--cheats":
			_set_open.call_deferred(true)
		elif a == "--fill":
			_fill_bag.call_deferred()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			var menu := get_tree().get_first_node_in_group("menu")
			var shack := get_tree().get_first_node_in_group("shack")
			if (menu and menu.is_open()) or (shack and shack.panel.is_open):
				return
			_set_open(not is_open)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and is_open:
			_set_open(false)
			get_viewport().set_input_as_handled()

func _set_open(on: bool) -> void:
	is_open = on
	_root.visible = on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED
	_reset_armed = false
	_reset_btn.text = "Reset game"

func _toast(text: String) -> void:
	get_tree().call_group("hud", "toast", text)

func _mgr_call(m: String, arg = null) -> Variant:
	var mgr := get_tree().get_first_node_in_group("debris_manager")
	if mgr == null:
		return null
	return mgr.call(m) if arg == null else mgr.call(m, arg)

func _max_upgrades() -> void:
	for id in GameState.UPGRADE_ORDER:
		GameState.levels[id] = int(GameState.UPGRADES[id].max)
	GameState._apply()
	GameState.upgrades_changed.emit()
	GameState.money_changed.emit()

## Fill the bag with a random catalog mix (stops after a few items that no longer fit).
func _fill_bag() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var misses := 0
	while misses < 12:
		var id: String = Catalog.random_id(rng)
		if GameState.can_add(float(Catalog.ITEMS[id].space)):
			GameState.add_to_bag(id)
		else:
			misses += 1

## Move the cleared count to `target` by really removing (or re-scattering) debris.
func _set_cleared(target: int) -> void:
	target = clampi(target, 0, GameState.initial_count)
	var cur := GameState.cleared_count
	if target > cur:
		var pieces := get_tree().get_nodes_in_group("debris")
		for i in mini(target - cur, pieces.size()):
			pieces[i].remove_from_group("debris")
			pieces[i].queue_free()
			GameState.register_clear()
	elif target < cur:
		GameState.cleared_count = target
		_mgr_call("scatter", cur - target)
		GameState.health_changed.emit(GameState.health())

func _reveal_notes() -> void:
	for i in preload("res://scripts/notes.gd").TEXTS.size():
		GameState.find_note(i)
	for b in get_tree().get_nodes_in_group("bottle"):
		b.queue_free()
	_toast("All notes revealed (see Pause > Notes)")

func _toggle_fast() -> void:
	_fast = not _fast
	_fast_btn.text = "Fast walk: " + ("x3" if _fast else "off")
	var p := get_tree().get_first_node_in_group("player")
	if p:
		p.speed_mult = 3.0 if _fast else 1.0
		p.apply_upgrades()

func _reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_btn.text = "Click again to WIPE SAVE and restart"
		return
	GameState.reset()
	_set_open(false)
	get_tree().reload_current_scene()
