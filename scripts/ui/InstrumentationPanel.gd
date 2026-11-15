extends CanvasLayer
## INSTRUMENTATION PANEL, fixed on the LEFT in every level. One reusable component; each level shows
## only its own resources:
##   L1 LAUNCH CONTROL · L2 SPACECRAFT STATUS · L3 GROUND CONTROL · L4 AGRICULTURAL ANALYSIS
## Reads everything from MissionState (the mission manager) and refreshes on its signals,
## so it always matches the Decision card and the Mission Tutor. Press I (or click the title) to collapse.

const Row := preload("res://scripts/ui/ResourceIndicator.gd")
const WIDTH := 296.0

var level := "launch"
var _panel: PanelContainer
var _title: Label
var _sub: Label
var _body: VBoxContainer
var _rows: Dictionary = {}
var _extra: Control
var _collapsed := false
var _t := 0.0

const TITLES := {"launch": "LAUNCH CONTROL", "space": "SPACECRAFT STATUS", "ground": "GROUND CONTROL", "user": "AGRICULTURAL ANALYSIS"}

func _ready() -> void:
	layer = 4
	add_to_group("instrumentation")
	level = LevelFlow.current_id() if LevelFlow.index >= 0 else "launch"
	_panel = PanelContainer.new()
	var s := FUI.box(Color(0.025, 0.05, 0.1, 0.9), Color(FUI.SKY, 0.35), 10, 12)
	s.border_width_left = 3
	_panel.add_theme_stylebox_override("panel", s)
	_panel.position = Vector2(12, 56)
	_panel.custom_minimum_size = Vector2(WIDTH, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_panel)
	var v := FUI.vb(7)
	_panel.add_child(v)
	var head := Button.new()
	head.flat = true
	head.focus_mode = Control.FOCUS_NONE
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.pressed.connect(toggle)
	var hv := FUI.hb(6)
	hv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = FUI.t(TITLES.get(level, ""), 16, FUI.SKY, "sans_semi")
	hv.add_child(_title)
	hv.add_child(FUI.grow())
	_sub = FUI.t("I ▾", 10, FUI.DIM, "mono")
	hv.add_child(_sub)
	head.add_child(hv)
	hv.set_anchors_preset(Control.PRESET_FULL_RECT)
	head.custom_minimum_size = Vector2(0, 20)
	v.add_child(head)
	_body = FUI.vb(7)
	v.add_child(_body)
	_build_rows()
	MissionState.design_changed.connect(refresh)
	MissionState.state_changed.connect(refresh)
	refresh()

func _row(id: String, icon: String, label: String) -> void:
	var r := Row.new(icon, label)
	_body.add_child(r)
	_rows[id] = r

func _build_rows() -> void:
	match level:
		"launch":
			_row("left", "money", "Budget left")
			_row("mass", "mass", "Spacecraft mass")
			_row("ready", "ready", "Launch readiness")
		"space":
			_row("battery", "battery", "Battery (lowest in eclipse)")
			_row("gen", "sun", "Power generation (avg)")
			_row("use", "bolt", "Power consumption")
			_row("storage", "storage", "Free onboard storage")
			_row("instrument", "camera", "Instrument")
			_row("progress", "progress", "Observation progress")
			_extra = _Subsystems.new()
			_extra.custom_minimum_size = Vector2(0, 34)
			_body.add_child(_extra)
		"ground":
			_row("signal", "signal", "Signal")
			_row("window", "clock", "Contact window")
			_row("onboard", "storage", "Onboard data")
			_row("capacity", "down", "Transmission capacity")
			_row("received", "down", "Received")
			_row("left", "missing", "Remaining in space")
			_extra = _Transfer.new()
			_extra.custom_minimum_size = Vector2(0, 58)
			_body.add_child(_extra)
		"user":
			_row("images", "camera", "Images received")
			_row("covered", "map", "Regions covered")
			_row("flood", "flood", "Flooded plots detected")
			_row("crops", "leaf", "Crop-health observations")
			_row("missing", "missing", "Missing data")
			_row("confidence", "ready", "Confidence in analysis")
			_extra = _FarmMap.new()
			_extra.custom_minimum_size = Vector2(0, 150)
			_body.add_child(_extra)

func toggle() -> void:
	_collapsed = not _collapsed
	_body.visible = not _collapsed
	_sub.text = "I ▸" if _collapsed else "I ▾"
	_panel.reset_size()

func _put(id: String, text: String, status := -1, frac := -1.0) -> void:
	if _rows.has(id):
		_rows[id].set_value(text, status, frac)

func _lv(rows: Array, id: String) -> int:
	for r in rows:
		if r["id"] == id:
			return r["level"]
	return -1

