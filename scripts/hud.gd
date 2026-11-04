extends CanvasLayer
## HUD: crosshair + aim label, bag space, money, beach health. Built in code. Group "hud".

const Catalog := preload("res://scripts/catalog.gd")

var _bag: Label
var _coins: Label  # money
var _bag_bar: ProgressBar
var _aim_box: PanelContainer
var _aim_label: Label
var _health: Label
var _bar: ProgressBar
var _panel: PanelContainer
var _cross: Control
var _msg: Label
var _hint: Label
var _aim := 0.0  # 0..1 crosshair ring amount
var _aiming := false
var _shake: Tween
var _prompt: Label
var _prompt_box: PanelContainer
var _shown_coins := 0.0
var _last_coins := 0  # cents
var _root: Control
var _pop: Tween
var _toast_box: PanelContainer
var _toast: Label
var _toast_tw: Tween

func _ready() -> void:
	add_to_group("hud")
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_root = root

	_cross = Control.new()
	_cross.set_anchors_preset(Control.PRESET_CENTER)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross.draw.connect(_draw_cross)
	root.add_child(_cross)

	_panel = PanelContainer.new()
	_panel.position = Vector2(20, 20)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _box(Color(0.06, 0.1, 0.16, 0.6), 16, 14))
	root.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_panel.add_child(v)
	_bag = _label(v, 26)
	_bag_bar = ProgressBar.new()
	_bag_bar.custom_minimum_size = Vector2(220, 10)
	_bag_bar.max_value = 1.0
	_bag_bar.show_percentage = false
	_bag_bar.add_theme_stylebox_override("background", _box(Color(1, 1, 1, 0.18), 5, 0))
	_bag_bar.add_theme_stylebox_override("fill", _box(Color(0.45, 0.8, 1.0), 5, 0))
	v.add_child(_bag_bar)
	_coins = _label(v, 26)
	_health = _label(v, 20)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(220, 14)
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.add_theme_stylebox_override("background", _box(Color(1, 1, 1, 0.18), 7, 0))
	_bar.add_theme_stylebox_override("fill", _box(Color(0.35, 0.95, 0.65), 7, 0))
	v.add_child(_bar)

	_aim_box = PanelContainer.new()
	_aim_box.set_anchors_preset(Control.PRESET_CENTER)
	_aim_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_aim_box.position = Vector2(0, 34)
	_aim_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aim_box.add_theme_stylebox_override("panel", _box(Color(0.06, 0.1, 0.16, 0.55), 10, 7))
	_aim_label = _label(_aim_box, 20)
	_aim_box.modulate.a = 0.0
	root.add_child(_aim_box)

	_msg = Label.new()
	_msg.set_anchors_preset(Control.PRESET_CENTER)
	_msg.position = Vector2(-150, 84)
	_msg.size = Vector2(300, 40)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.add_theme_font_size_override("font_size", 26)
	_msg.add_theme_color_override("font_color", Color(1, 0.45, 0.4))
	_msg.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_msg.add_theme_constant_override("outline_size", 8)
	_msg.modulate.a = 0.0
	root.add_child(_msg)

	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_CENTER)
	_hint.position = Vector2(-200, -140)
	_hint.size = Vector2(400, 40)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.text = "Click to play"
	_hint.add_theme_font_size_override("font_size", 30)
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_hint.add_theme_constant_override("outline_size", 8)
	root.add_child(_hint)

	_prompt_box = PanelContainer.new()
	_prompt_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt_box.position.y = -90
	_prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_box.add_theme_stylebox_override("panel", _box(Color(0.06, 0.1, 0.16, 0.72), 18, 14))
	_prompt = _label(_prompt_box, 26)
	_prompt_box.visible = false
	root.add_child(_prompt_box)

	_toast_box = PanelContainer.new()
	_toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_box.position.y = 28
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.add_theme_stylebox_override("panel", _box(Color(0.98, 0.9, 0.7, 0.92), 20, 16))
	_toast = _label(_toast_box, 30)
	_toast.add_theme_color_override("font_color", Color(0.25, 0.2, 0.12))
	_toast.add_theme_constant_override("outline_size", 0)
	_toast_box.modulate.a = 0.0
	root.add_child(_toast_box)
	GameState.milestone_reached.connect(_on_milestone)

	_coins.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	_shown_coins = GameState.cents
	_last_coins = GameState.cents
	GameState.bag_changed.connect(_refresh)
	GameState.money_changed.connect(_refresh)
	GameState.health_changed.connect(func(_h): _refresh())
	GameState.bag_full.connect(_on_bag_full)
	_refresh()

