extends "res://scripts/world/SegmentRoom.gd"
## LEVEL 4 · USER SEGMENT: an agricultural research and analysis centre on a bright day.
## The glass front looks out over the very farmland the satellite photographed: 24 plots in four rows
## (one row per region), some healthy, some stressed, some under water.
## At the ANALYSIS workstation the player sees the satellite imagery of every plot. Grey plots have no
## imagery (not photographed in Level 2, or the data never reached Earth in Level 3). Mark the
## flooded plots, choose how to tell people, deliver the report.

var plots: Array = []           # [{id, region, state, seen, marked}]
var product := ""
var delay_days := 0.0
var _panel
var delivered := false

func _configure() -> void:
	R = Vector3(16, 4.0, 11)
	title = ""
	accent = FUI.AMBER

# ======================================================================= which plots have imagery
func _make_plots() -> void:
	var sp: Dictionary = MissionState.level_results.get("space", {})
	var g: Dictionary = MissionState.level_results.get("ground", {})
	var scanned: Array = sp.get("scanned", [])
	var got: float = g.get("received_gb", 0.0)
	var left: float = g.get("left_onboard_gb", g.get("lost_gb", 0.0))
	var frac := clampf(got / maxf(got + left, 0.001), 0.0, 1.0) if got > 0.0 else 0.0
	var prio: String = g.get("priority", "floods")
	delay_days = g.get("delay_days", 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	plots = []
	for p in FarmRegions.truth():
		var d: Dictionary = p.duplicate()
		var flood_like := FarmRegions.is_flood(p["state"])
		# Data sent first (the priority) is more likely to have made it down before the link closed.
		var chance := frac
		if frac < 1.0:
			chance = minf(1.0, frac * 1.6) if (flood_like == (prio == "floods")) else frac * 0.6
		d["seen"] = scanned.has(p["region"]) and rng.randf() < chance
		d["marked"] = false
		plots.append(d)
	MissionState.set_live("plots", plots)
	MissionState.set_live("plots_total", plots.size())

func why_missing(p: Dictionary) -> String:
	var sp: Dictionary = MissionState.level_results.get("space", {})
	if not sp.get("scanned", []).has(p["region"]):
		return "We never photographed this region in orbit (Level 2)."
	return "The pictures were taken but never reached Earth: the link closed first (Level 3)."

# ======================================================================= building + farmland outside
func _build_world() -> void:
	Outdoor.sky(self, Color(0.25, 0.5, 0.9), Color(0.78, 0.87, 0.97), Color(0.35, 0.4, 0.3), Vector3(-55, 200, 0), 1.3)
	var wall := PartModels.mat(Color(0.93, 0.93, 0.91), 0.0, 0.85)
	var floor_m := PartModels.mat(Color(0.7, 0.55, 0.38), 0.0, 0.55)
	var ceil_m := PartModels.mat(Color(0.96, 0.96, 0.95), 0.0, 0.9)
	Outdoor.shell_with_window(self, R, floor_m, wall, ceil_m, 0.6, 3.6, 0.6, Color(0.85, 0.85, 0.85))
	Outdoor.lamps(self, R, Color(1, 0.98, 0.94), 0.4, 5.0)
	var hz := R.z / 2.0
	# Ceiling light panels, plants, a meeting table
	var panel_m := PartModels.mat(Color(1, 1, 1), 0.0, 0.5, 1.5)
	for x in [-5.0, 0.0, 5.0]:
		for z in [-2.0, 2.5]:
			add_child(PartModels.box(Vector3(1.6, 0.03, 1.0), panel_m, Vector3(x, R.y - 0.02, z)))
	for p in [Vector3(-7.2, 0, hz - 0.6), Vector3(7.2, 0, hz - 0.6), Vector3(7.2, 0, -hz + 0.9)]:
		add_child(PartModels.cyl(0.28, 0.22, 0.5, PartModels.mat(Color(0.85, 0.85, 0.82)), p + Vector3(0, 0.25, 0)))
		add_child(PartModels.ball(0.5, PartModels.mat(Color(0.2, 0.5, 0.2)), p + Vector3(0, 0.95, 0)))
	RoomKit.solid(self, Vector3(3.2, 0.06, 1.4), Vector3(2.5, 0.76, 2.4), PartModels.mat(Color(0.85, 0.8, 0.7), 0.0, 0.5))
	RoomKit.sign(self, "AGRICULTURAL ANALYSIS CENTRE", Vector3(0, R.y - 0.22, hz - 0.03), 180.0, 44, Color(0.15, 0.45, 0.25))

	# Outside: the farm plots, a river, a farmhouse, trees, hills
	var out := Node3D.new()
	out.position = Vector3(0, 0, -hz)
	add_child(out)
	Outdoor.ground(out, 3000.0, Color(0.4, 0.5, 0.26))
	Outdoor.hills(out, 14, 1300.0, Color(0.35, 0.48, 0.28), 14)
	Outdoor.trees(out, 220, 700.0, Vector3(0, 0, -350), Rect2(-80, -160, 160, 160), 31)
	Outdoor.clouds(out, 16, 1200.0, 600.0, 41)
	var truth := FarmRegions.truth()
	for i in truth.size():
		var p: Dictionary = truth[i]
		var col := i % 6
		var row := i / 6
		var c := Vector3((col - 2.5) * 21.0, 0, -18.0 - row * 26.0)
		_field(out, c, p["state"], p["id"])
	# Dirt tracks between the rows, a river beyond the fields, a farmhouse
	for row in 5:
		Outdoor.slab(out, Vector3(130, 0.05, 3.0), Vector3(0, 0.02, -4.5 - row * 26.0), Color(0.55, 0.45, 0.32))
	for k in 6:
		Outdoor.slab(out, Vector3(26, 0.06, 14), Vector3(-80 + k * 30.0 + sin(k) * 8.0, 0.03, -128 + cos(k * 1.3) * 6.0), Color(0.2, 0.4, 0.55), 0.1)
	Outdoor.slab(out, Vector3(10, 4, 8), Vector3(78, 2, -40), Color(0.85, 0.82, 0.75))
	var roof := PartModels.box(Vector3(10.6, 0.4, 9.0), PartModels.mat(Color(0.6, 0.25, 0.2)), Vector3(78, 4.4, -40))
	out.add_child(roof)
	Outdoor.slab(out, Vector3(3, 6, 3), Vector3(70, 3, -48), Color(0.7, 0.7, 0.72))

## One farm plot outside: crop rows, yellowing, standing water, or mud, matching what the satellite saw.
func _field(out: Node3D, c: Vector3, state: String, id: String) -> void:
	var base: Color = {"healthy": Color(0.36, 0.3, 0.2), "stressed": Color(0.5, 0.42, 0.25), "flooded": Color(0.3, 0.27, 0.2), "waterlogged": Color(0.28, 0.22, 0.15)}[state]
	Outdoor.slab(out, Vector3(18, 0.1, 22), c + Vector3(0, 0.05, 0), base)
	var crop: Color = {"healthy": Color(0.2, 0.55, 0.18), "stressed": Color(0.72, 0.62, 0.2), "flooded": Color(0.25, 0.45, 0.2), "waterlogged": Color(0.35, 0.45, 0.2)}[state]
	var rows := 9
	for r in rows:
		var h := 0.6 if state != "stressed" else 0.4
		out.add_child(PartModels.box(Vector3(16, h, 0.9), Outdoor.flat(crop.lerp(crop.darkened(0.2), r % 2)), c + Vector3(0, 0.1 + h / 2, -9.6 + r * 2.4)))
	if state == "flooded":
		var w := StandardMaterial3D.new()
		w.albedo_color = Color(0.28, 0.42, 0.55, 0.92)
		w.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		w.metallic = 0.4
		w.roughness = 0.08
		out.add_child(PartModels.box(Vector3(18.5, 0.1, 22.5), w, c + Vector3(0, 0.55, 0)))
	elif state == "waterlogged":
		for k in 4:
			var pool := StandardMaterial3D.new()
			pool.albedo_color = Color(0.3, 0.42, 0.5)
			pool.metallic = 0.3
			pool.roughness = 0.1
			out.add_child(PartModels.box(Vector3(5.0, 0.12, 3.5), pool, c + Vector3(-5 + (k % 2) * 9.0, 0.7, -6 + (k / 2) * 11.0)))
	var post := Label3D.new()
	post.text = id
	post.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	post.font_size = 64
	post.pixel_size = 0.012
	post.outline_size = 12
	post.modulate = Color(1, 1, 1, 0.9)
	post.position = c + Vector3(-8.0, 1.6, 10.5)
	out.add_child(post)

# ======================================================================= analysis workstations
func _build_level() -> void:
	_make_plots()
	var hz := R.z / 2.0
	var hx := R.x / 2.0
	_panel = preload("res://scripts/panels/AnalysisPanel.gd").new()
	_panel.room = self
	screen("Analysis Workstation", "SATELLITE IMAGERY ANALYSIS", Vector2(3.8, 2.3), Vector2i(1000, 605), Vector3(-hx + 0.06, 1.9, 0.0), 90.0, _panel)
	var desk := PartModels.mat(Color(0.95, 0.95, 0.95), 0.0, 0.4)
	# Three geospatial workstations on the desks (facing the analyst), each on a monitor stand
	var stand := PartModels.mat(Color(0.12, 0.12, 0.13), 0.6, 0.35)
	var ws := [[UserInstruments.Health, "CROP HEALTH (NDVI)", "Crop Health Map", -4.0],
		[UserInstruments.Viewer, "SATELLITE IMAGE VIEWER", "Image Viewer", 0.0],
		[UserInstruments.Flood, "FLOOD DETECTION", "Flood Detection Map", 4.0]]
	for w in ws:
		var x: float = w[3]
		RoomKit.solid(self, Vector3(2.6, 0.06, 1.0), Vector3(x, 0.74, -hz + 2.0), desk)
		for lx in [-1.15, 1.15]:
			RoomKit.solid(self, Vector3(0.06, 0.74, 0.9), Vector3(x + lx, 0.37, -hz + 2.0), desk)
		var sz := Vector2(1.75, 1.05)
		var my := 0.77 + 0.16 + sz.y / 2.0
		add_child(PartModels.box(Vector3(0.36, 0.02, 0.26), stand, Vector3(x, 0.78, -hz + 1.75)))
		add_child(PartModels.box(Vector3(0.07, 0.24, 0.05), stand, Vector3(x, 0.89, -hz + 1.7)))
		var d = screen(w[2], w[1], sz, Vector2i(860, 516), Vector3(x, my, -hz + 1.78), 0.0, null)
		d.set_display(w[0].new())
		add_child(PartModels.box(Vector3(0.6, 0.02, 0.2), PartModels.dark(), Vector3(x, 0.78, -hz + 2.25)))
	# Region selection for the image viewer
	button("◀ REGION", FUI.SKY, cycle_region.bind(-1), Vector3(-0.85, 0.8, -hz + 2.35))
	button("REGION ▶", FUI.SKY, cycle_region.bind(1), Vector3(0.85, 0.8, -hz + 2.35))
	MissionState.set_live("view_region", 0)
	# Analysis results on the right wall
	var res = screen("Analysis Results", "ANALYSIS RESULTS", Vector2(3.0, 1.85), Vector2i(900, 555), Vector3(hx - 0.12, 1.95, 0.0), -90.0, null)
	res.set_display(UserInstruments.Results.new())
	spawn = Vector3(0, 0.1, hz - 2.2)

# ======================================================================= actions (from the analysis screen)
## Show the next / previous farming region on the image viewer.
func cycle_region(step: int) -> void:
	var i := int(MissionState.live.get("view_region", 0))
	MissionState.set_live("view_region", posmod(i + step, FarmRegions.REGIONS.size()))

func toggle_mark(id: String) -> void:
	if delivered:
		return
	for p in plots:
		if p["id"] == id:
			p["marked"] = not p["marked"]
	MissionState.set_live("plots", plots)
	MissionState.set_live("flood_marked", marked_count())
	_panel.refresh()

func marked_count() -> int:
	return plots.filter(func(p): return p["marked"]).size()

func set_product(p: String) -> void:
	product = p
	_panel.refresh()
	get_tree().call_group("tutor", "on_event", "product_" + p)

func deliver() -> void:
	if delivered:
		return
	if product == "":
		get_tree().call_group("tutor", "on_event", "need_product")
		return
	delivered = true
	var flood_total := 0
	var found := 0
	var false_marks := 0
	var unseen_flood := 0
	var missed_seen := 0
	for p in plots:
		var f := FarmRegions.is_flood(p["state"])
		if f:
			flood_total += 1
			if not p["seen"]:
				unseen_flood += 1
			elif p["marked"]:
				found += 1
			else:
				missed_seen += 1
		elif p["marked"]:
			false_marks += 1
	var seen := plots.filter(func(p): return p["seen"]).size()
	var coverage := float(seen) / plots.size()
	var accuracy := clampf((found - 0.5 * false_marks) / maxf(flood_total, 1.0), 0.0, 1.0)
	var timely := clampf(1.0 - (delay_days - 1.0) / 6.0, 0.3, 1.0)
	var fit := 1.0 if product == "alert" or product == "map" else 0.6
	var impact := accuracy * timely * fit
	MissionState.set_live("impact", "HIGH" if impact > 0.6 else ("MEDIUM" if impact > 0.3 else "LOW"))
	MissionState.set_live("flood_found", str(found))
	MissionState.set_live("flood_total", str(flood_total))
	MissionState.set_live("unseen_flood", str(unseen_flood))
	get_tree().call_group("tutor", "on_event", "deliver_good" if impact > 0.6 else ("deliver_partial" if impact > 0.3 else "deliver_bad"))
	if unseen_flood > 0:
		get_tree().call_group("tutor", "on_event", "unseen_flood")
	await get_tree().create_timer(6.0).timeout
	finish_level({"products": [product], "coverage": coverage, "flood_total": flood_total, "flood_found": found,
		"false_marks": false_marks, "unseen_flood": unseen_flood, "missed_seen": missed_seen,
		"accuracy": accuracy, "delay_days": delay_days, "impact": impact})

# ======================================================================= small imagery monitors on the desks
class _MiniMap extends Control:
	var room
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if room == null:
			return
		var cw := size.x / 6.0
		var ch := size.y / 4.0
		for i in room.plots.size():
			var p: Dictionary = room.plots[i]
			var c: Color = FarmRegions.COLORS[p["state"]] if p["seen"] else FarmRegions.COLORS["none"]
			draw_rect(Rect2((i % 6) * cw + 2, (i / 6) * ch + 2, cw - 4, ch - 4), c)
			if p["marked"]:
				draw_rect(Rect2((i % 6) * cw + 2, (i / 6) * ch + 2, cw - 4, ch - 4), Color.WHITE, false, 3.0)

# ======================================================================= test helper
func test_views(d) -> void:
	player.teleport(Vector3(0, 0.1, 0.5), 0.0)
	player.cam.rotation.x = deg_to_rad(-6)
	await d._shot("user_1_window", 30)
	for p in plots:
		if p["seen"] and FarmRegions.is_flood(p["state"]):
			toggle_mark(p["id"])
	set_product("alert")
	get_tree().current_scene.find_children("*", "StaticBody3D", true, false).filter(func(n): return "screen_name" in n and n.screen_name == "Analysis Workstation")[0].interact()
	await d._shot("user_2_analysis", 20)
