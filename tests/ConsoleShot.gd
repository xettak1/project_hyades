extends Control
## Renders the Mission Console's four steps at its in-game size (800 x 560): /tmp/console_<n>.png
func _ready() -> void:
	MissionState.start_mission("flood_watch")
	for cat in ["payload", "solar", "battery", "comms"]:
		MissionState.picks[cat] = GameData.parts_for("flood_watch")[cat].keys()[0]
	var bg := ColorRect.new()
	bg.color = UI.COLOR_BG
	bg.size = Vector2(800, 560)
	add_child(bg)
	var m := MarginContainer.new()
	m.size = Vector2(800, 560)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 18)
	add_child(m)
	var p = load("res://scripts/panels/ConsolePanel.gd").new()
	m.add_child(p)
	for i in 4:
		if i == 2:
			MissionState.set_rocket("spacex_rideshare")
		p.go_step(i)
		for f in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/console_%d.png" % i)
	get_tree().quit()
