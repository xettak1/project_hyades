extends Node3D
## Builds the first-person world for the chosen mission and runs launch + operations.
## Each mission has its own environment (see GameData.MISSIONS[...]["env"]):
##   Flood & Crop Watch - bright CubeSat cleanroom
##   Radar Mapper       - big industrial integration hall with pallets and a crane
##   Lunar Mapper       - dark deep-space hangar with a Moon globe
##
## Layout (top view): front wall = Briefing | Resources | Advisors screens,
## side walls = part shelves + Mission Console, middle = spacecraft on its stand,
## back area = Mission Control with the big orbit screen and the control desk.

const PartItem := preload("res://scripts/world/PartItem.gd")
const Button3D := preload("res://scripts/world/Button3D.gd")
const Screen3D := preload("res://scripts/world/Screen3D.gd")
const Satellite := preload("res://scripts/world/Satellite.gd")
const Player := preload("res://scripts/world/Player.gd")
const HUD := preload("res://scripts/world/HUD.gd")
const OrbitView := preload("res://scripts/world/OrbitView.gd")
const PauseMenu := preload("res://scripts/world/PauseMenu.gd")
const ScreenView := preload("res://scripts/world/ScreenView.gd")
const Simulator := preload("res://scripts/sim/Simulator.gd")
const DAYS_PER_SECOND := 30.0

const CAT_TITLES := {"payload": "PAYLOAD", "solar": "SOLAR POWER", "battery": "BATTERIES",
	"comms": "RADIOS & ANTENNAS", "computer": "COMPUTERS & STORAGE", "adcs": "POINTING (ATTITUDE)",
	"propulsion": "PROPULSION & FUEL"}
const SHORT := {
	"leo_550": "ORBIT\nLEO 51.6", "sso_550": "ORBIT\nSUN-SYNC", "leo_500": "ORBIT\nLEO 500",
	"sso_700": "ORBIT\nDAWN-DUSK", "lunar_direct": "TRANSFER\nDIRECT", "lunar_low_energy": "TRANSFER\nLOW-ENERGY",
	"rideshare_leo": "ROCKET\nRIDE LEO", "rideshare_sso": "ROCKET\nRIDE SSO", "electron": "ROCKET\nSMALL",
	"rideshare_sso_big": "ROCKET\nRIDESHARE", "falcon9": "ROCKET\nMEDIUM", "falcon9_tli": "ROCKET\nMEDIUM",
	"heavy_tli": "ROCKET\nHEAVY"}

var env: Dictionary
var R: Vector3          # room size
var hx: float
var hz: float
var mc_start: float     # z where Mission Control begins
var k: float            # size factor for screens
var ps: float           # part display scale
var stand_z: float
var spawn: Vector3
var ops_spot: Vector3

var player: CharacterBody3D
var hud: CanvasLayer
var console_panel: VBoxContainer
var ops_screen: Node3D
var ops_panel: Control
var orbit_buttons: Dictionary = {}
var rocket_buttons: Dictionary = {}
var speed_buttons: Dictionary = {}

var sim
var speed := 1.0
var _day_accum := 0.0
var _launch_delay := 0.0
var _confirm_time := 0.0

func _ready() -> void:
	if MissionState.picks.is_empty():
		MissionState.start_mission("flood_watch")
	MissionState.phase = "design"
	add_to_group("lab")
	env = MissionState.mission()["env"]
	R = env["room"]
	hx = R.x / 2.0
	hz = R.z / 2.0
	mc_start = hz - 6.5
	k = R.x / 20.0
	ps = env["part_scale"]
	stand_z = (-hz + mc_start) / 2.0 - 0.5
	spawn = Vector3(0, 0.1, stand_z + 4.0 + (ps - 1.0) * 3.0)
	ops_spot = Vector3(0, 0.1, hz - 5.2)

	_build_environment()
	_build_room()
	_build_decor()
	_build_exhibits()
	_build_shelves()
	_build_stand()
	_build_wall_screens()
	_build_console()
	_build_mission_control()

	hud = HUD.new()
	add_child(hud)
	player = Player.new()
	add_child(player)
	player.teleport(spawn, 0.0)
	add_child(PauseMenu.new())
	var sv := ScreenView.new()
	sv.player = player
	add_child(sv)
	MissionState.design_changed.connect(_update_console_lights)
	_update_console_lights()
	if MissionState.tutor_enabled:
		var tutor := preload("res://scripts/world/Tutor.gd").new()
		tutor.lab = self
		add_child(tutor)
	else:
		hud.show_message("%s - %s. Read the briefing on the front wall, then build your spacecraft." % [env["title"].capitalize(), MissionState.mission()["name"]], 6.0)

