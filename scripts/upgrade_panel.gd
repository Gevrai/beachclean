extends CanvasLayer
## Upgrade shop panel (code-built). open()/close(); `is_open`. Frees the mouse while open.

const Catalog := preload("res://scripts/catalog.gd")
const INK := Color(0.30, 0.19, 0.10)
const SOFT := Color(0.45, 0.35, 0.26)

var is_open := false
var _root: Control
var _card: PanelContainer
var _coins: Label
var _shown := 0.0
var _rows: Dictionary = {}  # id -> {level, effect, button, row}

func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.08, 0.12, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(700, 0)
	var sb := _style(Color(0.99, 0.95, 0.86), 28, 26)
	sb.border_color = Color(0.62, 0.40, 0.22)
	sb.set_border_width_all(5)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 24
	_card.add_theme_stylebox_override("panel", sb)
	center.add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_card.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	var title := _label("Recycling Shack", 36, INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_coins = _label("$0.00", 30, Color(0.78, 0.5, 0.0))
	head.add_child(_coins)
	v.add_child(_label("Spend your money on better tools.", 18, SOFT))

	for id in GameState.UPGRADE_ORDER:
		_add_row(v, id)

	var foot := _label("E / Esc to close", 17, SOFT)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(foot)

	GameState.money_changed.connect(_on_coins)
	GameState.upgrades_changed.connect(_refresh)
	_shown = GameState.cents
	_refresh()

func _add_row(parent: Control, id: String) -> void:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _style(Color(1, 1, 1, 0.75), 18, 14))
	parent.add_child(row)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	row.add_child(h)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	h.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)
	top.add_child(_label(GameState.UPGRADES[id].name, 26, INK))
	var lvl := _label("", 20, Color(0.14, 0.52, 0.5))
	lvl.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(lvl)
	var eff := _label("", 19, SOFT)
	col.add_child(eff)
	var b := Button.new()
	b.custom_minimum_size = Vector2(150, 54)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_stylebox_override("normal", _style(Color(0.18, 0.66, 0.5), 16, 8))
	b.add_theme_stylebox_override("hover", _style(Color(0.26, 0.76, 0.58), 16, 8))
	b.add_theme_stylebox_override("pressed", _style(Color(0.12, 0.52, 0.4), 16, 8))
	b.add_theme_stylebox_override("disabled", _style(Color(0.82, 0.78, 0.72), 16, 8))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.52, 0.47, 0.42))
	b.pressed.connect(_on_buy.bind(id))
	h.add_child(b)
	_rows[id] = {"level": lvl, "effect": eff, "button": b, "row": row}

func _on_buy(id: String) -> void:
	if GameState.buy(id):
		var row: Control = _rows[id].row
		row.modulate = Color(1.0, 1.0, 0.7)
		create_tween().tween_property(row, "modulate", Color.WHITE, 0.4)

func _on_coins() -> void:
	if GameState.cents < _shown:
		_shown = GameState.cents  # spending snaps, earning counts up (_process)
	_refresh()

func _process(delta: float) -> void:
	if is_open and not is_equal_approx(_shown, float(GameState.cents)):
		_shown = move_toward(_shown, GameState.cents, maxf(absf(_shown - GameState.cents) / 0.6, 60.0) * delta)
		_coins.text = Catalog.money(roundi(_shown))

func _refresh() -> void:
	_coins.text = Catalog.money(roundi(_shown))
	for id in _rows:
		var r: Dictionary = _rows[id]
		var l := GameState.level(id)
		r.level.text = "Lv %d / %d" % [l, GameState.UPGRADES[id].max]
		r.effect.text = GameState.effect_text(id)
		var b: Button = r.button
		if GameState.is_maxed(id):
			b.text = "MAX"
			b.disabled = true
		else:
			b.text = "Buy  " + Catalog.money(GameState.cost(id))
			b.disabled = not GameState.can_buy(id)

func open() -> void:
	if is_open:
		return
	is_open = true
	_shown = minf(_shown, GameState.cents) if _shown > GameState.cents else _shown
	_refresh()
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2.ONE * 0.92
	_card.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "modulate:a", 1.0, 0.12)

func close() -> void:
	if not is_open:
		return
	is_open = false
	_root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _label(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func _style(c: Color, radius: int, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s
