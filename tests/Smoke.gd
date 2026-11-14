extends Node
# Headless smoke test: title screen, every mission's world, and several designs per mission.

const Simulator := preload("res://scripts/sim/Simulator.gd")

const DESIGNS := {
	"flood_watch": {
		"good": {"parts": {"solar": "solar_deploy", "battery": "bat_30", "comms": "radio_x", "adcs": "adcs_precise", "computer": "obc_big"}, "orbit": "sso_550", "rocket": "rideshare_sso", "life": 3},
	},
	"radar_mapper": {
		"good": {"parts": {"payload": "sar_large", "solar": "rsolar_wing", "comms": "rradio_x", "computer": "robc_2t"}, "orbit": "sso_700", "rocket": "rideshare_sso_big", "life": 5},
		"leo_cheap": {"parts": {"payload": "sar_small", "comms": "rradio_x"}, "orbit": "leo_500", "rocket": "falcon9", "life": 5},
		"all_adv": {"parts": {"payload": "sar_large", "solar": "rsolar_wing", "battery": "rbat_4k", "comms": "rradio_ka", "computer": "robc_2t", "adcs": "radcs_precise", "propulsion": "rprop_large"}, "orbit": "sso_700", "rocket": "rideshare_sso_big", "life": 6},
	},
	"lunar_mapper": {
		"good": {"parts": {"payload": "nac", "solar": "lsolar_2", "battery": "lbat_3", "comms": "lradio_ka", "computer": "lobc_1t", "adcs": "ladcs_precise", "propulsion": "tank_large"}, "orbit": "lunar_direct", "rocket": "falcon9_tli", "life": 2},
		"small_tank_direct": {"parts": {"payload": "nac", "solar": "lsolar_2", "comms": "lradio_ka", "computer": "lobc_1t"}, "orbit": "lunar_direct", "rocket": "falcon9_tli", "life": 1},
		"small_tank_lowE": {"parts": {"payload": "nac", "solar": "lsolar_2", "comms": "lradio_ka", "computer": "lobc_1t"}, "orbit": "lunar_low_energy", "rocket": "falcon9_tli", "life": 1},
	},
}

func _ready() -> void:
	var title = load("res://scenes/Main.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame
	title.queue_free()
	print("title ok")
	for mid in GameData.MISSION_ORDER:
		MissionState.start_mission(mid)
		var lab = load("res://scenes/Lab.tscn").instantiate()
		add_child(lab)
		await get_tree().process_frame
		await get_tree().physics_frame
		var parts: Array = lab.find_children("*", "StaticBody3D", true, false).filter(func(n): return n.has_method("setup") and "part_id" in n)
		print("\n##### ", mid, "  parts on shelves: ", parts.size())
		_try(mid, "default", {})
		for dname in DESIGNS[mid]:
			_try(mid, dname, DESIGNS[mid][dname])
		# full-view screen: open the console screen and click its LAUNCH button through the overlay
		var sv = lab.find_children("*", "CanvasLayer", true, false).filter(func(n): return n.has_method("open") and n.has_method("is_open"))[0]
		var screens: Array = lab.find_children("*", "StaticBody3D", true, false).filter(func(n): return "screen_name" in n)
		print("screens: ", screens.map(func(n): return n.screen_name))
		var console = screens.filter(func(n): return n.screen_name == "Mission Console")[0]
		console.interact()
		await get_tree().process_frame
		await get_tree().process_frame
		var launch_btn = console.viewport.find_children("*", "Button", true, false).filter(func(b): return b.text == "LAUNCH")[0]
		var r: Rect2 = sv._image_rect()
		var bc: Vector2 = launch_btn.get_global_rect().get_center()
		var win_pos: Vector2 = r.position + bc / Vector2(console.viewport.size) * r.size
		for pressed in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = pressed
			ev.position = win_pos
			sv._input(ev)
			await get_tree().process_frame
		print("view open: ", sv.is_open(), "  phase after clicking LAUNCH on screen: ", MissionState.phase, "  status: ", console.viewport.find_children("*", "Label", true, false).map(func(l): return l.text).filter(func(t): return t.begins_with("LAUNCH") or "warning" in t))
		sv.close()
		# real flow through the world: launch + skip
		lab._launch()
		lab._skip()
		print("world run: ", MissionState.last_result.get("score"))
		lab.queue_free()
		await get_tree().process_frame
	print("SMOKE TEST DONE")
	get_tree().quit()

func _try(mid: String, dname: String, d: Dictionary) -> void:
	MissionState.start_mission(mid)
	for cat in d.get("parts", {}):
		MissionState.pick(cat, d["parts"][cat])
	if d.has("orbit"):
		MissionState.set_orbit(d["orbit"]); MissionState.set_rocket(d["rocket"]); MissionState.set_lifetime(d["life"])
	var c := MissionState.compute()
	var x: Dictionary = c["extra"]
	var g := MissionState.gate()
	var sim = Simulator.new()
	sim.setup(c, MissionState.mission()["requirements"], MissionState.lifetime_years, 7)
	while not sim.done:
		sim.step_day()
	var r: Dictionary = sim.result()
	print("-- %s: mass %.1f cost %.1f load %.0f gen %.0f dl %.1f data %.1f life_cap %.1f fuel_left %.0f | hard %d warn %d | score %d %s" % [dname, x.mass, x.cost, x.load_w, x.gen_avg, x.downlink, x.data_gen, x.life_cap, x.fuel_left, g.hard.size(), g.warn.size(), r.score, r.rating])
	if g.hard.size() > 0:
		print("   HARD: ", g.hard)
	print("   why: ", r.why.slice(0, 2))
