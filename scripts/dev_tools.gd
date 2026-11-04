extends Node
## Dev-only: `-- --shot=path.png` saves a screenshot after ~2 s and quits. No effect otherwise.

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shoot(a.trim_prefix("--shot="))

func _shoot(path: String) -> void:
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
