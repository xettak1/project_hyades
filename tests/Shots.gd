extends Node
# Renders screenshots of the title, mission select and every mission world (needs a display).

func _shot(name: String, frames: int = 15) -> void:
	for i in frames:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/tmp/shots/%s.png" % name)
	print("saved ", name)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/shots")
	var title = load("res://scenes/Main.tscn").instantiate()
	add_child(title)
	await _shot("0_title")
	title._show(title._select)
	await _shot("0_select")
	title.queue_free()
	for mid in GameData.MISSION_ORDER:
		MissionState.start_mission(mid)
		var lab = load("res://scenes/Lab.tscn").instantiate()
		add_child(lab)
		await get_tree().process_frame
		var p = lab.player
		p.teleport(lab.spawn, 0.0); p.cam.rotation.x = 0.05
		await _shot(mid + "_1_spawn")
		p.teleport(Vector3(-lab.hx + 2.6 * lab.ps, 0.1, lab._slot_z(0)), 90.0); p.cam.rotation.x = -0.35
		await _shot(mid + "_2_shelf")
		lab._launch()
		await get_tree().create_timer(3.0).timeout
		p.teleport(lab.ops_spot, 180.0); p.cam.rotation.x = 0.15
		await _shot(mid + "_3_ops")
		lab.queue_free()
		await get_tree().process_frame
	get_tree().quit()
