class_name GroundInstruments
extends RefCounted
## LEVEL 3 · GROUND COMMUNICATIONS: rack-mounted station equipment, fed by GroundSegment
## (the real pass geometry, the link capacity from your radio and orbit, data received so far).
##   Tracking   - antenna sky plot (predicted pass, satellite, dish pointing), signal strength trend
##   Window     - communication window countdown, contact minutes per day, bandwidth, link lamps
##   Downlink   - the data bottleneck: onboard store → narrow radio link → ground archive

static func live(key: String, default = 0.0):
	return MissionState.live.get(key, default)

static func room() -> Node:
	var t := Engine.get_main_loop() as SceneTree
	return t.current_scene if t else null

## Signal-to-noise from elevation and the radio you chose (higher, faster radios get a stronger link).
static func snr_db(el: float) -> float:
	var mbps := float(MissionState.part_of("comms").get("mbps", 2.0))
	var base := 8.0 + 4.0 * log(maxf(mbps, 0.01)) / log(10.0)
	return base + 12.0 * sin(deg_to_rad(clampf(el, 0.0, 90.0))) + randf_range(-0.6, 0.6)

# ---------------------------------------------------------------------------- tracking
class Tracking extends AV.Display:
	var polar: AV.Polar
	var trend: AV.Trend
	var snr: AV.Readout
	var azel: AV.Readout
	var lock: AV.Lamp
	var trk: AV.Lamp
	func build() -> void:
		code = "RF-01"
		title = "SIGNAL & ANTENNA TRACKING"
		accent = AV.OK
		footer = "DISH 1 · 34 m · AUTOTRACK"
		var row := AV.hbox(16)
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(row)
		polar = AV.Polar.new("ANTENNA SKY PLOT", Vector2(240, 240))
		polar.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_child(polar)
		var col := AV.vbox(10)
		AV.expand(col, true, true)
		row.add_child(col)
		var rr := AV.hbox(12)
		snr = AV.Readout.new("SIGNAL STRENGTH", "dB", 30, 120)
		azel = AV.Readout.new("AZ / EL", "°", 24, 120)
		rr.add_child(snr)
		rr.add_child(azel)
		col.add_child(rr)
		trend = AV.Trend.new("SIGNAL (SNR)", 0.0, 30.0, Vector2(260, 120))
		trend.color = AV.OK
		trend.threshold = 6.0
		trend.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(trend)
		var lamps := AV.hbox(8)
		lock = AV.Lamp.new("CARRIER LOCK", Vector2(120, 44))
		trk = AV.Lamp.new("AUTOTRACK", Vector2(120, 44))
		lamps.add_child(lock)
		lamps.add_child(trk)
		col.add_child(lamps)
		# the predicted pass, same arc the satellite flies in the sky outside
		for i in 41:
			var a := lerpf(-1.25, 1.25, i / 40.0)
			var p := Vector3(sin(a) * 520.0, cos(a) * 170.0, -365.0)
			polar.track.append([fposmod(rad_to_deg(atan2(p.x, -p.z)), 360.0), rad_to_deg(atan2(p.y, Vector2(p.x, p.z).length()))])
	func refresh() -> void:
		var r = GroundInstruments.room()
		var passing: bool = r != null and "passing" in r and r.passing
		var link: bool = GroundInstruments.live("link_on", false)
		var el: float = GroundInstruments.live("sat_el", -1.0)
		var az: float = GroundInstruments.live("sat_az", 0.0)
		polar.az = az
		polar.el = el if passing else -1.0
		polar.pointing = Vector2(az, el) if passing else Vector2(180, 10)
		polar.queue_redraw()
		var s := GroundInstruments.snr_db(el) if link else randf_range(0.5, 2.0)
		trend.push(s)
		snr.set_value("%.1f" % s, AV.OK if s >= 6.0 else AV.WARN)
		azel.set_value("%03d / %02d" % [int(az), int(maxf(el, 0.0))] if passing else "PARK", AV.WHITE)
		lock.set_state(0 if link else (-1 if passing else -2), "CARRIER LOCK" if link else ("ACQUIRING" if passing else "NO SIGNAL"))
		trk.set_state(0 if passing else -2, "AUTOTRACK " + ("ON" if passing else "STBY"))
		status = 0 if link else -1
		status_text = "LOCKED" if link else ("ACQUIRING" if passing else "AWAITING PASS")

