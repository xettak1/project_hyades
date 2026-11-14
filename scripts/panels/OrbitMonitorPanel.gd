extends MarginContainer
## ORBIT & TRAJECTORY MONITOR - the Mission Control flight-ops screen.
## Rebuilt from the Google Stitch "Flight Ops - Orbit & Trajectory" design and driven by live data:
## the chosen orbit, the simulation (day, events, data) and the spacecraft design.
## Lab calls reset() at launch and refresh(sim) every frame during the mission.

const GroundTrackMap := preload("res://scripts/panels/GroundTrackMap.gd")
const EPOCH_UNIX := 1803945600   # 2027-03-01 00:00:00 UTC, launch day
const VISUAL_SECONDS_PER_ORBIT := 6.0

var sim = null
var vis_t := 0.0                 # orbital time shown (seconds)
var _acc := 0.0
var _v: Dictionary = {}          # labels updated live
var _map
var _pass_rows: Array = []
var _log_box: VBoxContainer
var _accent: Color
var _earth := true
var _R := 6371.0
var _mu := 398600.4

func _ready() -> void:
	add_theme_constant_override("margin_left", 12)
	add_theme_constant_override("margin_right", 12)
	add_theme_constant_override("margin_top", 10)
	add_theme_constant_override("margin_bottom", 8)
	var o := MissionState.orbit()
	_earth = o.get("body", "earth") == "earth"
	_R = 6371.0 if _earth else 1737.4
	_mu = 398600.4 if _earth else 4902.8
	_accent = MissionState.mission()["env"]["accent"]
	_build()
	_update()

func _draw() -> void:
	draw_rect(Rect2(-Vector2(18, 18), size + Vector2(36, 36)), FUI.BG)

# ======================================================================= build
func _build() -> void:
	var root := FUI.vb(8)
	add_child(root)
	root.add_child(_header())
	root.add_child(_ephemeris_strip())
	var main := FUI.hb(10)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.size_flags_stretch_ratio = 1.45
	root.add_child(main)
	main.add_child(_map_card())
	main.add_child(_params_card())
	var lower := FUI.hb(10)
	lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(lower)
	lower.add_child(_passes_card())
	lower.add_child(_solar_card())
	lower.add_child(_dv_card())
	var foot := FUI.hb(8)
	foot.add_child(FUI.dot(FUI.GREEN, 6))
	foot.add_child(FUI.t("Mission Control - Console 01  |  " + MissionState.mission()["env"]["title"].capitalize(), 11, FUI.DIM))
	foot.add_child(FUI.grow())
	_v["footer"] = FUI.t("", 11, FUI.FAINT, "mono")
	foot.add_child(_v["footer"])
	root.add_child(foot)

func _header() -> Control:
	var p := PanelContainer.new()
	var s := FUI.box(FUI.HEADER, FUI.BORDER, 10, 10)
	s.content_margin_left = 14
	s.content_margin_right = 14
	p.add_theme_stylebox_override("panel", s)
	var v := FUI.vb(8)
	p.add_child(v)
	var row := FUI.hb(14)
	v.add_child(row)
	# Identity
	var icon := PanelContainer.new()
	icon.add_theme_stylebox_override("panel", FUI.box(Color(_accent, 0.1), Color(_accent, 0.35), 8, 6))
	icon.add_child(FUI.t("SAT" if _earth else "LUN", 12, _accent, "mono_semi"))
	row.add_child(icon)
	var idv := FUI.vb(2)
	var idrow := FUI.hb(8)
	idrow.add_child(FUI.t("Flight Ops Control", 15, FUI.WHITE, "sans_semi"))
	idrow.add_child(FUI.t("/", 13, FUI.DIM, "mono"))
	idrow.add_child(FUI.t(MissionState.mission()["name"], 13, _accent, "sans_med"))
	idrow.add_child(FUI.chip(MissionState.mission()["spacecraft_class"], FUI.MUTED, true))
	idv.add_child(idrow)
	var sub := FUI.hb(8)
	_v["phase"] = FUI.t("", 12, FUI.MUTED)
	sub.add_child(_v["phase"])
	sub.add_child(FUI.t("•", 12, FUI.FAINT))
	_v["link_dot"] = FUI.dot(FUI.GREEN, 6)
	sub.add_child(_v["link_dot"])
	_v["link"] = FUI.t("", 12, FUI.GREEN)
	sub.add_child(_v["link"])
	idv.add_child(sub)
	row.add_child(idv)
	row.add_child(FUI.grow())
	# Timing block
	var tb := PanelContainer.new()
	var ts := FUI.box(Color("#0e172a"), FUI.BORDER, 8, 6)
	ts.content_margin_left = 14
	ts.content_margin_right = 14
	tb.add_theme_stylebox_override("panel", ts)
	var th := FUI.hb(16)
	tb.add_child(th)
	th.add_child(_stack("Mission elapsed time", "met", 16, FUI.WHITE, "mono_semi"))
	th.add_child(FUI.vline(30))
	th.add_child(_stack("UTC system time", "utc", 12, FUI.TEXT2, "mono_med"))
	th.add_child(FUI.vline(30))
	th.add_child(_stack("Next contact (AOS)", "aos", 12, FUI.GREEN, "mono_med"))
	row.add_child(tb)
	row.add_child(FUI.grow())
	# Badges
	_v["b_down"] = _badge(row, "DOWNLINK")
	_v["b_pwr"] = _badge(row, "POWER")
	# Tabs
	var tabs := FUI.hb(4)
	v.add_child(tabs)
	var first := true
	for name in ["Orbit & Trajectory", "Power & Thermal", "Attitude & Propulsion", "Payload & Instruments", "Events & Alarms"]:
		var tp := PanelContainer.new()
		var st := FUI.box(Color(_accent, 0.1) if first else Color(0, 0, 0, 0), Color(_accent, 0.25) if first else Color(0, 0, 0, 0), 6, 4)
		st.content_margin_left = 12
		st.content_margin_right = 12
		tp.add_theme_stylebox_override("panel", st)
		tp.add_child(FUI.t(name, 12, _accent if first else FUI.MUTED, "sans_med"))
		tabs.add_child(tp)
		first = false
	tabs.add_child(FUI.grow())
	_v["sys_dot"] = FUI.dot(FUI.GREEN, 6)
	tabs.add_child(_v["sys_dot"])
	_v["sys"] = FUI.t("", 12, FUI.MUTED, "mono")
	tabs.add_child(_v["sys"])
	return p

