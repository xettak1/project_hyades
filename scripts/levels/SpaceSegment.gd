extends "res://scripts/world/SegmentRoom.gd"
## LEVEL 2 · SPACE SEGMENT: inside the satellite, 700 km above Africa.
## A big observation window looks down on Earth (Africa, with the four farming regions marked).
## The planet turns below as the satellite orbits; between passes over Africa time fast-forwards.
## Pick a region that is IN VIEW on the Observation Console and scan it: a beam reaches down,
## the Satellite Camera zooms into the fields, and the pictures fill the onboard memory.
## Clouds can ruin an optical picture; memory can overflow; passes are limited (30 days / revisit).

const CAMPAIGN_DAYS := 30
const CLOUD_LIMIT := 0.68
const VIEW_ANGLE := 42.0           # degrees from straight down that the instrument can point
const ORBIT_SPEED := 0.03          # rad/s while Africa is below
const FAST_SPEED := 0.4            # rad/s fast-forward between passes
const SCAN_TIME := 2.8

var earth
var pivot: Node3D
var centre: Vector3
var sat_pos: Vector3
var markers: Dictionary = {}
var puffs: Dictionary = {}
var beam: MeshInstance3D
var cam: Camera3D
var scanline: ColorRect
var cam_label: Label

var selected := ""
var scanning := false
var fast := false
var scan_t := 0.0
var day := 0
var passes_total := 0
var passes_left := 0
var collected_gb := 0.0
var useful_gb := 0.0
var stored_gb := 0.0
var overflow_gb := 0.0
var storage_gb := 0.0
var scanned: Dictionary = {}
var scans_done := 0
# Power model (fed to the instruments and the left panel): sunlight / eclipse around each orbit
var orbit_ang := 0.0
var battery_wh := -1.0

func _configure() -> void:
	R = Vector3(9, 3.4, 9)
	title = ""
	accent = FUI.SKY

# ======================================================================= the spacecraft and Earth
func _build_world() -> void:
	Outdoor.space(self, Vector3(-32, 28, 0))   # sun behind and above the satellite, lighting the dayside below
	var wall := PartModels.mat(Color(0.86, 0.88, 0.9), 0.15, 0.55)
	var floor_m := PartModels.mat(Color(0.2, 0.22, 0.26), 0.5, 0.5)
	var ceil_m := PartModels.mat(Color(0.8, 0.82, 0.85), 0.1, 0.6)
	Outdoor.shell_with_window(self, R, floor_m, wall, ceil_m, 0.45, 3.05, 0.7, Color(0.3, 0.32, 0.36))
	Outdoor.lamps(self, R, Color(0.85, 0.92, 1.0), 0.28, 4.5)
	var hx := R.x / 2.0
	var hz := R.z / 2.0
	# Ceiling light strips, panel seams, handrails, equipment racks, cable runs
	var strip := PartModels.mat(Color(0.9, 0.95, 1.0), 0.0, 0.5, 2.0)
	for x in [-2.5, 0.0, 2.5]:
		add_child(PartModels.box(Vector3(0.18, 0.04, R.z - 2.0), strip, Vector3(x, R.y - 0.03, 0.5)))
	var seam := PartModels.mat(Color(0.55, 0.58, 0.62), 0.3, 0.5)
	for z in range(-3, 5, 2):
		for sx in [-1, 1]:
			add_child(PartModels.box(Vector3(0.03, R.y, 0.04), seam, Vector3(sx * (hx - 0.01), R.y / 2, z)))
	var rail := PartModels.mat(Color(1.0, 0.78, 0.15), 0.4, 0.4)
	for sx in [-1, 1]:
		for y in [1.05, 2.75]:
			add_child(PartModels.cyl(0.03, 0.03, R.z - 1.5, rail, Vector3(sx * (hx - 0.12), y, 0.4), Vector3(90, 0, 0)))
	var rack := PartModels.mat(Color(0.32, 0.35, 0.4), 0.6, 0.4)
	for sx in [-1, 1]:
		for z in [1.6, 3.0]:
			add_child(PartModels.box(Vector3(0.6, 1.6, 1.1), rack, Vector3(sx * (hx - 0.35), 0.8, z)))
			for k in 5:
				var led := PartModels.mat([FUI.GREEN, FUI.SKY, FUI.AMBER][k % 3], 0.0, 0.5, 2.5)
				add_child(PartModels.box(Vector3(0.02, 0.04, 0.06), led, Vector3(sx * (hx - 0.66), 0.4 + k * 0.25, z - 0.3)))
	var cable := PartModels.mat(Color(0.12, 0.12, 0.14), 0.0, 0.8)
	add_child(PartModels.cyl(0.05, 0.05, R.x - 1.0, cable, Vector3(0, R.y - 0.25, hz - 0.3), Vector3(0, 0, 90)))
	# Your payload, mounted at the window, looking down at Earth
	add_child(PartModels.box(Vector3(0.8, 0.5, 0.8), rack, Vector3(-2.6, 0.25, -hz + 0.9)))
	var inst := PartModels.for_part("payload", MissionState.picks.get("payload", ""))
	if inst:
		inst.scale = Vector3.ONE * 1.6
		inst.position = Vector3(-2.6, 0.5, -hz + 0.9)
		add_child(inst)
	RoomKit.sign(self, "FLOOD & CROP WATCH · %s" % MissionState.orbit()["name"].split(" (")[0].to_upper(), Vector3(0, R.y - 0.18, -hz + 0.02), 0.0, 30, FUI.SKY)

	# Earth below: 1 unit = 10 km, satellite 700 km up. Africa faces the window.
	var eye := Vector3(0, 1.6, 2.0)
	var down := Vector3(0, -0.52, -0.855).normalized()
	centre = eye + down * (637.1 + 70.0)
	sat_pos = Vector3(0, 1.6, -hz - 1.5)
	pivot = Node3D.new()
	pivot.position = centre
	add_child(pivot)
	earth = preload("res://scripts/world/EarthGlobe.gd").new()
	pivot.add_child(earth)
	earth.face(11.0, 4.0, -down, Vector3(0, 0, -1))
	_build_regions()
	beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 1.6
	cm.height = 1.0
	beam.mesh = cm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(0.3, 0.9, 1.0, 0.35)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = bm
	beam.visible = false
	add_child(beam)