# ---------------------------------------------------------------------------- comms window
class CommWindow extends AV.Display:
	var countdown: AV.Readout
	var perday: AV.Readout
	var bw: AV.Readout
	var cap: AV.Readout
	var used: AV.Gauge
	var aos: AV.Lamp
	var prio: AV.Lamp
	func build() -> void:
		code = "RF-02"
		title = "COMMUNICATION WINDOW"
		accent = AV.INFO
		footer = "PASS PLANNER · CONTACT SCHEDULE"
		var row := AV.hbox(16)
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(row)
		used = AV.Gauge.new("WINDOW USED", "%", 0.0, 100.0, "%.0f", Vector2(200, 190))
		used.bands = [[0.0, 0.75, AV.OK], [0.75, 0.92, AV.WARN], [0.92, 1.0, AV.BAD]]
		row.add_child(used)
		var col := AV.vbox(10)
		AV.expand(col)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(col)
		countdown = AV.Readout.new("WINDOW CLOSES IN", "", 40, 200)
		col.add_child(countdown)
		var rr := AV.hbox(12)
		perday = AV.Readout.new("CONTACT / DAY", "min", 24, 110)
		bw = AV.Readout.new("BANDWIDTH", "Mbps", 24, 110)
		rr.add_child(perday)
		rr.add_child(bw)
		col.add_child(rr)
		cap = AV.Readout.new("LINK CAPACITY THIS MONTH", "GB", 24, 200)
		col.add_child(cap)
		var lamps := AV.hbox(8)
		aos = AV.Lamp.new("LOS", Vector2(140, 44))
		prio = AV.Lamp.new("PRIORITY", Vector2(140, 44))
		lamps.add_child(aos)
		lamps.add_child(prio)
		body.add_child(lamps)
	func refresh() -> void:
		var r = GroundInstruments.room()
		var o := MissionState.orbit()
		var cmin := float(o.get("contact_min_per_day", 30.0))
		var k: float = GroundInstruments.live("pass_k", 0.0)
		var passing: bool = r != null and "passing" in r and r.passing
		var finished: bool = r != null and "finished" in r and r.finished
		if finished:
			k = 1.0
		var remain := cmin * (1.0 - k) * 60.0
		countdown.set_value("%02d:%02d" % [int(remain) / 60, int(remain) % 60] if passing or finished else "READY", AV.WARN if passing and k > 0.75 else (AV.WHITE if passing else AV.INFO))
		used.set_value(100.0 * k, 0 if k < 0.75 else (1 if k < 0.92 else 2))
		perday.set_value("%.0f" % cmin)
		bw.set_value("%.2f" % float(MissionState.part_of("comms").get("mbps", 0.0)) if float(MissionState.part_of("comms").get("mbps", 0.0)) < 1.0 else "%.0f" % float(MissionState.part_of("comms").get("mbps", 0.0)))
		cap.set_value("%.1f" % float(GroundInstruments.live("capacity_gb", 0.0)))
		var link: bool = GroundInstruments.live("link_on", false)
		aos.set_state(0 if link else (-2 if not passing else -1), "AOS · IN CONTACT" if link else ("LOS · NO CONTACT" if not passing else "ACQUIRING"))
		var p: String = GroundInstruments.live("priority", "floods")
		prio.set_state(-1, "PRIORITY: " + p.to_upper())
		status = -1 if not passing else (0 if k < 0.75 else 1)
		status_text = "PASS IN PROGRESS" if passing else ("PASS COMPLETE" if finished else "NEXT PASS READY")

# ---------------------------------------------------------------------------- downlink / bottleneck
class Downlink extends AV.Display:
	var pipe: Bottleneck
	var onb: AV.Readout
	var capr: AV.Readout
	var rec: AV.Readout
	var rem: AV.Readout
	var prog: AV.Meter
	func build() -> void:
		code = "DL-01"
		title = "DATA DOWNLINK"
		accent = AV.WARN
		footer = "ONBOARD STORE → RADIO LINK → GROUND ARCHIVE"
		pipe = Bottleneck.new()
		AV.expand(pipe, true, true)
		body.add_child(pipe)
		var rr := AV.hbox(12)
		onb = AV.Readout.new("TOTAL ONBOARD", "GB", 26, 110)
		capr = AV.Readout.new("LINK CAN CARRY", "GB", 26, 110)
		rec = AV.Readout.new("RECEIVED", "GB", 26, 110)
		rem = AV.Readout.new("REMAINING IN SPACE", "GB", 26, 110)
		for x in [onb, capr, rec, rem]:
			rr.add_child(x)
		body.add_child(rr)
		prog = AV.Meter.new("TRANSMISSION PROGRESS")
		body.add_child(prog)
	func refresh() -> void:
		var onboard: float = GroundInstruments.live("onboard_gb", 0.0)
		var capacity: float = GroundInstruments.live("capacity_gb", 0.0)
		var received: float = GroundInstruments.live("received_gb", 0.0)
		var left := maxf(onboard - received, 0.0)
		pipe.onboard = onboard
		pipe.capacity = capacity
		pipe.received = received
		pipe.link = GroundInstruments.live("link_on", false)
		onb.set_value("%.1f" % onboard)
		var fits := capacity >= onboard
		capr.set_value("%.1f" % capacity, AV.OK if fits else AV.WARN)
		rec.set_value("%.1f" % received, AV.OK)
		rem.set_value("%.1f" % left, AV.WHITE if left < 0.01 else AV.BAD)
		prog.set_value(received / maxf(onboard, 0.001), "%.0f%%" % (100.0 * received / maxf(onboard, 0.001)), 0 if fits else 1)
		prog.limit = clampf(capacity / maxf(onboard, 0.001), 0.0, 1.0) if not fits else -1.0
		prog.limit_text = "LINK LIMIT" if not fits else ""
		status = 0 if fits else 2
		status_text = "LINK OK" if fits else "BOTTLENECK"

