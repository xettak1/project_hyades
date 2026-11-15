extends Node
## Renders the mission debrief with sample level results: /tmp/debrief_<case>.png
## CASE env: "good" (a strong run) or "mixed" (default; a few mistakes per level).
func _ready() -> void:
	var good := OS.get_environment("CASE") == "good"
	var mid := "flood_watch"
	MissionState.start_mission(mid)
	for cat in GameData.parts_for(mid):
		MissionState.picks[cat] = GameData.parts_for(mid)[cat].keys()[0]
	MissionState.rocket_id = "spacex_rideshare"
	MissionState.level_results = {
		"launch": MissionState.launch_results(),
		"space": {"days": 30.0, "collected_gb": 42.0, "useful_gb": 36.0 if good else 18.0, "stored_gb": 40.0,
			"overflow_gb": 0.0 if good else 2.0, "scanned": ["a", "b", "c", "d"] if good else ["a", "b"], "scans": 9, "passes_total": 12},
		"ground": {"received_gb": 40.0 if good else 30.0, "lost_gb": 0.0 if good else 12.0, "left_onboard_gb": 0.0 if good else 10.0,
			"capacity_gb": 45.0, "priority": "floods" if good else "crops", "delay_days": 1.0 if good else 4.2},
		"user": {"products": ["alert" if good else "report"], "coverage": 0.95 if good else 0.6, "flood_total": 6, "flood_found": 6 if good else 3,
			"false_marks": 0 if good else 2, "unseen_flood": 0 if good else 2, "missed_seen": 0 if good else 1,
			"accuracy": 1.0 if good else 0.33, "delay_days": 1.0, "impact": 0.95 if good else 0.2},
	}
	var d := Debrief.build()
	print("DEBRIEF score=", d["score"], " rating=", d["rating"])
	for e in d["levels"]:
		print("  ", e["title"], " ", e["verdict"], " ", int(e["score"]), " | ", e["stat"])
		for l in e["right"]: print("     + ", l)
		for l in e["improve"]: print("     - ", l)
	add_child(load("res://scenes/MissionResults.tscn").instantiate())
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/debrief_%s.png" % ("good" if good else "mixed"))
	get_tree().quit()
