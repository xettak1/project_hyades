extends Node
## Screenshots of each level's environment (and the launch sequence).
var which := ""

func _shot(name: String, frames: int = 20) -> void:
	for i in frames:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/tmp/env/%s.png" % name)
	print("saved ", name)

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func run(level: String) -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/env")
	MissionState.start_mission("flood_watch")
	MissionState.tutor_enabled = false
	MissionState.pick("adcs", "fcw_adcs_advanced")
	MissionState.set_orbit("sso_700")
	var idx := ["launch", "space", "ground", "user"].find(level)
	LevelFlow.index = idx
	MissionState.level_results = {"launch": MissionState.launch_results(),
		"space": {"days": 30, "collected_gb": 22.5, "stored_gb": 22.5, "useful_gb": 22.0, "overflow_gb": 0.0, "scanned": ["volta", "niger_delta", "benue"]},
		"ground": {"received_gb": 15.0, "lost_gb": 7.5, "delay_days": 1.5}}
	get_tree().change_scene_to_file(LevelFlow.LEVELS[idx]["scene"])
	await _shot(level + "_0_spawn", 40)
	var room = get_tree().current_scene
	match level:
		"launch":
			room.player.teleport(Vector3(-4, 0.1, room.hz - 2.5), 180.0)
			room.player.cam.rotation.x = deg_to_rad(8)
			await _shot("launch_1_window", 30)
			room._launch()
			await _wait(1.5)
			await _shot("launch_2_countdown", 2)
			await _wait(3.5)
			await _shot("launch_3_ignition", 2)
			await _wait(3.0)
			await _shot("launch_4_liftoff", 2)
			await _wait(4.0)
			await _shot("launch_5_chase", 2)
			await _wait(4.0)
			await _shot("launch_6_high", 2)
		_:
			if room.has_method("test_views"):
				await room.test_views(self)
	get_tree().quit()
