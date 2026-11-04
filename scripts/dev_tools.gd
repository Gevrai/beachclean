extends Node
## Dev-only: `-- --shot=path.png` saves a screenshot after ~2 s (`--shot-delay=SECONDS` to change) and quits. No effect otherwise.

func _ready() -> void:
	var delay := 2.0
	var path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-delay="):
			delay = float(a.trim_prefix("--shot-delay="))
		elif a.begins_with("--shot="):
			path = a.trim_prefix("--shot=")
	if path != "":
		_shoot(path, delay)

func _shoot(path: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
