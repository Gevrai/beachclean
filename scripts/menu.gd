extends CanvasLayer
## Pause menu (Resume / Notes / Quit), notes list and the paper note overlay. Group "menu".
## Pauses the tree while open. Esc: close note -> back, notes -> pause menu, pause menu -> resume.

const INK := Color(0.30, 0.19, 0.10)
const SOFT := Color(0.45, 0.35, 0.26)
const Notes := preload("res://scripts/notes.gd")

enum S { NONE, PAUSE, LIST, NOTE }
var state := S.NONE
var _from_list := false
var _root: Control
var _card: PanelContainer
var _box: VBoxContainer

func _ready() -> void:
	add_to_group("menu")
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	_root.gui_input.connect(_on_gui_input)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.08, 0.12, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_card = PanelContainer.new()
	center.add_child(_card)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	_card.add_child(_box)
	for a in OS.get_cmdline_user_args():  # dev
		if a == "--pause":
			open_pause.call_deferred()
		elif a == "--pause=notes":
			(func(): open_pause(); _show_list()).call_deferred()
		elif a.begins_with("--note="):
			var i := int(a.trim_prefix("--note="))
			(func(): show_note(i)).call_deferred()

func is_open() -> bool:
	return state != S.NONE

func open_pause() -> void:
	if state != S.NONE:
		return
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_pause()

func resume() -> void:
	state = S.NONE
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## Found a bottle (or reread): shows the paper note. `from_list` returns to the list on close.
func show_note(id: int, from_list := false) -> void:
	GameState.find_note(id)
	if state == S.NONE:
		_root.visible = true
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_from_list = from_list
	state = S.NOTE
	_clear()
	_style_card(Color(0.97, 0.91, 0.76), Color(0.72, 0.58, 0.36), 44, Vector2(620, 0))
	_card.rotation = deg_to_rad(-1.2)
	_box.add_child(_label("Message %d of %d" % [id + 1, Notes.TEXTS.size()], 18, SOFT))
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.custom_minimum_size = Vector2(540, 0)
	rt.add_theme_font_size_override("normal_font_size", 28)
	rt.add_theme_font_size_override("italics_font_size", 28)
	rt.add_theme_color_override("default_color", INK)
	rt.add_theme_constant_override("line_separation", 6)
	rt.text = Notes.TEXTS[id].replace("\n", "\n\n")
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(rt)
	var foot := _label("click / E / Esc to close", 16, SOFT)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_box.add_child(foot)

func _show_pause() -> void:
	state = S.PAUSE
	_clear()
	_style_card(Color(0.99, 0.95, 0.86), Color(0.62, 0.40, 0.22), 28, Vector2(380, 0))
	var t := _label("Paused", 36, INK)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(t)
	_box.add_child(_button("Resume", resume))
	_box.add_child(_button("Notes", _show_list))
	_box.add_child(_button("Quit", _quit))
	var hint := _label("F1 - cheats", 15, SOFT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(hint)

func _show_list() -> void:
	state = S.LIST
	_clear()
	_style_card(Color(0.99, 0.95, 0.86), Color(0.62, 0.40, 0.22), 28, Vector2(460, 0))
	var t := _label("Notes  %d / %d" % [GameState.found_notes.size(), Notes.TEXTS.size()], 34, INK)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(t)
	for i in Notes.TEXTS.size():
		var b: Button
		if GameState.found_notes.has(i):
			b = _button("Message %d" % (i + 1), show_note.bind(i, true))
		else:
			b = _button("???", Callable())
			b.disabled = true
		_box.add_child(b)
	_box.add_child(_button("Back", _show_pause))

func _quit() -> void:
	GameState.save_game()
	get_tree().quit()

func _close_note() -> void:
	if _from_list:
		_show_list()
	else:
		resume()

func _input(event: InputEvent) -> void:
	if state == S.NONE or not (event is InputEventKey and event.pressed and not event.echo):
		return
	get_viewport().set_input_as_handled()
	match state:
		S.NOTE:
			if event.keycode == KEY_ESCAPE or event.keycode == KEY_E:
				_close_note()
		S.LIST:
			if event.keycode == KEY_ESCAPE:
				_show_pause()
		S.PAUSE:
			if event.keycode == KEY_ESCAPE:
				resume()

func _on_gui_input(event: InputEvent) -> void:
	if state == S.NOTE and event is InputEventMouseButton and event.pressed:
		_close_note()

func _clear() -> void:
	_card.rotation = 0.0
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()

func _style_card(fill: Color, border: Color, pad: int, min_size: Vector2) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(pad)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 22
	_card.add_theme_stylebox_override("panel", sb)
	_card.custom_minimum_size = min_size
	_card.pivot_offset = min_size / 2.0

func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.52, 0.42))
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": Color(0.96, 0.86, 0.62), "hover": Color(1.0, 0.9, 0.55), "pressed": Color(0.9, 0.78, 0.45), "disabled": Color(0.9, 0.85, 0.74)}[st]
		sb.set_corner_radius_all(12)
		b.add_theme_stylebox_override(st, sb)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b
