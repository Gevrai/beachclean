extends Node
## Dev-only: `-- --shot=path.png` saves a screenshot after ~2 s (`--shot-delay=SECONDS` to change) and quits.
## `-- --fps=SECONDS` measures the average fps (vsync off) and prints "FPS: n" (tools/fps). No effect otherwise.

func _ready() -> void:
	var delay := 2.0
	var path := ""
	var fps_secs := 0.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-delay="):
			delay = float(a.trim_prefix("--shot-delay="))
		elif a.begins_with("--shot="):
			path = a.trim_prefix("--shot=")
		elif a.begins_with("--fps="):
			fps_secs = float(a.trim_prefix("--fps="))
	if path != "":
		_shoot(path, delay)
	if fps_secs > 0.0:
		_measure_fps(fps_secs)

func _shoot(path: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()

func _measure_fps(secs: float) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await get_tree().create_timer(3.0).timeout  # warm-up
	var f0 := Engine.get_frames_drawn()
	var t0 := Time.get_ticks_msec()
	await get_tree().create_timer(secs).timeout
	var fps := float(Engine.get_frames_drawn() - f0) / ((Time.get_ticks_msec() - t0) / 1000.0)
	print("FPS: %.1f" % fps)
	get_tree().quit()