func _stack(caption: String, key: String, size: int, color: Color, kind: String) -> VBoxContainer:
	var v := FUI.vb(1)
	v.add_child(FUI.cap(caption, 10))
	_v[key] = FUI.t("", size, color, kind)
	v.add_child(_v[key])
	return v

func _badge(row: HBoxContainer, title: String) -> Label:
	var p := PanelContainer.new()
	var s := FUI.box(Color("#0e172a"), FUI.BORDER, 5, 4)
	s.content_margin_left = 10
	s.content_margin_right = 10
	p.add_theme_stylebox_override("panel", s)
	var h := FUI.hb(6)
	h.add_child(FUI.t(title, 11, FUI.DIM, "mono"))
	var l := FUI.t("", 12, FUI.TEXT, "mono_med")
	h.add_child(l)
	p.add_child(h)
	row.add_child(p)
	return l

func _ephemeris_strip() -> Control:
	var c := FUI.card(10)
	c.get_theme_stylebox("panel").content_margin_left = 18
	c.get_theme_stylebox("panel").content_margin_right = 18
	var h := FUI.hb(14)
	c.add_child(h)
	h.add_child(FUI.dot(FUI.GREEN, 9))
	h.add_child(FUI.t("Active Ephemeris", 14, FUI.WHITE, "sans_semi"))
	_v["eph_desc"] = FUI.t("", 12, FUI.MUTED, "mono")
	h.add_child(_v["eph_desc"])
	h.add_child(FUI.grow())
	var items := [["Latitude", "lat", FUI.WHITE], ["Longitude", "lon", FUI.WHITE], ["Altitude", "alt", FUI.GREEN], ["Velocity", "vel", FUI.SKY], ["Orbit period", "per", FUI.TEXT]]
	for i in items.size():
		if i > 0:
			h.add_child(FUI.vline(16))
		h.add_child(FUI.cap(items[i][0], 11, FUI.DIM))
		_v[items[i][1]] = FUI.t("", 13, items[i][2], "mono_med")
		h.add_child(_v[items[i][1]])
	return c

func _card_head(parent: VBoxContainer, title: String, subtitle: String, chip_key: String = "", chip_text: String = "", chip_color: Color = FUI.GREEN) -> void:
	var h := FUI.hb(8)
	var tv := FUI.vb(1)
	tv.add_child(FUI.t(title, 14, FUI.WHITE, "sans_semi"))
	tv.add_child(FUI.t(subtitle, 11, FUI.MUTED))
	h.add_child(tv)
	h.add_child(FUI.grow())
	if chip_key != "":
		var ch := FUI.chip(chip_text, chip_color, true)
		_v[chip_key] = ch.get_child(0)
		h.add_child(ch)
	parent.add_child(h)
	parent.add_child(FUI.hline())

