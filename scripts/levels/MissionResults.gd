extends Node3D
## MISSION RESULTS: final cinematic view of Earth + the mission report.
## Increment 1: the score still comes from the existing Simulator (whole mission), plus a summary
## of what each segment achieved. The 9-part evaluation and Dove comparison come in increment 6.

const Simulator := preload("res://scripts/sim/Simulator.gd")
var _cam: Camera3D
var _earth: Node3D
var _t := 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MissionState.phase = "results"
	var sim = Simulator.new()
	sim.setup(MissionState.compute(), MissionState.mission()["requirements"], MissionState.lifetime_years)
	while not sim.done:
		sim.step_day()
	var r: Dictionary = sim.result()
	MissionState.last_result = r
	MissionState.runs += 1
	MissionState.best_scores[MissionState.mission_id] = maxi(MissionState.best_score, int(r["score"]))
	_build_space()
	_build_ui()

func _build_space() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.005, 0.005, 0.02)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.15, 0.17, 0.25)
	e.glow_enabled = true
	we.environment = e
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-10, -70, 0)
	sun.light_energy = 1.6
	add_child(sun)
	_earth = ModelLib.fit("earth", 7.0, "center")
	if _earth == null:
		_earth = PartModels.ball(3.5, PartModels.mat(Color(0.2, 0.45, 0.9)))
	_earth.position = Vector3(4.5, -1.0, -2.0)
	add_child(_earth)
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 0.5, 9)
	_cam.current = true
	add_child(_cam)

func _process(delta: float) -> void:
	_t += delta
	_earth.rotate_y(delta * 0.06)
	_cam.look_at(Vector3(1.5, 0, 0), Vector3.UP)

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", FUI.box(Color(0.03, 0.06, 0.12, 0.92), Color(FUI.SKY, 0.4), 10, 18))
	p.position = Vector2(40, 24)
	p.custom_minimum_size = Vector2(800, 670)
	ui.add_child(p)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	var v := FUI.vb(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	# Buttons first so they are always visible
	var top := FUI.hb(10)
	v.add_child(top)
	var report := preload("res://scripts/panels/ResultsPanel.gd").new()
	v.add_child(report)
	v.add_child(FUI.hline())
	v.add_child(FUI.t("WHAT EACH SEGMENT ACHIEVED", 13, FUI.AMBER, "mono_semi"))
	var r: Dictionary = MissionState.level_results
	var l: Dictionary = r.get("launch", {})
	var s: Dictionary = r.get("space", {})
	var g: Dictionary = r.get("ground", {})
	var u: Dictionary = r.get("user", {})
	for line in [
		"1 LAUNCH   %s to %s · %.1f kg · $%.2fM left" % [l.get("rocket", "-"), l.get("orbit", "-"), l.get("mass_kg", 0.0), l.get("budget_left", 0.0)],
		"2 SPACE    %.1f GB collected in %d days · %.1f GB stored" % [s.get("collected_gb", 0.0), int(s.get("days", 0)), s.get("stored_gb", 0.0)],
		"3 GROUND   %.1f GB received · %.1f GB lost · %.1f days delay" % [g.get("received_gb", 0.0), g.get("lost_gb", 0.0), g.get("delay_days", 0.0)],
		"4 USER     %d%% of the region covered by the report" % int(100.0 * u.get("coverage", 0.0))]:
		v.add_child(FUI.t(line, 14, FUI.TEXT2, "mono"))
	var row := top
	var again := UI.button("FLY AGAIN FROM LEVEL 1", 18)
	again.pressed.connect(func():
		MissionState.start_mission(MissionState.mission_id)
		MissionState.tutor_enabled = false
		LevelFlow.start())
	row.add_child(again)
	var menu := UI.button("MAIN MENU", 18)
	menu.pressed.connect(LevelFlow.to_title)
	row.add_child(menu)
