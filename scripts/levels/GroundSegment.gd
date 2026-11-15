extends "res://scripts/world/SegmentRoom.gd"
## LEVEL 3 · GROUND SEGMENT: inside a satellite communications station at golden hour.
## The control room's big window looks out over the dish antennas, a lattice mast and dry savanna.
## Choose what to send first (flood imagery or crop imagery), then start the pass: the satellite
## crosses the sky, the dishes swing round to track it, a radio link lights up and data packets
## stream down. The link only stays open for the pass; if there is more data onboard than the pass
## can carry, the rest stays in space: the data bottleneck.

const PASS_TIME := 12.0

var dishes: Array = []          # [pivot, dish height]
var sat: Node3D
var beam: MeshInstance3D
var packets: Array = []
var passing := false
var pass_t := 0.0
var finished := false
var onboard := 0.0
var capacity := 0.0
var received := 0.0
var priority := "floods"
var prio_buttons := {}

func _configure() -> void:
	R = Vector3(14, 4.2, 10)
	title = ""
	accent = FUI.GREEN

# ======================================================================= building + outside
func _build_world() -> void:
	Outdoor.sky(self, Color(0.2, 0.34, 0.62), Color(0.98, 0.74, 0.5), Color(0.35, 0.3, 0.22), Vector3(-13, 158, 0), 1.35, Color(1.0, 0.82, 0.6))
	var wall := PartModels.mat(Color(0.62, 0.64, 0.66), 0.05, 0.85)
	var floor_m := PartModels.mat(Color(0.2, 0.24, 0.3), 0.2, 0.6)
	var ceil_m := PartModels.mat(Color(0.5, 0.52, 0.55), 0.0, 0.9)
	Outdoor.shell_with_window(self, R, floor_m, wall, ceil_m, 0.9, 3.7, 0.9, Color(0.15, 0.16, 0.18))
	Outdoor.lamps(self, R, Color(1.0, 0.93, 0.82), 0.45, 5.0)
	var hz := R.z / 2.0
	var hx := R.x / 2.0
	# Control desks facing the window
	var desk_m := PartModels.mat(Color(0.16, 0.18, 0.22), 0.4, 0.5)
	for x in [-4.0, 0.0, 4.0]:
		RoomKit.solid(self, Vector3(3.0, 0.8, 0.9), Vector3(x, 0.4, -hz + 2.2), desk_m)
		for k in [-0.8, 0.8]:
			var mon := PartModels.box(Vector3(0.9, 0.55, 0.05), PartModels.mat(Color(0.05, 0.25, 0.2), 0.0, 0.3, 1.2), Vector3(x + k, 1.15, -hz + 2.0))
			mon.rotation_degrees.x = -10
			add_child(mon)
	# Equipment racks on the back wall, with blinking lights
	for x in range(-6, 7, 2):
		RoomKit.solid(self, Vector3(1.4, 2.2, 0.7), Vector3(x, 1.1, hz - 0.4), PartModels.mat(Color(0.22, 0.24, 0.27), 0.6, 0.4))
		for k in 6:
			add_child(PartModels.box(Vector3(0.05, 0.04, 0.02), PartModels.mat([FUI.GREEN, FUI.AMBER, FUI.SKY][k % 3], 0, 0.5, 2.5), Vector3(x - 0.4 + k * 0.15, 1.7, hz - 0.76)))
	RoomKit.sign(self, "GROUND STATION · SATELLITE OPERATIONS", Vector3(0, R.y - 0.25, -hz + 0.02), 0.0, 40, FUI.GREEN)

	# Outside: dry savanna, dishes, mast, fence, access road, hills
	var out := Node3D.new()
	out.position = Vector3(0, 0, -hz)
	add_child(out)
	Outdoor.ground(out, 3000.0, Color(0.56, 0.5, 0.32))
	Outdoor.slab(out, Vector3(8, 0.06, 400), Vector3(-14, 0.02, -200), Color(0.4, 0.38, 0.34))
	Outdoor.slab(out, Vector3(160, 0.05, 110), Vector3(0, 0.02, -95), Color(0.5, 0.48, 0.42))
	Outdoor.hills(out, 16, 1200.0, Color(0.45, 0.42, 0.28), 8)
	Outdoor.trees(out, 140, 500.0, Vector3(0, 0, -250), Rect2(-110, -170, 220, 170), 21, 0.9)
	for d in [["ex_dsn70", Vector3(-40, 0, -115), 34.0], ["ex_dsn34", Vector3(30, 0, -80), 24.0], ["ex_dsn_antenna", Vector3(-2, 0, -55), 13.0]]:
		var pv := Node3D.new()
		pv.position = d[1]
		out.add_child(pv)
		var m := ModelLib.fit(d[0], d[2], "height")
		if m:
			pv.add_child(m)
		else:
			pv.add_child(PartModels.cyl(d[2] * 0.4, d[2] * 0.1, d[2] * 0.2, PartModels.alu(), Vector3(0, d[2] * 0.8, 0), Vector3(60, 0, 0)))
		Outdoor.slab(out, Vector3(d[2] * 0.9, 0.4, d[2] * 0.9), d[1] + Vector3(0, 0.2, 0), Color(0.7, 0.68, 0.64))
		dishes.append([pv, d[2]])
	Outdoor.lattice(out, Vector3(62, 0, -100), 48.0, 4.0, Color(0.85, 0.85, 0.85), 5.0)
	Outdoor.beacon(out, Vector3(62, 48.5, -100))
	var fence := PartModels.mat(Color(0.6, 0.6, 0.6), 0.5, 0.5)
	for i in 27:
		out.add_child(PartModels.box(Vector3(0.12, 2.2, 0.12), fence, Vector3(-80 + i * 6.0, 1.1, -150)))
	out.add_child(PartModels.box(Vector3(160, 0.05, 0.05), fence, Vector3(0, 2.0, -150)))
	out.add_child(PartModels.box(Vector3(160, 0.05, 0.05), fence, Vector3(0, 1.0, -150)))
	Outdoor.clouds(out, 10, 1200.0, 500.0, 31, Color(1.0, 0.88, 0.78))

	# The satellite (a bright point with a label) and the radio link
	sat = Node3D.new()
	sat.visible = false
	add_child(sat)
	sat.add_child(PartModels.ball(2.2, PartModels.mat(Color(1, 1, 1), 0.0, 0.3, 6.0)))
	var sl := Label3D.new()
	sl.text = "FLOOD & CROP WATCH"
	sl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sl.fixed_size = true
	sl.pixel_size = 0.0012
	sl.font_size = 32
	sl.outline_size = 8
	sl.position = Vector3(0, 8, 0)
	sat.add_child(sl)
	beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.4
	cm.bottom_radius = 0.4
	cm.height = 1.0
	beam.mesh = cm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(0.4, 1.0, 0.7, 0.45)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material_override = bm
	beam.visible = false
	add_child(beam)
	for i in 14:
		var p := PartModels.ball(1.1, PartModels.mat(Color(0.5, 1.0, 0.8), 0.0, 0.3, 5.0))
		p.visible = false
		add_child(p)
		packets.append(p)

