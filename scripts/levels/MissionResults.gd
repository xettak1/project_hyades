extends Node3D
## MISSION DEBRIEF: Earth turning in the background and a report card for each level:
## a GOOD / FAIR / POOR verdict, the key numbers, what went right and what to improve.
## The overall score is the average of the four level scores (see scripts/sim/Debrief.gd).

var _cam: Camera3D
var _earth: Node3D
var _t := 0.0

var _deb: Dictionary

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MissionState.phase = "results"
	_deb = Debrief.build()
	var score: int = _deb["score"]
	MissionState.last_result = {"score": score, "rating": _deb["rating"], "debrief": _deb}
	MissionState.runs += 1
	MissionState.best_scores[MissionState.mission_id] = maxi(MissionState.best_score, score)
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

const VERDICT_COLOR := {"GOOD": FUI.GREEN, "FAIR": FUI.AMBER, "POOR": FUI.RED, "NOT PLAYED": FUI.DIM}

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 28)
	ui.add_child(root)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", FUI.box(Color(0.03, 0.06, 0.12, 0.88), Color(FUI.SKY, 0.35), 12, 22))
	root.add_child(p)
	var v := FUI.vb(14)
	p.add_child(v)

	# Header: title, score, rating and the two buttons.
	var head := FUI.hb(18)
	v.add_child(head)
	var tv := FUI.vb(2)
	head.add_child(tv)
	tv.add_child(FUI.cap("MISSION DEBRIEF  ·  " + str(MissionState.mission().get("name", "")), 14, FUI.MUTED))
	var score: int = _deb["score"]
	var sc_col: Color = FUI.GREEN if score >= 650 else (FUI.AMBER if score >= 450 else FUI.RED)
	var sr := FUI.hb(14)
	tv.add_child(sr)
	sr.add_child(FUI.t(_deb["rating"], 34, sc_col, "sans_semi"))
	var num := FUI.t("%d / 1000" % score, 22, FUI.TEXT2, "mono_semi")
	num.size_flags_vertical = Control.SIZE_SHRINK_END
	sr.add_child(num)
	tv.add_child(FUI.t("Best so far %d  ·  run %d" % [MissionState.best_score, MissionState.runs], 13, FUI.DIM, "mono"))
	head.add_child(FUI.grow())
	var again := UI.button("FLY AGAIN", 18)
	again.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	again.pressed.connect(func():
		MissionState.start_mission(MissionState.mission_id)
		MissionState.tutor_enabled = false
		LevelFlow.start())
	head.add_child(again)
	var menu := UI.button("MAIN MENU", 18)
	menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menu.pressed.connect(LevelFlow.to_title)
	head.add_child(menu)
	v.add_child(FUI.hline())

	# Four level cards in a 2x2 grid.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)
	var i := 0
	for e in _deb["levels"]:
		i += 1
		grid.add_child(_level_card(i, e))

func _level_card(n: int, e: Dictionary) -> Control:
	var col: Color = VERDICT_COLOR.get(e["verdict"], FUI.DIM)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := FUI.box(Color(0.05, 0.08, 0.15, 0.92), Color(col, 0.55), 10, 16)
	sb.border_width_left = 5
	card.add_theme_stylebox_override("panel", sb)
	var v := FUI.vb(6)
	card.add_child(v)
	var h := FUI.hb(10)
	v.add_child(h)
	h.add_child(FUI.t("%d  %s" % [n, e["title"]], 22, FUI.WHITE, "sans_semi"))
	h.add_child(FUI.grow())
	if e["verdict"] != Debrief.NONE:
		h.add_child(FUI.t("%d" % int(round(e["score"])), 16, FUI.MUTED, "mono_semi"))
	var chip := FUI.chip(e["verdict"], col)
	(chip.get_child(0) as Label).add_theme_font_size_override("font_size", 15)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(chip)
	v.add_child(_wrap(e["stat"], 14, FUI.TEXT2, "mono"))
	if e["verdict"] != Debrief.NONE:
		v.add_child(FUI.cap("DID RIGHT", 12, FUI.GREEN))
		for line in e["right"]:
			v.add_child(_point(line, FUI.GREEN))
		if (e["right"] as Array).is_empty():
			v.add_child(_point("Nothing stood out this time.", FUI.MUTED))
	if not (e["improve"] as Array).is_empty():
		v.add_child(FUI.cap("COULD IMPROVE", 12, FUI.AMBER))
		for line in e["improve"]:
			v.add_child(_point(line, FUI.AMBER))
	elif e["verdict"] != Debrief.NONE:
		v.add_child(FUI.cap("COULD IMPROVE", 12, FUI.AMBER))
		v.add_child(_point("Nothing major. This level was flown well.", FUI.MUTED))
	return card

func _point(text: String, col: Color) -> Control:
	var r := FUI.hb(8)
	var d := FUI.dot(col, 7.0)
	d.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var holder := MarginContainer.new()
	holder.add_theme_constant_override("margin_top", 7)
	holder.add_child(d)
	r.add_child(holder)
	var l := _wrap(text, 15, FUI.TEXT, "sans")
	r.add_child(l)
	return r

func _wrap(text: String, size: int, col: Color, kind: String) -> Label:
	var l := FUI.t(text, size, col, kind)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 200
	return l