func _map_card() -> Control:
	var c := FUI.card(0)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_stretch_ratio = 2.0
	var v := FUI.vb(0)
	c.add_child(v)
	var head := MarginContainer.new()
	for side in ["left", "right"]:
		head.add_theme_constant_override("margin_" + side, 16)
	head.add_theme_constant_override("margin_top", 10)
	head.add_theme_constant_override("margin_bottom", 8)
	var hv := FUI.vb(0)
	head.add_child(hv)
	var hh := FUI.hb(10)
	var tv := FUI.vb(1)
	tv.add_child(FUI.t("World Ground Track & Trajectory" if _earth else "Lunar Ground Track & Trajectory", 14, FUI.WHITE, "sans_semi"))
	tv.add_child(FUI.t("Equirectangular projection with live day/night terminator and ground station masks" if _earth else "Polar mapping orbit over the Moon, Earth tracking by the Deep Space Network", 11, FUI.MUTED))
	hh.add_child(tv)
	hh.add_child(FUI.grow())
	_v["rev"] = FUI.t("", 12, FUI.MUTED, "mono")
	hh.add_child(_v["rev"])
	hh.add_child(FUI.chip("GMAT" if FileAccess.file_exists("res://data/orbits/%s_path.csv" % MissionState.orbit_id) else "High Precision", FUI.GREEN))
	hv.add_child(hh)
	v.add_child(head)
	v.add_child(FUI.hline())
	var mapwrap := PanelContainer.new()
	mapwrap.add_theme_stylebox_override("panel", FUI.box(FUI.MAP_BG, Color(0, 0, 0, 0), 0, 8, 0))
	mapwrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map = GroundTrackMap.new()
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.clip_contents = true
	var o := MissionState.orbit()
	_map.body = o.get("body", "earth")
	_map.inc_deg = float(o["inclination"])
	_map.period_s = float(o["period_min"]) * 60.0
	_map.accent = _accent
	_map.sc_label = MissionState.mission()["spacecraft_class"]
	_map.sc_mode = "Nadir pointing"
	_map.footprint_deg = 22.0 if float(o["altitude_km"]) >= 600.0 else 19.0
	_map.stations = _stations()
	mapwrap.add_child(_map)
	v.add_child(mapwrap)
	v.add_child(FUI.hline())
	var foot := PanelContainer.new()
	var fs := FUI.box(Color("#0c1322"), Color(0, 0, 0, 0), 0, 6, 0)
	fs.content_margin_left = 16
	fs.content_margin_right = 16
	foot.add_theme_stylebox_override("panel", fs)
	var fh := FUI.hb(18)
	fh.add_child(_kv("Projection", "WGS-84 Plate Carree" if _earth else "IAU Moon 2015"))
	_v["node"] = _kv("Ascending node", "")
	fh.add_child(_v["node"])
	fh.add_child(FUI.grow())
	fh.add_child(_kv("Propagator", "GMAT RK89" if FileAccess.file_exists("res://data/orbits/%s_path.csv" % MissionState.orbit_id) else "Two-body + J2"))
	fh.add_child(_kv("Step", "1.0 s"))
	foot.add_child(fh)
	v.add_child(foot)
	return c

func _kv(k: String, value: String) -> HBoxContainer:
	var h := FUI.hb(5)
	h.add_child(FUI.t(k + ":", 11, FUI.MUTED))
	var l := FUI.t(value, 11, FUI.TEXT2, "mono")
	l.name = "V"
	h.add_child(l)
	return h

func _params_card() -> Control:
	var c := FUI.card(14)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := FUI.vb(0)
	c.add_child(v)
	_card_head(v, "Orbital Parameters", "Keplerian elements derived from GPS epoch" if _earth else "Elements from DSN tracking", "valid", "Valid", FUI.GREEN)
	var rows := [["Semi-major axis (a)", "a", FUI.WHITE], ["Eccentricity (e)", "e", FUI.GREEN], ["Inclination (i)", "i", FUI.WHITE],
		["RAAN (Ω)", "raan", FUI.WHITE], ["Perigee / Apogee", "pa", FUI.TEXT], ["True anomaly (ν)", "nu", FUI.SKY]]
	for r in rows:
		var h := FUI.hb(6)
		h.add_child(FUI.t(r[0], 12, FUI.TEXT, "sans_med"))
		h.add_child(FUI.grow())
		_v[r[1]] = FUI.t("", 13, r[2], "mono_semi")
		h.add_child(_v[r[1]])
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_top", 5)
		m.add_theme_constant_override("margin_bottom", 5)
		m.add_child(h)
		v.add_child(m)
		v.add_child(_faint_line())
	var svh := FUI.hb(6)
	var svm := MarginContainer.new()
	svm.add_theme_constant_override("margin_top", 8)
	svm.add_theme_constant_override("margin_bottom", 4)
	svm.add_child(svh)
	svh.add_child(FUI.t("ECI J2000 state vector" if _earth else "Selenocentric state vector", 12, FUI.MUTED, "sans_med"))
	svh.add_child(FUI.grow())
	svh.add_child(FUI.t("12 GNSS SV locked" if _earth else "DSN 2-way Doppler", 11, FUI.SKY, "mono"))
	v.add_child(svm)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for k in [["X position", "x", FUI.WHITE], ["Y position", "y", FUI.WHITE], ["Z position", "z", FUI.WHITE],
			["Vx (km/s)", "vx", FUI.GREEN], ["Vy (km/s)", "vy", FUI.GREEN], ["Vz (km/s)", "vz", FUI.GREEN]]:
		grid.add_child(_cell(k[0], k[1], k[2]))
	v.add_child(grid)
	return c

func _faint_line() -> ColorRect:
	var l := FUI.hline()
	l.color = Color(FUI.BORDER, 0.5)
	return l

func _cell(caption: String, key: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", FUI.box(FUI.INSET, FUI.BORDER, 5, 5))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := FUI.vb(0)
	var c := FUI.t(caption, 10, FUI.DIM)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(c)
	_v[key] = FUI.t("", 12, color, "mono_med")
	_v[key].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_v[key])
	p.add_child(v)
	return p

