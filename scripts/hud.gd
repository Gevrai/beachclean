extends CanvasLayer
## HUD: crosshair + aim label, bag space, money, beach health. Layout: scenes/ui/hud.tscn. Group "hud".

const Catalog := preload("res://scripts/catalog.gd")

const FloatText := preload("res://scenes/ui/float_text.tscn")

@onready var _root: Control = %Root
@onready var _cross: Control = %Cross
@onready var _panel: PanelContainer = %Panel
@onready var _bag: Label = %Bag
@onready var _bag_bar: ProgressBar = %BagBar
@onready var _coins: Label = %Coins
@onready var _health: Label = %Health
@onready var _bar: ProgressBar = %HealthBar
@onready var _aim_box: PanelContainer = %AimBox
@onready var _aim_label: Label = %AimLabel
@onready var _msg: Label = %Msg
@onready var _hint: Label = %Hint
@onready var _prompt_box: PanelContainer = %PromptBox
@onready var _prompt: Label = %Prompt
@onready var _toast_box: PanelContainer = %ToastBox
@onready var _toast: Label = %Toast
var _bag_fill: StyleBoxFlat  # per-HUD copy of the theme's fill, recoloured as the bag fills
var _aim := 0.0  # 0..1 crosshair ring amount
var _aiming := false
var _shake: Tween
var _shown_coins := 0.0
var _last_coins := 0  # cents
var _pop: Tween
var _toast_tw: Tween

func _ready() -> void:
	add_to_group("hud")
	_cross.draw.connect(_draw_cross)
	_bag_fill = _bag_bar.get_theme_stylebox("fill").duplicate()
	_bag_bar.add_theme_stylebox_override("fill", _bag_fill)
	GameState.milestone_reached.connect(_on_milestone)
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
	_bag_fill.bg_color = Color(0.45, 0.8, 1.0).lerp(Color(1.0, 0.55, 0.3), clampf((fill - 0.6) / 0.4, 0.0, 1.0))
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
	var f: Label = FloatText.instantiate()
	f.text = "+" + Catalog.money(amount)
	f.position = _panel.position + Vector2(_panel.size.x + 12, 50)
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