func refresh() -> void:
	if not is_inside_tree():
		return
	var m := MissionState.mission()
	var x: Dictionary = MissionState.compute()["extra"]
	var a := MissionState.assess(x)
	var live: Dictionary = MissionState.live
	var res: Dictionary = MissionState.level_results
	match level:
		"launch":
			var budget := float(m["budget"])
			var left := budget - float(x["cost"])
			_put("left", "$%.2fM / $%.0fM" % [left, budget], _lv(a, "budget_used"), left / budget)
			_put("mass", "%.1f / %s kg" % [x["mass"], str(m["mass_limit"])], _lv(a, "mass_used"), x["mass"] / float(m["mass_limit"]))
			var g := MissionState.gate()
			var near := maxi(maxi(_lv(a, "mass_used"), _lv(a, "budget_used")), _lv(a, "rocket_used"))
			if not MissionState.missing_parts().is_empty() or MissionState.rocket_id == "":
				_put("ready", "NOT READY", 1)
			elif not g["hard"].is_empty():
				_put("ready", "INVALID", 3)
			elif near >= 1:
				_put("ready", "NEAR LIMIT", 1)
			elif not g["warn"].is_empty():
				_put("ready", "READY · %d ⚠" % g["warn"].size(), 1)
			else:
				_put("ready", "READY", 0)
		"space":
			var dod: float = x["need_wh"] / maxf(float(MissionState.part_of("battery").get("energy", 1.0)), 0.001)
			var lowest := clampf(1.0 - dod, 0.0, 1.0)
			_put("battery", "%d%%" % int(100 * live.get("battery_frac", lowest)), _lv(a, "battery_dod"), live.get("battery_frac", lowest))
			_put("gen", "%.1f W" % x["gen_avg"], -1)
			_put("use", "%.1f W" % x["load_w"], _lv(a, "power_margin"), x["load_w"] / maxf(x["gen_avg"], 0.01))
			var stored: float = live.get("stored_gb", 0.0)
			var cap2: float = x["storage"]
			_put("storage", "%.0f / %.0f GB" % [cap2 - stored, cap2], 0 if stored < cap2 * 0.8 else (1 if stored < cap2 else 2), (cap2 - stored) / maxf(cap2, 0.001))
			var pname: String = MissionState.part_of("payload").get("name", "-").split(",")[0].split(" (")[0].split(" ")[0]
			_put("instrument", "%s · %s" % [pname, live.get("instrument_state", "STANDBY")], 0 if live.get("instrument_state", "") == "ACTIVE" else -1)
			var target: float = live.get("target_gb", x["useful_per_day"] * 30.0)
			_put("progress", "%.1f / %.1f GB" % [live.get("collected_gb", 0.0), target], -1, live.get("collected_gb", 0.0) / maxf(target, 0.001))
			_extra.lights = [["POWER", _lv(a, "power_margin")], ["BATTERY", _lv(a, "battery_dod")], ["DATA", _lv(a, "downlink_load")], ["IMAGES", _lv(a, "data_margin")]]
			_extra.queue_redraw()
		"ground":
			var sp: Dictionary = res.get("space", {})
			var onboard: float = live.get("onboard_gb", sp.get("stored_gb", 0.0))
			var days: float = sp.get("days", 30.0)
			var capacity: float = live.get("capacity_gb", x["downlink"] * days)
			var received: float = live.get("received_gb", 0.0)
			var mbps: float = float(MissionState.part_of("comms").get("mbps", 0.0))
			var sig := 0 if mbps >= 20.0 else 1
			_put("signal", live.get("signal", "Strong" if mbps >= 20.0 else "Fair"), sig, 0.9 if mbps >= 20.0 else 0.5)
			_put("window", "%d min/day" % int(MissionState.orbit()["contact_min_per_day"]))
			_put("onboard", "%.1f GB" % onboard, -1)
			_put("capacity", "%.1f GB" % capacity, 0 if capacity >= onboard else 2, capacity / maxf(onboard, 0.001))
			_put("received", "%.1f GB" % received, 0 if received > 0.0 else -1, received / maxf(onboard, 0.001))
			var left2 := maxf(onboard - received, 0.0)
			_put("left", "%.1f GB" % left2, 0 if left2 <= 0.01 else (1 if received > 0.0 else -1))
			_extra.onboard = onboard
			_extra.capacity = capacity
			_extra.received = received
			_extra.queue_redraw()
		"user":
			var g2: Dictionary = res.get("ground", {})
			var plots: Array = live.get("plots", [])
			var seen := 0
			var floods := 0
			var crops := 0
			for p in plots:
				if p["seen"]:
					seen += 1
					if p["state"] in ["flooded", "waterlogged"]:
						floods += 1
					else:
						crops += 1
			var total := maxi(plots.size(), 1)
			var conf := float(seen) / total
			_put("images", "%.1f GB" % g2.get("received_gb", 0.0))
			_put("covered", "%d / %d plots" % [seen, plots.size()], 0 if conf >= 0.8 else (1 if conf >= 0.5 else 2), conf)
			_put("flood", "%d" % live.get("flood_marked", floods), -1)
			_put("crops", "%d plots" % crops)
			_put("missing", "%.1f GB · %d plots" % [g2.get("lost_gb", 0.0), plots.size() - seen], 0 if seen == plots.size() else (1 if conf >= 0.5 else 2))
			_put("confidence", "%d%%" % int(100 * conf), 0 if conf >= 0.8 else (1 if conf >= 0.5 else 2), conf)
			_extra.plots = plots
			_extra.queue_redraw()
	_panel.reset_size()

