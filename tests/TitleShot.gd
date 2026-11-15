extends Node
## Screenshots of the title screen pages and the intro. SHOT env var: title | intro
func _ready() -> void:
	var what := OS.get_environment("SHOT")
	DirAccess.make_dir_recursive_absolute("/tmp/title")
	if what == "intro":
		var s = load("res://scenes/Intro.tscn").instantiate()
		get_tree().root.add_child.call_deferred(s)
		await get_tree().process_frame
		await get_tree().process_frame
		for t in [3.0, 7.0, 11.0, 13.5, 18.0, 21.5, 26.5, 30.0, 35.0, 39.5]:
			while s._t < t:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("/tmp/title/intro_%04.1f.png" % t)
		get_tree().quit()
		return
	var s = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(s)
	await get_tree().create_timer(2.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/title/menu.png")
	s._show(s._options)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/title/options.png")
	s._show(s._brief)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/title/brief.png")
	get_tree().quit()

var _t0 := 0.0
func _enter_tree() -> void:
	_t0 = Time.get_ticks_msec() / 1000.0
