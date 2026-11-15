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
	"propulsion": "PROPULSION & FUEL", "thermal": "THERMAL CONTROL"}
const CAT_SHORT := {"payload": "PAYLOAD", "solar": "SOLAR", "battery": "BATTERY", "comms": "RADIOS",
	"computer": "COMPUTERS", "adcs": "POINTING", "propulsion": "PROPULSION", "thermal": "THERMAL"}
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
var outdoor: Dictionary = {}   # sky, sun, environment (used by the launch sequence)
var complex: Node3D            # the launch pad outside the window
var speed := 1.0
var _day_accum := 0.0
var _launch_delay := 0.0
var _confirm_time := 0.0

func _ready() -> void:
	if MissionState.picks.is_empty():
		MissionState.start_mission("flood_watch")
	MissionState.phase = "design"
	MissionState.live = {}
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
	if LevelFlow.index >= 0:
		_build_viewing_gallery()
	else:
		_build_mission_control()   # old single-room flow (kept for the tests)

	hud = HUD.new()
	add_child(hud)
	player = Player.new()
	add_child(player)
	player.teleport(spawn, 0.0)
	add_child(PauseMenu.new())
	add_child(preload("res://scripts/world/DecisionCard.gd").new())
	add_child(preload("res://scripts/ui/InstrumentationPanel.gd").new())
	add_child(preload("res://scripts/ui/MissionProgressBar.gd").new())
	var instr := preload("res://scripts/ui/MissionInstructions.gd").new()
	instr.room = self
	add_child(instr)
	var sv := ScreenView.new()
	sv.player = player
	add_child(sv)
	MissionState.design_changed.connect(_update_console_lights)
	_update_console_lights()
	# Mission Tutor (bottom of the screen). With the tutor switched off it still reacts to decisions.
	var tutor := preload("res://scripts/ui/TutorDialogueManager.gd").new()
	tutor.room = self
	add_child(tutor)

# ---------------------------------------------------------------- world
func _build_environment() -> void:
	# Launch control building on the coast: real daylight sky, sun behind the building lighting the pad.
	outdoor = Outdoor.sky(self, Color(0.28, 0.52, 0.88), Color(0.74, 0.84, 0.94), Color(0.32, 0.34, 0.3), Vector3(-38, 205, 0), 1.25)
	Outdoor.lamps(self, R, env["light"], float(env.get("lamp", 0.9)) * 0.8, 6.0)
	complex = preload("res://scripts/world/LaunchComplex.gd").new()
	complex.position = Vector3(0, 0, hz)
	add_child(complex)

const TEX_FLOOR := RoomKit.TEX_FLOOR
const TEX_WALL := RoomKit.TEX_WALL

## Tiled texture material. scale = repeats per metre (world-space triplanar, so any box works).
## Falls back to a plain colour if the texture file is missing.
func _tex_mat(path: String, scale: float, tint: Color, metal: float, rough: float, fallback: Color) -> StandardMaterial3D:
	return RoomKit.tex_mat(path, scale, tint, metal, rough, fallback)

func _solid(size: Vector3, pos: Vector3, m: Material) -> StaticBody3D:
	return RoomKit.solid(self, size, pos, m)

