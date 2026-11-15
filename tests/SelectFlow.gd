extends Node
## Title → mission select → Flood card → trailer (Skip button) → Level 1.
func _ready() -> void:
	if get_tree().current_scene == self:
		var d = load("res://tests/SelectFlow.gd").new()
		get_tree().root.add_child.call_deferred(d)
		return
	DirAccess.make_dir_recursive_absolute("/tmp/sel")
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
	await get_tree().create_timer(1.5).timeout
	SaveGame.play_intro = true
	var t = get_tree().current_scene
	t._new_game()
	await get_tree().create_timer(0.8).timeout
	# locked cards must not start anything
	for c in t._select.find_children("*", "Control", true, false):
		if c is MissionCard and c.locked:
			var e := InputEventMouseButton.new()
			e.pressed = true
			e.button_index = MOUSE_BUTTON_LEFT
			c._gui_input(e)
	await get_tree().create_timer(0.5).timeout
	print("after locked clicks scene=", get_tree().current_scene.name)
	t._launch_flood()
	await get_tree().create_timer(4.0).timeout
	print("trailer scene=", get_tree().current_scene.name)
	await _shot("trailer")
	get_tree().current_scene._skip_btn.pressed.emit()
	while not LevelFlow._card.visible:
		await get_tree().process_frame
	await _shot("level1_card")
	while LevelFlow.busy:
		LevelFlow._skip = true
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	print("now scene=", get_tree().current_scene.name, " level=", LevelFlow.index)
	get_tree().quit()

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/sel/%s.png" % n)