func _build_regions() -> void:
	var truth := FarmRegions.truth()
	for ri in FarmRegions.REGIONS.size():
		var r: Dictionary = FarmRegions.REGIONS[ri]
		var holder := Node3D.new()
		earth.place_flat(holder, r["lat"], r["lon"], 0.4)
		# Farm fields (3 x 2 plots, 3 km... shown 30 km wide so they are visible from orbit)
		var plots := truth.filter(func(p): return p["region"] == r["id"])
		for k in plots.size():
			var pm := PlaneMesh.new()
			pm.size = Vector2(2.8, 2.8)
			var mi := MeshInstance3D.new()
			mi.mesh = pm
			var col: Color = FarmRegions.COLORS[plots[k]["state"]].darkened(0.25)
			mi.material_override = PartModels.mat(col, 0.0, 0.9, 0.04)
			mi.position = Vector3((k % 3 - 1) * 3.0, 0.0, (k / 3 - 0.5) * 3.0)
			holder.add_child(mi)
			for row in 5:   # crop rows, visible when the camera zooms in
				mi.add_child(PartModels.box(Vector3(2.6, 0.02, 0.12), PartModels.mat(col.darkened(0.35), 0.0, 1.0), Vector3(0, 0.02, -1.1 + row * 0.55)))
		# Selection ring and name
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 6.2
		tm.outer_radius = 6.9
		ring.mesh = tm
		ring.material_override = PartModels.mat(FUI.AMBER, 0.0, 0.5, 2.0)
		holder.add_child(ring)
		var lab := Label3D.new()
		lab.text = r["name"]
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.fixed_size = true
		lab.pixel_size = 0.0011
		lab.font_size = 34
		lab.outline_size = 10
		lab.no_depth_test = true
		# each name sits on its own side of its region, so neighbouring names never overlap
		var off: Vector2 = {"volta": Vector2(-2.0, 11.0), "niger_delta": Vector2(-7.0, -9.5), "benue": Vector2(9.0, 10.0), "chad": Vector2(6.0, -9.5)}.get(r["id"], Vector2(0, -8))
		lab.position = Vector3(off.x, 4.0, off.y)
		holder.add_child(lab)
		# Cloud puff (shown when the region is cloudy on this pass)
		var puff := Node3D.new()
		for k in 5:
			var b := PartModels.ball(2.6, PartModels.mat(Color(1, 1, 1), 0.0, 1.0, 0.3), Vector3(randf_range(-3, 3), 2.0, randf_range(-3, 3)))
			b.scale = Vector3(1.6, 0.6, 1.3)
			puff.add_child(b)
		holder.add_child(puff)
		markers[r["id"]] = [ring, lab]
		puffs[r["id"]] = puff