## A painted wall sign. max_w (metres) shrinks the text so it never runs past its own space
## (e.g. a shelf sign never reaches the next shelf or a screen).
func _sign(text: String, pos: Vector3, yaw: float, size: int = 64, color: Color = Color(-1, 0, 0), max_w: float = 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.005
	if max_w > 0.0:
		var w := l.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * l.pixel_size if l.font else ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * l.pixel_size
		if w > max_w:
			l.pixel_size *= max_w / w
	l.outline_size = 10
	l.modulate = env["accent"] if color.r < 0.0 else color
	l.position = pos
	l.rotation_degrees.y = yaw
	add_child(l)
	return l

func _build_room() -> void:
	# Worn industrial look: diamond-plate floor, blue painted metal-plate walls and roof.
	var floor_m := _tex_mat(TEX_FLOOR, 0.45, Color(1, 1, 1), 0.55, 0.6, env["floor"])
	var wall_m := _tex_mat(TEX_WALL, 0.28, Color(1.45, 1.45, 1.45), 0.45, 0.5, env["wall"])
	var ceil_m := _tex_mat(TEX_WALL, 0.22, Color(1.05, 1.05, 1.05), 0.45, 0.55, env["wall"])
	_solid(Vector3(R.x, 0.2, R.z), Vector3(0, -0.1, 0), floor_m)
	_solid(Vector3(R.x, 0.2, R.z), Vector3(0, R.y + 0.1, 0), ceil_m)
	_solid(Vector3(R.x, R.y, 0.2), Vector3(0, R.y / 2, -hz - 0.1), wall_m)
	# Back wall = big window over the launch pad
	Outdoor.window_wall(self, Vector3(0, 0, hz + 0.1), R.x, R.y, 0.9, R.y - 0.75, 1.0, wall_m)
	_solid(Vector3(0.2, R.y, R.z), Vector3(-hx - 0.1, R.y / 2, 0), wall_m)
	_solid(Vector3(0.2, R.y, R.z), Vector3(hx + 0.1, R.y / 2, 0), wall_m)
	var mc_len := hz - mc_start
	add_child(PartModels.box(Vector3(R.x, 0.01, mc_len), _tex_mat(TEX_FLOOR, 0.45, Color(0.75, 0.8, 1.0), 0.6, 0.55, Color(0.15, 0.2, 0.32)), Vector3(0, 0.005, mc_start + mc_len / 2)))
	add_child(PartModels.box(Vector3(R.x, 0.012, 0.1), PartModels.mat(env["accent"]), Vector3(0, 0.006, mc_start)))
	_sign(env["title"], Vector3(0, R.y - 0.4, -hz + 0.05), 0.0, 72)
	_sign("LAUNCH PAD VIEW" if LevelFlow.index >= 0 else "MISSION CONTROL", Vector3(0, R.y - 0.38, hz - 0.05), 180.0, 64)

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
		# museum plaque on the front face of the plinth, so the model can never hide it
		var front := pos + Vector3(0, 0.15, foot / 2.0 + 0.012)
		add_child(PartModels.box(Vector3(foot * 0.92, 0.2, 0.01), PartModels.mat(Color(0.06, 0.07, 0.09), 0.6, 0.35), front))
		var plaque := Label3D.new()
		plaque.text = ex[5]
		plaque.font = FUI.font("Inter-SemiBold")
		plaque.font_size = 40
		plaque.outline_size = 0
		plaque.modulate = Color(0.92, 0.94, 0.97)
		plaque.pixel_size = 0.0022
		var tw: float = plaque.font.get_string_size(ex[5], HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x * plaque.pixel_size
		if tw > foot * 0.86:
			plaque.pixel_size *= foot * 0.86 / tw
		plaque.position = front + Vector3(0, 0, 0.008)
		add_child(plaque)

# ---------------------------------------------------------------- shelves
func _slot_z(i: int) -> float:
	var z0 := -hz + 2.2
	var z1 := mc_start - 1.6
	return z0 + (z1 - z0) * i / 3.0

func _build_shelves() -> void:
	var cats: Array = MissionState.categories()
	var table_m := PartModels.mat(env["table"], 0.4, 0.5)
	# Left wall takes 4 tables (5 when there are 8 categories); the right wall keeps its last slot for the console.
	var left_n := 5 if cats.size() > 7 else 4
	for n in cats.size():
		var cat: String = cats[n]
		var side := -1 if n < left_n else 1
		var z := _slot_z(n if n < left_n else n - left_n)
		if side < 0 and left_n == 5:
			z = -hz + 2.0 + (mc_start - 1.6 - (-hz + 2.0)) * n / 4.0
		var x: float = side * (hx - 0.8 * ps)
		var tlen := (1.75 if side < 0 and left_n == 5 else 2.3) * ps
		_solid(Vector3(1.2 * ps, 0.9, tlen), Vector3(x, 0.45, z), table_m)
		if env["stripes"]:
			for s in 8:
				add_child(PartModels.box(Vector3(1.2 * ps + 0.02, 0.12, tlen / 8 * 0.5), PartModels.mat(Color(1, 0.8, 0.1) if s % 2 == 0 else Color(0.05, 0.05, 0.05)), Vector3(x, 0.72, z - tlen / 2 + tlen / 8 * (s + 0.5))))
		var tight := side < 0 and left_n == 5
		var title: String = CAT_SHORT.get(cat, cat.to_upper()) if tight else CAT_TITLES.get(cat, cat.to_upper())
		_sign(title, Vector3(side * (hx - 0.05), 2.4 + (R.y - 6.0) * 0.3, z), -90.0 * side, 46 if tight else 56, Color(-1, 0, 0), tlen * 0.95)
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

	_build_launch_console(y)

	var adv := Screen3D.new()
	adv.position = Vector3(5.6 * k, y, -hz + 0.05)
	add_child(adv)
	adv.setup(Vector2(3.9, 2.6) * k, Vector2i(900, 600), "ADVISORS", env["accent"], "Advisors")
	adv.set_panel(preload("res://scripts/panels/AdvisorsPanel.gd").new())

## LAUNCH CONTROL CONSOLE: four separate displays (budget, payload, rocket status, mission overview)
## in a 2x2 bank on the front wall, with a control desk underneath.
func _build_launch_console(y: float) -> void:
	var sz := Vector2(1.75, 1.1) * k
	var px := Vector2i(900, 566)
	var dx := 0.98 * k
	var rows := [y + 0.95 * k, y - 0.55 * k]
	var specs := [
		[LaunchInstruments.Budget, "MISSION BUDGET", "Mission Budget", -dx, rows[0]],
		[LaunchInstruments.Payload, "PAYLOAD MONITOR", "Payload Monitor", dx, rows[0]],
		[LaunchInstruments.Rocket, "ROCKET STATUS", "Rocket Status", -dx, rows[1]],
		[LaunchInstruments.Overview, "MISSION OVERVIEW", "Mission Overview", dx, rows[1]]]
	for sp in specs:
		var scr := Screen3D.new()
		scr.position = Vector3(sp[3], sp[4], -hz + 0.12)
		add_child(scr)
		scr.setup(sz, px, sp[1], env["accent"], sp[2])
		scr.set_display(sp[0].new())
	# The console desk: sloped control panel with guarded switches and indicator buttons
	var desk_m := PartModels.mat(Color(0.14, 0.15, 0.17), 0.7, 0.35)
	var top_m := PartModels.mat(Color(0.06, 0.065, 0.075), 0.3, 0.6)
	var dz := -hz + 0.75
	_solid(Vector3(4.4 * k, 0.95, 1.0), Vector3(0, 0.475, dz), desk_m)
	var slope := PartModels.box(Vector3(4.3 * k, 0.04, 0.62), top_m, Vector3(0, 1.02, dz + 0.05))
	slope.rotation_degrees.x = 18.0
	add_child(slope)
	var cols := [Color(0.2, 1.0, 0.45), Color(1.0, 0.75, 0.2), Color(0.3, 0.75, 1.0), Color(1.0, 0.3, 0.3)]
	for i in 14:
		var bx := -1.9 * k + i * 0.29 * k
		var c: Color = cols[i % cols.size()]
		var bm := PartModels.mat(c, 0.0, 0.4, 1.6 if i % 3 != 1 else 0.2)
		var btn := PartModels.box(Vector3(0.09, 0.03, 0.07), bm, Vector3(bx, 1.06, dz - 0.05))
		btn.rotation_degrees.x = 18.0
		add_child(btn)
		# guarded toggle switches on the lower row
		if i % 2 == 0:
			var sw := PartModels.cyl(0.012, 0.012, 0.08, PartModels.mat(Color(0.85, 0.86, 0.88), 0.9, 0.25), Vector3(bx + 0.12, 1.02, dz + 0.17), Vector3(-25, 0, 0))
			add_child(sw)
			var guard := PartModels.box(Vector3(0.07, 0.035, 0.09), PartModels.mat(Color(0.9, 0.15, 0.1), 0.2, 0.4), Vector3(bx + 0.12, 1.0, dz + 0.2))
			guard.rotation_degrees.x = 18.0
			add_child(guard)
	var plate := Label3D.new()
	plate.text = "LAUNCH CONTROL CONSOLE"
	plate.font = FUI.font("Inter-SemiBold")
	plate.font_size = 48
	plate.pixel_size = 0.0024
	plate.outline_size = 0
	plate.modulate = Color(0.95, 0.62, 0.22)
	plate.position = Vector3(0, 0.62, dz + 0.505)
	add_child(plate)

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
	var scr := Screen3D.new()
	scr.position = Vector3(hx - 0.05, 2.25, z0)
	scr.rotation_degrees.y = -90.0
	add_child(scr)
	scr.setup(Vector2(2.7, 1.89), Vector2i(800, 560), "MISSION CONSOLE", UI.COLOR_ACCENT, "Mission Console")
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

# ---------------------------------------------------------------- viewing gallery (four-level flow)
## The back of launch control: the window over the pad, a railing and a few seats.
func _build_viewing_gallery() -> void:
	var rail := PartModels.mat(Color(0.75, 0.76, 0.8), 0.8, 0.3)
	add_child(PartModels.box(Vector3(R.x - 2.4, 0.06, 0.06), rail, Vector3(0, 1.05, hz - 0.9)))
	for i in 9:
		add_child(PartModels.box(Vector3(0.05, 1.05, 0.05), rail, Vector3(-hx + 1.2 + i * (R.x - 2.4) / 8.0, 0.52, hz - 0.9)))
	var seat := PartModels.mat(Color(0.15, 0.2, 0.35), 0.1, 0.7)
	for x in [-6.0, -4.5, -3.0, 3.0, 4.5, 6.0]:
		add_child(PartModels.box(Vector3(1.1, 0.45, 0.9), seat, Vector3(x, 0.23, hz - 3.2)))
		add_child(PartModels.box(Vector3(1.1, 0.7, 0.15), seat, Vector3(x, 0.8, hz - 3.6)))
	_sign("Your rocket is on the pad. Press LAUNCH at the Mission Console when you are ready.", Vector3(0, 0.95, hz - 0.85), 180.0, 28, Color(1, 1, 1))

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
		get_tree().call_group("tutor", "on_event", "launch_blocked")
		hud.show_message("CRITICAL: launch blocked. Check the console screen and the Advisors screen.", 4.0, Consequences.color("critical"))
		return
	if not g["warn"].is_empty() and _confirm_time <= 0.0:
		_confirm_time = 6.0
		console_panel.set_status("%d RED WARNING(S) on the Advisors screen. Press LAUNCH again within 6 s to launch anyway." % g["warn"].size())
		get_tree().call_group("tutor", "on_event", "launch_warning")
		hud.show_message("RED WARNINGS: the mission will underperform. Press LAUNCH again to launch anyway.", 4.0, Consequences.color("bad"))
		return
	_launch()

func _launch() -> void:
	_confirm_time = 0.0
	console_panel.set_status("")
	# Four-level flow: Level 1 ends with the launch, seen through the window, then hands over to Level 2.
	if LevelFlow.index >= 0:
		MissionState.phase = "launched"
		get_tree().call_group("tutor", "on_event", "launch")
		var seq := preload("res://scripts/world/LaunchSequence.gd").new()
		seq.lab = self
		seq.complex = complex
		seq.results = MissionState.launch_results()
		add_child(seq)
		seq.start()
		return
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
