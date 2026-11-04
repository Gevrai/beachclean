extends CanvasLayer
## Upgrade shop panel (layout: scenes/ui/upgrade_panel.tscn). open()/close(); `is_open`. Frees the mouse while open.

const Catalog := preload("res://scripts/catalog.gd")
const Row := preload("res://scenes/ui/upgrade_row.tscn")

var is_open := false
var _shown := 0.0
var _rows: Dictionary = {}  # id -> {level, effect, button, row}
@onready var _root: Control = %Root
@onready var _card: PanelContainer = %Card
@onready var _coins: Label = %Coins

func _ready() -> void:
	for id in GameState.UPGRADE_ORDER:
		var row: Control = Row.instantiate()
		%Rows.add_child(row)
		row.get_node("%Name").text = GameState.UPGRADES[id].name
		var b: Button = row.get_node("%Buy")
		b.pressed.connect(_on_buy.bind(id))
		_rows[id] = {"level": row.get_node("%Level"), "effect": row.get_node("%Effect"), "button": b, "row": row}
	GameState.money_changed.connect(_on_coins)
	GameState.upgrades_changed.connect(_refresh)
	_shown = GameState.cents
	_refresh()

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
