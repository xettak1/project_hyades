extends Node
## Plays the four-level flow end to end (lives on the root so it survives scene changes).

func _shot(name: String, frames: int = 20) -> void:
	for i in frames:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/tmp/flow/%s.png" % name)
	print("saved ", name, "  scene=", get_tree().current_scene.name if get_tree().current_scene else "-", "  level=", LevelFlow.index)

func _wait_card_then_skip(name: String) -> void:
	while not LevelFlow._card.visible:
		await get_tree().process_frame
	await _shot(name, 25)
	LevelFlow._skip = true
	while LevelFlow.busy:
		await get_tree().process_frame

func run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/flow")
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
	await _shot("0_title", 20)
	SaveGame.play_intro = false
	SaveGame.tutor = true
	get_tree().current_scene._new_game()
	await _shot("0_briefing", 10)
	LevelFlow.start()
	await _wait_card_then_skip("1_card_launch")
	var lab = get_tree().current_scene
	await _shot("1_launch_room", 20)
	print("start: mass=%.2f cost=%.2f gate_hard=%d" % [MissionState.compute()["extra"]["mass"], MissionState.compute()["extra"]["cost"], MissionState.gate()["hard"].size()])
	for cat in MissionState.categories():      # nothing is preselected: install the simple parts
		MissionState.pick(cat, GameData.parts_for(MissionState.mission_id)[cat].keys()[0])
	MissionState.set_rocket(MissionState.mission()["rockets"][0])
	MissionState.pick("adcs", "fcw_adcs_advanced")
	MissionState.set_orbit("sso_700")
	lab._launch()
	await _wait_card_then_skip("2_card_space")
	await _shot("2_space_room", 140)
	var sp = get_tree().current_scene
	for k in 3:
		var waited := 0
		while waited < 900:
			var ok := false
			for r in FarmRegions.REGIONS:
				if sp.in_view(r["id"]) and not sp.scanned.has(r["id"]) and sp.cloud_now(r["id"]) < sp.CLOUD_LIMIT:
					sp.select_region(r["id"])
					ok = true
					break
			if ok:
				break
			await get_tree().process_frame
			waited += 1
		sp.scan()
		while sp.scanning:
			await get_tree().process_frame
	sp.end_campaign()
	await _wait_card_then_skip("3_card_ground")
	await _shot("3_ground_room", 140)
	get_tree().current_scene.start_pass()
	await _wait_card_then_skip("4_card_user")
	await _shot("4_user_room", 20)
	var us = get_tree().current_scene
	for p in us.plots:
		if p["seen"] and FarmRegions.is_flood(p["state"]):
			us.toggle_mark(p["id"])
	us.set_product("alert")
	us.deliver()
	while not MissionState.level_results.has("user") or LevelFlow.busy:
		await get_tree().process_frame
	await _shot("5_results", 30)
	for k in MissionState.level_results:
		print(k, ": ", MissionState.level_results[k])
	print("score: ", MissionState.last_result.get("score"), " ", MissionState.last_result.get("rating"))
	print("FLOW TEST DONE")
	get_tree().quit()
