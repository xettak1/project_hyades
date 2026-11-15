extends Node
func _ready() -> void:
	MissionState.start_mission("flood_watch")
	var m := MissionState.mission()
	print("budget ", m["budget"], " mass ", m["mass_limit"], " req ", m["requirements"], " orbits ", m["orbits"], " rockets ", m["rockets"])
	print("cats ", MissionState.categories())
	print("weights ", GameData.SCORE_WEIGHTS)
	var x: Dictionary = MissionState.compute()["extra"]
	print("default: mass %.2f cost %.2f load %.1f gen %.1f need %.1f usable %.1f data %.2f dl %.2f useful %.2f revisit %d life %.1f" % [x["mass"], x["cost"], x["load_w"], x["gen_avg"], x["need_wh"], x["usable_wh"], x["data_gen"], x["downlink"], x["useful_per_day"], x["revisit"], x["life_cap"]])
	print(MissionState.gate())
	for r in MissionState.assess():
		print("  %-40s %10s  %s" % [r["label"], r["shown"], MissionState.LEVEL_NAMES[r["level"]]])
	for d in [["all advanced", {"payload": "fcw_payload_advanced", "solar": "fcw_solar_advanced", "battery": "fcw_battery_advanced", "comms": "fcw_comms_advanced", "computer": "fcw_computer_advanced", "adcs": "fcw_adcs_advanced", "propulsion": "fcw_propulsion_advanced", "thermal": "fcw_thermal_advanced"}]]:
		for cat in d[1]:
			MissionState.picks[cat] = d[1][cat]
		MissionState.orbit_id = "sso_700"
		print("-- ", d[0])
		for r in MissionState.assess():
			if r["level"] > 0:
				print("  %-40s %10s  %s" % [r["label"], r["shown"], MissionState.LEVEL_NAMES[r["level"]]])
	get_tree().quit()