# ======================================================================= consoles
func _build_level() -> void:
	var x: Dictionary = MissionState.compute()["extra"]
	passes_total = int(floor(CAMPAIGN_DAYS / maxf(float(x["revisit"]), 1.0)))
	passes_left = passes_total
	storage_gb = x["storage"]
	MissionState.set_live("target_gb", per_pass_gb() * passes_total)
	MissionState.set_live("stored_gb", 0.0)
	MissionState.set_live("storage_gb", storage_gb)
	var hx := R.x / 2.0
	var hz := R.z / 2.0
	var panel := preload("res://scripts/panels/ObservationPanel.gd").new()
	panel.room = self
	screen("Observation Console", "OBSERVATION CONSOLE", Vector2(2.9, 1.9), Vector2i(900, 590), Vector3(-hx + 0.06, 1.75, -0.7), 90.0, panel)
	# Live satellite camera
	cam = Camera3D.new()
	cam.fov = 24.0
	cam.far = 3000.0
	var ov := Control.new()
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cam_label = FUI.t("SATELLITE CAMERA", 22, FUI.SKY, "mono_semi")
	cam_label.position = Vector2(18, 12)
	ov.add_child(cam_label)
	var cross := FUI.t("+", 40, Color(1, 1, 1, 0.6))
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.position = Vector2(470, 270)
	ov.add_child(cross)
	scanline = ColorRect.new()
	scanline.color = Color(0.3, 1.0, 0.9, 0.7)
	scanline.size = Vector2(960, 4)
	scanline.visible = false
	ov.add_child(scanline)
	var cs = screen("Satellite Camera", "SATELLITE CAMERA", Vector2(2.6, 1.62), Vector2i(960, 600), Vector3(hx - 0.06, 1.75, -0.7), -90.0, null)
	cs.set_camera(cam, ov)
	ov.add_child(SpaceInstruments.CameraOverlay.new())
	# Flight displays on the back wall: power, data & instruments, orbital position
	var specs := [[SpaceInstruments.Power, "ELECTRICAL POWER", "Power System", -2.6],
		[SpaceInstruments.Data, "DATA & INSTRUMENTS", "Data and Instruments", 0.0],
		[SpaceInstruments.Orbit, "ORBITAL POSITION", "Orbital Position", 2.6]]
	for sp in specs:
		var d = screen(sp[2], sp[1], Vector2(2.35, 1.48), Vector2i(880, 556), Vector3(sp[3], 1.85, hz - 0.12), 180.0, null)
		d.set_display(sp[0].new())
	spawn = Vector3(0, 0.1, 2.0)

# ======================================================================= state helpers (used by the console)
func _region_index(id: String) -> int:
	for i in FarmRegions.REGIONS.size():
		if FarmRegions.REGIONS[i]["id"] == id:
			return i
	return -1

func in_view(id: String) -> bool:
	var r := FarmRegions.region(id)
	if r.is_empty():
		return false
	var n: Vector3 = earth.world_normal(r["lat"], r["lon"])
	var to_sat := (sat_pos - centre).normalized()
	return rad_to_deg(n.angle_to(to_sat)) < VIEW_ANGLE

func cloud_now(id: String) -> float:
	return FarmRegions.cloud_cover(_region_index(id), scans_done)

func per_pass_gb() -> float:
	var x: Dictionary = MissionState.compute()["extra"]
	return float(x["data_gen"]) * maxf(float(x["revisit"]), 1.0)

func scan_blocker() -> String:
	if selected == "":
		return "no region selected"
	if passes_left <= 0:
		return "no passes left this month"
	if not in_view(selected):
		return "not below us right now: wait for the next pass"
	return ""

