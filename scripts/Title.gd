extends Node3D
## Title screen and mission select. A slowly turning Earth and Moon behind the menu.

var _cam: Camera3D
var _earth: MeshInstance3D
var _globe: Node3D
var _sat: Node3D
var _t := 0.0
var _menu: Control
var _select: Control
var _help: Control

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	_build_space()
	var ui := CanvasLayer.new()
	add_child(ui)
	_menu = _build_menu()
	ui.add_child(_menu)
	_select = _build_select()
	ui.add_child(_select)
	_help = _build_help()
	ui.add_child(_help)
	_show(_select if MissionState.open_select else _menu)
	MissionState.open_select = false

# ---------------------------------------------------------------- 3D backdrop
func _build_space() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.005, 0.005, 0.02)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.15, 0.17, 0.25)
	we.environment = e
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-15, -60, 0)
	sun.light_energy = 1.5
	add_child(sun)

	_earth = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 3.0
	s.height = 6.0
	s.radial_segments = 64
	s.rings = 32
	_earth.mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.45, 0.9)
	if ResourceLoader.exists("res://assets/earth.jpg"):
		m.albedo_texture = load("res://assets/earth.jpg")
		m.albedo_color = Color.WHITE
	_earth.material_override = m
	_earth.position = Vector3(2.5, -0.5, 0)
	add_child(_earth)
	var glb_earth := ModelLib.fit("earth", 6.0, "center")
	if glb_earth:
		_earth.visible = false
		glb_earth.position = _earth.position
		add_child(glb_earth)
		_globe = glb_earth
	_sat = ModelLib.fit("sc_cubesat", 0.5, "center")
	if _sat:
		add_child(_sat)
	add_child(PartModels.ball(0.8, PartModels.mat(Color(0.65, 0.65, 0.62), 0.0, 0.95), Vector3(-6, 2.5, -9)))

	# Stars
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var star := SphereMesh.new()
	star.radius = 0.05
	star.height = 0.1
	star.radial_segments = 4
	star.rings = 2
	mm.mesh = star
	mm.instance_count = 500
	for i in 500:
		var dir := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 0.2)).normalized()
		mm.set_instance_transform(i, Transform3D(Basis(), dir * randf_range(40, 60)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = PartModels.mat(Color(1, 1, 1), 0.0, 0.5, 4.0)
	add_child(mmi)

	_cam = Camera3D.new()
	_cam.position = Vector3(0, 0.5, 10)
	_cam.current = true
	add_child(_cam)

func _process(delta: float) -> void:
	_t += delta
	_earth.rotate_y(delta * 0.08)
	if _globe:
		_globe.rotate_y(delta * 0.08)
	if _sat:
		var a := _t * 0.25
		_sat.position = Vector3(2.5 + cos(a) * 4.0, -0.5 + sin(a) * 1.2, sin(a) * 4.0)
		_sat.rotate_y(delta * 0.6)
	_cam.position = Vector3(sin(_t * 0.05) * 1.5, 0.5 + sin(_t * 0.07) * 0.4, 10)
	_cam.look_at(Vector3(0.5, 0, 0), Vector3.UP)

# ---------------------------------------------------------------- menus
func _show(panel: Control) -> void:
	for p in [_menu, _select, _help]:
		p.visible = (p == panel)

func _full() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c

func _build_menu() -> Control:
	var root := _full()
	var v := UI.vbox(14)
	v.position = Vector2(70, 120)
	v.custom_minimum_size = Vector2(520, 0)
	root.add_child(v)
	v.add_child(UI.label("MISSION CONTROL", 56, UI.COLOR_ACCENT))
	v.add_child(UI.label("Design a spacecraft. Launch it. Find out why it worked, or why it didn't.", 20, UI.COLOR_MUTED))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	v.add_child(gap)
	var start := UI.button("START GAME", 24)
	start.custom_minimum_size = Vector2(320, 56)
	start.pressed.connect(func(): _show(_select))
	v.add_child(start)
	var help := UI.button("HOW TO PLAY", 20)
	help.custom_minimum_size = Vector2(320, 48)
	help.pressed.connect(func(): _show(_help))
	v.add_child(help)
	var quit := UI.button("QUIT", 20)
	quit.custom_minimum_size = Vector2(320, 48)
	quit.pressed.connect(func(): get_tree().quit())
	v.add_child(quit)
	v.add_child(UI.label("Built with NASA resources: mission segments, Concept Maturity Levels, Mission Design Lab, GMAT, CubeSat 101.", 14, UI.COLOR_MUTED))
	return root

func _build_help() -> Control:
	var root := _full()
	var p := UI.panel(Color(0.06, 0.08, 0.14, 0.92))
	p.position = Vector2(70, 80)
	p.custom_minimum_size = Vector2(700, 0)
	root.add_child(p)
	var v := UI.vbox(10)
	p.add_child(v)
	v.add_child(UI.label("HOW TO PLAY", 30, UI.COLOR_ACCENT))
	for line in [
		"1. Start the Flood & Crop Watch mission. Pick 'With tutor' the first time: a mission engineer guides you step by step.",
		"2. Read the Briefing screen: your objective and the requirements you must meet.",
		"3. Walk to the shelves (WASD + mouse). Look at a part to read its specs, press E to install it on your spacecraft.",
		"4. Watch the Resources and Advisors screens: every part costs mass, power and money.",
		"5. At the Mission Console pick orbit (or trajectory) and rocket, then press LAUNCH.",
		"6. Watch your mission fly in Mission Control and read the report: it explains why it worked or failed.",
		"7. Improve the design and launch again. Esc opens the menu."]:
		v.add_child(UI.label(line, 18))
	var back := UI.button("BACK", 20)
	back.pressed.connect(func(): _show(_menu))
	v.add_child(back)
	return root

func _build_select() -> Control:
	var root := _full()
	var v := UI.vbox(16)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 50
	v.offset_right = -50
	v.offset_top = 40
	v.offset_bottom = -40
	root.add_child(v)
	v.add_child(UI.label("YOUR MISSION", 38, UI.COLOR_ACCENT))
	var row := UI.hbox(18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)
	for id in GameData.MISSION_ORDER:
		var c := _card(id)
		if GameData.MISSION_ORDER.size() == 1:
			c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			c.custom_minimum_size = Vector2(620, 0)
		row.add_child(c)
	var back := UI.button("BACK", 20)
	back.custom_minimum_size = Vector2(160, 44)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func(): _show(_menu))
	v.add_child(back)
	return root

func _card(id: String) -> Control:
	var m: Dictionary = GameData.MISSIONS[id]
	var accent: Color = m["env"]["accent"]
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.panel_style(Color(0.06, 0.08, 0.14, 0.92), accent, 2))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(10)
	p.add_child(v)
	v.add_child(UI.label(m["difficulty"].to_upper(), 16, accent))
	v.add_child(UI.label(m["name"], 26))
	v.add_child(UI.label(m["spacecraft_class"] + "  -  " + m["env"]["title"].capitalize(), 15, UI.COLOR_MUTED))
	v.add_child(UI.label(m["objective"], 17))
	var ch := UI.label(m["challenge"], 16, UI.COLOR_WARN)
	ch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(ch)
	v.add_child(UI.label("Budget $%s M   Mass limit %s kg" % [str(m["budget"]), str(m["mass_limit"])], 14, UI.COLOR_MUTED))
	var best: int = MissionState.best_scores.get(id, 0)
	if best > 0:
		v.add_child(UI.label("Your best: %d / 1000" % best, 15, UI.COLOR_GOOD))
	var bt := UI.button("START WITH TUTOR (recommended)", 20)
	bt.pressed.connect(func(): _start(id, true))
	v.add_child(bt)
	var b := UI.button("START WITHOUT TUTOR", 18)
	b.pressed.connect(func(): _start(id, false))
	v.add_child(b)
	return p

func _start(id: String, tutor: bool) -> void:
	MissionState.start_mission(id)
	MissionState.tutor_enabled = tutor
	MissionState.tutor_step = 0
	MissionState.tutor_done = false
	get_tree().change_scene_to_file("res://scenes/Lab.tscn")