# ======================================================================= controls
func _build_level() -> void:
	var sp: Dictionary = MissionState.level_results.get("space", {})
	var x: Dictionary = MissionState.compute()["extra"]
	onboard = sp.get("stored_gb", 0.0)
	var days: float = sp.get("days", 30.0)
	capacity = x["downlink"] * days
	MissionState.set_live("onboard_gb", onboard)
	MissionState.set_live("capacity_gb", capacity)
	MissionState.set_live("received_gb", 0.0)
	MissionState.set_live("station", "3 dishes, 1 site")
	var hz := R.z / 2.0
	var obj := preload("res://scripts/panels/ObjectivePanel.gd").new()
	obj.info = {"goal": "Get the data home",
		"story": "The satellite only talks to us while it flies over the station. This month's passes can carry %.1f GB, and there are %.1f GB waiting onboard. Decide what comes down first." % [capacity, onboard],
		"decisions": ["Priority: flood imagery first, or crop-health imagery first", "Start the pass and watch the link", "What stays in space if the link is too slow"]}
	screen("Objective", "OBJECTIVE", Vector2(3.0, 1.8), Vector2i(1000, 600), Vector3(-R.x / 2.0 + 0.06, 2.1, 0.5), 90.0, obj)
	spawn = Vector3(0, 0.1, hz - 2.6)
	# Priority and pass buttons on the middle desk
	prio_buttons["floods"] = button("PRIORITY\nFLOODS", FUI.SKY, set_priority.bind("floods"), Vector3(-1.0, 0.85, -hz + 2.6))
	prio_buttons["crops"] = button("PRIORITY\nCROPS", FUI.GREEN, set_priority.bind("crops"), Vector3(-0.2, 0.85, -hz + 2.6))
	button("START\nPASS", FUI.AMBER, start_pass, Vector3(1.0, 0.85, -hz + 2.6), 0.0, true)
	set_priority("floods")