func _passes_card() -> Control:
	var c := FUI.card(14)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := FUI.vb(6)
	c.add_child(v)
	_card_head(v, "Ground Station Passes", "Upcoming pass schedule & link margins", "track", "Active tracking", FUI.SKY)
	for i in 3:
		var p := PanelContainer.new()
		var rv := FUI.vb(2)
		p.add_child(rv)
		var top := FUI.hb(6)
		var name := FUI.t("", 12, FUI.WHITE, "sans_semi")
		top.add_child(name)
		top.add_child(FUI.grow())
		var when := FUI.t("", 11, FUI.GREEN, "mono_med")
		top.add_child(when)
		rv.add_child(top)
		var det := FUI.t("", 11, FUI.MUTED, "mono")
		rv.add_child(det)
		v.add_child(p)
		_pass_rows.append({"panel": p, "name": name, "when": when, "det": det})
	v.add_child(FUI.grow())
	var lh := FUI.hb(6)
	lh.add_child(FUI.t("Downlink capacity vs data made", 11, FUI.MUTED))
	lh.add_child(FUI.grow())
	_v["link_margin"] = FUI.t("", 11, FUI.GREEN, "mono_med")
	lh.add_child(_v["link_margin"])
	v.add_child(lh)
	_v["link_bar"] = FUI.bar(0.5, FUI.GREEN, 6)
	v.add_child(_v["link_bar"])
	return c

func _solar_card() -> Control:
	var c := FUI.card(14)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := FUI.vb(7)
	c.add_child(v)
	_card_head(v, "Solar Angle & Illumination", "Sun tracking and orbital eclipse cycle", "sun_chip", "Sun-locked", FUI.AMBER)
	var ban := PanelContainer.new()
	ban.add_theme_stylebox_override("panel", FUI.box(FUI.INSET, FUI.BORDER, 8, 10))
	var bh := FUI.hb(10)
	ban.add_child(bh)
	_v["sun_icon"] = FUI.t("☀", 20, FUI.AMBER)
	bh.add_child(_v["sun_icon"])
	var bv := FUI.vb(0)
	_v["sun_state"] = FUI.t("", 13, FUI.WHITE, "sans_semi")
	bv.add_child(_v["sun_state"])
	_v["beta"] = FUI.t("", 11, FUI.MUTED, "mono")
	bv.add_child(_v["beta"])
	bh.add_child(bv)
	bh.add_child(FUI.grow())
	var tv := FUI.vb(0)
	_v["sun_next_cap"] = FUI.cap("Penumbra in", 10, FUI.DIM)
	tv.add_child(_v["sun_next_cap"])
	_v["sun_next"] = FUI.t("", 13, FUI.TEXT2, "mono_semi")
	tv.add_child(_v["sun_next"])
	bh.add_child(tv)
	v.add_child(ban)
	var bat := FUI.hb(6)
	bat.add_child(FUI.t("Battery state of charge", 12, FUI.TEXT, "sans_med"))
	bat.add_child(FUI.grow())
	_v["soc"] = FUI.t("", 12, FUI.GREEN, "mono_med")
	bat.add_child(_v["soc"])
	v.add_child(bat)
	_v["soc_bar"] = FUI.bar(1.0, FUI.GREEN, 6)
	v.add_child(_v["soc_bar"])
	v.add_child(FUI.grow())
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_child(_cell("Solar array (W)", "p_in", FUI.AMBER))
	grid.add_child(_cell("Load (W)", "p_out", FUI.SKY))
	grid.add_child(_cell("Eclipse/orbit", "ecl", FUI.TEXT2))
	v.add_child(grid)
	return c

func _dv_card() -> Control:
	var c := FUI.card(14)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := FUI.vb(7)
	c.add_child(v)
	_card_head(v, "Delta-V Budget & Log", "Propellant reserve and flight dynamics events", "dv_chip", "", FUI.GREEN)
	var bx := PanelContainer.new()
	bx.add_theme_stylebox_override("panel", FUI.box(FUI.INSET, FUI.BORDER, 8, 10))
	var bv := FUI.vb(5)
	bx.add_child(bv)
	var h := FUI.hb(6)
	_v["dv_label"] = FUI.t("Remaining ΔV", 12, FUI.TEXT)
	h.add_child(_v["dv_label"])
	h.add_child(FUI.grow())
	_v["dv"] = FUI.t("", 12, FUI.GREEN, "mono_med")
	h.add_child(_v["dv"])
	bv.add_child(h)
	_v["dv_bar"] = FUI.bar(1.0, FUI.GREEN, 6)
	bv.add_child(_v["dv_bar"])
	_v["dv_note"] = FUI.t("", 11, FUI.MUTED, "mono")
	bv.add_child(_v["dv_note"])
	v.add_child(bx)
	v.add_child(FUI.t("Flight dynamics stream", 12, FUI.TEXT, "sans_med"))
	_log_box = FUI.vb(2)
	_log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_log_box)
	var bh := FUI.hb(6)
	var b1 := FUI.button("Speed 1x")
	b1.pressed.connect(func(): get_tree().call_group("lab", "request_speed", 1.0))
	var b2 := FUI.button("Speed 10x")
	b2.pressed.connect(func(): get_tree().call_group("lab", "request_speed", 10.0))
	var b3 := FUI.button("Skip to end", _accent)
	b3.pressed.connect(func(): get_tree().call_group("lab", "request_skip"))
	bh.add_child(b1)
	bh.add_child(b2)
	bh.add_child(b3)
	v.add_child(bh)
	return c