static func short_orbit() -> String:
	var o := MissionState.orbit()
	var kind := "Sun-sync" if MissionState.orbit_id.begins_with("sso") else ("Moon" if o.get("body", "earth") == "moon" else "LEO")
	return "%s %d km" % [kind, int(o["altitude_km"])]

func _process(delta: float) -> void:
	var sv_open := false
	for n in get_tree().get_nodes_in_group("screenview"):
		sv_open = sv_open or n.is_open()
	_panel.visible = not sv_open
	_t += delta
	if _t > 0.3:
		_t = 0.0
		refresh()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I and not get_tree().paused:
		toggle()
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- level extras
## L2: subsystem lights (a quick "how is my spacecraft" picture).
class _Subsystems extends Control:
	var lights: Array = []
	func _draw() -> void:
		var n := maxi(lights.size(), 1)
		var w := size.x / n
		for i in lights.size():
			var c: Color = [FUI.GREEN, FUI.AMBER, FUI.RED, Color("#ff3b3b")][clampi(lights[i][1], 0, 3)]
			var r := Rect2(i * w + 2, 2, w - 4, size.y - 4)
			draw_rect(r, Color(c, 0.15))
			draw_rect(r, Color(c, 0.6), false, 1.0)
			draw_circle(Vector2(r.position.x + 9, r.get_center().y), 4, c)
			draw_string(FUI.font("JetBrainsMono-SemiBold"), Vector2(r.position.x + 17, r.get_center().y + 4), lights[i][0], HORIZONTAL_ALIGNMENT_LEFT, w - 20, 9, c)

## L3: the data bottleneck, drawn so you can see it: what's onboard vs what the link can carry.
class _Transfer extends Control:
	var onboard := 0.0
	var capacity := 0.0
	var received := 0.0
	func _draw() -> void:
		var f := FUI.font("JetBrainsMono-SemiBold")
		var full := maxf(maxf(onboard, capacity), 0.001)
		var y := 18.0
		var h := 16.0
		draw_string(f, Vector2(0, 11), "DATA TRANSFER", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, FUI.MUTED)
		draw_rect(Rect2(0, y, size.x, h), Color(1, 1, 1, 0.06))
		var ob := size.x * onboard / full
		var cap := size.x * minf(capacity, onboard) / full
		draw_rect(Rect2(0, y, ob, h), Color(FUI.RED, 0.35))            # everything onboard (red = can't fit)
		draw_rect(Rect2(0, y, cap, h), Color(FUI.AMBER, 0.35))         # what the link can carry
		draw_rect(Rect2(0, y, size.x * received / full, h), FUI.GREEN) # actually received
		var cx := size.x * capacity / full
		draw_line(Vector2(cx, y - 4), Vector2(cx, y + h + 4), FUI.WHITE, 2.0)
		draw_string(f, Vector2(0, y + h + 14), "received", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, FUI.GREEN)
		draw_string(f, Vector2(70, y + h + 14), "link capacity", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, FUI.AMBER)
		draw_string(f, Vector2(165, y + h + 14), "won't fit", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, FUI.RED)

## L4: simplified farm map. green healthy · yellow stressed · blue flooded/waterlogged · grey no imagery.
class _FarmMap extends Control:
	var plots: Array = []
	func _draw() -> void:
		var f := FUI.font("JetBrainsMono-SemiBold")
		draw_string(f, Vector2(0, 10), "FARM MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, FUI.MUTED)
		if plots.is_empty():
			draw_string(f, Vector2(0, 40), "no imagery yet", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, FUI.DIM)
			return
		var cols := 6
		var rows := int(ceil(plots.size() / float(cols)))
		var top := 16.0
		var cw := size.x / cols
		var ch := (size.y - top - 16.0) / rows
		for i in plots.size():
			var p: Dictionary = plots[i]
			var r := Rect2((i % cols) * cw + 1, top + (i / cols) * ch + 1, cw - 2, ch - 2)
			var c: Color
			if not p["seen"]:
				c = Color(0.35, 0.37, 0.4)
			else:
				c = {"healthy": Color("#22c55e"), "stressed": Color("#eab308"), "flooded": Color("#3b82f6"), "waterlogged": Color("#60a5fa")}.get(p["state"], FUI.MUTED)
			draw_rect(r, Color(c, 0.85))
			if p.get("marked", false):
				draw_rect(r, FUI.WHITE, false, 2.0)
			draw_string(f, r.position + Vector2(3, 11), p["id"], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0, 0, 0, 0.7))
		var ly := size.y - 4
		var items := [["healthy", Color("#22c55e")], ["stressed", Color("#eab308")], ["flood", Color("#3b82f6")], ["no data", Color(0.35, 0.37, 0.4)]]
		for i in items.size():
			draw_rect(Rect2(i * 72, ly - 8, 8, 8), items[i][1])
			draw_string(f, Vector2(i * 72 + 11, ly), items[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, FUI.MUTED)