func set_priority(p: String) -> void:
	priority = p
	MissionState.set_live("priority", p)
	for k in prio_buttons:
		prio_buttons[k].set_lit(k == p)
	get_tree().call_group("tutor", "on_event", "priority_" + p)

func start_pass() -> void:
	if passing or finished:
		return
	passing = true
	pass_t = 0.0
	sat.visible = true
	get_tree().call_group("tutor", "on_event", "pass_start")

func _process(delta: float) -> void:
	if not passing:
		return
	pass_t += delta
	var k := clampf(pass_t / PASS_TIME, 0.0, 1.0)
	# Arc across the sky, left horizon to right horizon, in front of the building
	var a := lerpf(-1.25, 1.25, k)
	sat.global_position = Vector3(sin(a) * 520.0, cos(a) * 170.0 + 10.0, -R.z / 2.0 - 360.0)
	var main: Node3D = dishes[0][0]
	for d in dishes:
		var pv: Node3D = d[0]
		var to := sat.global_position - pv.global_position
		pv.rotation.y = lerp_angle(pv.rotation.y, atan2(-to.x, -to.z), 0.08)
	var link_on := k > 0.08 and k < 0.92
	var top: Vector3 = main.global_position + Vector3(0, dishes[0][1] * 0.75, 0)
	beam.visible = link_on
	if link_on:
		beam.global_position = (top + sat.global_position) / 2.0
		beam.scale = Vector3(1, top.distance_to(sat.global_position), 1)
		beam.look_at(sat.global_position, Vector3.UP)
		beam.rotate_object_local(Vector3(1, 0, 0), -PI / 2)
		var rate := capacity / (PASS_TIME * 0.84)
		received = minf(onboard, received + rate * delta)
		MissionState.set_live("received_gb", received)
		MissionState.set_live("transmitted_gb", received)
		if received >= onboard - 0.001:
			beam.visible = received < onboard
	for i in packets.size():
		var p: Node3D = packets[i]
		p.visible = link_on and received < onboard
		var f := fmod(pass_t * 0.6 + i / float(packets.size()), 1.0)
		p.global_position = sat.global_position.lerp(top, f)
	if k >= 1.0:
		_end_pass()

func _end_pass() -> void:
	passing = false
	finished = true
	sat.visible = false
	beam.visible = false
	for p in packets:
		p.visible = false
	var left := maxf(onboard - received, 0.0)
	var sp: Dictionary = MissionState.level_results.get("space", {})
	var x: Dictionary = MissionState.compute()["extra"]
	get_tree().call_group("tutor", "on_event", "bottleneck" if left > 0.01 else "all_received")
	await get_tree().create_timer(6.0).timeout
	finish_level({"received_gb": received, "lost_gb": left + sp.get("overflow_gb", 0.0), "left_onboard_gb": left,
		"capacity_gb": capacity, "priority": priority,
		"delay_days": clampf(float(x["data_gen"]) / maxf(float(x["downlink"]), 0.001), 0.2, 30.0)})

# ======================================================================= test helper
func test_views(d) -> void:
	player.teleport(Vector3(0, 0.1, -1.0), 0.0)
	player.cam.rotation.x = deg_to_rad(6)
	await d._shot("ground_1_window", 30)
	start_pass()
	await d._wait(5.0)
	await d._shot("ground_2_pass", 2)
	await d._wait(5.5)
	await d._shot("ground_3_late", 2)