# ======================================================================= data
func _stations() -> Array:
	if not _earth:
		return []
	return [{"name": "Svalbard (SG3)", "lat": 78.2, "lon": 15.4, "dish": "11 m"},
		{"name": "Madrid (MDS-1)", "lat": 40.4, "lon": -4.2, "dish": "34 m"},
		{"name": "Goldstone (GDS)", "lat": 35.4, "lon": -116.9, "dish": "34 m"}]

func reset() -> void:
	sim = null
	vis_t = 0.0
	for c in _log_box.get_children():
		c.queue_free()

func refresh(s) -> void:
	sim = s

func _process(delta: float) -> void:
	var period: float = float(MissionState.orbit()["period_min"]) * 60.0
	var running: bool = sim != null and not sim.done
	vis_t += delta * period / VISUAL_SECONDS_PER_ORBIT * (1.0 if running or sim == null else 0.0)
	_map.t = vis_t
	_acc += delta
	if _acc > 0.2:
		_acc = 0.0
		_update()

func _fmt_dur(s: float) -> String:
	s = maxf(s, 0.0)
	var m := int(s / 60.0)
	if m >= 60:
		return "%dh %02dm" % [m / 60, m % 60]
	return "%dm %02ds" % [m, int(s) % 60]

func _comma(v: float, dec: int = 3) -> String:
	var neg := v < 0.0
	var s := ("%." + str(dec) + "f") % absf(v)
	var parts := s.split(".")
	var ip: String = parts[0]
	var out := ""
	while ip.length() > 3:
		out = "," + ip.substr(ip.length() - 3) + out
		ip = ip.substr(0, ip.length() - 3)
	out = ip + out
	if parts.size() > 1:
		out += "." + parts[1]
	return ("-" if neg else "") + out