## The bottleneck made visible: a big onboard store pouring through a pipe whose width is what
## the radio link can carry, into the ground archive. Anything above the pipe's share stays in space.
class Bottleneck extends Control:
	func px_funnel(x: float) -> float:
		return x
	var onboard := 0.0
	var capacity := 0.0
	var received := 0.0
	var link := false
	var _t := 0.0
	func _init() -> void:
		custom_minimum_size = Vector2(400, 170)
	func _process(d: float) -> void:
		_t += d
		queue_redraw()
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var tank_w := w * 0.26
		var top := 26.0
		var th := h - top - 8.0
		AV.text(self, Vector2(0, 16), "SATELLITE STORE", 14, AV.LABEL, "sans_semi", HORIZONTAL_ALIGNMENT_CENTER, tank_w)
		AV.text(self, Vector2(w - tank_w, 16), "GROUND ARCHIVE", 14, AV.LABEL, "sans_semi", HORIZONTAL_ALIGNMENT_CENTER, tank_w)
		var sc := th / maxf(maxf(onboard, capacity), 0.001)
		# left tank: what is onboard (drains as data is received)
		var l_rect := Rect2(0, top, tank_w, th)
		draw_rect(l_rect, Color(1, 1, 1, 0.03))
		draw_rect(l_rect, AV.FRAME, false, 2.0)
		var left_h := maxf(onboard - received, 0.0) * sc
		var stuck := maxf(onboard - capacity, 0.0) * sc
		draw_rect(Rect2(4, top + th - left_h, tank_w - 8, left_h), Color(AV.INFO, 0.55))
		if stuck > 0.0:
			# the part that will never fit through the link this month
			draw_rect(Rect2(4, top + th - left_h, tank_w - 8, minf(stuck, left_h)), Color(AV.BAD, 0.6))
			AV.text(self, Vector2(0, top + th - left_h + 22), "WON'T FIT", 13, AV.WHITE, "mono_semi", HORIZONTAL_ALIGNMENT_CENTER, tank_w)
		# right tank: what has arrived
		var r_rect := Rect2(w - tank_w, top, tank_w, th)
		draw_rect(r_rect, Color(1, 1, 1, 0.03))
		draw_rect(r_rect, AV.FRAME, false, 2.0)
		var rec_h := received * sc
		draw_rect(Rect2(w - tank_w + 4, top + th - rec_h, tank_w - 8, rec_h), Color(AV.OK, 0.55))
		# the pipe: its width is the link capacity compared with what is onboard
		var ratio := clampf(capacity / maxf(onboard, 0.001), 0.04, 1.0)
		# narrow on purpose: the pipe is the radio link, much thinner than the store it drains
		var pipe_h := maxf(th * 0.18 * ratio, 6.0)
		var py := top + th * 0.62 - pipe_h * 0.5
		# funnel from the store into the pipe
		draw_colored_polygon(PackedVector2Array([Vector2(px_funnel(tank_w), top + th * 0.35), Vector2(px_funnel(tank_w), top + th - 4), Vector2(tank_w + 30, py + pipe_h), Vector2(tank_w + 30, py)]), Color(AV.INFO, 0.08))
		var px0 := tank_w + 30
		var px1 := w - tank_w
		draw_rect(Rect2(px0, py, px1 - px0, pipe_h), Color(1, 1, 1, 0.05))
		draw_rect(Rect2(px0, py, px1 - px0, pipe_h), Color(AV.WARN if ratio < 1.0 else AV.OK, 0.9), false, 2.0)
		if link:
			var n := 9
			for i in n:
				var f := fmod(_t * 0.5 + i / float(n), 1.0)
				var cx := lerpf(px0 + 6, px1 - 6, f)
				draw_rect(Rect2(cx - 5, py + pipe_h * 0.2, 10, pipe_h * 0.6), Color(AV.OK, 0.9))
		AV.text(self, Vector2(px0, py - 10), "RADIO LINK  %.1f GB / month" % capacity, 14, AV.WARN if ratio < 1.0 else AV.OK, "mono_semi", HORIZONTAL_ALIGNMENT_CENTER, px1 - px0)
		if ratio < 1.0:
			AV.text(self, Vector2(px0, py - 34), "BOTTLENECK: the link carries only %d%% of the data" % int(100.0 * ratio), 15, AV.BAD, "sans_semi", HORIZONTAL_ALIGNMENT_CENTER, px1 - px0)
