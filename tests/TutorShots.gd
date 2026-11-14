extends Node
# Walks through the tutor and saves screenshots of key steps.

func _shot(name: String, frames: int = 15) -> void:
	for i in frames:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/tmp/tshots/%s.png" % name)
	print("saved ", name, "  step=", MissionState.tutor_step)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/tshots")
	var title = load("res://scenes/Main.tscn").instantiate()
	add_child(title)
	title._show(title._select)
	await _shot("0_select", 30)
	title.queue_free()
	MissionState.start_mission("flood_watch")
	MissionState.tutor_enabled = true
	MissionState.tutor_step = 0
	MissionState.tutor_done = false
	var lab = load("res://scenes/Lab.tscn").instantiate()
	add_child(lab)
	await get_tree().process_frame
	var tutor = get_tree().get_first_node_in_group("tutor")
	var p = lab.player
	await _shot("1_welcome", 30)
	_enter()
	await _shot("2_move")
	p.global_position += Vector3(0, 0, -3)
	await _shot("3_briefing_arrow")
	var scr = func(nm): return lab.find_children("*", "StaticBody3D", true, false).filter(func(n): return "screen_name" in n and n.screen_name == nm)[0]
	scr.call("Briefing").interact()
	await _shot("4_requirements_fullview")
	get_tree().call_group("screenview", "close")
	await _shot("5_shelves")
	var part = lab.find_children("*", "StaticBody3D", true, false).filter(func(n): return "part_id" in n and n.category == "battery")[0]
	tutor.on_part_focus("battery")
	await _shot("6_install_concept")
	MissionState.pick("battery", "bat_30")
	await get_tree().process_frame
	scr.call("Resources").interact()
	await _shot("7_power")
	_enter()
	await _shot("8_data")
	get_tree().call_group("screenview", "close")
	await _shot("9_radio")
	MissionState.pick("comms", "radio_x")
	await _shot("10_advisors")
	scr.call("Advisors").interact()
	get_tree().call_group("screenview", "close")
	await _shot("11_console_arrow")
	scr.call("Mission Console").interact()
	await _shot("12_console")
	lab._launch()
	await get_tree().create_timer(2.5).timeout
	await _shot("13_ops")
	scr.call("Orbit & Trajectory Monitor").interact()
	await _shot("14_monitor")
	get_tree().call_group("screenview", "close")
	lab._skip()
	await _shot("15_results", 30)
	_enter()
	_enter()
	await _shot("16_done")
	print("tutor_done=", MissionState.tutor_done)
	get_tree().quit()

func _enter() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