# ---------------------------------------------------------------- world
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.05, 0.07)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = env["light"] * 0.6
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Real-world panorama used for reflections on metal (the satellite, bezels, floor plates).
	if ResourceLoader.exists(HDRI):
		var pano := PanoramaSkyMaterial.new()
		pano.panorama = load(HDRI)
		var sky := Sky.new()
		sky.sky_material = pano
		e.sky = sky
		e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		e.ambient_light_sky_contribution = 0.55
		e.ambient_light_energy = 0.9
	e.ssao_enabled = true
	e.ssao_intensity = 1.6
	e.glow_enabled = true
	e.glow_intensity = 0.4
	we.environment = e
	add_child(we)
	var x := -hx + 4.0
	while x < hx:
		var z := -hz + 3.0
		while z < hz:
			var l := OmniLight3D.new()
			l.position = Vector3(x, R.y - 0.5, z)
			l.omni_range = 9.0 + R.y * 0.3
			l.light_energy = float(env.get("lamp", 0.9))
			l.light_color = env["light"]
			add_child(l)
			z += 6.0
		x += 6.0

const TEX_FLOOR := "res://assets/textures/metal_plate_diff.jpg"
const TEX_WALL := "res://assets/textures/rusty_metal_diff.jpg"
const HDRI := "res://assets/textures/hdri_indoor.jpg"

## Tiled texture material. scale = repeats per metre (world-space triplanar, so any box works).
## Falls back to a plain colour if the texture file is missing.
func _tex_mat(path: String, scale: float, tint: Color, metal: float, rough: float, fallback: Color) -> StandardMaterial3D:
	if not ResourceLoader.exists(path):
		return PartModels.mat(fallback, 0.0, 0.8)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.albedo_color = tint
	m.metallic = metal
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

