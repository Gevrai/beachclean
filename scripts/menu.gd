extends CanvasLayer
## Pause menu (Resume / Notes / Quit), notes list and the paper note overlay. Group "menu".
## Pauses the tree while open. Esc: close note -> back, notes -> pause menu, pause menu -> resume.

const Notes := preload("res://scripts/notes.gd")

enum S { NONE, PAUSE, LIST, NOTE }
var state := S.NONE
var _from_list := false
@onready var _root: Control = %Root
@onready var _pause_card: Control = %PauseCard
@onready var _list_card: Control = %ListCard
@onready var _note: Control = %NoteOverlay

func _ready() -> void:
	add_to_group("menu")
	_root.gui_input.connect(_on_gui_input)
	%Resume.pressed.connect(resume)
	%Notes.pressed.connect(_show_list)
	%Quit.pressed.connect(_quit)
	%Back.pressed.connect(_show_pause)
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
	_show_only(_note)
	_note.show_note(id)

func _show_pause() -> void:
	state = S.PAUSE
	_show_only(_pause_card)

func _show_list() -> void:
	state = S.LIST
	_show_only(_list_card)
	%ListTitle.text = "Notes  %d / %d" % [GameState.found_notes.size(), Notes.TEXTS.size()]
	var holder: Control = %NoteButtons
	for c in holder.get_children():
		if c != %NoteButton:
			c.queue_free()
	for i in Notes.TEXTS.size():
		var b: Button = %NoteButton.duplicate()
		b.visible = true
		b.unique_name_in_owner = false
		if GameState.found_notes.has(i):
			b.text = "Message %d" % (i + 1)
			b.pressed.connect(show_note.bind(i, true))
		else:
			b.text = "???"
			b.disabled = true
		holder.add_child(b)

func _show_only(card: Control) -> void:
	for c in [_pause_card, _list_card, _note]:
		c.visible = c == card

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
