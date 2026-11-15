extends Node3D
## Story intro played on New Game (about 40 s, Space / Esc / Enter / click to skip).
##   1. Earth from space, West Africa at dawn: the farmers and the rains.
##   2. Farmland on a golden morning: fields, a village, the river.
##   3. The same fields under a storm: rain, the river rising, crops going under.
##   4. Back in orbit: a small satellite glides past, watching every field.
##   5. Black screen: the challenge, "You are the mission director", the title.
## Then the title screen opens straight on the mission briefing.

const SHOTS := [
	{"id": "earth", "len": 8.0, "say": ["West Africa. Every season, millions of farmers plant their fields and wait for the rains."]},
	{"id": "farm", "len": 7.5, "say": ["The rains bring the crops to life: maize, rice, sorghum, food for whole communities."]},
	{"id": "flood", "len": 8.5, "say": ["But when too much rain falls too fast, rivers burst their banks.", "A season of crops can vanish in days, often before anyone knows."]},
	{"id": "orbit", "len": 8.0, "say": ["From 700 km above, a small satellite could watch every field,", "spot the floods, and warn farmers in time."]},
	{"id": "director", "len": 9.0, "say": []},
]
const COPPER := Color(0.92, 0.52, 0.2)
const CREAM := Color(1.0, 0.94, 0.86)

var _t := 0.0
var _shot := -1
var _shot_t := 0.0
var _ending := false

var _we: WorldEnvironment
var _space_env: Environment
var _farm_env: Environment
var _farm_sky: ProceduralSkyMaterial
var _cam: Camera3D

var _space: Node3D
var _earth: Node3D
var _earth_model: Node3D
var _space_sun: DirectionalLight3D
var _sat: Node3D
var _beam: MeshInstance3D

var _farm: Node3D
var _farm_sun: DirectionalLight3D
var _water: MeshInstance3D
var _rain: CPUParticles3D

var _caption: Label
var _fade: ColorRect
var _black: ColorRect
var _center: VBoxContainer
var _lines: Array = []
var _skip_btn: Control

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	_we = WorldEnvironment.new()
	add_child(_we)
	_build_space()
	_build_farm()
	_cam = Camera3D.new()
	_cam.fov = 55
	_cam.far = 6000
	_cam.current = true
	add_child(_cam)
	_build_ui()