func _solid(size: Vector3, pos: Vector3, m: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.add_child(PartModels.box(size, m))
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	add_child(body)
	return body

func _sign(text: String, pos: Vector3, yaw: float, size: int = 64, color: Color = Color(-1, 0, 0)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.005
	l.outline_size = 10
	l.modulate = env["accent"] if color.r < 0.0 else color
	l.position = pos
	l.rotation_degrees.y = yaw
	add_child(l)
	return l

func _build_room() -> void:
	# Worn industrial look: diamond-plate floor, rusty painted metal walls.
	var floor_m := _tex_mat(TEX_FLOOR, 0.45, Color(1, 1, 1), 0.55, 0.6, env["floor"])
	var wall_m := _tex_mat(TEX_WALL, 0.28, Color(1.25, 1.25, 1.25), 0.25, 0.75, env["wall"])
	var ceil_m := _tex_mat(TEX_WALL, 0.2, Color(0.7, 0.7, 0.7), 0.25, 0.8, env["wall"])
	_solid(Vector3(R.x, 0.2, R.z), Vector3(0, -0.1, 0), floor_m)
	_solid(Vector3(R.x, 0.2, R.z), Vector3(0, R.y + 0.1, 0), ceil_m)
	_solid(Vector3(R.x, R.y, 0.2), Vector3(0, R.y / 2, -hz - 0.1), wall_m)
	_solid(Vector3(R.x, R.y, 0.2), Vector3(0, R.y / 2, hz + 0.1), wall_m)
	_solid(Vector3(0.2, R.y, R.z), Vector3(-hx - 0.1, R.y / 2, 0), wall_m)
	_solid(Vector3(0.2, R.y, R.z), Vector3(hx + 0.1, R.y / 2, 0), wall_m)
	var mc_len := hz - mc_start
	add_child(PartModels.box(Vector3(R.x, 0.01, mc_len), _tex_mat(TEX_FLOOR, 0.45, Color(0.75, 0.8, 1.0), 0.6, 0.55, Color(0.15, 0.2, 0.32)), Vector3(0, 0.005, mc_start + mc_len / 2)))
	add_child(PartModels.box(Vector3(R.x, 0.012, 0.1), PartModels.mat(env["accent"]), Vector3(0, 0.006, mc_start)))
	_sign(env["title"], Vector3(0, R.y - 0.4, -hz + 0.05), 0.0, 72)
	_sign("MISSION CONTROL", Vector3(0, R.y - 0.4, hz - 0.05), 180.0, 72)

func _build_decor() -> void:
	match env["sat_style"]:
		"cubesat":
			_sign("INTEGRATION BAY - HANDLE PARTS WITH CARE", Vector3(-hx + 0.05, R.y - 1.2, stand_z), 90.0, 40, Color(0.4, 0.4, 0.45))
		"smallsat":
			# Overhead gantry crane
			var orange := PartModels.mat(Color(1.0, 0.55, 0.1), 0.5, 0.5)
			for sx in [-1, 1]:
				add_child(PartModels.box(Vector3(0.4, 0.5, mc_start + hz), orange, Vector3(sx * (hx - 1.5), R.y - 0.6, (mc_start - hz) / 2)))
			add_child(PartModels.box(Vector3(R.x - 3.0, 0.6, 0.6), orange, Vector3(0, R.y - 0.9, stand_z)))
			add_child(PartModels.box(Vector3(0.6, 0.5, 0.6), PartModels.dark(), Vector3(0, R.y - 1.4, stand_z)))
			add_child(PartModels.cyl(0.02, 0.02, R.y - 5.0, PartModels.alu(), Vector3(0, (R.y - 1.6 + 3.4) / 2, stand_z)))
			_sign("CAUTION: OVERHEAD CRANE", Vector3(hx - 0.05, R.y - 2.0, stand_z), -90.0, 48, Color(1.0, 0.8, 0.1))
		"orbiter":
			# Big Moon globe and a star map on the wall
			var moon := PartModels.ball(1.6, PartModels.mat(Color(0.62, 0.62, 0.6), 0.0, 0.95))
			moon.position = Vector3(-hx + 2.8, 2.6, mc_start - 1.0)
			add_child(moon)
			_solid(Vector3(1.2, 1.0, 1.2), Vector3(-hx + 2.8, 0.5, mc_start - 1.0), PartModels.dark())
			for i in 140:
				var star := PartModels.ball(0.03, PartModels.mat(Color(1, 1, 1), 0.0, 0.5, 3.0))
				star.position = Vector3(hx - 0.08, randf_range(4.5, R.y - 0.5), randf_range(-hz + 1, mc_start))
				add_child(star)
			_sign("NEXT STOP: THE MOON", Vector3(-hx + 2.8, 4.8, mc_start - 1.0), 90.0, 44)

## Real NASA 3D models on pedestals (only if the .glb file is in assets/models).
func _build_exhibits() -> void:
	for ex in env.get("exhibits", []):
		var model_name: String = ex[0]
		var h: float = ex[3]
		var m := ModelLib.fit(model_name, h, "height")
		if m == null:
			continue
		var z: float = (hz - 2.6) if str(ex[2]) == "mc" else (-hz + float(ex[2]))
		var pos := Vector3(float(ex[1]), 0.0, z)
		var foot := clampf(h * 0.35, 0.9, 2.2)
		_solid(Vector3(foot, 0.3, foot), pos + Vector3(0, 0.15, 0), PartModels.mat(Color(0.2, 0.22, 0.26), 0.5, 0.4))
		m.position = pos + Vector3(0, 0.3, 0)
		m.rotation_degrees.y = ex[4]
		add_child(m)
		var plaque := Label3D.new()
		plaque.text = ex[5]
		plaque.font_size = 28
		plaque.pixel_size = 0.004
		plaque.outline_size = 8
		plaque.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		plaque.position = pos + Vector3(0, 0.75, 0)
		add_child(plaque)

# ---------------------------------------------------------------- shelves
func _slot_z(i: int) -> float:
	var z0 := -hz + 2.2
	var z1 := mc_start - 1.6
	return z0 + (z1 - z0) * i / 3.0

func _build_shelves() -> void:
	var cats: Array = MissionState.categories()
	var table_m := PartModels.mat(env["table"], 0.4, 0.5)
	for n in cats.size():
		var cat: String = cats[n]
		var side := -1 if n < 4 else 1
		var z := _slot_z(n if n < 4 else n - 4)
		var x: float = side * (hx - 0.8 * ps)
		var tlen := 2.3 * ps
		_solid(Vector3(1.2 * ps, 0.9, tlen), Vector3(x, 0.45, z), table_m)
		if env["stripes"]:
			for s in 8:
				add_child(PartModels.box(Vector3(1.2 * ps + 0.02, 0.12, tlen / 8 * 0.5), PartModels.mat(Color(1, 0.8, 0.1) if s % 2 == 0 else Color(0.05, 0.05, 0.05)), Vector3(x, 0.72, z - tlen / 2 + tlen / 8 * (s + 0.5))))
		_sign(CAT_TITLES.get(cat, cat.to_upper()), Vector3(side * (hx - 0.05), 2.4 + (R.y - 6.0) * 0.3, z), -90.0 * side, 56)
		var ids: Array = GameData.parts_for(MissionState.mission_id)[cat].keys()
		for i in ids.size():
			var item := PartItem.new()
			var offset: float = (i - (ids.size() - 1) / 2.0) * 0.75 * ps
			item.position = Vector3(x, 0.92, z + offset)
			item.scale = Vector3.ONE * ps
			add_child(item)
			item.setup(cat, ids[i])

func _build_stand() -> void:
	var big := 1.0 if env["sat_style"] == "cubesat" else 1.9
	_solid(Vector3(1.4 * big, 0.4, 1.4 * big), Vector3(0, 0.2, stand_z), PartModels.mat(Color(0.25, 0.27, 0.3), 0.5, 0.4))
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55 * big
	torus.outer_radius = 0.62 * big
	ring.mesh = torus
	ring.material_override = PartModels.mat(env["accent"], 0.0, 0.3, 2.0)
	ring.position = Vector3(0, 0.42, stand_z)
	add_child(ring)
	var sat := Satellite.new()
	sat.position = Vector3(0, env["sat_y"], stand_z)
	add_child(sat)
	var label := "YOUR CUBESAT (3x real size)" if env["sat_style"] == "cubesat" else "YOUR SPACECRAFT"
	_sign(label, Vector3(0, 0.2, stand_z + 0.71 * big), 0.0, 24, Color.WHITE)

func _build_wall_screens() -> void:
	var y := 3.3 + (R.y - 6.0) * 0.5
	var brief := Screen3D.new()
	brief.position = Vector3(-5.6 * k, y, -hz + 0.05)
	add_child(brief)
	brief.setup(Vector2(3.9, 2.6) * k, Vector2i(900, 600), "BRIEFING", env["accent"], "Briefing")
	brief.set_panel(preload("res://scripts/panels/BriefingPanel.gd").new())

	var res := Screen3D.new()
	res.position = Vector3(0, y + 0.4 * k, -hz + 0.05)
	add_child(res)
	res.setup(Vector2(2.7, 2.9) * k, Vector2i(500, 540), "RESOURCES", env["accent"], "Resources")
	res.set_panel(preload("res://scripts/ui/Dashboard.gd").new())

	var adv := Screen3D.new()
	adv.position = Vector3(5.6 * k, y, -hz + 0.05)
	add_child(adv)
	adv.setup(Vector2(3.9, 2.6) * k, Vector2i(900, 600), "ADVISORS", env["accent"], "Advisors")
	adv.set_panel(preload("res://scripts/panels/AdvisorsPanel.gd").new())

# ---------------------------------------------------------------- console
func _console_button(text: String, color: Color, action: Callable, pos: Vector3, big := false) -> Node3D:
	var b := Button3D.new()
	b.position = pos
	b.rotation_degrees.y = -90.0    # labels face the player standing to the west
	add_child(b)
	b.setup(text, color, action, big)
	return b

func _build_console() -> void:
	var z0 := _slot_z(3)
	var dx := hx - 0.7
	_solid(Vector3(1.2, 1.0, 3.6), Vector3(dx, 0.5, z0), PartModels.mat(Color(0.18, 0.2, 0.25), 0.5, 0.4))
	_sign("MISSION CONSOLE", Vector3(hx - 0.05, 3.6, z0), -90.0, 56)
	var scr := Screen3D.new()
	scr.position = Vector3(hx - 0.05, 2.25, z0)
	scr.rotation_degrees.y = -90.0
	add_child(scr)
	scr.setup(Vector2(2.7, 1.89), Vector2i(800, 560), "", UI.COLOR_ACCENT, "Mission Console")
	console_panel = preload("res://scripts/panels/ConsolePanel.gd").new()
	scr.set_panel(console_panel)

	var m := MissionState.mission()
	var z := z0 - 1.5
	for id in m["orbits"]:
		orbit_buttons[id] = _console_button(SHORT.get(id, id), env["accent"], MissionState.set_orbit.bind(id), Vector3(dx - 0.35, 1.0, z))
		z += 0.6
	for id in m["rockets"]:
		rocket_buttons[id] = _console_button(SHORT.get(id, id), Color(0.7, 0.5, 1.0), MissionState.set_rocket.bind(id), Vector3(dx - 0.35, 1.0, z))
		z += 0.6
	_console_button("LIFETIME\n-1 YEAR", UI.COLOR_GOOD, func(): MissionState.set_lifetime(maxi(1, MissionState.lifetime_years - 1)), Vector3(dx + 0.2, 1.0, z0 - 1.5))
	_console_button("LIFETIME\n+1 YEAR", UI.COLOR_GOOD, func(): MissionState.set_lifetime(mini(12, MissionState.lifetime_years + 1)), Vector3(dx + 0.2, 1.0, z0 - 0.9))
	_console_button("LAUNCH", UI.COLOR_BAD, _on_launch_pressed, Vector3(dx + 0.2, 1.0, z0 + 0.6), true)

func _update_console_lights() -> void:
	for id in orbit_buttons:
		orbit_buttons[id].set_lit(id == MissionState.orbit_id)
	for id in rocket_buttons:
		rocket_buttons[id].set_lit(id == MissionState.rocket_id)

# ---------------------------------------------------------------- mission control
func _desk_button(text: String, color: Color, action: Callable, x: float) -> Node3D:
	var b := Button3D.new()
	b.position = Vector3(x, 1.0, hz - 4.1)
	b.rotation_degrees.y = 180.0
	add_child(b)
	b.setup(text, color, action)
	return b

func _build_mission_control() -> void:
	_solid(Vector3(4.6, 1.0, 1.0), Vector3(0, 0.5, hz - 4.0), PartModels.mat(Color(0.18, 0.2, 0.25), 0.5, 0.4))
	var sy := 3.0 + (R.y - 6.0) * 0.15
	ops_screen = Screen3D.new()
	ops_screen.position = Vector3(0, sy, hz - 0.05)
	ops_screen.rotation_degrees.y = 180.0
	add_child(ops_screen)
	ops_screen.setup(Vector2(7.0, 3.94) * minf(k, 1.25), Vector2i(1024, 576), "", UI.COLOR_ACCENT, "Orbit View")
	var idle := VBoxContainer.new()
	idle.add_child(UI.label("NO SPACECRAFT IN FLIGHT", 40, UI.COLOR_MUTED))
	idle.add_child(UI.label("Build your spacecraft in the lab and press LAUNCH on the Mission Console.", 26, UI.COLOR_MUTED))
	ops_screen.set_panel(idle)

	var side := Screen3D.new()
	side.position = Vector3(-6.8 * k, sy, hz - 0.05)
	side.rotation_degrees.y = 180.0
	add_child(side)
	side.setup(Vector2(4.4, 2.475) * k, Vector2i(1600, 900), "ORBIT & TRAJECTORY", env["accent"], "Orbit & Trajectory Monitor")
	ops_panel = preload("res://scripts/panels/OrbitMonitorPanel.gd").new()
	side.set_panel(ops_panel)

	speed_buttons["1"] = _desk_button("SPEED\n1x", UI.COLOR_ACCENT, func(): _set_speed(1.0), 1.6)
	speed_buttons["10"] = _desk_button("SPEED\n10x", UI.COLOR_ACCENT, func(): _set_speed(10.0), 0.8)
	_desk_button("SKIP\nTO END", UI.COLOR_WARN, _skip, 0.0)
	_desk_button("BACK\nTO LAB", UI.COLOR_GOOD, func(): player.teleport(spawn, 0.0), -1.2)
	_set_speed(1.0)

func _set_speed(s: float) -> void:
	speed = s
	speed_buttons["1"].set_lit(s == 1.0)
	speed_buttons["10"].set_lit(s == 10.0)

# ---------------------------------------------------------------- called from screen buttons
func request_launch() -> void:
	_on_launch_pressed()

func request_speed(s: float) -> void:
	_set_speed(s)

func request_skip() -> void:
	_skip()

func back_to_lab() -> void:
	get_tree().call_group("screenview", "close")
	player.teleport(spawn, 0.0)

# ---------------------------------------------------------------- launch + operations
func _on_launch_pressed() -> void:
	if MissionState.phase == "ops":
		hud.show_message("A mission is already flying. Go to Mission Control.")
		return
	var g := MissionState.gate()
	if not g["hard"].is_empty():
		console_panel.set_status("LAUNCH BLOCKED: " + g["hard"][0])
		hud.show_message("Launch blocked. Check the console screen and the Advisors screen.")
		return
	if not g["warn"].is_empty() and _confirm_time <= 0.0:
		_confirm_time = 6.0
		console_panel.set_status("%d warning(s) on the Advisors screen. Press LAUNCH again within 6 s to launch anyway." % g["warn"].size())
		hud.show_message("Warnings! Press LAUNCH again to launch anyway.")
		return
	_launch()

func _launch() -> void:
	_confirm_time = 0.0
	console_panel.set_status("")
	MissionState.phase = "ops"
	sim = Simulator.new()
	sim.setup(MissionState.compute(), MissionState.mission()["requirements"], MissionState.lifetime_years)
	ops_screen.set_world(OrbitView.new())
	ops_panel.reset()
	_day_accum = 0.0
	_launch_delay = 2.0
	get_tree().call_group("screenview", "close")
	player.teleport(ops_spot, 180.0)
	hud.show_message("LIFTOFF! Your spacecraft is on its way.", 4.0)
	get_tree().call_group("tutor", "on_event", "launch")

func _skip() -> void:
	if MissionState.phase != "ops" or sim == null:
		return
	while not sim.done:
		sim.step_day()
	ops_panel.refresh(sim)
	_finish()

func _process(delta: float) -> void:
	if _confirm_time > 0.0:
		_confirm_time -= delta
		if _confirm_time <= 0.0:
			console_panel.set_status("")
	if MissionState.phase != "ops" or sim == null:
		return
	if _launch_delay > 0.0:
		_launch_delay -= delta
		return
	var cruise_boost := 4.0 if sim.in_cruise() else 1.0
	_day_accum += delta * DAYS_PER_SECOND * speed * cruise_boost
	while _day_accum >= 1.0 and not sim.done:
		sim.step_day()
		_day_accum -= 1.0
	ops_panel.refresh(sim)
	if sim.done:
		_finish()

func _finish() -> void:
	if MissionState.phase != "ops":
		return
	var r: Dictionary = sim.result()
	MissionState.last_result = r
	MissionState.runs += 1
	MissionState.best_scores[MissionState.mission_id] = maxi(MissionState.best_score, int(r["score"]))
	MissionState.phase = "design"
	ops_screen.overlay(preload("res://scripts/panels/ResultsPanel.gd").new())
	get_tree().call_group("tutor", "on_event", "finished")
	hud.show_message("Mission over: %s, %d / 1000. Read the report on the big screen." % [r["rating"], r["score"]], 6.0)
