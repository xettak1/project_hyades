extends Node
## Screenshots of the in-level interface (instructions, resources, decision card, tutor) in all four levels.
func _shot(name: String, frames := 30) -> void:
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/ui/%s.png" % name)

func _skip_card() -> void:
	var prev = get_tree().current_scene
	var waited := 0.0
	while get_tree().current_scene == prev and waited < 20.0 and not LevelFlow.busy:
		await get_tree().create_timer(0.2).timeout
		waited += 0.2
	while LevelFlow.busy:
		Input.parse_input_event(_key(KEY_SPACE))
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(0.6).timeout

func _key(k: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.pressed = true
	return e

func _ready() -> void:
	if get_tree().current_scene == self:
		var d = load("res://tests/UIShots.gd").new()
		d.name = "UIDriver"
		get_tree().root.add_child.call_deferred(d)
		return
	DirAccess.make_dir_recursive_absolute("/tmp/ui")
	SaveGame.play_intro = false
	MissionState.start_mission("flood_watch")
	MissionState.tutor_enabled = true
	MissionState.tutor_steps = {}
	LevelFlow.start()
	await _skip_card()
	var lab = get_tree().current_scene
	await _shot("1a_intro", 60)
	get_tree().call_group("tutor", "next")
	get_tree().call_group("tutor", "on_part_focus", "payload")
	get_tree().call_group("decision", "show_part", "payload", "fcw_payload_advanced")
	await _shot("1b_card", 40)
	get_tree().call_group("tutor", "next")
	MissionState.set_rocket("spacex_rideshare")
	await _shot("1c_react", 60)
	get_tree().call_group("decision", "hide_part", "payload", "fcw_payload_advanced")
	MissionState.set_orbit("sso_700")
	lab._launch()
	await _skip_card()
	var sp = get_tree().current_scene
	await _shot("2a_space", 60)
	MissionState.tutor_steps["space"] = 2
	get_tree().call_group("tutor", "on_screen_opened", "Observation Console")
	for r in FarmRegions.REGIONS:
		if sp.in_view(r["id"]):
			sp.select_region(r["id"])
			break
	await _shot("2b_selected", 60)
	sp.end_campaign()
	await _skip_card()
	var gs = get_tree().current_scene
	gs.set_priority("floods")
	gs.start_pass()
	await get_tree().create_timer(14.0).timeout
	await _shot("3_ground", 10)
	await _skip_card()
	var us = get_tree().current_scene
	get_tree().call_group("tutor", "on_screen_opened", "Analysis Workstation")
	for p in us.plots:
		if p["seen"] and FarmRegions.is_flood(p["state"]):
			us.toggle_mark(p["id"])
			break
	await _shot("4_user", 60)
	get_tree().quit()
