extends CanvasLayer
const Catalog := preload("res://scripts/catalog.gd")

## Debug cheat panel, toggled with F1 (prototype: available in every build). Frees the mouse while open.
## Health cheats really add/remove debris so milestones, animals and toasts fire. Dev args: --cheats, --fill.

var is_open := false
var _root: Control
var _fast := false
var _fast_btn: Button
var _reset_btn: Button
var _reset_armed := false

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP  # swallow clicks so the player doesn't recapture the mouse
	_root.visible = false
	add_child(_root)
	var card := PanelContainer.new()
	card.position = Vector2(24, 200)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.16, 0.92)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", sb)
	_root.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var t := Label.new()
	t.text = "Cheats (F1 to close)"
	t.add_theme_font_size_override("font_size", 20)
	v.add_child(t)
	_row(v, [["+$1", func(): GameState.add_money(100)], ["+$10", func(): GameState.add_money(1000)]])
	_row(v, [["Max upgrades", _max_upgrades], ["Fill bag", _fill_bag]])
	_row(v, [["Clear 10% of beach", func(): _set_cleared(GameState.cleared_count + ceili(0.1 * GameState.initial_count))],
		["Spawn tide", func(): _mgr_call("tide")]])
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 6)
	var hl := Label.new()
	hl.text = "Health:"
	hr.add_child(hl)
	for pct in [25, 50, 75, 100]:
		_btn(hr, "%d%%" % pct, func(): _set_cleared(roundi(pct / 100.0 * GameState.initial_count)))
	v.add_child(hr)
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	_btn(r, "Reveal all notes", _reveal_notes)
	_fast_btn = _btn(r, "Fast walk: off", _toggle_fast)
	v.add_child(r)
	_reset_btn = Button.new()
	_reset_btn.text = "Reset game"
	_reset_btn.pressed.connect(_reset)
	v.add_child(_reset_btn)
	for a in OS.get_cmdline_user_args():
		if a == "--cheats":
			_set_open.call_deferred(true)
		elif a == "--fill":
			_fill_bag.call_deferred()

func _btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _row(parent: Control, items: Array) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	for it in items:
		_btn(h, it[0], it[1])
	parent.add_child(h)

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