func _update() -> void:
	var o := MissionState.orbit()
	var c := MissionState.compute()
	var x: Dictionary = c["extra"]
	var period: float = float(o["period_min"]) * 60.0
	var alt: float = float(o["altitude_km"])
	var a: float = _R + alt
	var day: int = 0
	var phase := "Phase D - Integration & test (awaiting launch)"
	if sim != null:
		day = sim.day
		if sim.done:
			phase = "Phase F - Mission complete"
		elif sim.in_cruise():
			phase = "Phase E0 - Lunar transfer cruise"
		else:
			phase = "Phase E1 - Science acquisition"
	var secs_today := fposmod(vis_t, 86400.0)
	var met_s: float = day * 86400.0 + secs_today
	_v["phase"].text = phase
	_v["met"].text = ("+%03d : %02d : %02d : %02d" % [day, int(secs_today / 3600.0), int(fposmod(secs_today, 3600.0) / 60.0), int(fposmod(secs_today, 60.0))]) if sim != null else "T- 00 : 00 : 00"
	_v["utc"].text = Time.get_datetime_string_from_unix_time(EPOCH_UNIX + int(met_s), true) + "Z"

	# Position and velocity
	var sp: Vector2 = _map.subpoint(vis_t)
	_v["lat"].text = "%.4f° %s" % [absf(sp.x), "N" if sp.x >= 0.0 else "S"]
	_v["lon"].text = "%.4f° %s" % [absf(sp.y), "E" if sp.y >= 0.0 else "W"]
	_v["alt"].text = "%.2f km" % alt
	var vel: float = sqrt(_mu / a)
	_v["vel"].text = "%.3f km/s" % vel
	_v["per"].text = "%.2f min" % (period / 60.0)
	_v["eph_desc"].text = "%s  •  Inclination %.1f°" % [o["name"], o["inclination"]]
	_v["rev"].text = "Revolution #%d" % (int(met_s / period) + 1)
	_v["node"].get_node("V").text = "%s (%.1f° %s)" % [Time.get_time_string_from_unix_time(EPOCH_UNIX + int(met_s - fposmod(met_s, period))), absf(_map.subpoint(vis_t - fposmod(vis_t, period)).y), "E" if _map.subpoint(vis_t - fposmod(vis_t, period)).y >= 0.0 else "W"]

	# Keplerian elements and state vector
	var e := 0.00112
	var inc := deg_to_rad(float(o["inclination"]))
	var precess := 0.9856 if absf(float(o["inclination"]) - 98.0) < 1.5 else (-5.0 if _earth else 0.0)
	var raan := deg_to_rad(fposmod(142.2 + precess * met_s / 86400.0, 360.0))
	var nu := fposmod(rad_to_deg(TAU * vis_t / period), 360.0)
	_v["a"].text = _comma(a) + " km"
	_v["e"].text = "%.6f  near-circular" % e
	_v["i"].text = "%.4f°" % o["inclination"]
	_v["raan"].text = "%.4f°" % rad_to_deg(raan)
	_v["pa"].text = "%.1f / %.1f km" % [alt - a * e, alt + a * e]
	_v["nu"].text = "%.4f°" % nu
	var th := deg_to_rad(nu)
	var r := Vector3(a * (cos(raan) * cos(th) - sin(raan) * sin(th) * cos(inc)), a * (sin(raan) * cos(th) + cos(raan) * sin(th) * cos(inc)), a * sin(th) * sin(inc))
	var vv := Vector3(vel * (-cos(raan) * sin(th) - sin(raan) * cos(th) * cos(inc)), vel * (-sin(raan) * sin(th) + cos(raan) * cos(th) * cos(inc)), vel * cos(th) * sin(inc))
	_v["x"].text = "%+.1f" % r.x
	_v["y"].text = "%+.1f" % r.y
	_v["z"].text = "%+.1f" % r.z
	_v["vx"].text = "%+.3f" % vv.x
	_v["vy"].text = "%+.3f" % vv.y
	_v["vz"].text = "%+.3f" % vv.z

	# Contacts
	var contact_now := false
	var next_aos := INF
	var next_name := ""
	if _earth:
		var rows: Array = []
		for st in _map.stations:
			var info := _scan_pass(st, period)
			st["active"] = info["now"]
			st["status"] = "IN CONTACT" if info["now"] else ("Out of reach" if info.get("never", false) else "AOS in " + _fmt_dur(info["aos"] - vis_t))
			rows.append([info, st])
			if info["now"]:
				contact_now = true
			elif info["aos"] < next_aos:
				next_aos = info["aos"]
				next_name = st["name"].split(" ")[0]
		rows.sort_custom(func(p, q): return (0.0 if p[0]["now"] else p[0]["aos"]) < (0.0 if q[0]["now"] else q[0]["aos"]))
		for i in 3:
			var info: Dictionary = rows[i][0]
			var st: Dictionary = rows[i][1]
			var row: Dictionary = _pass_rows[i]
			row["name"].text = "%s %s dish" % [st["name"], st["dish"]]
			if info.get("never", false):
				row["when"].text = "Never in view"
				row["when"].add_theme_color_override("font_color", FUI.RED)
				row["det"].text = "Orbit inclination %.1f° never reaches latitude %.1f°" % [o["inclination"], st["lat"]]
			else:
				row["when"].text = ("IN CONTACT · LOS in " + _fmt_dur(info["los"] - vis_t)) if info["now"] else ("Next pass in " + _fmt_dur(info["aos"] - vis_t))
				row["when"].add_theme_color_override("font_color", FUI.GREEN if (info["now"] or i == 0) else FUI.DIM)
				row["det"].text = "AOS %s   Max El %.1f°   Dur %s" % [Time.get_time_string_from_unix_time(EPOCH_UNIX + int(day * 86400.0 + fposmod(info["aos"], 86400.0))), info["el"], _fmt_dur(info["dur"])]
			var hl: bool = i == 0
			row["panel"].add_theme_stylebox_override("panel", FUI.box(FUI.INSET if hl else Color(FUI.INSET, 0.6), Color(FUI.GREEN, 0.3) if hl else FUI.BORDER, 8, 8))
	else:
		# Lunar orbit: Earth is hidden behind the Moon for part of each orbit
		var ph := fposmod(vis_t / period, 1.0)
		contact_now = ph < 0.62
		next_aos = vis_t + (1.0 - ph) * period if not contact_now else vis_t
		next_name = "DSN"
		var dsn := [["Goldstone (DSS-14)", "70 m"], ["Madrid (DSS-63)", "70 m"], ["Canberra (DSS-43)", "70 m"]]
		var who := int(fposmod(met_s / 28800.0, 3.0))
		for i in 3:
			var row: Dictionary = _pass_rows[i]
			var idx := (who + i) % 3
			row["name"].text = "%s %s dish" % dsn[idx]
			if i == 0:
				row["when"].text = ("TRACKING · LOS in " + _fmt_dur((0.62 - ph) * period)) if contact_now else ("Behind Moon · AOS in " + _fmt_dur((1.0 - ph) * period))
			else:
				row["when"].text = "Handover in " + _fmt_dur((float(i) - fposmod(met_s / 28800.0, 1.0)) * 28800.0)
			row["when"].add_theme_color_override("font_color", FUI.GREEN if i == 0 else FUI.DIM)
			row["det"].text = "Range 384,400 km   Light time 1.28 s   X/Ka band"
			row["panel"].add_theme_stylebox_override("panel", FUI.box(FUI.INSET if i == 0 else Color(FUI.INSET, 0.6), Color(FUI.GREEN, 0.3) if i == 0 else FUI.BORDER, 8, 8))
	_v["link"].text = ("Carrier locked (frame sync)" if contact_now else "Loss of signal - recording onboard") if sim != null else "Ground checkout - umbilical"
	_v["link"].add_theme_color_override("font_color", FUI.GREEN if contact_now or sim == null else FUI.AMBER)
	_v["link_dot"].color = FUI.GREEN if contact_now or sim == null else FUI.AMBER
	_v["aos"].text = "IN CONTACT" if contact_now else ("No station in reach" if next_aos == INF else "%s in %s" % [next_name, _fmt_dur(next_aos - vis_t)])
	var mbps: float = float(MissionState.part_of("comms").get("mbps", 0.0))
	_v["b_down"].text = ("%.2f Mbps" % mbps) if contact_now and sim != null else "LOS"
	var dl: float = x["downlink"]
	var need: float = maxf(x["data_gen"], 0.001)
	_v["link_margin"].text = "%.2f / %.1f GB/day" % [dl, need]
	var ratio: float = dl / need
	var lc: Color = FUI.GREEN if ratio >= 1.0 else (FUI.AMBER if ratio >= 0.5 else FUI.RED)
	_v["link_margin"].add_theme_color_override("font_color", lc)
	_v["link_bar"].value = clampf(ratio, 0.0, 1.0)
	(_v["link_bar"].get_theme_stylebox("fill") as StyleBoxFlat).bg_color = lc

	# Sun / eclipse
	var ecl_frac: float = float(o["eclipse_min"]) / float(o["period_min"])
	var ph2 := fposmod(vis_t / period, 1.0)
	var e0 := 0.5 - ecl_frac / 2.0
	var e1 := 0.5 + ecl_frac / 2.0
	var in_ecl := ph2 >= e0 and ph2 < e1
	var to_next := ((e1 - ph2) if in_ecl else fposmod(e0 - ph2, 1.0)) * period
	_v["sun_state"].text = "Eclipse (umbra)" if in_ecl else "Full daylight phase"
	_v["sun_icon"].text = "◐" if in_ecl else "☀"
	_v["sun_icon"].add_theme_color_override("font_color", FUI.MUTED if in_ecl else FUI.AMBER)
	_v["sun_next_cap"].text = "SUNLIGHT IN" if in_ecl else "PENUMBRA IN"
	_v["sun_next"].text = _fmt_dur(to_next) if ecl_frac > 0.001 else "--"
	var beta := 75.0 if float(o["eclipse_min"]) < 10.0 else (22.4 if absf(float(o["inclination"]) - 98.0) < 1.5 else 35.0)
	_v["beta"].text = "Beta angle (β): %+.2f°" % beta
	_v["sun_chip"].text = "Eclipse" if in_ecl else "Sun-locked"
	var depth: float = 0.0
	var energy: float = float(MissionState.part_of("battery").get("energy", 1.0))
	if in_ecl:
		depth = (ph2 - e0) / maxf(ecl_frac, 0.001) * x["need_wh"] / energy
	else:
		var since := fposmod(ph2 - e1, 1.0) / maxf(1.0 - ecl_frac, 0.001)
		depth = maxf(0.0, x["need_wh"] / energy * (1.0 - since / 0.35))
	var soc := clampf(1.0 - depth, 0.0, 1.0)
	_v["soc"].text = "%.0f %%" % (soc * 100.0)
	var sc: Color = FUI.GREEN if soc > 0.6 else (FUI.AMBER if soc > 0.3 else FUI.RED)
	_v["soc"].add_theme_color_override("font_color", sc)
	_v["soc_bar"].value = soc
	(_v["soc_bar"].get_theme_stylebox("fill") as StyleBoxFlat).bg_color = sc
	var peak: float = float(MissionState.part_of("solar").get("power_gen", 0.0))
	_v["p_in"].text = "%.1f" % (0.0 if in_ecl else peak)
	_v["p_out"].text = "%.1f" % x["load_w"]
	_v["ecl"].text = "%.0f min" % o["eclipse_min"]
	var margin_w: float = x["gen_avg"] - x["load_w"]
	_v["b_pwr"].text = "%+.1f W" % margin_w
	_v["b_pwr"].add_theme_color_override("font_color", FUI.GREEN if margin_w >= 0.0 else FUI.RED)

	# Delta-V / fuel
	var life_days: float = maxf(float(x["life_cap"]) * 365.0, 1.0)
	var used_frac: float = 0.0
	if sim != null:
		used_frac = clampf(float(sim.day - sim.cruise_days) / life_days, 0.0, 1.0)
	if MissionState.has_fuel_system():
		var left_kg: float = maxf(x["fuel_left"], 0.0) * (1.0 - used_frac) if sim != null and not sim.in_cruise() else x["fuel"]
		var isp: float = float(MissionState.part_of("propulsion").get("isp", 220.0))
		var dry: float = x["dry_mass"]
		var dv_left: float = isp * GameData.G0 * log((dry + left_kg) / dry)
		var dv_full: float = isp * GameData.G0 * log((dry + x["fuel"]) / dry)
		_v["dv_label"].text = "Remaining ΔV (hydrazine)"
		_v["dv"].text = "%.0f m/s / %.0f m/s" % [dv_left, dv_full]
		_v["dv_bar"].value = dv_left / maxf(dv_full, 1.0)
		_v["dv_note"].text = "Fuel %.0f kg   Braking burn %.0f m/s   Station-keeping %.0f m/s/yr" % [left_kg, o["delta_v_insert"], o["delta_v_per_year"]]
		_v["dv_chip"].text = "%.1f%% remaining" % (100.0 * dv_left / maxf(dv_full, 1.0))
	elif int(MissionState.part_of("propulsion").get("life_bonus", 0)) > 0:
		var full := 25.0 * float(MissionState.part_of("propulsion").get("life_bonus", 0))
		var left := full * (1.0 - used_frac)
		_v["dv_label"].text = "Remaining ΔV (drag make-up)"
		_v["dv"].text = "%.1f m/s / %.1f m/s" % [left, full]
		_v["dv_bar"].value = left / full
		_v["dv_note"].text = "Orbit life ~%.1f years with fuel" % x["life_cap"]
		_v["dv_chip"].text = "%.1f%% remaining" % (100.0 * left / full)
	else:
		_v["dv_label"].text = "No propulsion: orbit decaying"
		_v["dv"].text = "0 m/s"
		_v["dv_bar"].value = 1.0 - used_frac
		_v["dv_note"].text = "Altitude lost so far ~%.1f km   Re-entry in ~%.1f years" % [used_frac * 120.0, maxf(0.0, x["life_cap"] * (1.0 - used_frac))]
		_v["dv_chip"].text = "Drag only"
	var g := MissionState.gate()
	var cautions: int = g["warn"].size() + g["hard"].size()
	_v["sys"].text = "All systems nominal" if cautions == 0 else "%d caution(s) - see Advisors" % cautions
	_v["sys_dot"].color = FUI.GREEN if cautions == 0 else FUI.AMBER
	_v["footer"].text = "Build 4.18.2  •  Telemetry source: %s  •  S-band uplink %s" % ["SIM" if sim != null else "TEST", "active" if contact_now else "idle"]
	_update_log(met_s)

