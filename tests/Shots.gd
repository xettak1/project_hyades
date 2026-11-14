extends Node
# Renders screenshots of the title, every mission world, exhibits, orbit view and a full-view screen.

func _shot(name: String, frames: int = 20) -> void:
	for i in frames:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/tmp/shots/%s.png" % name)
	print("saved ", name)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/shots")
	var title = load("res://scenes/Main.tscn").instantiate()
	add_child(title)
	await _shot("0_title", 40)
	title.queue_free()
	for mid in GameData.MISSION_ORDER:
		MissionState.start_mission(mid)
		var lab = load("res://scenes/Lab.tscn").instantiate()
		add_child(lab)
		await get_tree().process_frame
		var p = lab.player
		p.teleport(lab.spawn + Vector3(0, 0, 2.0), 0.0); p.cam.rotation.x = 0.1
		await _shot(mid + "_1_spawn")
		p.teleport(lab.spawn + Vector3(0, 0, -1.0), 0.0); p.rotation_degrees.y = 35; p.cam.rotation.x = 0.15
		await _shot(mid + "_2_exhibit_left")
		var console = lab.find_children("*", "StaticBody3D", true, false).filter(func(n): return "screen_name" in n and n.screen_name == "Mission Console")[0]
		console.interact()
		await _shot(mid + "_3_console_fullview")
		get_tree().call_group("screenview", "close")
		lab._launch()
		await get_tree().create_timer(3.0).timeout
		p.teleport(lab.ops_spot, 180.0); p.cam.rotation.x = 0.12
		await _shot(mid + "_4_ops")
		var mon = lab.find_children("*", "StaticBody3D", true, false).filter(func(n): return "screen_name" in n and n.screen_name == "Orbit & Trajectory Monitor")[0]
		mon.interact()
		await _shot(mid + "_5_monitor_fullview", 30)
		get_tree().call_group("screenview", "close")
		lab.queue_free()
		await get_tree().process_frame
	get_tree().quit()
