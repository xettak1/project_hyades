extends Node
## For LEVEL=launch|space|ground|user: opens that level and photographs every Screen3D head-on
## (HUD hidden), plus wide views with the HUD. Output: /tmp/scr/<level>_*.png
var level := "launch"

func _ready() -> void:
	if get_tree().current_scene == self:
		var d = load("res://tests/ScreenShots.gd").new()
		d.name = "ScreenDriver"
		get_tree().root.add_child.call_deferred(d)
		return
	level = OS.get_environment("LEVEL") if OS.get_environment("LEVEL") != "" else "launch"
	DirAccess.make_dir_recursive_absolute("/tmp/scr")
	MissionState.start_mission("flood_watch")
	if OS.get_environment("LEVEL") != "launch":
		for cat in MissionState.categories():
			MissionState.picks[cat] = GameData.parts_for(MissionState.mission_id)[cat].keys()[0]
		MissionState.rocket_id = MissionState.mission()["rockets"][0]
	MissionState.tutor_enabled = true
	MissionState.tutor_steps = {}
	MissionState.level_results = {
		"launch": {"mass_kg": 5.0, "orbit": "sso_700"},
		"space": {"days": 30, "collected_gb": 42.0, "useful_gb": 30.0, "stored_gb": 42.0, "overflow_gb": 0.0, "scanned": ["volta", "niger_delta", "benue"], "scans": 5, "passes_total": 10},
		"ground": {"received_gb": 18.0, "lost_gb": 24.0, "left_onboard_gb": 24.0, "capacity_gb": 18.0, "priority": "floods", "delay_days": 2}}
	var idx: int = {"launch": 0, "space": 1, "ground": 2, "user": 3}[level]
	LevelFlow.resume(idx)
	await get_tree().create_timer(0.5).timeout
	while LevelFlow.busy:
		Input.parse_input_event(_key(KEY_SPACE))
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(2.0).timeout
	var room = get_tree().current_scene
	if level == "ground" and room.has_method("start_pass"):
		room.set_priority("floods")
		room.start_pass()
		await get_tree().create_timer(6.0).timeout
	if level == "space" and room.has_method("scan"):
		for r in FarmRegions.REGIONS:
			if room.in_view(r["id"]):
				room.select_region(r["id"])
				room.scan()
				break
		await get_tree().create_timer(3.5).timeout
	await _shot("%s_0_hud" % level, 10)
	# head-on shots of every screen, HUD hidden
	var layers: Array = []
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if n.visible:
			layers.append(n)
			n.visible = false
	var cam := Camera3D.new()
	cam.fov = 50
	room.add_child(cam)
	cam.current = true
	var screens: Array = room.find_children("*", "StaticBody3D", true, false).filter(func(n): return n.get_script() == preload("res://scripts/world/Screen3D.gd"))
	var i := 0
	for s in screens:
		var sz: Vector2 = s.size_m
		var dist: float = maxf(sz.x / 1.6, sz.y / 0.85) / (2.0 * tan(deg_to_rad(25.0))) * 1.05 + 0.15
		cam.global_position = s.global_transform * Vector3(0, 0.03, dist)
		cam.look_at(s.global_transform * Vector3(0, 0.03, 0), Vector3.UP)
		i += 1
		await _shot("%s_s%d_%s" % [level, i, str(s.screen_name).replace(" ", "_")], 12)
	# a wide view of the room
	cam.current = false
	for n in layers:
		n.visible = true
	get_tree().quit()

func _key(k: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.pressed = true
	return e

func _shot(name: String, frames := 30) -> void:
	for f in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/scr/%s.png" % name)
