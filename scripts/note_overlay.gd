extends CenterContainer
## The paper note card (layout in scenes/ui/note_overlay.tscn). Shown by the pause menu.

const Notes := preload("res://scripts/notes.gd")

func show_note(id: int) -> void:
	%Meta.text = "Message %d of %d" % [id + 1, Notes.TEXTS.size()]
	%Text.text = Notes.TEXTS[id].replace("\n", "\n\n")