func select_region(id: String) -> void:
	selected = id
	MissionState.set_live("region_name", FarmRegions.region(id)["name"])
	if not in_view(id):
		get_tree().call_group("tutor", "on_event", "not_in_view")
	elif scans_done == 0:
		get_tree().call_group("tutor", "on_event", "region_selected")

func scan() -> void:
	if scan_blocker() != "" or scanning:
		if selected != "" and not in_view(selected):
			get_tree().call_group("tutor", "on_event", "not_in_view")
		return
	scanning = true
	scan_t = 0.0
	MissionState.set_live("instrument_state", "ACTIVE")

func _scan_done() -> void:
	scanning = false
	beam.visible = false
	scanline.visible = false
	MissionState.set_live("instrument_state", "STANDBY")
	var x: Dictionary = MissionState.compute()["extra"]
	var per := per_pass_gb()
	var cloudy := cloud_now(selected) > CLOUD_LIMIT
	collected_gb += per
	var room_left := maxf(storage_gb - stored_gb, 0.0)
	var kept := minf(per, room_left)
	stored_gb += kept
	overflow_gb += per - kept
	if not cloudy:
		useful_gb += kept * float(x["pointing"])
		scanned[selected] = int(scanned.get(selected, 0)) + 1
	scans_done += 1
	passes_left -= 1
	day = mini(CAMPAIGN_DAYS, day + int(maxf(float(x["revisit"]), 1.0)))
	MissionState.set_live("scan_gb", "%.1f" % per)
	MissionState.set_live("collected_gb", collected_gb)
	MissionState.set_live("stored_gb", stored_gb)
	var ev := "scan_done"
	if cloudy:
		ev = "scan_cloudy"
	if per > room_left:
		ev = "storage_full"
	elif stored_gb > storage_gb * 0.8 and not cloudy:
		ev = "storage_high"
	get_tree().call_group("tutor", "on_event", "first_scan")
	get_tree().call_group("tutor", "on_event", ev)
	if passes_left <= 0:
		get_tree().call_group("tutor", "on_event", "no_passes")

func end_campaign() -> void:
	var ids: Array = []
	for id in scanned:
		ids.append(id)
	finish_level({"days": float(maxi(day, 1)), "collected_gb": collected_gb, "useful_gb": useful_gb, "stored_gb": stored_gb,
		"overflow_gb": overflow_gb, "scanned": ids, "scans": scans_done, "passes_total": passes_total})

# ======================================================================= per frame: orbit, camera, scan effect
func _process(delta: float) -> void:
	var any := false
	for r in FarmRegions.REGIONS:
		var vis := in_view(r["id"])
		any = any or vis
		var m: Array = markers[r["id"]]
		var sel: bool = r["id"] == selected
		m[0].material_override.emission = (FUI.GREEN if sel else FUI.AMBER) * (2.5 if vis else 0.6)
		m[0].scale = Vector3.ONE * (1.0 + (0.15 * sin(Time.get_ticks_msec() / 200.0) if sel else 0.0))
		m[1].modulate = FUI.GREEN if sel else (Color(1, 1, 1) if vis else Color(0.6, 0.6, 0.6))
		puffs[r["id"]].visible = cloud_now(r["id"]) > CLOUD_LIMIT
	fast = not any
	var dang := 0.0
	if not scanning:
		dang = (FAST_SPEED if fast else ORBIT_SPEED) * delta
		pivot.rotate(Vector3(1, 0, 0), -dang)
	else:
		dang = ORBIT_SPEED * 0.25 * delta    # time still passes while scanning
	_power_step(dang)
	_update_camera(delta)
	if scanning:
		scan_t += delta
		var r := FarmRegions.region(selected)
		var p: Vector3 = earth.world_point(r["lat"], r["lon"])
		beam.visible = true
		var mid := (sat_pos + p) / 2.0
		beam.global_position = mid
		beam.scale = Vector3(1, sat_pos.distance_to(p), 1)
		beam.look_at(p, Vector3.UP)
		beam.rotate_object_local(Vector3(1, 0, 0), -PI / 2)
		scanline.visible = true
		scanline.position.y = fmod(scan_t * 420.0, 600.0)
		if scan_t >= SCAN_TIME:
			_scan_done()