func _update_log(met_s: float) -> void:
	var lines: Array = []
	if sim != null:
		for i in range(sim.events.size() - 1, -1, -1):
			var ev: Dictionary = sim.events[i]
			lines.append([ev["day"], "EVT", ev["title"] + ".", FUI.AMBER])
			if lines.size() >= 2:
				break
	var routine := [["OBC", "Star tracker lock established.", FUI.GREEN], ["GNSS", "State vector corrected onboard.", FUI.SKY],
		["COMM", "Radio configured for next ground pass.", FUI.AMBER], ["PL", "Imaging sequence uploaded.", FUI.GREEN]]
	var n := int(met_s / 900.0)
	while lines.size() < 4:
		var rr: Array = routine[n % routine.size()]
		lines.append([-1, rr[0], rr[1], rr[2]])
		n -= 1
	for c in _log_box.get_children():
		c.queue_free()
	var k := 0
	for ln in lines:
		var h := FUI.hb(8)
		var stamp := ("Day %d" % ln[0]) if ln[0] >= 0 else Time.get_time_string_from_unix_time(EPOCH_UNIX + int(met_s) - k * 900)
		h.add_child(FUI.t(stamp, 11, FUI.DIM, "mono"))
		h.add_child(FUI.t(ln[1], 11, ln[3], "mono_semi"))
		var msg := FUI.t(ln[2], 11, FUI.TEXT, "mono")
		msg.clip_text = true
		msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(msg)
		_log_box.add_child(h)
		k += 1