func _process(delta: float) -> void:
	_hint.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not _prompt_hold
	if not is_equal_approx(_shown_coins, float(GameState.cents)):
		var step := maxf(absf(_shown_coins - GameState.cents) / 0.6, 60.0) * delta  # count-up
		_shown_coins = move_toward(_shown_coins, GameState.cents, step)
		_coins.text = Catalog.money(roundi(_shown_coins))
	var goal := 1.0 if _aiming else 0.0
	if not is_equal_approx(_aim, goal):
		_aim = move_toward(_aim, goal, delta * 8.0)
		_cross.queue_redraw()

## `text` = what the crosshair is on ("Soda can · 10¢"), shown in a small label below it.
func set_aiming(on: bool, text := "") -> void:
	_aiming = on
	if on and text != "":
		_aim_label.text = text
		_aim_box.modulate.a = 1.0
	else:
		_aim_box.modulate.a = 0.0

func _draw_cross() -> void:
	var col := Color(1, 1, 1, 0.9).lerp(Color(1.0, 0.95, 0.45), _aim)
	_cross.draw_circle(Vector2.ZERO, 3.0 + 1.5 * _aim, Color(0, 0, 0, 0.45))
	_cross.draw_circle(Vector2.ZERO, 2.2 + 1.2 * _aim, col)
	if _aim > 0.01:
		_cross.draw_arc(Vector2.ZERO, 12.0 + 4.0 * (1.0 - _aim), 0.0, TAU, 32, Color(col, _aim), 2.5, true)

func _refresh() -> void:
	_bag.text = "Bag  %s / %s" % [Catalog.num(GameState.bag_used()), Catalog.num(GameState.bag_capacity)]
	var fill := GameState.bag_used() / maxf(GameState.bag_capacity, 0.1)
	_bag_bar.value = fill
	_bag_bar.add_theme_stylebox_override("fill", _box(Color(0.45, 0.8, 1.0).lerp(Color(1.0, 0.55, 0.3), clampf((fill - 0.6) / 0.4, 0.0, 1.0)), 5, 0))
	var c := GameState.cents
	if c > _last_coins:
		_coin_pop(c - _last_coins)
	elif c < _last_coins:
		_shown_coins = c  # spending: snap
	_last_coins = c
	_coins.text = Catalog.money(roundi(_shown_coins))
	var h := GameState.health()
	_health.text = "Beach health  %d%%" % roundi(h * 100.0)
	_bar.value = h

## Bottom-centre interaction prompt ("" hides it). `hold` = a panel is open, so hide the click hint too.
var _prompt_hold := false
func set_prompt(text: String, hold := false) -> void:
	_prompt_hold = hold
	_prompt_box.visible = text != "" and not hold
	_prompt.text = text

func _coin_pop(amount: int) -> void:
	_coins.pivot_offset = Vector2(0, _coins.size.y * 0.5)
	if _pop:
		_pop.kill()
	_pop = create_tween()
	_pop.tween_property(_coins, "scale", Vector2.ONE * 1.25, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop.tween_property(_coins, "scale", Vector2.ONE, 0.25)
	var f := Label.new()
	f.text = "+" + Catalog.money(amount)
	f.add_theme_font_size_override("font_size", 30)
	f.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	f.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	f.add_theme_constant_override("outline_size", 6)
	f.position = _panel.position + Vector2(_panel.size.x + 12, 50)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(f)
	var tw := f.create_tween().set_parallel(true)
	tw.tween_property(f, "position:y", f.position.y - 40.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(f, "modulate:a", 0.0, 0.5).set_delay(0.5)
	tw.chain().tween_callback(f.queue_free)

func _on_milestone(id: String) -> void:
	for m in GameState.MILESTONES:
		if m.id == id:
			toast(m.msg)

## Small centred-top message that fades after ~3 s.
func toast(text: String) -> void:
	_toast.text = text
	if _toast_tw:
		_toast_tw.kill()
	_toast_box.modulate.a = 0.0
	_toast_box.position.y = 14
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast_box, "modulate:a", 1.0, 0.3)
	_toast_tw.parallel().tween_property(_toast_box, "position:y", 28.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_toast_tw.tween_property(_toast_box, "modulate:a", 0.0, 0.6).set_delay(2.2)

func _on_bag_full() -> void:
	_msg.text = "Bag full!"
	_msg.modulate.a = 1.0
	create_tween().tween_property(_msg, "modulate:a", 0.0, 1.1).set_delay(0.5)
	_bag.modulate = Color(1, 0.4, 0.35)
	create_tween().tween_property(_bag, "modulate", Color.WHITE, 0.6)
	if _shake:
		_shake.kill()
	_shake = create_tween()
	for i in 3:
		_shake.tween_property(_panel, "position:x", 20.0 + 8.0 * (1 if i % 2 == 0 else -1), 0.04)
	_shake.tween_property(_panel, "position:x", 20.0, 0.04)

func _label(parent: Control, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
	l.add_theme_constant_override("outline_size", 4)
	parent.add_child(l)
	return l

func _box(c: Color, radius: int, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s