# ======================================================================= space
func _build_space() -> void:
	_space = Node3D.new()
	add_child(_space)
	_space_env = Environment.new()
	_space_env.background_mode = Environment.BG_COLOR
	_space_env.background_color = Color(0, 0, 0.006)
	_space_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_space_env.ambient_light_color = Color(0.3, 0.34, 0.45)
	_space_env.ambient_light_energy = 0.35
	_space_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_space_env.glow_enabled = true
	_space_env.glow_intensity = 0.7
	_space_env.glow_bloom = 0.06
	_space_sun = DirectionalLight3D.new()
	_space_sun.light_energy = 2.3
	_space_sun.light_color = Color(1, 0.93, 0.85)
	_space.add_child(_space_sun)
	_space_sun.look_at_from_position(Vector3.ZERO, Vector3(0.75, -0.15, -0.65), Vector3.UP)
	Outdoor.stars(_space, 1400, 3000.0)
	# Earth: the 3D Earth model (its daylight is painted into the texture, centred on Africa),
	# turned so Africa faces the camera, with a soft blue atmosphere around the edge.
	_earth = Node3D.new()
	_space.add_child(_earth)
	var africa := Vector3(1.0, 0.45, -0.7).normalized()      # where Africa lies on the model
	_earth.basis = Basis(Quaternion(africa, Vector3(0, 0, 1)))
	_earth_model = ModelLib.fit("earth_intro", 637.1 * 2.0, "center")
	if _earth_model == null:
		_earth_model = PartModels.ball(637.1, PartModels.mat(Color(0.2, 0.4, 0.8)))
	for mi in _earth_model.find_children("*", "MeshInstance3D", true, false):
		var src: Material = mi.mesh.surface_get_material(0)
		if src is StandardMaterial3D:
			var m: StandardMaterial3D = src.duplicate()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1.25, 1.25, 1.25)
			mi.material_override = m
	_earth.add_child(_earth_model)
	var atmo := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 637.1 * 1.035
	sm.height = 637.1 * 2.07
	sm.radial_segments = 64
	sm.rings = 32
	atmo.mesh = sm
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
void fragment() {
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float a = pow(rim, 3.0);
	ALBEDO = vec3(0.35, 0.65, 1.0) * a * 1.6;
	ALPHA = a;
}"""
	var amat := ShaderMaterial.new()
	amat.shader = sh
	atmo.material_override = amat
	_earth.add_child(atmo)

	_sat = ModelLib.fit("cubesat", 1.4, "center")
	if _sat == null:
		_sat = PartModels.box(Vector3(0.6, 0.6, 1.2), PartModels.alu())
	_sat.visible = false
	_space.add_child(_sat)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 5.0
	cm.height = 1.0
	cm.radial_segments = 16
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.albedo_color = Color(0.25, 1.0, 0.55, 0.22)
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam = MeshInstance3D.new()
	_beam.mesh = cm
	_beam.material_override = bm
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visible = false
	_space.add_child(_beam)

# ======================================================================= farmland
func _build_farm() -> void:
	_farm = Node3D.new()
	add_child(_farm)
	_farm_sky = ProceduralSkyMaterial.new()
	_farm_sky.sky_top_color = Color(0.28, 0.5, 0.82)
	_farm_sky.sky_horizon_color = Color(0.85, 0.66, 0.45)
	_farm_sky.ground_horizon_color = Color(0.6, 0.5, 0.38)
	_farm_sky.ground_bottom_color = Color(0.3, 0.25, 0.2)
	_farm_sky.sun_angle_max = 25.0
	var sk := Sky.new()
	sk.sky_material = _farm_sky
	_farm_env = Environment.new()
	_farm_env.background_mode = Environment.BG_SKY
	_farm_env.sky = sk
	_farm_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_farm_env.ambient_light_energy = 0.5
	_farm_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_farm_env.tonemap_exposure = 0.85
	_farm_env.glow_enabled = true
	_farm_env.glow_intensity = 0.3
	_farm_env.fog_enabled = true
	_farm_env.fog_light_color = Color(0.92, 0.8, 0.62)
	_farm_env.fog_density = 0.0018
	_farm_env.fog_aerial_perspective = 0.4
	_farm_sun = DirectionalLight3D.new()
	_farm_sun.rotation_degrees = Vector3(-18, -125, 0)
	_farm_sun.light_energy = 1.6
	_farm_sun.light_color = Color(1, 0.84, 0.62)
	_farm_sun.shadow_enabled = true
	_farm_sun.directional_shadow_max_distance = 160.0
	_farm.add_child(_farm_sun)

	Outdoor.ground(_farm, 2400.0, Color(0.36, 0.33, 0.2))
	# A grid of fields, each with crop rows (one MultiMesh for all rows).
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var rows: Array = []
	for fx in range(-4, 5):
		for fz in range(-5, 3):
			var c := Vector3(fx * 21.0, 0, fz * 25.0)
			if absf(c.x - _river_x(c.z)) < 16.0:
				continue
			Outdoor.slab(_farm, Vector3(19, 0.1, 23), c + Vector3(0, 0.05, 0), Color(0.4, 0.31, 0.2).lerp(Color(0.33, 0.27, 0.18), rng.randf()))
			var crop: Color = [Color(0.22, 0.55, 0.16), Color(0.3, 0.6, 0.2), Color(0.45, 0.6, 0.2), Color(0.2, 0.48, 0.15)][rng.randi() % 4]
			var along_x := rng.randf() < 0.5
			for r in 9:
				var off := -9.6 + r * 2.4
				var pos := c + (Vector3(0, 0.45, off) if along_x else Vector3(off, 0.45, 0))
				rows.append([pos, along_x, crop.lerp(crop.darkened(0.25), r % 2)])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bx := BoxMesh.new()
	bx.size = Vector3(17, 0.7, 1.0)
	mm.mesh = bx
	mm.instance_count = rows.size()
	for i in rows.size():
		var b := Basis() if rows[i][1] else Basis(Vector3.UP, PI / 2)
		mm.set_instance_transform(i, Transform3D(b, rows[i][0]))
		mm.set_instance_color(i, rows[i][2])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var cmat := StandardMaterial3D.new()
	cmat.vertex_color_use_as_albedo = true
	cmat.roughness = 0.95
	mmi.material_override = cmat
	_farm.add_child(mmi)

	# Real plants close to the camera paths: weed plants in the nearest fields, shrubs by the village.
	var weeds: Array = []
	var prng := RandomNumberGenerator.new()
	prng.seed = 23
	while weeds.size() < 260:
		var pp := Vector3(prng.randf_range(-130.0, 70.0), 0.1, prng.randf_range(-40.0, 120.0))
		if absf(pp.x - _river_x(pp.z)) < 7.0:
			continue
		# keep to the field edges and paths in front of the camera paths
		if Vector2(pp.x + 75.0, pp.z - 70.0).length() > 70.0 and Vector2(pp.x - 35.0, pp.z - 40.0).length() > 45.0:
			continue
		weeds.append([pp, prng.randf() * TAU, prng.randf_range(0.7, 1.3)])
	Outdoor.scatter(_farm, "weed_plant", weeds, 0.9)
	var shrubs: Array = []
	for sp in [Vector3(-98, 0, -20), Vector3(-114, 0, -4), Vector3(-132, 0, -52), Vector3(-92, 0, -40)]:
		shrubs.append([sp, prng.randf() * TAU, prng.randf_range(0.85, 1.2)])
	Outdoor.scatter(_farm, "searsia_shrub", shrubs, 3.2)

	# The river, winding through the farms.
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.3, 0.42, 0.45)
	wm.metallic = 0.3
	wm.roughness = 0.12
	for k in 24:
		var z := -170.0 + k * 12.0
		var a := _river_x(z)
		var b := _river_x(z + 12.0)
		var seg := PartModels.box(Vector3(9, 0.12, 12.6), wm, Vector3((a + b) * 0.5, 0.08, z + 6.0))
		seg.rotation.y = atan2(b - a, 12.0)
		_farm.add_child(seg)

	# A small village: round huts with conical roofs.
	var wall := Outdoor.flat(Color(0.62, 0.45, 0.3))
	var roof := Outdoor.flat(Color(0.55, 0.45, 0.25))
	for h in [Vector3(-118, 0, -30), Vector3(-126, 0, -18), Vector3(-110, 0, -12), Vector3(-130, 0, -40), Vector3(-104, 0, -44), Vector3(-138, 0, -26)]:
		_farm.add_child(PartModels.cyl(2.4, 2.4, 2.6, wall, h + Vector3(0, 1.3, 0)))
		_farm.add_child(PartModels.cyl(0.05, 3.2, 2.4, roof, h + Vector3(0, 3.8, 0)))
	Outdoor.trees(_farm, 140, 230.0, Vector3.ZERO, Rect2(-95, -140, 190, 210), 4, 1.1)
	Outdoor.hills(_farm, 12, 520.0, Color(0.38, 0.4, 0.26), 9)

	# Flood water (rises during the storm shot).
	var fw := StandardMaterial3D.new()
	fw.albedo_color = Color(0.33, 0.29, 0.2, 0.97)
	fw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fw.metallic = 0.0
	fw.roughness = 0.55
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	_water = MeshInstance3D.new()
	_water.mesh = pm
	_water.material_override = fw
	_water.position = Vector3(0, -0.4, 0)
	_water.visible = false
	_farm.add_child(_water)

	_rain = CPUParticles3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(0.03, 0.9, 0.03)
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(0.8, 0.85, 0.95, 0.45)
	dm.material = rm
	_rain.mesh = dm
	_rain.amount = 2600
	_rain.lifetime = 0.7
	_rain.preprocess = 1.0
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(45, 1, 45)
	_rain.direction = Vector3(0.1, -1, 0)
	_rain.spread = 2.0
	_rain.initial_velocity_min = 38.0
	_rain.initial_velocity_max = 46.0
	_rain.gravity = Vector3(0, -20, 0)
	_rain.local_coords = false
	_rain.emitting = false
	_farm.add_child(_rain)

func _river_x(z: float) -> float:
	return 22.0 + sin(z * 0.018) * 30.0

# ======================================================================= captions
func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.custom_minimum_size = Vector2(0, 86)
		if not top:
			bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(bar)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.modulate.a = 0.0
	ui.add_child(_black)
	_caption = FUI.t("", 24, CREAM, "sans_med")
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_top = -86
	_caption.offset_left = 120
	_caption.offset_right = -120
	_caption.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_caption.add_theme_constant_override("shadow_offset_y", 2)
	ui.add_child(_caption)

	_center = VBoxContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.alignment = BoxContainer.ALIGNMENT_CENTER
	_center.add_theme_constant_override("separation", 18)
	ui.add_child(_center)
	for spec in [["Money is limited. Power is limited. Time is short.", 26, CREAM, "sans_med", 0],
			["Every choice you make will decide whether the data reaches the farmers.", 20, Color(CREAM, 0.75), "sans", 0],
			["YOU ARE THE MISSION DIRECTOR.", 30, Color.WHITE, "sans_semi", 6],
			["FLOOD & CROP WATCH", 54, COPPER, "sans_semi", 12],
			["H . Y . A . D . E . S", 15, Color(CREAM, 0.7), "sans_med", 6]]:
		var l := FUI.t(spec[0], spec[1], spec[2], spec[3])
		if spec[4] > 0:
			var f := FontVariation.new()
			f.base_font = l.get_theme_font("font")
			f.spacing_glyph = spec[4]
			l.add_theme_font_override("font", f)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.modulate.a = 0.0
		_center.add_child(l)
		_lines.append(l)

	# Skip button (also Space / Esc / Enter)
	var skip := MenuButtonBar.new("SKIP  ▸▸", Vector2(170, 40))
	skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip.offset_left = -196
	skip.offset_right = -26
	skip.offset_top = 22
	skip.offset_bottom = 62
	skip.pressed.connect(_finish)
	_skip_btn = skip

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_fade)
	ui.add_child(_skip_btn)

# ======================================================================= timeline
func _process(delta: float) -> void:
	if _ending:
		return
	_t += delta
	var acc := 0.0
	var idx := SHOTS.size()
	for i in SHOTS.size():
		if _t < acc + SHOTS[i]["len"]:
			idx = i
			break
		acc += SHOTS[i]["len"]
	if idx >= SHOTS.size():
		_finish()
		return
	if idx != _shot:
		_shot = idx
		_enter(SHOTS[idx]["id"])
	_shot_t = _t - acc
	var L: float = SHOTS[idx]["len"]
	var k := _shot_t / L
	# fade in / out at shot edges
	_fade.modulate.a = clampf(maxf(1.0 - _shot_t / 0.8, (_shot_t - (L - 0.7)) / 0.7), 0.0, 1.0)
	_update_caption(SHOTS[idx]["say"], _shot_t, L)
	match SHOTS[idx]["id"]:
		"earth":
			_cam.position = Vector3(0, 40, 2150).lerp(Vector3(0, 30, 1700), _ease(k))
			_cam.look_at(Vector3(120, 30, 0), Vector3.UP)
			_earth_model.rotate_object_local(Vector3.UP, delta * 0.004)
		"farm":
			_cam.position = Vector3(-150, 16, 120).lerp(Vector3(-75, 9, 70), _ease(k))
			_cam.look_at(Vector3(20, 0, -30), Vector3.UP)
		"flood":
			var storm := clampf(_shot_t / 2.0, 0.0, 1.0)
			_set_weather(storm)
			_water.position.y = lerpf(-0.4, 0.66, clampf((_shot_t - 1.5) / 5.5, 0.0, 1.0))
			_cam.position = Vector3(55, 13, 70).lerp(Vector3(35, 7, 40), _ease(k))
			_cam.look_at(Vector3(-10, 0, -25), Vector3.UP)
			_rain.global_position = _cam.global_position + Vector3(0, 22, -18)
		"orbit":
			var base := Vector3(0, 0, 700)
			var fwd := Vector3(-1, 0.3, -0.42).normalized()
			_cam.position = base
			_cam.look_at(base + fwd, Vector3(0, 0, 1))
			var b := _cam.global_transform.basis
			var p := base + b * Vector3(lerpf(-2.6, 2.2, k), -0.35 + sin(_shot_t * 0.6) * 0.05, -5.2)
			_sat.position = p
			_sat.rotate_object_local(Vector3(0.2, 1, 0).normalized(), delta * 0.25)
			var down := -p.normalized()
			var length := p.length() - 637.1
			_beam.visible = k > 0.25
			_beam.position = p + down * length * 0.5
			_beam.basis = Basis(Quaternion(Vector3.UP, -down)).scaled(Vector3(1, length, 1))
			_earth_model.rotate_object_local(Vector3.UP, delta * 0.002)
		"director":
			_black.modulate.a = clampf(_shot_t / 0.6, 0.0, 1.0)
			_fade.modulate.a = clampf((_shot_t - (L - 0.9)) / 0.9, 0.0, 1.0)
			var starts := [0.4, 1.9, 3.8, 5.4, 6.0]
			for i in _lines.size():
				_lines[i].modulate.a = clampf((_shot_t - starts[i]) / 0.8, 0.0, 1.0)

func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)

func _update_caption(lines: Array, st: float, L: float) -> void:
	if lines.is_empty():
		_caption.text = ""
		return
	var per := (L - 1.0) / lines.size()
	var i := clampi(int((st - 0.6) / per), 0, lines.size() - 1)
	_caption.text = lines[i]
	var local := st - 0.6 - i * per
	_caption.modulate.a = clampf(minf(local / 0.5, (per - local) / 0.4), 0.0, 1.0) if st > 0.6 else 0.0

func _enter(id: String) -> void:
	var in_space := id in ["earth", "orbit", "director"]
	_space.visible = in_space
	_farm.visible = not in_space
	_we.environment = _space_env if in_space else _farm_env
	_sat.visible = id == "orbit"
	_beam.visible = false
	_rain.emitting = id == "flood"
	_water.visible = id == "flood"
	if id == "farm":
		_set_weather(0.0)
	if id == "orbit":
		_space_sun.look_at_from_position(Vector3.ZERO, Vector3(0.35, -0.55, -0.75), Vector3.UP)

## 0 = golden morning, 1 = dark storm.
func _set_weather(s: float) -> void:
	_farm_sky.sky_top_color = Color(0.28, 0.5, 0.82).lerp(Color(0.2, 0.22, 0.26), s)
	_farm_sky.sky_horizon_color = Color(0.85, 0.66, 0.45).lerp(Color(0.42, 0.44, 0.46), s)
	_farm_env.fog_light_color = Color(0.92, 0.8, 0.62).lerp(Color(0.4, 0.42, 0.45), s)
	_farm_env.fog_density = lerpf(0.0018, 0.012, s)
	_farm_sun.light_energy = lerpf(1.6, 0.25, s)
	_farm_env.ambient_light_energy = lerpf(0.5, 0.45, s)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_finish()

func _finish() -> void:
	if _ending:
		return
	_ending = true
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.5)
	await tw.finished
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	LevelFlow.start()