## Next pass of a station: scans ahead for when the ground track enters the station circle.
func _scan_pass(st: Dictionary, period: float) -> Dictionary:
	var fp: float = _map.footprint_deg
	var step := 30.0
	var tt := vis_t
	var inside := _ang(_map.subpoint(tt), st) < fp
	var aos := tt
	if inside:
		while _ang(_map.subpoint(aos - step), st) < fp and aos > vis_t - period:
			aos -= step
	else:
		var limit := vis_t + 86400.0 * 1.5
		while tt < limit and _ang(_map.subpoint(tt), st) >= fp:
			tt += step
		aos = tt
	if not inside and tt >= vis_t + 86400.0 * 1.5:
		return {"now": false, "aos": INF, "los": INF, "dur": 0.0, "el": 0.0, "never": true}
	var los := aos
	var dmin := 999.0
	while _ang(_map.subpoint(los), st) < fp and los < aos + period:
		dmin = minf(dmin, _ang(_map.subpoint(los), st))
		los += step
	return {"now": inside, "aos": aos, "los": los, "dur": los - aos, "el": clampf(90.0 * (1.0 - dmin / fp), 5.0, 89.0)}

func _ang(sp: Vector2, st: Dictionary) -> float:
	var la1 := deg_to_rad(sp.x)
	var la2 := deg_to_rad(float(st["lat"]))
	var dl := deg_to_rad(sp.y - float(st["lon"]))
	return rad_to_deg(acos(clampf(sin(la1) * sin(la2) + cos(la1) * cos(la2) * cos(dl), -1.0, 1.0)))