## Battery / solar / load around the orbit, from the parts you chose in Level 1.
func _power_step(dang: float) -> void:
	orbit_ang += dang
	var o := MissionState.orbit()
	var x: Dictionary = MissionState.compute()["extra"]
	var ef := clampf(float(o.get("eclipse_min", 30.0)) / maxf(float(o.get("period_min", 95.0)), 1.0), 0.0, 0.45)
	var ph := fposmod(orbit_ang, TAU)
	var eclipse := absf(wrapf(ph - PI, -PI, PI)) < PI * ef
	var gen := 0.0 if eclipse else float(x["gen_avg"]) / maxf(1.0 - ef, 0.1)
	var pay := float(MissionState.part_of("payload").get("power", 0.0))
	var load := float(x["load_w"]) + (pay if scanning else 0.0)
	var cap := maxf(float(MissionState.part_of("battery").get("energy", 10.0)), 0.1)
	if battery_wh < 0.0:
		battery_wh = cap
	var dt_h := dang / TAU * float(o.get("period_min", 95.0)) / 60.0
	battery_wh = clampf(battery_wh + (gen - load) * dt_h, 0.0, cap)
	var lv := MissionState.live
	lv["battery_frac"] = battery_wh / cap
	lv["battery_wh"] = battery_wh
	lv["battery_cap_wh"] = cap
	lv["gen_now"] = gen
	lv["load_now"] = load
	lv["eclipse"] = eclipse
	lv["orbit_phase"] = ph / TAU
	# Sub-satellite point (lat, lon) from the real 3D geometry
	if earth and earth.spin:
		var d: Vector3 = earth.spin.to_local(sat_pos).normalized()
		lv["sub_lat"] = rad_to_deg(asin(clampf(d.y, -1.0, 1.0)))
		lv["sub_lon"] = rad_to_deg(atan2(-d.x, -d.z))

func _update_camera(_delta: float) -> void:
	var target_id := selected
	if target_id == "":
		cam.global_position = sat_pos
		cam.look_at(centre, Vector3(0, 0, -1))
		cam_label.text = "SATELLITE CAMERA · looking straight down"
		return
	var r := FarmRegions.region(target_id)
	var p: Vector3 = earth.world_point(r["lat"], r["lon"])
	var n: Vector3 = earth.world_normal(r["lat"], r["lon"])
	var north: Vector3 = (earth.world_point(r["lat"] + 1.0, r["lon"]) - p).normalized()
	var dist := 70.0
	if scanning:
		dist = lerpf(70.0, 7.0, clampf(scan_t / (SCAN_TIME * 0.7), 0.0, 1.0))
	if not in_view(target_id):
		cam_label.text = "SATELLITE CAMERA · %s is below the horizon" % r["name"]
		cam.global_position = sat_pos
		cam.look_at(centre, Vector3(0, 0, -1))
		return
	cam.global_position = p + n * dist
	cam.look_at(p, north)
	cam_label.text = "SATELLITE CAMERA · %s%s" % [r["name"], "  ·  SCANNING" if scanning else ""]

# ======================================================================= test helper
func test_views(d) -> void:
	player.teleport(Vector3(0, 0.1, 2.0), 0.0)
	player.cam.rotation.x = deg_to_rad(-18)
	await d._shot("space_1_window", 40)
	for i in 600:
		var ok := false
		for r in FarmRegions.REGIONS:
			ok = ok or in_view(r["id"])
		if ok:
			break
		await get_tree().process_frame
	for r in FarmRegions.REGIONS:
		if in_view(r["id"]):
			select_region(r["id"])
			break
	await d._shot("space_2_selected", 20)
	scan()
	await d._wait(1.6)
	await d._shot("space_3_scanning", 2)
	player.teleport(Vector3(2.2, 0.1, -0.7), -90.0)
	await d._shot("space_4_camera", 4)
	await d._wait(2.0)
	get_tree().current_scene.find_children("*", "StaticBody3D", true, false).filter(func(n): return "screen_name" in n and n.screen_name == "Observation Console")[0].interact()
	await d._shot("space_5_console", 20)
