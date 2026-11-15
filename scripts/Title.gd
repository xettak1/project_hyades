extends Node3D
## Title screen: Earth at sunrise filling the bottom of the screen, an astronaut and two
## satellites drifting past, the game logo and copper menu bars on the left.
## Pages: main menu, options (with how to play), mission briefing.

const COPPER := Color(0.92, 0.52, 0.2)
const CREAM := Color(1.0, 0.94, 0.86)
const PANEL_BG := Color(0.07, 0.035, 0.02, 0.86)
const ASTRO_POS := Vector3(1.9, 2.3, -13)

var _cam: Camera3D
var _earth: Node3D
var _astro: Node3D
var _moon: Node3D
var _sats: Array = []
var _glow: MeshInstance3D
var _t := 0.0
var _menu: Control
var _options: Control
var _brief: Control
var _logo: Control

func _ready() -> void:
	SaveGame.load_settings()
	AudioManager.set_music_volume(SaveGame.music_volume)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	_build_space()
	var ui := CanvasLayer.new()
	add_child(ui)
	ui.add_child(_vignette())
	_logo = _build_logo()
	ui.add_child(_logo)
	_menu = _build_menu()
	ui.add_child(_menu)
	_options = _build_options()
	ui.add_child(_options)
	_brief = _build_briefing()
	ui.add_child(_brief)
	if MissionState.open_brief:
		MissionState.open_brief = false
		_show(_brief)
	else:
		_show(_menu)
	MissionState.open_select = false

# ---------------------------------------------------------------- 3D backdrop
func _build_space() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.0, 0.0, 0.008)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.25, 0.3, 0.42)
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.1
	e.glow_enabled = true
	e.glow_intensity = 0.9
	e.glow_bloom = 0.12
	e.glow_hdr_threshold = 0.9
	we.environment = e
	add_child(we)

	Outdoor.stars(self, 1400, 2600.0)

	# Earth: a huge globe whose edge sweeps across the lower part of the view.
	var centre := Vector3(0.24, -0.86, -0.4).normalized() * 790.0
	_earth = preload("res://scripts/world/EarthGlobe.gd").new()
	add_child(_earth)
	_earth.position = centre
	_earth.call_deferred("face", 9.0, 6.0, (-centre).normalized().lerp(Vector3(0, 0, 1), 0.35).normalized(), Vector3(0.2, 0.3, -1))

	# The sun rising over the edge, a little left of centre (just right of the menu).
	var ray := _limb_ray(centre, 637.1 * 1.03, -0.02)
	var sun_pos := ray * 2400.0 + Vector3(0, 28, 0)
	_billboard(sun_pos, 5200.0, Color(1.0, 0.45, 0.15), 0.35)
	_glow = _billboard(sun_pos, 1500.0, Color(1.0, 0.6, 0.25), 2.6)
	_billboard(sun_pos, 5200.0, Color(1.0, 0.5, 0.2), 0.7, 0.05)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.68, 0.4)
	sun.light_energy = 2.4
	add_child(sun)
	var to_scene := -(ray + Vector3(0, 0.15, 0)).normalized()
	to_scene.z = -to_scene.z * 0.6     # come partly from our side so the near surface glows
	sun.look_at_from_position(Vector3.ZERO, to_scene.normalized(), Vector3.UP)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.45, 0.6, 1.0)
	fill.light_energy = 0.25
	add_child(fill)
	fill.look_at_from_position(Vector3.ZERO, Vector3(-0.6, -0.3, -1.0), Vector3.UP)

	# A neighbouring planet, cut off by the top-right corner.
	_moon = ModelLib.fit("moon", 600.0, "center")
	if _moon == null:
		var pm := PartModels.mat(Color(0.05, 0.2, 0.4), 0.0, 0.8)
		_moon = PartModels.ball(300.0, pm)
	_moon.position = Vector3(640, 470, -820)
	add_child(_moon)

	_astro = ModelLib.fit("ex_astronaut", 2.4, "center")
	if _astro:
		_astro.position = ASTRO_POS
		_astro.rotation_degrees = Vector3(25, -30, -35)
		add_child(_astro)
	for spec in [["sc_landsat8", 4.0, Vector3(9.5, 1.2, -21)], ["cubesat", 0.9, Vector3(6.4, -0.6, -12)], ["cubesat", 0.7, Vector3(11.5, 2.0, -24)]]:
		var s := ModelLib.fit(spec[0], spec[1], "center")
		if s:
			s.position = spec[2]
			s.rotation_degrees = Vector3(randf_range(-20, 20), randf_range(0, 360), randf_range(-20, 20))
			add_child(s)
			_sats.append([s, spec[2]])

	_cam = Camera3D.new()
	_cam.fov = 60
	_cam.far = 5000
	_cam.current = true
	add_child(_cam)

## Direction from the camera that just grazes the planet's edge, at horizontal angle az (radians).
func _limb_ray(c: Vector3, r: float, az: float) -> Vector3:
	var lo := -1.2
	var hi := 1.2
	for i in 40:
		var el := (lo + hi) * 0.5
		var d := Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))
		var t := c.dot(d)
		var hit := t > 0.0 and (c - d * t).length() < r
		if hit:
			lo = el
		else:
			hi = el
	var e := hi
	return Vector3(sin(az) * cos(e), sin(e), -cos(az) * cos(e)).normalized()

func _billboard(pos: Vector3, size: float, color: Color, energy: float, squash := 1.0) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(size, size * squash)
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 tint : source_color;
uniform float energy = 1.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz),0,0,0), vec4(0,length(MODEL_MATRIX[1].xyz),0,0), vec4(0,0,length(MODEL_MATRIX[2].xyz),0), vec4(0,0,0,1));
}
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float a = pow(clamp(1.0 - d, 0.0, 1.0), 2.6) + 0.6 * pow(clamp(1.0 - d * 3.0, 0.0, 1.0), 2.0);
	ALBEDO = tint.rgb * energy * a;
	ALPHA = a;
}"""
	m.shader = sh
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("energy", energy)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _process(delta: float) -> void:
	_t += delta
	if _earth and _earth.spin:
		_earth.spin.rotate_object_local(Vector3.UP, delta * 0.004)
	if _astro:
		_astro.position = ASTRO_POS + Vector3(sin(_t * 0.11) * 0.25, sin(_t * 0.23) * 0.18, 0)
		_astro.rotate_object_local(Vector3(0.3, 1, 0.2).normalized(), delta * 0.05)
	for i in _sats.size():
		var s: Node3D = _sats[i][0]
		var base: Vector3 = _sats[i][1]
		s.position = base + Vector3(-fmod(_t * (0.12 + i * 0.05), 6.0) + 3.0, sin(_t * 0.3 + i) * 0.15, 0) * (1.0 if i == 0 else 0.6)
		s.rotate_y(delta * (0.08 + i * 0.05))
	_moon.rotate_y(delta * 0.01)
	_glow.scale = Vector3.ONE * (1.0 + sin(_t * 0.8) * 0.03)
	_cam.position = Vector3(sin(_t * 0.04) * 0.4, sin(_t * 0.06) * 0.2, 0)
	_cam.look_at(_cam.position + Vector3(0.0, 0.0, -1.0), Vector3.UP)

# ---------------------------------------------------------------- building blocks
func _show(page: Control) -> void:
	for p in [_menu, _options, _brief]:
		p.visible = (p == page)
	_logo.visible = page != _brief

func _full() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _vignette() -> Control:
	var r := TextureRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.55))
	g.set_color(1, Color(0, 0, 0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0.5)
	gt.fill_to = Vector2(0.6, 0.5)
	r.texture = gt
	r.stretch_mode = TextureRect.STRETCH_SCALE
	return r

func _text(s: String, size: int, color: Color, kind := "sans_semi", spacing := 0) -> Label:
	var l := FUI.t(s, size, color, kind)
	if spacing != 0:
		var f := FontVariation.new()
		f.base_font = l.get_theme_font("font")
		f.spacing_glyph = spacing
		l.add_theme_font_override("font", f)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l

func _build_logo() -> Control:
	var l := _text("H.Y.A.D.E.S", 80, Color.WHITE, "sans_semi", 12)
	l.position = Vector2(84, 80)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _footer() -> Control:
	var l := _text("Built with NASA resources: mission segments, Mission Design Lab, GMAT, CubeSat 101", 13, Color(1, 1, 1, 0.45), "sans")
	l.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l.position -= Vector2(24, 18)
	return l

func _panel(pos: Vector2, width: float) -> VBoxContainer:
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = PANEL_BG
	st.border_color = Color(COPPER, 0.7)
	st.set_border_width_all(1)
	st.border_width_left = 5
	st.set_content_margin_all(20)
	st.corner_radius_top_right = 14
	p.add_theme_stylebox_override("panel", st)
	p.position = pos
	p.custom_minimum_size = Vector2(width, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	p.add_child(v)
	return v

# ---------------------------------------------------------------- main menu
func _build_menu() -> Control:
	var root := _full()
	var v := VBoxContainer.new()
	v.position = Vector2(84, 250)
	v.add_theme_constant_override("separation", 12)
	root.add_child(v)

	var newb := MenuButtonBar.new("NEW GAME")
	newb.pressed.connect(_new_game)
	v.add_child(newb)

	var save := SaveGame.progress()
	var cont := MenuButtonBar.new("CONTINUE")
	cont.disabled = save.is_empty()
	cont.pressed.connect(_continue)
	v.add_child(cont)
	if not save.is_empty():
		var lv: Dictionary = LevelFlow.LEVELS[clampi(int(save["index"]), 0, LevelFlow.LEVELS.size() - 1)]
		var hint := _text("      Level %d  ·  %s" % [lv["n"], lv["title"].capitalize()], 14, Color(CREAM, 0.7), "sans_med")
		v.add_child(hint)

	var opt := MenuButtonBar.new("OPTIONS")
	opt.pressed.connect(func(): _show(_options))
	v.add_child(opt)

	var ex := MenuButtonBar.new("EXIT")
	ex.pressed.connect(func(): get_tree().quit())
	v.add_child(ex)
	newb.call_deferred("grab_focus")
	return root

func _new_game() -> void:
	MissionState.start_mission("flood_watch")
	MissionState.tutor_enabled = SaveGame.tutor
	MissionState.tutor_steps = {}
	if SaveGame.play_intro:
		get_tree().change_scene_to_file("res://scenes/Intro.tscn")
	else:
		_show(_brief)

func _continue() -> void:
	var i := SaveGame.restore()
	if i >= 0:
		LevelFlow.resume(i)

# ---------------------------------------------------------------- options
func _toggle(v: VBoxContainer, label: String, value: bool, on_change: Callable) -> void:
	var c := CheckButton.new()
	c.text = label
	c.button_pressed = value
	c.add_theme_font_override("font", FUI.font("Inter-Medium"))
	c.add_theme_font_size_override("font_size", 18)
	c.add_theme_color_override("font_color", CREAM)
	c.add_theme_color_override("font_hover_color", Color.WHITE)
	c.add_theme_color_override("font_pressed_color", CREAM)
	c.toggled.connect(on_change)
	v.add_child(c)

func _slider(v: VBoxContainer, label: String, lo: float, hi: float, step: float, value: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := _text(label, 18, CREAM, "sans_med")
	l.custom_minimum_size = Vector2(190, 0)
	row.add_child(l)
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = value
	sl.custom_minimum_size = Vector2(260, 24)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.value_changed.connect(on_change)
	row.add_child(sl)
	v.add_child(row)

func _build_options() -> Control:
	var root := _full()
	var v := _panel(Vector2(84, 205), 640)
	root.add_child(v.get_parent())
	v.add_child(_text("OPTIONS", 28, COPPER, "sans_semi", 4))
	_toggle(v, "Mission Tutor (guides you step by step)", SaveGame.tutor, func(on): SaveGame.tutor = on; SaveGame.save_settings())
	_toggle(v, "Play the story intro on New Game", SaveGame.play_intro, func(on): SaveGame.play_intro = on; SaveGame.save_settings())
	_toggle(v, "Fullscreen", SaveGame.fullscreen, func(on): SaveGame.fullscreen = on; SaveGame.save_settings())
	_slider(v, "Music volume", 0.0, 1.0, 0.05, SaveGame.music_volume, func(x): SaveGame.music_volume = x; AudioManager.set_music_volume(x); SaveGame.save_settings())
	_slider(v, "Mouse look speed", 0.4, 2.0, 0.1, SaveGame.mouse_sens, func(x): SaveGame.mouse_sens = x; SaveGame.save_settings())
	v.add_child(_text("HOW TO PLAY", 18, COPPER, "sans_semi", 3))
	for line in [
		"WASD to walk, mouse to look, E to use a screen or pick up a part. Esc opens the menu.",
		"Level 1: choose the satellite's parts, orbit and rocket, then launch.",
		"Level 2: from orbit, scan the farming regions that are in view and not under cloud.",
		"Level 3: at the ground station, choose what comes down first and run the pass.",
		"Level 4: mark the flooded farm plots and send the right report in time.",
		"Every choice carries forward: a weak design shows up as missing data later."]:
		var l := _text(line, 14, Color(CREAM, 0.85), "sans")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(580, 0)
		v.add_child(l)
	var back := MenuButtonBar.new("BACK", Vector2(220, 42))
	back.pressed.connect(func(): _show(_menu))
	v.add_child(back)
	return root

# ---------------------------------------------------------------- mission briefing
func _build_briefing() -> Control:
	var root := _full()
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = PANEL_BG
	st.border_color = Color(COPPER, 0.7)
	st.set_border_width_all(1)
	st.border_width_left = 5
	st.set_content_margin_all(24)
	st.corner_radius_top_right = 14
	p.add_theme_stylebox_override("panel", st)
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.offset_left = 50
	p.offset_right = -50
	p.offset_top = 30
	p.offset_bottom = -30
	root.add_child(p)
	var v := FUI.vb(10)
	p.add_child(v)
	v.add_child(_text("MISSION BRIEFING  ·  YOU ARE THE MISSION DIRECTOR", 14, COPPER, "mono_semi"))
	v.add_child(_text("Flood & Crop Watch", 40, Color.WHITE, "sans_semi"))
	for line in [
		"Farmers need timely information about crop health, and floods can wipe out a season of crops in days.",
		"Satellites can watch the fields from space, but your mission has limited money, mass and power.",
		"Your job: design and operate a satellite mission that collects useful imagery of farmland, detects flooded areas and gets actionable information to farmers and agricultural scientists."]:
		var l := _text(line, 18, CREAM, "sans")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	var m := GameData.mission("flood_watch")
	v.add_child(_text("Budget $%s M  ·  Mass limit %s kg  ·  Every decision affects the next level" % [str(m["budget"]), str(m["mass_limit"])], 15, FUI.AMBER, "mono_semi"))
	var row := FUI.hb(12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)
	var colors := [Color(1.0, 0.45, 0.3), FUI.SKY, FUI.GREEN, FUI.AMBER]
	for i in LevelFlow.LEVELS.size():
		var lv: Dictionary = LevelFlow.LEVELS[i]
		var c := PanelContainer.new()
		c.add_theme_stylebox_override("panel", FUI.box(Color(0.1, 0.06, 0.04, 0.9), Color(colors[i], 0.5), 10, 14))
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := FUI.vb(6)
		c.add_child(cv)
		cv.add_child(FUI.t("LEVEL %d" % lv["n"], 12, colors[i], "mono_semi"))
		cv.add_child(FUI.t(lv["title"].capitalize(), 20, FUI.WHITE, "sans_semi"))
		cv.add_child(FUI.t(lv["goal"], 15, colors[i], "sans_med"))
		var intro := FUI.t(lv["intro"], 14, FUI.TEXT)
		intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(intro)
		row.add_child(c)
	var lesson := _text("A spacecraft can reach orbit and still fail: without enough power, radio capacity, storage or ground stations, the data never helps anyone.", 15, Color(CREAM, 0.6), "sans")
	lesson.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(lesson)
	var btns := FUI.hb(16)
	var go := MenuButtonBar.new("BEGIN LEVEL 1", Vector2(320, 48))
	go.pressed.connect(LevelFlow.start)
	btns.add_child(go)
	var tut := CheckButton.new()
	tut.text = "Mission Tutor"
	tut.button_pressed = SaveGame.tutor
	tut.add_theme_font_size_override("font_size", 17)
	tut.add_theme_color_override("font_color", CREAM)
	tut.toggled.connect(func(on): MissionState.tutor_enabled = on; MissionState.tutor_steps = {})
	btns.add_child(tut)
	var back := MenuButtonBar.new("BACK", Vector2(180, 48))
	back.pressed.connect(func(): _show(_menu))
	btns.add_child(back)
	v.add_child(btns)
	return root
